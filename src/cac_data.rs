//! This module should be exclusively for database types that are shared
//! between all scripting engines.
//! Any engine-specific functionality should be placed in seperate,
//! self-contained modules.

use alua::{ClassAnnotation, UserData};
use chrono::{DateTime, Utc};
use mongodb::bson::doc;
use serde::{Deserialize, Serialize};
use serde_with::serde_as;
use std::{collections::HashMap, sync::Arc};

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
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, ClassAnnotation)]
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
    /// Name of the user who assigned the work group
    #[serde(rename = "WorkGroupAssignedBy")]
    pub work_group_assigned_by: Option<String>,
    /// Date time the work group was assigned
    #[serde(rename = "WorkGroupAssignedDateTime")]
    #[serde_as(as = "Option<bson::DateTime>")]
    #[alua(as_lua = "string?")]
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
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, ClassAnnotation, UserData)]
pub struct CodeReferenceWithDocument {
    #[serde(rename = "document")]
    #[alua(get)]
    pub document: Arc<CACDocument>,
    /// Code
    #[serde(rename = "code_reference")]
    #[alua(get)]
    pub code_reference: Arc<CodeReference>,
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, ClassAnnotation)]
#[alua(fields = [
    "find_code_references fun(self: Account, code: string?): CodeReferenceWithDocument[] - Find code references in the account",
    "find_documents fun(self: Account, document_type: string?): CACDocument[] - Find documents in the account",
    "find_discrete_values fun(self: Account, discrete_value_name: string?): DiscreteValue[] - Find discrete values in the account",
    "find_medications fun(self: Account, medication_category: string?): Medication[] - Find medications in the account",

    "get_unique_code_references fun(self: Account): string[] - Return all code reference keys in the account",
    "get_unique_documents fun(self: Account): string[] - Return all document keys in the account",
    "get_unique_discrete_values fun(self: Account): string[] - Return all discrete value keys in the account",
    "get_unique_medications fun(self: Account): string[] - Return all medication keys in the account",
])]
pub struct Account {
    /// Account number
    #[serde(rename = "_id")]
    pub id: String,
    #[serde(rename = "AdmitDateTime")]
    #[serde_as(as = "Option<bson::DateTime>")]
    #[alua(as_lua = "string?")]
    pub admit_date_time: Option<DateTime<Utc>>,
    #[serde(rename = "DischargeDateTime")]
    #[serde_as(as = "Option<bson::DateTime>")]
    #[alua(as_lua = "string?")]
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
    /// List of documents
    #[serde(rename = "Documents", default)]
    pub documents: Vec<Arc<CACDocument>>,
    /// List of medications
    #[serde(rename = "Medications", default)]
    pub medications: Vec<Arc<Medication>>,
    /// List of discrete values
    #[serde(rename = "DiscreteValues", default)]
    pub discrete_values: Vec<Arc<DiscreteValue>>,
    /// List of cdi alerts
    #[serde(rename = "CdiAlerts", default)]
    pub cdi_alerts: Vec<Arc<CdiAlert>>,

    // These are just caches, do not (de)serialize them.
    #[serde(skip)]
    #[alua(skip)]
    pub hashed_code_references: HashMap<Arc<str>, Vec<CodeReferenceWithDocument>>,
    #[serde(skip)]
    #[alua(skip)]
    pub hashed_discrete_values: HashMap<Arc<str>, Vec<Arc<DiscreteValue>>>,
    #[serde(skip)]
    #[alua(skip)]
    pub hashed_medications: HashMap<Arc<str>, Vec<Arc<Medication>>>,
    #[serde(skip)]
    #[alua(skip)]
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
                Ok(code_references.clone())
            } else {
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
        methods.add_method("get_unique_code_references", |_, this, ()| {
            Ok(this
                .hashed_code_references
                .keys()
                // Arc<str> is better for Rust, but Lua only understands String.
                .map(|x| x.to_string())
                .collect::<Vec<String>>())
        });
        methods.add_method("get_unique_discrete_values", |_, this, ()| {
            Ok(this
                .hashed_discrete_values
                .keys()
                // Arc<str> is better for Rust, but Lua only understands String.
                .map(|x| x.to_string())
                .collect::<Vec<String>>())
        });
        methods.add_method("get_unique_medications", |_, this, ()| {
            Ok(this
                .hashed_medications
                .keys()
                // Arc<str> is better for Rust, but Lua only understands String.
                .map(|x| x.to_string())
                .collect::<Vec<String>>())
        });
        methods.add_method("get_unique_documents", |_, this, ()| {
            Ok(this
                .hashed_documents
                .keys()
                // Arc<str> is better for Rust, but Lua only understands String.
                .map(|x| x.to_string())
                .collect::<Vec<String>>())
        });
    }
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, ClassAnnotation, UserData)]
pub struct Patient {
    /// Medical record number
    #[serde(rename = "MRN")]
    #[alua(get)]
    pub mrn: Option<String>,
    #[serde(rename = "FirstName")]
    #[alua(get)]
    pub first_name: Option<String>,
    #[serde(rename = "MiddleName")]
    #[alua(get)]
    pub middle_name: Option<String>,
    #[serde(rename = "LastName")]
    #[alua(get)]
    pub last_name: Option<String>,
    #[serde(rename = "Gender")]
    #[alua(get)]
    pub gender: Option<String>,
    #[serde(rename = "BirthDate")]
    #[serde_as(as = "Option<bson::DateTime>")]
    #[alua(as_lua = "string?", get)]
    pub birthdate: Option<DateTime<Utc>>,
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, ClassAnnotation, UserData)]
pub struct CACDocument {
    #[serde(rename = "DocumentId")]
    #[alua(as_lua = "string", get)]
    pub document_id: Arc<str>,
    #[serde(rename = "DocumentType")]
    pub document_type: Option<String>,
    #[serde(rename = "DocumentDate")]
    #[serde_as(as = "Option<bson::DateTime>")]
    #[alua(as_lua = "string?", get)]
    pub document_date: Option<DateTime<Utc>>,
    /// Content type (e.g. html, text, etc.)
    #[serde(rename = "ContentType")]
    #[alua(get)]
    pub content_type: Option<String>,
    /// List of code references on this document
    #[serde(rename = "CodeReferences", default)]
    #[alua(get)]
    pub code_references: Vec<Arc<CodeReference>>,
    /// List of abstraction references on this document
    #[serde(rename = "AbstractionReferences", default)]
    #[alua(get)]
    pub abstraction_references: Vec<Arc<CodeReference>>,
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, ClassAnnotation, UserData)]
pub struct Medication {
    #[serde(rename = "ExternalId")]
    #[alua(as_lua = "string", get)]
    pub external_id: Arc<str>,
    #[serde(rename = "Medication")]
    #[alua(get)]
    pub medication: Option<String>,
    #[serde(rename = "Dosage")]
    #[alua(get)]
    pub dosage: Option<String>,
    #[serde(rename = "Route")]
    #[alua(get)]
    pub route: Option<String>,
    #[serde(rename = "StartDate")]
    #[serde_as(as = "Option<bson::DateTime>")]
    #[alua(as_lua = "string?", get)]
    pub start_date: Option<DateTime<Utc>>,
    #[serde(rename = "EndDate")]
    #[serde_as(as = "Option<bson::DateTime>")]
    #[alua(as_lua = "string?", get)]
    pub end_date: Option<DateTime<Utc>>,
    #[serde(rename = "Status")]
    #[alua(get)]
    pub status: Option<String>,
    #[serde(rename = "Category")]
    #[alua(get)]
    pub category: Option<String>,
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, ClassAnnotation)]
pub struct DiscreteValue {
    #[serde(rename = "UniqueId")]
    #[alua(as_lua = "string")]
    pub unique_id: Arc<str>,
    #[serde(rename = "Name")]
    pub name: Option<String>,
    #[serde(rename = "Result")]
    pub result: Option<String>,
    #[serde(rename = "ResultDate")]
    #[serde_as(as = "Option<bson::DateTime>")]
    #[alua(as_lua = "string?")]
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
    fn add_fields<'lua, F: mlua::UserDataFields<'lua, Self>>(f: &mut F) {
        f.add_field_method_get("unique_id", |_, this| Ok(this.unique_id.to_string()));
        getter!(f, name);
        getter!(f, result);
        f.add_field_method_get("result_date", |_, this| {
            Ok(this.result_date.map(|x| x.to_string()))
        });

        f.add_field_method_set("unique_id", |_, this, value: String| {
            this.unique_id = value.into();
            Ok(())
        });
        setter!(f, name);
        setter!(f, result);
    }
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, ClassAnnotation, UserData)]
pub struct CodeReference {
    #[serde(rename = "Code")]
    #[alua(as_lua = "string", get)]
    pub code: Arc<str>,
    #[serde(rename = "Value")]
    #[alua(get)]
    pub value: Option<String>,
    #[serde(rename = "Description")]
    #[alua(get)]
    pub description: Option<String>,
    #[serde(rename = "Phrase")]
    #[alua(get)]
    pub phrase: Option<String>,
    #[serde(rename = "Start")]
    #[alua(get)]
    pub start: Option<i32>,
    #[serde(rename = "Length")]
    #[alua(get)]
    pub length: Option<i32>,
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, ClassAnnotation)]
pub struct CdiAlert {
    /// The name of the script that generated the alert    
    #[serde(rename = "ScriptName")]
    pub script_name: String,
    /// Whether the alert passed or failed    
    #[serde(rename = "Passed")]
    pub passed: bool,
    /// A list of links to display in the alert    
    #[serde(rename = "Links", default)]
    pub links: Vec<Arc<CdiAlertLink>>,
    /// Whether the alert has been validated by a user or autoclosed
    #[serde(rename = "Validated")]
    pub validated: bool,
    /// A subtitle to display in the alert    
    #[serde(rename = "SubTitle")]
    pub subtitle: Option<String>,
    /// The outcome of the alert    
    #[serde(rename = "Outcome")]
    pub outcome: Option<String>,
    /// The reason for the alert    
    #[serde(rename = "Reason")]
    pub reason: Option<String>,
    /// The weight of the alert    
    #[serde(rename = "Weight")]
    pub weight: Option<f64>,
    /// The sequence number of the alert    
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
        fields.add_field_method_set("links", |_, this, value: mlua::Table| {
            let mut links = Vec::new();

            for x in value.pairs::<String, mlua::AnyUserData>() {
                let (_, value) = x?;

                if let Ok(value) = value.borrow::<CdiAlertLink>() {
                    links.push(Arc::new(value.clone()));
                };
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
        fields.add_field_method_set("sequence", |_, this, value| {
            this.weight = value;
            Ok(())
        });
    }
}

#[serde_as]
#[derive(Clone, Default, Debug, Serialize, Deserialize, PartialEq, ClassAnnotation)]
pub struct CdiAlertLink {
    /// The text to display for the link
    #[serde(rename = "LinkText")]
    pub link_text: String,
    /// The document id to link to
    #[serde(rename = "DocumentId")]
    pub document_id: Option<String>,
    /// The code to link to
    #[serde(rename = "Code")]
    pub code: Option<String>,
    /// The discrete value id to link to
    #[serde(rename = "DiscreteValueId")]
    pub discrete_value_id: Option<String>,
    /// The discrete value name to link to
    #[serde(rename = "DiscreteValueName")]
    pub discrete_value_name: Option<String>,
    /// The medication id to link to
    #[serde(rename = "MedicationId")]
    pub medication_id: Option<String>,
    /// The medication name to link to
    #[serde(rename = "MedicationName")]
    pub medication_name: Option<String>,
    /// The latest discrete value to link to
    #[serde(rename = "LatestDiscreteValueId")]
    pub latest_discrete_value_id: Option<String>,
    /// Whether the link has been validated by a user
    #[serde(rename = "IsValidated")]
    pub is_validated: bool,
    /// User notes for the link
    #[serde(rename = "UserNotes")]
    pub user_notes: Option<String>,
    /// A list of sublinks
    #[serde(rename = "Links", default)]
    pub links: Vec<Arc<CdiAlertLink>>,
    /// The sequence number of the link
    #[serde(rename = "Sequence")]
    pub sequence: i32,
    /// Whether the link is hidden
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
        f.add_field_method_set("links", |_, this, value: mlua::Table| {
            let mut links = Vec::new();

            for x in value.pairs::<String, mlua::AnyUserData>() {
                let (_, value) = x?;

                if let Ok(value) = value.borrow::<CdiAlertLink>() {
                    links.push(Arc::new(value.clone()));
                };
            }
            this.links = links;
            Ok(())
        });
    }
}

#[serde_as]
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct EvaluationQueueEntry {
    #[serde(rename = "_id")]
    pub id: String,
    #[serde(rename = "TimeQueued")]
    #[serde_as(as = "bson::DateTime")]
    pub time_queued: DateTime<Utc>,
    #[serde(rename = "Source")]
    pub source: String,
}
