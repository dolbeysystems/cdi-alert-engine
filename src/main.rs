#![feature(let_chains)]

use anyhow::Result;
use cdi_alert_engine::*;
use clap::Parser;
use derive_environment::FromEnv;
use futures::future::join_all;
use mlua::LuaSerdeExt;
use std::cell::Cell;
use std::collections::HashMap;
use std::fs;
use std::path::Path;
use std::process::exit;
use tokio::task;
use tracing::*;
use tracing_subscriber::layer::SubscriberExt;

const ENV_PREFIX: &str = "CDI_ALERT_ENGINE";

#[derive(clap::Parser)]
#[clap(author, version, about)]
pub struct Cli {
    #[clap(short, long, value_name = "path", default_value = "config.lua")]
    pub config: Box<Path>,
    #[clap(short, long, value_name = "path", default_value = "info")]
    pub log: config::LogLevel,
}

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize, FromEnv)]
pub struct Config {
    #[env(ignore)]
    pub scripts: HashMap<Box<Path>, ScriptInfo>,
    pub polling_seconds: u64,
    #[serde(default)]
    pub create_test_accounts: u32,
    #[serde(default)]
    pub script_engine_workflow_rest_url: String,
    pub mongo: config::Mongo,
    #[serde(default = "default_dv_days_back")]
    pub dv_days_back: u32,
    #[serde(default = "default_med_days_back")]
    pub med_days_back: u32,
}
fn default_dv_days_back() -> u32 {
    7
}
fn default_med_days_back() -> u32 {
    7
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

#[derive(Clone, Debug, Default, serde::Serialize, serde::Deserialize, FromEnv)]
pub struct ScriptInfo {
    pub criteria_group: String,
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();

    tracing_subscriber::registry()
        .with(tracing_subscriber::fmt::layer())
        .with(cli.log.to_filter());

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

    loop {
        // All scripts for all accounts are joined at once,
        // and then sorted back into a hashmap of accounts
        // so that results can be written to the database in bulk.
        let mut script_threads = Vec::new();

        while let Some(account) = cdi_alerts::next_pending_account(
            &config.mongo.url,
            config.dv_days_back,
            config.med_days_back,
        )
        .await
        .map_err(|e| error!("Failed to get next pending account: {e}"))
        .ok()
        // coallesce Option<Option<T> into Option<T>.
        .and_then(|x| x)
        {
            info!("Evaluating account: {:?}", account.id);

            for (path, _info) in config.scripts.iter() {
                let path = path.clone();
                // Script path without directory & extension
                let script_name = path.file_name().map(|x| x.to_string_lossy());
                let script_name = script_name
                    .as_ref()
                    .map(|x| x.to_string())
                    .unwrap_or("unnamed script".into());

                let result = cac_data::CdiAlert {
                    script_name: script_name.to_string(),
                    ..Default::default()
                };

                let account = account.clone();

                script_threads.push(task::spawn_blocking(move || {
                    thread_local! {
                        static RUNTIME: Cell<Option<mlua::Lua>> = const { Cell::new(None) };
                    }

                    let _enter =
                        error_span!("lua", path = &*script_name, account = &account.id).entered();
                    RUNTIME.with(|runtime| {
                        let lua = if let Some(runtime) = runtime.take() {
                            runtime
                        } else {
                            cdi_alert_engine::make_runtime().expect("runtime init should not fail")
                        };

                        let function = match lua
                            .load(mlua::chunk! { return require "cdi.scripts" [...] })
                            .call::<Option<mlua::Function>>(path.as_ref())
                        {
                            Ok(Some(function)) => function,
                            Ok(None) => match fs::read_to_string(&path) {
                                Ok(chunk) => lua
                                    .load(chunk)
                                    .set_name(&script_name)
                                    .into_function()
                                    .map_err(|msg| {
                                        error!("failed to load {} into lua: {msg}", path.display())
                                    })
                                    .ok()?,
                                Err(msg) => {
                                    error!("failed to open {}: {msg}", path.display());
                                    return None;
                                }
                            },
                            Err(msg) => {
                                error!("failed to retrieve script cache: {msg}");
                                return None;
                            }
                        };

                        runtime.set(Some(lua.clone()));

                        let function_environment = lua.create_table().unwrap();
                        let function_environment_meta = lua.create_table().unwrap();
                        function_environment_meta
                            .set("__index", lua.globals())
                            .unwrap();
                        function_environment.set_metatable(Some(function_environment_meta));
                        function_environment
                            .set("Account", account.clone())
                            .unwrap();
                        function_environment.set("Result", result).unwrap();
                        function
                            .set_environment(function_environment.clone())
                            .unwrap();

                        function
                            .call::<()>(())
                            .map_err(|msg| error!("Lua script error: {msg}"))
                            .ok()
                            .and_then(|()| {
                                let result = function_environment.get::<mlua::Value>("Result");
                                match result {
                                    Ok(result) => match result.as_userdata() {
                                        Some(result) => {
                                            let result = result.take();
                                            if let Err(msg) = &result {
                                                error!("Failed to retrieve result value: {msg}");
                                            }
                                            return result.ok().zip(Some(account));
                                        }
                                        None => error!(
                                            "Result value is an unrecognized type: {}",
                                            result.type_name()
                                        ),
                                    },
                                    Err(msg) => error!("Result value is missing: {msg}"),
                                };
                                None
                            })
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
                &config.mongo,
                account,
                result.into_iter(),
                &config.script_engine_workflow_rest_url,
            )
            .await;
            if let Err(e) = save_result {
                // The lack of requeue here is intentional. Best to just fail and log.
                error!("Failed to save results: {e}");
            }
        }
        debug!("Completed processing pending accounts");

        tokio::time::sleep(tokio::time::Duration::from_secs(config.polling_seconds)).await;
    }
}
