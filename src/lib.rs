pub mod cac_data;
pub mod cdi_alerts;
pub mod config;

pub fn make_runtime() -> mlua::Result<mlua::Lua> {
    let lua = mlua::Lua::new();
    let log = lua.create_table()?;

    macro_rules! register_logging {
        ($type:ident) => {
            log.set(
                stringify!($type),
                lua.create_function(|_, s: mlua::String| {
                    tracing::$type!("{}", s.to_str()?.as_ref());
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

    lua.load_from_function::<mlua::Value>(
        "cdi.log",
        lua.create_function(move |_, ()| Ok(log.clone()))?,
    )?;
    lua.load_from_function::<mlua::Value>(
        "cdi.link",
        lua.create_function(move |lua, ()| {
            lua.create_function(|_, ()| Ok(cac_data::CdiAlertLink::default()))
        })?,
    )?;
    lua.load_from_function::<mlua::Value>(
        "cdi.discrete_value",
        lua.create_function(move |lua, ()| {
            lua.create_function(|_, (id, name): (String, _)| {
                Ok(cac_data::DiscreteValue::new(&id, name))
            })
        })?,
    )?;

    // Initialize a scripts "library" to contain function caches.
    lua.load_from_function::<mlua::Value>(
        "cdi.scripts",
        lua.create_function(|lua, ()| lua.create_table())?,
    )?;

    Ok(lua)
}
