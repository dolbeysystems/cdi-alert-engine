use cdi_alert_engine::*;
use clap::Parser;
use derive_environment::FromEnv;
use mlua::Lua;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::exit;
use std::sync::Arc;
use tracing::*;
use tracing_subscriber::layer::SubscriberExt;

const ENV_PREFIX: &str = "FAE_SCRIPT_ENGINE";

#[derive(clap::Parser)]
#[clap(author, version, about)]
pub struct Cli {
    #[clap(short, long, value_name = "path", default_value = "config.toml")]
    pub config: PathBuf,
    #[clap(short, long, value_name = "path")]
    pub scripts: Vec<PathBuf>,
    #[clap(short, long, value_name = "path", default_value = "info")]
    pub log: config::LogLevel,
}

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize, FromEnv)]
pub struct Config {
    pub scripts: Vec<config::Script>,
    pub mongo: config::Mongo,
    // TODO: Rabbit
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
    scripts: Arc<[Script]>,
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
    let Config { scripts, mongo } = config;

    let scripts: Arc<[Script]> = match scripts
        .into_iter()
        .filter(|x| !script_changes.remove.contains(&x.path))
        .chain(script_changes.scripts.into_iter())
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
            error!("Failed to load {}: {msg}", path.display());
            exit(1);
        }
    };

    info!(
        "Loaded the following scripts:{}",
        scripts.iter().fold(String::new(), |s, x| {
            s + "\n\t" + &x.config.path.to_string_lossy()
        })
    );

    InitResults { mongo, scripts }
}

#[tokio::main]
async fn main() {
    let InitResults { mongo, scripts } = init().await;
    loop {
        profiling::scope!("database poll");

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
        }
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

    lua
}
