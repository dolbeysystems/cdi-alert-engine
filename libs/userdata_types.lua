--- @class Account
--- @field id string - Account number
--- @field admit_date_time string? -
--- @field discharge_date_time string? -
--- @field patient Patient? -
--- @field patient_type string? -
--- @field admit_source string? -
--- @field admit_type string? -
--- @field hospital_service string? -
--- @field building string? -
--- @field documents CACDocument[] - List of documents
--- @field medications Medication[] - List of medications
--- @field discrete_values DiscreteValue[] - List of discrete values
--- @field cdi_alerts CdiAlert[] - List of cdi alerts
--- @field working_history AccountWorkingHistoryEntry[] -
--- @field find_code_references fun(self: Account, code: string?): CodeReferenceWithDocument[] - Find code references in the account
--- @field find_documents fun(self: Account, document_type: string?): CACDocument[] - Find documents in the account
--- @field find_discrete_values fun(self: Account, discrete_value_name: string?): DiscreteValue[] - Find discrete values in the account
--- @field find_medications fun(self: Account, medication_category: string?): Medication[] - Find medications in the account
--- @field get_unique_code_references fun(self: Account): string[] - Return all code reference keys in the account
--- @field get_unique_documents fun(self: Account): string[] - Return all document keys in the account
--- @field get_unique_discrete_values fun(self: Account): string[] - Return all discrete value keys in the account
--- @field get_unique_medications fun(self: Account): string[] - Return all medication keys in the account
--- @field is_diagnosis_code_in_working_history fun(self: Account, code: string): boolean - Check if a diagnosis code is in the working history
--- @field is_procedure_code_in_working_history fun(self: Account, code: string): boolean - Check if a procedure code is in the working history

--- @class Patient
--- @field mrn string? - Medical record number
--- @field first_name string? -
--- @field middle_name string? -
--- @field last_name string? -
--- @field gender string? -
--- @field birthdate string? -

--- @class CACDocument
--- @field document_id string -
--- @field document_type string? -
--- @field document_date string? -
--- @field content_type string? - Content type (e.g. html, text, etc.)
--- @field code_references CodeReference[] - List of code references on this document
--- @field abstraction_references CodeReference[] - List of abstraction references on this document

--- @class CodeReference
--- @field code string -
--- @field value string? -
--- @field description string? -
--- @field phrase string? -
--- @field start integer? -
--- @field length integer? -

--- @class CodeReferenceWithDocument
--- @field document CACDocument -
--- @field code_reference CodeReference - Code

--- @class Medication
--- @field external_id string -
--- @field medication string? -
--- @field dosage string? -
--- @field route string? -
--- @field start_date string? -
--- @field end_date string? -
--- @field status string? -
--- @field category string? -
--- @field cdi_alert_category string? -

--- @class DiscreteValue
--- @field unique_id string -
--- @field name string? -
--- @field result string? -
--- @field result_date string? -

--- @class AccountCustomWorkFlowEntry
--- @field work_group string? -
--- @field criteria_group string? -
--- @field criteria_sequence integer? -
--- @field work_group_category string? -
--- @field work_group_type string? -
--- @field work_group_assigned_by string? - Name of the user who assigned the work group
--- @field work_group_date_time string? - Date time the work group was assigned

--- @class CdiAlert
--- @field script_name string - The name of the script that generated the alert    
--- @field passed boolean - Whether the alert passed or failed    
--- @field links CdiAlertLink[] - A list of links to display in the alert    
--- @field validated boolean - Whether the alert has been validated by a user or autoclosed
--- @field subtitle string? - A subtitle to display in the alert    
--- @field outcome string? - The outcome of the alert    
--- @field reason string? - The reason for the alert    
--- @field weight number? - The weight of the alert    
--- @field sequence integer? - The sequence number of the alert    

--- @class CdiAlertLink
--- @field link_text string - The text to display for the link
--- @field document_id string? - The document id to link to
--- @field code string? - The code to link to
--- @field discrete_value_id string? - The discrete value id to link to
--- @field discrete_value_name string? - The discrete value name to link to
--- @field medication_id string? - The medication id to link to
--- @field medication_name string? - The medication name to link to
--- @field latest_discrete_value_id string? - The latest discrete value to link to
--- @field is_validated boolean - Whether the link has been validated by a user
--- @field user_notes string? - User notes for the link
--- @field links CdiAlertLink[] - A list of sublinks
--- @field sequence integer - The sequence number of the link
--- @field hidden boolean - Whether the link is hidden

--- @class AccountWorkingHistoryEntry
--- @field diagnoses DiagnosisCode[] -
--- @field procedures ProcedureCode[] -

--- @class DiagnosisCode
--- @field code string -
--- @field description string -
--- @field is_principal boolean -

--- @class ProcedureCode
--- @field code string -
--- @field description string -
--- @field is_principal boolean -

