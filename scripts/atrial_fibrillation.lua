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
local alerts = require("libs.common.alerts")
local links = require("libs.common.basic_links")
local codes = require("libs.common.codes")
local discrete = require("libs.common.discrete_values")




--------------------------------------------------------------------------------
--- Setup
--------------------------------------------------------------------------------
local dv_heart_rate = {
    "Heart Rate cc (bpm)",
    "3.5 Heart Rate (Apical) (bpm)",
    "3.5 Heart Rate (Other) (bpm)",
    "3.5 Heart Rate (Radial) (bpm)",
    "SCC Monitor Pulse (bpm)"
}
local high_heart_rate_predicate = function(dv) return discrete.get_dv_value_number(dv) > 90 end
local map_dv_names = { "Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)" }
local low_map_predicate = function(dv) return discrete.get_dv_value_number(dv) < 70 end
local systolic_blood_pressure_dv_names = { "SBP 3.5 (No Calculation) (mm Hg)" }
local low_systolic_blood_pressure_predicate = function(dv) return discrete.get_dv_value_number(dv) < 90 end

local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }
local subtitle = existing_alert and existing_alert.subtitle or nil



if not existing_alert or not existing_alert.validated then
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
    --- Top-Level Link Header Variables
    --------------------------------------------------------------------------------
    local result_links = {}

    local documented_dx_header = links.make_header_link("Documented Dx")
    local documented_dx_links = {}
    local vital_signs_intake_header = links.make_header_link("Vital Signs/Intake and Output Data")
    local vital_signs_intake_links = {}
    local clinical_evidence_header = links.make_header_link("Clinical Evidence")
    local clinical_evidence_links = {}
    local treatment_and_monitoring_header = links.make_header_link("Treatment and Monitoring")
    local treatment_and_monitoring_links = {}
    local ekg_header = links.make_header_link("EKG")
    local ekg_links = {}




    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    local i4891_code_link = links.get_code_links { code = "I48.91", text = "Unspecified Atrial Fibrillation Dx Present" }
    local i480_code_link = links.get_code_links { code = "I48.0", text = "Paroxysmal Atrial Fibrillation" }
    local i4819_code_link = links.get_code_links { code = "I48.19", text = "Other Persistent Atrial Fibrillation" }
    local i4820_code_link = links.get_code_links { code = "I48.20", text = "Chronic Atrial Fibrillation" }
    local i4821_code_link = links.get_code_links { code = "I48.21", text = "Permanent Atrial Fibrillation" }




    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    -- Alert Conflicting Atrial Fibrillation Dx
    if i480_code_link and (i4819_code_link or i4820_code_link or i4821_code_link) then
        table.insert(documented_dx_links, i480_code_link)
        table.insert(documented_dx_links, i4819_code_link)
        table.insert(documented_dx_links, i4820_code_link)
        table.insert(documented_dx_links, i4821_code_link)
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
            local description = alert_code_dictionary[code]
            local temp_code = links.get_code_links { code = code, text = "Autoresolved Specified Code - " .. description }

            if temp_code then
                table.insert(documented_dx_links, temp_code)
            end
        end
        Result.validated = true
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.passed = true

    elseif i4891_code_link and #account_alert_codes == 0 then
        -- Unspecified Atrial Fibrillation Dx
        table.insert(documented_dx_links, i4891_code_link)
        Result.subtitle = "Unspecified Atrial Fibrillation Dx"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Clinical Evidence Links
            links.get_abstraction_link { code = "ABLATION", text = "Ablation", target = clinical_evidence_links, seq = 1 }
            links.get_code_link { code = "I35.1", text = "Aortic Regurgitation", target = clinical_evidence_links, seq = 2 }
            links.get_code_link { code = "I35.0", text = "Aortic Stenosis", target = clinical_evidence_links, seq = 3 }
            links.get_abstraction_link { code = "CARDIOVERSION", text = "Cardioversion", target = clinical_evidence_links, seq = 4 }
            links.get_abstraction_value_link { code = "DYSPNEA_ON_EXERTION", text = "Dyspnea On Exertion", target = clinical_evidence_links, seq = 5 }
            links.get_code_link { code = "R53.83", text = "Fatigue", target = clinical_evidence_links, seq = 6 }
            links.get_abstraction_link { code = "HEART_PALPITATIONS", text = "Heart Palpitations", target = clinical_evidence_links, seq = 7 }
            links.get_abstraction_link { code = "IMPLANTABLE_CARDIAC_ASSIST_DEVICE", text = "Implantable Cardiac Assist Device", target = clinical_evidence_links, seq = 8 }
            links.get_abstraction_link { code = "IRREGULAR_ECHO_FINDING", text = "Irregular Echo Findings", target = clinical_evidence_links, seq = 9 }
            links.get_code_link { code = "R42", text = "Light Headed", target = clinical_evidence_links, seq = 10 }
            links.get_abstraction_link { code = "MAZE_PROCEDURE", text = "Maze Procedure", target = clinical_evidence_links, seq = 11 }
            links.get_code_link { code = "I34.0", text = "Mitral Regurgitation", target = clinical_evidence_links, seq = 12 }
            links.get_code_link { code = "I34.2", text = "Mitral Stenosis", target = clinical_evidence_links, seq = 13 }
            links.get_code_link { code = "I35.1", text = "Pulmonic Regurgitation", target = clinical_evidence_links, seq = 14 }
            links.get_code_link { code = "I37.0", text = "Pulmonic Stenosis", target = clinical_evidence_links, seq = 15 }
            links.get_abstraction_value_link { code = "SHORTNESS_OF_BREATH", text = "Shortness of Breath", target = clinical_evidence_links, seq = 16 }
            links.get_code_link { code = "R55", text = "Syncopal", target = clinical_evidence_links, seq = 17 }
            links.get_code_link { code = "I36.1", text = "Tricuspid Regurgitation", target = clinical_evidence_links, seq = 18 }
            links.get_code_link { code = "I36.0", text = "Tricuspid Stenosis", target = clinical_evidence_links, seq = 19 }
            links.get_abstraction_link { code = "WATCHMAN_PROCEDURE", text = "Watchman Procedure", target = clinical_evidence_links, seq = 20 }

            -- Document Links
            links.get_document_link { documentType = "EKG", text = "EKG", target = ekg_links }
            links.get_document_link { documentType = "Electrocardiogram Adult   ECGR", text = "Electrocardiogram Adult   ECGR", target = ekg_links }
            links.get_document_link { documentType = "ECG Adult", text = "ECG Adult", target = ekg_links }
            links.get_document_link { documentType = "RestingECG", text = "RestingECG", target = ekg_links }
            links.get_document_link { documentType = "EKG", text = "EKG", target = ekg_links }

            -- Treatment Links
            links.get_medication_link { cat = "Adenosine", text = "", target = treatment_and_monitoring_links, seq = 1 }
            links.get_abstraction_link { code = "ADENOSINE", text = "Adenosine", target = treatment_and_monitoring_links, seq = 2 }
            links.get_medication_link { cat = "Antiarrhythmic", text = "", target = treatment_and_monitoring_links, seq = 3 }
            links.get_abstraction_link { code = "ANTIARRHYTHMIC", text = "Antiarrhythmic", target = treatment_and_monitoring_links, seq = 4 }
            links.get_medication_link { cat = "Anticoagulant", text = "", target = treatment_and_monitoring_links, seq = 5 }
            links.get_abstraction_link { code = "ANTICOAGULANT", text = "Anticoagulant", target = treatment_and_monitoring_links, seq = 6 }
            links.get_medication_link { cat = "Antiplatelet", text = "", target = treatment_and_monitoring_links, seq = 7 }
            links.get_abstraction_link { code = "ANTIPLATELET", text = "Antiplatelet", target = treatment_and_monitoring_links, seq = 8 }
            links.get_medication_link { cat = "Beta Blocker", text = "", target = treatment_and_monitoring_links, seq = 9 }
            links.get_abstraction_link { code = "BETA_BLOCKER", text = "Beta Blocker", target = treatment_and_monitoring_links, seq = 10 }
            links.get_medication_link { cat = "Calcium Channel Blockers", text = "", target = treatment_and_monitoring_links, seq = 11 }
            links.get_abstraction_link { code = "CALCIUM_CHANNEL_BLOCKER", text = "Calcium Channel Blocker", target = treatment_and_monitoring_links, seq = 12 }
            links.get_medication_link { cat = "Digitalis", text = "", target = treatment_and_monitoring_links, seq = 13 }
            links.get_abstraction_link { code = "DIGOXIN", text = "Digoxin", target = treatment_and_monitoring_links, seq = 14 }
            links.get_code_link { code = "Z79.01", text = "Long Term Use of Z79.01", target = treatment_and_monitoring_links, seq = 15 }
            links.get_code_link { code = "Z79.02", text = "Long Term Use of Antithrombotics/Z79.02", target = treatment_and_monitoring_links, seq = 16 }

            -- Vital Links
            links.get_discrete_value_link { discreteValueNames = dv_heart_rate, text = "Heart Rate", target = vital_signs_intake_links, seq = 1, calc = high_heart_rate_predicate }
            links.get_discrete_value_link { discreteValueNames = map_dv_names, text = "Mean Arterial Pressure", target = vital_signs_intake_links, seq = 2, calc = low_map_predicate }
            links.get_discrete_value_link { discreteValueNames = systolic_blood_pressure_dv_names, text = "Systolic Blood Pressure", target = vital_signs_intake_links, seq = 3, calc = low_systolic_blood_pressure_predicate }
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        if #documented_dx_links > 0 then
            documented_dx_header.links = documented_dx_links
            table.insert(result_links, documented_dx_header)
        end
        if #clinical_evidence_links > 0 then
            clinical_evidence_header.links = clinical_evidence_links
            table.insert(result_links, clinical_evidence_header)
        end
        if #vital_signs_intake_links > 0 then
            vital_signs_intake_header.links = vital_signs_intake_links
            table.insert(result_links, vital_signs_intake_header)
        end
        if #treatment_and_monitoring_links > 0 then
            treatment_and_monitoring_header.links = treatment_and_monitoring_links
            table.insert(result_links, treatment_and_monitoring_header)
        end
        if #ekg_links > 0 then
            ekg_header.links = ekg_links
            table.insert(result_links, ekg_header)
        end

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end
end

