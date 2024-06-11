use cdi_alert_engine::*;
use clap::Parser;
use derive_environment::FromEnv;
use futures::future::join_all;
use mlua::{Lua, LuaSerdeExt};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::process::exit;
use std::sync::Arc;
use std::{fs, io};
use tokio::task;
use tracing::*;
use tracing_subscriber::layer::SubscriberExt;

const ENV_PREFIX: &str = "CDI_ALERT_ENGINE";

#[derive(clap::Parser)]
#[clap(author, version, about)]
pub struct Cli {
    /// Default config file.
    /// Provides valid default values for every field.
    #[clap(short, long, value_name = "path", default_value = "config.toml")]
    pub config: PathBuf,
    /// Modifies the config file using a lua script.
    /// Each script will have access to the config structure through the `Config` global variable.
    #[clap(long, value_name = "path")]
    pub config_scripts: Vec<PathBuf>,
    #[clap(short, long, value_name = "path")]
    pub scripts: Vec<PathBuf>,
    #[clap(short, long, value_name = "path", default_value = "info")]
    pub log: config::LogLevel,
}

#[derive(Debug, serde::Serialize, serde::Deserialize, FromEnv)]
pub struct Config {
    pub scripts: Vec<config::Script>,
    pub polling_seconds: u64,
    #[serde(default)]
    pub create_test_accounts: u32,
    #[serde(default)]
    pub script_engine_workflow_rest_url: String,
    pub mongo: config::Mongo,
}

impl Config {
    pub fn open(path: impl AsRef<Path>) -> Result<Self, config::OpenConfigError> {
        Ok(toml::from_str(&fs::read_to_string(path.as_ref())?)?)
    }
}

#[derive(Clone, Debug)]
struct Script {
    config: config::Script,
    contents: String,
}

struct InitResults {
    mongo: config::Mongo,
    scripts: Vec<config::Script>,
    script_changes: config::ScriptDiff,
    polling_seconds: u64,
    script_engine_workflow_rest_url: String,
}

#[profiling::function]
async fn init() -> InitResults {
    // `clap` takes care of its own logging.
    let cli = Cli::parse();

    let tracing_registry = tracing_subscriber::registry()
        .with(tracing_subscriber::fmt::layer())
        .with(cli.log.to_filter());

    // Send tracing spans and logging to tracy.
    // This is mutually exclusive with the "tracy" feature.
    #[cfg(feature = "tracy-tracing")]
    let tracing_registry = tracing_registry.with(tracing_tracy::TracyLayer::default());

    tracing::subscriber::set_global_default(tracing_registry).unwrap();

    #[cfg(feature = "tracy-client")]
    tracy_client::Client::start();

    let mut config = match Config::open(&cli.config) {
        Ok(config) => config,
        Err(msg) => {
            error!("Failed to open {}: {msg}", cli.config.display());
            exit(1);
        }
    };
    for path in &cli.config_scripts {
        if let Err(msg) = augment_config(&mut config, path) {
            error!(
                "failed to apply configuration script \"{}\": {msg}",
                path.display()
            );
        }
    }
    let mut script_changes = config::ScriptDiff::default();
    for path in &cli.scripts {
        match config::ScriptDiff::open(path) {
            Ok(diff) => {
                script_changes.merge(diff);
            }
            Err(msg) => {
                error!("Failed to open {}: {msg}", path.display());
            }
        }
    }
    // Replace fields with environment variables.
    if let Err(msg) = config.with_env(ENV_PREFIX) {
        error!("{msg}");
    }
    let Config {
        scripts,
        polling_seconds,
        create_test_accounts,
        mongo,
        script_engine_workflow_rest_url,
    } = config;

    if create_test_accounts > 0 {
        info!("Removing old test data");
        if let Err(e) = cdi_alerts::delete_test_data(&mongo.url).await {
            error!("Failed to delete test data: {e}");
        }
        info!("Creating test data");
        if let Err(e) =
            cdi_alerts::create_test_data(&mongo.url, create_test_accounts as usize).await
        {
            error!("Failed to create test data: {e}");
        }
    }

    InitResults {
        mongo,
        scripts,
        script_changes,
        polling_seconds,
        script_engine_workflow_rest_url,
    }
}

fn load_scripts(
    scripts: &[config::Script],
    script_changes: &config::ScriptDiff,
) -> Result<Arc<[Script]>, (PathBuf, io::Error)> {
    let scripts: Arc<[Script]> = scripts
        .iter()
        .filter(|x| !script_changes.remove.contains(&x.path))
        .chain(script_changes.scripts.iter())
        .map(|x| match fs::read_to_string(&x.path) {
            Ok(contents) => Ok(Script {
                contents,
                config: x.clone(),
            }),
            Err(e) => Err((x.path.clone(), e)),
        })
        .collect::<Result<Arc<[Script]>, (PathBuf, io::Error)>>()?;

    info!(
        "Loaded the following scripts:{}",
        scripts.iter().fold(String::new(), |s, x| {
            s + "\n\t" + &x.config.path.to_string_lossy()
        })
    );

    Ok(scripts)
}

#[tokio::main]
async fn main() {
    let InitResults {
        mongo,
        scripts,
        script_changes,
        polling_seconds,
        script_engine_workflow_rest_url,
    } = init().await;

    loop {
        profiling::scope!("database poll");

        info!("Reloading scripts");
        let scripts = match load_scripts(&scripts, &script_changes) {
            Ok(scripts) => scripts,
            Err((path, msg)) => {
                error!("Failed to open {}: {msg}", path.display());
                exit(1);
            }
        };

        // All scripts for all accounts are joined at once,
        // and then sorted back into a hashmap of accounts
        // so that results can be written to the database in bulk.
        let mut script_threads = Vec::new();

        while let Some(account) = cdi_alerts::next_pending_account(&mongo.url)
            .await
            // print error message
            .map_err(|e| error!("Failed to get next pending account: {e}"))
            // discard error
            .ok()
            // coallesce Option<Option<T> into Option<T>.
            .and_then(|x| x)
        {
            profiling::scope!("processing account");
            info!("Evaluating account: {:?}", account.id);

            for script in scripts.iter().cloned() {
                profiling::scope!("initializing script");

                // Script name without directory
                let script_name = script.config.path.file_name().map(|x| x.to_string_lossy());
                let script_name = script_name
                    .as_ref()
                    .map(|x| x.as_ref())
                    .unwrap_or("unnamed script");

                let result = cac_data::CdiAlert {
                    script_name: script_name.to_string(),
                    passed: false,
                    validated: false,
                    outcome: None,
                    reason: None,
                    subtitle: None,
                    links: Vec::new(),
                    weight: None,
                    sequence: None,
                };

                let account = account.clone();

                script_threads.push(task::spawn_blocking(move || {
                    profiling::scope!("executing script");

                    let lua = make_runtime();
                    let script_name = script.config.path.to_string_lossy();
                    let _enter =
                        error_span!("lua", path = &*script_name, account = &account.id).entered();

                    #[allow(clippy::unwrap_used)]
                    {
                        lua.globals().set("Account", account.clone()).unwrap();
                        lua.globals().set("Result", result).unwrap();
                        lua.globals().set("ScriptName", script_name).unwrap();
                    }

                    lua.load(&script.contents)
                        .exec()
                        .map_err(|msg| error!("Lua script error: {msg}"))
                        .ok()
                        .and_then(|()| {
                            match lua.globals().get::<_, mlua::Value>("Result") {
                                Ok(result) => match result.as_userdata() {
                                    Some(result) => {
                                        let result = result.take();
                                        if let Err(msg) = &result {
                                            error!("Failed to retrieve result value: {msg}");
                                        }
                                        return result.ok().zip(Some(account));
                                    }
                                    None => error!("Result value is an unrecognized type"),
                                },
                                Err(msg) => error!("Result value is missing: {msg}"),
                            };
                            None
                        })
                }));
            }
        }

        debug!("Joining {} threads", script_threads.len());
        let alert_results = join_all(script_threads).await;
        let alert_results = alert_results
            .iter()
            .filter_map(|x| {
                x.as_ref()
                    .map_err(|msg| error!("Failed to join thread: {msg}"))
                    .ok()
            })
            .filter_map(|x| if let Some(x) = &x { Some(x) } else { None });
        let mut results = HashMap::new();
        for (result, account) in alert_results {
            results
                .entry(account.id.as_str())
                .or_insert_with(|| (account, Vec::new()))
                .1
                .push(result)
        }
        for (_, (account, result)) in results.into_iter() {
            let save_result = cdi_alerts::save(
                &mongo,
                account,
                result.into_iter(),
                &script_engine_workflow_rest_url,
            )
            .await;
            if let Err(e) = save_result {
                // The lack of requeue here is intentional. Best to just fail and log.
                error!("Failed to save results: {e}");
            }
        }
        debug!("Completed processing pending accounts");

        // Flush profiling information
        profiling::finish_frame!();

        tokio::time::sleep(tokio::time::Duration::from_secs(polling_seconds)).await;
    }
}

#[allow(clippy::unwrap_used)]
#[profiling::function]
fn make_runtime() -> Lua {
    let lua = Lua::new();

    macro_rules! register_logging {
        ($type:ident) => {
            lua.globals()
                .set(
                    stringify!($type),
                    lua.create_function(|_lua, s: String| {
                        $type!("{s}");
                        Ok(())
                    })
                    .unwrap(),
                )
                .unwrap();
        };
    }

    register_logging!(error);
    register_logging!(warn);
    register_logging!(info);
    register_logging!(debug);

    lua.globals()
        .set(
            "CdiAlertLink",
            lua.create_table_from([(
                "new",
                lua.create_function(|_lua, ()| Ok(cac_data::CdiAlertLink::default()))
                    .unwrap(),
            )])
            .unwrap(),
        )
        .unwrap();
    lua.globals()
        .set(
            "DiscreteValue",
            lua.create_table_from([(
                "new",
                lua.create_function(|_lua, (id, name): (String, _)| {
                    Ok(cac_data::DiscreteValue::new(&id, name))
                })
                .unwrap(),
            )])
            .unwrap(),
        )
        .unwrap();

    lua
}

fn augment_config(config: &mut Config, script: impl AsRef<Path>) -> mlua::Result<()> {
    let lua = Lua::new();
    lua.globals().set("Config", lua.to_value(config)?)?;
    lua.load(fs::read_to_string(script)?).exec()?;
    *config = lua.from_value(lua.globals().get("Config")?)?;
    Ok(())
}
