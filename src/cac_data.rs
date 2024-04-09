use chrono::{DateTime, Utc};
use mongodb::{bson::doc, options::FindOneAndDeleteOptions};
use serde::{Deserialize, Serialize};
use serde_with::serde_as;
use std::{collections::HashMap, sync::Arc};
use tracing::*;

use crate::config::Config;

macro_rules! getter {
    ($fields:ident, $field:ident) => {
        $fields.add_field_method_get(stringify!($field), |_, this| Ok(this.$field.clone()));
    };
}

macro_rules! setter {
    ($fields:ident, $field:ident) => {
        $fields.add_field_method_set(stringify!($field), |_, this, value| {
            this.$field = value;
            Ok(())
        });
    };
}

// To avoid excessive cloning, wrap `UserData` in `Arc`s!

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct AccountCustomWorkFlowEntry {
    #[serde(rename = "WorkGroup")]
    pub work_group: Option<String>,
    #[serde(rename = "CriteriaGroup")]
    pub criteria_group: Option<String>,
    #[serde(rename = "CriteriaSequence")]
    pub criteria_sequence: Option<i32>,
    #[serde(rename = "WorkGroupCategory")]
    pub work_group_category: Option<String>,
    #[serde(rename = "WorkGroupType")]
    pub work_group_type: Option<String>,
    #[serde(rename = "WorkGroupAssignedBy")]
    pub work_group_assigned_by: Option<String>,
    #[serde(rename = "WorkGroupAssignedDateTime")]
    #[serde_as(as = "Option<bson::DateTime>")]
    pub work_group_date_time: Option<DateTime<Utc>>,
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct WorkGroupCategory {
    #[serde(rename = "_id")]
    pub id: Arc<str>,
    #[serde(rename = "WorkGroups")]
    pub workgroups: Vec<WorkGroup>,
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct WorkGroup {
    #[serde(rename = "WorkGroup")]
    pub work_group: String,
    #[serde(rename = "CriteriaGroups")]
    pub criteria_groups: Vec<CriteriaGroup>,
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct CriteriaGroup {
    #[serde(rename = "Name")]
    pub name: String,
    #[serde(rename = "Filters")]
    pub filters: Vec<CriteriaFilter>,
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct CriteriaFilter {
    #[serde(rename = "Property")]
    pub property: String,
    #[serde(rename = "Operator")]
    pub operator: String,
    #[serde(rename = "Value")]
    pub value: String,
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct CodeReferenceWithDocument {
    #[serde(rename = "document")]
    pub document: Arc<CACDocument>,
    #[serde(rename = "code_reference")]
    pub code_reference: Arc<CodeReference>,
}
impl mlua::UserData for CodeReferenceWithDocument {
    fn add_fields<'lua, F: mlua::UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_field_method_get("document", |_, this| Ok(this.document.clone()));
        fields.add_field_method_get("code_reference", |_, this| Ok(this.code_reference.clone()));
    }
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct Account {
    #[serde(rename = "_id")]
    pub id: String,
    #[serde(rename = "AdmitDateTime")]
    #[serde_as(as = "Option<bson::DateTime>")]
    pub admit_date_time: Option<DateTime<Utc>>,
    #[serde(rename = "DischargeDateTime")]
    #[serde_as(as = "Option<bson::DateTime>")]
    pub discharge_date_time: Option<DateTime<Utc>>,
    #[serde(rename = "Patient")]
    pub patient: Option<Arc<Patient>>,
    #[serde(rename = "PatientType")]
    pub patient_type: Option<String>,
    #[serde(rename = "AdmitSource")]
    pub admit_source: Option<String>,
    #[serde(rename = "AdmitType")]
    pub admit_type: Option<String>,
    #[serde(rename = "HospitalService")]
    pub hospital_service: Option<String>,
    #[serde(rename = "Building")]
    pub building: Option<String>,
    #[serde(rename = "Documents", default)]
    pub documents: Vec<Arc<CACDocument>>,
    #[serde(rename = "Medications", default)]
    pub medications: Vec<Arc<Medication>>,
    #[serde(rename = "DiscreteValues", default)]
    pub discrete_values: Vec<Arc<DiscreteValue>>,
    #[serde(rename = "CdiAlerts", default)]
    pub cdi_alerts: Vec<Arc<CdiAlert>>,
    #[serde(rename = "CustomWorkflow", default)]
    pub custom_workflow: Option<Vec<AccountCustomWorkFlowEntry>>,

    // These are just caches, do not (de)serialize them.
    #[serde(skip)]
    pub hashed_code_references: HashMap<Arc<str>, Vec<CodeReferenceWithDocument>>,
    #[serde(skip)]
    pub hashed_discrete_values: HashMap<Arc<str>, Vec<Arc<DiscreteValue>>>,
    #[serde(skip)]
    pub hashed_medications: HashMap<Arc<str>, Vec<Arc<Medication>>>,
    #[serde(skip)]
    pub hashed_documents: HashMap<Arc<str>, Vec<Arc<CACDocument>>>,
}

impl mlua::UserData for Account {
    fn add_fields<'lua, F: mlua::UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_field_method_get("id", |_, this| Ok(this.id.clone()));
        fields.add_field_method_get("admit_date_time", |_, this| {
            Ok(this.admit_date_time.map(|x| x.to_string()))
        });
        fields.add_field_method_get("discharge_date_time", |_, this| {
            Ok(this.discharge_date_time.map(|x| x.to_string()))
        });
        fields.add_field_method_get("patient", |_, this| Ok(this.patient.clone()));
        fields.add_field_method_get("patient_type", |_, this| Ok(this.patient_type.clone()));
        fields.add_field_method_get("admit_source", |_, this| Ok(this.admit_source.clone()));
        fields.add_field_method_get("admit_type", |_, this| Ok(this.admit_type.clone()));
        fields.add_field_method_get("hospital_service", |_, this| {
            Ok(this.hospital_service.clone())
        });
        fields.add_field_method_get("building", |_, this| Ok(this.building.clone()));
        fields.add_field_method_get("documents", |_, this| Ok(this.documents.clone()));
        fields.add_field_method_get("medications", |_, this| Ok(this.medications.clone()));
        fields.add_field_method_get("discrete_values", |_, this| {
            Ok(this.discrete_values.clone())
        });
        fields.add_field_method_get("cdi_alerts", |_, this| Ok(this.cdi_alerts.clone()));
    }

    fn add_methods<'lua, M: mlua::UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_method("find_code_references", |_, this, code: String| {
            if let Some(code_references) = this.hashed_code_references.get(&*code) {
                info!("Found code references for code: {:?}", code);
                Ok(code_references.clone())
            } else {
                info!("No code references found for code: {:?}", code);
                Ok(Vec::new())
            }
        });
        methods.add_method("find_discrete_values", |_, this, unique_id: String| {
            if let Some(discrete_values) = this.hashed_discrete_values.get(&*unique_id) {
                Ok(discrete_values.clone())
            } else {
                Ok(Vec::new())
            }
        });
        methods.add_method("find_medications", |_, this, external_id: String| {
            if let Some(medications) = this.hashed_medications.get(&*external_id) {
                Ok(medications.clone())
            } else {
                Ok(Vec::new())
            }
        });
        methods.add_method("find_documents", |_, this, document_id: String| {
            if let Some(documents) = this.hashed_documents.get(&*document_id) {
                Ok(documents.clone())
            } else {
                Ok(Vec::new())
            }
        });
    }
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct Patient {
    #[serde(rename = "MRN")]
    pub mrn: Option<String>,
    #[serde(rename = "FirstName")]
    pub first_name: Option<String>,
    #[serde(rename = "MiddleName")]
    pub middle_name: Option<String>,
    #[serde(rename = "LastName")]
    pub last_name: Option<String>,
    #[serde(rename = "Gender")]
    pub gender: Option<String>,
    #[serde(rename = "BirthDate")]
    #[serde_as(as = "Option<bson::DateTime>")]
    pub birthdate: Option<DateTime<Utc>>,
}

impl mlua::UserData for Patient {
    fn add_fields<'lua, F: mlua::UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_field_method_get("mrn", |_, this| Ok(this.mrn.clone()));
        fields.add_field_method_get("first_name", |_, this| Ok(this.first_name.clone()));
        fields.add_field_method_get("middle_name", |_, this| Ok(this.middle_name.clone()));
        fields.add_field_method_get("last_name", |_, this| Ok(this.last_name.clone()));
        fields.add_field_method_get("gender", |_, this| Ok(this.gender.clone()));
        fields.add_field_method_get("birthdate", |_, this| {
            Ok(this.birthdate.map(|x| x.to_string()))
        });
    }
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct CACDocument {
    #[serde(rename = "DocumentId")]
    pub document_id: Arc<str>,
    #[serde(rename = "DocumentType")]
    pub document_type: Option<String>,
    #[serde(rename = "DocumentDate")]
    #[serde_as(as = "Option<bson::DateTime>")]
    pub document_date: Option<DateTime<Utc>>,
    #[serde(rename = "ContentType")]
    pub content_type: Option<String>,
    #[serde(rename = "CodeReferences", default)]
    pub code_references: Vec<Arc<CodeReference>>,
    #[serde(rename = "AbstractionReferences", default)]
    pub abstraction_references: Vec<Arc<CodeReference>>,
}
impl mlua::UserData for CACDocument {
    fn add_fields<'lua, F: mlua::UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_field_method_get("document_id", |_, this| Ok(this.document_id.to_string()));
        fields.add_field_method_get("document_type", |_, this| Ok(this.document_type.clone()));
        fields.add_field_method_get("document_date", |_, this| {
            Ok(this.document_date.map(|d| d.to_string()))
        });
        fields.add_field_method_get("content_type", |_, this| Ok(this.content_type.clone()));
        fields.add_field_method_get("code_references", |_, this| {
            Ok(this.code_references.clone())
        });
        fields.add_field_method_get("abstraction_references", |_, this| {
            Ok(this.abstraction_references.clone())
        });
    }
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct Medication {
    #[serde(rename = "ExternalId")]
    pub external_id: Arc<str>,
    #[serde(rename = "Medication")]
    pub medication: Option<String>,
    #[serde(rename = "Dosage")]
    pub dosage: Option<String>,
    #[serde(rename = "Route")]
    pub route: Option<String>,
    #[serde(rename = "StartDate")]
    #[serde_as(as = "Option<bson::DateTime>")]
    pub start_date: Option<DateTime<Utc>>,
    #[serde(rename = "EndDate")]
    #[serde_as(as = "Option<bson::DateTime>")]
    pub end_date: Option<DateTime<Utc>>,
    #[serde(rename = "Status")]
    pub status: Option<String>,
    #[serde(rename = "Category")]
    pub category: Option<String>,
}

impl mlua::UserData for Medication {
    fn add_fields<'lua, F: mlua::UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_field_method_get("external_id", |_, this| Ok(this.external_id.to_string()));
        fields.add_field_method_get("medication", |_, this| Ok(this.medication.clone()));
        fields.add_field_method_get("dosage", |_, this| Ok(this.dosage.clone()));
        fields.add_field_method_get("route", |_, this| Ok(this.route.clone()));
        fields.add_field_method_get("start_date", |_, this| {
            Ok(this.start_date.map(|x| x.to_string()))
        });
        fields.add_field_method_get("end_date", |_, this| {
            Ok(this.end_date.map(|x| x.to_string()))
        });
        fields.add_field_method_get("status", |_, this| Ok(this.status.clone()));
        fields.add_field_method_get("category", |_, this| Ok(this.category.clone()));
    }
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct DiscreteValue {
    #[serde(rename = "UniqueId")]
    pub unique_id: Arc<str>,
    #[serde(rename = "Name")]
    pub name: Option<String>,
    #[serde(rename = "Result")]
    pub result: Option<String>,
    #[serde(rename = "ResultDate")]
    #[serde_as(as = "Option<bson::DateTime>")]
    pub result_date: Option<DateTime<Utc>>,
}

impl DiscreteValue {
    pub fn new(unique_id: &str, name: String) -> Self {
        Self {
            unique_id: unique_id.into(),
            name: Some(name),
            result: None,
            result_date: None,
        }
    }
}

impl mlua::UserData for DiscreteValue {
    fn add_fields<'lua, F: mlua::UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_field_method_get("unique_id", |_, this| Ok(this.unique_id.to_string()));
        fields.add_field_method_get("name", |_, this| Ok(this.name.clone()));
        fields.add_field_method_get("result", |_, this| Ok(this.result.clone()));
        fields.add_field_method_get("result_date", |_, this| {
            Ok(this.result_date.map(|x| x.to_string()))
        });

        setter!(fields, name);
        setter!(fields, result);

        fields.add_field_method_set("unique_id", |_, this, value: String| {
            this.unique_id = value.into();
            Ok(())
        });
    }
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct CodeReference {
    #[serde(rename = "Code")]
    pub code: Arc<str>,
    #[serde(rename = "Value")]
    pub value: Option<String>,
    #[serde(rename = "Description")]
    pub description: Option<String>,
    #[serde(rename = "Phrase")]
    pub phrase: Option<String>,
    #[serde(rename = "Start")]
    pub start: Option<i32>,
    #[serde(rename = "Length")]
    pub length: Option<i32>,
}

impl mlua::UserData for CodeReference {
    fn add_fields<'lua, F: mlua::UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_field_method_get("code", |_, this| Ok(this.code.to_string()));
        fields.add_field_method_get("value", |_, this| Ok(this.value.clone()));
        fields.add_field_method_get("description", |_, this| Ok(this.description.clone()));
        fields.add_field_method_get("phrase", |_, this| Ok(this.phrase.clone()));
        fields.add_field_method_get("start", |_, this| Ok(this.start));
        fields.add_field_method_get("length", |_, this| Ok(this.length));
    }
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct CdiAlert {
    #[serde(rename = "ScriptName")]
    pub script_name: String,
    #[serde(rename = "Passed")]
    pub passed: bool,
    #[serde(rename = "Links", default)]
    pub links: Vec<Arc<CdiAlertLink>>,
    #[serde(rename = "Validated")]
    pub validated: bool,
    #[serde(rename = "SubTitle")]
    pub subtitle: Option<String>,
    #[serde(rename = "Outcome")]
    pub outcome: Option<String>,
    #[serde(rename = "Reason")]
    pub reason: Option<String>,
    #[serde(rename = "Weight")]
    pub weight: Option<f64>,
    #[serde(rename = "Sequence")]
    pub sequence: Option<i32>,
}

impl mlua::UserData for CdiAlert {
    fn add_fields<'lua, F: mlua::UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_field_method_get("script_name", |_, this| Ok(this.script_name.clone()));
        fields.add_field_method_get("passed", |_, this| Ok(this.passed));
        fields.add_field_method_get("links", |_, this| Ok(this.links.clone()));
        fields.add_field_method_get("validated", |_, this| Ok(this.validated));
        fields.add_field_method_get("subtitle", |_, this| Ok(this.subtitle.clone()));
        fields.add_field_method_get("outcome", |_, this| Ok(this.outcome.clone()));
        fields.add_field_method_get("reason", |_, this| Ok(this.reason.clone()));
        fields.add_field_method_get("weight", |_, this| Ok(this.weight));
        fields.add_field_method_get("sequence", |_, this| Ok(this.sequence));

        // Notice that script_name is not mutable!!
        fields.add_field_method_set("passed", |_, this, value| {
            this.passed = value;
            Ok(())
        });
        fields.add_field_method_set("links", |_, this, value: Vec<mlua::AnyUserData>| {
            let mut links = Vec::new();
            for i in value {
                links.push(Arc::new(i.borrow::<CdiAlertLink>()?.clone()))
            }
            this.links = links;
            Ok(())
        });
        fields.add_field_method_set("validated", |_, this, value| {
            this.validated = value;
            Ok(())
        });
        fields.add_field_method_set("subtitle", |_, this, value| {
            this.subtitle = value;
            Ok(())
        });
        fields.add_field_method_set("outcome", |_, this, value| {
            this.outcome = value;
            Ok(())
        });
        fields.add_field_method_set("reason", |_, this, value| {
            this.reason = value;
            Ok(())
        });
        fields.add_field_method_set("weight", |_, this, value| {
            this.weight = value;
            Ok(())
        });
    }
}

#[serde_as]
#[derive(Clone, Default, Debug, Serialize, Deserialize, PartialEq)]
pub struct CdiAlertLink {
    #[serde(rename = "LinkText")]
    pub link_text: String,
    #[serde(rename = "DocumentId")]
    pub document_id: Option<String>,
    #[serde(rename = "Code")]
    pub code: Option<String>,
    #[serde(rename = "DiscreteValueId")]
    pub discrete_value_id: Option<String>,
    #[serde(rename = "DiscreteValueName")]
    pub discrete_value_name: Option<String>,
    #[serde(rename = "MedicationId")]
    pub medication_id: Option<String>,
    #[serde(rename = "MedicationName")]
    pub medication_name: Option<String>,
    #[serde(rename = "LatestDiscreteValueId")]
    pub latest_discrete_value_id: Option<DiscreteValue>,
    #[serde(rename = "IsValidated")]
    pub is_validated: bool,
    #[serde(rename = "UserNotes")]
    pub user_notes: Option<String>,
    #[serde(rename = "Links", default)]
    pub links: Vec<CdiAlertLink>,
    #[serde(rename = "Sequence")]
    pub sequence: i32,
    #[serde(rename = "Hidden")]
    pub hidden: bool,
}

impl mlua::UserData for CdiAlertLink {
    fn add_fields<'lua, F: mlua::UserDataFields<'lua, Self>>(f: &mut F) {
        getter!(f, link_text);
        getter!(f, document_id);
        getter!(f, code);
        getter!(f, discrete_value_id);
        getter!(f, discrete_value_name);
        getter!(f, medication_id);
        getter!(f, medication_name);
        getter!(f, latest_discrete_value_id);
        getter!(f, is_validated);
        getter!(f, user_notes);
        getter!(f, links);
        getter!(f, sequence);
        getter!(f, hidden);

        setter!(f, link_text);
        setter!(f, document_id);
        setter!(f, code);
        setter!(f, discrete_value_id);
        setter!(f, discrete_value_name);
        setter!(f, medication_id);
        setter!(f, medication_name);
        setter!(f, is_validated);
        setter!(f, user_notes);
        setter!(f, sequence);
        setter!(f, hidden);

        f.add_field_method_set(
            "latest_discrete_value_id",
            |_, this, value: mlua::AnyUserData| {
                this.latest_discrete_value_id = value.take()?;
                Ok(())
            },
        );
        f.add_field_method_set("links", |_, this, value: mlua::AnyUserData| {
            this.links = value.take()?;
            Ok(())
        });
    }
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct CdiAlertQueueEntry {
    #[serde(rename = "_id")]
    pub id: String,
    #[serde(rename = "TimeQueued")]
    #[serde_as(as = "bson::DateTime")]
    pub time_queued: DateTime<Utc>,
    #[serde(rename = "AccountNumber")]
    pub account_number: String,
    #[serde(rename = "ScriptName")]
    pub script_name: String,
}

#[derive(thiserror::Error, Debug)]
pub enum GetAccountError<'connection> {
    #[error("failed to parse CAC database connection string ({string}): {error}")]
    ConnectionString {
        string: &'connection str,
        error: mongodb::error::Error,
    },
    // For any other generic mongo errors.
    #[error(transparent)]
    Mongo(#[from] mongodb::error::Error),
}

#[derive(thiserror::Error, Debug)]
pub enum SaveCdiAlertsError<'connection> {
    #[error("failed to parse CAC database connection string ({string}): {error}")]
    ConnectionString {
        string: &'connection str,
        error: mongodb::error::Error,
    },
    // For any other generic mongo errors.
    #[error(transparent)]
    Mongo(#[from] mongodb::error::Error),
    #[error(transparent)]
    Bson(#[from] bson::ser::Error),
}

#[derive(thiserror::Error, Debug)]
pub enum CreateTestDataError<'connection> {
    #[error("failed to parse CAC database connection string ({string}): {error}")]
    ConnectionString {
        string: &'connection str,
        error: mongodb::error::Error,
    },
    // For any other generic mongo errors.
    #[error(transparent)]
    Mongo(#[from] mongodb::error::Error),
}

#[derive(thiserror::Error, Debug)]
pub enum DeleteTestDataError<'connection> {
    #[error("failed to parse CAC database connection string ({string}): {error}")]
    ConnectionString {
        string: &'connection str,
        error: mongodb::error::Error,
    },
    // For any other generic mongo errors.
    #[error(transparent)]
    Mongo(#[from] mongodb::error::Error),
}

pub async fn get_next_pending_account(
    connection_string: &str,
) -> Result<Option<Account>, GetAccountError> {
    debug!("Getting next pending account");
    let cac_database_client_options = mongodb::options::ClientOptions::parse(connection_string)
        .await
        .map_err(|e| GetAccountError::ConnectionString {
            string: connection_string,
            error: e,
        })?;

    let cac_database_client = mongodb::Client::with_options(cac_database_client_options)?;
    let cac_database = cac_database_client.database("FusionCAC2");
    let pending_accounts_collection =
        cac_database.collection::<CdiAlertQueueEntry>("CdiAlertQueue");

    let pending_account = pending_accounts_collection
        .find_one_and_delete(
            doc! {},
            FindOneAndDeleteOptions::builder()
                .sort(Some(doc! { "TimeQueued" : 1 }))
                .build(),
        )
        .await?;

    if pending_account.is_some() {
        let id = pending_account.unwrap().id.clone();
        let account = get_account_by_id(connection_string, &id).await?;
        info!("Found pending account: {:?}", &id);
        Ok(account)
    } else {
        info!("No pending accounts found");
        Ok(None)
    }
}

pub async fn get_account_by_id<'connection>(
    connection_string: &'connection str,
    id: &str,
) -> Result<Option<Account>, GetAccountError<'connection>> {
    debug!("Loading account #{:?} from database", id);
    let cac_database_client_options = mongodb::options::ClientOptions::parse(connection_string)
        .await
        .map_err(|e| GetAccountError::ConnectionString {
            string: connection_string,
            error: e,
        })?;

    let cac_database_client = mongodb::Client::with_options(cac_database_client_options)?;
    let cac_database = cac_database_client.database("FusionCAC2");
    let account_collection = cac_database.collection::<Account>("accounts");
    let mut account_cursor = account_collection
        .find(Some(doc! { "_id" : id }), None)
        .await?;

    let account = if !(account_cursor.advance().await?) {
        None
    } else {
        let account = account_cursor.deserialize_current();
        Some(account.unwrap())
    };

    if account.is_none() {
        return Ok(None);
    }

    let mut account = account.unwrap();

    debug!("Checking account #{:?} for external discrete values", id);
    let discrete_values_collection = cac_database.collection::<DiscreteValue>("discreteValues");
    let mut discrete_values_cursor = discrete_values_collection
        .find(Some(doc! { "AccountNumber" : id }), None)
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

pub async fn save_cdi_alerts<'config>(
    config: &'config Config,
    account: &Account,
    cdi_alerts: impl Iterator<Item = &CdiAlert> + Clone,
) -> Result<(), SaveCdiAlertsError<'config>> {
    let connection_string = &config.mongo.url;
    let cac_database_client_options = mongodb::options::ClientOptions::parse(connection_string)
        .await
        .map_err(|e| SaveCdiAlertsError::ConnectionString {
            string: connection_string,
            error: e,
        })?;
    let cac_database_client = mongodb::Client::with_options(cac_database_client_options)?;
    let cac_database = cac_database_client.database("FusionCAC2");
    let account_collection = cac_database.collection::<Account>("accounts");
    let workgroups_collection = cac_database.collection::<WorkGroupCategory>("workgroups");

    let workgroup_category = workgroups_collection
        .find_one(doc! { "_id": config.cdi_workgroup.category.clone() }, None)
        .await?;

    let workgroup_category_object = workgroup_category.unwrap();

    let workgroup_object = workgroup_category_object
        .workgroups
        .iter()
        .find(|x| x.work_group == config.cdi_workgroup.name)
        .unwrap();

    // Find the first criteria group with a script matching a passing alert
    let first_matching_criteria_group =
        workgroup_object
            .criteria_groups
            .iter()
            .find_map(|criteria_group| {
                criteria_group
                    .filters
                    .iter()
                    .find(|filter| {
                        filter.property == "EvaluationScript"
                            && cdi_alerts
                                .clone()
                                .any(|alert| alert.passed && alert.script_name == filter.value)
                    })
                    .map(|_| criteria_group)
            });

    debug!(
        "First matching criteria group: {:?}",
        first_matching_criteria_group
    );

    // Create a bson array from our result iterator.
    // You *could* do this automatically with `bson::to_bson<Vec>`,
    // but this is wasteful because it allocates a vector just to convert it into another vector
    // (`bson::Array` is a typedef for `Vec<Bson>`)
    let mut cdi_alerts_bson = bson::Array::new();
    for i in cdi_alerts {
        if i.passed {
            cdi_alerts_bson.push(bson::to_bson(&i)?);
        }
    }

    // We are going to take care of merge logic entirely in the scripts
    account_collection
        .update_one(
            doc! { "_id": account.id.clone() },
            doc! { "$set": { "CdiAlerts": cdi_alerts_bson } },
            None,
        )
        .await?;

    let new_criteria_group = first_matching_criteria_group.map(|x| x.name.clone());

    // find existing workgroup assignment
    let existing_workgroup_assignment = account.custom_workflow.clone().and_then(|x| {
        x.iter().find_map(|x| match x.work_group.clone() {
            Some(workgroup) => {
                if workgroup == config.cdi_workgroup.name {
                    Some(x.clone())
                } else {
                    None
                }
            }
            None => None,
        })
    });

    // Update or insert workgroup assignment for the category/workgroup
    match existing_workgroup_assignment {
        Some(_) => {
            account_collection
                .update_one(
                    doc! {
                        "_id": account.id.clone(),
                        "CustomWorkflow.WorkGroupCategory": config.cdi_workgroup.name.clone(),
                        "CustomWorkflow.WorkGroup": config.cdi_workgroup.name.clone(),
                    },
                    doc! {
                        "$set": {
                            "CustomWorkflow.$.CriteriaGroup" : new_criteria_group,
                        }
                    },
                    None,
                )
                .await?;
        }
        None => {
            account_collection
                .update_one(
                    doc! {
                        "_id": account.id.clone(),
                    },
                    doc! {
                        "$push": {
                            "CustomWorkflow": {
                                "WorkGroup": config.cdi_workgroup.name.clone(),
                                "CriteriaGroup": new_criteria_group,
                                "CriteriaSequence": 0,
                                "WorkGroupCategory": config.cdi_workgroup.category.clone(),
                                "WorkGroupType": "CDI",
                                "WorkGroupAssignedBy": "CDI",
                                "WorkGroupAssignedDateTime": bson::DateTime::now(),
                            }
                        }
                    },
                    None,
                )
                .await?;
        }
    };

    Ok(())
}

pub async fn create_test_data(config: &Config) -> Result<(), CreateTestDataError> {
    let connection_string = &config.mongo.url;
    let cac_database_client_options = mongodb::options::ClientOptions::parse(connection_string)
        .await
        .map_err(|e| CreateTestDataError::ConnectionString {
            string: connection_string,
            error: e,
        })?;
    let cac_database_client = mongodb::Client::with_options(cac_database_client_options)?;
    let cac_database = cac_database_client.database("FusionCAC2");
    let account_collection = cac_database.collection::<Account>("accounts");
    let cdi_alert_queue_collection = cac_database.collection::<CdiAlertQueueEntry>("CdiAlertQueue");

    // create test account #TEST_CDI_001
    account_collection
        .insert_one(
            Account {
                id: "TEST_CDI_001".to_string(),
                admit_date_time: Some(Utc::now()),
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
                custom_workflow: Some(vec![]),
                hashed_code_references: HashMap::new(),
                hashed_discrete_values: HashMap::new(),
                hashed_medications: HashMap::new(),
                hashed_documents: HashMap::new(),
            },
            None,
        )
        .await?;

    cdi_alert_queue_collection
        .insert_one(
            CdiAlertQueueEntry {
                id: "TEST_CDI_001".to_string(),
                time_queued: Utc::now(),
                account_number: "TEST_CDI_001".to_string(),
                script_name: "test_script_001".to_string(),
            },
            None,
        )
        .await?;

    // create test account #TEST_CDI_002
    /*
    account_collection
        .insert_one(
            Account {
                id: "TEST_CDI_002".to_string(),
                admit_date_time: Some(Utc::now()),
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
                documents: vec![],
                medications: vec![],
                discrete_values: vec![],
                cdi_alerts: vec![],
                custom_workflow: Some(vec![]),
                hashed_code_references: HashMap::new(),
                hashed_discrete_values: HashMap::new(),
                hashed_medications: HashMap::new(),
                hashed_documents: HashMap::new(),
            },
            None,
        )
        .await?;

    cdi_alert_queue_collection
        .insert_one(
            CdiAlertQueueEntry {
                id: "TEST_CDI_002".to_string(),
                time_queued: Utc::now(),
                account_number: "TEST_CDI_002".to_string(),
                script_name: "test_script_002".to_string(),
            },
            None,
        )
        .await?;
    */

    Ok(())
}

pub async fn delete_test_data(config: &Config) -> Result<(), DeleteTestDataError> {
    let connection_string = &config.mongo.url;
    let cac_database_client_options = mongodb::options::ClientOptions::parse(connection_string)
        .await
        .map_err(|e| DeleteTestDataError::ConnectionString {
            string: connection_string,
            error: e,
        })?;
    let cac_database_client = mongodb::Client::with_options(cac_database_client_options)?;
    let cac_database = cac_database_client.database("FusionCAC2");
    let account_collection = cac_database.collection::<Account>("accounts");
    let cdi_alert_queue_collection = cac_database.collection::<CdiAlertQueueEntry>("CdiAlertQueue");

    // delete test account #TEST_CDI_001
    account_collection
        .delete_one(doc! { "_id": "TEST_CDI_001" }, None)
        .await?;

    // delete test account #TEST_CDI_002
    account_collection
        .delete_one(doc! { "_id": "TEST_CDI_002" }, None)
        .await?;

    // delete cdi queue entries for #TEST_CDI_001 and #TEST_CDI_002 if they are still present
    cdi_alert_queue_collection
        .delete_one(doc! { "_id": "TEST_CDI_001" }, None)
        .await?;
    cdi_alert_queue_collection
        .delete_one(doc! { "_id": "TEST_CDI_002" }, None)
        .await?;

    Ok(())
}
