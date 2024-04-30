use derive_environment::{FromEnv, FromEnvError};
use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::str::FromStr;
use std::{fs, io};

/// Logging level enum, used for deserialization.
#[derive(Clone, Debug, Default, serde::Deserialize, serde::Serialize)]
pub enum LogLevel {
    /// Enables trace, debug, info, warn, and error logging messages.
    #[serde(rename = "trace")]
    Trace,
    /// Enables debug, info, warn, and error logging messages.
    #[serde(rename = "debug")]
    Debug,
    #[default]
    /// Enables info, warn, and error logging messages.
    #[serde(rename = "info")]
    Info,
    /// Enables warn, and error logging messages.
    #[serde(rename = "warn")]
    Warn,
    /// Enables error logging messages.
    #[serde(rename = "error")]
    Error,
}

impl LogLevel {
    pub fn to_tracing(self) -> tracing::Level {
        match self {
            LogLevel::Trace => tracing::Level::TRACE,
            LogLevel::Debug => tracing::Level::DEBUG,
            LogLevel::Info => tracing::Level::INFO,
            LogLevel::Warn => tracing::Level::WARN,
            LogLevel::Error => tracing::Level::ERROR,
        }
    }
}

/// Error that occurs when an invalid string is used as a log level.
#[derive(Debug, thiserror::Error)]
#[error("Invalid log level: {0}")]
pub struct LogLevelParseError(String);

impl FromStr for LogLevel {
    type Err = LogLevelParseError;
    fn from_str(s: &str) -> Result<Self, LogLevelParseError> {
        match s {
            "trace" => Ok(LogLevel::Trace),
            "debug" => Ok(LogLevel::Debug),
            "info" => Ok(LogLevel::Info),
            "warn" => Ok(LogLevel::Warn),
            "error" => Ok(LogLevel::Error),
            _ => Err(LogLevelParseError(s.to_string())),
        }
    }
}

derive_environment::impl_using_from_str!(LogLevel);

#[derive(clap::Parser)]
#[clap(author, version, about)]
pub struct Cli {
    #[clap(short, long, value_name = "path", default_value = "config.toml")]
    pub config: PathBuf,
    #[clap(short, long, value_name = "path")]
    pub scripts: Vec<PathBuf>,
    #[clap(short, long, value_name = "path", default_value = "info")]
    pub log: LogLevel,
}

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize, FromEnv)]
pub struct Config {
    pub scripts: Vec<Script>,
    pub polling_seconds: u64,
    #[serde(default)]
    pub create_test_data: bool,
    #[serde(default = "default_update_workgroup_assignment")]
    pub update_workgroup_assignment: bool,
    pub mongo: Mongo,
    pub cdi_workgroup: CdiWorkgroup,
}
fn default_update_workgroup_assignment() -> bool {
    true
}

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize, FromEnv)]
pub struct Mongo {
    pub url: String,
}

#[derive(Clone, Debug, Default, serde::Serialize, serde::Deserialize, FromEnv)]
pub struct Script {
    pub path: PathBuf,
    pub criteria_group: String,
}

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize, FromEnv)]
pub struct CdiWorkgroup {
    pub category: String,
    pub name: String,
}

#[derive(Debug, thiserror::Error)]
pub enum OpenConfigError {
    #[error(transparent)]
    Io(#[from] io::Error),
    #[error(transparent)]
    Toml(#[from] toml::de::Error),
}

impl Config {
    pub fn open(path: impl AsRef<Path>) -> Result<Self, OpenConfigError> {
        Ok(toml::from_str(&fs::read_to_string(path.as_ref())?)?)
    }
}

/// Used for making small adjustments to the active scripts
/// without modifying the central config file.
#[derive(Clone, Default, Debug, serde::Serialize, serde::Deserialize)]
#[serde(default)]
pub struct ScriptDiff {
    pub scripts: Vec<Script>,
    pub remove: HashSet<PathBuf>,
}

impl ScriptDiff {
    pub fn open(path: impl AsRef<Path>) -> Result<Self, OpenConfigError> {
        Ok(toml::from_str(&fs::read_to_string(path.as_ref())?)?)
    }

    pub fn merge(&mut self, mut other: Self) {
        self.scripts.append(&mut other.scripts);
        for i in other.remove.drain() {
            self.remove.insert(i);
        }
    }
}
