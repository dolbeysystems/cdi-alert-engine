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
local dv_hemoglobin_a1c = { "HEMOGLOBIN A1C (%)" }
local calc_hemoglobin_a1c1 = function(dv_, num) return num > 0 end
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
    local glasgow_coma_score_dv = links.get_discrete_value_link { discreteValueNames = dv_glasgow_coma_scale, text = "Glasgow Coma Score" }
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
    --[[
    elif subtitle == "Possible Type 2 Diabetes Mellitus with Ketoacidosis with Coma" and e1111Code is not None:
        #11.1/12.1
        if e1111Code is not None: dc.Links.Add(e1111Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    --]]
    --[[
    elif DKA >= 1 and DKACheck and (SoC or r4020Code is not None) and unspecTypeIIDiabetes is not None and e1111Code is None:
        #11
        dc.Links.Add(unspecTypeIIDiabetes)
        if r4020Code is not None: dc.Links.Add(r4020Code)
        DKAAlertPassed = True
        result.Subtitle = "Possible Type 2 Diabetes Mellitus with Ketoacidosis with Coma"
        AlertPassed = True
    --]]
    --[[
    elif (SoC or r4020Code is not None) and e1110Code is not None and e1111Code is None:
        #12
        dc.Links.Add(e1110Code)
        if r4020Code is not None: dc.Links.Add(r4020Code)
        DKAAlertPassed = True
        result.Subtitle = "Possible Type 2 Diabetes Mellitus with Ketoacidosis with Coma"
        AlertPassed = True
    --]]
    --[[
    elif subtitle == "Possible Type 2 Diabetes Mellitus with Hyperosmolarity with Coma" and e1101Code is not None:
        #13.1
        if e1101Code is not None: dc.Links.Add(e1101Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    --]]
    --[[
    elif e1165Code is not None and (SoC or r4020Code is not None) and elevatedSerumOsmolalityDV is not None and e1101Code is None:
        #13
        dc.Links.Add(e1165Code)
        if r4020Code is not None: dc.Links.Add(r4020Code)
        HHNSAlertPassed = True
        result.Subtitle = "Possible Type 2 Diabetes Mellitus with Hyperosmolarity with Coma"
        AlertPassed = True
    --]]
    --[[
    elif subtitle == "Possible Type 2 Diabetes Mellitus with Hyperosmolarity without Coma" and e1101Code is not None:
        #14.1
        if e1101Code is not None: dc.Links.Add(e1101Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    --]]
    --[[
    elif e1165Code is not None and (SoC is False and r4020Code is None) and elevatedSerumOsmolalityDV is not None and e1101Code is None:
        #14
        dc.Links.Add(e1165Code)
        if r4020Code is not None: dc.Links.Add(r4020Code)
        HHNSAlertPassed = True
        result.Subtitle = "Possible Type 2 Diabetes Mellitus with Hyperosmolarity without Coma"
        AlertPassed = True        
    --]]
    --[[
    elif subtitle == "Possible Type 2 Diabetes Mellitus with Ketoacidosis without Coma" and (e1100Code is not None or e1101Code is not None):
        #15.1
        if e1110Code is not None: updateLinkText(e1110Code, autoCodeText); dc.Links.Add(e1110Code)
        if e1111Code is not None: dc.Links.Add(e1111Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    --]]
    --[[
    elif (SoC is False and r4020Code is None) and DKA >= 1 and DKACheck and unspecTypeIIDiabetes is not None and e1110Code is None and e1111Code is None:
        #15
        dc.Links.Add(unspecTypeIIDiabetes)
        DKAAlertPassed = True
        result.Subtitle = "Possible Type 2 Diabetes Mellitus with Ketoacidosis without Coma"
        AlertPassed = True
    --]]
    --[[
    elif subtitle == "Possible Type 2 Diabetes Mellitus with Hypoglycemia with Coma" and e11641Code is not None:
        #16.1/17.1
        if e11641Code is not None: dc.Links.Add(e11641Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    --]]
    --[[
    elif unspecTypeIIDiabetes is not None and (r4020Code is not None or SoC) and len(lowBloodGlucoseDV or noLabs) > 1 and e11641Code is None:
        #16
        dc.Links.Add(unspecTypeIIDiabetes)
        if r4020Code is not None: dc.Links.Add(r4020Code)
        for entry in lowBloodGlucoseDV:
            bloodGlucose.Links.Add(entry)
        if bloodGlucose.Links: dc.Links.Add(bloodGlucose)
        result.Subtitle = "Possible Type 2 Diabetes Mellitus with Hypoglycemia with Coma"
        AlertPassed = True
    --]]
    --[[
    elif e11649Code is not None and (SoC or r4020Code is not None) and e11641Code is None:
        #17
        dc.Links.Add(e11649Code)
        if r4020Code is not None: dc.Links.Add(r4020Code)
        result.Subtitle = "Possible Type 2 Diabetes Mellitus with Hypoglycemia with Coma"
        AlertPassed = True
    --]]
    --[[
    elif unspecTypeIDiabetes is not None and unspecTypeIIDiabetes is not None:
        #18
        dc.Links.Add(unspecTypeIDiabetes)
        dc.Links.Add(unspecTypeIIDiabetes)
        result.Subtitle = "Conflicting Diabetes Type 1 and Diabetes Type 2 Dx"
        AlertPassed = True
    --]]
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            --[[
            #Abs
            if HHNSAlertPassed: r4182Code = codeValue("R41.82", "Altered Level Of Consciousness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
            if HHNSAlertPassed: alteredAbs = abstractValue("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level Of Consciousness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2)
            if HHNSAlertPassed: 
                if r4182Code is not None:
                    abs.Links.Add(r4182Code)
                    if alteredAbs is not None: alteredAbs.Hidden = True; abs.Links.Add(alteredAbs)
                elif r4182Code is None and alteredAbs is not None:
                    abs.Links.Add(alteredAbs)
            if DKAAlertPassed: codeValue("G93.6", "Cerebral Edema: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, abs, True)
            codeValue("R41.0", "Confusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, abs, True)
            if HHNSAlertPassed: abstractValue("EXTREME_THIRST","Extreme Thirst: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5, abs, True)
            if DKAAlertPassed: codeValue("R53.83", "Fatigue: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, abs, True)
            abstractValue("FRUITY_BREATH","Fruity Breath '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7, abs, True)
            codeValue("Z90.410", "History of Pancreatectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8, abs, True)
            codeValue("Z90.411", "History of Partial Pancreatectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, abs, True)
            if DKAAlertPassed: codeValue("E87.6", "Hypokalemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, abs, True)
            abstractValue("INCREASED_URINARY_FREQUENCY","Increased Urinary Frequency: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11, abs, True)
            if DKAAlertPassed and r824Code is not None: abs.Links.Add(r824Code) #12
            dvOxygenCheck(dict(maindiscreteDic), dvOxygenTherapy, "Oxygen Therapy: [VALUE] (Result Date: [RESULTDATETIME])", 13, abs, True)
            if HHNSAlertPassed: codeValue("R63.1", "Polydipsia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, abs, True)
            if HHNSAlertPassed: abstractValue("PSYCHOSIS","Psychosis: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 15, abs, True)
            abstractValue("SEIZURE", "Seizure: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 15, abs, True)
            if DKAAlertPassed: abstractValue("SHORTNESS_OF BREATH","Shortness of Breath '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 16, abs, True)
            if HHNSAlertPassed: codeValue("R47.81", "Slurred Speech: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17, abs, True)
            if HHNSAlertPassed: codeValue("R11.10", "Vomiting: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, abs, True)
            if DKAAlertPassed: abstractValue("VOMITING","Vomiting '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 19, abs, True)
            if HHNSAlertPassed: codeValue("R11.11", "Vomiting without Nausea: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20, abs, True)
            --]]

            --[[

            #Coma
            if decrLvlConsciousnessAbs is not None: coma.Links.Add(decrLvlConsciousnessAbs) #1
            if glasgowComaScoreDV is not None: coma.Links.Add(glasgowComaScoreDV) #2
            if glasgowComaScoreAbs is not None: coma.Links.Add(glasgowComaScoreAbs) #3
            if a5a193Codes is not None: coma.Links.Add(a5a193Codes) #4
            if obtundedAbs is not None: coma.Links.Add(obtundedAbs) #5
            if a0bh18ezCode is not None: coma.Links.Add(a0bh18ezCode) #6
            if r401Code is not None: coma.Links.Add(r401Code) #8
            --]]

            --[[

            #Labs
            if DKAAlertPassed: dvValue(dvAcetone, "Acetone: [VALUE] (Result Date: [RESULTDATETIME])", calcAcetone1, 1, labs, True)
            if DKAAlertPassed: dvValue(dvAnionGap, "Anion Gap: [VALUE] (Result Date: [RESULTDATETIME])", calcAnionGap1, 2, labs, True)
            if DKAAlertPassed: abstractValue("ANION_GAP","Anion Gap: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3, labs, True)
            if DKAAlertPassed and lowArterialBloodPHDV is not None: labs.Links.Add(lowArterialBloodPHDV) #4
            if DKAAlertPassed and BetaHydroxybutyrateDV is not None: labs.Links.Add(BetaHydroxybutyrateDV) #5
            if DKAAlertPassed and serumBicarbonateDV is not None: labs.Links.Add(serumBicarbonateDV) #6
            if DKAAlertPassed: abstractValue("LOW_SERUM_BICABONATE", "Arterial Blood PH: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7, labs, True)
            if DKAAlertPassed: abstractValue("HIGH_BLOOD_GLUCOSE_DKA", "Blood Glucose: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, labs, True)
            if DKAAlertPassed: abstractValue("HIGH_BLOOD_GLUCOSE_DKA","Blood Glucose: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, labs, True)
            if HHNSAlertPassed and elevatedSerumOsmolalityDV is not None: labs.Links.Add(elevatedSerumOsmolalityDV) #10
            if DKAAlertPassed: abstractValue("LOW_SERUM_POTASSIUM","Serum Potassium '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11, labs, True)
            if DKAAlertPassed and urineKetonesDV is not None: labs.Links.Add(urineKetonesDV) #12
            if DKAAlertPassed and serumKetonesDV is not None: labs.Links.Add(serumKetonesDV) #13
            --]]

            --[[

            #Labs Subheadings
            if DKAAlertPassed and highBloodGlucoseDKADV is not None:
                for entry in highBloodGlucoseDKADV:
                    bloodGlucose.Links.Add(entry)
            if HHNSAlertPassed and highBloodGlucoseHHNSDV is not None:
                for entry in highBloodGlucoseHHNSDV:
                    bloodGlucose.Links.Add(entry)
            --]]

            --[[

            #Meds
            medValue("Albumin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, meds, True)
            medValue("Anti-Hypoglycemic Agent", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 2, meds, True)
            medValue("Dextrose 50%", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 3, meds, True)
            medValue("Fluid Bolus", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 4, meds, True)
            abstractValue("FLUID_BOLUS","Fluid Bolus '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5, meds, True)
            medValue("Insulin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 6, meds, True)
            abstractValue("INSULIN_ADMINISTRATION","Insulin Administration '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7, meds, True)
            medValue("Sodium Bicarbonate", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 8, meds, True)
            abstractValue("SODIUM_BICARBONATE","Sodium Bicarbonate '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, meds, True)
            --]]

            --[[

            #Vitals
            if HHNSAlertPassed: dvValue(dvTemperature, "Fever: [VALUE] (Result Date: [RESULTDATETIME])", calcTemperature1, 1, vitals, True)
            dvValue(dvHeartRate, "Heart Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcHeartRate1, 2, vitals, True)
            --]]
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

