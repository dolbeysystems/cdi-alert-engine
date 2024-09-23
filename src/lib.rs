pub mod cac_data;
pub mod cdi_alerts;
pub mod config;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error(transparent)]
    Io(#[from] std::io::Error),
    #[error(transparent)]
    Lua(#[from] mlua::Error),
}
