use chrono::{DateTime, Utc};
use mongodb::{bson::doc, options::FindOneAndDeleteOptions};
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

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
    pub patient: Option<Patient>,
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
    #[serde(rename = "Documents")]
    pub documents: Option<Vec<CACDocument>>,
    #[serde(rename = "Medications")]
    pub medications: Option<Vec<Medication>>,
    #[serde(rename = "DiscreteValues")]
    pub discrete_values: Option<Vec<DiscreteValue>>,
    #[serde(rename = "CdiAlerts")]
    pub cdi_alerts: Option<Vec<CdiAlert>>,
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
        // TODO: fields.add_field_method_get("patient", |_, this| Ok(this.patient));
        fields.add_field_method_get("patient_type", |_, this| Ok(this.patient_type.clone()));
        fields.add_field_method_get("admit_source", |_, this| Ok(this.admit_source.clone()));
        fields.add_field_method_get("admit_type", |_, this| Ok(this.admit_type.clone()));
        fields.add_field_method_get("hospital_service", |_, this| {
            Ok(this.hospital_service.clone())
        });
        fields.add_field_method_get("building", |_, this| Ok(this.building.clone()));
        // TODO: fields.add_field_method_get("documents", |_, this| Ok(this.documents));
        // TODO: fields.add_field_method_get("medications", |_, this| Ok(this.medications));
        // TODO: fields.add_field_method_get("discrete_values", |_, this| Ok(this.discrete_values));
        // TODO: fields.add_field_method_get("cdi_alerts", |_, this| Ok(this.cdi_alerts));
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

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct CACDocument {
    #[serde(rename = "DocumentId")]
    pub document_id: Option<String>,
    #[serde(rename = "DocumentType")]
    pub document_type: Option<String>,
    #[serde(rename = "ContentType")]
    pub content_type: Option<String>,
    #[serde(rename = "CodeReferences")]
    pub code_references: Option<Vec<CodeReference>>,
    #[serde(rename = "AbstractionReferences")]
    pub abstraction_references: Option<Vec<CodeReference>>,
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct Medication {
    #[serde(rename = "ExternalId")]
    pub external_id: Option<String>,
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

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct DiscreteValue {
    #[serde(rename = "UniqueId")]
    pub unique_id: Option<String>,
    #[serde(rename = "Name")]
    pub name: Option<String>,
    #[serde(rename = "Result")]
    pub result: Option<String>,
    #[serde(rename = "ResultDate")]
    #[serde_as(as = "Option<bson::DateTime>")]
    pub result_date: Option<DateTime<Utc>>,
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct CodeReference {
    #[serde(rename = "Code")]
    pub code: Option<String>,
    #[serde(rename = "Description")]
    pub description: Option<String>,
    #[serde(rename = "Phrase")]
    pub phrase: Option<String>,
    #[serde(rename = "Start")]
    pub start: Option<i32>,
    #[serde(rename = "Length")]
    pub length: Option<i32>,
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct CdiAlert {
    #[serde(rename = "ScriptName")]
    pub script_name: String,
    #[serde(rename = "Passed")]
    pub passed: bool,
    #[serde(rename = "Links")]
    pub links: Option<Vec<CdiAlertLink>>,
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
}

impl mlua::UserData for CdiAlert {
    fn add_fields<'lua, F: mlua::UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_field_method_get("script_name", |_, this| Ok(this.script_name.clone()));
        fields.add_field_method_get("passed", |_, this| Ok(this.passed));
        // TODO: fields.add_field_method_get("links", |_, this| Ok(this.links));
        fields.add_field_method_get("validated", |_, this| Ok(this.validated));
        fields.add_field_method_get("subtitle", |_, this| Ok(this.subtitle.clone()));
        fields.add_field_method_get("outcome", |_, this| Ok(this.outcome.clone()));
        fields.add_field_method_get("reason", |_, this| Ok(this.reason.clone()));
        fields.add_field_method_get("weight", |_, this| Ok(this.weight));
    }
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
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
    #[serde(rename = "Links")]
    pub links: Option<Vec<CdiAlertLink>>,
    #[serde(rename = "Sequence")]
    pub sequence: i32,
    #[serde(rename = "Hidden")]
    pub hidden: bool,
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct CdiAlertQueueEntry {
    #[serde(rename = "_id")]
    pub id: String,
    #[serde(rename = "TimeQueued")]
    #[serde_as(as = "bson::DateTime")]
    pub time_queued: DateTime<Utc>,
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

pub async fn get_next_pending_account(
    connection_string: &str,
) -> Result<Option<Account>, GetAccountError> {
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
        let account = get_account_by_id(connection_string, &pending_account.unwrap().id).await?;
        Ok(account)
    } else {
        Ok(None)
    }
}

pub async fn get_account_by_id<'connection>(
    connection_string: &'connection str,
    id: &str,
) -> Result<Option<Account>, GetAccountError<'connection>> {
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

    let discrete_values_collection = cac_database.collection::<DiscreteValue>("discreteValues");
    let mut discrete_values_cursor = discrete_values_collection
        .find(Some(doc! { "AccountNumber" : id }), None)
        .await?;

    let mut external_discrete_values = Vec::<DiscreteValue>::new();
    while discrete_values_cursor.advance().await? {
        let discrete_value = discrete_values_cursor.deserialize_current()?;
        external_discrete_values.push(discrete_value);
    }

    if external_discrete_values.is_empty() {
        Ok(Some(account))
    } else {
        match account.discrete_values {
            Some(ref mut discrete_values) => {
                discrete_values.append(&mut external_discrete_values);
            }
            None => {
                account.discrete_values = Some(external_discrete_values);
            }
        }
        Ok(Some(account))
    }
}
