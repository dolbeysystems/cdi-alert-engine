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
--- @field custom_workflow AccountCustomWorkFlowEntry[]? -
--- @method find_code_references(code: string?): CodeReferenceWithDocument[] - Find code references in the account
--- @method find_documents(document_type: string?): Document[] - Find documents in the account
--- @method find_discrete_values(discrete_value_name: string?): DiscreteValue[] - Find discrete values in the account
--- @method find_medications(medication_category: string?): Medication[] - Find medications in the account

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
--- @field passed bool - Whether the alert passed or failed    
--- @field links CdiAlertLink[] - A list of links to display in the alert    
--- @field validated bool - Whether the alert has been validated by a user or autoclosed    
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
--- @field is_validated bool - Whether the link has been validated by a user
--- @field user_notes string? - User notes for the link
--- @field links CdiAlertLink[] - A list of sublinks
--- @field sequence integer - The sequence number of the link
--- @field hidden bool - Whether the link is hidden

