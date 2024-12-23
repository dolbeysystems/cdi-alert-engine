---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Malnutrition
---
--- This script checks an account to see if it matches the criteria for a malnutrition alert.
---
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
---------------------------------------------------------------------------------------------------------------------
---@diagnostic disable: unused-local, empty-block -- Remove once the script is filled out



-------------------------------------------------------------------------------
--- Requires
-------------------------------------------------------------------------------
local alerts = require("libs.common.alerts")(Account)
local links = require("libs.common.basic_links")(Account)
local codes = require("libs.common.codes")(Account)
local dates = require("libs.common.dates")
local discrete = require("libs.common.discrete_values")(Account)
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
                    link.link_text = links.replace_link_place_holders(link.link_text)
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
local dv_weightkg = { "Weight lbs 3.5 (kg)" }
local dv_weight_lbs = { "Weight lbs 3.5 (lb)" }



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
    local ms441 = false
    local cms45 = false
    local cms46 = false



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
    --[[
    #Main Algorithm
    #1
    if (CMS40 or CMS41 or CMS42 or CMS43 or CMS440 or CMS441 or CMS45):
        if e40CC[0] is not None and CMS40: dc.Links.Add(e40CC[0])
        if e41CC[0] is not None and CMS41: dc.Links.Add(e41CC[0])
        if e42CC[0] is not None and CMS42: dc.Links.Add(e42CC[0])
        if e43CC[0] is not None and CMS43: dc.Links.Add(e43CC[0])
        if e440CC[0] is not None and CMS440: dc.Links.Add(e440CC[0])
        if e441CC[0] is not None and CMS441: dc.Links.Add(e441CC[0])
        if e45CC[0] is not None and CMS45: dc.Links.Add(e45CC[0])
        if e40CC[1] is False: dc.Links.Add(e40CC[0])
        if e41CC[1] is False: dc.Links.Add(e41CC[0])
        if e42CC[1] is False: dc.Links.Add(e42CC[0])
        if e43CC[1] is False: dc.Links.Add(e43CC[0])
        if e440CC[1] is False: dc.Links.Add(e440CC[0])
        if e441CC[1] is False: dc.Links.Add(e441CC[0])
        if e45CC[1] is False: dc.Links.Add(e45CC[0])
        result.Subtitle = "Conflicting Malnutrition Severity (Provider/RDN)"
        AlertPassed = True 
    --]]
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
    --[[
    #2  
    elif codesExist > 1:
        for code in codeList:
            desc = codeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, desc + ": [CODE] '[PHRASE]' '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            dc.Links.Add(tempCode)
        result.Subtitle = "Conflicting Malnutrition Dx " + str1
        if validated:
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"
            result.Validated = False
        AlertPassed = True
    --]]
    --[[
    #3.1
    elif subtitle == "Malnutrition Missing Acuity" and codesExist == 1:
        for code in codeList:
            desc = codeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            if tempCode is not None:
                dc.Links.Add(tempCode)
                break
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    --]]
    --[[
    #3
    elif triggerAlert and codesExist == 0 and e46Code is not None:
        if e46Code is not None: dc.Links.Add(e46Code)
        result.Subtitle = "Malnutrition Missing Acuity"
        AlertPassed = True
    --]]
    --[[
    #4.1
    elif (
        subtitle == "Possible Malnutrition" and
        autoCC == True and 
        (codesExist > 0 or e46Code is not None)
    ):
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    --]]
    --[[
    #4
    elif (
        triggerAlert and
        (e40CC[0] is not None and e40CC[1] is False) or
        (e41CC[0] is not None and e41CC[1] is False) or
        (e42CC[0] is not None and e42CC[1] is False) or
        (e43CC[0] is not None and e43CC[1] is False) or
        (e440CC[0] is not None and e440CC[1] is False) or
        (e441CC[0] is not None and e441CC[1] is False) or
        (e45CC[0] is not None and e45CC[1] is False) or
        (e46CC[0] is not None and e46CC[1] is False)
    ):
        if e40CC[0] is not None and e40CC[1] is False: dc.Links.Add(e40CC[0])
        if e41CC[0] is not None and e41CC[1] is False: dc.Links.Add(e41CC[0])
        if e42CC[0] is not None and e42CC[1] is False: dc.Links.Add(e42CC[0])
        if e43CC[0] is not None and e43CC[1] is False: dc.Links.Add(e43CC[0])
        if e440CC[0] is not None and e440CC[1] is False: dc.Links.Add(e440CC[0])
        if e441CC[0] is not None and e441CC[1] is False: dc.Links.Add(e441CC[0])
        if e45CC[0] is not None and e45CC[1] is False: dc.Links.Add(e45CC[0])
        if e46CC[0] is not None and e46CC[1] is False: dc.Links.Add(e46CC[0])
        result.Subtitle = "Possible Malnutrition"
        AlertPassed = True
    --]]
    --[[
    #5.1
    elif (
        subtitle == "Possible Low BMI" and
        ((r627Code is not None or r634Code is not None or r64Code is not None or r636Code is not None or t730xxxaCode is not None or e46Code is not None) or
        (malnutritionCodes is not None and autoCC))
    ):
        if r627Code is not None: updateLinkText(r627Code, "Autoresolved Specified Code - "); dc.Links.Add(r627Code)
        if r634Code is not None: updateLinkText(r634Code, "Autoresolved Specified Code - "); dc.Links.Add(r634Code)
        if r64Code is not None: updateLinkText(r64Code, "Autoresolved Specified Code - "); dc.Links.Add(r64Code)
        if r636Code is not None: updateLinkText(r636Code, "Autoresolved Specified Code - "); dc.Links.Add(r636Code)
        if t730xxxaCode is not None: updateLinkText(t730xxxaCode, "Autoresolved Specified Code - "); dc.Links.Add(t730xxxaCode)
        if malnutritionCodes is not None: updateLinkText(malnutritionCodes, "Autoresolved Specified Code - "); dc.Links.Add(malnutritionCodes)
        if e46Code is not None: updateLinkText(e46Code, "Autoresolved Specified Code - "); dc.Links.Add(e46Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one or more Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    --]]
    --[[
    #5
    elif triggerAlert and (lowBMIDV is not None or lowBMIAbs is not None) and r627Code is None and e46Code is None and r634Code is None and r64Code is None and r636Code is None and t730xxxaCode is None and malnutritionCodes is None:
        result.Subtitle = "Possible Low BMI"
        AlertPassed = True
    --]]
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            --[[
            #Negations
            transferrinNegation = multiCodeValue(["K72.0", "K72.00", "K72.01", "K72.1", "K72.10", "K72.11", "K72.9", "K72.90",
                                              "K72.91", "K74.4", "K74.5", "K74.6", "K74.60", "D59.13", "D59.19", "D59.2",
                                              "D59.3", "D59.30", "D59.31", "D59.32", "D59.39", "D59.4", "D59.5", "D59.6",
                                              "D59.8", "D59.9"],
                                            "Transferrin Negation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            lymphocyteCountNegation = multiCodeValue(["D60.0", "D60.1", "D60.8", "D60.9", "D61", "D61.0", "D61.01", "D61.09",
                                                  "D61.1", "D61.2", "D61.3", "D61.8", "D61.81", "D61.810", "D61.811",
                                                  "D61.818", "D61.82", "D61.89", "D61.9"],
                                                "Lymphocyte Count Negation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            --]]
            --[[
            #Abstractions
            #1-2
            prefixCodeValue("^E54\.", "Ascorbic Acid Deficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, abs, True)
            #4
            if lowBMIDV is not None: abs.Links.Add(lowBMIDV) #5
            else: dvValue(dvBMI, "BMI: [VALUE] (Result Date: [RESULTDATETIME])", calcBMI2, 5)
            if lowBMIAbs is not None: abs.Links.Add(lowBMIAbs) #6
            abstractValue("DECREASED_FUNCTIONAL_CAPACITY", "Decreased Functional Capacity '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7, abs, True)
            prefixCodeValue("^E53\.", "Deficiency of other B group Vitamins: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8, abs, True)
            prefixCodeValue("^E61\.", "Deficiency of other Nutrient Elements: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, abs, True)
            abstractValue("DIARRHEA", "Diarrhea '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10, abs, True)
            codeValue("E58", "Dietary Calcium Deficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, abs, True)
            codeValue("E59", "Dietary Selenium Deficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, abs, True)
            codeValue("E60", "Dietary Zinc Deficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13, abs, True)
            multiCodeValue(["R13.10", "R13.11", "R13.12", "R13.13", "R13.14", "R13.19"], "Dysphagia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, abs, True)
            codeValue("R53.83", "Fatigue: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
            abstractValue("FEELING_COLD", "Feeling Cold '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 16, abs, True)
            abstractValue("FRAIL", "Frail '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 17, abs, True)
            --]]
            --[[
            #18-19
            abstractValue("HEIGHT", "Height: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 20, abs, True)
            #21-26
            abstractValue("LOW_FOOD_INTAKE", "Low Food Intake '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 27, abs, True)
            abstractValue("MALNOURISHED_SIGN", "Malnourished Sign '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 28, abs, True)
            abstractValue("MALNUTRITION_RISK_FACTORS", "Malnutrition Risk Factors '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 29, abs, True)
            --]]
            --[[
            #30
            abstractValue("MODERATE_MALNUTRITION", "Moderate Malnutrition '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 31, abs, True)
            prefixCodeValue("^E52\.", "Niacin Deficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 32, abs, True)
            #33
            prefixCodeValue("^E63\.", "Other Nutritional Deficiencies: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 34, abs, True)
            prefixCodeValue("^E56\.", "Other Vitamin Deficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 35, abs, True)
            --]]
            --[[
            #36-39
            abstractValue("SEVERE_MALNUTRTION", "Severe Malnutrition '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 40, abs, True)
            codeValue("T73.0XXA", "Starvation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 41, abs, True)
            prefixCodeValue("^E51\.", "Thiamine Deficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 42, abs, True)
            --]]
            --[[
            #43-45
            prefixCodeValue("^E50\.", "Vitamin A Deficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 46, abs, True)
            prefixCodeValue("^E55\.", "Vitamin D Deficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 47, abs, True)
            codeValue("R11.10", "Vomiting: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 48, abs, True)
            abstractValue("WEAKNESS", "Weakness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 49, abs, True)
            abstractValue("WEIGHT", "Weight '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 50, abs, True)
            --]]
            --[[
            #Labs
            if lymphocyteCountNegation is None:
                dvValue(dvLymphocyteCount, "Lymphocyte Count: [VALUE] (Result Date: [RESULTDATETIME])", calcLymphocyteCount1, 1, labs, True)
            --]]
            --[[
            dvValue(dvSerumCalcium, "Serum Calcium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumCalcium1, 2, labs, True)
            dvValue(dvSerumCalcium, "Serum Calcium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumCalcium2, 3, labs, True)
            dvValue(dvSerumChloride, "Serum Chloride: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumChloride1, 4, labs, True)
            dvValue(dvSerumChloride, "Serum Chloride: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumChloride2, 4, labs, True)
            dvValue(dvSerumMagnesium, "Serum Magnesium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumMagnesium1, 5, labs, True)
            dvValue(dvSerumMagnesium, "Serum Magnesium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumMagnesium2, 5, labs, True)
            dvValue(dvSerumPhosphate, "Serum Phosphate: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumPhosphate1, 6, labs, True)
            dvValue(dvSerumPhosphate, "Serum Phosphate: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumPhosphate2, 6, labs, True)
            dvValue(dvSerumPotassium, "Serum Potassium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumPotassium1, 7, labs, True)
            dvValue(dvSerumPotassium, "Serum Potassium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumPotassium2, 7, labs, True)
            dvValue(dvSerumSodium, "Serum Sodium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumSodium1, 8, labs, True)
            dvValue(dvSerumSodium, "Serum Sodium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumSodium2, 8, labs, True)
            dvValue(dvTotalCholesterol, "Total Cholesterol: [VALUE] (Result Date: [RESULTDATETIME])", calcTotalCholesterol1, 9, labs, True)
            --]]
            --[[
            if transferrinNegation is None:
                dvValue(dvTransferrin, "Transferrin: [VALUE] (Result Date: [RESULTDATETIME])", calcTransferrin1, 10, labs, True)
            --]]
            --[[
            #Treatment
            abstractValue("DIET", "Diet '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1, treatment, True)
            codeValue("3E0G76Z", "Enteral Nutrition: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, treatment, True)
            codeValue("3E0H76Z", "J Tube Nutrition: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, treatment, True)
            abstractValue("NUTRITIONAL_SUPPLEMENT", "Nutritional Supplement: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4, treatment, True)
            abstractValue("PARENTERAL_NUTRITION", "Parenteral Nutrition '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5, treatment, True)
            --]]
            --[[
            #Risk Factors
            codeValue("B20", "AIDS/HIV: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, risk, True)
            prefixCodeValue("^F10\.1", "Alcohol Abuse: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, risk, True)
            prefixCodeValue("^F10\.2", "Alcohol Dependence: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, risk, True)
            prefixCodeValue("^K70\.", "Alcoholic Liver Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, risk, True)
            codeValue("R63.0", "Anorexia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, risk, True)
            abstractValue("CANCER", "Cancer '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5, risk, True)
            --]]
            --[[
            codeValue("K90.0", "Celiac Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, risk, True)
            prefixCodeValue("^Z51\.1", "Chemotherapy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, risk, True)
            prefixCodeValue("^Z79\.63", "Chemotherapy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8, risk, True)
            codeValue("3E04305", "Chemotherapy Administration: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, risk, True)
            codeValue("N52.9", "Colitis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, risk, True)
            prefixCodeValue("^K50\.", "Crohns Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, risk, True)
            prefixCodeValue("^E84\.", "Cystic Fibrosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, risk, True)
            prefixCodeValue("^K57\.", "Diverticulitis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13, risk, True)
            --]]
            --[[
            multiCodeValue(["F50.00", "F50.01", "F50.02", "F50.2", "F50.82", "F50.9"], "Eating Disorder: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, risk, True)
            codeValue("I50.84", "End Stage Heart Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, risk, True)
            codeValue("N18.6", "End-Stage Renal Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, risk, True)
            codeValue("K56.7", "Ileus: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17, risk, True)
            multiCodeValue(["K90.89", "K90.9"], "Intestinal Malabsorption: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, risk, True)
            prefixCodeValue("^K56\.6", "Intestinal Obstructions: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19, risk, True)
            --]]
            --[[
            abstractValue("MENTAL_HEALTH_DISORDER", "Mental Health Disorder '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 20, risk, True)
            prefixCodeValue("^Z79\.62", "On Immunosuppressants: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21, risk, True)
            abstractValue("POOR_DENTITION", "Poor Dentition '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 22, risk, True)
            --]]
            --[[
            prefixCodeValue("^F01\.C", "Severe Dementia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23, risk, True)
            prefixCodeValue("^F02\.C", "Severe Dementia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 24, risk, True)
            prefixCodeValue("^F03\.C", "Severe Dementia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 25, risk, True)
            prefixCodeValue("^K90\.82", "Short Bowel Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 26, risk, True)
            abstractValue("SOCIAL_FACTOR", "Social Factor '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 27, risk, True)
            prefixCodeValue("^K51\.", "Ulcerative Colitis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 28, risk, True)
            --]]
        end



        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        compile_links()
    end
end
