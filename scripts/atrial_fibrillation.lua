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
--- Site Constants
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



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }
local subtitle = existing_alert and existing_alert.subtitle or nil



if not existing_alert or not existing_alert.validated then
    --------------------------------------------------------------------------------
    --- Header Variables and Helper Functions
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
    --- @param link CdiAlertLink?
    local function add_clinical_evidence_link(link)
        table.insert(clinical_evidence_links, link)
    end
    --- @param code string
    --- @param text string
    local function add_clinical_evidence_code(code, text)
        add_clinical_evidence_link(links.get_code_link { code = code, text = text })
    end
    --- @param prefix string
    --- @param text string
    local function add_clinical_evidence_code_prefix(prefix, text)
        add_clinical_evidence_link(codes.get_code_prefix_link { prefix = prefix, text = text })
    end
    --- @param code_set string[]
    --- @param text string
    local function add_clinical_evidence_any_code(code_set, text)
        add_clinical_evidence_link(links.get_code_link { codes = code_set, text = text })
    end
    --- @param code string
    --- @param text string
    local function add_clinical_evidence_abstraction(code, text)
        add_clinical_evidence_link(links.get_abstraction_link { code = code, text = text })
    end
    local function compile_links()
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
            table.insert(clinical_evidence_links, links.get_abstraction_link { code = "ABLATION", text = "Ablation", seq = 1 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "I35.1", text = "Aortic Regurgitation", seq = 2 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "I35.0", text = "Aortic Stenosis", seq = 3 })
            table.insert(clinical_evidence_links, links.get_abstraction_link { code = "CARDIOVERSION", text = "Cardioversion", seq = 4 })
            table.insert(clinical_evidence_links, links.get_abstraction_value_link { code = "DYSPNEA_ON_EXERTION", text = "Dyspnea On Exertion", seq = 5 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "R53.83", text = "Fatigue", seq = 6 })
            table.insert(clinical_evidence_links, links.get_abstraction_link { code = "HEART_PALPITATIONS", text = "Heart Palpitations", seq = 7 })
            table.insert(clinical_evidence_links, links.get_abstraction_link { code = "IMPLANTABLE_CARDIAC_ASSIST_DEVICE", text = "Implantable Cardiac Assist Device", seq = 8 })
            table.insert(clinical_evidence_links, links.get_abstraction_link { code = "IRREGULAR_ECHO_FINDING", text = "Irregular Echo Findings", seq = 9 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "R42", text = "Light Headed", seq = 10 })
            table.insert(clinical_evidence_links, links.get_abstraction_link { code = "MAZE_PROCEDURE", text = "Maze Procedure", seq = 11 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "I34.0", text = "Mitral Regurgitation", seq = 12 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "I34.2", text = "Mitral Stenosis", seq = 13 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "I35.1", text = "Pulmonic Regurgitation", seq = 14 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "I37.0", text = "Pulmonic Stenosis", seq = 15 })
            table.insert(clinical_evidence_links, links.get_abstraction_value_link { code = "SHORTNESS_OF_BREATH", text = "Shortness of Breath", seq = 16 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "R55", text = "Syncopal", seq = 17 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "I36.1", text = "Tricuspid Regurgitation", seq = 18 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "I36.0", text = "Tricuspid Stenosis", seq = 19 })
            table.insert(clinical_evidence_links, links.get_abstraction_link { code = "WATCHMAN_PROCEDURE", text = "Watchman Procedure", seq = 20 })

            -- Document Links
            table.insert(ekg_links, links.get_document_link { documentType = "EKG", text = "EKG" })
            table.insert(ekg_links, links.get_document_link { documentType = "Electrocardiogram Adult   ECGR", text = "Electrocardiogram Adult   ECGR" })
            table.insert(ekg_links, links.get_document_link { documentType = "ECG Adult", text = "ECG Adult" })
            table.insert(ekg_links, links.get_document_link { documentType = "RestingECG", text = "RestingECG" })
            table.insert(ekg_links, links.get_document_link { documentType = "EKG", text = "EKG" })

            -- Treatment Links
            table.insert(treatment_and_monitoring_links, links.get_medication_link { cat = "Adenosine", text = "", seq = 1 })
            table.insert(treatment_and_monitoring_links, links.get_abstraction_link { code = "ADENOSINE", text = "Adenosine", seq = 2 })
            table.insert(treatment_and_monitoring_links, links.get_medication_link { cat = "Antiarrhythmic", text = "", seq = 3 })
            table.insert(treatment_and_monitoring_links, links.get_abstraction_link { code = "ANTIARRHYTHMIC", text = "Antiarrhythmic", seq = 4 })
            table.insert(treatment_and_monitoring_links, links.get_medication_link { cat = "Anticoagulant", text = "", seq = 5 })
            table.insert(treatment_and_monitoring_links, links.get_abstraction_link { code = "ANTICOAGULANT", text = "Anticoagulant", seq = 6 })
            table.insert(treatment_and_monitoring_links, links.get_medication_link { cat = "Antiplatelet", text = "", seq = 7 })
            table.insert(treatment_and_monitoring_links, links.get_abstraction_link { code = "ANTIPLATELET", text = "Antiplatelet", seq = 8 })
            table.insert(treatment_and_monitoring_links, links.get_medication_link { cat = "Beta Blocker", text = "", seq = 9 })
            table.insert(treatment_and_monitoring_links, links.get_abstraction_link { code = "BETA_BLOCKER", text = "Beta Blocker", seq = 10 })
            table.insert(treatment_and_monitoring_links, links.get_medication_link { cat = "Calcium Channel Blockers", text = "", seq = 11 })
            table.insert(treatment_and_monitoring_links, links.get_abstraction_link { code = "CALCIUM_CHANNEL_BLOCKER", text = "Calcium Channel Blocker", seq = 12 })
            table.insert(treatment_and_monitoring_links, links.get_medication_link { cat = "Digitalis", text = "", seq = 13 })
            table.insert(treatment_and_monitoring_links, links.get_abstraction_link { code = "DIGOXIN", text = "Digoxin", seq = 14 })
            table.insert(treatment_and_monitoring_links, links.get_code_link { code = "Z79.01", text = "Long Term Use of Z79.01", seq = 15 })
            table.insert(treatment_and_monitoring_links, links.get_code_link { code = "Z79.02", text = "Long Term Use of Antithrombotics/Z79.02", seq = 16 })

            -- Vital Links
            table.insert(vital_signs_intake_links, links.get_discrete_value_link { discreteValueNames = dv_heart_rate, text = "Heart Rate", calc = high_heart_rate_predicate, seq = 1 })
            table.insert(vital_signs_intake_links, links.get_discrete_value_link { discreteValueNames = map_dv_names, text = "Mean Arterial Pressure", calc = low_map_predicate, seq = 2 })
            table.insert(vital_signs_intake_links, links.get_discrete_value_link { discreteValueNames = systolic_blood_pressure_dv_names, text = "Systolic Blood Pressure", calc = low_systolic_blood_pressure_predicate, seq = 3 })
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

