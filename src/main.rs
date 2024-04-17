use derive_environment::FromEnv;
use futures::future::join_all;
use mlua::Lua;
use std::collections::HashMap;
use std::fs;
use std::process::exit;
use std::sync::Arc;
use tokio::task;
use tracing::*;

mod cac_data;
mod config;

const ENV_PREFIX: &str = "CDI_ALERT_ENGINE";

#[derive(Clone)]
struct Script {
    config: config::Script,
    contents: String,
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt().init();
    // TODO: configure this from the command line.
    let config_path = "config.toml";
    let mut config = match config::InitialConfig::open(config_path) {
        Ok(config) => config,
        Err(msg) => {
            error!("failed to open {config_path}: {msg}");
            exit(1);
        }
    };
    // Replace fields with environment variables.
    if let Err(msg) = config.with_env(ENV_PREFIX) {
        error!("{msg}");
    }
    let config::InitialConfig {
        scripts,
        polling_seconds,
        create_test_data,
        mut config,
    } = config;
    // This is the sub-config struct, which also needs to respect environment variables.
    if let Err(msg) = config.with_env(ENV_PREFIX) {
        error!("{msg}");
    }

    if create_test_data {
        if let Err(e) = cac_data::delete_test_data(&config).await {
            error!("failed to delete test data: {e}");
        }
        if let Err(e) = cac_data::create_test_data(&config).await {
            error!("failed to create test data: {e}");
        }
    }

    let scripts: Arc<[Script]> = match scripts
        .into_iter()
        .map(|x| match fs::read_to_string(&x.path) {
            Ok(contents) => Ok(Script {
                contents,
                config: x,
            }),
            Err(e) => Err((x.path, e)),
        })
        .collect()
    {
        Ok(scripts) => scripts,
        Err((path, msg)) => {
            error!("failed to load {}: {msg}", path.display());
            exit(1);
        }
    };

    loop {
        info!("scanning collection");

        // All scripts for all accounts are joined at once,
        // and then sorted back into a hashmap of accounts
        // so that results can be written to the database in bulk.
        let mut script_threads = Vec::new();

        while let Some(account) = cac_data::get_next_pending_account(&config.mongo.url)
            .await
            // print error message
            .map_err(|e| error!("failed to get account: {e}"))
            // discard error
            .ok()
            // coallesce Option<Option<T> into Option<T>.
            .and_then(|x| x)
        {
            let scripts = scripts.clone();

            info!("processing account: {:?}", account.id);
            for script in scripts.iter().cloned() {
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
                                            error!("failed to retrieve result value: {msg}");
                                        }
                                        return result.ok().zip(Some(account));
                                    }
                                    None => error!("result value is an unrecognized type"),
                                },
                                Err(msg) => error!("result value is missing: {msg}"),
                            };
                            None
                        })
                }));
                info!("{} threads", script_threads.len());
            }
        }

        info!("joining {} threads", script_threads.len());
        let alert_results = join_all(script_threads).await;
        let alert_results = alert_results
            .iter()
            .filter_map(|x| {
                x.as_ref()
                    .map_err(|msg| error!("failed to join thread: {msg}"))
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
            let save_result = cac_data::save_cdi_alerts(&config, account, result.into_iter()).await;
            if let Err(e) = save_result {
                // The lack of requeue here is intentional. Best to just fail and log.
                error!("failed to save results: {e}");
            }
        }

        tokio::time::sleep(tokio::time::Duration::from_secs(polling_seconds)).await;
    }
}

#[allow(clippy::unwrap_used)]
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
