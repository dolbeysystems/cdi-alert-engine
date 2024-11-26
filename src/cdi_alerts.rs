use crate::cac_data::*;
use crate::config;
use anyhow::{Context, Result};
use chrono::{TimeZone, Utc};
use mongodb::bson::doc;
use std::{collections::HashMap, sync::Arc};
use tracing::*;

#[profiling::function]
pub async fn next_pending_account(connection_string: &str) -> Result<Option<Account>> {
    debug!("Getting next pending account");
    let cac_database_client = mongodb::Client::with_uri_str(connection_string)
        .await
        .with_context(|| format!("while connecting to {connection_string}"))?;
    let cac_database = cac_database_client.database("FusionCAC2");
    let evaluation_queue_collection =
        cac_database.collection::<EvaluationQueueEntry>("EvaluationQueue");

    let pending_account = evaluation_queue_collection
        .find_one_and_delete(doc! {})
        .sort(doc! { "TimeQueued": 1 })
        .await?;

    if let Some(pending_account) = pending_account {
        let id = pending_account.id.clone();
        let account = get_account_by_id(connection_string, &id).await?;
        debug!("Found pending account: {:?}", &id);
        Ok(account)
    } else {
        debug!("No pending accounts found");
        Ok(None)
    }
}

#[profiling::function]
pub async fn get_account_by_id(connection_string: &str, id: &str) -> Result<Option<Account>> {
    debug!("Loading account #{:?} from database", id);
    let cac_database_client = mongodb::Client::with_uri_str(connection_string)
        .await
        .with_context(|| format!("while connecting to {connection_string}"))?;
    let cac_database = cac_database_client.database("FusionCAC2");
    let account_collection = cac_database.collection::<Account>("accounts");
    let mut account_cursor = account_collection.find(doc! { "_id" : id }).await?;

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
        .find(doc! { "AccountNumber" : id })
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
    for discrete_value in account.discrete_values.iter() {
        let name = discrete_value.name.clone().unwrap_or("".to_string());
        account
            .hashed_discrete_values
            .entry(name.into())
            .or_insert_with(Vec::new)
            .push(discrete_value.clone());
    }

    for medication in account.medications.iter() {
        let category = medication.category.clone().unwrap_or("".to_string());
        account
            .hashed_medications
            .entry(category.into())
            .or_insert_with(Vec::new)
            .push(medication.clone());
    }

    for document in account.documents.iter() {
        let document_type = document.document_type.clone().unwrap_or("".to_string());
        account
            .hashed_documents
            .entry(document_type.into())
            .or_insert_with(Vec::new)
            .push(document.clone());

        for code_reference in document.code_references.iter() {
            let code_reference = code_reference.clone();
            account
                .hashed_code_references
                .entry(code_reference.code.clone())
                .or_insert_with(Vec::new)
                .push(CodeReferenceWithDocument {
                    document: document.clone(),
                    code_reference: code_reference.clone(),
                });
        }
        for code_reference in document.abstraction_references.iter() {
            account
                .hashed_code_references
                .entry(code_reference.code.clone())
                .or_insert_with(Vec::new)
                .push(CodeReferenceWithDocument {
                    document: document.clone(),
                    code_reference: code_reference.clone(),
                });
        }
    }

    Ok(Some(account))
}

#[profiling::function]
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
        .find_one(doc! { "_id": account.id.clone() })
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

        let mut doc = doc! {
            "_id" : account.id.clone(),
        };

        for alert in cdi_alerts.clone() {
            let alert_doc = bson::to_bson(&alert)?;
            doc.insert(alert.script_name.replace(".lua", "").clone(), alert_doc);
        }

        evaluation_results_collection
            .replace_one(doc! { "_id": account.id.clone() }, doc)
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
                    time_queued: Utc::now(),
                    source: "Requeue".to_string(),
                })
                .await?;
        }
    }
    Ok(())
}

#[profiling::function]
pub async fn create_test_data(
    connection_string: &str,
    number_of_test_accounts: usize,
) -> Result<()> {
    let cac_database_client = mongodb::Client::with_uri_str(connection_string)
        .await
        .with_context(|| format!("while connecting to {connection_string}"))?;
    let cac_database = cac_database_client.database("FusionCAC2");
    let account_collection = cac_database.collection::<Account>("accounts");
    let evaluation_queue_collection =
        cac_database.collection::<EvaluationQueueEntry>("EvaluationQueue");

    // create test accounts #TEST_CDI_X
    for i in 0..number_of_test_accounts {
        profiling::scope!("creating test account");

        let account_number = format!("TEST_CDI_{}", &i.to_string());
        account_collection
            .insert_one(Account {
                id: account_number,
                // April 17, 2024 12:00:00 PM
                admit_date_time: Some(Utc.with_ymd_and_hms(2024, 4, 17, 12, 0, 0).unwrap()),
                discharge_date_time: None,
                patient: Some(Arc::new(Patient {
                    mrn: Some("123456".to_string()),
                    first_name: Some("John".to_string()),
                    middle_name: Some("Q".to_string()),
                    last_name: Some("Public".to_string()),
                    gender: Some("M".to_string()),
                    birthdate: Some(Utc::now()),
                })),
                patient_type: Some("Inpatient".to_string()),
                admit_source: Some("Emergency Room".to_string()),
                admit_type: Some("Emergency".to_string()),
                hospital_service: Some("Medicine".to_string()),
                building: Some("Main".to_string()),
                documents: vec![
                    Arc::new(CACDocument {
                        document_id: "DOC_001".into(),
                        document_type: Some("Discharge Summary".to_string()),
                        document_date: Some(Utc::now()),
                        content_type: Some("text/plain".to_string()),
                        code_references: vec![
                            Arc::new(CodeReference {
                                code: "I10".into(),
                                value: None,
                                description: Some("Essential (primary) hypertension".to_string()),
                                phrase: Some("".to_string()),
                                start: Some(0),
                                length: Some(4),
                            }),
                            Arc::new(CodeReference {
                                code: "E11".into(),
                                value: None,
                                description: Some("Type 2 Diabetes".to_string()),
                                phrase: Some("".to_string()),
                                start: Some(0),
                                length: Some(4),
                            }),
                        ],
                        abstraction_references: vec![],
                    }),
                    Arc::new(CACDocument {
                        document_id: "DOC_002".into(),
                        document_type: Some("Physician Note".to_string()),
                        document_date: Some(Utc::now()),
                        content_type: Some("text/plain".to_string()),
                        code_references: vec![
                            Arc::new(CodeReference {
                                code: "R99".into(),
                                value: None,
                                description: Some("".to_string()),
                                phrase: Some("".to_string()),
                                start: Some(0),
                                length: Some(4),
                            }),
                            Arc::new(CodeReference {
                                code: "A10".into(),
                                value: None,
                                description: Some("".to_string()),
                                phrase: Some("".to_string()),
                                start: Some(0),
                                length: Some(4),
                            }),
                        ],
                        abstraction_references: vec![],
                    }),
                ],
                medications: vec![],
                discrete_values: vec![],
                cdi_alerts: vec![],
                working_history: vec![],
                hashed_code_references: HashMap::new(),
                hashed_discrete_values: HashMap::new(),
                hashed_medications: HashMap::new(),
                hashed_documents: HashMap::new(),
            })
            .await?;
    }

    // Queue up test accounts #TEST_CDI_X
    for i in 0..number_of_test_accounts {
        profiling::scope!("queueing test account");
        let account_number = format!("TEST_CDI_{}", &i.to_string());
        evaluation_queue_collection
            .insert_one(EvaluationQueueEntry {
                id: account_number,
                time_queued: Utc::now(),
                source: "test".to_string(),
            })
            .await?;
    }
    Ok(())
}

#[profiling::function]
pub async fn delete_test_data(connection_string: &str) -> Result<()> {
    let cac_database_client = mongodb::Client::with_uri_str(connection_string)
        .await
        .with_context(|| format!("while connecting to {connection_string}"))?;
    let cac_database = cac_database_client.database("FusionCAC2");
    let account_collection = cac_database.collection::<Account>("accounts");
    let evaluation_queue_collection =
        cac_database.collection::<EvaluationQueueEntry>("EvaluationQueue");
    let evaluation_results_collection =
        cac_database.collection::<bson::Document>("EvaluationResults");

    // delete test account #TEST_CDI_001
    account_collection
        .delete_many(doc! { "_id": { "$regex": "^TEST_CDI_.*" } })
        .await?;

    // delete cdi queue entries for #TEST_CDI_001 and #TEST_CDI_002 if they are still present
    evaluation_queue_collection
        .delete_many(doc! { "_id": { "$regex": "^TEST_CDI_.*" } })
        .await?;

    // delete cdi results for #TEST_CDI_001 and #TEST_CDI_002 if they are still present
    evaluation_results_collection
        .delete_many(doc! { "_id": { "$regex": "^TEST_CDI_.*" } })
        .await?;

    Ok(())
}
