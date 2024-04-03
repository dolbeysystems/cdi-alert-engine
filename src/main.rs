use mlua::Lua;
use std::path::Path;
use std::process::exit;
use std::{fs, io};
use tracing::*;

mod cac_data;
mod config;

fn get_scripts(path: impl AsRef<Path>) -> io::Result<Vec<String>> {
    let mut scripts = Vec::new();
    for entry in fs::read_dir(path)? {
        let entry = entry?;
        let path = entry.path();
        if !path.is_dir() {
            scripts.push(fs::read_to_string(path)?);
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

    let scripts = match get_scripts(&config.script_directory) {
        Ok(scripts) => scripts,
        Err(msg) => {
            error!(
                "failed to load {}: {msg}",
                config.script_directory.display()
            );
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

            lua_runtime.globals().set("account", account).unwrap();

            let results: Vec<cac_data::CdiAlert> = scripts
                .iter()
                .map(|script| {
                    let result = cac_data::CdiAlert {
                        script_name: script.to_string(),
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
                            .load(script)
                            .exec()
                            .and_then(get_result)
                            .map_err(|msg| error!("failed to run script: {msg}"))
                            .ok()
                    }
                })
                .filter_map(|x| x)
                .collect();

            // TODO: Update account.CdiAlerts with only results with passed == true
            // (there is some special merge logic here for updating an entry that already exists)
        }

        tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;
    }
}
