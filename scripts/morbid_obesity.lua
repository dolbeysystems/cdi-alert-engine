---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Morbid Obesity
---
--- This script checks an account to see if it matches the criteria for a morbid obesity alert.
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
local headers = require("libs.common.headers")(Account)



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local dv_arterial_blood_c02 = { "CO2 (mmol/L)", "PaCO2 (mmHg)" }
local calc_arterial_blood_c021 = function(dv_, num) return num > 50 end
local dv_arterial_blood_ph = { "pH" }
local calc_arterial_blood_ph1 = function(dv_, num) return num < 7.35 end
local dv_bmi = { "3.5 BMI Calculation (kg/m2)" }
local calc_bmi1 = function(dv_, num) return num >= 40.0 end
local calc_bmi2 = function(dv_, num) return num >= 35.0 and num < 40.0 end
local calc_bmi3 = function(dv_, num) return num < 35.0 end
local dv_glasgow_coma_scale = { "3.5 Neuro Glasgow Score" }
local calc_glasgow_coma_scale1 = function(dv_, num) return num < 15 end
local dv_pa_o2 = { "BLD GAS O2 (mmHg)", "PO2 (mmHg)" }
local calc_pa_o21 = function(dv_, num) return num < 80 end
local dv_ph = { "pH (VENOUS)", "pH VENOUS" }
local calc_ph1 = function(dv_, num) return num < 7.30 end
local dv_serum_bicarbonate = { "HCO3 BldA-sCnc (mmol/L)", "CO2 SerPl-sCnc (mmol/L)", "CO2 (SAH) (mmol/L)" }
local calc_serum_bicarbonate1 = function(dv_, num) return num > 30 end
local dv_spo2 = { "Pulse Oximetry(Num) (%)" }
local calc_spo21 = function(dv_, num) return num < 90 end
local dv_venous_blood_co2 = { "BLD GAS CO2 VEN (mmHg)" }
local calc_venous_blood_co2 = function(dv_, num) return num > 55 end



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = Result.script_name }
local subtitle = existing_alert and existing_alert.subtitle or nil

local link_text1 = "Possibly Missing BMI to meet Morbid Obesity Criteria"
local link_text2 = "Possibly Missing Sign of Hypoventilation"
local message1 = false
local message2 = false

if existing_alert then
    for _, alert_link in ipairs(existing_alert.links) do
        if alert_link.link_text == "Alert Trigger(s)" then
            for _, links in ipairs(alert_link.links) do
                if links.link_text == link_text1 then
                    message1 = true
                end
                if links.link_text == link_text2 then
                    message2 = true
                end
            end
        end
    end
end



if not existing_alert or not existing_alert.validated then
    --------------------------------------------------------------------------------
    --- Header Variables and Helper Functions
    --------------------------------------------------------------------------------
    local result_links = {}
    local documented_dx_header = headers.make_header_builder("Documented Dx", 1)
    local oxygenation_ventilation_header = headers.make_header_builder("Oxygenation/Ventilation", 2)
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 3)
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 4)
    local morbidity_header = headers.make_header_builder("Obesity Co-Morbidities", 5)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 6)

    local function compile_links()
        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, oxygenation_ventilation_header:build(true))
        table.insert(result_links, morbidity_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Negations
    local pregnancy_negation = codes.get_code_prefix_link { prefix = "O", text = "Pregnancy Negation" }
    local pregnancy_negation2 = codes.get_code_prefix_link { prefix = "Z3A", text = "Pregnancy Negation" }
    local pneumonia_negations1 = links.get_code_links {
        codes = { "A01.03", "A02.22", "A21.2", "A22.1", "A42.0", "A43.0", "A54.84", "B01.2", "B05.2", "B06.81", "B25.0", "B37.1", "B38.0", "B39.0", "B44.0", "B44.1", "B58.3", "B59", "B77.81" },
        text = "Pneumonia Dx"
    }
    local pneumonia_negations2 = codes.get_code_prefix_link { prefix = "J12%.", text = "Pneumonia Dx" }
    local pneumonia_negations3 = codes.get_code_prefix_link { prefix = "J14%.", text = "Pneumonia Dx" }
    local pneumonia_negations4 = codes.get_code_prefix_link { prefix = "J15%.", text = "Pneumonia Dx" }
    local pneumonia_negations5 = links.get_code_link { code = "J16.0", text = "Pneumonia Dx" }
    local pneumonia_negations6 = codes.get_code_prefix_link { prefix = "J69%.", text = "Pneumonia Dx" }
    local pulmonary_edema_negation = links.get_code_links { codes = { "J81.0", "J81.1" }, text = "Pulmonary Edema Dx" }
    local pulmonary_embolism_negation = codes.get_code_prefix_link { prefix = "I26%.", text = "Pulmonary Embolism Dx" }
    local heart_failure_negation = links.get_code_links {
        codes = { "I50.21", "I50.23", "I50.31", "I50.33", "I50.41", "I50.43" },
        text = "Acute Heart Failure Dx"
    }
    local cardiac_arrest_negations = codes.get_code_prefix_link { prefix = "I46%.", text = "Cardiac Arrest Dx" }
    local r6521_negations = links.get_code_link { code = "R65.21", text = "Septic Shock Dx" }
    local shock_negations = codes.get_code_prefix_link { prefix = "R57%.", text = "Shock Dx" }
    local sepsis_negations1 = codes.get_code_prefix_link { prefix = "A40%.", text = "Sepsis Dx" }
    local sepsis_negations2 = codes.get_code_prefix_link { prefix = "A41%.", text = "Sepsis Dx" }
    local asthma_attack_negation = links.get_code_links { codes = { "J45.901", "J45.902" }, text = "Asthma Attack Dx" }
    local j441_negation = links.get_code_link { code = "J44.1", text = "COPD Exacerbation Dx" }
    local opioid_overdose_negation = links.get_abstraction_link { code = "OPIOID_OVERDOSE", text = "Opioid Overdose" }
    local glascow_coma_negation = links.get_discrete_value_link {
        discreteValueNames = dv_glasgow_coma_scale,
        text = "Arterial Blood CO2",
        predicate = calc_glasgow_coma_scale1
    }
    local encephalopathy_negation = links.get_code_links {
        codes = { "E51.2", "G31.2", "G92.8", "G93.41", "I67.4", "G92.9", "G93.41" },
        text = "Encephalopathy Dx"
    }
    local e669_negation = codes.get_code_link { code = "E66.9", text = "Obesity" }

    -- Alert Trigger
    local r0689_code = codes.get_code_link { code = "R06.89", text = "Hypoventilation" }
    local e662_code = codes.get_code_link { code = "E66.2", text = "Morbid (Severe) Obesity With Alveolar Hypoventilation" }
    local e6601_code = codes.get_code_link { code = "E66.01", text = "Morbid (Severe) Obesity Due To Excess Calories" }
    local e66811_code = codes.get_code_link { code = "E66.811", text = "Obesity, Class 1" }
    local e66812_code = codes.get_code_link { code = "E66.812", text = "Obesity, Class 2" }
    local e66813_code = codes.get_code_link { code = "E66.812", text = "Obesity, Class 3" }
    local bmi_gte40_codes = codes.get_multi_code_link {
        codes = { "Z68.41", "Z68.42", "Z68.43", "Z68.44", "Z68.45" },
        text = "BMI >or= 40"
    }
    local bmi_gte35_codes = codes.get_multi_code_link {
        codes = { "Z68.35", "Z68.36", "Z68.37", "Z68.38", "Z68.39" },
        text = "BMI"
    }
    local bmi_lt35_dv = links.get_discrete_value_link {
        discreteValueNames = dv_bmi,
        text = "BMI",
        predicate = calc_bmi3
    }
    local bmi_gte40_dv = links.get_discrete_value_link {
        discreteValueNames = dv_bmi,
        text = "BMI",
        predicate = calc_bmi1
    }
    local bmi_lt40_ge35_dv = links.get_discrete_value_link {
        discreteValueNames = dv_bmi,
        text = "BMI",
        predicate = calc_bmi2
    }
    local bmi_lt40_codes = codes.get_multi_code_link {
        codes = { "Z68.1", "Z68.20", "Z68.21", "Z68.22", "Z68.23", "Z68.24", "Z68.25", "Z68.26", "Z68.27", "Z68.28", "Z68.29", "Z68.3", "Z68.30", "Z68.31", "Z68.32", "Z68.33", "Z68.34", "Z68.35", "Z68.36", "Z68.37", "Z68.38", "Z68.39" },
        text = "BMI"
    }
    local bmi_lt35_codes = codes.get_multi_code_link {
        codes = { "Z68.1", "Z68.20", "Z68.21", "Z68.22", "Z68.23", "Z68.24", "Z68.25", "Z68.26", "Z68.27", "Z68.28", "Z68.29", "Z68.30", "Z68.31", "Z68.32", "Z68.33", "Z68.34" },
        text = "BMI"
    }
    local bmi_ge35l40_abs = links.get_abstraction_link {
        code = "HIGH_BMI_1",
        text = "BMI"
    }
    local bmi_ge40_abs = links.get_abstraction_link {
        code = "HIGH_BMI_2",
        text = "BMI"
    }
    local bmi_ge185l35_abs = links.get_abstraction_link {
        code = "MID_BMI",
        text = "BMI"
    }
    local bmi_lt185_abs = links.get_abstraction_link {
        code = "LOW_BMI",
        text = "BMI"
    }

    -- Co-Morbidities
    local coronary_artery_angina = codes.get_multi_code_link {
        codes = { "I25.110", "I25.111", "I25.112", "I25.118", "I25.119" },
        text = "Coronary Artery Disease with Angina"
    }
    local i2510_code = codes.get_code_link { code = "I25.10", text = "Coronary Artery Disease without Angina" }
    local e785_code = codes.get_code_link { code = "E78.5", text = "Hyperlipidemia" }
    local i10_code = codes.get_code_link { code = "I10", text = "Hypertension" }
    local hypertensive_chronic_kidney = codes.get_multi_code_link {
        codes = { "I12.0", "I12.9" },
        text = "Hypertensive Chronic Kidney Disease"
    }
    local hypertensive_heart_chronic_kidney = codes.get_multi_code_link {
        codes = { "I13.0", "I13.10", "I13.11", "I13.2" },
        text = "Hypertensive Heart and Chronic Kidney Disease"
    }
    local hypertensive_heart = codes.get_multi_code_link {
        codes = { "E11.0", "E11.9" },
        text = "Hypertensive Heart Disease"
    }
    local k760_code = codes.get_code_link { code = "K76.0", text = "Non-Alcoholic Fatty Liver Disease (NAFLD)" }
    local g4733_code = codes.get_code_link { code = "G47.33", text = "Obstructive Sleep Apnea (OSA)" }
    local osteoarthritis = codes.get_multi_code_link { codes = { "M19.90", "M19.93" }, text = "Osteoarthritis" }
    local osteoarthritis_hip = codes.get_multi_code_link { codes = { "M16.6", "M16.7", "M16.9" }, text = "Osteoarthritis of Hip" }
    local osteoarthritis_knee = codes.get_multi_code_link { codes = { "M17.4", "M17.5", "M17.9" }, text = "Osteoarthritis of Knee" }
    local a4730_code = codes.get_code_link { code = "A47.30", text = "Sleep Apnea" }
    local type2_diabetes_abs = links.get_abstraction_link {
        code = "DIABETES_TYPE_2",
        text = "Type 2 Diabetes"
    }

    -- Labs
    local arterial_blood_co2_dv = links.get_discrete_value_link {
        discreteValueNames = dv_arterial_blood_c02,
        text = "PaCO2",
        predicate = calc_arterial_blood_c021
    }
    local venous_blood_co2_dv = links.get_discrete_value_link {
        discreteValueNames = dv_venous_blood_co2,
        text = "Venous Blood C02",
        predicate = calc_venous_blood_co2
    }

    -- Oxygen
    local non_invasive_mechanical_ventilation = links.get_abstraction_link {
        code = "NON_INVASIVE_VENTILATION",
        text = "Non-Invasive Ventilation"
    }
    local invasive_mechanical_ventilation = codes.get_multi_code_link {
        codes = { "5A1935Z", "5A1945Z", "5A1955Z" },
        text = "Invasive Mechanical Ventilation"
    }

    -- Alert Checks
    local negation =
        pneumonia_negations1 or
        pneumonia_negations2 or
        pneumonia_negations3 or
        pneumonia_negations4 or
        pneumonia_negations5 or
        pneumonia_negations6 or
        pulmonary_edema_negation or
        pulmonary_embolism_negation or
        heart_failure_negation or
        cardiac_arrest_negations or
        r6521_negations or
        shock_negations or
        sepsis_negations1 or
        sepsis_negations2 or
        asthma_attack_negation or
        j441_negation or
        opioid_overdose_negation or
        glascow_coma_negation or
        encephalopathy_negation

    -- Co-Morbitities Count and Abstraction
    local comorbidity =
        (coronary_artery_angina and 1 or 0) +
        (i2510_code and 1 or 0) +
        (e785_code and 1 or 0) +
        (i10_code and 1 or 0) +
        (hypertensive_chronic_kidney and 1 or 0) +
        (hypertensive_heart_chronic_kidney and 1 or 0) +
        (hypertensive_heart and 1 or 0) +
        (k760_code and 1 or 0) +
        (g4733_code and 1 or 0) +
        (osteoarthritis and 1 or 0) +
        (osteoarthritis_hip and 1 or 0) +
        (osteoarthritis_knee and 1 or 0) +
        (a4730_code and 1 or 0) +
        (type2_diabetes_abs and 1 or 0)

    morbidity_header:add_link(coronary_artery_angina)
    morbidity_header:add_link(i2510_code)
    morbidity_header:add_link(e785_code)
    morbidity_header:add_link(i10_code)
    morbidity_header:add_link(hypertensive_chronic_kidney)
    morbidity_header:add_link(hypertensive_heart_chronic_kidney)
    morbidity_header:add_link(hypertensive_heart)
    morbidity_header:add_link(k760_code)
    morbidity_header:add_link(g4733_code)
    morbidity_header:add_link(osteoarthritis)
    morbidity_header:add_link(osteoarthritis_hip)
    morbidity_header:add_link(osteoarthritis_knee)
    morbidity_header:add_link(a4730_code)
    morbidity_header:add_link(type2_diabetes_abs)



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if pregnancy_negation or pregnancy_negation2 then
        Result.passed = false

    elseif
        subtitle == "Morbid Obesity with Alveolar Hypoventilation Dx Lacking Supporting Evidence" and
        (
            (
                bmi_gte40_codes or bmi_gte40_dv or bmi_ge40_abs or
                ((bmi_gte35_codes or bmi_lt40_ge35_dv or bmi_ge35l40_abs) and comorbidity > 0) and message1
            ) or
            (
                (
                    non_invasive_mechanical_ventilation or invasive_mechanical_ventilation or
                    r0689_code or arterial_blood_co2_dv or venous_blood_co2_dv
                ) and message2
            )
        )
    then
        -- 1.1
        if message1 then
            if bmi_gte40_codes then
                bmi_gte40_codes.link_text = "Autoresolved Code - " .. bmi_gte40_codes.link_text
                documented_dx_header:add_link(bmi_gte40_codes)
            end
            if bmi_ge40_abs then
                bmi_ge40_abs.link_text = "Autoresolved Evidence - " .. bmi_ge40_abs.link_text
                documented_dx_header:add_link(bmi_ge40_abs)
            end
            if bmi_gte40_dv then
                bmi_gte40_dv.link_text = "Autoresolved Evidence - " .. bmi_gte40_dv.link_text
                documented_dx_header:add_link(bmi_gte40_dv)
            end
            if bmi_gte35_codes then
                bmi_gte35_codes.link_text = "Autoresolved Code - " .. bmi_gte35_codes.link_text
                documented_dx_header:add_link(bmi_gte35_codes)
            end
            if bmi_ge35l40_abs then
                bmi_ge35l40_abs.link_text = "Autoresolved Evidence - " .. bmi_ge35l40_abs.link_text
                documented_dx_header:add_link(bmi_ge35l40_abs)
            end
            if bmi_lt40_ge35_dv then
                bmi_lt40_ge35_dv.link_text = "Autoresolved Evidence - " .. bmi_lt40_ge35_dv.link_text
                documented_dx_header:add_link(bmi_lt40_ge35_dv)
            end
            documented_dx_header:add_text_link(link_text1)
        end
        if message2 then
            documented_dx_header:add_text_link(link_text2)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = false

    elseif
        e662_code and
        ((not bmi_gte40_codes and not bmi_gte40_dv and not bmi_ge40_abs) or (not bmi_gte35_codes and not bmi_lt40_ge35_dv and not bmi_ge35l40_abs and comorbidity == 0)) and
        (not non_invasive_mechanical_ventilation and not invasive_mechanical_ventilation and r0689_code and not arterial_blood_co2_dv and not venous_blood_co2_dv)
    then
        -- 1
        if e662_code then
            documented_dx_header:add_link(e662_code)
        end
        if
            (not bmi_gte40_codes and not bmi_gte40_dv and not bmi_ge40_abs) or
            (not bmi_gte35_codes and not bmi_lt40_ge35_dv and not bmi_ge35l40_abs and comorbidity == 0)
        then
            documented_dx_header:add_text_link(link_text1)
        end
        if
            not non_invasive_mechanical_ventilation and
            not invasive_mechanical_ventilation and
            r0689_code and
            not arterial_blood_co2_dv and
            not venous_blood_co2_dv
        then
            documented_dx_header:add_text_link(link_text2)
        end
        Result.subtitle = "Morbid Obesity with Alveolar Hypoventilation Dx Lacking Supporting Evidence"
        Result.passed = true

    elseif
        subtitle == "Morbid (Severe) Obesity Documented, but BMI Criteria Not Met" and
        (
            bmi_gte40_codes or bmi_gte40_dv or bmi_ge40_abs or
            ((bmi_gte35_codes or bmi_lt40_ge35_dv or bmi_ge35l40_abs) and comorbidity > 0)
        )
    then
        -- 2.1
        if bmi_gte40_codes then
            bmi_gte40_codes.link_text = "Autoresolved Code - " .. bmi_gte40_codes.link_text
            documented_dx_header:add_link(bmi_gte40_codes)
        end
        if bmi_ge40_abs then
            bmi_ge40_abs.link_text = "Autoresolved Evidence - " .. bmi_ge40_abs.link_text
            documented_dx_header:add_link(bmi_ge40_abs)
        end
        if bmi_gte40_dv then
            bmi_gte40_dv.link_text = "Autoresolved Evidence - " .. bmi_gte40_dv.link_text
            documented_dx_header:add_link(bmi_gte40_dv)
        end
        if bmi_gte35_codes then
            bmi_gte35_codes.link_text = "Autoresolved Code - " .. bmi_gte35_codes.link_text
            documented_dx_header:add_link(bmi_gte35_codes)
        end
        if bmi_ge35l40_abs then
            bmi_ge35l40_abs.link_text = "Autoresolved Evidence - " .. bmi_ge35l40_abs.link_text
            documented_dx_header:add_link(bmi_ge35l40_abs)
        end
        if bmi_lt40_ge35_dv then
            bmi_lt40_ge35_dv.link_text = "Autoresolved Evidence - " .. bmi_lt40_ge35_dv.link_text
            documented_dx_header:add_link(bmi_lt40_ge35_dv)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        (e662_code or e6601_code) and
        (
            ((bmi_gte35_codes or bmi_lt40_ge35_dv or bmi_ge35l40_abs) and comorbidity == 0) or
            (bmi_lt35_codes or bmi_lt35_dv) or
            (
                not bmi_lt40_codes and
                not bmi_gte35_codes and
                not bmi_lt35_codes and
                not bmi_lt40_ge35_dv and
                not bmi_lt35_dv
            )
        ) and
        not bmi_gte40_dv and
        not bmi_gte40_codes and not bmi_ge40_abs
    then
        -- 2
        if e662_code then documented_dx_header:add_link(e662_code) end
        if e6601_code then documented_dx_header:add_link(e6601_code) end
        if bmi_gte40_codes then documented_dx_header:add_link(bmi_gte40_codes) end
        if bmi_lt35_codes then documented_dx_header:add_link(bmi_lt35_codes) end
        if bmi_lt35_dv then documented_dx_header:add_link(bmi_lt35_dv) end
        if bmi_gte35_codes then documented_dx_header:add_link(bmi_gte35_codes) end
        if bmi_ge35l40_abs then documented_dx_header:add_link(bmi_ge35l40_abs) end
        if bmi_lt40_ge35_dv then documented_dx_header:add_link(bmi_lt40_ge35_dv) end
        if bmi_lt185_abs then documented_dx_header:add_link(bmi_lt185_abs) end
        if bmi_ge185l35_abs then documented_dx_header:add_link(bmi_ge185l35_abs) end
        if bmi_ge35l40_abs then documented_dx_header:add_link(bmi_ge35l40_abs) end
        Result.subtitle = "Morbid (Severe) Obesity Documented, but BMI Criteria Not Met"
        Result.passed = true

    elseif subtitle == "Possible Morbid (Severe) Obesity with Hypoventilation" and e662_code then
        -- 3.1
        if e662_code then
            e662_code.link_text = "Autoresolved Code - " .. e662_code.link_text
            documented_dx_header:add_link(e662_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        not e662_code and
        (
            bmi_gte40_codes or bmi_gte40_dv or bmi_ge40_abs or
            ((bmi_gte35_codes or bmi_lt40_ge35_dv or bmi_ge35l40_abs) and comorbidity > 0)
        ) and
        (
            non_invasive_mechanical_ventilation or invasive_mechanical_ventilation or
            r0689_code or arterial_blood_co2_dv or venous_blood_co2_dv
        ) and not negation
    then
        -- 3
        documented_dx_header:add_link(bmi_gte40_codes)
        documented_dx_header:add_link(bmi_ge40_abs)
        documented_dx_header:add_link(bmi_gte40_dv)
        documented_dx_header:add_link(bmi_gte35_codes)
        documented_dx_header:add_link(bmi_ge35l40_abs)
        documented_dx_header:add_link(bmi_lt40_ge35_dv)
        Result.subtitle = "Possible Morbid (Severe) Obesity with Hypoventilation"
        Result.passed = false

    elseif
        (e6601_code or e662_code or e669_negation or e66811_code or e66812_code or e66813_code) and
        subtitle == "Possible Morbid (Severe) Obesity"
    then
        if e6601_code then
            e6601_code.link_text = "Autoresolved Code - " .. e6601_code.link_text
            documented_dx_header:add_link(e6601_code)
        end
        if e662_code then
            e662_code.link_text = "Autoresolved Code - " .. e662_code.link_text
            documented_dx_header:add_link(e662_code)
        end
        if e669_negation then
            e669_negation.link_text = "Autoresolved Code - " .. e669_negation.link_text
            documented_dx_header:add_link(e669_negation)
        end
        if e66811_code then
            e66811_code.link_text = "Autoresolved Code - " .. e66811_code.link_text
            documented_dx_header:add_link(e66811_code)
        end
        if e66812_code then
            e66812_code.link_text = "Autoresolved Code - " .. e66812_code.link_text
            documented_dx_header:add_link(e66812_code)
        end
        if e66813_code then
            e66813_code.link_text = "Autoresolved Code - " .. e66813_code.link_text
            documented_dx_header:add_link(e66813_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to a fully specified code now existing on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        not e669_negation and
        not e6601_code and
        not e662_code and
        not e66811_code and
        not e66812_code and
        not e66813_code and
        not (bmi_gte40_codes or bmi_gte40_dv or bmi_ge40_abs)
    then
        if bmi_gte40_codes then documented_dx_header:add_link(bmi_gte40_codes) end
        if bmi_ge40_abs then documented_dx_header:add_link(bmi_ge40_abs) end
        if bmi_gte40_dv then documented_dx_header:add_link(bmi_gte40_dv) end
        Result.subtitle = "Possible Morbid (Severe) Obesity"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Clinical Evidence
            clinical_evidence_header:add_code_one_of_link({ "Z68.41", "Z68.42", "Z68.43", "Z68.44", "Z68.45" }, "BMI")
            clinical_evidence_header:add_code_one_of_link({ "Z68.35", "Z68.36", "Z68.37", "Z68.38", "Z68.39" }, "BMI")
            clinical_evidence_header:add_abstraction_link(
                "DECREASED_FUNCTIONAL_CAPACITY",
                "Decreased Functional Capacity"
            )
            clinical_evidence_header:add_abstraction_link("DIAPHORETIC", "Diaphoretic")
            clinical_evidence_header:add_abstraction_link("DYSPNEA_ON_EXERTION", "Dyspnea on Exertion")
            clinical_evidence_header:add_abstraction_link("HEIGHT", "Height")
            clinical_evidence_header:add_code_link("G47.33", "Obstructive Sleep Apnea")
            clinical_evidence_header:add_abstraction_link("RESPIRATORY_ACIDOSIS", "Respiratory Acidosis")
            clinical_evidence_header:add_abstraction_link("SHORTNESS_OF_BREATH", "Shortness of Breath")
            clinical_evidence_header:add_code_link("G47.30", "Sleep Apnea")
            clinical_evidence_header:add_abstraction_link("WEIGHT", "Weight")
            if arterial_blood_co2_dv then laboratory_studies_header:add_link(arterial_blood_co2_dv) end
            laboratory_studies_header:add_discrete_value_one_of_link(dv_pa_o2, "Pa02", calc_pa_o21)
            local arterial_blood = links.get_discrete_value_link {
                discreteValueNames = dv_arterial_blood_ph,
                text = "Blood PH",
                predicate = calc_arterial_blood_ph1
            }
            if arterial_blood then
                laboratory_studies_header:add_link(arterial_blood)
            else
                laboratory_studies_header:add_discrete_value_one_of_link(dv_ph, "PH", calc_ph1)
            end
            laboratory_studies_header:add_code_link("R09.02", "Hypoxemia")
            laboratory_studies_header:add_discrete_value_one_of_link(dv_spo2, "SpO2", calc_spo21)
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_serum_bicarbonate,
                "Serum Bicarbonate",
                calc_serum_bicarbonate1
            )
            laboratory_studies_header:add_link(venous_blood_co2_dv)

            -- Oxygen
            oxygenation_ventilation_header:add_code_link("Z99.81", "Home Oxygen Use")
            oxygenation_ventilation_header:add_link(invasive_mechanical_ventilation)
            oxygenation_ventilation_header:add_code_link("3E0F7SF", "Nasal Cannula")
            oxygenation_ventilation_header:add_link(non_invasive_mechanical_ventilation)
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

