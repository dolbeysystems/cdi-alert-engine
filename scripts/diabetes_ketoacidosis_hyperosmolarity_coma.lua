---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Diabetes Ketoacidosis Hyperosmolarity Coma
---
--- This script checks an account to see if it matches the criteria for a diabetes ketoacidosis hyperosmolarity coma
--- alert.
---
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
---------------------------------------------------------------------------------------------------------------------
---@diagnostic disable: unused-local, empty-block -- Remove once the script is filled out



--------------------------------------------------------------------------------
--- Requires 
--------------------------------------------------------------------------------
local alerts = require("libs.common.alerts")(Account)
local links = require("libs.common.basic_links")(Account)
local codes = require("libs.common.codes")(Account)
local dates = require("libs.common.dates")
local discrete = require("libs.common.discrete_values")(Account)
local headers = require("libs.common.headers")(Account)



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local dv_acetone = { "" }
local calc_acetone1 = function(dv_, num) return num > 0 end
local dv_anion_gap = { "" }
local calc_anion_gap1 = function(dv_, num) return num > 14 end
local dv_arterial_blood_ph = { "pH" }
local calc_arterial_blood_ph1 = function(dv_, num) return num < 7.35 end
local dv_beta_hydroxybutyrate = { "BETAHYDROXY BUTYRATE (mmol/L)" }
local calc_beta_hydroxybutyrate1 = function(dv_, num) return num > 0.27 end
local dv_blood_glucose = { "GLUCOSE (mg/dL)", "GLUCOSE" }
local calc_blood_glucose1 = function(dv_, num) return num > 600 end
local calc_blood_glucose2 = function(dv_, num) return num < 70 end
local calc_blood_glucose3 = function(dv_, num) return num > 250 end
local dv_blood_glucose_poc = { "GLUCOSE ACCUCHECK (mg/dL)" }
local calc_blood_glucose_poc1 = function(dv_, num) return num > 250 end
local calc_blood_glucose_poc2 = function(dv_, num) return num > 600 end
local calc_blood_glucose_poc3 = function(dv_, num) return num < 70 end
local dv_glasgow_coma_scale = { "3.5 Neuro Glasgow Score" }
local calc_glasgow_coma_scale1 = function(dv_, num) return num < 8 end
local dv_heart_rate = { "Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)", "3.5 Heart Rate (Radial) (bpm)", "SCC Monitor Pulse (bpm)" }
local calc_heart_rate1 = function(dv_, num) return num > 90 end
local dv_serum_bicarbonate = { "HCO3 (meq/L)", "HCO3 (mmol/L)", "HCO3 VENOUS (meq/L)" }
local calc_serum_bicarbonate1 = function(dv_, num) return num < 22 end
local dv_serum_ketone = { "" }
local calc_serum_ketone1 = function(dv_, num) return num > 0 end
local dv_serum_osmolality = { "OSMOLALITY (mOsm/kg)" }
local calc_serum_osmolality1 = function(dv_, num) return num > 320 end
local dv_temperature = { "Temperature Degrees C 3.5 (degrees C)", "Temperature  Degrees C 3.5 (degrees C)", "TEMPERATURE (C)" }
local calc_temperature1 = function(dv_, num) return num > 38.3 end
local dv_urine_ketone = { "UR KETONES (mg/dL)", "KETONES (mg/dL)" }
local calc_urine_ketone1 = function(dv_, num) return num > 0 end
local dv_oxygen_therapy = { "DELIVERY" }



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
    local documented_dx_header = headers.make_header_builder("Documented Dx", 1)
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 2)
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 3)
    local coma_header = headers.make_header_builder("Signs of Coma", 4)
    local vital_signs_intake_header = headers.make_header_builder("Vital Signs/Intake", 5)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 6)
    local blood_glucose_header = headers.make_header_builder("Blood Glucose", 7)

    local function compile_links()
        laboratory_studies_header:add_link(blood_glucose_header:build(true))

        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, coma_header:build(true))
        table.insert(result_links, vital_signs_intake_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Alert Trigger
    local e1011_code = links.get_code_link { code = "E10.11", text = "Type 1 Diabetes Mellitus With Ketoacidosis With Coma" }
    local e1641_code = links.get_code_link { code = "E10.641", text = "Type 1 Diabetes Mellitus With Hypoglycemia With Coma" }
    local e1101_code = links.get_code_link { code = "E11.01", text = "Type 2 Diabetes Mellitus With Hyperosmolarity With Coma" }
    local e1111_code = links.get_code_link { code = "E11.11", text = "Type 2 Diabetes Mellitus With Ketoacidosis With Coma" }
    local e11641_code = links.get_code_link { code = "E11.641", text = "Type 2 Diabetes Mellitus With Hypoglycemia With Coma" }
    local e10649_code = links.get_code_link { code = "E10.649", text = "Type 1 Diabetes with Hypoglycemia without Coma" }
    local e10641_code = links.get_code_link { code = "E10.641", text = "Type 1 Diabetes Mellitus with Hypoglycemia with Coma" }
    local r4020_code = links.get_code_link { code = "R40.20", text = "Unspecified Coma" }
    local unspec_type1_diabetes = links.get_abstract_link { text = "Type 1 Diabetes Present" }
    local e1010_code = links.get_code_link { code = "E10.10", text = "Type 1 Diabetes with Ketoacidosis without Coma" }
    local unspec_type2_diabetes = links.get_abstract_link { text = "Type 2 Diabetes Present" }
    local e1100_code = links.get_code_link { code = "E11.00", text = "Type 2 Diabetes Mellitus With Hyperosmolarity Without Nonketotic Hyperglycemic-Hyperosmolar Coma" }
    local e1110_code = links.get_code_link { code = "E11.10", text = "Type 2 Diabetes Mellitus With Ketoacidosis Without Coma" }
    local e1165_code = links.get_code_link { code = "E11.65", text = "Type 2 Diabetes Mellitus With Hyperglycemia" }
    local e11649_code = links.get_code_link { code = "E11.649", text = "Type 2 Diabetes Mellitus With Hypoglycemia Without Coma" }

    -- Clinical Evidence
    local r824_code = links.get_code_link { code = "R82.4", text = "Ketonuria" }

    -- Coma
    local decr_lvl_consciousness_abs = links.get_abstraction_value_link { code = "DECREASED_LEVEL_OF_CONSCIOUSNESS", text = "Decreased Level of Consciousness" }
    local glasgow_coma_score_dv = links.get_discrete_value_link { discreteValueNames = dv_glasgow_coma_scale, text = "Glasgow Coma Score", predicate = calc_glasgow_coma_scale1 }
    local glasgow_coma_score_abs = links.get_abstraction_value_link { code = "LOW_GLASGOW_COMA_SCORE_SEVERE", text = "Glasgow Coma Score" }
    local a5a193_codes = links.get_multi_code_link { codes = { "5A1935Z", "5A1945Z", "5A1955Z" }, text = "Invasive Mechanical Ventilation" }
    local obtunded_abs = links.get_abstraction_value_link { code = "OBTUNDED", text = "Obtunded" }
    local a0bh18ez_code = links.get_multi_code_link { codes = { "0BH18EZ", "0BH17EZ" }, text = "Patient Intubated" }
    local r401_code = links.get_code_link { code = "R40.1", text = "Stupor" }

    -- Labs
    local low_art_blood_ph_dv = links.get_discrete_value_link {
        discreteValueNames = dv_arterial_blood_ph,
        text = "Arterial Blood PH",
        predicate = calc_arterial_blood_ph1,
    }
    local beta_hydroxybutyrate_dv = links.get_discrete_value_link {
        discreteValueNames = dv_beta_hydroxybutyrate,
        text = "Beta-Hydroxybutyrate",
        predicate = calc_beta_hydroxybutyrate1,
    }
    local serum_bicarbonate_dv = links.get_discrete_value_link {
        discreteValueNames = dv_serum_bicarbonate,
        text = "Blood C02",
        predicate = calc_serum_bicarbonate1,
    }
    local elevated_serum_osmolality_dv = links.get_discrete_value_link {
        discreteValueNames = dv_serum_osmolality,
        text = "Serum Osmolality",
        predicate = calc_serum_osmolality1,
    }
    local urine_ketones_dv = links.get_discrete_value_link {
        discreteValueNames = dv_urine_ketone,
        text = "Urine Ketones Present",
        predicate = calc_urine_ketone1,
    }
    local serum_ketones_dv = links.get_discrete_value_link {
        discreteValueNames = dv_serum_ketone,
        text = "Urine Ketones Present",
        predicate = calc_serum_ketone1,
    }

    -- Labs Subheadings
    local low_blood_glucose_dv = links.get_discrete_value_links {
        discreteValueNames = dv_blood_glucose,
        text = "Low Blood Glucose",
        predicate = calc_blood_glucose2
    }
    if not low_blood_glucose_dv then
        low_blood_glucose_dv = links.get_discrete_value_links {
            discreteValueNames = dv_blood_glucose_poc,
            text = "Low Blood Glucose",
            predicate = calc_blood_glucose_poc3
        }
    end
    local high_blood_glucose_hhns_dv = links.get_discrete_value_link {
        discreteValueNames = dv_blood_glucose,
        text = "Blood Glucose",
        predicate = calc_blood_glucose1
    }
    if not high_blood_glucose_hhns_dv then
        high_blood_glucose_hhns_dv = links.get_discrete_value_link {
            discreteValueNames = dv_blood_glucose_poc,
            text = "Blood Glucose",
            predicate = calc_blood_glucose_poc2
        }
    end
    local high_blood_glucose_dka_dv = links.get_discrete_value_link {
        discreteValueNames = dv_blood_glucose,
        text = "Blood Glucose",
        predicate = calc_blood_glucose3
    }
    if not high_blood_glucose_dka_dv then
        high_blood_glucose_dka_dv = links.get_discrete_value_link {
            discreteValueNames = dv_blood_glucose_poc,
            text = "Blood Glucose",
            predicate = calc_blood_glucose_poc1
        }
    end

    -- Abstracting Main Clinical Indicators
    local hhns = (high_blood_glucose_hhns_dv and 1 or 0) + (elevated_serum_osmolality_dv and 1 or 0)
    local dka = (low_art_blood_ph_dv and 1 or 0) + (serum_bicarbonate_dv and 1 or 0)

    -- Signs of Coma Check
    local soc =
        (not a5a193_codes and not a0bh18ez_code) and
        (glasgow_coma_score_dv or glasgow_coma_score_abs or decr_lvl_consciousness_abs or obtunded_abs or r401_code)

    -- DKA Check
    local dka_check =
        (urine_ketones_dv or r824_code or serum_ketones_dv or beta_hydroxybutyrate_dv) and
        high_blood_glucose_dka_dv

    local dka_alert_passed = false
    local hhns_alert_passed = false



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if
        (e1011_code or e1641_code) and
        (e1101_code or e1111_code or e11641_code)
    then
        -- #1
        if e1011_code then clinical_evidence_header:add_link(e1011_code) end
        if e1641_code then clinical_evidence_header:add_link(e1641_code) end
        if e1101_code then clinical_evidence_header:add_link(e1101_code) end
        if e1111_code then clinical_evidence_header:add_link(e1111_code) end
        if e11641_code then clinical_evidence_header:add_link(e11641_code) end
        Result.subtitle = "Conflicting Diabetes Mellitus Type 1 and Type 2 with Coma Dx, Clarification Needed"
        Result.passed = true

    elseif e1010_code and e1110_code then
        -- #2
        clinical_evidence_header:add_link(e1010_code)
        clinical_evidence_header:add_link(e1110_code)
        Result.subtitle = "Conflicting Type 1 and Type 2 with Ketoacidosis without Coma Dx"
        Result.passed = true

    elseif subtitle == "Possible Type 1 Diabetes Mellitus with Ketoacidosis with Coma" and e1011_code then
        -- #3.1/4.1
        clinical_evidence_header:add_link(e1011_code)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif dka >= 1 and dka_check and (soc or r4020_code) and unspec_type1_diabetes and not e1011_code then
        -- #3.0
        clinical_evidence_header:add_link(unspec_type1_diabetes)
        clinical_evidence_header:add_link(r4020_code)
        dka_alert_passed = true
        Result.subtitle = "Possible Type 1 Diabetes Mellitus with Ketoacidosis with Coma"
        Result.passed = true

    elseif e1010_code and (soc or r4020_code) and not e1011_code then
        -- #4.0
        clinical_evidence_header:add_link(e1010_code)
        if r4020_code then clinical_evidence_header:add_link(r4020_code) end
        Result.subtitle = "Possible Type 1 Diabetes Mellitus with Ketoacidosis with Coma"
        dka_alert_passed = true
        Result.passed = true

    elseif subtitle == "Possible Type 1 Diabetes Mellitus with Ketoacidosis without Coma" and (e1011_code or e1010_code) then
        -- #5.1
        if e1011_code then
            e1011_code.link_text = "Autoresolved Code - " .. e1011_code.link_text
            clinical_evidence_header:add_link(e1011_code)
        end
        if e1010_code then
            e1010_code.link_text = "Autoresolved Code - " .. e1010_code.link_text
            clinical_evidence_header:add_link(e1010_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif dka >= 1 and dka_check and (not r4020_code or not soc) and unspec_type1_diabetes and not e1010_code and not e1011_code then
        -- #5
        clinical_evidence_header:add_link(unspec_type1_diabetes)
        dka_alert_passed = true
        Result.subtitle = "Possible Type 1 Diabetes Mellitus with Ketoacidosis without Coma"
        Result.passed = true

    elseif subtitle == "Possible Type 1 Diabetes Mellitus with Hypoglycemia with Coma" and e10641_code then
        -- #6.1/7.1
        if e10641_code then
            e10641_code.link_text = "Autoresolved Code - " .. e10641_code.link_text
            clinical_evidence_header:add_link(e10641_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif (r4020_code or soc) and e10649_code and not e10641_code then
        -- #6
        documented_dx_header:add_link(unspec_type1_diabetes)
        if r4020_code then documented_dx_header:add_link(r4020_code) end
        for _, entry in ipairs(low_blood_glucose_dv) do
            blood_glucose_header:add_link(entry)
        end
        if blood_glucose_header.links then
            documented_dx_header:add_link(blood_glucose_header:build(true))
        end
        Result.subtitle = "Possible Type 1 Diabetes Mellitus with Hypoglycemia with Coma"
        Result.passed = true

    elseif e10649_code and (soc or r4020_code) and not e10641_code then
        -- #7
        documented_dx_header:add_link(e10649_code)
        documented_dx_header:add_link(r4020_code)
        Result.subtitle = "Possible Type 1 Diabetes Mellitus with Hypoglycemia with Coma"
        Result.passed = true

    elseif subtitle == "Possible Type 2 Diabetes Mellitus with Hyperosmolarity without Coma" and e1101_code then
        -- #8.1/10.1
        clinical_evidence_header:add_link(e1101_code)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif hhns > 1 and unspec_type2_diabetes and (r4020_code and soc) and e1101_code then
        -- #8
        documented_dx_header:add_link(unspec_type2_diabetes)
        documented_dx_header:add_link(r4020_code)
        hhns_alert_passed = true
        Result.subtitle = "Possible Type 2 Diabetes Mellitus with Hyperosmolarity with Coma"
        Result.passed = true

    elseif subtitle == "Possible Type 2 Diabetes Mellitus with Hyperosmolarity without Coma" and (e1100_code or e1101_code) then
        -- #9.1
        documented_dx_header:add_link(e1101_code)
        if e1100_code then
            e1100_code.link_text = "Autoresolved Code - " .. e1100_code.link_text
            documented_dx_header:add_link(e1100_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif hhns > 1 and (not r4020_code or not soc) and unspec_type2_diabetes and not e1100_code and not e1101_code then
        -- #9
        documented_dx_header:add_link(unspec_type2_diabetes)
        hhns_alert_passed = true
        Result.subtitle = "Possible Type 2 Diabetes Mellitus with Hyperosmolarity without Coma"
        Result.passed = true

    elseif (soc or r4020_code) and e1110_code and not e1111_code then
        -- #10
        documented_dx_header:add_link(e1110_code)
        documented_dx_header:add_link(r4020_code)
        dka_alert_passed = true
        Result.subtitle = "Possible Type 2 Diabetes Mellitus with Ketoacidosis with Coma"
        Result.passed = true

    elseif subtitle == "Possible Type 2 Diabetes Mellitus with Keotacidosis with Coma" and e1111_code then
        -- #11.1/12.1
        documented_dx_header:add_link(e1111_code)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif dka >= 1 and dka_check and (soc or r4020_code) and unspec_type2_diabetes and not e1111_code then
        -- #11
        documented_dx_header:add_link(unspec_type2_diabetes)
        documented_dx_header:add_link(r4020_code)
        dka_alert_passed = true
        Result.subtitle = "Possible Type 2 Diabetes Mellitus with Ketoacidosis with Coma"
        Result.passed = true

    elseif (soc or r4020_code) and e1110_code and not e1111_code then
        -- #12
        documented_dx_header:add_link(e1110_code)
        documented_dx_header:add_link(r4020_code)
        dka_alert_passed = true
        Result.subtitle = "Possible Type 2 Diabetes Mellitus with Ketoacidosis with Coma"
        Result.passed = true

    elseif subtitle == "Possible Type 2 Diabetes Mellitus with Hyperosmolarity without Coma" and e1101_code then
        -- #13.1
        documented_dx_header:add_link(e1101_code)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif e1165_code and (soc or r4020_code) and elevated_serum_osmolality_dv and not e1101_code then
        -- #13
        clinical_evidence_header:add_link(e1165_code)
        clinical_evidence_header:add_link(r4020_code)
        hhns_alert_passed = true
        Result.subtitle = "Possible Type 2 Diabetes Mellitus with Hyperosmolarity with Coma"
        Result.passed = true

    elseif subtitle == "Possible Type 2 Diabetes Mellitus with Hyperosmolarity without Coma" and e1101_code then
        -- #14.1
        clinical_evidence_header:add_link(e1101_code)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif e1165_code and (not soc and not r4020_code) and elevated_serum_osmolality_dv and not e1101_code then
        -- #14
        documented_dx_header:add_link(e1165_code)
        documented_dx_header:add_link(r4020_code)
        hhns_alert_passed = true
        Result.subtitle = "Possible Type 2 Diabetes Mellitus with Hyperosmolarity without Coma"
        Result.passed = true

    elseif subtitle == "Possible Type 2 Diabetes Mellitus with Ketoacidosis without Coma" and (e1100_code or e1101_code) then
        -- #15.1
        if e1110_code then
            e1110_code.link_text = "Autoresolved Code - " .. e1110_code.link_text
            clinical_evidence_header:add_link(e1110_code)
        end
        clinical_evidence_header:add_link(e1111_code)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif (not soc and not r4020_code) and dka >= 1 and dka_check and unspec_type2_diabetes and not e1110_code and not e1111_code then
        -- #15
        documented_dx_header:add_link(unspec_type2_diabetes)
        dka_alert_passed = true
        Result.subtitle = "Possible Type 2 Diabetes Mellitus with Ketoacidosis without Coma"
        Result.passed = true

    elseif subtitle == "Possible Type 2 Diabetes Mellitus with Hypoglycemai with Coma" and e11641_code then
        -- #16.1/17.1
        documented_dx_header:add_link(e11641_code)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif unspec_type2_diabetes and (r4020_code or soc) and #low_blood_glucose_dv > 1 and not e11641_code then
        -- #16
        documented_dx_header:add_link(unspec_type2_diabetes)
        documented_dx_header:add_link(r4020_code)
        for _, entry in ipairs(low_blood_glucose_dv) do
            blood_glucose_header:add_link(entry)
        end
        Result.subtitle = "Possible Type 2 Diabetes Mellitus with Hypoglycemia with Coma"
        Result.passed = true

    elseif e11649_code and (soc or r4020_code) and not e11641_code then
        -- #17
        documented_dx_header:add_link(e11649_code)
        documented_dx_header:add_link(r4020_code)
        Result.subtitle = "Possible Type 2 Diabetes Mellitus with Hypoglycemia with Coma"
        Result.passed = true

    elseif unspec_type1_diabetes and unspec_type2_diabetes then
        -- #18
        documented_dx_header:add_link(unspec_type1_diabetes)
        documented_dx_header:add_link(unspec_type2_diabetes)
        Result.subtitle = "Conflicting Diabetes Type 1 and Diabetes Type 2 Dx"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Clinical Evidence
            if hhns_alert_passed then
                local r4182_code = links.get_code_link { code = "R41.82", text = "Altered Level Of Consciousness" }
                local altered_abs = links.get_abstraction_value_link { code = "ALTERED_LEVEL_OF_CONSCIOUSNESS", text = "Altered Level Of Consciousness" }
                if r4182_code then
                    clinical_evidence_header:add_link(r4182_code)
                    if altered_abs then
                        altered_abs.hidden = true
                        clinical_evidence_header:add_link(altered_abs)
                    end
                elseif altered_abs then
                    clinical_evidence_header:add_link(altered_abs)
                end
            end
            if dka_alert_passed then clinical_evidence_header:add_code_link("G93.6", "Cerebral Edema") end
            clinical_evidence_header:add_code_link("R41.0", "Confusion")
            if hhns_alert_passed then clinical_evidence_header:add_abstraction_link("EXTREME_THIRST", "Extreme Thirst") end
            if dka_alert_passed then clinical_evidence_header:add_code_link("R53.83", "Fatigue") end
            clinical_evidence_header:add_abstraction_link("FRUITY_BREATH", "Fruity Breath")
            clinical_evidence_header:add_code_link("Z90.410", "History of Pancreatectomy")
            clinical_evidence_header:add_code_link("Z90.411", "History of Partial Pancreatectomy")
            if dka_alert_passed then clinical_evidence_header:add_code_link("E87.6", "Hypokalemia") end
            clinical_evidence_header:add_abstraction_link("INCREASED_URINARY_FREQUENCY", "Increased Urinary Frequency")
            if r824_code then clinical_evidence_header:add_link(r824_code) end
            clinical_evidence_header:add_discrete_value_one_of_link(dv_oxygen_therapy, "Oxygen Therapy", function(dv, num_) return dv.result ~= nil end)
            if hhns_alert_passed then clinical_evidence_header:add_code_link("R63.1", "Polydipsia") end
            if hhns_alert_passed then clinical_evidence_header:add_abstraction_link("PSYCHOSIS", "Psychosis") end
            clinical_evidence_header:add_abstraction_link("SEIZURE", "Seizure")
            if dka_alert_passed then clinical_evidence_header:add_abstraction_link("SHORTNESS_OF_BREATH", "Shortness of Breath") end
            if hhns_alert_passed then clinical_evidence_header:add_code_link("R47.81", "Slurred Speech") end
            if hhns_alert_passed then clinical_evidence_header:add_code_link("R11.10", "Vomiting") end
            if dka_alert_passed then clinical_evidence_header:add_abstraction_link("VOMITING", "Vomiting") end
            if hhns_alert_passed then clinical_evidence_header:add_code_link("R11.11", "Vomiting without Nausea") end

            -- Coma
            if decr_lvl_consciousness_abs then coma_header:add_link(decr_lvl_consciousness_abs) end
            if glasgow_coma_score_dv then coma_header:add_link(glasgow_coma_score_dv) end
            if glasgow_coma_score_abs then coma_header:add_link(glasgow_coma_score_abs) end
            if a5a193_codes then coma_header:add_link(a5a193_codes) end
            if obtunded_abs then coma_header:add_link(obtunded_abs) end
            if a0bh18ez_code then coma_header:add_link(a0bh18ez_code) end
            if r401_code then coma_header:add_link(r401_code) end

            -- Labs
            if dka_alert_passed then
                laboratory_studies_header:add_discrete_value_one_of_link(dv_acetone, "Acetone", calc_acetone1)
                laboratory_studies_header:add_discrete_value_one_of_link(dv_anion_gap, "Anion Gap", calc_anion_gap1)
                laboratory_studies_header:add_abstraction_link_with_value("ANION_GAP", "Anion Gap")
                laboratory_studies_header:add_link(low_art_blood_ph_dv)
                laboratory_studies_header:add_link(beta_hydroxybutyrate_dv)
                laboratory_studies_header:add_link(serum_bicarbonate_dv)
                laboratory_studies_header:add_abstraction_link_with_value("LOW_SERUM_BICABONATE", "Arterial Blood PH")
                laboratory_studies_header:add_abstraction_link_with_value("HIGH_BLOOD_GLUCOSE_DKA", "Blood Glucose")
                laboratory_studies_header:add_abstraction_link_with_value("HIGH_BLOOD_GLUCOSE_DKA", "Blood Glucose")
            end
            if hhns_alert_passed then laboratory_studies_header:add_link(elevated_serum_osmolality_dv) end
            if dka_alert_passed then
                laboratory_studies_header:add_abstraction_link_with_value("LOW_SERUM_POTASSIUM", "Serum Potassium")
                laboratory_studies_header:add_link(urine_ketones_dv)
                laboratory_studies_header:add_link(serum_ketones_dv)
            end

            -- Labs Subheadings
            if dka_alert_passed and high_blood_glucose_dka_dv then
                for _, entry in ipairs(high_blood_glucose_dka_dv) do
                    blood_glucose_header:add_link(entry)
                end
            end
            if hhns_alert_passed and high_blood_glucose_hhns_dv then
                for _, entry in ipairs(high_blood_glucose_hhns_dv) do
                    blood_glucose_header:add_link(entry)
                end
            end

            -- Meds
            treatment_and_monitoring_header:add_medication_link("Albumin", "")
            treatment_and_monitoring_header:add_medication_link("Anti-Hypoglycemic Agent", "")
            treatment_and_monitoring_header:add_medication_link("Dextrose 50%", "")
            treatment_and_monitoring_header:add_medication_link("Fluid Bolus", "")
            treatment_and_monitoring_header:add_abstraction_link("FLUID_BOLUS", "Fluid Bolus")
            treatment_and_monitoring_header:add_medication_link("Insulin", "")
            treatment_and_monitoring_header:add_abstraction_link("INSULIN_ADMINISTRATION", "Insulin Administration")
            treatment_and_monitoring_header:add_medication_link("Sodium Bicarbonate", "")
            treatment_and_monitoring_header:add_abstraction_link("SODIUM_BICARBONATE", "Sodium Bicarbonate")

            -- Vitals
            if hhns_alert_passed then
                vital_signs_intake_header:add_discrete_value_one_of_link(dv_temperature, "Fever", calc_temperature1)
            end
            vital_signs_intake_header:add_discrete_value_one_of_link(dv_heart_rate, "Heart Rate", calc_heart_rate1)
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

