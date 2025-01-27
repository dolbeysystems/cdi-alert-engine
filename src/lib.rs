use alua::{ClassAnnotation, UserData};
use bson::doc;
use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    sync::Arc,
    time::{Duration, SystemTime},
};

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

fn system_time_t(time: SystemTime) -> u64 {
    time.duration_since(SystemTime::UNIX_EPOCH)
        .unwrap()
        .as_secs()
}

// To avoid excessive cloning, wrap `UserData` in `Arc`s!

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
    #[alua(as_lua = "string?")]
    pub work_group_date_time: Option<SystemTime>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct WorkGroupCategory {
    #[serde(rename = "_id")]
    pub id: Arc<str>,
    #[serde(rename = "WorkGroups")]
    pub workgroups: Vec<WorkGroup>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct WorkGroup {
    #[serde(rename = "WorkGroup")]
    pub work_group: String,
    #[serde(rename = "CriteriaGroups")]
    pub criteria_groups: Vec<CriteriaGroup>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct CriteriaGroup {
    #[serde(rename = "Name")]
    pub name: String,
    #[serde(rename = "Filters")]
    pub filters: Vec<CriteriaFilter>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct CriteriaFilter {
    #[serde(rename = "Property")]
    pub property: String,
    #[serde(rename = "Operator")]
    pub operator: String,
    #[serde(rename = "Value")]
    pub value: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, ClassAnnotation, UserData)]
pub struct CodeReferenceWithDocument {
    #[alua(get)]
    pub document: Arc<CACDocument>,
    /// Code
    #[alua(get)]
    pub code_reference: Arc<CodeReference>,
}

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
    "is_diagnosis_code_in_working_history fun(self: Account, code: string): boolean - Check if a diagnosis code is in the working history",
    "is_procedure_code_in_working_history fun(self: Account, code: string): boolean - Check if a procedure code is in the working history",
])]
pub struct Account {
    /// Account number
    #[serde(rename = "_id")]
    pub id: String,
    #[serde(rename = "AdmitDateTime")]
    #[alua(as_lua = "string?")]
    pub admit_date_time: Option<SystemTime>,
    #[serde(rename = "DischargeDateTime")]
    #[alua(as_lua = "string?")]
    pub discharge_date_time: Option<SystemTime>,
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
    // List of working history entries
    #[serde(rename = "WorkingHistory", default)]
    pub working_history: Vec<Arc<AccountWorkingHistoryEntry>>,

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
    fn add_fields<F: mlua::UserDataFields<Self>>(fields: &mut F) {
        fields.add_field_method_get("id", |_, this| Ok(this.id.clone()));
        fields.add_field_method_get("admit_date_time", |_, this| {
            Ok(this.admit_date_time.map(system_time_t))
        });
        fields.add_field_method_get("discharge_date_time", |_, this| {
            Ok(this.discharge_date_time.map(system_time_t))
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
        fields.add_field_method_get("working_history", |_, this| {
            Ok(this.working_history.clone())
        });
    }

    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
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
        methods.add_method(
            "is_diagnosis_code_in_working_history",
            |_, this, code: String| {
                Ok(this
                    .working_history
                    .iter()
                    .any(|x| x.diagnoses.iter().any(|y| y.code == code)))
            },
        );

        methods.add_method(
            "is_procedure_code_in_working_history",
            |_, this, code: String| {
                Ok(this
                    .working_history
                    .iter()
                    .any(|x| x.procedures.iter().any(|y| y.code == code)))
            },
        );
    }
}

impl Account {
    pub fn build_caches(&mut self, dv_days_back: u32, med_days_back: u32) {
        fn cache_by_date<'a, T: Clone + 'a>(
            get_date: impl Fn(&T) -> SystemTime,
            mut root_values: impl Iterator<Item = (&'a str, &'a T)> + Clone,
            hashed_values: &mut HashMap<Arc<str>, Vec<T>>,
        ) {
            while let Some((key, discrete_value)) = root_values.next() {
                if hashed_values.contains_key(key) {
                    continue;
                }
                // capture the current state of the root values iterator
                // (past entries will never be useful)
                let mut keyed_values = Some(discrete_value)
                    .into_iter()
                    .chain(root_values.clone().filter(|x| x.0 == key).map(|x| x.1))
                    .cloned()
                    .collect::<Vec<_>>();
                keyed_values.sort_by_key(|a| std::cmp::Reverse(get_date(a)));
                hashed_values.insert(key.into(), keyed_values);
            }
        }

        let oldest_allowed =
            SystemTime::now() - Duration::from_secs(dv_days_back as u64 * 24 * 60 * 60);
        let root_discrete_values = self
            .discrete_values
            .iter()
            .filter(|x| x.result_date.is_some_and(|x| x >= oldest_allowed))
            .filter_map(|x| x.name.as_deref().zip(Some(x)));
        cache_by_date(
            |x| x.result_date.unwrap(),
            root_discrete_values,
            &mut self.hashed_discrete_values,
        );
        let oldest_allowed =
            SystemTime::now() - Duration::from_secs(med_days_back as u64 * 24 * 60 * 60);
        let root_medications = self
            .medications
            .iter()
            .filter(|x| x.start_date.is_some_and(|x| x >= oldest_allowed))
            .filter_map(|x| x.category.as_deref().zip(Some(x)));
        cache_by_date(
            |x| x.start_date.unwrap(),
            root_medications,
            &mut self.hashed_medications,
        );

        for document in self.documents.iter() {
            let document_type = document.document_type.clone().unwrap_or("".to_string());
            self.hashed_documents
                .entry(document_type.into())
                .or_default()
                .push(document.clone());

            for code_reference in document.code_references.iter() {
                let code_reference = code_reference.clone();
                self.hashed_code_references
                    .entry(code_reference.code.clone())
                    .or_default()
                    .push(CodeReferenceWithDocument {
                        document: document.clone(),
                        code_reference: code_reference.clone(),
                    });
            }
            for code_reference in document.abstraction_references.iter() {
                self.hashed_code_references
                    .entry(code_reference.code.clone())
                    .or_default()
                    .push(CodeReferenceWithDocument {
                        document: document.clone(),
                        code_reference: code_reference.clone(),
                    });
            }
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, ClassAnnotation)]
pub struct Patient {
    /// Medical record number
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
    #[alua(as_lua = "integer?")]
    pub birthdate: Option<SystemTime>,
}

impl mlua::UserData for Patient {
    fn add_fields<F: mlua::UserDataFields<Self>>(fields: &mut F) {
        getter!(fields, mrn);
        getter!(fields, first_name);
        getter!(fields, middle_name);
        getter!(fields, last_name);
        getter!(fields, gender);
        fields.add_field_method_get("birthdate", |_, this| Ok(this.birthdate.map(system_time_t)));
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, ClassAnnotation)]
pub struct CACDocument {
    #[serde(rename = "DocumentId")]
    #[alua(as_lua = "string", get)]
    pub document_id: Arc<str>,
    #[serde(rename = "DocumentType")]
    pub document_type: Option<String>,
    #[serde(rename = "DocumentDate")]
    #[alua(as_lua = "integer?")]
    pub document_date: Option<SystemTime>,
    /// Content type (e.g. html, text, etc.)
    #[serde(rename = "ContentType")]
    pub content_type: Option<String>,
    /// List of code references on this document
    #[serde(rename = "CodeReferences", default)]
    pub code_references: Vec<Arc<CodeReference>>,
    /// List of abstraction references on this document
    #[serde(rename = "AbstractionReferences", default)]
    pub abstraction_references: Vec<Arc<CodeReference>>,
}

impl mlua::UserData for CACDocument {
    fn add_fields<F: mlua::UserDataFields<Self>>(fields: &mut F) {
        fields.add_field_method_get("document_id", |_, this| Ok(this.document_id.to_string()));
        getter!(fields, document_type);
        fields.add_field_method_get("document_date", |_, this| {
            Ok(this.document_date.map(system_time_t))
        });
        getter!(fields, content_type);
        getter!(fields, code_references);
        getter!(fields, abstraction_references);
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, ClassAnnotation)]
pub struct Medication {
    #[serde(rename = "ExternalId")]
    #[alua(as_lua = "string")]
    pub external_id: Arc<str>,
    #[serde(rename = "Medication")]
    pub medication: Option<String>,
    #[serde(rename = "Dosage")]
    pub dosage: Option<String>,
    #[serde(rename = "Route")]
    pub route: Option<String>,
    #[serde(rename = "StartDate")]
    #[alua(as_lua = "integer?")]
    pub start_date: Option<SystemTime>,
    #[serde(rename = "EndDate")]
    #[alua(as_lua = "integer?")]
    pub end_date: Option<SystemTime>,
    #[serde(rename = "Status")]
    pub status: Option<String>,
    #[serde(rename = "Category")]
    pub category: Option<String>,
    #[serde(rename = "CDIAlertCategory")]
    pub cdi_alert_category: Option<String>,
}

impl mlua::UserData for Medication {
    fn add_fields<F: mlua::UserDataFields<Self>>(fields: &mut F) {
        fields.add_field_method_get("external_id", |_, this| Ok(this.external_id.to_string()));
        getter!(fields, medication);
        getter!(fields, dosage);
        getter!(fields, route);
        fields.add_field_method_get("start_date", |_, this| {
            Ok(this.start_date.map(system_time_t))
        });
        fields.add_field_method_get("end_date", |_, this| Ok(this.end_date.map(system_time_t)));
        getter!(fields, status);
        getter!(fields, category);
        getter!(fields, cdi_alert_category);
    }
}

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
    #[alua(as_lua = "integer?")]
    pub result_date: Option<SystemTime>,
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
    fn add_fields<F: mlua::UserDataFields<Self>>(f: &mut F) {
        f.add_field_method_get("unique_id", |_, this| Ok(this.unique_id.to_string()));
        getter!(f, name);
        getter!(f, result);
        f.add_field_method_get("result_date", |_, this| {
            Ok(this.result_date.map(system_time_t))
        });

        f.add_field_method_set("unique_id", |_, this, value: String| {
            this.unique_id = value.into();
            Ok(())
        });
        setter!(f, name);
        setter!(f, result);
    }
}

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

#[derive(
    Clone, Default, Debug, Serialize, Deserialize, PartialEq, ClassAnnotation, mlua::FromLua,
)]
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
    fn add_fields<F: mlua::UserDataFields<Self>>(fields: &mut F) {
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
    fn add_fields<F: mlua::UserDataFields<Self>>(f: &mut F) {
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

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, UserData)]
pub struct EvaluationQueueEntry {
    #[serde(rename = "_id")]
    pub id: String,
    #[serde(rename = "TimeQueued")]
    pub time_queued: SystemTime,
    #[serde(rename = "Source")]
    pub source: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, UserData, ClassAnnotation)]
pub struct AccountWorkingHistoryEntry {
    #[serde(rename = "Diagnoses")]
    pub diagnoses: Vec<DiagnosisCode>,
    #[serde(rename = "Procedures")]
    pub procedures: Vec<ProcedureCode>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, UserData, ClassAnnotation)]
pub struct DiagnosisCode {
    #[serde(rename = "Code")]
    pub code: String,
    #[serde(rename = "Description")]
    pub description: String,
    #[serde(rename = "isPrincipal")]
    pub is_principal: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, UserData, ClassAnnotation)]
pub struct ProcedureCode {
    #[serde(rename = "Code")]
    pub code: String,
    #[serde(rename = "Description")]
    pub description: String,
    #[serde(rename = "isPrincipal")]
    pub is_principal: bool,
}

pub fn lua_lib(lua: &mlua::Lua) -> mlua::Result<()> {
    let log = lua.create_table()?;

    macro_rules! register_logging {
        ($type:ident) => {
            log.set(
                stringify!($type),
                lua.create_function(|_, s: mlua::String| {
                    tracing::$type!("{}", s.to_str()?.as_ref());
                    Ok(())
                })?,
            )?;
        };
    }

    register_logging!(error);
    register_logging!(warn);
    register_logging!(info);
    register_logging!(debug);

    lua.load_from_function::<mlua::Value>(
        "cdi.log",
        lua.create_function(move |_, ()| Ok(log.clone()))?,
    )?;
    lua.load_from_function::<mlua::Value>(
        "cdi.link",
        lua.create_function(move |lua, ()| {
            lua.create_function(|_, ()| Ok(CdiAlertLink::default()))
        })?,
    )?;
    lua.load_from_function::<mlua::Value>(
        "cdi.discrete_value",
        lua.create_function(move |lua, ()| {
            lua.create_function(|_, (id, name): (String, _)| Ok(DiscreteValue::new(&id, name)))
        })?,
    )?;

    Ok(())
}
