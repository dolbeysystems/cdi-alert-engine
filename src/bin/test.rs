use cdi_alert_engine::{
    cac_data::{self, Account, CdiAlert},
    cdi_alerts,
};
use mlua::LuaSerdeExt;
use std::{fs, process::exit};

fn main() -> anyhow::Result<()> {
    let lua = cdi_alert_engine::make_runtime()?;
    let collections = fae_ghost::lib(&lua)?;
    let tests = lua
        .load(fs::read_to_string("test.lua")?)
        .eval::<mlua::Table>()?;

    let mut passes = 0;
    let mut failures = 0;

    for i in tests.pairs::<String, mlua::Table>() {
        let (script_path, accounts) = i?;
        let script = lua
            .load(fs::read_to_string(&script_path)?)
            .set_name(format!("@{script_path}"))
            .into_function()?;
        for i in accounts.pairs::<String, mlua::Function>() {
            let (account_script_path, expected_result) = i?;
            lua.load(fs::read_to_string(&account_script_path)?)
                .set_name(format!("@{account_script_path}"))
                .exec()?;
            let accounts = collections.get::<mlua::Table>("Accounts")?;
            let mut accounts = accounts.pairs::<mlua::Value, mlua::Value>();
            let (id, account) = accounts.next().unwrap()?;
            if accounts.next().is_some() {
                eprintln!(
                    "multiple accounts provided by {}, using _id = {id:?}",
                    &account_script_path
                );
            }
            // Clear out the collections table so that the next test can start fresh.
            collections.clear()?;
            // This step isn't strictly necessary (besides the account cache function)
            // but it normalizes the account representation since the serde field names are PascalCase
            // and the lua field names are snake_case.
            // The test files *could* provide lua's key names but this way the account definitions
            // may be reused for testing via other serde sources (eg, mongodb).
            let mut account: Account = lua.from_value(account)?;
            // Accept all provided medications and discrete values.
            // Test accounts should not provide them if they should not be used.
            cdi_alerts::build_account_caches(&mut account, 7, 7);
            let globals = lua.globals();
            globals.set("Account", account)?;
            globals.set(
                "Result",
                cac_data::CdiAlert {
                    script_name: account_script_path.to_string(),
                    ..Default::default()
                },
            )?;
            script.call::<()>(())?;
            let result: CdiAlert = globals.get("Result")?;
            if expected_result.call(result)? {
                eprintln!("{script_path}:{account_script_path} ... passed");
                passes += 1;
            } else {
                eprintln!("{script_path}:{account_script_path} ... failed");
                failures += 1;
            }
        }
    }

    eprintln!();
    eprintln!("{passes} test{} passed", if passes == 1 { "" } else { "s" });
    eprintln!(
        "{failures} test{} failed",
        if failures == 1 { "" } else { "s" }
    );
    exit(if failures > 0 { 1 } else { 0 });
}
