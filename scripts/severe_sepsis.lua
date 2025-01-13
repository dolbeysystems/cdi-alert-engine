---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Severe Sepsis
---
--- This script checks an account to see if it matches the criteria for a severe sepsis alert.
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
local dv_arterial_blood_oxygen = { "BLD GAS O2 (mmHg)", "PO2 (mmHg)" }
local calc_arterial_blood_oxygen_1 = function(dv_, num) return num < 60 end

local dv_dbp = { "BP Arterial Diastolic cc (mm Hg)", "DBP 3.5 (No Calculation) (mmhg)",
    "DBP 3.5 (No Calculation) (mm Hg)" }

local dv_glasgow_coma_scale = { "3.5 Neuro Glasgow Score" }
local calc_glasgow_coma_scale_1 = function(dv_, num) return num < 15 end
local calc_glasgow_coma_scale_2 = function(dv_, num) return num < 12 end

local dv_heart_rate = { "Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)",
    "3.5 Heart Rate (Radial) (bpm)", "SCC Monitor Pulse (bpm)" }

local dv_map = { "Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)" }
local calc_map_1 = function(dv_, num) return num < 60 end

local dv_platelet_count = { "PLATELET COUNT (10x3/uL)" }
local calc_platelet_count_severe_sepsis_1 = function(dv_, num) return num <= 100 end
local calc_platelet_count_1 = function(dv_, num) return num < 150 end
local calc_platelet_count_2 = function(dv_, num) return num < 100 end

local dv_po2_fio2 = { "PO2/FiO2 (mmHg)" }
local calc_po2_fio2_1 = function(dv_, num) return num <= 300 end

local dv_poc_lactate = { "" }
local calc_poc_lactate_1 = function(dv_, num) return 2 <= num and num < 4 end
local calc_poc_lactate_2 = function(dv_, num) return num >= 4 end

local dv_sbp = { "SBP 3.5 (No Calculation) (mm Hg)" }
local calc_sbp_1 = function(dv_, num) return num < 90 end

local dv_serum_bilirubin = { "BILIRUBIN (mg/dL)" }
local calc_serum_bilirubin_1 = function(dv_, num) return num >= 2.0 end

local dv_serum_creatinine = { "CREATININE (mg/dL)", "CREATININE SERUM (mg/dL)" }
local calc_serum_creatinine_1 = function(dv_, num) return num > 1.3 end

local dv_serum_lactate = { "LACTIC ACID (mmol/L)", "LACTATE (mmol/L)" }
local calc_serum_lactate_1 = 4
local calc_serum_lactate_2 = function(dv_, num) return 2 <= num and num < 4 end

local dv_spo2 = { "Pulse Oximetry(Num) (%)" }
local calc_spo2_1 = function(dv_, num) return num < 90 end


--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }
local subtitle = existing_alert and existing_alert.subtitle or nil

local message1_found = false
local message2_found = false
if existing_alert then
    for link in existing_alert.links or {} do
        if link.linkText == "Septic Shock Evidence" then
            for sublink in link.links or {} do
                if sublink.linkText == "Possible Missing Signs of Septic Shock Please Review" then
                    message1_found = true
                end
            end
        elseif link.linkText == "Organ Dysfunction Sign" then
            for sublink in link.links or {} do
                if sublink.linkText == "Possible Missing Signs of Organ Dysfunction Please Review" then
                    message2_found = true
                end
            end
        end
    end
end



--------------------------------------------------------------------------------
--- Header Variables and Helper Functions
--------------------------------------------------------------------------------
local result_links = {}
local documented_dx_header = headers.make_header_builder("Documented Dx", 1)
local organ_dysfunction_sign_header = headers.make_header_builder("Organ Dysfunction Sign", 2)
local septic_shock_indicators_header = headers.make_header_builder("Septic Shock Indicators", 3)
local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 4)
local sbp_header = headers.make_header_builder("SBP", 90)
local map_header = headers.make_header_builder("MAP", 91)
local lactate_ods_header = headers.make_header_builder("Lactate", 92)
local lactate_ssi_header = headers.make_header_builder("Lactate", 92)

local function compile_links()
    organ_dysfunction_sign_header:add_link(sbp_header:build(true))
    organ_dysfunction_sign_header:add_link(map_header:build(true))
    organ_dysfunction_sign_header:add_link(lactate_ods_header:build(true))

    septic_shock_indicators_header:add_link(lactate_ssi_header:build(true))

    table.insert(result_links, documented_dx_header:build(true))
    table.insert(result_links, organ_dysfunction_sign_header:build(true))
    table.insert(result_links, treatment_and_monitoring_header:build(true))
    table.insert(result_links, septic_shock_indicators_header:build(true))

    if existing_alert then
        result_links = links.merge_links(existing_alert.links, result_links)
    end
    Result.links = result_links
end



--------------------------------------------------------------------------------
--- Script Specific Functions
--------------------------------------------------------------------------------
---@param mv Medication med
---@return boolean
local function anesthesia_med_predicate(mv)
    return mv.route and
        mv.dosage and
        (
            string.match(mv.dosage, "%f[%a]hr%f[%A]") or
            string.match(mv.dosage, "%f[%a]hour%f[%A]") or
            string.match(mv.dosage, "%f[%a]min%f[%A]") or
            string.match(mv.dosage, "%f[%a]minute%f[%A]")
        ) and (
            string.match(mv.route, "%f[%a]Intravenous%f[%A]") or
            string.match(mv.route, "%f[%a]IV Push%f[%A]")
        )
end


local function dv_value_multi_min(dv_dic)
    local map_dvs = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_map,
    }
    local sbp_dvs = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_sbp,
    }
    local hr_dvs = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_heart_rate
    }
    local dbp_dvs = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_dbp
    }
    ---@type DiscreteValue[]
    local combined_map_sbp_dvs = {}
    local s_m = 0
    local m_m = 0
    for _, dv in map_dvs do
        if calc_map_1(dv, discrete.get_dv_value_number(dv)) then
            m_m = m_m + 1
            table.insert(combined_map_sbp_dvs, dv)
        end
    end
    for _, dv in sbp_dvs do
        if calc_sbp_1(dv, discrete.get_dv_value_number(dv)) then
            s_m = s_m + 1
            table.insert(combined_map_sbp_dvs, dv)
        end
    end

    local s = #sbp_dvs
    local d = #dbp_dvs
    local m = #map_dvs
    local h = #hr_dvs
    local sm = #combined_map_sbp_dvs

    local matched_sbp_list = {}
    local matched_map_list = {}

    if s_m > 1 or m_m > 1 then
        local abstracted_list = {}

        for _, item in combined_map_sbp_dvs do
            local dbp_dv = nil
            local hr_dv = nil
            local map_dv = nil
            local sbp_dv = nil
            local id = nil
            
            local matching_date = dates.date_string_to_int(item.result_date)
            if lists.includes(dv_sbp, item.name) and item.unique_id and not lists.includes(abstracted_list, item.unique_id) then
                sbp_dv = item.result
                table.insert(abstracted_list, item.unique_id)
                id = item.unique_id

                local link = cdi_alert_link()
                link.discrete_value_id = id
                link.discrete_value_name = item.name
                
                link.link_text = links.replace_link_place_holders(
                    "Systolic Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])",
                    nil, nil, item, nil
                )
                table.insert(matched_sbp_list, link)

                for _, item1 in map_dvs do
                    if dates.date_string_to_int(item1.result_date) == matching_date and lists.includes(dv_map, item1.name) then
                        map_dv = item1.result
                        table.insert(abstracted_list, item1.unique_id)
                        break
                    end
                end
            elseif lists.includes(dv_map, item.name) and discrete.get_dv_value_number(item) < calc_map_1 and not lists.includes(abstracted_list, item.unique_id) then
                map_dv = item.result
                id = item.unique_id
                table.insert(abstracted_list, item.unique_id)

                local link = cdi_alert_link()
                link.discrete_value_id = id
                link.link_text = links.replace_link_place_holders(
                    "Mean Arterial Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])",
                    nil, nil, item, nil
                )
                table.insert(matched_map_list, link)

                for item in sbp_dvs do
                    if dates.date_string_to_int(item.result_date) == matching_date and lists.includes(dv_sbp, item.name) then
                        sbp_dv = item.result
                        table.insert(abstracted_list, item.unique_id)
                        break
                    end
                end
            end

            if h > 0 then
                for _, item2 in hr_dvs do
                    if dates.date_string_to_int(item2.result_date) == matching_date then
                        hr_dv = item2.result
                        break
                    end
                end
            end
            if d > 0 then
                for _, item3 in dbp_dvs do
                    if dates.date_string_to_int(item3.result_date) == matching_date then
                        dbp_dv = item3.result
                        break
                    end
                end
            end

            dbp_dv = dbp_dv or "XX"
            hr_dv = hr_dv or "XX"
            map_dv = map_dv or "XX"
            sbp_dv = sbp_dv or "XX"
            if id and matching_date then
                local link = cdi_alert_link()
                link.discrete_value_id = id
                link.link_text = 
                    "[RESULTDATETIME] HR = " .. tostring(hr_dv) ..
                    ", BP = " .. tostring(sbp_dv) .. "/" .. tostring(dbp_dv) ..
                    ", MAP = " + tostring(map_dv)
                septic_shock_indicators_header:add_link(link)
            end
        end
    elseif s_m == 1 or m_m == 1 then
        for _, item in combined_map_sbp_dvs do
            local link = cdi_alert_link()
            link.discrete_value_id = item.unique_id
            if lists.includes(dv_sbp, item.name) then
                link.link_text = links.replace_link_place_holders(
                    "Systolic Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])",
                    nil, nil, item, nil
                )
                table.insert(matched_sbp_list, link)
            else
                link.link_text = links.replace_link_place_holders(
                    "Mean Arterial Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])",
                    nil, nil, item, nil
                )
                table.insert(matched_map_list, link)
            end
        end
    end

    if #matched_sbp_list == 0 then
        matched_sbp_list = { false }
    end
    if #matched_map_list == 0 then
        matched_map_list = { false }
    end
    return { matched_sbp_list, matched_map_list }
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
        ["A41.89"] = "Other Specified Sepsis ",
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
        ["T81.44XS"] = "Sepsis Following a Procedure, Sequela"
    }
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Negations
    local liver_cirrhosis_check = links.get_code_link {
        codes = {
            "K70.0", "K70.10", "K70.11", "K70.2", "K70.30", "K70.31", "K70.40", "K70.41", "K70.9", "K74.60", "K72.1",
            "K71", "K71.0", "K71.10", "K71.11", "K71.2", "K71.3", "K71.4", "K71.50", "K71.51", "K71.6", "K71.7", "K71.8",
            "K71.9", "K72.10", "K72.11", "K73.0", "K73.1", "K73.2", "K73.8", "K73.9", "R18.0"
        },
        text = "Liver Cirrhosis",
    }
    local alcohol_and_opioid_abuse_check = links.get_code_link {
        codes = {
            "F10.920", "F10.921", "F10.929", "F10.930", "F10.931", "F10.932",
            "F10.939", "F11.120", "F11.121", "F11.122", "F11.129", "F11.13"
        },
        text = "Alcohol and Opioid Abuse",
    }
    local chronic_kidney_failure_check = links.get_code_link {
        codes = {
            "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6", "N18.9"
        },
        text = "Chronic Kidney Failure",
    }

    -- Alert Trigger
    local r579_code = links.get_code_link { code = "R57.9", text = "Shock, unspecified" }
    local r6520_code = links.get_code_link { code = "R65.20", text = "Severe Sepsis without Septic Shock" }
    local r6521_code = links.get_code_link { code = "R65.21", text = "Severe Sepsis with Septic Shock" }
    local sepsis_code = links.get_code_link {
        codes = {
            "A40.0", "A40.1", "A40.3", "A40.8", "A40.9", " A41.01", "A41.02", "A41.1", "A41.2", "A41.3", "A41.4",
            "A41.9", "A41.50", "A41.51", "A41.52", "A41.53", "A41.54", "A41.59", "A41.8", "A41.81", "A41.89", "A42.7", "A22.7", "B37.7",
            "A26.7", "A54.86", "B00.7", "A32.7", "A24.1", "A20.7", "T81.44XA", "T81.44XD", "T81.44XS"
        },
        text = "Sepsis Dx",
    }

    -- Meds
    local dobutamine = links.get_medication_link { cat = "Dobutamine", text = "Dobutamine, Dosage" }
    if not dobutamine then
        dobutamine = links.get_abstraction_link { text = "Dobutamine", code = "DOBUTAMINE" }
    end
    local dopamine = links.get_medication_link { cat = "Dopamine", text = "Dopamine, Dosage" }
    if not dopamine then
        dopamine = links.get_abstraction_link { text = "Dopamine", code = "DOPAMINE" }
    end
    local epinephrine = links.get_anesthesia_medication_link { cat = "Epinephrine", text = "Epinephrine, Dosage" }
    if not epinephrine then
        epinephrine = links.get_abstraction_link { text = "Epinephrine", code = "EPINEPHRINE" }
    end
    local levophed = links.get_anesthesia_medication_link { cat = "Levophed", text = "Levophed, Dosage" }
    if not levophed then
        levophed = links.get_abstraction_link { text = "Levophed", code = "LEVOPHED" }
    end
    local milrinone = links.get_medication_link { cat = "Milrinone", text = "Milrinone, Dosage" }
    if not milrinone then
        milrinone = links.get_abstraction_link { text = "Milrinone", code = "MILRINONE" }
    end
    local neosynephrine = links.get_anesthesia_medication_link {
        cat = "Neosynephrine",
        text = "Neosynephrine, Dosage"
    }
    if not neosynephrine then
        neosynephrine = links.get_abstraction_link { text = "Neosynephrine", code = "NEOSYNEPHRINE" }
    end

    local vasoactive_medication_abs = links.get_abstraction_link { text = "Vasoactive Medication", code = "VASOACTIVE_MEDICATION" }
    local vasopressin = links.get_anesthesia_medication_link { cat = "Vasopressin", text = "Vasopressin, Dosage" }
    if not vasopressin then
        vasopressin = links.get_abstraction_link { text = "Vasopressin", code = "VASOPRESSIN" }
    end

    -- Organ Dysfunction Sign
    local g9341_code = links.get_code_link { code = "G93.41", text = "Acute Metabolic Encephalopathy" }
    local acute_heart_failure = links.get_code_link {
        codes = { "I50.21", "I50.31", "I50.41" },
        text = "Acute Heart Failure"
    }
    local acute_kidney_failure = links.get_code_link {
        codes = { "N17.", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6", "N18.9" },
        text = "Acute Kidney Failure"
    }
    local acute_liver_failure = links.get_code_link { codes = { "K72.00", "K72.01" }, text = "Acute Liver Failure" }
    local i21a_code = links.get_code_link { code = "I21.A", text = "Acute MI Type 2" }
    local acute_respiratory_failure = links.get_code_link {
        codes = { "J96.00", "J96.01", "J96.02" },
        text = "Acute Respiratory Failure"
    }
    local r4182_code = links.get_code_link { code = "R41.82", text = "Altered Level of Consciousness" }
    local altered_abs = links.get_abstraction_link { text = "Altered Level Of Consciousness" }
    local low_blood_pressure_abs = links.get_abstraction_link { text = "Blood Pressure" }
    local r410_code = links.get_code_link { code = "R41.0", text = "Disorientation" }
    local glasgow_coma_score_dv = links.get_discrete_value_link {
        discreteValueNames = dv_glasgow_coma_scale,
        text = "Glasgow Coma Score",
        predicate = calc_glasgow_coma_scale_2
    }
    local low_mean_arterial_blood_pressure_dv = links.get_discrete_value_link {
        discreteValueNames = dv_map,
        text = "Mean Arterial Blood Pressure",
        predicate = calc_map_1
    }
    local pa02_dv = links.get_discrete_value_link {
        discreteValueNames = dv_arterial_blood_oxygen,
        text = "PaO2",
        predicate = calc_arterial_blood_oxygen_1
    }
    local p02_fio2_dv = links.get_discrete_value_link {
        discreteValueNames = dv_po2_fio2,
        text = "PaO2/FiO2 Ratio",
        predicate = calc_po2_fio2_1
    }
    local low_platelet_count_dv = links.get_discrete_value_link {
        discreteValueNames = dv_platelet_count,
        text = "Platelet Count",
        predicate = calc_platelet_count_severe_sepsis_1
    }
    local high_serum_bilirubin_dv = links.get_discrete_value_link {
        discreteValueNames = dv_serum_bilirubin,
        text = "Serum Bilirubin",
        predicate = calc_serum_bilirubin_1
    }
    local high_serum_creatinine_dv = links.get_discrete_value_link {
        discreteValueNames = dv_serum_creatinine,
        text = "Serum Creatinine",
        predicate = calc_serum_creatinine_1
    }
    local high_serum_lactate_2_dv = links.get_discrete_value_link {
        discreteValueNames = dv_serum_lactate,
        text = "Serum Lactate",
        predicate = calc_serum_lactate_2
    }
    local high_poc_lactate_2_dv = links.get_discrete_value_link {
        discreteValueNames = dv_poc_lactate,
        text = "Serum Lactate",
        predicate = calc_poc_lactate_2
    }
    local sp_o2_dv = links.get_discrete_value_link {
        discreteValueNames = dv_spo2,
        text = "SP02",
        predicate = calc_spo2_1
    }
    local low_systolic_blood_pressure_dv = links.get_discrete_value_link {
        discreteValueNames = dv_sbp,
        text = "Systolic Blood Pressure",
        predicate = calc_sbp_1
    }
    local low_urine_output_abs = links.get_abstraction_link { text = "Low Urine Output" }

    -- Septic Shock
    local high_serum_lactate_4_dv = links.get_discrete_value_link {
        discreteValueNames = dv_serum_lactate,
        text = "Serum Lactate",
        predicate = calc_serum_lactate_1
    }
    local high_poc_lactate_4_dv = links.get_discrete_value_link {
        discreteValueNames = dv_poc_lactate,
        text = "Serum Lactate",
        predicate = calc_poc_lactate_1
    }
    local multi_sbp_map_dv = dv_value_multi_min()

    -- Organ Dysfunction Sign
    local ods = 0
    if
        ((g9341_code or glasgow_coma_score_dv) and not alcohol_and_opioid_abuse_check) or
        (r4182_code or altered_abs) or
        r410_code
    then
        ods = ods + 1
    end
    if
        low_blood_pressure_abs or
        low_mean_arterial_blood_pressure_dv or
        low_systolic_blood_pressure_dv
    then
        ods = ods + 1
    end
    if
        p02_fio2_dv or
        acute_respiratory_failure or
        sp_o2_dv or
        pa02_dv
    then
        ods = ods + 1
    end
    if high_serum_bilirubin_dv or liver_cirrhosis_check or acute_liver_failure then
        ods = ods + 1
    end
    if
        (high_serum_creatinine_dv or chronic_kidney_failure_check) or
        low_urine_output_abs or
        acute_kidney_failure
    then
        ods = ods + 1
    end
    if acute_heart_failure then ods = ods + 1 end
    if low_platelet_count_dv then ods = ods + 1 end
    if high_serum_lactate_2_dv or high_poc_lactate_2_dv then ods = ods + 1 end
    if i21a_code then ods = ods + 1 end
    if multi_sbp_map_dv[1][1] and #multi_sbp_map_dv[1] == 1 then
        ods = ods + 1
        for _, entry in multi_sbp_map_dv[1] do
            sbp_header:add_link(entry)
        end
        organ_dysfunction_sign_header:add_link(sbp_header:build(true))
    end
    if multi_sbp_map_dv[2][1] and #multi_sbp_map_dv[2] == 1 then
        ods = ods + 1
        for _, entry in multi_sbp_map_dv[2] do
            map_header:add_link(entry)
        end
        organ_dysfunction_sign_header:add_link(map_header:build(true))
    end

    -- Septic Shock Indicators
    local ssi = 0
    if multi_sbp_map_dv[1][1] and #multi_sbp_map_dv[1] > 1 then
        ssi = ssi + 1
    end
    if multi_sbp_map_dv[2][1] and #multi_sbp_map_dv[2] > 1 then
        ssi = ssi + 1
    end
    if high_serum_lactate_4_dv or high_poc_lactate_4_dv then
        ssi = ssi + 1
    end
    if
        epinephrine or
        levophed or
        milrinone or
        neosynephrine or
        vasoactive_medication_abs or
        vasopressin or
        dobutamine or
        dopamine
    then
        ssi = ssi + 1
    end



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    -- Main alert Algorithm
    if subtitle == "Severe Sepsis with Septic Shock Possibly Lacking Supporting Evidence" and ods > 0 and ssi > 0 then
        if message1_found then
            septic_shock_indicators_header:add_text_link("Possible Missing Signs of Septic Shock Please Review")
        end
        if message2_found then
            organ_dysfunction_sign_header:add_text_link("Possible Missing Signs of Organ Dysfunction Please Review")
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.validated = true
        Result.passed = true

    elseif r6521_code and (ods == 0 or ssi == 0) then
        if ods == 0 then
            organ_dysfunction_sign_header:add_text_link("Possible Missing Signs of Organ Dysfunction Please Review")
        end
        if ssi == 0 then
            septic_shock_indicators_header:add_text_link("Possible Missing Signs of Septic Shock Please Review")
        end
        if r6521_code then
            septic_shock_indicators_header:add_link(r6521_code)
        end
        Result.subtitle = "Severe Sepsis with Septic Shock Possibly Lacking Supporting Evidence"
        Result.passed = true

    elseif subtitle == "Severe Sepsis without Septic Shock Possibly Lacking Supporting Evidence" and ods > 0 then
        if message2_found then
            organ_dysfunction_sign_header:add_text_link("Possible Missing Signs of Organ Dysfunction Please Review")
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.validated = true
        Result.passed = true

    elseif r6520_code and ods == 0 then
        organ_dysfunction_sign_header:add_text_link("Possible Missing Signs of Organ Dysfunction Please Review")
        organ_dysfunction_sign_header:add_link(r6520_code)
        Result.subtitle = "Severe Sepsis without Septic Shock Possibly Lacking Supporting Evidence"
        Result.passed = true

    elseif subtitle == "Possible Severe Sepsis without Septic Shock present" and (r6520_code or r6521_code) then
        documented_dx_header:add_link(r6520_code)
        documented_dx_header:add_link(r6521_code)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to specified code now existing on the Account"
        Result.passed = true

    elseif sepsis_code and r6520_code and not r6521_code and ods >= 2 and ssi == 0 then
        documented_dx_header:add_link(sepsis_code)
        Result.subtitle = "Possible Severe Sepsis without Septic Shock present"
        Result.passed = true

    elseif subtitle == "Possible Severe Sepsis with Septic Shock present" and r6521_code then
        documented_dx_header:add_link(r6521_code)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to specified code now existing on the Account"
        Result.passed = true

    elseif (sepsis_code or r6520_code) and r6521_code and ods >= 2 and (ssi >= 1 or r579_code) then
        documented_dx_header:add_link(sepsis_code)
        documented_dx_header:add_link(r579_code)
        documented_dx_header:add_link(r6520_code)
        Result.subtitle = "Possible Severe Sepsis with Septic Shock present"
        Result.passed = true

    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            organ_dysfunction_sign_header:add_link(g9341_code)
            organ_dysfunction_sign_header:add_link(acute_heart_failure)
            organ_dysfunction_sign_header:add_link(acute_kidney_failure)
            organ_dysfunction_sign_header:add_link(acute_liver_failure)
            organ_dysfunction_sign_header:add_link(i21a_code)
            organ_dysfunction_sign_header:add_link(acute_respiratory_failure)
            organ_dysfunction_sign_header:add_link(r4182_code)
            organ_dysfunction_sign_header:add_link(altered_abs)
            organ_dysfunction_sign_header:add_link(low_blood_pressure_abs)
            organ_dysfunction_sign_header:add_link(r410_code)
            organ_dysfunction_sign_header:add_link(glasgow_coma_score_dv)
            organ_dysfunction_sign_header:add_link(low_mean_arterial_blood_pressure_dv)
            organ_dysfunction_sign_header:add_link(pa02_dv)
            organ_dysfunction_sign_header:add_link(p02_fio2_dv)
            organ_dysfunction_sign_header:add_link(low_platelet_count_dv)
            organ_dysfunction_sign_header:add_link(high_serum_bilirubin_dv)
            organ_dysfunction_sign_header:add_link(high_serum_creatinine_dv)

            if high_serum_lactate_2_dv then
                for entry in high_serum_lactate_2_dv do
                    lactate_ods_header:add_link(entry)
                end
            end
            if high_poc_lactate_2_dv then
                for entry in high_poc_lactate_2_dv do
                    lactate_ods_header:add_link(entry)
                end
            end
            organ_dysfunction_sign_header:add_link(sp_o2_dv)
            organ_dysfunction_sign_header:add_link(low_systolic_blood_pressure_dv)
            organ_dysfunction_sign_header:add_link(low_urine_output_abs)

            -- Septic Shock Indicators
            if high_serum_lactate_4_dv then
                for entry in high_serum_lactate_4_dv do
                    lactate_ssi_header:add_link(entry)
                end
            end
            if high_poc_lactate_4_dv then
                for entry in high_poc_lactate_4_dv do
                    lactate_ssi_header:add_link(entry)
                end
            end

            -- Treatment and Monitoring
            treatment_and_monitoring_header:add_medication_link("Albumin", "Albumin")
            treatment_and_monitoring_header:add_link(dobutamine)
            treatment_and_monitoring_header:add_link(dopamine)
            treatment_and_monitoring_header:add_link(epinephrine)

            local fluid_bolus = links.get_medication_link { cat = "Fluid Bolus", text = "Fluid Bolus, Dosage" }
            if not fluid_bolus then
                fluid_bolus = links.get_abstraction_link { text = "Fluid Bolus", code = "FLUID_BOLUS" }
            end
            treatment_and_monitoring_header:add_link(fluid_bolus)
            treatment_and_monitoring_header:add_link(levophed)
            treatment_and_monitoring_header:add_link(milrinone)
            treatment_and_monitoring_header:add_link(neosynephrine)
            treatment_and_monitoring_header:add_link(vasoactive_medication_abs)
            treatment_and_monitoring_header:add_link(vasopressin)
        end



        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        compile_links()
    end
end
