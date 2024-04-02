use std::path::Path;
use std::process::exit;
use std::{fs, io};
use tracing::*;

mod cac_data;

fn get_scripts(path: impl AsRef<Path>) -> io::Result<Vec<String>> {
    let mut scripts = Vec::new();
    for entry in fs::read_dir(path)? {
        let entry = entry?;
        let path = entry.path();
        if !path.is_dir() {
            scripts.push(fs::read_to_string(path)?);
        }
    }
    Ok(scripts)
}

#[tokio::main(worker_threads = 256)]
async fn main() {
    tracing_subscriber::fmt().init();

    let scripts = match get_scripts("scripts/") {
        Ok(scripts) => scripts,
        Err(msg) => {
            error!("failed to load scripts: {msg}");
            exit(1);
        }
    };

    loop {
        info!("scanning collection");

        let connection_string = "mongodb://localhost:27017";
        while let Some(account) = cac_data::get_next_pending_account(connection_string)
            .await
            // print error message
            .map_err(|e| error!("failed to get account: {e}"))
            // discard error
            .ok()
            // coallesce Option<Option<T> into Option<T>.
            .and_then(|x| x)
        {
            info!("processing account: {:?}", account.id);

            let results: Vec<cac_data::CdiAlert> = scripts
                .iter()
                .map(|script| {
                    let mut result = cac_data::CdiAlert {
                        script_name: script.to_string(),
                        passed: false,
                        validated: false,
                        outcome: None,
                        reason: None,
                        subtitle: None,
                        links: None,
                        weight: None,
                    };
                    // TODO: Run lua script, exposing the account (readonly) and result (read/write)

                    // return the modified result
                    result
                })
                .collect();

            // TODO: Update account.CdiAlerts with only results with passed == true
            // (there is some special merge logic here for updating an entry that already exists)
        }

        tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;
    }
}
