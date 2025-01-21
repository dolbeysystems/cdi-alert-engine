---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Malnutrition
---
--- This script checks an account to see if it matches the criteria for a malnutrition alert.
---
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
---------------------------------------------------------------------------------------------------------------------



-------------------------------------------------------------------------------
--- Requires
-------------------------------------------------------------------------------
local alerts = require("libs.common.alerts")(Account)
local links = require("libs.common.basic_links")(Account)
local codes = require("libs.common.codes")(Account)
local headers = require("libs.common.headers")(Account)
local lists = require("libs.common.lists")
local cdi_alert_link = require "cdi.link"



-------------------------------------------------------------------------------
--- Script Specific Functions
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--- Returns a link for a caution code
---
--- @param code string The code to get the link for
--- @param text string The text to display for the link
---
--- @return CdiAlertLink? - The link for the code
-------------------------------------------------------------------------------
local function get_non_caution_code_link(code, text)
    local caution_code_docs = {
        "Dietitian Progress Notes",
        "Nutrition MNT Follow-Up ADIME Note",
        "Clinical Nutrition",
        "Nutrition A-D-I-M-E Note",
        "Nutrition ADIME Initial Note",
        "Nutrition ADIME Follow Up Note"
    }
    for _, document in ipairs(Account.documents) do
        if not lists.some(caution_code_docs, function(dt) return dt == document.document_type end) then
            -- Not a caution code document
            for _, code_ in ipairs(document.code_references) do
                if code_ == code then
                    local link = cdi_alert_link()
                    link.document_id = document.document_id
                    link.code = code
                    link.link_text = text .. ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])"
                    link.link_text = links.replace_link_place_holders(link.link_text, code_, document, nil, nil)
                    return link
                end
            end
        end
    end
    return nil
end



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local dv_bmi = { "3.5 BMI Calculation (kg/m2)" }
local calc_bmi1 = function(dv_, num) return num > 0 and num < 18.5 end
local calc_bmi2 = function(dv_, num) return num > 18.5 end
local dv_lymphocyte_count = { "" }
local calc_lymphocyte_count1 = function(dv_, num) return num < 1 end
local dv_serum_calcium = { "CALCIUM (mg/dL)" }
local calc_serum_calcium1 = function(dv_, num) return num < 8.3 end
local calc_serum_calcium2 = function(dv_, num) return num > 10.2 end
local dv_serum_chloride = { "CHLORIDE (mmol/L)" }
local calc_serum_chloride1 = function(dv_, num) return num < 98 end
local calc_serum_chloride2 = function(dv_, num) return num > 110 end
local dv_serum_magnesium = { "MAGNESIUM (mg/dL)" }
local calc_serum_magnesium1 = function(dv_, num) return num < 1.6 end
local calc_serum_magnesium2 = function(dv_, num) return num > 2.5 end
local dv_serum_phosphate = { "PHOSPHATE (mg/dL)" }
local calc_serum_phosphate1 = function(dv_, num) return num < 2.7 end
local calc_serum_phosphate2 = function(dv_, num) return num > 4.5 end
local dv_serum_potassium = { "POTASSIUM (mmol/L)" }
local calc_serum_potassium1 = function(dv_, num) return num < 3.4 end
local calc_serum_potassium2 = function(dv_, num) return num > 5.1 end
local dv_serum_sodium = { "SODIUM (mmol/L)" }
local calc_serum_sodium1 = function(dv_, num) return num < 131 end
local calc_serum_sodium2 = function(dv_, num) return num > 145 end
local dv_total_cholesterol = { "CHOLESTEROL (mg/dL)", "CHOLESTEROL" }
local calc_total_cholesterol1 = function(dv_, num) return num < 200 end
local dv_transferrin = { "TRANSFERRIN" }
local calc_transferrin1 = function(dv_, num) return num < 215 end



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local auto_cc = false
local trigger_alert = false
local e40_triggered = false
local e41_triggered = false
local e42_triggered = false
local e43_triggered = false
local e440_triggered = false
local e441_triggered = false
local e45_triggered = false
local e46_triggered = false
local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }
local subtitle = existing_alert and existing_alert.subtitle or nil
if existing_alert then
    if existing_alert.outcome == 'AUTORESOLVED' or existing_alert.reason == 'Previously Autoresolved' then
        trigger_alert = false
    end
    if existing_alert.subtitle == "Possible Malnutrition" or existing_alert.subtitle == "Possible Low BMI" then
        for _, alert_link in existing_alert.links do
            if alert_link.link_text == "Documented Dx" then
                for _, link in ipairs(alert_link.links) do
                    if link.link_text:find("Caution Code - Kwashiorkor") then
                        e40_triggered = true
                    end
                    if link.link_text:find("Caution Code - Nutritional") then
                        e41_triggered = true
                    end
                    if link.link_text:find("Caution Code - Marasmic") then
                        e42_triggered = true
                    end
                    if link.link_text:find("Caution Code - Severe Protein-Calorie Malnutrition") then
                        e43_triggered = true
                    end
                    if link.link_text:find("Caution Code - Moderate") then
                        e440_triggered = true
                    end
                    if link.link_text:find("Caution Code - Mild") then
                        e441_triggered = true
                    end
                    if link.link_text:find("Caution Code - Retarded") then
                        e45_triggered = true
                    end
                    if link.link_text:find("Caution Code - Unspecified Protein-Calorie Malnutrition") then
                        e46_triggered = true
                    end
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
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 2)
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 3)
    local risk_factor_header = headers.make_header_builder("Risk Factor(s)", 4)
    local nutrition_note_header = headers.make_header_builder("Nutrition Note", 5)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 6)

    local function compile_links()
        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, risk_factor_header:build(true))
        table.insert(result_links, nutrition_note_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end


    --------------------------------------------------------------------------------
    --- Alert Variables
    --------------------------------------------------------------------------------
    local alert_code_dictionary = {
        ["E40"] = "Kwashiorkor",
        ["E41"] = "Nutritional Marasmus",
        ["E42"] = "Marasmic Kwashiorkor",
        ["E43"] = "Unspecified Severe Protein-Calorie Malnutrition",
        ["E44.0"] = "Moderate Protein-Calorie Malnutrition",
        ["E44.1"] = "Mild Protein-Calorie Malnutrition",
        ["E45"] = "Retarded Development Following Protein-Calorie Malnutrition"
    }
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)
    local ci = 0
    local cms40 = false
    local cms41 = false
    local cms441 = false
    local cms42 = false
    local cms43 = false
    local cms440 = false
    local cms45 = false



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Alert Trigger
    local e46_code = links.get_code_link { code = "E46", text = "Unspecified Protein-Calorie Malnutrition" }
    local r636_code = links.get_code_link { code = "R63.6", text = "Underweight" }
    local t730xxxa_code = links.get_code_link { code = "T73.0XXA", text = "Starvation" }
    local malnutrition_codes = links.get_code_link { codes = { "E40", "E41", "E42", "E43", "E44.0", "E44.1", "E45" }, text = "Malnutrition" }

    -- Clinical Evidence
    local r634_code = links.get_code_link { code = "R63.4", text = "Abnormal Weight Loss" }
    local r627_code = links.get_code_link { code = "R62.7", text = "Adult Failure to Thrive" }
    local low_bmi_abs = links.get_abstraction_value_link { code = "LOW_BMI", text = "BMI" }
    local low_bmi_dv = links.get_discrete_value_link { discreteValueNames = dv_bmi, text = "BMI", predicate = calc_bmi1 }
    local r64_code = links.get_code_link { code = "R64", text = "Cachexia" }
    local r601_code = links.get_code_link { code = "R60.1", text = "Generalized Edema" }
    local grip_strength_abs = links.get_abstraction_link { code = "GRIP_STRENGTH_REDUCED", text = "Reduced Grip Strength" }
    local loss_of_muscle_mass_mild_abs = links.get_abstraction_link { code = "LOSS_OF_MUSCLE_MASS_MILD", text = "Loss of Muscle Mass Mild" }
    local loss_of_muscle_mass_mod_abs = links.get_abstraction_link { code = "LOSS_OF_MUSCLE_MASS_MODERATE", text = "Loss of Muscle Mass Moderate" }
    local loss_of_muscle_mass_severe_abs = links.get_abstraction_link { code = "LOSS_OF_MUSCLE_MASS_SEVERE", text = "Loss of Muscle Mass Severe" }
    local loss_of_subcutaneous_fat_mild_abs = links.get_abstraction_link { code = "LOSS_OF_SUBCUTANEOUS_FAT_MILD", text = "Loss of Subcutaneous Fat Mild" }
    local loss_of_subcutaneous_fat_mod_abs = links.get_abstraction_link { code = "LOSS_OF_SUBCUTANEOUS_FAT_MODERATE", text = "Loss of Subcutaneous Fat Moderate" }
    local loss_of_subcutaneous_fat_severe_abs = links.get_abstraction_link { code = "LOSS_OF_SUBCUTANEOUS_FAT_SEVERE", text = "Loss of Subcutaneous Fat Severe" }
    local mod_fluid_accumulation_abs = links.get_abstraction_link { code = "MODERATE_FLUID_ACCUMULATION", text = "Moderate Fluid Accumulation" }
    local non_healing_wound_abs = links.get_abstraction_link { code = "NON_HEALING_WOUND", text = "Non Healing Wound" }
    local reduced_energy_intake_abs = links.get_abstraction_link { code = "REDUCED_ENERGY_INTAKE", text = "Reduced Energy Intake" }
    local reduced_energy_intake_severe_abs = links.get_abstraction_link { code = "REDUCED_ENERGY_INTAKE_SEVERE", text = "Reduced Energy Intake Severe" }
    local reduced_energy_intake_mod_abs = links.get_abstraction_link { code = "REDUCED_ENERGY_INTAKE_MODERATE", text = "Reduced Energy Intake Moderate" }
    local severe_fluid_accumulation_abs = links.get_abstraction_link { code = "SEVERE_FLUID_ACCUMULATION", text = "Severe Fluid Accumulation" }
    local unintentional_weight_loss_mild_abs = links.get_abstraction_link { code = "UNINTENTIONAL_WEIGHT_LOSS_MILD", text = "Unintentional Weight Loss Mild" }
    local unintentional_weight_loss_severe_abs = links.get_abstraction_link { code = "UNINTENTIONAL_WEIGHT_LOSS_SEVERE", text = "Unintentional Weight Loss Severe" }
    local unintentional_weight_loss_abs = links.get_abstraction_link { code = "UNINTENTIONAL_WEIGHT_LOSS", text = "Unintentional Weight Loss" }

    -- Doc Links
    nutrition_note_header:add_document_link("Dietitian Progress Notes", "Dietitian Progress Notes")
    nutrition_note_header:add_document_link("Nutrition MNT Follow-Up ADIME Note", "Nutrition MNT Follow-Up ADIME Note")
    nutrition_note_header:add_document_link("Clinical Nutrition", "Clinical Nutrition")
    nutrition_note_header:add_document_link("Nutrition A-D-I-M-E Note", "Nutrition A-D-I-M-E Note")
    nutrition_note_header:add_document_link("Nutrition ADIME Initial Note", "Nutrition ADIME Initial Note")
    nutrition_note_header:add_document_link("Nutrition ADIME Follow Up Note", "Nutrition ADIME Follow Up Note")

    -- Caution Code
    local e40 = links.get_code_link { code = "E40", text = "Caution Code - Kwashiorkor (MCC)" }
    local e41 = links.get_code_link { code = "E41", text = "Caution Code - Nutritional Marasmus (MCC)" }
    local e42 = links.get_code_link { code = "E42", text = "Caution Code - Marasmic Kwashiorkor (MCC)" }
    local e43 = links.get_code_link { code = "E43", text = "Caution Code - Severe Protein-Calorie Malnutrition (MCC)" }
    local e440 = links.get_code_link { code = "E44.0", text = "Caution Code - Moderate Protein-Calorie Malnutrition (CC)" }
    local e441 = links.get_code_link { code = "E44.1", text = "Caution Code - Mild Protein-Calorie Malnutrition (CC)" }
    local e45 = links.get_code_link { code = "E45", text = "Caution Code - Retarded Development Following Protein-Calorie Malnutrition (CC)" }
    local e46 = links.get_code_link { code = "E46", text = "Caution Code - Unspecified Protein-Calorie Malnutrition" }

    local e40_non_cc = get_non_caution_code_link("E40", "Caution Code - Kwashiorkor (MCC)")
    local e41_non_cc = get_non_caution_code_link("E41", "Caution Code - Nutritional Marasmus (MCC)")
    local e42_non_cc = get_non_caution_code_link("E42", "Caution Code - Marasmic Kwashiorkor (MCC)")
    local e43_non_cc = get_non_caution_code_link("E43", "Caution Code - Severe Protein-Calorie Malnutrition (MCC)")
    local e440_non_cc = get_non_caution_code_link("E44.0", "Caution Code - Moderate Protein-Calorie Malnutrition (CC)")
    local e441_non_cc = get_non_caution_code_link("E44.1", "Caution Code - Mild Protein-Calorie Malnutrition (CC)")
    local e45_non_cc = get_non_caution_code_link("E45", "Caution Code - Retarded Development Following Protein-Calorie Malnutrition (CC)")
    local e46_non_cc = get_non_caution_code_link("E46", "Caution Code - Unspecified Protein-Calorie Malnutrition")

    if loss_of_subcutaneous_fat_mild_abs or loss_of_subcutaneous_fat_mod_abs or loss_of_subcutaneous_fat_severe_abs then
        if loss_of_subcutaneous_fat_mild_abs then clinical_evidence_header:add_link(loss_of_subcutaneous_fat_mild_abs) end
        if loss_of_subcutaneous_fat_mod_abs then clinical_evidence_header:add_link(loss_of_subcutaneous_fat_mod_abs) end
        if loss_of_subcutaneous_fat_severe_abs then clinical_evidence_header:add_link(loss_of_subcutaneous_fat_severe_abs) end
        ci = ci + 1
    end
    if loss_of_muscle_mass_mild_abs or loss_of_muscle_mass_mod_abs or loss_of_muscle_mass_severe_abs then
        if loss_of_muscle_mass_mild_abs then clinical_evidence_header:add_link(loss_of_muscle_mass_mild_abs) end
        if loss_of_muscle_mass_mod_abs then clinical_evidence_header:add_link(loss_of_muscle_mass_mod_abs) end
        if loss_of_muscle_mass_severe_abs then clinical_evidence_header:add_link(loss_of_muscle_mass_severe_abs) end
        ci = ci + 1
    end
    if unintentional_weight_loss_mild_abs or unintentional_weight_loss_abs or unintentional_weight_loss_severe_abs then
        if unintentional_weight_loss_mild_abs then clinical_evidence_header:add_link(unintentional_weight_loss_mild_abs) end
        if unintentional_weight_loss_abs then clinical_evidence_header:add_link(unintentional_weight_loss_abs) end
        if unintentional_weight_loss_severe_abs then clinical_evidence_header:add_link(unintentional_weight_loss_severe_abs) end
        ci = ci + 1
    end
    if reduced_energy_intake_abs or reduced_energy_intake_mod_abs or reduced_energy_intake_severe_abs then
        if reduced_energy_intake_abs then clinical_evidence_header:add_link(reduced_energy_intake_abs) end
        if reduced_energy_intake_mod_abs then clinical_evidence_header:add_link(reduced_energy_intake_mod_abs) end
        if reduced_energy_intake_severe_abs then clinical_evidence_header:add_link(reduced_energy_intake_severe_abs) end
        ci = ci + 1
    end

    if r634_code then
        clinical_evidence_header:add_link(r634_code)
        ci = ci + 1
    end
    if grip_strength_abs then
        clinical_evidence_header:add_link(grip_strength_abs)
        ci = ci + 1
    end
    if non_healing_wound_abs then
        clinical_evidence_header:add_link(non_healing_wound_abs)
        ci = ci + 1
    end
    if r627_code then
        clinical_evidence_header:add_link(r627_code)
        ci = ci + 1
    end
    if r64_code then
        clinical_evidence_header:add_link(r64_code)
        ci = ci + 1
    end
    if r601_code then
        clinical_evidence_header:add_link(r601_code)
        ci = ci + 1
    end
    if severe_fluid_accumulation_abs then
        clinical_evidence_header:add_link(severe_fluid_accumulation_abs)
        ci = ci + 1
    end
    if mod_fluid_accumulation_abs then
        clinical_evidence_header:add_link(mod_fluid_accumulation_abs)
        ci = ci + 1
    end

    -- Determine Conflicting Malnutrition Severity
    cms40 = e40_non_cc ~= nil and (not e41_non_cc or not e42_non_cc or not e43_non_cc or not e440_non_cc or not e441_non_cc or not e45_non_cc)
    cms41 = e41_non_cc ~= nil and (not e40_non_cc or not e42_non_cc or not e43_non_cc or not e440_non_cc or not e441_non_cc or not e45_non_cc)
    cms42 = e42_non_cc ~= nil and (not e40_non_cc or not e41_non_cc or not e43_non_cc or not e440_non_cc or not e441_non_cc or not e45_non_cc)
    cms43 = e43_non_cc ~= nil and (not e40_non_cc or not e41_non_cc or not e42_non_cc or not e440_non_cc or not e441_non_cc or not e45_non_cc)
    cms440 = e440_non_cc ~= nil and (not e40_non_cc or not e41_non_cc or not e42_non_cc or not e43_non_cc or not e441_non_cc or not e45_non_cc)
    cms441 = e441_non_cc ~= nil and (not e40_non_cc or not e41_non_cc or not e42_non_cc or not e43_non_cc or not e440_non_cc or not e45_non_cc)
    cms45 = e45_non_cc ~= nil and (not e40_non_cc or not e41_non_cc or not e42_non_cc or not e43_non_cc or not e440_non_cc or not e441_non_cc)

    -- Check if Caution Coding is no longer present and if so autoresolve the alert.
    auto_cc =
        (e40_non_cc ~= nil and e40_triggered) or
        (e41_non_cc ~= nil and e41_triggered) or
        (e42_non_cc ~= nil and e42_triggered) or
        (e43_non_cc ~= nil and e43_triggered) or
        (e440_non_cc ~= nil and e440_triggered) or
        (e441_non_cc ~= nil and e441_triggered) or
        (e45_non_cc ~= nil and e45_triggered) or
        (e46_non_cc ~= nil and e46_triggered)



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    -- Main Algorithm
    -- #1
    if cms40 or cms41 or cms42 or cms43 or cms440 or cms441 or cms45 then
        if e40 and cms40 then clinical_evidence_header:add_link(e40) end
        if e41 and cms41 then clinical_evidence_header:add_link(e41) end
        if e42 and cms42 then clinical_evidence_header:add_link(e42) end
        if e43 and cms43 then clinical_evidence_header:add_link(e43) end
        if e440 and cms440 then clinical_evidence_header:add_link(e440) end
        if e441 and cms441 then clinical_evidence_header:add_link(e441) end
        if e45 and cms45 then clinical_evidence_header:add_link(e45) end

        if e40 and not e40_non_cc then clinical_evidence_header:add_link(e40) end
        if e41 and not e41_non_cc then clinical_evidence_header:add_link(e41) end
        if e42 and not e42_non_cc then clinical_evidence_header:add_link(e42) end
        if e43 and not e43_non_cc then clinical_evidence_header:add_link(e43) end
        if e440 and not e440_non_cc then clinical_evidence_header:add_link(e440) end
        if e441 and not e441_non_cc then clinical_evidence_header:add_link(e441) end
        if e45 and not e45_non_cc then clinical_evidence_header:add_link(e45) end

        Result.subtitle = "Conflicting Malnutrition Severity (Provider/RDN)"
        Result.passed = true
    elseif #account_alert_codes > 1 then
        for _, code in ipairs(account_alert_codes) do
            local desc = alert_code_dictionary[code]
            local temp_code = links.get_code_link { code = code, text = desc }
            clinical_evidence_header:add_link(temp_code)
        end
        Result.subtitle = "Conflicting Malnutrition Dx" .. table.concat(account_alert_codes, ", ")
        if existing_alert and existing_alert.validated then
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
            Result.validated = false
        end
        Result.passed = true

    elseif subtitle == "Malnutrition Missing Acuity" and #account_alert_codes == 1 then
        for _, code in ipairs(account_alert_codes) do
            local desc = alert_code_dictionary[code]
            local temp_code = links.get_code_link { code = code, text = "Autoresolved Specified Code - " .. desc }
            if temp_code then
                clinical_evidence_header:add_link(temp_code)
                break
            end
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif trigger_alert and #account_alert_codes == 0 and e46_code then
        clinical_evidence_header:add_link(e46_code)
        Result.subtitle = "Malnutrition Missing Acuity"
        Result.passed = true

    elseif subtitle == "Possible Malnutrition" and auto_cc and (#account_alert_codes > 0 or e46_code) then
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif trigger_alert and
        (e40 and not e40_non_cc) or
        (e41 and not e41_non_cc) or
        (e42 and not e42_non_cc) or
        (e43 and not e43_non_cc) or
        (e440 and not e440_non_cc) or
        (e441 and not e441_non_cc) or
        (e45 and not e45_non_cc) or
        (e46 and not e46_non_cc)
    then
        if e40 and not e40_non_cc then clinical_evidence_header:add_link(e40) end
        if e41 and not e41_non_cc then clinical_evidence_header:add_link(e41) end
        if e42 and not e42_non_cc then clinical_evidence_header:add_link(e42) end
        if e43 and not e43_non_cc then clinical_evidence_header:add_link(e43) end
        if e440 and not e440_non_cc then clinical_evidence_header:add_link(e440) end
        if e441 and not e441_non_cc then clinical_evidence_header:add_link(e441) end
        if e45 and not e45_non_cc then clinical_evidence_header:add_link(e45) end
        if e46 and not e46_non_cc then clinical_evidence_header:add_link(e46) end
        Result.subtitle = "Possible Malnutrition"
        Result.passed = true

    elseif
        subtitle == "Possible Low BMI" and
        (
            (r627_code or r634_code or r64_code or r636_code or t730xxxa_code or e46_code) or
            (malnutrition_codes and auto_cc)
        )
    then
        if r627_code then
            r627_code.link_text = "Autoresolved Specified Code - " .. r627_code.link_text
            clinical_evidence_header:add_link(r627_code)
        end
        if r634_code then
            r634_code.link_text = "Autoresolved Specified Code - " .. r634_code.link_text
            clinical_evidence_header:add_link(r634_code)
        end
        if r64_code then
            r64_code.link_text = "Autoresolved Specified Code - " .. r64_code.link_text
            clinical_evidence_header:add_link(r64_code)
        end
        if r636_code then
            r636_code.link_text = "Autoresolved Specified Code - " .. r636_code.link_text
            clinical_evidence_header:add_link(r636_code)
        end
        if t730xxxa_code then
            t730xxxa_code.link_text = "Autoresolved Specified Code - " .. t730xxxa_code.link_text
            clinical_evidence_header:add_link(t730xxxa_code)
        end
        if malnutrition_codes then
            malnutrition_codes.link_text = "Autoresolved Specified Code - " .. malnutrition_codes.link_text
            clinical_evidence_header:add_link(malnutrition_codes)
        end
        if e46_code then
            e46_code.link_text = "Autoresolved Specified Code - " .. e46_code.link_text
            clinical_evidence_header:add_link(e46_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one or more Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        trigger_alert and
        (low_bmi_dv or low_bmi_abs) and
        not r627_code and
        not e46_code and
        not r634_code and
        not r64_code and
        not r636_code and
        not t730xxxa_code and
        not malnutrition_codes
    then
        Result.subtitle = "Possible Low BMI"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Negations
            local transferrin_negation = links.get_code_links {
                codes = {
                    "K72.0", "K72.00", "K72.01", "K72.1", "K72.10", "K72.11", "K72.9", "K72.90",
                    "K72.91", "K74.4", "K74.5", "K74.6", "K74.60", "D59.13", "D59.19", "D59.2",
                    "D59.3", "D59.30", "D59.31", "D59.32", "D59.39", "D59.4", "D59.5", "D59.6",
                    "D59.8", "D59.9"
                },
                text = "Transferrin Negation"
            }
            local lymphocyte_count_negation = links.get_code_links {
                codes = {
                    "D60.0", "D60.1", "D60.8", "D60.9", "D61", "D61.0", "D61.01", "D61.09",
                    "D61.1", "D61.2", "D61.3", "D61.8", "D61.81", "D61.810", "D61.811",
                    "D61.818", "D61.82", "D61.89", "D61.9"
                },
                text = "Lymphocyte Count Negation"
            }

            -- Abstractions
            -- 1-2
            clinical_evidence_header:add_code_prefix_link("E54%.", "Ascorbic Acid Deficiency")
            -- 4
            if low_bmi_dv then
                clinical_evidence_header:add_link(low_bmi_dv) -- 5
            else
                clinical_evidence_header:add_discrete_value_one_of_link(
                    dv_bmi,
                    "BMI",
                    calc_bmi2
                )
            end
            if low_bmi_abs then
                clinical_evidence_header:add_link(low_bmi_abs) -- 6
            end
            clinical_evidence_header:add_abstraction_link("DECREASED_FUNCTIONAL_CAPACITY", "Decreased Functional Capacity")
            clinical_evidence_header:add_code_prefix_link("E53%.", "Deficiency of other B group Vitamins")
            clinical_evidence_header:add_code_prefix_link("E61%.", "Deficiency of other Nutrient Elements")
            clinical_evidence_header:add_abstraction_link("DIARRHEA", "Diarrhea")
            clinical_evidence_header:add_code_link("E58", "Dietary Calcium Deficiency")
            clinical_evidence_header:add_code_link("E59", "Dietary Selenium Deficiency")
            clinical_evidence_header:add_code_link("E60", "Dietary Zinc Deficiency")
            clinical_evidence_header:add_code_one_of_link({ "R13.10", "R13.11", "R13.12", "R13.13", "R13.14", "R13.19" }, "Dysphagia")
            clinical_evidence_header:add_code_link("R53.83", "Fatigue")
            clinical_evidence_header:add_abstraction_link("FEELING_COLD", "Feeling Cold")
            clinical_evidence_header:add_abstraction_link("FRAIL", "Frail")

            -- 18-19
            clinical_evidence_header:add_abstraction_link("HEIGHT", "Height")
            clinical_evidence_header:add_abstraction_link("LOW_FOOD_INTAKE", "Low Food Intake")

            -- 21-26
            clinical_evidence_header:add_abstraction_link("MALNOURISHED_SIGN", "Malnourished Sign")
            clinical_evidence_header:add_abstraction_link("MALNUTRITION_RISK_FACTORS", "Malnutrition Risk Factors")

            -- 30
            clinical_evidence_header:add_abstraction_link("MODERATE_MALNUTRITION", "Moderate Malnutrition")
            clinical_evidence_header:add_code_prefix_link("E52%.", "Niacin Deficiency")

            -- 33
            clinical_evidence_header:add_code_prefix_link("E63%.", "Other Nutritional Deficiencies")
            clinical_evidence_header:add_code_prefix_link("E56%.", "Other Vitamin Deficiency")

            -- 36-39
            clinical_evidence_header:add_abstraction_link("SEVERE_MALNUTRTION", "Severe Malnutrition")
            clinical_evidence_header:add_code_link("T73.0XXA", "Starvation")
            clinical_evidence_header:add_code_prefix_link("E51%.", "Thiamine Deficiency")

            -- 43-45
            clinical_evidence_header:add_code_prefix_link("E50%.", "Vitamin A Deficiency")
            clinical_evidence_header:add_code_prefix_link("E55%.", "Vitamin D Deficiency")
            clinical_evidence_header:add_code_link("R11.10", "Vomiting")
            clinical_evidence_header:add_abstraction_link("WEAKNESS", "Weakness")
            clinical_evidence_header:add_abstraction_link("WEIGHT", "Weight")

            -- Labs
            if lymphocyte_count_negation then
                laboratory_studies_header:add_discrete_value_one_of_link(
                    dv_lymphocyte_count,
                    "Lymphocyte Count",
                    calc_lymphocyte_count1
                )
            end
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_serum_calcium,
                "Serum Calcium",
                calc_serum_calcium1
            )
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_serum_calcium,
                "Serum Calcium",
                calc_serum_calcium2
            )
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_serum_chloride,
                "Serum Chloride",
                calc_serum_chloride1
            )
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_serum_chloride,
                "Serum Chloride",
                calc_serum_chloride2
            )
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_serum_magnesium,
                "Serum Magnesium",
                calc_serum_magnesium1
            )
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_serum_magnesium,
                "Serum Magnesium",
                calc_serum_magnesium2
            )
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_serum_phosphate,
                "Serum Phosphate",
                calc_serum_phosphate1
            )
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_serum_phosphate,
                "Serum Phosphate",
                calc_serum_phosphate2
            )
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_serum_potassium,
                "Serum Potassium",
                calc_serum_potassium1
            )
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_serum_potassium,
                "Serum Potassium",
                calc_serum_potassium2
            )
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_serum_sodium,
                "Serum Sodium",
                calc_serum_sodium1
            )
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_serum_sodium,
                "Serum Sodium",
                calc_serum_sodium2
            )
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_total_cholesterol,
                "Total Cholesterol",
                calc_total_cholesterol1
            )
            if transferrin_negation then
                laboratory_studies_header:add_discrete_value_one_of_link(
                    dv_transferrin,
                    "Transferrin",
                    calc_transferrin1
                )
            end

            -- Treatment
            treatment_and_monitoring_header:add_abstraction_link("DIET", "Diet")
            treatment_and_monitoring_header:add_code_link("3E0G76Z", "Enteral Nutrition")
            treatment_and_monitoring_header:add_code_link("3E0H76Z", "J Tube Nutrition")
            treatment_and_monitoring_header:add_abstraction_link("NUTRITIONAL_SUPPLEMENT", "Nutritional Supplement")
            treatment_and_monitoring_header:add_abstraction_link("PARENTERAL_NUTRITION", "Parenteral Nutrition")

            -- Risk Factors
            risk_factor_header:add_code_link("B20", "AIDS/HIV")
            risk_factor_header:add_code_prefix_link("F10%.1", "Alcohol Abuse")
            risk_factor_header:add_code_prefix_link("F10%.2", "Alcohol Dependence")
            risk_factor_header:add_code_prefix_link("K70%.", "Alcoholic Liver Disease")
            risk_factor_header:add_code_link("R63.0", "Anorexia")
            risk_factor_header:add_abstraction_link("CANCER", "Cancer")
            risk_factor_header:add_code_link("K90.0", "Celiac Disease")
            risk_factor_header:add_code_prefix_link("Z51%.1", "Chemotherapy")
            risk_factor_header:add_code_prefix_link("Z79%.63", "Chemotherapy")
            risk_factor_header:add_code_link("3E04305", "Chemotherapy Administration")
            risk_factor_header:add_code_link("N52.9", "Colitis")
            risk_factor_header:add_code_prefix_link("K50%.", "Crohns Disease")
            risk_factor_header:add_code_prefix_link("E84%.", "Cystic Fibrosis")
            risk_factor_header:add_code_prefix_link("K57%.", "Diverticulitis")
            risk_factor_header:add_code_one_of_link(
                { "F50.00", "F50.01", "F50.02", "F50.2", "F50.82", "F50.9" },
                "Eating Disorder"
            )
            risk_factor_header:add_code_link("I50.84", "End Stage Heart Failure")
            risk_factor_header:add_code_link("N18.6", "End-Stage Renal Disease")
            risk_factor_header:add_code_link("K56.7", "Ileus")
            risk_factor_header:add_code_one_of_link({ "K90.89", "K90.9" }, "Intestinal Malabsorption")
            risk_factor_header:add_code_prefix_link("K56%.6", "Intestinal Obstructions")
            risk_factor_header:add_abstraction_link("MENTAL_HEALTH_DISORDER", "Mental Health Disorder")
            risk_factor_header:add_code_prefix_link("Z79%.62", "On Immunosuppressants")
            risk_factor_header:add_abstraction_link("POOR_DENTITION", "Poor Dentition")
            risk_factor_header:add_code_prefix_link("F01%.C", "Severe Dementia")
            risk_factor_header:add_code_prefix_link("F02%.C", "Severe Dementia")
            risk_factor_header:add_code_prefix_link("F03%.C", "Severe Dementia")
            risk_factor_header:add_code_prefix_link("K90%.82", "Short Bowel Syndrome")
            risk_factor_header:add_abstraction_link("SOCIAL_FACTOR", "Social Factor")
            risk_factor_header:add_code_prefix_link("K51%.", "Ulcerative Colitis")
        end



        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        compile_links()
    end
end
