---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Sepsis/SIRS
---
--- This script checks an account to see if it matches the criteria for a Sepsis/SIRS alert.
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
local lists = require("libs.common.lists")
local cdi_alert_link = require "cdi.link"




--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local dv_alanine_transaminase = { "ALT", "ALT/SGPT (U/L) 16-61" }
local calc_alanine_transaminase_1 = function(dv_, num) return num > 62 end

local dv_aspartate_transaminase = { "AST", "AST/SGOT (U/L)" }
local calc_aspartate_transaminase_1 = function(dv_, num) return num > 35 end

local dv_bacteria_urine = { "BACTERIA (/HPF)" }
local calc_bacteria_urine_1 = function(dv_, num) return num > 0 end

local dv_blood_glucose = { "GLUCOSE (mg/dL)", "GLUCOSE" }
local calc_blood_glucose_1 = function(dv_, num) return num > 140 end

local dv_blood_glucose_poc = { "GLUCOSE ACCUCHECK (mg/dL)" }
local calc_blood_glucose_poc_1 = function(dv_, num) return num > 140 end

local dv_c_blood = { "" }
local dv_urine_culture = { "" }

local dv_c_reactive_protein = { "C REACTIVE PROTEIN (mg/dL)" }
local calc_c_reactive_protein_1 = function(dv_, num) return num > 0.3 end

local dv_glasgow_coma_scale = { "3.5 Neuro Glasgow Score" }
local calc_glasgow_coma_scale_1 = function(dv_, num) return num < 15 end

local dv_heart_rate = { "Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)", "3.5 Heart Rate (Radial) (bpm)", "SCC Monitor Pulse (bpm)" }
local calc_heart_rate_1 = 90
local calc_heart_rate_2 = function(dv_, num) return num > 90 end

local dv_hematocrit = { "HEMATOCRIT (%)", "HEMATOCRIT" }
local calc_hematocrit_1 = function(dv_, num) return num < 35 end
local calc_hematocrit_2 = function(dv_, num) return num < 40 end

local dv_hemoglobin = { "HEMOGLOBIN", "HEMOGLOBIN (g/dL)" }
local calc_hemoglobin_1 = function(dv_, num) return num < 13.5 end
local calc_hemoglobin_2 = function(dv_, num) return num < 11.6 end

local dv_inr = { "INR" }
local calc_inr_1 = function(dv_, num) return num > 1.2 end

local dv_interleukin_6 = { "INTERLEUKIN 6" }
local calc_interleukin_1 = function(dv_, num) return num > 7.0 end

local dv_map = { "Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)" }
local calc_map_1 = function(dv_, num) return num < 70 end

local dv_pa_o2 = { "BLD GAS O2 (mmHg)", "PO2 (mmHg)" }
local calc_pa_o2_1 = function(dv_, num) return num < 80 end

local dv_pa_o2_fi_o2 = { "PO2/FiO2 (mmHg)" }
local calc_pa_o2_fi_o2_1 = function(dv_, num) return num < 300 end

local dv_pco2 = { "pCO2 BldV (mm Hg)" }
local calc_pco2 = 32

local dv_platelet_count = { "PLATELET COUNT (10x3/uL)" }
local calc_platelet_count_1 = function(dv_, num) return num < 150 end
local calc_platelet_count_2 = function(dv_, num) return num < 100 end

local dv_poc_lactate = { "" }
local calc_poc_lactate_1 = function(dv_, num) return num > 2 end

local dv_procalcitonin = { "PROCALCITONIN (ng/mL)" }
local calc_procalcitonin_1 = function(dv_, num) return num > 0.50 end

local dv_respiratory_rate = { "3.5 Respiratory Rate (#VS I&O) (per Minute)" }
local calc_resp_rate_1 = 20
local calc_resp_rate_2 = function(dv_, num) return num > 20 end

local dv_sbp = { "SBP 3.5 (No Calculation) (mm Hg)" }
local calc_sbp_1 = function(dv_, num) return num < 90 end

local dv_serum_band = { "Band Neutrophils (%)" }
local calc_serum_band_1 = 5
local calc_serum_band_2 = function(dv_, num) return num > 5 end

local dv_serum_bilirubin = { "BILIRUBIN (mg/dL)" }
local calc_serum_bilirubin_1 = function(dv_, num) return num > 1.2 end

local dv_serum_bun = { "BUN (mg/dL)" }
local calc_serum_bun_1 = function(dv_, num) return num > 23 end

local dv_serum_creatinine = { "CREATININE (mg/dL)", "CREATININE SERUM (mg/dL)" }
local calc_serum_creatinine_1 = function(dv_, num) return num > 1.3 end

local dv_serum_lactate = { "LACTIC ACID (mmol/L)", "LACTATE (mmol/L)" }
local calc_serum_lactate_1 = function(dv_, num) return num > 2 end

local dv_sp_o2 = { "Pulse Oximetry(Num) (%)" }
local calc_spo2_1 = function(dv_, num) return num < 90 end

local dv_temperature = { "Temperature Degrees C 3.5 (degrees C)", "Temperature Degrees C 3.5 (degrees C)", "TEMPERATURE (C)" }
local calc_temp_1 = 38.3
local calc_temp_2 = 36.0
local calc_temp_3 = function(dv_, num) return num > 38.3 end
local calc_temp_4 = function(dv_, num) return num < 36.0 end

local dv_urinary = { "" }
local calc_urinary_1 = function(dv_, num) return num > 0 end

local dv_wbc = { "WBC (10x3/ul)" }
local calc_wbc_1 = 12
local calc_wbc_2 = 4
local calc_wbc_3 = function(dv_, num) return num > 12 end
local calc_wbc_4 = function(dv_, num) return num < 4 end



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }
local subtitle = existing_alert and existing_alert.subtitle or nil



--------------------------------------------------------------------------------
--- Header Variables and Helper Functions
--------------------------------------------------------------------------------
local result_links = {}
local documented_dx_header = headers.make_header_builder("Documented Dx", 1)
local sirs_criteria_header = headers.make_header_builder("SIRS Criteria", 2)
local vital_signs_intake_header = headers.make_header_builder("Vital Signs/Intake and Output Data", 3)
local infection_header = headers.make_header_builder("Infection", 4)
local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 5)
local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 6)
local oxygenation_ventilation_header = headers.make_header_builder("Oxygenation/Ventilation", 7)
local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 8)
local contributing_dx_header = headers.make_header_builder("Contributing Dx", 9)
local sirs_resp_header = headers.make_header_builder("Respiratory Rate: > 20 breaths per min or PC02 < 32", 1)
local sirs_wbc_header = headers.make_header_builder("WBC Count: > 12,000 or < 4,000 or bands > 10%", 2)
local sirs_temp_header = headers.make_header_builder("Temperature: > 100.4F/38.0C or < 96.8F/36.0C", 3)
local sirs_heart_header = headers.make_header_builder("Heart Rate: > 90bpm", 4)

local function compile_links()
    sirs_criteria_header:add_link(sirs_resp_header:build(true))
    sirs_criteria_header:add_link(sirs_temp_header:build(true))
    sirs_criteria_header:add_link(sirs_wbc_header:build(true))
    sirs_criteria_header:add_link(sirs_heart_header:build(true))

    table.insert(result_links, documented_dx_header:build(true))
    table.insert(result_links, sirs_criteria_header:build(true))
    table.insert(result_links, vital_signs_intake_header:build(true))
    table.insert(result_links, infection_header:build(true))
    table.insert(result_links, clinical_evidence_header:build(true))
    table.insert(result_links, laboratory_studies_header:build(true))
    table.insert(result_links, oxygenation_ventilation_header:build(true))
    table.insert(result_links, treatment_and_monitoring_header:build(true))
    table.insert(result_links, contributing_dx_header:build(true))

    if existing_alert then
        result_links = links.merge_links(existing_alert.links, result_links)
    end
    Result.links = result_links
end



--------------------------------------------------------------------------------
--- Script Specific Functions
--------------------------------------------------------------------------------
local function positive_check(dv, num_)
    return dv and dv.result and (string.find(dv.result, "positive") or string.find(dv.result, "Detected"))
end

local function anesthesia_med_predicate(dv, num_)
    return dv and dv.route and dv.dosage and (string.find(dv.dosage, "hr") or string.find(dv.dosage, "hour") or string.find(dv.dosage, "min") or string.find(dv.dosage, "minute")) and (string.find(dv.route, "Intravenous") or string.find(dv.route, "IV Push"))
end

local function antibiotic_med_value_predicate(dv, num_)
    return dv and dv.route and dv.category == "Antibiotic" and not (string.find(dv.route, "Eye") or string.find(dv.route, "topical") or string.find(dv.route, "ocular") or string.find(dv.route, "ophthalmic"))
end

---@param dv_sirs_match DiscreteValue[]
---@return CdiAlertLink[]?
local function sirs_lookup(dv_sirs_match)
    local matched_list = {}
    local date_list = {}
    -- Pull all values for discrete values we need
    for _, value in pairs(dv_sirs_match) do
        local temp_dv = 'XX'
        local hr_dv = 'XX'
        local resp_dv = 'XX'
        local date = value.result_date or ""
        local match = value.name
        local id = value.unique_id
        if not date_list[date] then
            date_list[date] = true
            if lists.includes(dv_temperature, match) then
                temp_dv = value.result
            elseif lists.includes(dv_heart_rate, match) then
                hr_dv = value.result
            elseif lists.includes(dv_respiratory_rate, match) then
                resp_dv = value.result
            end
            for _, dv in pairs(Account.discrete_values) do
                local dvr = discrete.get_dv_value_number(dv)
                if lists.includes(dv_temperature, dv.name) and dvr and not lists.includes(dv_temperature, match) and dv.result_date == date then
                    -- Temperature
                    temp_dv = dv.result
                elseif lists.includes(dv_heart_rate, dv.name) and dvr and not lists.includes(dv_heart_rate, match) and dv.result_date == date then
                    -- Heart Rate
                    hr_dv = dv.result
                elseif lists.includes(dv_respiratory_rate, dv.name) and dvr and not lists.includes(dv_respiratory_rate, match) and dv.result_date == date then
                    -- Respiratory Rate
                    resp_dv = dv.result
                end
            end
            local link = cdi_alert_link()
            link.link_text = date .. " Temp = " .. tostring(temp_dv) .. ", HR = " .. tostring(hr_dv) .. ", RR = " .. tostring(resp_dv)
            link.discrete_value_id = id
            link.discrete_value_name = value.name
            vital_signs_intake_header:add_link(link)
            table.insert(matched_list, link)
        end
    end

    if #matched_list > 0 then
        return matched_list
    else
        return nil
    end
end

---@param sirs_match_id string
---@return boolean?
local function sirs_lookup_lacking(sirs_match_id)
    local matched_list = {}
    local date_list = {}
    -- Pull all values for discrete values we need
    for _, value in pairs(Account.discrete_values) do
        if value.unique_id == sirs_match_id then
            local temp_dv = 'XX'
            local hr_dv = 'XX'
            local resp_dv = 'XX'
            local date = value.result_date or ""
            local match = value.name
            local id = value.unique_id
            if not date_list[date] then
                date_list[date] = true
                if lists.includes(dv_temperature, match) then
                    temp_dv = value.result
                elseif lists.includes(dv_heart_rate, match) then
                    hr_dv = value.result
                elseif lists.includes(dv_respiratory_rate, match) then
                    resp_dv = value.result
                end
                for _, dv in pairs(Account.discrete_values) do
                    local dvr = discrete.get_dv_value_number(dv)
                    if lists.includes(dv_temperature, dv.name) and dvr and not lists.includes(dv_temperature, match) and dv.result_date == date then
                        -- Temperature
                        temp_dv = dv.result
                    elseif lists.includes(dv_heart_rate, dv.name) and dvr and not lists.includes(dv_heart_rate, match) and dv.result_date == date then
                        -- Heart Rate
                        hr_dv = dv.result
                    elseif lists.includes(dv_respiratory_rate, dv.name) and dvr and not lists.includes(dv_respiratory_rate, match) and dv.result_date == date then
                        -- Respiratory Rate
                        resp_dv = dv.result
                    end
                end
                --table.insert(matched_list, cdi_alert_link(nil, date .. " Temp = " .. tostring(temp_dv) .. ", HR = " .. tostring(hr_dv) .. ", RR = " .. tostring(resp_dv), nil, id, vitals, 0, true))
                local link = cdi_alert_link()
                link.link_text = date .. " Temp = " .. tostring(temp_dv) .. ", HR = " .. tostring(hr_dv) .. ", RR = " .. tostring(resp_dv)
                link.discrete_value_id = id
                link.discrete_value_name = value.name
                vital_signs_intake_header:add_link(link)
                table.insert(matched_list, link)
                return true
            end
        end
    end
    return nil
end



if not existing_alert or not existing_alert.validated then
    --------------------------------------------------------------------------------
    --- Alert Variables 
    --------------------------------------------------------------------------------
    local alert_code_dictionary = {
        ["A40.0"] = "Sepsis Due To Streptococcus, Group A",
        ["A40.1"] = "Sepsis due to Streptococcus, Group B",
        ["A40.3"] = "Sepsis due to Streptococcus Pneumoniae",
        ["A40.8"] = "Other Streptococcal Sepsis",
        ["A40.9"] = "Streptococcal Sepsis, Unspecified",
        ["A41.01"] = "Sepsis due to Methicillin Susceptible Staphylococcus Aureus",
        ["A41.02"] = "Sepsis due To Methicillin Resistant Staphylococcus Aureus",
        ["A41.1"] = "Sepsis due to Other Specified Staphylococcus",
        ["A41.2"] = "Sepsis due to Unspecified Staphylococcus",
        ["A41.3"] = "Sepsis due to Hemophilus Influenzae",
        ["A41.4"] = "Sepsis due to Anaerobes",
        ["A41.50"] = "Gram-Negative Sepsis, Unspecified",
        ["A41.51"] = "Sepsis due to Escherichia Coli [E. Coli]",
        ["A41.52"] = "Sepsis due to Pseudomonas",
        ["A41.53"] = "Sepsis due to Serratia",
        ["A41.54"] = "Sepsis Due to Acinetobacter Baumannii",
        ["A41.59"] = "Other Gram-Negative Sepsis",
        ["A41.81"] = "Sepsis due to Enterococcus",
        ["A41.89"] = "Other Specified Sepsis",
        ["A42.7"] = "Actinomycotic Sepsis",
        ["A22.7"] = "Anthrax Sepsis",
        ["B37.7"] = "Candidal Sepsis",
        ["A26.7"] = "Erysipelothrix Sepsis",
        ["A54.86"] = "Gonococcal Sepsis",
        ["B00.7"] = "Herpesviral Sepsis",
        ["A32.7"] = "Listerial Sepsis",
        ["A24.1"] = "Melioidosis Sepsis",
        ["A20.7"] = "Septicemic Plague",
        ["T81.44XA"] = "Sepsis Following A Procedure",
        ["T81.44XD"] = "Sepsis Following A Procedure",
        ["T81.44XS"] = "Sepsis Following a Procedure, Sequela",
        ["R65.20"] = "Severe Sepsis Without Septic Shock",
        ["R65.21"] = "Severe Sepsis With Septic Shock"

    }
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    --[[
    #Documented Dx
    r6521Code = codeValue("R65.21", "Severe Sepsis with Septic Shock: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    a419Code = codeValue("A41.9", "Sepsis Dx Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 99)
    #Negations
    PulmonaryDCode = codeValue("J44.1", "Chronic Obstructive Pulmonary Disease with (Acute) Exacerbation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    hypothermiaCheck = multiCodeValue(["T68.0", "T68.XXXA", "T88.51XA", "T88.51"], "Hypothermia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 99)
    kidneyDiseaseCode = multiCodeValue(["N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6"], "Kidney Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    FeverCheck = multiCodeValue(["G21.0", "T43.225A", "T43.224A", "T43.221A", "T88.3XXA", "R50.83", "R50.84", "R50.2"], "Fever: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 99)
    d469Code = codeValue("D46.9", "Myelodysplastic Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 99)
    a3e04305Code = codeValue("3E04305", "Chemotherapy Medication Administration: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 99)
    currentChemotherapyAbs = abstractValue("CURRENT_CHEMOTHERAPY", "Current Chemotherapy '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 99)
    --]]
    -- Documented Dx
    local r6521_code = links.get_code_link { code = "R65.21", text = "Severe Sepsis with Septic Shock" }
    local a419_code = links.get_code_link { code = "A41.9", text = "Sepsis Dx Unspecified" }
    -- Negations
    local pulmonary_d_code = links.get_code_link { code = "J44.1", text = "Chronic Obstructive Pulmonary Disease with (Acute) Exacerbation" }
    local hypothermia_check = links.get_code_links { codes = { "T68.0", "T68.XXXA", "T88.51XA", "T88.51" }, text = "Hypothermia" }
    local kidney_disease_code = links.get_code_links { codes = { "N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6" }, text = "Kidney Disease" }
    local fever_check = links.get_code_links { codes = { "G21.0", "T43.225A", "T43.224A", "T43.221A", "T88.3XXA", "R50.83", "R50.84", "R50.2" }, text = "Fever" }
    local d469_code = links.get_code_link { code = "D46.9", text = "Myelodysplastic Syndrome" }
    local a3e04305_code = links.get_code_link { code = "3E04305", text = "Chemotherapy Medication Administration" }
    local current_chemotherapy_abs = links.get_abstraction_link { code = "CURRENT_CHEMOTHERAPY", text = "Current Chemotherapy" }

    --[[
    acuteHeartFailureCheck = multiCodeValue(["I50.21", "I50.23", "I50.33", "I50.41", "I50.43", "I50.811", "I50.813", "I50.814", "I50.9"], "Acute Heart Failure Codes: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 99)
    diabetesE10Check = prefixCodeValue("^E10\.", "Diabetes: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 99)
    diabetesE11Check = prefixCodeValue("^E11\.", "Diabetes: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 99)
    goutFlareAbs = abstractValue("GOUT_FLARE", "Gout Flare '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 99)
    hyperhidrosisCode = codeValue("R61", "Hyperhidrosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 99)
    --]]
    local acute_heart_failure_check = links.get_code_links { codes = { "I50.21", "I50.23", "I50.33", "I50.41", "I50.43", "I50.811", "I50.813", "I50.814", "I50.9" }, text = "Acute Heart Failure Codes" }
    local diabetes_e10_check = codes.get_code_prefix_link { prefix = "E10%.", text = "Diabetes" }
    local diabetes_e11_check = codes.get_code_prefix_link { prefix = "E11%.", text = "Diabetes" }
    local gout_flare_abs = links.get_abstraction_link { code = "GOUT_FLARE", text = "Gout Flare" }
    local hyperhidrosis_code = links.get_code_link { code = "R61", text = "Hyperhidrosis" }
    --[[
    leukemiaCheck = multiCodeValue(["C91", "C91.0", "C91.00", "C91.01", "C91.01", "C91.1", "C91.10", "C91.11",
                "C91.12", "C91.3", "C91.30", "C91.31", "C91.32", "C91.4", "C91.40", "C91.41",
                "C91.42", "C91.5", "C91.50", "C91.51", "C91.52", "C91.6", "C91.60", "C91.61",
                "C91.62", "C91.A", "C91.A0", "C91.A1", "C91.A2", "C91.Z", "C91.Z0", "C91.Z1",
                "C91.Z2", "C91.9", "C91.90", "C91.91", "C91.92", "C92", "C92.0", "C92.00", "C92.01",
                "C92.02", "C92.1", "C92.11", "C92.12", "C92.2", "C92.20", "C92.21", "C92.22",
                "D45", "D75.81", "D70.0", "D72.0", "D70.1", "D70.2"], "Leukemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 99)
    liverCirrhosisCheck = multiCodeValue(["K70.0", "K70.10", "K70.11", "K70.2", "K70.30", "K70.31", "K70.40", "K70.41", "K70.9",
                                        "K74.60", "K72.1", "K71", "K71.0", "K71.10", "K71.11", "K71.2", "K71.3", "K71.4", "K71.50",
                                        "K71.51", "K71.6", "K71.7", "K71.8", "K71.9", "K72.10", "K72.11", "K73.0", "K73.1", "K73.2",
                                        "K73.8", "K73.9", "R18.0"], "Liver Cirrhosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 99)
    --]]
    local leukimia_check = links.get_code_links {
        codes = {
            "C91", "C91.0", "C91.00", "C91.01", "C91.01", "C91.1", "C91.10", "C91.11", "C91.12", "C91.3", "C91.30",
            "C91.31", "C91.32", "C91.4", "C91.40", "C91.41", "C91.42", "C91.5", "C91.50", "C91.51", "C91.52", "C91.6",
            "C91.60", "C91.61", "C91.62", "C91.A", "C91.A0", "C91.A1", "C91.A2", "C91.Z", "C91.Z0", "C91.Z1", "C91.Z2",
            "C91.9", "C91.90", "C91.91", "C91.92", "C92", "C92.0", "C92.00", "C92.01", "C92.02", "C92.1", "C92.11",
            "C92.12", "C92.2", "C92.20", "C92.21", "C92.22", "D45", "D75.81", "D70.0", "D72.0", "D70.1", "D70.2"
        },
        text = "Leukemia"
    }
    local liver_cirrhosis_check = links.get_code_links {
        codes = {
            "K70.0", "K70.10", "K70.11", "K70.2", "K70.30", "K70.31", "K70.40", "K70.41", "K70.9", "K74.60", "K72.1",
            "K71", "K71.0", "K71.10", "K71.11", "K71.2", "K71.3", "K71.4", "K71.50", "K71.51", "K71.6", "K71.7",
            "K71.8", "K71.9", "K72.10", "K72.11", "K73.0", "K73.1", "K73.2", "K73.8", "K73.9", "R18.0"
        },
        text = "Liver Cirrhosis"
    }
    --[[
    alcoholAndOpioidAbuseCheck = multiCodeValue(["F10.920", "F10.921", "F10.929", "F10.930", "F10.931", "F10.932",
            "F10.939", "F11.120", "F11.121", "F11.122", "F11.129", "F11.13"], "Alcohol and Opioid Abuse: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    chronicKidneyFailureCheck = multiCodeValue(["N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6", "N18.9"],
            "Chronic Kidney Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    longTermImmunomodulatorsImunosuppCode = codeValue("Z79.69", "Long term use of other immunomodulators and immunosuppressants: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 99)
    --]]
    local alcohol_and_opioid_abuse_check = links.get_code_links {
        codes = {
            "F10.920", "F10.921", "F10.929", "F10.930", "F10.931", "F10.932", "F10.939", "F11.120", "F11.121",
            "F11.122", "F11.129", "F11.13"
        },
        text = "Alcohol and Opioid Abuse"
    }
    local chronic_kidney_failure_check = links.get_code_links {
        codes = { "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6", "N18.9" },
        text = "Chronic Kidney Failure"
    }
    local long_term_immunomodulators_imunosupp_code = links.get_code_link { code = "Z79.69", text = "Long term use of other immunomodulators and immunosuppressants" }
    --[[
    lowHemoglobinDV = None
    lowHematocritDV = None
    if gender == 'F':
        lowHemoglobinDV = dvValue(dvHemoglobin, "Hemoglobin: [VALUE] (Result Date: [RESULTDATETIME])", calcHemoglobin2, 99)
        lowHematocritDV = dvValue(dvHematocrit, "Hematocrit: [VALUE] (Result Date: [RESULTDATETIME])", calcHematocrit1, 99)
    if gender == 'M':
        lowHemoglobinDV = dvValue(dvHemoglobin, "Hemoglobin: [VALUE] (Result Date: [RESULTDATETIME])", calcHemoglobin1, 99)
        lowHematocritDV = dvValue(dvHematocrit, "Hematocrit: [VALUE] (Result Date: [RESULTDATETIME])", calcHematocrit2, 99)
    --]]
    local low_hemoglobin_dv = nil
    local low_hematocrit_dv = nil
    if Account.patient.gender == "F" then
        low_hemoglobin_dv = links.get_discrete_value_link { discreteValueNames = dv_hemoglobin, text = "Hemoglobin" }
        low_hematocrit_dv = links.get_discrete_value_link { discreteValueNames = dv_hematocrit, text = "Hematocrit" }
    elseif Account.patient.gender == "M" then
        low_hemoglobin_dv = links.get_discrete_value_link { discreteValueNames = dv_hemoglobin, text = "Hemoglobin" }
        low_hematocrit_dv = links.get_discrete_value_link { discreteValueNames = dv_hematocrit, text = "Hematocrit" }
    end
    --[[
    negationsHeartRateCheck = multiCodeValue(["F15.10", "F15.929", "E05.90", "F41.0", "J44.1", "J45.902", "I48.0", "I48.1", "I48.19", "I48.20", "I48.21",
                "I48.3", "I48.4", "I48.91", "I48.92"], "Negated for Heart Rate: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 99)
    negationsRespiratoryCheck = multiCodeValue(["F15.929", "F45.8", "F41.0", "J45.901", "J45.902", "J44.1"],
                "Negations for Respiratory: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 99)
    pulmonaryEmbolismCheck = prefixCodeValue("^I26\.", "Pulmonary Embolism '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 99)
    psychogenicHyperventilationAbs = abstractValue("PSYCHOGENIC_HYPERVENTILATION", "Psychogenic Hyperventilation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 99)
    --]]
    local negations_heart_rate_check = links.get_code_links {
        codes = {
            "F15.10", "F15.929", "E05.90", "F41.0", "J44.1", "J45.902", "I48.0", "I48.1", "I48.19", "I48.20", "I48.21",
            "I48.3", "I48.4", "I48.91", "I48.92"
        },
        text = "Negated for Heart Rate"
    }
    local negations_respiratory_check = links.get_code_links {
        codes = { "F15.929", "F45.8", "F41.0", "J45.901", "J45.902", "J44.1" },
        text = "Negations for Respiratory"
    }
    local pulmonary_embolism_check = codes.get_code_prefix_link { prefix = "I26%.", text = "Pulmonary Embolism" }
    local psychogenic_hyperventilation_abs = links.get_abstraction_link { code = "PSYCHOGENIC_HYPERVENTILATION", text = "Psychogenic Hyperventilation" }
    --[[
    steroidsAbs = abstractValue("STEROIDS", "Steroid '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 99)
    anticoagulantAbs = abstractValue("ANTICOAGULANT", "Anticoagulant '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    negationAspartate = multiCodeValue(["B18.2", "B19.20", "K72.10", "K72.11", "K73", "K74.60", "K74.69", "Z79.01", "Z86.19"], "Negation Aspartate '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    r6510Code = codeValue("R65.10", "Systemic Inflammatory Response Syndrome (SIRS) of Non-Infectious Origin without Acute Organ Dysfunction: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 99)
    r6511Code = codeValue("R65.11", "Systemic Inflammatory Response Syndrome (SIRS) of Non-Infectious Origin with Acute Organ Dysfunction: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 99)
    --]]
    local steroids_abs = links.get_abstraction_link { code = "STEROIDS", text = "Steroid" }
    local anticoagulant_abs = links.get_abstraction_link { code = "ANTICOAGULANT", text = "Anticoagulant" }
    local negation_aspartate = links.get_code_links {
        codes = { "B18.2", "B19.20", "K72.10", "K72.11", "K73", "K74.60", "K74.69", "Z79.01", "Z86.19" },
        text = "Negation Aspartate"
    }
    local r6510_code = links.get_code_link { code = "R65.10", text = "Systemic Inflammatory Response Syndrome (SIRS) of Non-Infectious Origin without Acute Organ Dysfunction" }
    local r6511_code = links.get_code_link { code = "R65.11", text = "Systemic Inflammatory Response Syndrome (SIRS) of Non-Infectious Origin with Acute Organ Dysfunction" }
    --[[
    #Abstraction Links
    abdominalDistentionAbs = abstractValue("ABDOMINAL_DISTENTION", "Abdominal Distention '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1)
    abdominalPainAbs = abstractValue("ABDOMINAL_PAIN", "Abdominal Pain '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2)
    abnormalSputumAbs = abstractValue("ABNORMAL_SPUTUM", "Abnormal Sputum '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3)
    r1114Code = codeValue("R11.14", "Bilious Vomiting: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4)
    r6883Code = codeValue("R68.83", "Chills '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5)
    cloudyUrineAbs = abstractValue("CLOUDY_URINE", "Cloudy Urine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6)
    --]]
    -- Abstraction Links
    local abdominal_distention_abs = links.get_abstraction_link { code = "ABDOMINAL_DISTENTION", text = "Abdominal Distention" }
    local abdominal_pain_abs = links.get_abstraction_link { code = "ABDOMINAL_PAIN", text = "Abdominal Pain" }
    local abnormal_sputum_abs = links.get_abstraction_link { code = "ABNORMAL_SPUTUM", text = "Abnormal Sputum" }
    local r1114_code = links.get_code_link { code = "R11.14", text = "Bilious Vomiting" }
    local r6883_code = links.get_code_link { code = "R68.83", text = "Chills" }
    local cloudy_urine_abs = links.get_abstraction_link { code = "CLOUDY_URINE", text = "Cloudy Urine" }
    --[[
    if PulmonaryDCode is None: 
        r05Codes = multiCodeValue(["R05.1", "R05.9"], "Cough: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7)
    diaphoreticAbs = abstractValue("DIAPHORETIC", "Diaphoretic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8)
    diarrheaAbs = abstractValue("DIARRHEA", "Diarrhea '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9)
    --]]
    local r05_codes =
        pulmonary_d_code == nil and links.get_code_links { codes = { "R05.1", "R05.9" }, text = "Cough" } or nil
    local diaphoretic_abs = links.get_abstraction_link { code = "DIAPHORETIC", text = "Diaphoretic" }
    local diarrhea_abs = links.get_abstraction_link { code = "DIARRHEA", text = "Diarrhea" }
    --[[
    r410Code = codeValue("R41.0", "Disorientation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10)
    r60Codes = multiCodeValue(["R60.1", "R60.9"], "Edema: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11)
    g934Codes = multiCodeValue(["G93.40", "G93.41", "G93.49"], "Encephalopathy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12)
    foulSmellingDischargeAbs = abstractValue("FOUL_SMELLING_DISCHARGE", "Foul-Smelling Discharge '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13)
    glasgowComaScoreDV = dvValue(dvGlasgowComaScale, "Glasgow Coma Score: [VALUE] (Result Date: [RESULTDATETIME])", calcGlasgowComaScale1, 14)
    --]]
    local r410_code = links.get_code_link { code = "R41.0", text = "Disorientation" }
    local r60_codes = links.get_code_links { codes = { "R60.1", "R60.9" }, text = "Edema" }
    local g934_codes = links.get_code_links { codes = { "G93.40", "G93.41", "G93.49" }, text = "Encephalopathy" }
    local foul_smelling_discharge_abs = links.get_abstraction_link { code = "FOUL_SMELLING_DISCHARGE", text = "Foul-Smelling Discharge" }
    local glasgow_coma_score_dv = links.get_discrete_value_link { discreteValueNames = dv_glasgow_coma_scale, text = "Glasgow Coma Score" }
    --[[
    inflammationAbs = abstractValue("INFLAMMATION", "Inflammation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 17)
    m7910Code = codeValue("M79.10", "Myalgias: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18)
    pelvicPainAbs = abstractValue("PELVIC_PAIN", "Pelvic Pain '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 20)
    photophobiaAbs = abstractValue("PHOTOPHOBIA", "Photophobia '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 22)
    r1112Code = codeValue("R11.12", "Projectile Vomiting: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23)
    purulentDrainageAbs = abstractValue("PURULENT_DRAINAGE", "Purulent Drainage '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 24)
    --]]
    local inflammation_abs = links.get_abstraction_link { code = "INFLAMMATION", text = "Inflammation" }
    local m7910_code = links.get_code_link { code = "M79.10", text = "Myalgias" }
    local pelvic_pain_abs = links.get_abstraction_link { code = "PELVIC_PAIN", text = "Pelvic Pain" }
    local photophobia_abs = links.get_abstraction_link { code = "PHOTOPHOBIA", text = "Photophobia" }
    local r1112_code = links.get_code_link { code = "R11.12", text = "Projectile Vomiting" }
    local purulent_drainage_abs = links.get_abstraction_link { code = "PURULENT_DRAINAGE", text = "Purulent Drainage" }
    --[[
    r8281Code = codeValue("R82.81", "Pyuria '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 25)
    soreThroatAbs = abstractValue("SORE_THROAT", "Sore Throat '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 27)
    stiffNeckAbs = abstractValue("STIFF_NECK", "Stiff Neck '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 28)
    swollenLymphNodesAbs = abstractValue("SWOLLEN_LYMPH_NODES", "Swollen Lymph Nodes '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 29)
    urinaryPainAbs = abstractValue("URINARY_PAIN", "Urinary Pain '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 30)
    r1110Code = codeValue("R11.10", "Vomiting: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 31)
    vomitingAbs = abstractValue("VOMITING", "Vomiting '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 32)
    r1113Code = codeValue("R11.13", "Vomiting Fecal Matter: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 33)
    --]]
    local r8281_code = links.get_code_link { code = "R82.81", text = "Pyuria" }
    local sore_throat_abs = links.get_abstraction_link { code = "SORE_THROAT", text = "Sore Throat" }
    local stiff_neck_abs = links.get_abstraction_link { code = "STIFF_NECK", text = "Stiff Neck" }
    local swollen_lymph_nodes_abs = links.get_abstraction_link { code = "SWOLLEN_LYMPH_NODES", text = "Swollen Lymph Nodes" }
    local urinary_pain_abs = links.get_abstraction_link { code = "URINARY_PAIN", text = "Urinary Pain" }
    local r1110_code = links.get_code_link { code = "R11.10", text = "Vomiting" }
    local vomiting_abs = links.get_abstraction_link { code = "VOMITING", text = "Vomiting" }
    local r1113_code = links.get_code_link { code = "R11.13", text = "Vomiting Fecal Matter" }
    --[[
    #infection Links
    aspergillosisCode = prefixCodeValue("^B44\.", "Aspergillosis Infection Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    bacteremiaCode = codeValue("R78.81", "Bacteremia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    bacterialInfectionCode = prefixCodeValue("^A49\.", "Bacterial Infection Of Unspecified Site Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3)
    bacteriuriaCode = codeValue("R82.71", "Bacteriuria: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4)
    blastomycosisCode = prefixCodeValue("^B40\.", "Blastomycosis Infection Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5)
    --]]
    -- Infection Links
    local aspergillosis_code = codes.get_code_prefix_link { prefix = "B44%.", text = "Aspergillosis Infection" }
    local bacteremia_code = links.get_code_link { code = "R78.81", text = "Bacteremia" }
    local bacterial_infection_code = codes.get_code_prefix_link { prefix = "A49%.", text = "Bacterial Infection Of Unspecified Site" }
    local bacteriuria_code = links.get_code_link { code = "R82.71", text = "Bacteriuria" }
    local blastomycosis_code = codes.get_code_prefix_link { prefix = "B40%.", text = "Blastomycosis Infection" }
    --[[
    chromomycosisPheomycoticAbscessCode = prefixCodeValue("^B43\.", "Chromomycosis And Pheomycotic Abscess Infection Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6)
    cryptococcosisCode = prefixCodeValue("^B45\.", "Cryptococcosis Infection Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7)
    cytomegaloviralCode = prefixCodeValue("^B25\.", "Cytomegaloviral Disease Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8)
    infectionAbs = abstractValue("INFECTION", "Infection '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10)
    mycosisCode = prefixCodeValue("^B49\.", "Mycosis Infection Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12)
    --]]
    local chromomycosis_pheomycotic_abscess_code = codes.get_code_prefix_link { prefix = "B43%.", text = "Chromomycosis And Pheomycotic Abscess Infection" }
    local cryptococcosis_code = codes.get_code_prefix_link { prefix = "B45%.", text = "Cryptococcosis Infection" }
    local cytomegaloviral_code = codes.get_code_prefix_link { prefix = "B25%.", text = "Cytomegaloviral Disease" }
    local infection_abs = links.get_abstraction_link { code = "INFECTION", text = "Infection" }
    local mycosis_code = codes.get_code_prefix_link { prefix = "B49%.", text = "Mycosis Infection" }
    --[[
    otherBacterialAgentsCode = prefixCodeValue("B96\.", "Other Bacterial Agents As The Cause Of Diseases Infection Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13)
    paracoccidioidomycosisCode = prefixCodeValue("^B41\.", "Paracoccidioidomycosis  Infection Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14)
    positiveCerebrospinalFluidCultureCode = codeValue("R83.5", "Positive Cerebrospinal Fluid Culture: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15)
    positiveRespiratoryCultureCode = codeValue("R84.5", "Positive Respiratory Culture: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16)
    bacteriaUrinedv = dvValue(dvBacteriaUrine, "Positive Result for Bacteria In Urine: [DISCRETEVALUE]", calcBacteriaUrine1, 0)
    --]]
    local other_bacterial_agents_code = codes.get_code_prefix_link { prefix = "B96%.", text = "Other Bacterial Agents As The Cause Of Diseases Infection" }
    local paracoccidioidomycosis_code = codes.get_code_prefix_link { prefix = "B41%.", text = "Paracoccidioidomycosis Infection" }
    local positive_cerebrospinal_fluid_culture_code = links.get_code_link { code = "R83.5", text = "Positive Cerebrospinal Fluid Culture" }
    local positive_respiratory_culture_code = links.get_code_link { code = "R84.5", text = "Positive Respiratory Culture" }
    local bacteria_urine_dv = links.get_discrete_value_link { discreteValueNames = dv_bacteria_urine, text = "Positive Result for Bacteria In Urine" }
    --[[
    positiveUrineAnalysisCode = codeValue("R82.998", "Positive Urine Analysis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17)
    positiveUrineCultureCode = codeValue("R82.79", "Positive Urine Culture: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18)
    postiveWoundCultureAbs = abstractValue("POSITIVE_WOUND_CULTURE", "Positive Wound Culture '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 19)
    sporotrichosisCode = prefixCodeValue("^B42\.", "Sporotrichosis Infection Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20)
    streptococcusStaphylococcusEnterococcusCode = prefixCodeValue("^B95\.", "Streptococcus, Staphylococcus, and Enterococcus Infection Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21)
    zygomycosisCode = prefixCodeValue("^B46\.", "Zygomycosis Infection Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 22)
    --]]
    local positive_urine_analysis_code = links.get_code_link { code = "R82.998", text = "Positive Urine Analysis" }
    local positive_urine_culture_code = links.get_code_link { code = "R82.79", text = "Positive Urine Culture" }
    local postive_wound_culture_abs = links.get_abstraction_link { code = "POSITIVE_WOUND_CULTURE", text = "Positive Wound Culture" }
    local sporotrichosis_code = codes.get_code_prefix_link { prefix = "B42%.", text = "Sporotrichosis Infection" }
    local streptococcus_staphylococcus_enterococcus_code = codes.get_code_prefix_link { prefix = "B95%.", text = "Streptococcus, Staphylococcus, and Enterococcus Infection" }
    local zygomycosis_code = codes.get_code_prefix_link { prefix = "B46%.", text = "Zygomycosis Infection" }
    --[[
    #Labs
    alaTranDV = dvValue(dvAlanineTransaminase, "Alanine Aminotransferase: [VALUE] (Result Date: [RESULTDATETIME])", calcAlanineTransaminase1, 1)
    cBloodDV = dvPositiveCheck(dict(maindiscreteDic), dvCBlood, "Blood Culture Result: '[VALUE]' (Result Date: [RESULTDATETIME])", 2)
    urineCultureDV = dvPositiveCheck(dict(maindiscreteDic), dvUrineCulture, "Urine Culture Result: '[VALUE]' (Result Date: [RESULTDATETIME])", 3)
    aspTranDV = dvValue(dvAspartateTransaminase, "Aspartate Aminotransferase: [VALUE] (Result Date: [RESULTDATETIME])", calcAspartateTransaminase1, 4)
    highBloodGlucoseDV = dvValue(dvBloodGlucose, "Blood Glucose: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodGlucose1, 6)
    if highBloodGlucoseDV is None: highBloodGlucoseDV = dvValue(dvBloodGlucosePOC, "Blood Glucose POC: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodGlucosePOC1, 7)
    --]]
    -- Labs
    local ala_tran_dv = links.get_discrete_value_link { discreteValueNames = dv_alanine_transaminase, text = "Alanine Aminotransferase" }
    local c_blood_dv = links.get_positive_check { discreteValueNames = dv_c_blood, text = "Blood Culture Result" }
    local urine_culture_dv = links.get_positive_check { discreteValueNames = dv_urine_culture, text = "Urine Culture Result" }
    local asp_tran_dv = links.get_discrete_value_link { discreteValueNames = dv_aspartate_transaminase, text = "Aspartate Aminotransferase" }
    local high_blood_glucose_dv =
        links.get_discrete_value_link { discreteValueNames = dv_blood_glucose, text = "Blood Glucose" } or
        links.get_discrete_value_link { discreteValueNames = dv_blood_glucose_poc, text = "Blood Glucose POC" }
    --[[
    highCReactiveProteinDV = dvValue(dvCreactiveProtein, "C-Reactive Protein: [VALUE] (Result Date: [RESULTDATETIME])", calcCreactiveProtein1, 8)
    pa02DV = dvValue(dvPaO2, "pa02: [VALUE] (Result Date: [RESULTDATETIME])", calcPAO21, 11)
    proclcitoninDV = dvValue(dvProcalcitonin, "Procalcitonin: [VALUE] (Result Date: [RESULTDATETIME])", calcProcalcitonin1, 13)
    serumBilirubinDV = dvValue(dvSerumBilirubin, "Serum Bilirubin: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumBilirubin1, 14)
    serumBunDV = dvValue(dvSerumBun, "Serum BUN: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumBun1, 15)
    serumCreatinineDV = dvValue(dvSerumCreatinine, "Serum Creatinine: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumCreatinine1, 16)
    serumLactateDV = dvValue(dvSerumLactate, "Serum Lactate: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumLactate1, 17)
    pocLactateDV = dvValue(dvPOCLactate, "Serum Lactate: [VALUE] (Result Date: [RESULTDATETIME])", calcPOCLactate1, 17)
    --]]
    local high_c_reactive_protein_dv = links.get_discrete_value_link { discreteValueNames = dv_c_reactive_protein, text = "C-Reactive Protein" }
    local pa_o2_dv = links.get_discrete_value_link { discreteValueNames = dv_pa_o2, text = "pao2" }
    local proclcitonin_dv = links.get_discrete_value_link { discreteValueNames = dv_procalcitonin, text = "Procalcitonin" }
    local serum_bilirubin_dv = links.get_discrete_value_link { discreteValueNames = dv_serum_bilirubin, text = "Serum Bilirubin" }
    local serum_bun_dv = links.get_discrete_value_link { discreteValueNames = dv_serum_bun, text = "Serum BUN" }
    local serum_creatinine_dv = links.get_discrete_value_link { discreteValueNames = dv_serum_creatinine, text = "Serum Creatinine" }
    local serum_lactate_dv = links.get_discrete_value_link { discreteValueNames = dv_serum_lactate, text = "Serum Lactate" }
    local poc_lactate_dv = links.get_discrete_value_link { discreteValueNames = dv_poc_lactate, text = "Serum Lactate" }
    --[[
    #Medication Links
    antibioticMed = antiboticMedValue(dict(mainMedDic), "Antibiotic", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 2)
    antibiotic2Med = antiboticMedValue(dict(mainMedDic), "Antibiotic2", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 3)
    antibioticAbs = abstractValue("ANTIBIOTIC", "Antibiotic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4)
    antibiotic2Abs = abstractValue("ANTIBIOTIC_2", "Antibiotic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5)
    --]]
    -- Medication Links
    local antibiotic_med = links.get_medication_link { cat = "Antibiotic", text = "Antibiotic" }
    local antibiotic2_med = links.get_medication_link { cat = "Antibiotic", text = "Antibiotic2" }
    local antibiotic_abs = links.get_abstraction_link { code = "ANTIBIOTIC", text = "Antibiotic" }  
    local antibiotic2_abs = links.get_abstraction_link { code = "ANTIBIOTIC_2", text = "Antibiotic" }
    --[[
    antifungalMed = medValue("Antifungal", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 6)
    antifungalAbs = abstractValue("ANTIFUNGAL", "Antifungal '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7)
    antiviralMed = medValue("Antiviral", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 8)
    antiviralAbs = abstractValue("ANTIVIRAL", "Antiviral '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9)
    --]]
    local antifungal_med = links.get_medication_link { cat = "Antifungal", text = "Antifungal" }
    local antifungal_abs = links.get_abstraction_link { code = "ANTIFUNGAL", text = "Antifungal" }
    local antiviral_med = links.get_medication_link { cat = "Antiviral", text = "Antiviral" }
    local antiviral_abs = links.get_abstraction_link { code = "ANTIVIRAL", text = "Antiviral" }
    --[[
    #Organ Dysfunction Only used for calculation
    g9341Code = codeValue("G93.41", "Acute Metabolic Encephalopathy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    acuteHeartFailure = multiCodeValue(["I50.21", "I50.31", "I50.41"], "Acute Heart Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    acuteKidneyFailure = prefixCodeValue("^N17\.", "Acute Kidney Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    acuteLiverFailure2 = multiCodeValue(["K72.00", "K72.01"], "Acute Liver Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    acuteRespiratroyFailure = multiCodeValue(["J96.00", "J96.01", "J96.02"], "Acute Respiratory Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    r4182Code = codeValue("R41.82", "Altered Level of Consciousness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    --]]
    -- Organ Dysfunction Only used for calculation
    local g9341_code = links.get_code_link { code = "G93.41", text = "Acute Metabolic Encephalopathy" }
    local acute_heart_failure = links.get_code_links { codes = { "I50.21", "I50.31", "I50.41" }, text = "Acute Heart Failure" }
    local acute_kidney_failure = codes.get_code_prefix_link { prefix = "N17%.", text = "Acute Kidney Failure" }
    local acute_liver_failure2 = links.get_code_links { codes = { "K72.00", "K72.01" }, text = "Acute Liver Failure" }
    local acute_respiratroy_failure = links.get_code_links { codes = { "J96.00", "J96.01", "J96.02" }, text = "Acute Respiratory Failure" }
    local r4182_code = links.get_code_link { code = "R41.82", text = "Altered Level of Consciousness" }
    --[[
    alteredAbs = abstractValue("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level Of Consciousness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    p02fio2DV = dvValue(dvPa02Fi02, "PaO2/FIO2 Ratio: [VALUE] (Result Date: [RESULTDATETIME])", calcPa02Fi021)
    lowBloodPressureAbs = abstractValue("LOW_BLOOD_PRESSURE", "Blood Pressure: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    lowPlateletCountDV = dvValue(dvPlateletCount, "Platelet Count: [VALUE] (Result Date: [RESULTDATETIME])", calcPlateletCount2)
    i21aCode = codeValue("I21.A", "Acute MI Type 2: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    lowUrineOutputAbs = abstractValue("LOW_URINE_OUTPUT", "Urine Output '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 21)
    --]]
    local altered_abs = links.get_abstraction_link { code = "ALTERED_LEVEL_OF_CONSCIOUSNESS", text = "Altered Level Of Consciousness" }
    local pa_o2_fi_o2_dv = links.get_discrete_value_link { discreteValueNames = dv_pa_o2_fi_o2, text = "PaO2/FIO2 Ratio" }
    local low_blood_pressure_abs = links.get_abstraction_link { code = "LOW_BLOOD_PRESSURE", text = "Blood Pressure" }
    local low_platelet_count_dv = links.get_discrete_value_link { discreteValueNames = dv_platelet_count, text = "Platelet Count" }
    local i21a_code = links.get_code_link { code = "I21.A", text = "Acute MI Type 2" }
    local low_urine_output_abs = links.get_abstraction_link { code = "LOW_URINE_OUTPUT", text = "Urine Output" }
    --[[
    #Vitals
    mapDV = dvValue(dvMAP, "Mean Arterial Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcMAP1, 6)
    mapAbs = abstractValue("LOW_MEAN_ARTERIAL_BLOOD_PRESSURE", "Mean Arterial Blood Pressure: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    sp02DV = dvValue(dvSPO2, "Sp02: [VALUE] (Result Date: [RESULTDATETIME])", calcSPO21, 5)
    sbpDV = dvValue(dvSBP, "Systolic Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcSBP1, 6)
    sbpAbs = abstractValue("LOW_SYSTOLIC_BLOOD_PRESSURE", "Systolic Blood Pressure: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    --]]
    -- Vitals
    local map_dv = links.get_discrete_value_link { discreteValueNames = dv_map, text = "Mean Arterial Blood Pressure" }
    local map_abs = links.get_abstraction_link { code = "LOW_MEAN_ARTERIAL_BLOOD_PRESSURE", text = "Mean Arterial Blood Pressure" }
    local sp_o2_dv = links.get_discrete_value_link { discreteValueNames = dv_sp_o2, text = "Sp02" }
    local sbp_dv = links.get_discrete_value_link { discreteValueNames = dv_sbp, text = "Systolic Blood Pressure" }
    local sbp_abs = links.get_abstraction_link { code = "LOW_SYSTOLIC_BLOOD_PRESSURE", text = "Systolic Blood Pressure" }
    --[[
    #Conflicting
    k5506Prefeix = prefixCodeValue("^K55\.06", "Acute Infarction of Intestine: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    k5504Prefix = prefixCodeValue("^K55\.04", "Acute Infarction of Large Intestine: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    k5502Prefix = prefixCodeValue("^K55\.02", "Acute Infarction of Small Intestine: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3)
    k85Prefix = prefixCodeValue("^K85\.", "Acute Pancreatitis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4)
    aspirationAbs = abstractValue("ASPIRATION", "Aspiration: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5)
    --]]
    -- Conflicting
    local k5506_prefeix = codes.get_code_prefix_link { prefix = "K55%.06", text = "Acute Infarction of Intestine" }
    local k5504_prefix = codes.get_code_prefix_link { prefix = "K55%.04", text = "Acute Infarction of Large Intestine" }
    local k5502_prefix = codes.get_code_prefix_link { prefix = "K55%.02", text = "Acute Infarction of Small Intestine" }
    local k85_prefix = codes.get_code_prefix_link { prefix = "K85%.", text = "Acute Pancreatitis" }
    local aspiration_abs = links.get_abstraction_link { code = "ASPIRATION", text = "Aspiration" }
    --[[
    j69Prefix = prefixCodeValue("^J69\.", "Aspiration Pneumonitis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6)
    burnCodes = multiCodeValue(["T31.1", "T31.10", "T31.11", "T31.2", "T31.20", "T31.21", "T31.22", "T31.3", "T31.30", "T31.31", "T31.32",
        "T31.33", "T31.4", "T31.40", "T31.42", "T31.43", "T31.44", "T31.5", "T31.50", "T31.51", "T31.52", "T31.53", "T31.54", "T31.55", 
        "T31.6", "T31.60", "T31.61", "T31.62", "T31.63", "T31.64", "T31.65", "T31.66", "T31.7", "T31.71", "T31.72", "T31.73", "T31.74", 
        "T31.75", "T31.76", "T31.77", "T31.8", "T31.81", "T31.82", "T31.83", "T31.84", "T31.85", "T31.86", "T31.87", "T31.88", "T31.9", 
        "T31.91", "T31.92", "T31.93", "T31.94", "T31.95", "T31.96", "T31.97", "T31.98", "T31.99", "T32.1", "T32.11", "T32.2", "T32.20", 
        "T32.21", "T32.22", "T32.3", "T32.30", "T32.31", "T32.32", "T32.33", "T32.4", "T32.41", "T32.42", "T32.43", "T32.44", "T32.5", 
        "T32.50", "T32.51", "T32.52", "T32.53", "T32.54", "T32.55", "T32.6", "T32.60", "T32.61", "T32.62", "T32.63", "T32.64", "T32.65", 
        "T32.66", "T32.7", "T32.70", "T32.71", "T32.72", "T32.73", "T32.74", "T32.75", "T32.76", "T32.77", "T32.8", "T32.81", "T32.82", 
        "T32.83", "T32.84", "T32.85", "T32.86", "T32.87", "T32.88", "T32.9", "T32.91", "T32.92", "T32.93", "T32.94", "T32.95", "T32.96", 
        "T32.97", "T32.98", "T32.99"], "Burns: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4)
    malignantNeoplasmAbs = abstractValue("MALIGNANT_NEOPLASM", "Malignant Neoplasms: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8)
    t07Prefix = prefixCodeValue("^T07\.", "Multiple Injuries: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9)
    e883Code = codeValue("E88.3", "Tumor lysis Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10)
    --]]
    local j69_prefix = codes.get_code_prefix_link { prefix = "J69%.", text = "Aspiration Pneumonitis" }
    local burn_codes = links.get_code_links {
        codes = {
            "T31.1", "T31.10", "T31.11", "T31.2", "T31.20", "T31.21", "T31.22", "T31.3", "T31.30", "T31.31", "T31.32",
            "T31.33", "T31.4", "T31.40", "T31.42", "T31.43", "T31.44", "T31.5", "T31.50", "T31.51", "T31.52", "T31.53",
            "T31.54", "T31.55", "T31.6", "T31.60", "T31.61", "T31.62", "T31.63", "T31.64", "T31.65", "T31.66", "T31.7",
            "T31.71", "T31.72", "T31.73", "T31.74", "T31.75", "T31.76", "T31.77", "T31.8", "T31.81", "T31.82", "T31.83",
            "T31.84", "T31.85", "T31.86", "T31.87", "T31.88", "T31.9", "T31.91", "T31.92", "T31.93", "T31.94", "T31.95",
            "T31.96", "T31.97", "T31.98", "T31.99", "T32.1", "T32.11", "T32.2", "T32.20", "T32.21", "T32.22", "T32.3",
            "T32.30", "T32.31", "T32.32", "T32.33", "T32.4", "T32.41", "T32.42", "T32.43", "T32.44", "T32.5", "T32.50",
            "T32.51", "T32.52", "T32.53", "T32.54", "T32.55", "T32.6", "T32.60", "T32.61", "T32.62", "T32.63", "T32.64",
            "T32.65", "T32.66", "T32.7", "T32.70", "T32.71", "T32.72", "T32.73", "T32.74", "T32.75", "T32.76", "T32.77",
            "T32.8", "T32.81", "T32.82", "T32.83", "T32.84", "T32.85", "T32.86", "T32.87", "T32.88", "T32.9", "T32.91",
            "T32.92", "T32.93", "T32.94", "T32.95", "T32.96", "T32.97", "T32.98", "T32.99"
        },
        text = "Burns"
    }
    local malignant_neoplasm_abs = links.get_abstraction_link { code = "MALIGNANT_NEOPLASM", text = "Malignant Neoplasms" }
    local t07_prefix = codes.get_code_prefix_link { prefix = "T07%.", text = "Multiple Injuries" }
    local e883_code = links.get_code_link { code = "E88.3", text = "Tumor lysis Syndrome" }
    --[[
    #Other Inflammatory Response Criteria
    if proclcitoninDV is not None: OIR += 1
    if mapDV is not None or mapAbs is not None: OIR += 1
    if sbpDV is not None or sbpAbs is not None: OIR += 1
    if highCReactiveProteinDV is not None:  OIR += 1
    --]]
    -- Other Inflammatory Response Criteria
    local oir =
        (proclcitonin_dv and 1 or 0) +
        ((map_dv or map_abs) and 1 or 0) +
        ((sbp_dv or sbp_abs) and 1 or 0) +
        (high_c_reactive_protein_dv and 1 or 0)
    --[[
    #Minor counts
    if diabetesE10Check is None and diabetesE11Check is None and steroidsAbs is None:
        if highBloodGlucoseDV is not None: labs.Links.Add(highBloodGlucoseDV); minorCount += 1
    if cloudyUrineAbs is not None: minorCount += 1; abs.Links.Add(cloudyUrineAbs)
    if r1110Code is not None or vomitingAbs is not None: 
        minorCount += 1; 
        if r1110Code is not None: abs.Links.Add(r1110Code)
        if vomitingAbs is not None: abs.Links.Add(vomitingAbs)
    --]]
    -- Minor counts
    local minor_count = 0
    if not diabetes_e10_check and not diabetes_e11_check and not steroids_abs then
        if high_blood_glucose_dv then
            minor_count = minor_count + 1
            laboratory_studies_header:add_link(high_blood_glucose_dv)
        end
    end
    if not r1110_code and not vomiting_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(r1110_code)
        clinical_evidence_header:add_link(vomiting_abs)
    end
    --[[
    if r1112Code is not None: minorCount += 1; abs.Links.Add(r1112Code)
    if r1113Code is not None: minorCount += 1; abs.Links.Add(r1113Code)
    if r1114Code is not None: minorCount += 1; abs.Links.Add(r1114Code)
    if highCReactiveProteinDV is not None: minorCount += 1; labs.Links.Add(highCReactiveProteinDV)
    if purulentDrainageAbs is not None: minorCount += 1; abs.Links.Add(purulentDrainageAbs)
    if foulSmellingDischargeAbs is not None: minorCount += 1; abs.Links.Add(foulSmellingDischargeAbs)
    if liverCirrhosisCheck is None and abdominalDistentionAbs is not None: minorCount += 1; abs.Links.Add(abdominalDistentionAbs)
    if inflammationAbs is not None: minorCount += 1; abs.Links.Add(inflammationAbs)
    if swollenLymphNodesAbs is not None: minorCount += 1; abs.Links.Add(swollenLymphNodesAbs)
    if r6883Code is not None: minorCount += 1; abs.Links.Add(r6883Code)
    if stiffNeckAbs is not None: minorCount += 1; abs.Links.Add(stiffNeckAbs)
    --]]
    if r1112_code then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(r1112_code)
    end
    if r1113_code then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(r1113_code)
    end
    if r1114_code then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(r1114_code)
    end
    if high_c_reactive_protein_dv then
        minor_count = minor_count + 1
        laboratory_studies_header:add_link(high_c_reactive_protein_dv)
    end
    if purulent_drainage_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(purulent_drainage_abs)
    end
    if foul_smelling_discharge_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(foul_smelling_discharge_abs)
    end
    if not liver_cirrhosis_check and abdominal_distention_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(abdominal_distention_abs)
    end
    if inflammation_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(inflammation_abs)
    end
    if swollen_lymph_nodes_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(swollen_lymph_nodes_abs)
    end
    if r6883_code then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(r6883_code)
    end
    if stiff_neck_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(stiff_neck_abs)
    end
    --[[
    if photophobiaAbs is not None: minorCount += 1; abs.Links.Add(photophobiaAbs)
    if soreThroatAbs is not None: minorCount += 1; abs.Links.Add(soreThroatAbs)
    if urinaryPainAbs is not None: minorCount += 1; abs.Links.Add(urinaryPainAbs)
    if diaphoreticAbs is not None and hyperhidrosisCode is None: minorCount += 1; abs.Links.Add(diaphoreticAbs)
    if abnormalSputumAbs is not None: minorCount += 1; abs.Links.Add(abnormalSputumAbs)
    if m7910Code is not None: minorCount += 1; abs.Links.Add(m7910Code)
    if diarrheaAbs is not None: minorCount += 1; abs.Links.Add(diarrheaAbs)
    if abdominalPainAbs is not None: minorCount += 1; abs.Links.Add(abdominalPainAbs)
    if pelvicPainAbs is not None: minorCount += 1; abs.Links.Add(pelvicPainAbs)
    --]]
    if photophobia_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(photophobia_abs)
    end
    if sore_throat_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(sore_throat_abs)
    end
    if urinary_pain_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(urinary_pain_abs)
    end
    if diaphoretic_abs and not hyperhidrosis_code then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(diaphoretic_abs)
    end
    if abnormal_sputum_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(abnormal_sputum_abs)
    end
    if m7910_code then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(m7910_code)
    end
    if diarrhea_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(diarrhea_abs)
    end
    if abdominal_pain_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(abdominal_pain_abs)
    end
    if pelvic_pain_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(pelvic_pain_abs)
    end
    --[[
    if r8281Code is not None: minorCount += 1; abs.Links.Add(r8281Code)
    if r60Codes is not None: minorCount += 1; abs.Links.Add(r60Codes)
    if g934Codes is not None: minorCount += 1; abs.Links.Add(g934Codes)
    if proclcitoninDV is not None: minorCount += 1
    if PulmonaryDCode is None and r05Codes is not None: minorCount += 1; abs.Links.Add(r05Codes)
    if r410Code is not None: minorCount += 1; abs.Links.Add(r410Code)
    --]]
    if r8281_code then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(r8281_code)
    end
    if r60_codes then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(r60_codes)
    end
    if g934_codes then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(g934_codes)
    end
    if proclcitonin_dv then
        minor_count = minor_count + 1
    end
    if not pulmonary_d_code and r05_codes then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(r05_codes)
    end
    if r410_code then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(r410_code)
    end
    --[[
    #SIRS Qualification and algorithm
    respiratoryCheck = False
    heartRateCheck = False
    tempCheck = False
    wbcCheck = False
    SirsCheck = False
    if minorCount >= 3:
        countPassed = True
    db.LogEvaluationScriptMessage("Major infectionCheck " + str(infectionCheck) + " " + str(account._id), scriptName, scriptInstance, "Debug")
    db.LogEvaluationScriptMessage("Minor Count" + str(minorCount) + " " + str(account._id), scriptName, scriptInstance, "Debug")
    --]]
    -- SIRS Qualification and algorithm
    local respiratory_check = false
    local heart_rate_check = false
    local temp_check = false
    local wbc_check = false
    local sirs_check = false
    local count_passed = false

    if minor_count >= 3 then
        count_passed = true
    end
    --[[
    #SIRS Specific Variables
    tempDict = {}
    heartDict = {}
    wbcDict = {}
    respDict = {}
    serumBandDict = {}
    pco2Dict = {}
    sirsResult = None
    --]]
    -- SIRS Specific Variables
    local temp_dict = {}
    local heart_dict = {}
    local wbc_dict = {}
    local resp_dict = {}
    local serum_band_dict = {}
    local pco2_dict = {}
    local sirs_result = nil
    --[[
    respLinkText = "Respiratory Rate: [VALUE] (Result Date: [RESULTDATETIME])"
    heartLinkText = "Heart Rate: [VALUE] (Result Date: [RESULTDATETIME])"
    wbcLinkText = "White Blood Cell Count: [VALUE] (Result Date: [RESULTDATETIME])"
    serumBandLinkText = "Serum Band: [VALUE] (Result Date: [RESULTDATETIME])"
    tempLinkText = "Temperature: [VALUE] (Result Date: [RESULTDATETIME])"
    pco2LinkText = "PCO2: [VALUE] (Result Date: [RESULTDATETIME])"
    temp = 0; heart = 0; wbc = 0; resp = 0; serumBand = 0; pCO2 = 0
    --]]
    local resp_link_text = "Respiratory Rate"
    local heart_link_text = "Heart Rate"
    local wbc_link_text = "White Blood Cell Count"
    local serum_band_link_text = "Serum Band"
    local temp_link_text = "Temperature"
    local pco2_link_text = "PCO2"
    local temp = 0
    local heart = 0
    local wbc = 0
    local resp = 0
    local serum_band = 0
    local pco2 = 0

    -- SIRS Find all Matching Values
    local temp_dict = {}
    local heart_dict = {}
    local wbc_dict = {}
    local resp_dict = {}
    local serum_band_dict = {}
    local pco2_dict = {}

    for _, dv in discrete.get_ordered_discrete_value {
        discreteValueNames = dv_temperature,
        predicate = function(dv, num)
            return num ~= nil and num > calc_temp_1 or num < calc_temp_2
        end
    } do
        table.insert(temp_dict, dv)
    end

    for _, dv in discrete.get_ordered_discrete_value {
        discreteValueNames = dv_heart_rate,
        predicate = function(dv, num)
            return num ~= nil and num > calc_heart_rate_1
        end
    } do
        table.insert(heart_dict, dv)
    end

    for _, dv in discrete.get_ordered_discrete_value {
        discreteValueNames = dv_wbc,
        predicate = function(dv, num)
            return num ~= nil and num > calc_wbc_1 or num < calc_wbc_2
        end
    } do
        table.insert(wbc_dict, dv)
    end

    for _, dv in discrete.get_ordered_discrete_value {
        discreteValueNames = dv_serum_band,
        predicate = function(dv, num)
            return num ~= nil and num > calc_serum_band_1
        end
    } do
        table.insert(serum_band_dict, dv)
    end

    for _, dv in discrete.get_ordered_discrete_value {
        discreteValueNames = dv_respiratory_rate,
        predicate = function(dv, num)
            return num ~= nil and num > calc_resp_rate_1
        end
    } do
        table.insert(resp_dict, dv)
    end

    for _, dv in discrete.get_ordered_discrete_value {
        discreteValueNames = dv_pco2,
        predicate = function(dv, num)
            return num ~= nil and num < calc_pco2
        end
    } do
        table.insert(pco2_dict, dv)
    end


    --[[
    #SIRS determine if SIRS is triggered
    sirsLookupDict = {}
    sirsX = 0
    sirsLacking = 0
    noResp = None
    noHeart = None
    noTemp = None
    noWBC = None
    --]]

    -- SIRS determine if SIRS is triggered
    local sirs_lookup_dict = {}
    local sirs_x = 0
    local sirs_lacking = 0
    local no_resp = nil
    local no_heart = nil
    local no_temp = nil
    local no_wbc = nil
    local sirs_criteria_counter = 0
    local no_resp = nil

    if #resp_dict > 0 then
    --[[
    if resp > 0:
        if (
            negationsRespiratoryCheck is None and
            psychogenicHyperventilationAbs is None and
            acuteHeartFailureCheck is None and
            pulmonaryEmbolismCheck is None
        ):
            sirsCriteriaCounter += 1
            respiratoryCheck = True
        sirsLacking += 1
        sirsX += 1
        sirsLookupDict[sirsX] = respDict[resp]
        dataConversion(respDict[resp].ResultDate, respLinkText, respDict[resp].Result, respDict[resp].UniqueId or respDict[resp]._id, sirsResp, 1)
    elif pCO2 > 0:
        sirsLacking += 1
        dataConversion(pco2Dict[pCO2].ResultDate, pco2LinkText, pco2Dict[pCO2].Result, pco2Dict[pCO2].UniqueId or pco2Dict[pCO2]._id, sirsResp, 1)
    else:
        noResp = MatchedCriteriaLink("The system did not find any Respiratory Rate values that match the specified SIRs Criteria range set.", None, None, None)
    --]]
        if
            not negations_respiratory_check and
            not psychogenic_hyperventilation_abs and
            not acute_heart_failure_check and
            not pulmonary_embolism_check
        then
            sirs_criteria_counter = sirs_criteria_counter + 1
            respiratory_check = true
        end
        sirs_lacking = sirs_lacking + 1
        sirs_x = sirs_x + 1
        sirs_lookup_dict[sirs_x] = resp_dict[resp]
        -- TODO: make link
        local no_resp = cdi_alert_link()
        no_resp.link_text = resp_link_text
    elseif #pco2_dict > 0 then
        sirs_lacking = sirs_lacking + 1
        local no_resp = cdi_alert_link()
        no_resp.link_text = pco2_link_text
    else
        local no_resp = cdi_alert_link()
        no_resp.link_text = "The system did not find any Respiratory Rate values that match the specified SIRs Criteria range set."
    end

    if #heart_dict > 0 then
    --[[
    if heart > 0:
        if (
            negationsHeartRateCheck is None and
            acuteHeartFailureCheck is None and
            pulmonaryEmbolismCheck is None
        ):
            sirsCriteriaCounter += 1
            heartRateCheck = True
        sirsLacking += 1
        sirsX += 1
        sirsLookupDict[sirsX] = heartDict[heart]
        dataConversion(heartDict[heart].ResultDate, heartLinkText, heartDict[heart].Result, heartDict[heart].UniqueId or heartDict[heart]._id, sirsHeart, 1)
    else:
        noHeart = MatchedCriteriaLink("The system did not find any Heart Rate values that match the specified SIRs Criteria range set.", None, None, None)
    --]]
    end

    if #temp_dict > 0 then
    --[[
    if temp > 0:
        sirsResult = cleanNumbers(str(tempDict[temp]['Result']))
        if FeverCheck is None and float(sirsResult) > float(calcTemp1):
            tempCheck = True
            sirsCriteriaCounter += 1
        if hypothermiaCheck is None and float(sirsResult) < float(calcTemp2):
            tempCheck = True
            sirsCriteriaCounter += 1
        sirsLacking += 1
        sirsX += 1
        sirsLookupDict[sirsX] = tempDict[temp]
        dataConversion(tempDict[temp].ResultDate, tempLinkText, tempDict[temp].Result, tempDict[temp].UniqueId or tempDict[temp]._id, sirsTemp, 1)
    else:
        noTemp = MatchedCriteriaLink("The system did not find any Temperature values that match the specified SIRs Criteria range set.", None, None, None)
    --]]
    end
    if not long_term_immunomodulators_imunosupp_code and not leukemia_check then
    --[[
    if longTermImmunomodulatorsImunosuppCode is None and leukemiaCheck is None:
        if wbc > 0:
            sirsResult = cleanNumbers(str(wbcDict[wbc]['Result']))
            if goutFlareAbs is None and float(sirsResult) > float(calcwbc1):
                wbcCheck = True
                sirsCriteriaCounter += 1
            if lowHemoglobinDV is None and d469Code is None and a3e04305Code is None and currentChemotherapyAbs is None and float(sirsResult) < float(calcwbc2):
                wbcCheck = True
                sirsCriteriaCounter += 1
            sirsLacking += 1
            dataConversion(wbcDict[wbc].ResultDate, wbcLinkText, wbcDict[wbc].Result, wbcDict[wbc].UniqueId or wbcDict[wbc]._id, sirsWBC, 1)
        elif serumBand > 0:
            wbcCheck = True
            sirsCriteriaCounter += 1
            sirsLacking += 1
            dataConversion(serumBandDict[serumBand].ResultDate, serumBandLinkText, serumBandDict[serumBand].Result, serumBandDict[serumBand].UniqueId or serumBandDict[serumBand]._id, sirsWBC, 1)
        else:
            noWBC = MatchedCriteriaLink("The system did not find any WBC values that match the specified SIRs Criteria range set.", None, None, None)
    elif longTermImmunomodulatorsImunosuppCode is not None or leukemiaCheck is not None:
        if wbc > 0:
            sirsLacking += 1
            dataConversion(wbcDict[wbc].ResultDate, wbcLinkText, wbcDict[wbc].Result, wbcDict[wbc].UniqueId or wbcDict[wbc]._id, sirsWBC, 1, True)
        elif serumBand > 0:
            sirsLacking += 1
            dataConversion(serumBandDict[serumBand].ResultDate, serumBandLinkText, serumBandDict[serumBand].Result, serumBandDict[serumBand].UniqueId or serumBandDict[serumBand]._id, sirsWBC, 1, True)
        else:
            noWBC = MatchedCriteriaLink("The system did not find any WBC values that match the specified SIRs Criteria range set.", None, None, None)
    --]]
    end

    --[[
    #Sirs Lacking Check
    sirsLacking2 = 0
    respRateDV = dvValue(dvRespiratoryRate, "Respiratory Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcRespRate2, 0)
    heartRateDV = dvValue(dvHeartRate, "Heart Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcHeartRa2, 0)
    highWBCDV = dvValue(dvWBC, "WBC: [VALUE] (Result Date: [RESULTDATETIME])", calcwbc3, 0)
    lowWBCDV = dvValue(dvWBC, "WBC: [VALUE] (Result Date: [RESULTDATETIME])", calcwbc4, 0)
    serumBandDV = dvValue(dvSerumBand, "Serum Band: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumB2, 0)
    highTempDV = dvValue(dvTemperature, "Temperature: [VALUE] (Result Date: [RESULTDATETIME])", calcTemp3, 0)
    lowTempDV = dvValue(dvTemperature, "Temperature: [VALUE] (Result Date: [RESULTDATETIME])", calcTemp4, 0)
    --]]
    -- Sirs Lacking Check
    local sirs_lacking_2 = 0
    local resp_rate_dv = links.get_discrete_value_link {
        discreteValueNames = dv_respiratory_rate,
        text = "Respiratory Rate",
        predicate = calc_resp_rate_2
    }
    local heart_rate_dv = links.get_discrete_value_link {
        discreteValueNames = dv_heart_rate,
        text = "Heart Rate",
        predicate = calc_heart_rate_2
    }
    local high_wbc_dv = links.get_discrete_value_link {
        discreteValueNames = dv_wbc,
        text = "WBC",
        predicate = calc_wbc_3
    }
    local low_wbc_dv = links.get_discrete_value_link {
        discreteValueNames = dv_wbc,
        text = "WBC",
        predicate = calc_wbc_4
    }
    local serum_band_dv = links.get_discrete_value_link {
        discreteValueNames = dv_serum_band,
        text = "Serum Band",
        predicate = calc_serum_band_2
    }
    local high_temp_dv = links.get_discrete_value_link {
        discreteValueNames = dv_temperature,
        text = "Temperature",
        predicate = calc_temp_3
    }
    local low_temp_dv = links.get_discrete_value_link {
        discreteValueNames = dv_temperature,
        text = "Temperature",
        predicate = calc_temp_4
    }

    --[[
    if respRateDV is not None:
        sirsLacking2 += 1
    if heartRateDV is not None:
        sirsLacking2 += 1
    if highWBCDV is not None or lowWBCDV is not None or serumBandDV is not None:
        sirsLacking2 += 1
    if highTempDV is not None or lowTempDV is not None:
        sirsLacking2 += 1
    --]]
    if resp_rate_dv then sirs_lacking_2 = sirs_lacking_2 + 1 end
    if heart_rate_dv then sirs_lacking_2 = sirs_lacking_2 + 1 end
    if high_wbc_dv or low_wbc_dv or serum_band_dv then sirs_lacking_2 = sirs_lacking_2 + 1 end
    if high_temp_dv or low_temp_dv then sirs_lacking_2 = sirs_lacking_2 + 1 end
    --[[
    #Sirs Lookup Call
    if sirsX > 0:
        sirsLookup(dict(mainSIRSDVDic), dict(sirsLookupDict))
    --]]
    -- Sirs Lookup Call
    if sirs_x > 0 then sirs_lookup(sirs_lookup_dict) end
    --[[
    #Sirs Disqualification Check
    if sirsCriteriaCounter == 2 and respiratoryCheck and heartRateCheck:
        SirsCheck = True
    --]]
    -- Sirs Disqualification Check
    if sirs_criteria_counter == 2 and respiratory_check and heart_rate_check then sirs_check = true end
    --[[
    #Infection Check
    if (
        aspergillosisCode is not None or
        bacterialInfectionCode is not None or
        blastomycosisCode is not None or
        chromomycosisPheomycoticAbscessCode is not None or
        cryptococcosisCode is not None or
        cytomegaloviralCode is not None or
        infectionAbs is not None or
        mycosisCode is not None or
        otherBacterialAgentsCode is not None or
        paracoccidioidomycosisCode is not None or
        sporotrichosisCode is not None or
        streptococcusStaphylococcusEnterococcusCode is not None or
        zygomycosisCode is not None or
        bacteremiaCode is not None or
        mycosisCode is not None or
        positiveCerebrospinalFluidCultureCode is not None or
        positiveRespiratoryCultureCode is not None or
        positiveUrineAnalysisCode is not None or
        positiveUrineCultureCode is not None or
        postiveWoundCultureAbs is not None or
        bacteriaUrinedv is not None or
        bacteriuriaCode is not None or
        cBloodDV is not None or 
        urineCultureDV is not None
    ):
        infectionCheck = True
    --]]
    --[[
    #Organ Dysfunction Count
    if (
        ((g9341Code is not None or glasgowComaScoreDV is not None) and alcoholAndOpioidAbuseCheck is None) or
        (r4182Code is not None or alteredAbs is not None ) or
        r410Code is not None
    ):
        ODC += 1
    --]]
    --[[
    if (
        lowBloodPressureAbs is not None or
        pa02DV is not None or
        sbpDV is not None
    ):
        ODC += 1
    --]]
    --[[
    if (
        p02fio2DV is not None or
        acuteRespiratroyFailure is not None or
        sp02DV is not None or
        pa02DV is not None
    ):
        ODC += 1 
    --]]
    --[[
    if (
        (serumCreatinineDV is not None and chronicKidneyFailureCheck is None) or 
        lowUrineOutputAbs is not None or
        acuteKidneyFailure is not None
    ):
        ODC += 1
    --]]
    --[[
    if (serumBilirubinDV is not None and liverCirrhosisCheck is None) or acuteLiverFailure2 is not None: ODC += 1
    if acuteHeartFailure is not None: ODC += 1
    if lowPlateletCountDV is not None: ODC += 1
    if i21aCode is not None: ODC += 1
    if serumLactateDV is not None or pocLactateDV is not None: ODC += 1
    --]]
    --[[
    db.LogEvaluationScriptMessage("SIRS Count " + str(sirsCriteriaCounter) + ", Sirs Lacking Count: " + str(sirsLacking) + ", Secondard Sirs Lacking Count: " + 
        str(sirsLacking2) + ", Sirs Disqualification Check: " + str(SirsCheck) + ", infection check: " + str(infectionCheck) +
        ", ODC Count: " + str(ODC) + " " + str(account._id), scriptName, scriptInstance, "Debug")
    --]]
    --[[
    #SME-1528
    sirsLackingCheck = False
    --]]



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    --[[
    if (
        (codesExist > 0 or a419Code is not None) and
        ((infectionCheck and message2) or 
        (message1 and (sirsLacking > 1 or sirsLacking2 > 1))) and
        subtitle == "Sepsis Dx Documented Possibly Lacking Clinical Evidence"
    ):
        if message1: dc.Links.Add(MatchedCriteriaLink("Possible SIRS Criteria Not Met Please Review", None, None, None, False))
        if message2: 
            infection.Links.Add(MatchedCriteriaLink("Possible Infection Not Documented Please Review", None, None, None, False))
            if bacterialInfectionCode is not None: updateLinkText(bacterialInfectionCode, autoEvidenceText); infection.Links.Add(bacterialInfectionCode)
            if cytomegaloviralCode is not None: updateLinkText(cytomegaloviralCode, autoEvidenceText); infection.Links.Add(cytomegaloviralCode)
            if blastomycosisCode is not None: updateLinkText(blastomycosisCode, autoEvidenceText); infection.Links.Add(blastomycosisCode)
            if paracoccidioidomycosisCode is not None: updateLinkText(paracoccidioidomycosisCode, autoEvidenceText); infection.Links.Add(paracoccidioidomycosisCode)
            if sporotrichosisCode is not None: updateLinkText(sporotrichosisCode, autoEvidenceText); infection.Links.Add(sporotrichosisCode)
            if chromomycosisPheomycoticAbscessCode is not None: updateLinkText(chromomycosisPheomycoticAbscessCode, autoEvidenceText); infection.Links.Add(chromomycosisPheomycoticAbscessCode)
            if aspergillosisCode is not None: updateLinkText(aspergillosisCode, autoEvidenceText); infection.Links.Add(aspergillosisCode)
            if cryptococcosisCode is not None: updateLinkText(cryptococcosisCode, autoEvidenceText); infection.Links.Add(cryptococcosisCode)
            if zygomycosisCode is not None: updateLinkText(zygomycosisCode, autoEvidenceText); infection.Links.Add(zygomycosisCode)
            if mycosisCode is not None: updateLinkText(mycosisCode, autoEvidenceText); infection.Links.Add(mycosisCode)
            if streptococcusStaphylococcusEnterococcusCode is not None: updateLinkText(streptococcusStaphylococcusEnterococcusCode, autoEvidenceText); infection.Links.Add(streptococcusStaphylococcusEnterococcusCode)
            if otherBacterialAgentsCode is not None: updateLinkText(otherBacterialAgentsCode, autoEvidenceText); infection.Links.Add(otherBacterialAgentsCode)
            if infectionAbs is not None: updateLinkText(infectionAbs, autoEvidenceText); infection.Links.Add(infectionAbs)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to New Evidence that Supports the Sepsis Dx"
        result.Validated = True
        AlertConditions = True
    --]]
    --[[
    elif (
        (codesExist > 0 or a419Code is not None) and
        (infectionCheck is False or 
        (sirsLacking == 1 and OIR == 0) or
        (sirsLacking == 0 and OIR > 0) or 
        (sirsLacking == 0 and OIR == 0)) and
        sirsLacking2 < 2
    ):
        if sirsLacking == 0:
            if respRateDV is not None:
                sirsResp.Links.Add(respRateDV)
                sirsLookupLacking(dict(maindiscreteDic), respRateDV.DiscreteValueId)
            else:
                sirsResp.Links.Add(noResp)
            if heartRateDV is not None:
                sirsHeart.Links.Add(heartRateDV)
                sirsLookupLacking(dict(maindiscreteDic), heartRateDV.DiscreteValueId)
            else:
                sirsHeart.Links.Add(noHeart)
            if highWBCDV is not None or lowWBCDV is not None or serumBandDV is not None:    
                if highWBCDV is not None:
                    sirsWBC.Links.Add(highWBCDV)
                    sirsLookupLacking(dict(maindiscreteDic), highWBCDV.DiscreteValueId)
                if lowWBCDV is not None:
                    sirsWBC.Links.Add(lowWBCDV)
                    sirsLookupLacking(dict(maindiscreteDic), lowWBCDV.DiscreteValueId)
                if serumBandDV is not None:
                    sirsWBC.Links.Add(serumBandDV)
                    sirsLookupLacking(dict(maindiscreteDic), serumBandDV.DiscreteValueId)
            else:
                sirsWBC.Links.Add(noWBC)
            if highTempDV is not None or lowTempDV is not None:
                if highTempDV is not None:
                    sirsTemp.Links.Add(highTempDV)
                    sirsLookupLacking(dict(maindiscreteDic), highTempDV.DiscreteValueId)
                if lowTempDV is not None:
                    sirsTemp.Links.Add(lowTempDV)
                    sirsLookupLacking(dict(maindiscreteDic), lowTempDV.DiscreteValueId)
            else: 
                sirsTemp.Links.Add(noTemp)
        else:
            if noHeart is not None: sirsHeart.Links.Add(noHeart)
            if noWBC is not None: sirsWBC.Links.Add(noWBC)
            if noTemp is not None: sirsTemp.Links.Add(noTemp)
            if noResp is not None: sirsResp.Links.Add(noResp)
        sirsLackingCheck = True
        for code in codeList:
            desc = codeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            if tempCode is not None:
                dc.Links.Add(tempCode)
                break
        if a419Code is not None: dc.Links.Add(a419Code)
        if sirsLacking < 2 or (sirsLacking2 < 2 and sirsLacking == 0): dc.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None))
        if infectionAbs is None: infection.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None))
        result.Subtitle = "Sepsis Dx Documented Possibly Lacking Clinical Evidence"
        AlertConditions = True
    --]]
    --[[
    elif codesExist == 1:
        db.LogEvaluationScriptMessage("One specific code was on the chart, alert failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        if alertTriggered:
            for code in codeList:
                desc = codeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code  - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    dc.Links.Add(tempCode)
                    break
            result.Outcome = "AUTORESOLVED"
            result.Reason = "Autoresolved due to one Specified Code on the Account"
            result.Validated = True
            AlertConditions = True
        else: result.Passed = False
    --]]
    --[[
    elif subtitle == "Possible Sepsis Dx" and (a419Code is not None or codesExist > 0):
        if codesExist > 0:
            for code in codeList:
                desc = codeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code  - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    dc.Links.Add(tempCode)
                    break
        if a419Code is not None: dc.Links.Add(a419Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    --]]
    --[[
    elif (
        a419Code is None and codesExist == 0 and
        codesExist == 0 and
        (sirsCriteriaCounter >= 3 or
        (sirsCriteriaCounter == 2 and SirsCheck is False)) and
        infectionCheck
    ):
        result.Subtitle = "Possible Sepsis Dx"
        AlertPassed = True
    --]]
    --[[
    elif (
        a419Code is None and
        codesExist == 0 and
        infectionCheck is False and
        countPassed and
        (sirsCriteriaCounter >= 3 or
        (sirsCriteriaCounter == 2 and SirsCheck is False))
    ):
        result.Subtitle = "Possible Sepsis Dx"
        AlertPassed = True    
    --]]
    --[[
    elif (
        (subtitle == "Possible Non-Infectious SIRS without Organ Dysfunction" or
        subtitle == "Possible Non-Infectious SIRS with Organ Dysfunction") and
        (a419Code is not None or codesExist >= 1 or r6510Code is not None or r6511Code is not None)
    ):
        if r6510Code is not None: updateLinkText(r6510Code, autoCodeText); dc.Links.Add(r6510Code)
        if r6511Code is not None: updateLinkText(r6511Code, autoCodeText); dc.Links.Add(r6511Code)
        if a419Code is not None: updateLinkText(a419Code, autoCodeText); dc.Links.Add(a419Code)
        if codesExist >= 1:
            for code in codeList:
                desc = codeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code  - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    dc.Links.Add(tempCode)
                    break
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Sepsis Dx Existing and no C Blood Test Positive"
        result.Validated = True
        AlertConditions = True
    --]]
    --[[
    elif (
        codesExist == 0 and
        (sirsCriteriaCounter >= 3 or
        (sirsCriteriaCounter == 2 and SirsCheck is False))  and
        a419Code is None and
        infectionCheck == False and
        ODC == 0 and
        cBloodDV is None and
        urineCultureDV is None and
        antibioticMed is None and
        antibiotic2Med is None and
        antibioticAbs is None and
        antibiotic2Abs is None and 
        antifungalMed is None and
        antifungalAbs is None and
        antiviralMed is None and
        antiviralAbs is None and
        (k5506Prefeix is not None or
        k5504Prefix is not None or
        k5502Prefix is not None or
        k85Prefix is not None or
        aspirationAbs is not None or
        burnCodes is not None or 
        j69Prefix is not None or
        malignantNeoplasmAbs is not None or
        t07Prefix is not None or
        e883Code is not None) and
        r6510Code is None and
        r6511Code is None
    ):
        result.Subtitle = "Possible Non-Infectious SIRS without Organ Dysfunction"
        SIRSContri = True
        AlertPassed = True
    --]]
    --[[
    elif (
        codesExist == 0 and
        (sirsCriteriaCounter >= 3 or
        (sirsCriteriaCounter == 2 and SirsCheck is False)) and
        a419Code is None and
        infectionCheck == False and
        ODC >= 1 and
        cBloodDV is None and
        urineCultureDV is None and
        antibioticMed is None and
        antibiotic2Med is None and
        antibioticAbs is None and
        antibiotic2Abs is None and 
        antifungalMed is None and
        antifungalAbs is None and
        antiviralMed is None and
        antiviralAbs is None and
        (k5506Prefeix is not None or
        k5504Prefix is not None or
        k5502Prefix is not None or
        k85Prefix is not None or
        burnCodes is not None or 
        aspirationAbs is not None or
        j69Prefix is not None or
        malignantNeoplasmAbs is not None or
        t07Prefix is not None or
        e883Code is not None) and
        r6510Code is None and
        r6511Code is None
    ):
        result.Subtitle = "Possible Non-Infectious SIRS with Organ Dysfunction"
        SIRSContri = True
        AlertPassed = True
    --]]



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            --[[
            #Link No Sirs Messages
            if sirsLackingCheck is False:
                if noResp is not None: sirsResp.Links.Add(noResp)
                if noHeart is not None: sirsHeart.Links.Add(noHeart)
                if noTemp is not None: sirsTemp.Links.Add(noTemp)
                if noWBC is not None: sirsWBC.Links.Add(noWBC)
            --]]
            --[[
            #Negations
            kidneyDiseaseCode = multiCodeValue(["N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6"], "Kidney Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            negationAlanine = multiCodeValue(["B18.2", "B19.20", "K70.11", "K72.10", "K72.11", "K74.60", "K74.69"], "Negation Alanine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            i9581Code = codeValue("I95.81", "Post Procedural Hypotension: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            i9589Code = codeValue("I95.89", "Chronic Hypotension: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            --]]
            --[[
            #Abs
            #1-13
            if glasgowComaScoreDV is not None: abs.Links.Add(glasgowComaScoreDV) #14
            abstractValue("LOW_GLASGOW_COMA_SCORE", "Glasgow Coma Score: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 15, abs, True)
            codeValue("R09.02", "Hypoxemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, abs, True)
            --]]
            --[[
            #17-18
            codeValue("R23.1", "Pale: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19, abs, True)
            #20
            codeValue("K63.1", "Perforation of Intestine: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21, abs, True)
            #22-25
            abstractValue("RESPIRATORY_DISTRESS", "Respiratory Distress '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 26, abs, True)
            --]]
            --[[
            #27-33
            #Infection
            if bacteremiaCode is not None: infection.Links.Add(bacteremiaCode)
            if mycosisCode is not None: infection.Links.Add(mycosisCode)
            if positiveCerebrospinalFluidCultureCode is not None: infection.Links.Add(positiveCerebrospinalFluidCultureCode)
            if positiveRespiratoryCultureCode is not None: infection.Links.Add(positiveRespiratoryCultureCode)
            if positiveUrineAnalysisCode is not None: infection.Links.Add(positiveUrineAnalysisCode)
            if positiveUrineCultureCode is not None: infection.Links.Add(positiveUrineCultureCode)
            if postiveWoundCultureAbs is not None: infection.Links.Add(postiveWoundCultureAbs)
            if bacteriaUrinedv is not None: infection.Links.Add(bacteriaUrinedv)
            if bacteriuriaCode is not None: infection.Links.Add(bacteriuriaCode)
            if aspergillosisCode is not None: infection.Links.Add(aspergillosisCode)
            --]]
            --[[
            if bacterialInfectionCode is not None: infection.Links.Add(bacterialInfectionCode)
            if blastomycosisCode is not None: infection.Links.Add(blastomycosisCode)
            if chromomycosisPheomycoticAbscessCode is not None: infection.Links.Add(chromomycosisPheomycoticAbscessCode)
            if cryptococcosisCode is not None: infection.Links.Add(cryptococcosisCode)
            if cytomegaloviralCode is not None: infection.Links.Add(cytomegaloviralCode)
            if infectionAbs is not None: infection.Links.Add(infectionAbs)
            codeValue("T81.42XA", "Infection Following a Procedure, Deep Incisional Surgical Site: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, infection, True)
            if mycosisCode is not None: infection.Links.Add(mycosisCode)
            if otherBacterialAgentsCode is not None: infection.Links.Add(otherBacterialAgentsCode)
            if paracoccidioidomycosisCode is not None: infection.Links.Add(paracoccidioidomycosisCode)
            if sporotrichosisCode is not None: infection.Links.Add(sporotrichosisCode)
            if streptococcusStaphylococcusEnterococcusCode is not None: infection.Links.Add(streptococcusStaphylococcusEnterococcusCode)
            if zygomycosisCode is not None: infection.Links.Add(zygomycosisCode)
            --]]
            --[[
            #Labs
            if negationAlanine is None:
                if alaTranDV is not None: labs.Links.Add(alaTranDV) #1      
            elif negationAlanine is not None:
                if alaTranDV is not None: alaTranDV.Hidden = True; labs.Links.Add(alaTranDV)
            --]]
            --[[
            #2-3
            if negationAspartate is None:
                if aspTranDV is not None: labs.Links.Add(aspTranDV) #4
            elif negationAspartate is not None:
                if aspTranDV is not None: aspTranDV.Hidden = True; labs.Links.Add(aspTranDV) #4
            codeValue("D72.825", "Bandemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, labs, True)
            --]]
            --[[
            #6-8
            if anticoagulantAbs is None:
                dvValue(dvInr, "INR: [VALUE] (Result Date: [RESULTDATETIME])", calcInr1, 9, labs, True)
            elif anticoagulantAbs is not None:
                inrDV = dvValue(dvInr, "INR: [VALUE] (Result Date: [RESULTDATETIME])", calcInr1, 9)
                if inrDV is not None: inrDV.Hidden = True; labs.Links.Add(inrDV)
            --]]
            --[[
            dvValue(dvInterleukin6, "Interleukin 6: [VALUE] (Result Date: [RESULTDATETIME])", calcInterleukin1, 10, labs, True)
            if pa02DV is not None: labs.Links.Add(pa02DV) #11
            dvValue(dvPlateletCount, "Platelet Count: [VALUE] (Result Date: [RESULTDATETIME])", calcPlateletCount1, 12, labs, True)
            if proclcitoninDV is not None: labs.Links.Add(proclcitoninDV) #13
            if serumBilirubinDV is not None: labs.Links.Add(serumBilirubinDV) #14
            --]]
            --[[
            if kidneyDiseaseCode is None:
                if serumBunDV is not None: labs.Links.Add(serumBunDV) #15
                if serumCreatinineDV is not None: labs.Links.Add(serumCreatinineDV) #16
            elif kidneyDiseaseCode is not None:
                if serumBunDV is not None: serumBunDV.Hidden = True; labs.Links.Add(serumBunDV)
                if serumCreatinineDV is not None: serumCreatinineDV.Hidden = True; labs.Links.Add(serumCreatinineDV)
            --]]
            --[[
            if serumLactateDV is not None: labs.Links.Add(serumLactateDV) #17
            codeValue("D69.6", "Thrombocytopenia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, labs, True)
            --]]
            --[[
            #Medications
            if antibioticMed is not None: meds.Links.Add(antibioticMed) #1
            if antibiotic2Med is not None: meds.Links.Add(antibiotic2Med) #2
            if antibioticAbs is not None: meds.Links.Add(antibioticAbs) #3
            if antibiotic2Abs is not None: meds.Links.Add(antibiotic2Abs) #4
            if antifungalMed is not None: meds.Links.Add(antifungalMed) #5
            if antifungalAbs is not None: meds.Links.Add(antifungalAbs) #6
            if antiviralMed is not None: meds.Links.Add(antiviralMed) #7
            if antiviralAbs is not None: meds.Links.Add(antiviralAbs) #8
            --]]
            --[[
            medValue("Dobutamine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 9, meds, True)
            abstractValue("DOBUTAMINE", "Dobutamine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10, meds, True)
            medValue("Dopamine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 11, meds, True)
            abstractValue("DOPAMINE", "Dopamine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12, meds, True)
            anesthesiaMedValue(dict(mainMedDic), "Epinephrine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 13, meds, True)
            abstractValue("EPINEPHRINE", "Epinephrine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 14, meds, True)
            medValue("Fluid Bolus", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 15, meds, True)
            abstractValue("FLUID_BOLUS", "Fluid Bolus '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 16, meds, True)
            --]]
            --[[
            anesthesiaMedValue(dict(mainMedDic), "Levophed", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 17, meds, True)
            abstractValue("LEVOPHED", "Levophed '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 18, meds, True)
            medValue("Methylprednisolone", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 19, meds, True)
            abstractValue("METHYLPREDNISOLONE", "Methylprednisolone '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 20, meds, True)
            medValue("Milrinone", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 21, meds, True)
            abstractValue("MILRINONE", "Milrinone '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 22, meds, True)
            anesthesiaMedValue(dict(mainMedDic), "Neosynephrine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 23, meds, True)
            abstractValue("NEOSYNEPHRINE", "Neosynephrine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 24, meds, True)
            --]]
            --[[
            medValue("Steroid", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 25, meds, True)
            abstractValue("STEROIDS", "Steroid '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 26, meds, True)
            abstractValue("VASOACTIVE_MEDICATION", "Vasoactive Medication '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 27, meds, True)
            anesthesiaMedValue(dict(mainMedDic), "Vasopressin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 28, meds, True)
            abstractValue("VASOPRESSIN", "Vasopressin '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 29, meds, True)
            --]]
            --[[
            #Oxygen
            codeValue("Z99.1", "Dependence on Ventilator: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, oxygen, True)
            multiCodeValue(["5A0935A", "5A0945A", "5A0955A"], "High Flow Nasal Oxygen: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, oxygen, True)
            codeValue("0BH17EZ", "Intubation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, oxygen, True)
            codeValue("5A1935Z", "Mechanical Ventilation Less than 24 hours: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, oxygen, True)
            codeValue("5A1945Z", "Mechanical Ventilation 24 to 96 hours: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, oxygen, True)
            codeValue("5A1955Z", "Mechanical Ventilation Greater than 96 hours: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, oxygen, True)
            --]]
            --[[
            multiCodeValue(["5A09357", "5A09457", "5A09557"], "Non-Invasive Ventilation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8, oxygen, True)
            abstractValue("VENTILATOR_DAYS", "Ventilator Days: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, oxygen, True)
            --]]
            --[[
            #Vitals
            if i9581Code is None and i9589Code is None:
                if lowBloodPressureAbs is not None: vitals.Links.Add(lowBloodPressureAbs)
            abstractValue("DELAYED_CAPILLARY_REFILL", "Delayed Capillary Refill '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2, vitals, True)
            dvValue(dvUrinary, "Urine Output: [VALUE] (Result Date: [RESULTDATETIME])", calcUrinary1, 3, vitals, True)
            if sp02DV is not None: vitals.Links.Add(sp02DV) #4
            --]]
            --[[
            #Contributing
            if SIRSContri == True:
                if k5506Prefeix is not None: contri.Links.Add(k5506Prefeix)
                if k5504Prefix is not None: contri.Links.Add(k5504Prefix)
                if k5502Prefix is not None: contri.Links.Add(k5502Prefix)
                if k85Prefix is not None: contri.Links.Add(k85Prefix)
                if burnCodes is not None: contri.Links.Add(burnCodes)
                if aspirationAbs is not None: contri.Links.Add(aspirationAbs)
                if j69Prefix is not None: contri.Links.Add(j69Prefix)
                if malignantNeoplasmAbs is not None: contri.Links.Add(malignantNeoplasmAbs)
                if t07Prefix is not None: contri.Links.Add(t07Prefix)
                if e883Code is not None: contri.Links.Add(e883Code)
            --]]
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

