use futures::future::join_all;
use mlua::Lua;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::process::exit;
use std::sync::Arc;
use std::{fs, io};
use tokio::task;
use tracing::*;

mod cac_data;
mod config;

#[derive(Clone)]
struct Script {
    path: PathBuf,
    contents: String,
}

fn get_scripts(path: impl AsRef<Path>) -> io::Result<Vec<Script>> {
    let mut scripts = Vec::new();
    for entry in fs::read_dir(path)? {
        let entry = entry?;
        let path = entry.path();
        if !path.is_dir() {
            scripts.push(Script {
                path: path.to_path_buf(),
                contents: fs::read_to_string(path)?,
            });
        }
    }
    Ok(scripts)
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt().init();
    let config_path = "config.toml";
    let config = Arc::new(match config::Config::open(config_path) {
        Ok(config) => config,
        Err(msg) => {
            error!("failed to open {config_path}: {msg}");
            exit(1);
        }
    });

    let scripts: Arc<[Script]> = match get_scripts(&config.lua.scripts) {
        Ok(scripts) => scripts,
        Err(msg) => {
            error!("failed to load {}: {msg}", config.lua.scripts.display());
            exit(1);
        }
    }
    .into();

    loop {
        info!("scanning collection");

        // All scripts for all accounts are joined at once,
        // and then sorted back into a hashmap of accounts
        // so that results can be written to the database in bulk.
        let mut script_threads = Vec::new();

        while let Some(account) = cac_data::get_next_pending_account(&config.mongo_url)
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
                let script_name = script.path.to_string_lossy();

                let result = cac_data::CdiAlert {
                    script_name: script_name.to_string(),
                    passed: false,
                    validated: false,
                    outcome: None,
                    reason: None,
                    subtitle: None,
                    links: Vec::new(),
                    weight: None,
                };

                let account = account.clone();

                script_threads.push(task::spawn_blocking(move || {
                    let lua = make_runtime();
                    let script_name = script.path.to_string_lossy();
                    let _enter =
                        error_span!("lua", path = &*script_name, account = &account.id).entered();

                    lua.globals().set("account", account.clone()).unwrap();
                    lua.globals().set("result", result).unwrap();

                    lua.load(&script.contents)
                        .exec()
                        .map_err(|msg| error!("lua script failed: {msg}"))
                        .ok()
                        .and_then(|()| {
                            let result = lua
                                .globals()
                                .get::<_, mlua::Value>("result")
                                .unwrap()
                                .as_userdata()
                                .and_then(|x| x.take::<cac_data::CdiAlert>().ok());
                            if result.is_none() {
                                error!("failed to convert return value to result type");
                            }
                            result.zip(Some(account))
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
            if !results.contains_key(&account.id) {
                results.insert(&account.id, (account, Vec::new()));
            }
            let (_, ref mut results) = results.get_mut(&account.id).unwrap();
            results.push(result);
        }
        for (_, (account, result)) in results.into_iter() {
            let save_result = cac_data::save_cdi_alerts(&config, account, result.into_iter()).await;
            if let Err(e) = save_result {
                // The lack of requeue here is intentional. Best to just fail and log.
                error!("failed to save results: {e}");
            }
        }

        tokio::time::sleep(tokio::time::Duration::from_secs(config.polling_seconds)).await;
    }
}

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
