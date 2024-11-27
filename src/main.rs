use anyhow::Result;
use cdi_alert_engine::*;
use clap::Parser;
use derive_environment::FromEnv;
use futures::future::join_all;
use mlua::{Lua, LuaSerdeExt};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::exit;
use tokio::task;
use tracing::*;
use tracing_subscriber::layer::SubscriberExt;

const ENV_PREFIX: &str = "CDI_ALERT_ENGINE";

#[derive(clap::Parser)]
#[clap(author, version, about)]
pub struct Cli {
    #[clap(short, long, value_name = "path", default_value = "config.lua")]
    pub config: PathBuf,
    #[clap(short, long, value_name = "path", default_value = "info")]
    pub log: config::LogLevel,
}

#[derive(Debug, serde::Serialize, serde::Deserialize, FromEnv)]
pub struct Config {
    #[env(ignore)]
    pub scripts: HashMap<Box<Path>, ScriptInfo>,
    pub polling_seconds: u64,
    #[serde(default)]
    pub create_test_accounts: u32,
    #[serde(default)]
    pub script_engine_workflow_rest_url: String,
    pub mongo: config::Mongo,
}

impl Config {
    pub fn open(path: impl AsRef<Path>) -> Result<Self> {
        let lua = mlua::Lua::new();
        let path = path.as_ref();
        lua.load(&fs::read_to_string(path)?)
            .set_name(path.to_string_lossy())
            .exec()?;
        Ok(lua.from_value_with(
            mlua::Value::Table(lua.globals()),
            // These settings allow us to load our config from _G
            mlua::DeserializeOptions::new()
                // _G contains lua functions
                .deny_unsupported_types(false)
                // _G is recursive (_G._G)
                .deny_recursive_tables(false),
        )?)
    }
}

#[derive(Clone, Debug)]
struct Script {
    path: Box<Path>,
    // We don't use this info yet, but it is necessary
    info: ScriptInfo,
    contents: String,
}

#[derive(Clone, Debug, Default, serde::Serialize, serde::Deserialize, FromEnv)]
pub struct ScriptInfo {
    pub criteria_group: String,
}

fn load_scripts(scripts: impl Iterator<Item = (Box<Path>, ScriptInfo)>) -> Result<Box<[Script]>> {
    scripts
        .map(|(path, info)| {
            let contents = fs::read_to_string(&path)?;
            info!("loaded script: {}", path.display());
            Ok(Script {
                path,
                info,
                contents,
            })
        })
        .collect()
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();

    let tracing_registry = tracing_subscriber::registry()
        .with(tracing_subscriber::fmt::layer())
        .with(cli.log.to_filter());
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
    let mut scripts = load_scripts(scripts.into_iter()).unwrap();

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

    loop {
        profiling::scope!("database poll");

        info!("Reloading scripts");
        match Config::open(&cli.config) {
            Ok(config) => scripts = load_scripts(config.scripts.into_iter()).unwrap(),
            Err(msg) => {
                error!("Failed to open {}: {msg}", cli.config.display());
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
                let script_name = script.path.file_name().map(|x| x.to_string_lossy());
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

                    let lua = make_runtime().unwrap();
                    let script_name = script.path.to_string_lossy();
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
                            match lua.globals().get::<mlua::Value>("Result") {
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
fn make_runtime() -> mlua::Result<Lua> {
    let lua = Lua::new();
    let log = lua.create_table()?;

    macro_rules! register_logging {
        ($type:ident) => {
            log.set(
                stringify!($type),
                lua.create_function(|_, s: mlua::String| {
                    $type!("{}", s.to_str()?.as_ref());
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

    lua.load_from_function::<mlua::Value>(
        "cdi.log",
        lua.create_function(move |_, ()| Ok(log.clone()))?,
    )?;
    // TODO: Why aren't these used anywhere?
    lua.load_from_function::<mlua::Value>(
        "cdi.link",
        lua.create_function(move |lua, ()| {
            lua.create_function(|_, ()| Ok(cac_data::CdiAlertLink::default()))
        })?,
    )?;
    lua.load_from_function::<mlua::Value>(
        "cdi.discrete_value",
        lua.create_function(move |lua, ()| {
            lua.create_function(|_, (id, name): (String, _)| {
                Ok(cac_data::DiscreteValue::new(&id, name))
            })
        })?,
    )?;

    Ok(lua)
}
