use std::{
    fs, io,
    path::{Path, PathBuf},
};

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
pub struct Config {
    pub mongo_url: String,
    pub script_directory: PathBuf,
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
