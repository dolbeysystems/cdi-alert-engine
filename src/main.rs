use anyhow::Result;

mod cac_data;

#[tokio::main(worker_threads = 256)]
async fn main() -> Result<()> {
    loop {
        println!("Scanning collection");

        let connection_string = "mongodb://localhost:27017";
        while let Some(account) = cac_data::get_next_pending_account(connection_string).await? {
            println!("Processing account: {:?}", account.id);

            // TODO: Run all lua scripts from script directory
            let scripts = vec!["script1.lua", "script2.lua", "script3.lua"];

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

            // TODO: Update account.CdiAlerts with only results with passed == true (there is some
            // special merge logic here for updating an entry that already exits)
        }

        tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;
    }
}
