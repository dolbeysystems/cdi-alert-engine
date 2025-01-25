use anyhow::{bail, Context};
use cdi_alert_engine::cac_data::{self, Account, CdiAlert};
use cdi_alert_engine::cdi_alerts;
use clap::Parser;
use mlua::LuaSerdeExt;
use std::env;
use std::path::Path;
use std::{fs, process::exit};
use tracing::warn;

#[derive(clap::Parser)]
#[clap(author, version, about)]
pub struct Cli {
    /// Silence output of successful tests.
    #[clap(short, long)]
    pub quiet: bool,
    #[clap(short, long, value_name = "path", default_value = "test.lua")]
    pub config: Box<Path>,
    /// If present, only run specified tests.
    #[clap(value_name = "test")]
    pub tests: Vec<String>,
}

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
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
        .load(fs::read_to_string(cli.config)?)
        .eval::<mlua::Table>()?;

    let mut passes = 0;
    let mut failures = 0;

    let mut scripts = tests
        .pairs()
        .collect::<mlua::Result<Box<[(String, mlua::Table)]>>>()
        .with_context(|| "failed to collect test configurations")?;
    scripts.sort_unstable_by(|a, b| a.0.cmp(&b.0));
    for (script_path, accounts) in scripts {
        let includes_script_path =
            |x: &String| x.split_once(':').unwrap_or((x, "")).0 == script_path;
        if !cli.tests.is_empty() && !cli.tests.iter().any(includes_script_path) {
            continue;
        }
        let script = lua
            .load(
                fs::read_to_string(&script_path)
                    .with_context(|| format!("failed to open {script_path}"))?,
            )
            .set_name(format!("@{script_path}"))
            .into_function()
            .with_context(|| format!("failed to load {script_path} into lua"))?;
        let accounts = accounts
            .pairs()
            .collect::<mlua::Result<Box<[(String, mlua::Function)]>>>()
            .with_context(|| format!("failed to collect accounts for {script_path}"))?;
        for (account_script_path, expected_result) in accounts {
            if !cli.tests.is_empty()
                && !cli
                    .tests
                    .iter()
                    .filter(|x| includes_script_path(x))
                    .any(|x| {
                        x.split_once(':')
                            .is_none_or(|(_, x)| x == account_script_path)
                    })
            {
                continue;
            }
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
                            if !cli.quiet {
                                eprintln!("{script_path}:{account_script_path} ... {passed}",);
                            }
                            passes += 1;
                        }
                        Ok((false, reason)) => {
                            eprintln!("{script_path}:{account_script_path} ... {failed}",);
                            if let Some(reason) = reason {
                                eprintln!("\t{}", reason.display());
                            }
                            failures += 1;
                        }
                        Err(e) => {
                            eprintln!("{script_path}:{account_script_path} ... {error}",);
                            eprintln!("\t{e}");
                            failures += 1;
                        }
                    }
                }
                Err(e) => {
                    eprintln!("{script_path}:{account_script_path} ... {error}",);
                    eprintln!("\t{e}");
                    failures += 1;
                }
            }
        }
    }

    if cli.quiet && failures > 0 || !cli.quiet && passes + failures > 0 {
        eprintln!();
    }
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
    script_path: &str,
    script: &mlua::Function,
    account_script_path: &str,
) -> Result<(), anyhow::Error> {
    lua.load(
        fs::read_to_string(account_script_path)
            .with_context(|| format!("failed to open {account_script_path}"))?,
    )
    .set_name(format!("@{account_script_path}"))
    .exec()
    .with_context(|| format!("failed to evalutate {account_script_path}"))?;
    let Ok(accounts) = collections.get::<mlua::Table>("Accounts") else {
        bail!("no accounts provided by {account_script_path}");
    };
    let mut accounts = accounts.pairs::<mlua::Value, mlua::Value>();
    let (id, account) = accounts.next().unwrap()?;
    if accounts.next().is_some() {
        warn!("multiple accounts provided by {account_script_path}, using _id = {id:?}",);
    }
    collections.clear()?;
    let mut account: Account = lua
        .from_value(account)
        .with_context(|| "failed to deserialize account object")?;
    cdi_alerts::build_account_caches(&mut account, 7, 7);
    let globals = lua.globals();
    globals.set("Account", account)?;
    let script_name = Path::new(script_path)
        .file_name()
        .map(|x| x.to_string_lossy());
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
        .with_context(|| format!("{script_path} returned an error"))
}
