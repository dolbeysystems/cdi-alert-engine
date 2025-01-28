use alua::{ClassAnnotation, UserData};
use bson::doc;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::{Duration, SystemTime};

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
#[serde(rename_all = "PascalCase")]
pub struct Account {
    /// Account number
    #[serde(rename = "_id")]
    pub id: String,
    #[alua(as_lua = "string?")]
    pub admit_date_time: Option<SystemTime>,
    #[alua(as_lua = "string?")]
    pub discharge_date_time: Option<SystemTime>,
    pub patient: Option<Patient>,
    pub patient_type: Option<String>,
    pub admit_source: Option<String>,
    pub admit_type: Option<String>,
    pub hospital_service: Option<String>,
    pub building: Option<String>,
    #[serde(default)]
    pub documents: Vec<CACDocument>,
    #[serde(default)]
    pub medications: Vec<Medication>,
    #[serde(default)]
    pub discrete_values: Vec<DiscreteValue>,
    #[serde(default)]
    pub cdi_alerts: Vec<CdiAlert>,
    #[serde(default)]
    pub working_history: Vec<AccountWorkingHistoryEntry>,

    // These are just caches, do not (de)serialize them.
    #[serde(skip)]
    #[alua(skip)]
    pub hashed_code_references: HashMap<String, Vec<CodeReferenceWithDocument>>,
    #[serde(skip)]
    #[alua(skip)]
    pub hashed_discrete_values: HashMap<String, Vec<DiscreteValue>>,
    #[serde(skip)]
    #[alua(skip)]
    pub hashed_medications: HashMap<String, Vec<Medication>>,
    #[serde(skip)]
    #[alua(skip)]
    pub hashed_documents: HashMap<String, Vec<CACDocument>>,
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
                .cloned()
                .collect::<Vec<String>>())
        });
        methods.add_method("get_unique_discrete_values", |_, this, ()| {
            Ok(this
                .hashed_discrete_values
                .keys()
                .cloned()
                .collect::<Vec<String>>())
        });
        methods.add_method("get_unique_medications", |_, this, ()| {
            Ok(this
                .hashed_medications
                .keys()
                .cloned()
                .collect::<Vec<String>>())
        });
        methods.add_method("get_unique_documents", |_, this, ()| {
            Ok(this
                .hashed_documents
                .keys()
                .cloned()
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
            hashed_values: &mut HashMap<String, Vec<T>>,
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
                .entry(document_type)
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
#[serde(rename_all = "PascalCase")]
pub struct Patient {
    /// Medical record number
    #[serde(rename = "MRN")]
    pub mrn: Option<String>,
    pub first_name: Option<String>,
    pub middle_name: Option<String>,
    pub last_name: Option<String>,
    pub gender: Option<String>,
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
#[serde(rename_all = "PascalCase")]
pub struct CACDocument {
    pub document_id: String,
    pub document_type: Option<String>,
    #[alua(as_lua = "integer?")]
    pub document_date: Option<SystemTime>,
    /// Content type (e.g. html, text, etc.)
    pub content_type: Option<String>,
    /// List of code references on this document
    #[serde(default)]
    pub code_references: Vec<CodeReference>,
    /// List of abstraction references on this document
    #[serde(default)]
    pub abstraction_references: Vec<CodeReference>,
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
#[serde(rename_all = "PascalCase")]
pub struct Medication {
    #[alua(as_lua = "string")]
    pub external_id: String,
    pub medication: Option<String>,
    pub dosage: Option<String>,
    pub route: Option<String>,
    #[alua(as_lua = "integer?")]
    pub start_date: Option<SystemTime>,
    #[alua(as_lua = "integer?")]
    pub end_date: Option<SystemTime>,
    pub status: Option<String>,
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

#[derive(Clone, Debug, Default, Serialize, Deserialize, PartialEq, ClassAnnotation)]
#[serde(rename_all = "PascalCase")]
pub struct DiscreteValue {
    #[alua(as_lua = "string")]
    pub unique_id: String,
    pub name: Option<String>,
    pub result: Option<String>,
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
            this.unique_id = value;
            Ok(())
        });
        setter!(f, name);
        setter!(f, result);
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, ClassAnnotation, UserData)]
#[serde(rename_all = "PascalCase")]
pub struct CodeReference {
    #[alua(as_lua = "string", get)]
    pub code: String,
    #[alua(get)]
    pub value: Option<String>,
    #[alua(get)]
    pub description: Option<String>,
    #[alua(get)]
    pub phrase: Option<String>,
    #[alua(get)]
    pub start: Option<i32>,
    #[alua(get)]
    pub length: Option<i32>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, ClassAnnotation, UserData)]
#[serde(rename_all = "PascalCase")]
pub struct CodeReferenceWithDocument {
    #[alua(get)]
    pub document: CACDocument,
    /// Code
    #[alua(get)]
    pub code_reference: CodeReference,
}

#[derive(
    Clone, Default, Debug, Serialize, Deserialize, PartialEq, ClassAnnotation, mlua::FromLua,
)]
#[serde(rename_all = "PascalCase")]
pub struct CdiAlert {
    /// The name of the script that generated the alert.
    ///
    /// This is the name of the script file without its extension.
    /// See [[script_name]]
    pub script_name: String,
    /// Whether the alert passed or failed    
    pub passed: bool,
    /// A list of links to display in the alert    
    #[serde(default)]
    pub links: Vec<CdiAlertLink>,
    /// Whether the alert has been validated by a user or autoclosed
    pub validated: bool,
    /// A subtitle to display in the alert    
    #[serde(rename = "SubTitle")]
    pub subtitle: Option<String>,
    /// The outcome of the alert    
    pub outcome: Option<String>,
    /// The reason for the alert    
    pub reason: Option<String>,
    /// The weight of the alert    
    pub weight: Option<f64>,
    /// The sequence number of the alert    
    pub sequence: Option<i32>,
}

impl mlua::UserData for CdiAlert {
    fn add_fields<F: mlua::UserDataFields<Self>>(fields: &mut F) {
        getter!(fields, script_name);
        getter!(fields, passed);
        getter!(fields, links);
        getter!(fields, validated);
        getter!(fields, subtitle);
        getter!(fields, outcome);
        getter!(fields, reason);
        getter!(fields, weight);
        getter!(fields, sequence);

        // Notice that script_name is not mutable!!
        setter!(fields, passed);
        setter!(fields, validated);
        setter!(fields, subtitle);
        setter!(fields, outcome);
        setter!(fields, reason);
        setter!(fields, weight);
        setter!(fields, sequence);

        fields.add_field_method_set("links", |_, this, value: mlua::Table| {
            let mut links = Vec::new();

            for x in value.pairs::<String, mlua::AnyUserData>() {
                let (_, value) = x?;

                if let Ok(value) = value.borrow::<CdiAlertLink>() {
                    links.push(value.clone());
                };
            }
            this.links = links;
            Ok(())
        });
    }
}

#[derive(Clone, Default, Debug, Serialize, Deserialize, PartialEq, ClassAnnotation)]
#[serde(rename_all = "PascalCase")]
pub struct CdiAlertLink {
    /// The text to display for the link
    pub link_text: String,
    /// The document id to link to
    pub document_id: Option<String>,
    /// The code to link to
    pub code: Option<String>,
    /// The discrete value id to link to
    pub discrete_value_id: Option<String>,
    /// The discrete value name to link to
    pub discrete_value_name: Option<String>,
    /// The medication id to link to
    pub medication_id: Option<String>,
    /// The medication name to link to
    pub medication_name: Option<String>,
    /// The latest discrete value to link to
    pub latest_discrete_value_id: Option<String>,
    /// Whether the link has been validated by a user
    pub is_validated: bool,
    /// User notes for the link
    pub user_notes: Option<String>,
    /// A list of sublinks
    #[serde(default)]
    pub links: Vec<CdiAlertLink>,
    /// The sequence number of the link
    pub sequence: i32,
    /// Whether the link is hidden
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
                    links.push(value.clone());
                };
            }
            this.links = links;
            Ok(())
        });
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, UserData)]
#[serde(rename_all = "PascalCase")]
pub struct EvaluationQueueEntry {
    #[serde(rename = "_id")]
    pub id: String,
    pub time_queued: SystemTime,
    pub source: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, UserData, ClassAnnotation)]
#[serde(rename_all = "PascalCase")]
pub struct AccountWorkingHistoryEntry {
    pub diagnoses: Vec<DiagnosisCode>,
    pub procedures: Vec<ProcedureCode>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, UserData, ClassAnnotation)]
#[serde(rename_all = "PascalCase")]
pub struct DiagnosisCode {
    pub code: String,
    pub description: String,
    #[serde(rename = "isPrincipal")]
    pub is_principal: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, UserData, ClassAnnotation)]
#[serde(rename_all = "PascalCase")]
pub struct ProcedureCode {
    pub code: String,
    pub description: String,
    #[serde(rename = "isPrincipal")]
    pub is_principal: bool,
}

pub fn script_name(script: &str) -> &str {
    script.rsplit_once('/').map(|x| x.1).unwrap_or(script)
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
