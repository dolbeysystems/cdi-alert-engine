pub mod config;

use anyhow::{Context, Result};
use cdi_alert_engine::{Account, CdiAlert, DiscreteValue, EvaluationQueueEntry};
use mongodb::bson;
use std::sync::Arc;
use std::time::{Duration, SystemTime};
use tracing::*;

pub async fn next_pending_account(
    connection_string: &str,
    dv_days_back: u32,
    med_days_back: u32,
) -> Result<Option<Account>> {
    debug!("Getting next pending account");
    let cac_database_client = mongodb::Client::with_uri_str(connection_string)
        .await
        .with_context(|| format!("while connecting to {connection_string}"))?;
    let cac_database = cac_database_client.database("FusionCAC2");
    let evaluation_queue_collection =
        cac_database.collection::<EvaluationQueueEntry>("EvaluationQueue");

    let pending_account = evaluation_queue_collection
        .find_one_and_delete(bson::doc! {})
        .sort(bson::doc! { "TimeQueued": 1 })
        .await?;

    if let Some(pending_account) = pending_account {
        let id = pending_account.id.clone();
        let account =
            get_account_by_id(connection_string, &id, dv_days_back, med_days_back).await?;
        debug!("Found pending account: {:?}", &id);
        Ok(account)
    } else {
        debug!("No pending accounts found");
        Ok(None)
    }
}

pub async fn get_account_by_id(
    connection_string: &str,
    id: &str,
    dv_days_back: u32,
    med_days_back: u32,
) -> Result<Option<Account>> {
    debug!("Loading account #{:?} from database", id);
    let cac_database_client = mongodb::Client::with_uri_str(connection_string)
        .await
        .with_context(|| format!("while connecting to {connection_string}"))?;
    let cac_database = cac_database_client.database("FusionCAC2");
    let account_collection = cac_database.collection::<Account>("accounts");
    let mut account_cursor = account_collection.find(bson::doc! { "_id" : id }).await?;

    let account = if !(account_cursor.advance().await?) {
        None
    } else {
        let account = account_cursor.deserialize_current()?;
        Some(account)
    };

    let Some(mut account) = account else {
        return Ok(None);
    };

    debug!("Checking account #{:?} for external discrete values", id);
    let discrete_values_collection = cac_database.collection::<DiscreteValue>("discreteValues");
    let mut discrete_values_cursor = discrete_values_collection
        .find(bson::doc! { "AccountNumber" : id, "ResultDate" : { "$gte" : bson::DateTime::from_system_time(SystemTime::now() - Duration::from_secs(dv_days_back as u64 * 24 * 60 * 60)) } })
        .await?;

    let mut external_discrete_values = Vec::new();
    while discrete_values_cursor.advance().await? {
        let discrete_value = discrete_values_cursor.deserialize_current()?;
        external_discrete_values.push(Arc::new(discrete_value));
    }

    if !external_discrete_values.is_empty() {
        account
            .discrete_values
            .append(&mut external_discrete_values);
    }

    debug!("Building HashMaps for account #{:?}", id);
    account.build_caches(dv_days_back, med_days_back);

    Ok(Some(account))
}

pub async fn save<'config>(
    mongo: &'config config::Mongo,
    account: &Account,
    cdi_alerts: impl Iterator<Item = &CdiAlert> + Clone,
    script_engine_workflow_rest_url: &'config str,
) -> Result<()> {
    let cac_database_client = mongodb::Client::with_uri_str(&mongo.url)
        .await
        .with_context(|| format!("while connecting to {}", mongo.url))?;
    let cac_database = cac_database_client.database(&mongo.database);
    let evaluation_results_collection =
        cac_database.collection::<bson::Document>("EvaluationResults");

    // Create a bson array from our result iterator.
    // You *could* do this automatically with `bson::to_bson<Vec>`,
    // but this is wasteful because it allocates a vector just to convert it into another vector
    // (`bson::Array` is a typedef for `Vec<Bson>`)
    let mut cdi_alerts_bson = bson::Array::new();
    for i in cdi_alerts.clone() {
        if i.passed {
            cdi_alerts_bson.push(bson::to_bson(&i)?);
        }
    }

    // get existing alert result record (these are stored as properties on the record keyed off of
    // script name without extension, not as an array, so there's some annoying unpacking here.)
    let existing_result = evaluation_results_collection
        .find_one(bson::doc! { "_id": account.id.clone() })
        .await?;

    let alerts_changed = if let Some(existing_result) = existing_result {
        let mut any_different = false;
        for alert in cdi_alerts.clone() {
            let existing_alert_bson =
                existing_result.get(alert.script_name.replace(".lua", "").clone());
            if let Some(existing_alert_bson) = existing_alert_bson {
                if let Ok(existing_alert) = bson::from_bson::<CdiAlert>(existing_alert_bson.clone())
                {
                    if existing_alert != *alert {
                        // Present but different
                        any_different = true;
                        break;
                    }
                } else {
                    // Problem deserializing
                    any_different = true;
                    break;
                }
            } else {
                // Not present
                any_different = true;
                break;
            }
        }
        any_different
    } else {
        true
    };

    if alerts_changed && !script_engine_workflow_rest_url.is_empty() {
        // Save to Evaluation Results with _id and results remapped as properties by
        // script name without lua extension.  E.g.:
        // { _id: "001234", "anemia": { passed: true, links: [] }, "hypertension": { passed: false, links: [] } }

        let mut doc = bson::doc! {
            "_id" : account.id.clone(),
        };

        for alert in cdi_alerts.clone() {
            let alert_doc = bson::to_bson(&alert)?;
            doc.insert(alert.script_name.replace(".lua", "").clone(), alert_doc);
        }

        evaluation_results_collection
            .replace_one(bson::doc! { "_id": account.id.clone() }, doc)
            .upsert(true)
            .await?;

        info!(
            "Saved changed alert results for account {:?}, rerunning workflow",
            account.id
        );

        let client = reqwest::Client::new();
        let response = client
            .get(format!(
                "{}/{}",
                script_engine_workflow_rest_url, account.id
            ))
            .send()
            .await;

        let requeue_successful = match response {
            Ok(response) => {
                if response.status().is_success() {
                    true
                } else {
                    error!("Failed to queue account for workflow: {:?}", response);
                    false
                }
            }
            Err(e) => {
                error!("Failed to queue account for workflow: {:?}", e);
                false
            }
        };

        if !requeue_successful {
            let evaluation_queue_collection =
                cac_database.collection::<EvaluationQueueEntry>("EvaluationQueue");
            evaluation_queue_collection
                .insert_one(EvaluationQueueEntry {
                    id: account.id.clone(),
                    time_queued: SystemTime::now(),
                    source: "Requeue".to_string(),
                })
                .await?;
        }
    }
    Ok(())
}
