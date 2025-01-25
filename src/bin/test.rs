use anyhow::{bail, Context};
use cdi_alert_engine::cac_data::{self, Account, CdiAlert};
use cdi_alert_engine::cdi_alerts;
use mlua::LuaSerdeExt;
use std::env;
use std::path::{Path, PathBuf};
use std::{fs, process::exit};
use tracing::warn;

fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();

    let (passed, failed, error) =
        if let Ok("truecolor" | "24bit") = env::var("COLORTERM").as_ref().map(String::as_str) {
            use colored::Colorize;
            ("passed".green(), "failed".red(), "error".red())
        } else {
            ("passed".into(), "failed".into(), "error".into())
        };

    let lua = cdi_alert_engine::make_runtime()?;
    let collections = fae_ghost::lib(&lua)?;
    let tests = lua
        .load(fs::read_to_string("test.lua")?)
        .eval::<mlua::Table>()?;

    let mut passes = 0;
    let mut failures = 0;

    let mut scripts = tests
        .pairs::<PathBuf, mlua::Table>()
        .collect::<mlua::Result<Box<[(PathBuf, mlua::Table)]>>>()
        .with_context(|| "failed to collect test configurations")?;
    scripts.sort_unstable_by(|a, b| a.0.cmp(&b.0));
    for (script_path, accounts) in scripts {
        let script = lua
            .load(
                fs::read_to_string(&script_path)
                    .with_context(|| format!("failed to open {}", script_path.display()))?,
            )
            .set_name(format!("@{}", script_path.display()))
            .into_function()
            .with_context(|| format!("failed to load {} into lua", script_path.display()))?;
        let accounts = accounts
            .pairs::<PathBuf, mlua::Function>()
            .collect::<mlua::Result<Box<[(PathBuf, mlua::Function)]>>>()
            .with_context(|| format!("failed to collect accounts for {}", script_path.display()))?;
        for (account_script_path, expected_result) in accounts {
            match test(
                &lua,
                &collections,
                &script_path,
                &script,
                &account_script_path,
            ) {
                Ok(()) => {
                    let result: CdiAlert = lua.globals().get("Result")?;
                    match expected_result.call::<(bool, Option<mlua::String>)>(result) {
                        Ok((true, _)) => {
                            eprintln!(
                                "{}:{} ... {passed}",
                                script_path.display(),
                                account_script_path.display()
                            );
                            passes += 1;
                        }
                        Ok((false, reason)) => {
                            eprintln!(
                                "{}:{} ... {failed}",
                                script_path.display(),
                                account_script_path.display()
                            );
                            if let Some(reason) = reason {
                                eprintln!("\t{}", reason.display());
                            }
                            failures += 1;
                        }
                        Err(e) => {
                            eprintln!(
                                "{}:{} ... {error}",
                                script_path.display(),
                                account_script_path.display()
                            );
                            eprintln!("\t{e}");
                            failures += 1;
                        }
                    }
                }
                Err(e) => {
                    eprintln!(
                        "{}:{} ... {error}",
                        script_path.display(),
                        account_script_path.display()
                    );
                    eprintln!("\t{e}");
                    failures += 1;
                }
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

fn test(
    lua: &mlua::Lua,
    collections: &mlua::Table,
    script_path: &Path,
    script: &mlua::Function,
    account_script_path: &Path,
) -> Result<(), anyhow::Error> {
    lua.load(
        fs::read_to_string(account_script_path)
            .with_context(|| format!("failed to open {}", account_script_path.display()))?,
    )
    .set_name(format!("@{}", account_script_path.display()))
    .exec()
    .with_context(|| format!("failed to evalutate {}", account_script_path.display()))?;
    let Ok(accounts) = collections.get::<mlua::Table>("Accounts") else {
        bail!("no accounts provided by {}", account_script_path.display());
    };
    let mut accounts = accounts.pairs::<mlua::Value, mlua::Value>();
    let (id, account) = accounts.next().unwrap()?;
    if accounts.next().is_some() {
        warn!(
            "multiple accounts provided by {}, using _id = {id:?}",
            account_script_path.display()
        );
    }
    collections.clear()?;
    let mut account: Account = lua
        .from_value(account)
        .with_context(|| "failed to deserialize account object")?;
    cdi_alerts::build_account_caches(&mut account, 7, 7);
    let globals = lua.globals();
    globals.set("Account", account)?;
    let script_name = script_path.file_name().map(|x| x.to_string_lossy());
    let script_name = script_name
        .as_ref()
        .map(|x| x.to_string())
        .unwrap_or("unnamed script".into());
    globals.set(
        "Result",
        cac_data::CdiAlert {
            script_name,
            ..Default::default()
        },
    )?;
    script
        .call::<()>(())
        .with_context(|| format!("{} returned an error", script_path.display()))
}
