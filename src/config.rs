use derive_environment::FromEnv;
use std::path::{Path, PathBuf};
use std::{fs, io};

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize, FromEnv)]
pub struct InitialConfig {
    pub scripts: Vec<Script>,
    pub polling_seconds: u64,
    #[serde(default)]
    pub create_test_data: bool,

    // This is ignored so that it can manually be "flattened" in main.rs
    #[env(ignore)]
    #[serde(flatten)]
    pub config: Config,
}

/// This is persistent config that needs to be shared among threads.
#[derive(Clone, Debug, serde::Serialize, serde::Deserialize, FromEnv)]
pub struct Config {
    pub mongo: Mongo,
    pub cdi_workgroup: CdiWorkgroup,
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

impl InitialConfig {
    pub fn open(path: impl AsRef<Path>) -> Result<Self, OpenConfigError> {
        Ok(toml::from_str(&fs::read_to_string(path.as_ref())?)?)
    }
}
