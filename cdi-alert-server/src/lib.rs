pub mod config;

use anyhow::{Context, Result};
use cdi_alert_engine::{Account, CdiAlert, DiscreteValue, EvaluationQueueEntry};
use futures::StreamExt;
use mongodb::bson;
use std::sync::Arc;
use std::time::{Duration, SystemTime};
use tracing::*;

pub async fn next_pending_account(
    connection_string: &str,
    dv_days_back: u32,
    med_days_back: u32,
) -> Result<Option<Account>> {
    if let Some(pending_account) = mongodb::Client::with_uri_str(connection_string)
        .await
        .with_context(|| format!("while connecting to {connection_string}"))?
        .database("FusionCAC2")
        .collection::<EvaluationQueueEntry>("EvaluationQueue")
        .find_one_and_delete(bson::doc! {})
        .sort(bson::doc! { "TimeQueued": 1 })
        .await?
    {
        Ok(get_account_by_id(
            connection_string,
            &pending_account.id,
            dv_days_back,
            med_days_back,
        )
        .await?)
    } else {
        Ok(None)
    }
}

pub async fn get_account_by_id(
    connection_string: &str,
    id: &str,
    dv_days_back: u32,
    med_days_back: u32,
) -> Result<Option<Account>> {
    let cac_database = mongodb::Client::with_uri_str(connection_string)
        .await
        .with_context(|| format!("while connecting to {connection_string}"))?
        .database("FusionCAC2");

    let Some(mut account) = cac_database
        .collection::<Account>("accounts")
        .find(bson::doc! { "_id" : id })
        .await?
        .next()
        .await
        .transpose()?
    else {
        return Ok(None);
    };

    account.discrete_values.append(
        &mut (cac_database.collection::<DiscreteValue>("discreteValues")
            .find(bson::doc! { "AccountNumber" : id, "ResultDate" : { "$gte" : bson::DateTime::from_system_time(SystemTime::now() - Duration::from_secs(dv_days_back as u64 * 24 * 60 * 60)) } })
            .await?
            .filter_map(async |x| x.ok().map(Arc::new))
            .collect::<Vec<Arc<DiscreteValue>>>()
            .await),
    );

    account.build_caches(dv_days_back, med_days_back);

    Ok(Some(account))
}

pub async fn save<'config>(
    mongo: &'config config::Mongo,
    account: &Account,
    cdi_alerts: impl Iterator<Item = &CdiAlert> + Clone,
    script_engine_workflow_rest_url: &'config str,
) -> Result<()> {
    let cac_database = mongodb::Client::with_uri_str(&mongo.url)
        .await
        .with_context(|| format!("while connecting to {}", mongo.url))?
        .database(&mongo.database);
    let evaluation_results_collection =
        cac_database.collection::<bson::Document>("EvaluationResults");

    // get existing alert result record (these are stored as properties on the record keyed off of
    // script name without extension, not as an array, so there's some annoying unpacking here.)
    let alerts_changed = evaluation_results_collection
        .find_one(bson::doc! { "_id": account.id.clone() })
        .await?
        .map(|existing_alert| {
            cdi_alerts.clone().any(|alert| {
                existing_alert
                    .get(alert.script_name.replace(".lua", ""))
                    .map(|bson| {
                        bson::from_bson::<CdiAlert>(bson.clone())
                            .map(|existing| existing != *alert)
                            .unwrap_or(true)
                    })
                    .unwrap_or(true)
            })
        })
        .unwrap_or(false);

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
