---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Atrial Fibrillation
---
--- This script checks an account to see if it matches the criteria for an atrial fibrillation alert.
---
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
---------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Requires
--------------------------------------------------------------------------------
local alerts = require("libs.common.alerts")(Account)
local links = require("libs.common.basic_links")(Account)
local codes = require("libs.common.codes")(Account)
local discrete = require("libs.common.discrete_values")(Account)
local headers = require("libs.common.headers")(Account)
local lists = require("libs.common.lists")



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local dv_heart_rate = {
    "Heart Rate cc (bpm)",
    "3.5 Heart Rate (Apical) (bpm)",
    "3.5 Heart Rate (Other) (bpm)",
    "3.5 Heart Rate (Radial) (bpm)",
    "SCC Monitor Pulse (bpm)"
}
local high_heart_rate_predicate = discrete.make_gt_predicate(90)
local map_dv_names = { "Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)" }
local low_map_predicate = discrete.make_lt_predicate(70)
local systolic_blood_pressure_dv_names = { "SBP 3.5 (No Calculation) (mm Hg)" }
local low_systolic_blood_pressure_predicate = discrete.make_lt_predicate(90)



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = Result.script_name }
local subtitle = existing_alert ~= nil and existing_alert.subtitle

--------------------------------------------------------------------------------
--- Initial Qualification Link Collection
--------------------------------------------------------------------------------
local i4891_code_link = codes.make_code_link("I48.91", "Unspecified Atrial Fibrillation Dx Present")
local i480_code_link = codes.make_code_link("I48.0", "Paroxysmal Atrial Fibrillation")
local i4819_code_link = codes.make_code_link("I48.19", "Other Persistent Atrial Fibrillation")
local i4820_code_link = codes.make_code_link("I48.20", "Chronic Atrial Fibrillation")
local i4821_code_link = codes.make_code_link("I48.21", "Permanent Atrial Fibrillation")

if
    not (existing_alert and existing_alert.validated) or
    (i480_code_link and lists.some { i4819_code_link, i4820_code_link, i4821_code_link })
then
    --------------------------------------------------------------------------------
    --- Header Variables and Helper Functions
    --------------------------------------------------------------------------------
    local result_links = {}
    local documented_dx_header = headers.make_header_builder("Documented Dx", 1)
    local vital_signs_intake_header = headers.make_header_builder("Vital Signs/Intake", 2)
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 3)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 4)
    local ekg_header = headers.make_header_builder("EKG", 5)

    local function compile_links()
        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, vital_signs_intake_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))
        table.insert(result_links, ekg_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end



    --------------------------------------------------------------------------------
    --- Alert Variables
    --------------------------------------------------------------------------------
    local alert_code_dictionary = {
        ["I48.0"] = "Paroxysmal Atrial Fibrillation",
        ["I48.11"] = "Longstanding Persistent Atrial Fibrillation",
        ["I48.19"] = "Other Persistent Atrial Fibrillation",
        ["I48.21"] = "Permanent Atrial Fibrillation",
        ["I48.20"] = "Chronic Atrial Fibrillation"
    }
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    -- Alert Conflicting Atrial Fibrillation Dx
    if i480_code_link and lists.some { i4819_code_link, i4820_code_link, i4821_code_link } then
        documented_dx_header:add_link(i480_code_link)
        documented_dx_header:add_link(i4819_code_link)
        documented_dx_header:add_link(i4820_code_link)
        documented_dx_header:add_link(i4821_code_link)
        Result.subtitle = "Conflicting Atrial Fibrillation Dx"
        Result.passed = true

        if existing_alert and existing_alert.validated then
            Result.validated = false
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
        end
    elseif subtitle == "Unspecified Atrial Fibrillation Dx" and #account_alert_codes > 0 then
        -- Auto Resolve Unspecified Atrial Fibrillation Dx
        for _, code in ipairs(account_alert_codes) do
            documented_dx_header:add_link(codes.make_code_link(code,
                "Autoresolved Specified Code - " .. alert_code_dictionary[code]))
        end
        Result.validated = true
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.passed = true
    elseif i4891_code_link and #account_alert_codes == 0 then
        -- Unspecified Atrial Fibrillation Dx
        documented_dx_header:add_link(i4891_code_link)
        Result.subtitle = "Unspecified Atrial Fibrillation Dx"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Clinical Evidence Links
            clinical_evidence_header:add_abstraction_link("ABLATION", "Ablation")
            clinical_evidence_header:add_code_link("I35.1", "Aortic Regurgitation")
            clinical_evidence_header:add_code_link("I35.0", "Aortic Stenosis")
            clinical_evidence_header:add_abstraction_link_with_value("CARDIOVERSION", "Cardioversion")
            clinical_evidence_header:add_abstraction_link("DYSPNEA_ON_EXERTION", "Dyspnea On Exertion")
            clinical_evidence_header:add_code_link("R53.83", "Fatigue")
            clinical_evidence_header:add_abstraction_link("HEART_PALPITATIONS", "Heart Palpitations")
            clinical_evidence_header:add_abstraction_link("IMPLANTABLE_CARDIAC_ASSIST_DEVICE",
                "Implantable Cardiac Assist Device")
            clinical_evidence_header:add_abstraction_link("IRREGULAR_ECHO_FINDING", "Irregular Echo Findings")
            clinical_evidence_header:add_code_link("R42", "Light Headed")
            clinical_evidence_header:add_abstraction_link("MAZE_PROCEDURE", "Maze Procedure")
            clinical_evidence_header:add_code_link("I34.0", "Mitral Regurgitation")
            clinical_evidence_header:add_code_link("I34.2", "Mitral Stenosis")
            clinical_evidence_header:add_code_link("I35.1", "Pulmonic Regurgitation")
            clinical_evidence_header:add_code_link("I37.0", "Pulmonic Stenosis")
            clinical_evidence_header:add_abstraction_link_with_value("SHORTNESS_OF_BREATH", "Shortness of Breath")
            clinical_evidence_header:add_code_link("R55", "Syncopal")
            clinical_evidence_header:add_code_link("I36.1", "Tricuspid Regurgitation")
            clinical_evidence_header:add_code_link("I36.0", "Tricuspid Stenosis")
            clinical_evidence_header:add_abstraction_link("WATCHMAN_PROCEDURE", "Watchman Procedure")

            -- Document Links
            ekg_header:add_document_link("EKG", "EKG")
            ekg_header:add_document_link("Electrocardiogram Adult   ECGR", "Electrocardiogram Adult   ECGR")
            ekg_header:add_document_link("ECG Adult", "ECG Adult")
            ekg_header:add_document_link("RestingECG", "RestingECG")
            ekg_header:add_document_link("EKG", "EKG")

            -- Treatment Links
            treatment_and_monitoring_header:add_medication_link("Adenosine", "")
            treatment_and_monitoring_header:add_abstraction_link("ADENOSINE", "Adenosine")
            treatment_and_monitoring_header:add_medication_link("Antiarrhythmic", "")
            treatment_and_monitoring_header:add_abstraction_link("ANTIARRHYTHMIC", "Antiarrhythmic")
            treatment_and_monitoring_header:add_medication_link("Anticoagulant", "")
            treatment_and_monitoring_header:add_abstraction_link("ANTICOAGULANT", "Anticoagulant")
            treatment_and_monitoring_header:add_medication_link("Antiplatelet", "")
            treatment_and_monitoring_header:add_abstraction_link("ANTIPLATELET", "Antiplatelet")
            treatment_and_monitoring_header:add_medication_link("Beta Blocker", "")
            treatment_and_monitoring_header:add_abstraction_link("BETA_BLOCKER", "Beta Blocker")
            treatment_and_monitoring_header:add_medication_link("Calcium Channel Blockers", "")
            treatment_and_monitoring_header:add_abstraction_link("CALCIUM_CHANNEL_BLOCKER", "Calcium Channel Blocker")
            treatment_and_monitoring_header:add_medication_link("Digitalis", "")
            treatment_and_monitoring_header:add_abstraction_link("DIGOXIN", "Digoxin")
            treatment_and_monitoring_header:add_code_link("Z79.01", "Long Term Use of Z79.01")
            treatment_and_monitoring_header:add_code_link("Z79.02", "Long Term Use of Antithrombotics/Z79.02")

            -- Vital Links
            vital_signs_intake_header:add_discrete_value_one_of_link(dv_heart_rate, "Heart Rate",
                high_heart_rate_predicate)
            vital_signs_intake_header:add_discrete_value_one_of_link(map_dv_names, "Mean Arterial Pressure",
                low_map_predicate)
            vital_signs_intake_header:add_discrete_value_one_of_link(
                systolic_blood_pressure_dv_names,
                "Systolic Blood Pressure",
                low_systolic_blood_pressure_predicate
            )
        end



        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        compile_links()
    end
end
