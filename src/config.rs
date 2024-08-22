use derive_environment::{FromEnv, FromEnvError};
use std::{path::PathBuf, str::FromStr};

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
    pub fn to_filter(self) -> tracing_subscriber::filter::LevelFilter {
        match self {
            LogLevel::Trace => tracing_subscriber::filter::LevelFilter::TRACE,
            LogLevel::Debug => tracing_subscriber::filter::LevelFilter::DEBUG,
            LogLevel::Info => tracing_subscriber::filter::LevelFilter::INFO,
            LogLevel::Warn => tracing_subscriber::filter::LevelFilter::WARN,
            LogLevel::Error => tracing_subscriber::filter::LevelFilter::ERROR,
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

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize, FromEnv)]
pub struct Mongo {
    pub url: String,
    pub database: String,
}

#[derive(Clone, Debug, Default, serde::Serialize, serde::Deserialize, FromEnv)]
pub struct Tls {
    pub ca_file: Option<PathBuf>,
    pub cert_file: Option<PathBuf>,
    pub password: Option<String>,
    #[serde(default)]
    pub allow_invalid_hostnames: bool,
}
