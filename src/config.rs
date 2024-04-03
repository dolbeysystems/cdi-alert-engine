use std::{
    fs, io,
    path::{Path, PathBuf},
};

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
pub struct Config {
    pub mongo_url: String,
    pub lua: Lua,
    pub cdi_workgroup_category: String,
    pub cdi_workgroup_name: String,
    pub polling_seconds: u64,
}

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
pub struct Lua {
    pub scripts: PathBuf,
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
