use mlua::Lua;
use std::path::{Path, PathBuf};
use std::process::exit;
use std::{fs, io};
use tracing::*;

mod cac_data;
mod config;

struct Script {
    path: PathBuf,
    // TODO: try precompiling this into a binary at startup.
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

#[tokio::main(worker_threads = 256)]
async fn main() {
    tracing_subscriber::fmt().init();
    let config_path = "config.toml";
    let config = match config::Config::open(config_path) {
        Ok(config) => config,
        Err(msg) => {
            error!("failed to open {config_path}: {msg}");
            exit(1);
        }
    };
    let lua_runtime = Lua::new();

    macro_rules! register_logging {
        ($type:ident) => {
            lua_runtime
                .globals()
                .set(
                    stringify!($type),
                    lua_runtime
                        .create_function(|_lua, s: String| {
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

    let scripts = match get_scripts(&config.lua.scripts) {
        Ok(scripts) => scripts,
        Err(msg) => {
            error!("failed to load {}: {msg}", config.lua.scripts.display());
            exit(1);
        }
    };

    loop {
        info!("scanning collection");

        while let Some(account) = cac_data::get_next_pending_account(&config.mongo_url)
            .await
            // print error message
            .map_err(|e| error!("failed to get account: {e}"))
            // discard error
            .ok()
            // coallesce Option<Option<T> into Option<T>.
            .and_then(|x| x)
        {
            info!("processing account: {:?}", account.id);

            lua_runtime
                .globals()
                .set("account", account.clone())
                .unwrap();

            let alert_results: Vec<cac_data::CdiAlert> = scripts
                .iter()
                .filter_map(|script| {
                    let script_name = script.path.to_string_lossy();
                    lua_runtime
                        .globals()
                        .set("script_filename", script_name.clone())
                        .unwrap();

                    let result = cac_data::CdiAlert {
                        script_name: script_name.into(),
                        passed: false,
                        validated: false,
                        outcome: None,
                        reason: None,
                        subtitle: None,
                        links: Vec::new(),
                        weight: None,
                    };
                    lua_runtime.globals().set("result", result).unwrap();

                    let get_result = |()| -> Result<cac_data::CdiAlert, mlua::Error> {
                        lua_runtime
                            .globals()
                            .get::<&str, mlua::Value>("result")?
                            .as_userdata()
                            .ok_or(mlua::Error::UserDataTypeMismatch)?
                            .take()
                    };
                    {
                        // Prefixes logging messages from lua with "lua".
                        let _enter = error_span!("lua").entered();
                        lua_runtime
                            .load(&script.contents)
                            .exec()
                            .and_then(get_result)
                            .map_err(|msg| error!("failed to run script: {msg}"))
                            .ok()
                    }
                })
                .collect();

            let save_result = cac_data::save_cdi_alerts(&config, &account, &alert_results).await;

            if let Err(e) = save_result {
                // The lack of requeue here is intentional. Best to just fail and log.
                error!("failed to save results: {e}");
            }
        }

        tokio::time::sleep(tokio::time::Duration::from_secs(config.polling_seconds)).await;
    }
}
