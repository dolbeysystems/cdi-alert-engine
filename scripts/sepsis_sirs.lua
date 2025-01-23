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

local dv_heart_rate = {
    "Heart Rate cc (bpm)",
    "3.5 Heart Rate (Apical) (bpm)",
    "3.5 Heart Rate (Other) (bpm)",
    "3.5 Heart Rate (Radial) (bpm)",
    "SCC Monitor Pulse (bpm)"
}
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
local calc_sp_o2_1 = function(dv_, num) return num < 90 end

local dv_temperature = {
    "Temperature Degrees C 3.5 (degrees C)",
    "Temperature Degrees C 3.5 (degrees C)",
    "TEMPERATURE (C)"
}
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
local existing_alert = alerts.get_existing_cdi_alert { scriptName = Result.script_name }
local subtitle = existing_alert and existing_alert.subtitle or nil
local lacking_sirs_link_text = "Possible Lacking Positive SIRS Criteria, Please Review"
local lacking_infection_link_text = "Possible No Documentation of Infection Present, Please Review"
local lacking_sirs_message_found
local lacking_infection_message_found

if existing_alert then
    for _, alert_link in ipairs(existing_alert.links) do
        if alert_link.link_text == 'Documented Dx' then
            for _, links in ipairs(alert_link.links) do
                if links.link_text == lacking_sirs_link_text then
                    lacking_sirs_message_found = true
                end
            end
        end
        if alert_link.link_text == 'Infection' then
            for _, links in ipairs(alert_link.links) do
                if links.link_text == lacking_infection_link_text then
                    lacking_infection_message_found = true
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
    return dv and dv.route and dv.dosage and
        (
            string.find(dv.dosage, "hr") or string.find(dv.dosage, "hour") or
            string.find(dv.dosage, "min") or string.find(dv.dosage, "minute")
        ) and (
            string.find(dv.route, "Intravenous") or string.find(dv.route, "IV Push")
        )
end

local function antibiotic_med_value_predicate(dv, num_)
    return dv and dv.route and dv.category == "Antibiotic" and
        not (
            string.find(dv.route, "Eye") or string.find(dv.route, "topical") or
            string.find(dv.route, "ocular") or string.find(dv.route, "ophthalmic")
        )
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
                if
                    lists.includes(dv_temperature, dv.name) and
                    dvr and
                    not lists.includes(dv_temperature, match) and
                    dv.result_date == date
                then
                    -- Temperature
                    temp_dv = dv.result
                elseif
                    lists.includes(dv_heart_rate, dv.name) and
                    dvr and
                    not lists.includes(dv_heart_rate, match) and dv.result_date == date
                then
                    -- Heart Rate
                    hr_dv = dv.result
                elseif
                    lists.includes(dv_respiratory_rate, dv.name) and
                    dvr and
                    not lists.includes(dv_respiratory_rate, match) and
                    dv.result_date == date
                then
                    -- Respiratory Rate
                    resp_dv = dv.result
                end
            end
            local link = cdi_alert_link()
            link.link_text =
                date ..
                " Temp = " .. tostring(temp_dv) ..
                ", HR = " .. tostring(hr_dv) ..
                ", RR = " .. tostring(resp_dv)
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
                    if
                        lists.includes(dv_temperature, dv.name) and
                        dvr and
                        not lists.includes(dv_temperature, match) and
                        dv.result_date == date
                    then
                        -- Temperature
                        temp_dv = dv.result
                    elseif
                        lists.includes(dv_heart_rate, dv.name) and
                        dvr and
                        not lists.includes(dv_heart_rate, match) and
                        dv.result_date == date
                    then
                        -- Heart Rate
                        hr_dv = dv.result
                    elseif
                        lists.includes(dv_respiratory_rate, dv.name) and
                        dvr and
                        not lists.includes(dv_respiratory_rate, match) and
                        dv.result_date == date
                    then
                        -- Respiratory Rate
                        resp_dv = dv.result
                    end
                end
                local link = cdi_alert_link()
                link.link_text = date ..
                    " Temp = " .. tostring(temp_dv) ..
                    ", HR = " .. tostring(hr_dv) ..
                    ", RR = " .. tostring(resp_dv)
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
    -- Need to pack evidence into a table for this script because it otherwise exceeds the 200 varable limit
    local evidence = {}
    -- Documented Dx
    evidence.r6521_code = links.get_code_link { code = "R65.21", text = "Severe Sepsis with Septic Shock" }
    evidence.a419_code = links.get_code_link { code = "A41.9", text = "Sepsis Dx Unspecified" }
    -- Negations
    evidence.pulmonary_d_code = links.get_code_link {
        code = "J44.1",
        text = "Chronic Obstructive Pulmonary Disease with (Acute) Exacerbation"
    }
    evidence.phypothermia_check = links.get_code_links {
        codes = { "T68.0", "T68.XXXA", "T88.51XA", "T88.51" },
        text = "Hypothermia"
    }
    evidence.kidney_disease_code = links.get_code_links {
        codes = { "N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6" },
        text = "Kidney Disease"
    }
    evidence.fever_check = links.get_code_links {
        codes = { "G21.0", "T43.225A", "T43.224A", "T43.221A", "T88.3XXA", "R50.83", "R50.84", "R50.2" },
        text = "Fever"
    }
    evidence.d469_code = links.get_code_link { code = "D46.9", text = "Myelodysplastic Syndrome" }
    evidence.a3e04305_code = links.get_code_link {
        code = "3E04305",
        text = "Chemotherapy Medication Administration"
    }
    evidence.current_chemotherapy_abs = links.get_abstraction_link {
        code = "CURRENT_CHEMOTHERAPY",
        text = "Current Chemotherapy"
    }

    evidence.acute_heart_failure_check = links.get_code_links {
        codes = { "I50.21", "I50.23", "I50.33", "I50.41", "I50.43", "I50.811", "I50.813", "I50.814", "I50.9" },
        text = "Acute Heart Failure Codes"
    }
    evidence.diabetes_e10_check = codes.get_code_prefix_link { prefix = "E10%.", text = "Diabetes" }
    evidence.diabetes_e11_check = codes.get_code_prefix_link { prefix = "E11%.", text = "Diabetes" }
    evidence.gout_flare_abs = links.get_abstraction_link { code = "GOUT_FLARE", text = "Gout Flare" }
    evidence.hyperhidrosis_code = links.get_code_link { code = "R61", text = "Hyperhidrosis" }
    evidence.leukemia_check = links.get_code_links {
        codes = {
            "C91", "C91.0", "C91.00", "C91.01", "C91.01", "C91.1", "C91.10", "C91.11", "C91.12", "C91.3", "C91.30",
            "C91.31", "C91.32", "C91.4", "C91.40", "C91.41", "C91.42", "C91.5", "C91.50", "C91.51", "C91.52", "C91.6",
            "C91.60", "C91.61", "C91.62", "C91.A", "C91.A0", "C91.A1", "C91.A2", "C91.Z", "C91.Z0", "C91.Z1", "C91.Z2",
            "C91.9", "C91.90", "C91.91", "C91.92", "C92", "C92.0", "C92.00", "C92.01", "C92.02", "C92.1", "C92.11",
            "C92.12", "C92.2", "C92.20", "C92.21", "C92.22", "D45", "D75.81", "D70.0", "D72.0", "D70.1", "D70.2"
        },
        text = "Leukemia"
    }
    evidence.liver_cirrhosis_check = links.get_code_links {
        codes = {
            "K70.0", "K70.10", "K70.11", "K70.2", "K70.30", "K70.31", "K70.40", "K70.41", "K70.9", "K74.60", "K72.1",
            "K71", "K71.0", "K71.10", "K71.11", "K71.2", "K71.3", "K71.4", "K71.50", "K71.51", "K71.6", "K71.7",
            "K71.8", "K71.9", "K72.10", "K72.11", "K73.0", "K73.1", "K73.2", "K73.8", "K73.9", "R18.0"
        },
        text = "Liver Cirrhosis"
    }
    evidence.alcohol_and_opioid_abuse_check = links.get_code_links {
        codes = {
            "F10.920", "F10.921", "F10.929", "F10.930", "F10.931", "F10.932", "F10.939", "F11.120", "F11.121",
            "F11.122", "F11.129", "F11.13"
        },
        text = "Alcohol and Opioid Abuse"
    }
    evidence.chronic_kidney_failure_check = links.get_code_links {
        codes = { "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6", "N18.9" },
        text = "Chronic Kidney Failure"
    }
    evidence.long_term_immunomodulators_imunosupp_code = links.get_code_link {
        code = "Z79.69",
        text = "Long term use of other immunomodulators and immunosuppressants"
    }
    evidence.low_hemoglobin_dv = nil
    evidence.low_hematocrit_dv = nil
    if Account.patient.gender == "F" then
        evidence.low_hemoglobin_dv = links.get_discrete_value_link {
            discreteValueNames = dv_hemoglobin,
            text = "Hemoglobin",
            predicate = calc_hemoglobin_2
        }
        evidence.low_hematocrit_dv = links.get_discrete_value_link {
            discreteValueNames = dv_hematocrit,
            text = "Hematocrit",
            predicate = calc_hematocrit_1
        }
    elseif Account.patient.gender == "M" then
        evidence.low_hemoglobin_dv = links.get_discrete_value_link {
            discreteValueNames = dv_hemoglobin,
            text = "Hemoglobin",
            predicate = calc_hemoglobin_1
        }
        evidence.low_hematocrit_dv = links.get_discrete_value_link {
            discreteValueNames = dv_hematocrit,
            text = "Hematocrit",
            predicate = calc_hematocrit_2
        }
    end
    evidence.negations_heart_rate_check = links.get_code_links {
        codes = {
            "F15.10", "F15.929", "E05.90", "F41.0", "J44.1", "J45.902", "I48.0", "I48.1", "I48.19", "I48.20", "I48.21",
            "I48.3", "I48.4", "I48.91", "I48.92"
        },
        text = "Negated for Heart Rate"
    }
    evidence.negations_respiratory_check = links.get_code_links {
        codes = { "F15.929", "F45.8", "F41.0", "J45.901", "J45.902", "J44.1" },
        text = "Negations for Respiratory"
    }
    evidence.pulmonary_embolism_check = codes.get_code_prefix_link { prefix = "I26%.", text = "Pulmonary Embolism" }
    evidence.psychogenic_hyperventilation_abs = links.get_abstraction_link {
        code = "PSYCHOGENIC_HYPERVENTILATION",
        text = "Psychogenic Hyperventilation"
    }
    evidence.steroids_abs = links.get_abstraction_link { code = "STEROIDS", text = "Steroid" }
    evidence.anticoagulant_abs = links.get_abstraction_link { code = "ANTICOAGULANT", text = "Anticoagulant" }
    evidence.negation_aspartate = links.get_code_links {
        codes = { "B18.2", "B19.20", "K72.10", "K72.11", "K73", "K74.60", "K74.69", "Z79.01", "Z86.19" },
        text = "Negation Aspartate"
    }
    evidence.r6510_code = links.get_code_link {
        code = "R65.10",
        text = "Systemic Inflammatory Response Syndrome (SIRS) of Non-Infectious Origin without Acute Organ Dysfunction"
    }
    evidence.r6511_code = links.get_code_link {
        code = "R65.11",
        text = "Systemic Inflammatory Response Syndrome (SIRS) of Non-Infectious Origin with Acute Organ Dysfunction"
    }

    -- Abstraction Links
    evidence.abdominal_distention_abs =
        links.get_abstraction_link { code = "ABDOMINAL_DISTENTION", text = "Abdominal Distention" }
    evidence.abdominal_pain_abs = links.get_abstraction_link { code = "ABDOMINAL_PAIN", text = "Abdominal Pain" }
    evidence.abnormal_sputum_abs = links.get_abstraction_link { code = "ABNORMAL_SPUTUM", text = "Abnormal Sputum" }
    evidence.r1114_code = links.get_code_link { code = "R11.14", text = "Bilious Vomiting" }
    evidence.r6883_code = links.get_code_link { code = "R68.83", text = "Chills" }
    evidence.cloudy_urine_abs = links.get_abstraction_link { code = "CLOUDY_URINE", text = "Cloudy Urine" }
    evidence.r05_codes =
        evidence.pulmonary_d_code == nil and
        links.get_code_links { codes = { "R05.1", "R05.9" }, text = "Cough" } or
        nil
    evidence.diaphoretic_abs = links.get_abstraction_link { code = "DIAPHORETIC", text = "Diaphoretic" }
    evidence.diarrhea_abs = links.get_abstraction_link { code = "DIARRHEA", text = "Diarrhea" }
    evidence.r410_code = links.get_code_link { code = "R41.0", text = "Disorientation" }
    evidence.r60_codes = links.get_code_links { codes = { "R60.1", "R60.9" }, text = "Edema" }
    evidence.g934_codes = links.get_code_links { codes = { "G93.40", "G93.41", "G93.49" }, text = "Encephalopathy" }
    evidence.foul_smelling_discharge_abs =
        links.get_abstraction_link { code = "FOUL_SMELLING_DISCHARGE", text = "Foul-Smelling Discharge" }
    evidence.glasgow_coma_score_dv = links.get_discrete_value_link {
        discreteValueNames = dv_glasgow_coma_scale,
        text = "Glasgow Coma Score",
        predicate = calc_glasgow_coma_scale_1
    }
    evidence.inflammation_abs = links.get_abstraction_link { code = "INFLAMMATION", text = "Inflammation" }
    evidence.m7910_code = links.get_code_link { code = "M79.10", text = "Myalgias" }
    evidence.pelvic_pain_abs = links.get_abstraction_link { code = "PELVIC_PAIN", text = "Pelvic Pain" }
    evidence.photophobia_abs = links.get_abstraction_link { code = "PHOTOPHOBIA", text = "Photophobia" }
    evidence.r1112_code = links.get_code_link { code = "R11.12", text = "Projectile Vomiting" }
    evidence.purulent_drainage_abs =
        links.get_abstraction_link { code = "PURULENT_DRAINAGE", text = "Purulent Drainage" }
    evidence.r8281_code = links.get_code_link { code = "R82.81", text = "Pyuria" }
    evidence.sore_throat_abs = links.get_abstraction_link { code = "SORE_THROAT", text = "Sore Throat" }
    evidence.stiff_neck_abs = links.get_abstraction_link { code = "STIFF_NECK", text = "Stiff Neck" }
    evidence.swollen_lymph_nodes_abs =
        links.get_abstraction_link { code = "SWOLLEN_LYMPH_NODES", text = "Swollen Lymph Nodes" }
    evidence.urinary_pain_abs = links.get_abstraction_link { code = "URINARY_PAIN", text = "Urinary Pain" }
    evidence.r1110_code = links.get_code_link { code = "R11.10", text = "Vomiting" }
    evidence.vomiting_abs = links.get_abstraction_link { code = "VOMITING", text = "Vomiting" }
    evidence.r1113_code = links.get_code_link { code = "R11.13", text = "Vomiting Fecal Matter" }

    -- Infection Links
    evidence.aspergillosis_code = codes.get_code_prefix_link { prefix = "B44%.", text = "Aspergillosis Infection" }
    evidence.bacteremia_code = links.get_code_link { code = "R78.81", text = "Bacteremia" }
    evidence.bacterial_infection_code = codes.get_code_prefix_link { prefix = "A49%.", text = "Bacterial Infection Of Unspecified Site" }
    evidence.bacteriuria_code = links.get_code_link { code = "R82.71", text = "Bacteriuria" }
    evidence.blastomycosis_code = codes.get_code_prefix_link { prefix = "B40%.", text = "Blastomycosis Infection" }
    evidence.chromomycosis_pheomycotic_abscess_code = codes.get_code_prefix_link { prefix = "B43%.", text = "Chromomycosis And Pheomycotic Abscess Infection" }
    evidence.cryptococcosis_code = codes.get_code_prefix_link { prefix = "B45%.", text = "Cryptococcosis Infection" }
    evidence.cytomegaloviral_code = codes.get_code_prefix_link { prefix = "B25%.", text = "Cytomegaloviral Disease" }
    evidence.infection_abs = links.get_abstraction_link { code = "INFECTION", text = "Infection" }
    evidence.mycosis_code = codes.get_code_prefix_link { prefix = "B49%.", text = "Mycosis Infection" }
    evidence.other_bacterial_agents_code = codes.get_code_prefix_link { prefix = "B96%.", text = "Other Bacterial Agents As The Cause Of Diseases Infection" }
    evidence.paracoccidioidomycosis_code = codes.get_code_prefix_link { prefix = "B41%.", text = "Paracoccidioidomycosis Infection" }
    evidence.positive_cerebrospinal_fluid_culture_code = links.get_code_link { code = "R83.5", text = "Positive Cerebrospinal Fluid Culture" }
    evidence.positive_respiratory_culture_code = links.get_code_link { code = "R84.5", text = "Positive Respiratory Culture" }
    evidence.bacteria_urine_dv = links.get_discrete_value_link { discreteValueNames = dv_bacteria_urine, text = "Positive Result for Bacteria In Urine", predicate = calc_bacteria_urine_1 }
    evidence.positive_urine_analysis_code = links.get_code_link { code = "R82.998", text = "Positive Urine Analysis" }
    evidence.positive_urine_culture_code = links.get_code_link { code = "R82.79", text = "Positive Urine Culture" }
    evidence.postive_wound_culture_abs = links.get_abstraction_link { code = "POSITIVE_WOUND_CULTURE", text = "Positive Wound Culture" }
    evidence.sporotrichosis_code = codes.get_code_prefix_link { prefix = "B42%.", text = "Sporotrichosis Infection" }
    evidence.streptococcus_staphylococcus_enterococcus_code = codes.get_code_prefix_link { prefix = "B95%.", text = "Streptococcus, Staphylococcus, and Enterococcus Infection" }
    evidence.zygomycosis_code = codes.get_code_prefix_link { prefix = "B46%.", text = "Zygomycosis Infection" }

    -- Labs
    evidence.ala_tran_dv = links.get_discrete_value_link { discreteValueNames = dv_alanine_transaminase, text = "Alanine Aminotransferase", predicate = calc_alanine_transaminase_1 }
    evidence.c_blood_dv = links.get_discrete_value_link { discreteValueNames = dv_c_blood, text = "Blood Culture Result" }
    evidence.urine_culture_dv = links.get_discrete_value_link { discreteValueNames = dv_urine_culture, text = "Urine Culture Result", predicate = positive_check }
    evidence.asp_tran_dv = links.get_discrete_value_link { discreteValueNames = dv_aspartate_transaminase, text = "Aspartate Aminotransferase", predicate = calc_aspartate_transaminase_1 }
    evidence.high_blood_glucose_dv =
        links.get_discrete_value_link { discreteValueNames = dv_blood_glucose, text = "Blood Glucose", predicate = calc_blood_glucose_1 } or
        links.get_discrete_value_link { discreteValueNames = dv_blood_glucose_poc, text = "Blood Glucose POC", predicate = calc_blood_glucose_poc_1 }
    evidence.high_c_reactive_protein_dv = links.get_discrete_value_link { discreteValueNames = dv_c_reactive_protein, text = "C-Reactive Protein", predicate = calc_c_reactive_protein_1 }
    evidence.pa_o2_dv = links.get_discrete_value_link { discreteValueNames = dv_pa_o2, text = "pao2", calc_pa_o2_1, predicate = calc_pa_o2_1 }
    evidence.procalcitonin_dv = links.get_discrete_value_link { discreteValueNames = dv_procalcitonin, text = "Procalcitonin", predicate = calc_procalcitonin_1 }
    evidence.serum_bilirubin_dv = links.get_discrete_value_link { discreteValueNames = dv_serum_bilirubin, text = "Serum Bilirubin", predicate = calc_serum_bilirubin_1 }
    evidence.serum_bun_dv = links.get_discrete_value_link { discreteValueNames = dv_serum_bun, text = "Serum BUN", predicate = calc_serum_bun_1 }
    evidence.serum_creatinine_dv = links.get_discrete_value_link { discreteValueNames = dv_serum_creatinine, text = "Serum Creatinine", predicate = calc_serum_creatinine_1 }
    evidence.serum_lactate_dv = links.get_discrete_value_link { discreteValueNames = dv_serum_lactate, text = "Serum Lactate", predicate = calc_serum_lactate_1 }
    evidence.poc_lactate_dv = links.get_discrete_value_link { discreteValueNames = dv_poc_lactate, text = "Serum Lactate", predicate = calc_poc_lactate_1 }

    -- Medication Links
    evidence.antibiotic_med = links.get_medication_link { cat = "Antibiotic", text = "Antibiotic", predicate = antibiotic_med_value_predicate }
    evidence.antibiotic2_med = links.get_medication_link { cat = "Antibiotic", text = "Antibiotic2", predicate = antibiotic_med_value_predicate }
    evidence.antibiotic_abs = links.get_abstraction_link { code = "ANTIBIOTIC", text = "Antibiotic" }
    evidence.antibiotic2_abs = links.get_abstraction_link { code = "ANTIBIOTIC_2", text = "Antibiotic" }
    evidence.antifungal_med = links.get_medication_link { cat = "Antifungal", text = "Antifungal" }
    evidence.antifungal_abs = links.get_abstraction_link { code = "ANTIFUNGAL", text = "Antifungal" }
    evidence.antiviral_med = links.get_medication_link { cat = "Antiviral", text = "Antiviral" }
    evidence.antiviral_abs = links.get_abstraction_link { code = "ANTIVIRAL", text = "Antiviral" }

    -- Organ Dysfunction Only used for calculation
    evidence.g9341_code = links.get_code_link { code = "G93.41", text = "Acute Metabolic Encephalopathy" }
    evidence.acute_heart_failure = links.get_code_links { codes = { "I50.21", "I50.31", "I50.41" }, text = "Acute Heart Failure" }
    evidence.acute_kidney_failure = codes.get_code_prefix_link { prefix = "N17%.", text = "Acute Kidney Failure" }
    evidence.acute_liver_failure2 = links.get_code_links { codes = { "K72.00", "K72.01" }, text = "Acute Liver Failure" }
    evidence.acute_respiratroy_failure = links.get_code_links { codes = { "J96.00", "J96.01", "J96.02" }, text = "Acute Respiratory Failure" }
    evidence.r4182_code = links.get_code_link { code = "R41.82", text = "Altered Level of Consciousness" }
    evidence.altered_abs = links.get_abstraction_link { code = "ALTERED_LEVEL_OF_CONSCIOUSNESS", text = "Altered Level Of Consciousness" }
    evidence.pa_o2_fi_o2_dv = links.get_discrete_value_link { discreteValueNames = dv_pa_o2_fi_o2, text = "PaO2/FIO2 Ratio", predicate = calc_pa_o2_fi_o2_1 }
    evidence.low_blood_pressure_abs = links.get_abstraction_link { code = "LOW_BLOOD_PRESSURE", text = "Blood Pressure" }
    evidence.low_platelet_count_dv = links.get_discrete_value_link { discreteValueNames = dv_platelet_count, text = "Platelet Count", predicate = calc_platelet_count_2 }
    evidence.i21a_code = links.get_code_link { code = "I21.A", text = "Acute MI Type 2" }
    evidence.low_urine_output_abs = links.get_abstraction_link { code = "LOW_URINE_OUTPUT", text = "Urine Output" }

    -- Vitals
    evidence.map_dv = links.get_discrete_value_link { discreteValueNames = dv_map, text = "Mean Arterial Blood Pressure", predicate = calc_map_1 }
    evidence.map_abs = links.get_abstraction_link { code = "LOW_MEAN_ARTERIAL_BLOOD_PRESSURE", text = "Mean Arterial Blood Pressure" }
    evidence.sp_o2_dv = links.get_discrete_value_link { discreteValueNames = dv_sp_o2, text = "Sp02", predicate = calc_sp_o2_1 }
    evidence.sbp_dv = links.get_discrete_value_link { discreteValueNames = dv_sbp, text = "Systolic Blood Pressure", predicate = calc_sbp_1 }
    evidence.sbp_abs = links.get_abstraction_link { code = "LOW_SYSTOLIC_BLOOD_PRESSURE", text = "Systolic Blood Pressure" }

    -- Conflicting
    evidence.k5506_prefix = codes.get_code_prefix_link { prefix = "K55%.06", text = "Acute Infarction of Intestine" }
    evidence.k5504_prefix = codes.get_code_prefix_link { prefix = "K55%.04", text = "Acute Infarction of Large Intestine" }
    evidence.k5502_prefix = codes.get_code_prefix_link { prefix = "K55%.02", text = "Acute Infarction of Small Intestine" }
    evidence.k85_prefix = codes.get_code_prefix_link { prefix = "K85%.", text = "Acute Pancreatitis" }
    evidence.aspiration_abs = links.get_abstraction_link { code = "ASPIRATION", text = "Aspiration" }
    evidence.j69_prefix = codes.get_code_prefix_link { prefix = "J69%.", text = "Aspiration Pneumonitis" }
    evidence.burn_codes = links.get_code_links {
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
    evidence.malignant_neoplasm_abs = links.get_abstraction_link { code = "MALIGNANT_NEOPLASM", text = "Malignant Neoplasms" }
    evidence.t07_prefix = codes.get_code_prefix_link { prefix = "T07%.", text = "Multiple Injuries" }
    evidence.e883_code = links.get_code_link { code = "E88.3", text = "Tumor lysis Syndrome" }

    -- Other Inflammatory Response Criteria
    local oir =
        (evidence.procalcitonin_dv and 1 or 0) +
        ((evidence.map_dv or evidence.map_abs) and 1 or 0) +
        ((evidence.sbp_dv or evidence.sbp_abs) and 1 or 0) +
        (evidence.high_c_reactive_protein_dv and 1 or 0)

    -- Minor counts
    local minor_count = 0
    if not evidence.diabetes_e10_check and not evidence.diabetes_e11_check and not evidence.steroids_abs then
        if evidence.high_blood_glucose_dv then
            minor_count = minor_count + 1
            laboratory_studies_header:add_link(evidence.high_blood_glucose_dv)
        end
    end
    if not evidence.r1110_code and not evidence.vomiting_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.r1110_code)
        clinical_evidence_header:add_link(evidence.vomiting_abs)
    end
    if evidence.r1112_code then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.r1112_code)
    end
    if evidence.r1113_code then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.r1113_code)
    end
    if evidence.r1114_code then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.r1114_code)
    end
    if evidence.high_c_reactive_protein_dv then
        minor_count = minor_count + 1
        laboratory_studies_header:add_link(evidence.high_c_reactive_protein_dv)
    end
    if evidence.purulent_drainage_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.purulent_drainage_abs)
    end
    if evidence.foul_smelling_discharge_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.foul_smelling_discharge_abs)
    end
    if not evidence.liver_cirrhosis_check and evidence.abdominal_distention_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.abdominal_distention_abs)
    end
    if evidence.inflammation_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.inflammation_abs)
    end
    if evidence.swollen_lymph_nodes_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.swollen_lymph_nodes_abs)
    end
    if evidence.r6883_code then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.r6883_code)
    end
    if evidence.stiff_neck_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.stiff_neck_abs)
    end
    if evidence.photophobia_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.photophobia_abs)
    end
    if evidence.sore_throat_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.sore_throat_abs)
    end
    if evidence.urinary_pain_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.urinary_pain_abs)
    end
    if evidence.diaphoretic_abs and not evidence.hyperhidrosis_code then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.diaphoretic_abs)
    end
    if evidence.abnormal_sputum_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.abnormal_sputum_abs)
    end
    if evidence.m7910_code then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.m7910_code)
    end
    if evidence.diarrhea_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.diarrhea_abs)
    end
    if evidence.abdominal_pain_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.abdominal_pain_abs)
    end
    if evidence.pelvic_pain_abs then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.pelvic_pain_abs)
    end
    if evidence.r8281_code then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.r8281_code)
    end
    if evidence.r60_codes then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.r60_codes)
    end
    if evidence.g934_codes then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.g934_codes)
    end
    if evidence.procalcitonin_dv then
        minor_count = minor_count + 1
    end
    if not evidence.pulmonary_d_code and evidence.r05_codes then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.r05_codes)
    end
    if evidence.r410_code then
        minor_count = minor_count + 1
        clinical_evidence_header:add_link(evidence.r410_code)
    end

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

    -- SIRS Specific Variables
    local temp_dict = {}
    local heart_dict = {}
    local wbc_dict = {}
    local resp_dict = {}
    local serum_band_dict = {}
    local pco2_dict = {}
    local sirs_result = nil
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
        if
            not evidence.negations_respiratory_check and
            not evidence.psychogenic_hyperventilation_abs and
            not evidence.acute_heart_failure_check and
            not evidence.pulmonary_embolism_check
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
        if
            not evidence.negations_heart_rate_check and
            not evidence.acute_heart_failure_check and
            not evidence.pulmonary_embolism_check
        then
            sirs_criteria_counter = sirs_criteria_counter + 1
            heart_rate_check = true
        end
        sirs_lacking = sirs_lacking + 1
        sirs_x = sirs_x + 1
        sirs_lookup_dict[sirs_x] = heart_dict[heart]
        local link = cdi_alert_link()
        link.link_text = heart_link_text
        link.discrete_value_id = heart_dict[heart].unique_id
        sirs_heart_header:add_link(link)
    end

    if #temp_dict > 0 then
        if
            not evidence.fever_check and
            tonumber(temp_dict[temp].result) > tonumber(calc_temp_1)
        then
            temp_check = true
            sirs_criteria_counter = sirs_criteria_counter + 1
        end
        if
            not evidence.hypothermia_check and
            tonumber(temp_dict[temp].result) < tonumber(calc_temp_2)
        then
            temp_check = true
            sirs_criteria_counter = sirs_criteria_counter + 1
        end
        sirs_lacking = sirs_lacking + 1
        sirs_x = sirs_x + 1
        sirs_lookup_dict[sirs_x] = temp_dict[temp]

        local link = cdi_alert_link()
        link.link_text = temp_link_text
        link.discrete_value_id = temp_dict[temp].unique_id
        sirs_temp_header:add_link(link)
    else
        local no_temp = cdi_alert_link()
        no_temp.link_text = "The system did not find any Temperature values that match the specified SIRs Criteria range set."
    end

    if not evidence.long_term_immunomodulators_imunosupp_code and not evidence.leukemia_check then
        if #wbc_dict > 0 then
            if not evidence.gout_flare_abs and tonumber(wbc_dict[wbc].result) > tonumber(calc_wbc_1) then
                wbc_check = true
                sirs_criteria_counter = sirs_criteria_counter + 1
            end
            if
                not evidence.low_hemoglobin_dv and
                not evidence.d469_code and
                not evidence.a3e04305_code and
                not evidence.current_chemotherapy_abs and
                tonumber(wbc_dict[wbc].result) < tonumber(calc_wbc_2)
            then
                wbc_check = true
                sirs_criteria_counter = sirs_criteria_counter + 1
            end
            sirs_lacking = sirs_lacking + 1

            local link = cdi_alert_link()
            link.link_text = wbc_link_text
            link.discrete_value_id = wbc_dict[wbc].unique_id
            sirs_wbc_header:add_link(link)
        elseif #serum_band_dict > 0 then
            wbc_check = true
            sirs_criteria_counter = sirs_criteria_counter + 1
            sirs_lacking = sirs_lacking + 1

            local link = cdi_alert_link()
            link.link_text = serum_band_link_text
            link.discrete_value_id = serum_band_dict[serum_band].unique_id
            sirs_wbc_header:add_link(link)
        else
            local no_wbc = cdi_alert_link()
            no_wbc.link_text = "The system did not find any WBC values that match the specified SIRs Criteria range set."
        end
    elseif evidence.long_term_immunomodulators_imunosupp_code or evidence.leukemia_check then
        if #wbc_dict > 0 then
            sirs_lacking = sirs_lacking + 1

            local link = cdi_alert_link()
            link.link_text = wbc_link_text
            link.discrete_value_id = wbc_dict[wbc].unique_id
            sirs_wbc_header:add_link(link)
        elseif #serum_band_dict > 0 then
            sirs_lacking = sirs_lacking + 1

            local link = cdi_alert_link()
            link.link_text = serum_band_link_text
            link.discrete_value_id = serum_band_dict[serum_band].unique_id
            sirs_wbc_header:add_link(link)
        else
            local no_wbc = cdi_alert_link()
            no_wbc.link_text = "The system did not find any WBC values that match the specified SIRs Criteria range set."
        end
    end

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

    if resp_rate_dv then sirs_lacking_2 = sirs_lacking_2 + 1 end
    if heart_rate_dv then sirs_lacking_2 = sirs_lacking_2 + 1 end
    if high_wbc_dv or low_wbc_dv or serum_band_dv then sirs_lacking_2 = sirs_lacking_2 + 1 end
    if high_temp_dv or low_temp_dv then sirs_lacking_2 = sirs_lacking_2 + 1 end

    -- Sirs Lookup Call
    if sirs_x > 0 then sirs_lookup(sirs_lookup_dict) end

    -- Sirs Disqualification Check
    if sirs_criteria_counter == 2 and respiratory_check and heart_rate_check then sirs_check = true end

    local infection_check =
        evidence.aspergillosis_code or
        evidence.bacterial_infection_code or
        evidence.blastomycosis_code or
        evidence.chromomycosis_pheomycotic_abscess_code or
        evidence.cryptococcosis_code or
        evidence.cytomegaloviral_code or
        evidence.infection_abs or
        evidence.mycosis_code or
        evidence.other_bacterial_agents_code or
        evidence.paracoccidioidomycosis_code or
        evidence.sporotrichosis_code or
        evidence.streptococcus_staphylococcus_enterococcus_code or
        evidence.zygomycosis_code or
        evidence.bacteremia_code or
        evidence.positive_cerebrospinal_fluid_culture_code or
        evidence.positive_respiratory_culture_code or
        evidence.positive_urine_analysis_code or
        evidence.positive_urine_culture_code or
        evidence.postive_wound_culture_abs or
        evidence.bacteria_urine_dv or
        evidence.bacteriuria_code or
        evidence.c_blood_dv or
        evidence.urine_culture_dv

    -- Organ Dysfunction Count
    local odc = 0

    if
        ((evidence.g9341_code or evidence.altered_abs) and not evidence.alcohol_and_opioid_abuse_check) or
        (evidence.r4182_code or evidence.altered_abs) or
        evidence.r410_code
    then
        odc = odc + 1
    end

    if evidence.low_blood_pressure_abs or evidence.pa_o2_dv or evidence.sbp_dv then odc = odc + 1 end
    if evidence.pa_o2_fi_o2_dv or evidence.acute_respiratroy_failure or evidence.sp_o2_dv or evidence.pa_o2_dv then odc = odc + 1 end
    if
        (evidence.serum_creatinine_dv and not evidence.chronic_kidney_failure_check) or
        evidence.low_urine_output_abs or
        evidence.acute_kidney_failure
    then
        odc = odc + 1
    end
    if evidence.serum_bilirubin_dv and not evidence.liver_cirrhosis_check then odc = odc + 1 end
    if evidence.acute_heart_failure then odc = odc + 1 end
    if evidence.low_platelet_count_dv then odc = odc + 1 end
    if evidence.i21a_code then odc = odc + 1 end
    if evidence.serum_lactate_dv or evidence.poc_lactate_dv then odc = odc + 1 end

    -- SME-1528
    local sirs_lacking_check = false



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    local sirs_contributing = false
    if
        #account_alert_codes > 0 or evidence.a419_code or
        (
            (infection_check and lacking_infection_message_found) or
            (lacking_sirs_message_found and (sirs_lacking > 1 or sirs_lacking_2 > 1))
        ) and
        subtitle == "Sepsis Dx Documented Possibly Lacking Clinical Evidence"
    then
        if lacking_sirs_message_found then
            documented_dx_header:add_text_link("Possible SIRS Criteria Not Met Please Review")
        end
        if lacking_infection_message_found then
            infection_header:add_text_link("Possible Infection Not Documented Please Review")
            if evidence.bacterial_infection_code then
                evidence.bacterial_infection_code.link_text = "Autoresolved Evidence - " .. evidence.bacterial_infection_code.link_text
                infection_header:add_link(evidence.bacterial_infection_code)
            end
            if evidence.cytomegaloviral_code then
                evidence.cytomegaloviral_code.link_text = "Autoresolved Evidence - " .. evidence.cytomegaloviral_code.link_text
                infection_header:add_link(evidence.cytomegaloviral_code)
            end
            if evidence.blastomycosis_code then
                evidence.blastomycosis_code.link_text = "Autoresolved Evidence - " .. evidence.blastomycosis_code.link_text
                infection_header:add_link(evidence.blastomycosis_code)
            end
            if evidence.paracoccidioidomycosis_code then
                evidence.paracoccidioidomycosis_code.link_text = "Autoresolved Evidence - " .. evidence.paracoccidioidomycosis_code.link_text
                infection_header:add_link(evidence.paracoccidioidomycosis_code)
            end
            if evidence.sporotrichosis_code then
                evidence.sporotrichosis_code.link_text = "Autoresolved Evidence - " .. evidence.sporotrichosis_code.link_text
                infection_header:add_link(evidence.sporotrichosis_code)
            end
            if evidence.chromomycosis_pheomycotic_abscess_code then
                evidence.chromomycosis_pheomycotic_abscess_code.link_text = "Autoresolved Evidence - " .. evidence.chromomycosis_pheomycotic_abscess_code.link_text
                infection_header:add_link(evidence.chromomycosis_pheomycotic_abscess_code)
            end
            if evidence.aspergillosis_code then
                evidence.aspergillosis_code.link_text = "Autoresolved Evidence - " .. evidence.aspergillosis_code.link_text
                infection_header:add_link(evidence.aspergillosis_code)
            end
            if evidence.cryptococcosis_code then
                evidence.cryptococcosis_code.link_text = "Autoresolved Evidence - " .. evidence.cryptococcosis_code.link_text
                infection_header:add_link(evidence.cryptococcosis_code)
            end
            if evidence.zygomycosis_code then
                evidence.zygomycosis_code.link_text = "Autoresolved Evidence - " .. evidence.zygomycosis_code.link_text
                infection_header:add_link(evidence.zygomycosis_code)
            end
            if evidence.mycosis_code then
                evidence.mycosis_code.link_text = "Autoresolved Evidence - " .. evidence.mycosis_code.link_text
                infection_header:add_link(evidence.mycosis_code)
            end
            if evidence.streptococcus_staphylococcus_enterococcus_code then
                evidence.streptococcus_staphylococcus_enterococcus_code.link_text = "Autoresolved Evidence - " .. evidence.streptococcus_staphylococcus_enterococcus_code.link_text
                infection_header:add_link(evidence.streptococcus_staphylococcus_enterococcus_code)
            end
            if evidence.other_bacterial_agents_code then
                evidence.other_bacterial_agents_code.link_text = "Autoresolved Evidence - " .. evidence.other_bacterial_agents_code.link_text
                infection_header:add_link(evidence.other_bacterial_agents_code)
            end
            if evidence.infection_abs then
                evidence.infection_abs.link_text = "Autoresolved Evidence - " .. evidence.infection_abs.link_text
                infection_header:add_link(evidence.infection_abs)
            end
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to New Evidence that Supports the Sepsis Dx"
        Result.validated = true
        Result.passed = true

    elseif
        (#account_alert_codes > 0 or evidence.a419_code) and
        (
            not infection_check or
            (sirs_lacking < 2 and oir == 0) or
            (sirs_lacking == 0 and oir > 0) or
            (sirs_lacking == 0 and oir == 0)
        ) and
        sirs_lacking_2 < 2
    then
        if sirs_lacking == 0 then
            if resp_rate_dv then
                sirs_resp_header:add_link(resp_rate_dv)
                sirs_lookup_lacking(resp_rate_dv.discrete_value_id)
            else
                sirs_resp_header:add_link(no_resp)
            end
            if heart_rate_dv then
                sirs_heart_header:add_link(heart_rate_dv)
                sirs_lookup_lacking(heart_rate_dv.discrete_value_id)
            else
                sirs_heart_header:add_link(no_heart)
            end
            if high_wbc_dv or low_wbc_dv or serum_band_dv then
                if high_wbc_dv then
                    sirs_wbc_header:add_link(high_wbc_dv)
                    sirs_lookup_lacking(high_wbc_dv.discrete_value_id)
                end
                if low_wbc_dv then
                    sirs_wbc_header:add_link(low_wbc_dv)
                    sirs_lookup_lacking(low_wbc_dv.discrete_value_id)
                end
                if serum_band_dv then
                    sirs_wbc_header:add_link(serum_band_dv)
                    sirs_lookup_lacking(serum_band_dv.discrete_value_id)
                end
            else
                sirs_wbc_header:add_link(no_wbc)
            end
            if high_temp_dv or low_temp_dv then
                if high_temp_dv then
                    sirs_temp_header:add_link(high_temp_dv)
                    sirs_lookup_lacking(high_temp_dv.discrete_value_id)
                end
                if low_temp_dv then
                    sirs_temp_header:add_link(low_temp_dv)
                    sirs_lookup_lacking(low_temp_dv.discrete_value_id)
                end
            else
                sirs_temp_header:add_link(no_temp)
            end
        else
            sirs_heart_header:add_link(no_heart)
            sirs_wbc_header:add_link(no_wbc)
            sirs_temp_header:add_link(no_temp)
            sirs_resp_header:add_link(no_resp)
        end
        sirs_lacking_check = true
        for _, code in ipairs(account_alert_codes) do
            local desc = alert_code_dictionary[code]
            local temp_code = links.get_code_link { code = code, text = desc }
            if temp_code then
                documented_dx_header:add_link(temp_code)
                break
            end
        end
        documented_dx_header:add_link(evidence.a419_code)
        if sirs_lacking < 2 or (sirs_lacking_2 < 2 and sirs_lacking == 0) then
            documented_dx_header:add_link(cdi_alert_link())
        end
        if not infection_check then
            infection_header:add_link(cdi_alert_link())
        end
        Result.subtitle = "Sepsis Dx Documented Possibly Lacking Clinical Evidence"
        Result.passed = true

    elseif #account_alert_codes == 1 then
        if existing_alert then
            for _, code in ipairs(account_alert_codes) do
                local desc = alert_code_dictionary[code]
                local temp_code = links.get_code_link { code = code, text = desc }
                if temp_code then
                    documented_dx_header:add_link(temp_code)
                    break
                end
            end
            Result.outcome = "AUTORESOLVED"
            Result.reason = "Autoresolved due to one Specified Code on the Account"
            Result.validated = true
            Result.passed = true
        else
            Result.passed = false
        end

    elseif subtitle == "Possible Sepsis Dx" and (evidence.a419_code or #account_alert_codes > 0) then
        if #account_alert_codes > 0 then
            for _, code in ipairs(account_alert_codes) do
                local desc = alert_code_dictionary[code]
                local temp_code = links.get_code_link { code = code, text = desc }
                if temp_code then
                    documented_dx_header:add_link(temp_code)
                    break
                end
            end
        end
        documented_dx_header:add_link(evidence.a419_code)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        not evidence.a419_code and #account_alert_codes == 0 and
        #account_alert_codes == 0 and
        (sirs_criteria_counter >= 3 or (sirs_criteria_counter == 2 and not sirs_check)) and
        infection_check
    then
        Result.subtitle = "Possible Sepsis Dx"
        Result.passed = true

    elseif
        not evidence.a419_code and #account_alert_codes == 0 and
        not infection_check and
        count_passed and
        (sirs_criteria_counter >= 3 or (sirs_criteria_counter == 2 and not sirs_check))
    then
        Result.subtitle = "Possible Sepsis Dx"
        Result.passed = true

    elseif
        (
            subtitle == "Possible Non-Infectious SIRS without Organ Dysfunction" or
            subtitle == "Possible Non-Infectious SIRS with Organ Dysfunction"
        ) and (evidence.a419_code or #account_alert_codes > 0 or evidence.r6510_code or evidence.r6511_code)
    then
        if evidence.r6510_code then
            evidence.r6510_code.link_text = "Autoresolved Specified Code  - " .. evidence.r6510_code.link_text
            documented_dx_header:add_link(evidence.r6510_code)
        end
        if evidence.r6511_code then
            evidence.r6511_code.link_text = "Autoresolved Specified Code  - " .. evidence.r6511_code.link_text
            documented_dx_header:add_link(evidence.r6511_code)
        end
        if evidence.a419_code then
            evidence.a419_code.link_text = "Autoresolved Specified Code  - " .. evidence.a419_code.link_text
            documented_dx_header:add_link(evidence.a419_code)
        end
        if #account_alert_codes > 0 then
            for _, code in ipairs(account_alert_codes) do
                local desc = alert_code_dictionary[code]
                local temp_code = links.get_code_link { code = code, text = "Autoresolved Specified Code  - " .. desc }
                if temp_code then
                    documented_dx_header:add_link(temp_code)
                    break
                end
            end
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Sepsis Dx Existing and no C Blood Test Positive"
        Result.validated = true
        Result.passed = true

    elseif
        #account_alert_codes == 0 and
        (sirs_criteria_counter >= 3 or (sirs_criteria_counter == 2 and not sirs_check)) and
        not evidence.a419_code and
        not infection_check and
        odc == 0 and
        not evidence.c_blood_dv and
        not evidence.urine_culture_dv and
        not evidence.antibiotic_med and
        not evidence.antibiotic2_med and
        not evidence.antibiotic_abs and
        not evidence.antibiotic2_abs and
        not evidence.antifungal_med and
        not evidence.antifungal_abs and
        not evidence.antiviral_med and
        not evidence.antiviral_abs and
        (
            evidence.k5506_prefix or
            evidence.k5504_prefix or
            evidence.k5502_prefix or
            evidence.k85_prefix or
            evidence.aspiration_abs or
            evidence.burn_codes or
            evidence.j69_prefix or
            evidence.malignant_neoplasm_abs or
            evidence.t07_prefix or
            evidence.e883_code
        ) and
        not evidence.r6510_code and
        not evidence.r6511_code
    then
        Result.subtitle = "Possible Non-Infectious SIRS without Organ Dysfunction"
        sirs_contributing = true
        Result.passed = true

    elseif
        #account_alert_codes == 0 and
        (sirs_criteria_counter >= 3 or (sirs_criteria_counter == 2 and not sirs_check)) and
        not evidence.a419_code and
        not infection_check and
        odc >= 1 and
        not evidence.c_blood_dv and
        not evidence.urine_culture_dv and
        not evidence.antibiotic_med and
        not evidence.antibiotic2_med and
        not evidence.antibiotic_abs and
        not evidence.antibiotic2_abs and
        not evidence.antifungal_med and
        not evidence.antifungal_abs and
        not evidence.antiviral_med and
        not evidence.antiviral_abs and
        (
            evidence.k5506_prefix or
            evidence.k5504_prefix or
            evidence.k5502_prefix or
            evidence.k85_prefix or
            evidence.burn_codes or
            evidence.aspiration_abs or
            evidence.j69_prefix or
            evidence.malignant_neoplasm_abs or
            evidence.t07_prefix or
            evidence.e883_code
        ) and
        not evidence.r6510_code and
        not evidence.r6511_code
    then
        Result.subtitle = "Possible Non-Infectious SIRS with Organ Dysfunction"
        sirs_contributing = true
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Link No Sirs Messages
            if not sirs_lacking_check then
                if no_resp then sirs_resp_header:add_link(no_resp) end
                if no_heart then sirs_heart_header:add_link(no_heart) end
                if no_temp then sirs_temp_header:add_link(no_temp) end
                if no_wbc then sirs_wbc_header:add_link(no_wbc) end
            end

            -- Negations
            local kidney_disease_code = links.get_code_link {
                codes = { "N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6" },
                text = "Kidney Disease"
            }
            local negation_alanine = links.get_code_link {
                codes = { "B18.2", "B19.20", "K70.11", "K72.10", "K72.11", "K74.60", "K74.69" },
                text = "Negation Alanine"
            }
            local i9581_code = links.get_code_link { code = "I95.81", text = "Post Procedural Hypotension" }
            local i9589_code = links.get_code_link { code = "I95.89", text = "Chronic Hypotension" }

            -- Clinical Evidence
            -- 1-13
            clinical_evidence_header:add_link(evidence.glasgow_coma_score_dv)
            clinical_evidence_header:add_abstraction_link("LOW_GLASGOW_COMA_SCORE", "Glasgow Coma Score")
            clinical_evidence_header:add_code_link("R09.02", "Hypoxemia")
            -- 17-18
            clinical_evidence_header:add_code_link("R23.1", "Pale")
            -- 20
            clinical_evidence_header:add_code_link("K63.1", "Perforation of Intestine")
            -- 22-25
            clinical_evidence_header:add_abstraction_link("RESPIRATORY_DISTRESS", "Respiratory Distress")
            -- 27-33
            infection_header:add_link(evidence.bacteremia_code)
            infection_header:add_link(evidence.mycosis_code)
            infection_header:add_link(evidence.positive_cerebrospinal_fluid_culture_code)
            infection_header:add_link(evidence.positive_respiratory_culture_code)
            infection_header:add_link(evidence.positive_urine_analysis_code)
            infection_header:add_link(evidence.positive_urine_culture_code)
            infection_header:add_link(evidence.postive_wound_culture_abs)
            infection_header:add_link(evidence.bacteria_urine_dv)
            infection_header:add_link(evidence.bacteriuria_code)
            infection_header:add_link(evidence.aspergillosis_code)
            infection_header:add_link(evidence.bacterial_infection_code)
            infection_header:add_link(evidence.blastomycosis_code)
            infection_header:add_link(evidence.chromomycosis_pheomycotic_abscess_code)
            infection_header:add_link(evidence.cryptococcosis_code)
            infection_header:add_link(evidence.cytomegaloviral_code)
            infection_header:add_link(evidence.infection_abs)
            infection_header:add_code_link("T81.42XA", "Infection Following a Procedure, Deep Incisional Surgical Site")
            infection_header:add_link(evidence.mycosis_code)
            infection_header:add_link(evidence.other_bacterial_agents_code)
            infection_header:add_link(evidence.paracoccidioidomycosis_code)
            infection_header:add_link(evidence.sporotrichosis_code)
            infection_header:add_link(evidence.streptococcus_staphylococcus_enterococcus_code)
            infection_header:add_link(evidence.zygomycosis_code)

            -- Labs
            if negation_alanine then
                if evidence.ala_tran_dv then
                    evidence.ala_tran_dv.hidden = true
                    laboratory_studies_header:add_link(evidence.ala_tran_dv)
                end
            else
                if evidence.ala_tran_dv then laboratory_studies_header:add_link(evidence.ala_tran_dv) end
            end

            -- 2-3
            if not negation_alanine then
                if evidence.asp_tran_dv then laboratory_studies_header:add_link(evidence.asp_tran_dv) end
            else
                if evidence.asp_tran_dv then evidence.asp_tran_dv.hidden = true end
            end
            laboratory_studies_header:add_code_link("D72.825", "Bandemia")
            -- 6-8
            if not evidence.anticoagulant_abs then
                laboratory_studies_header:add_discrete_value_one_of_link(dv_inr, "INR", calc_inr_1)
            else
                local inr_dv = links.get_discrete_value_link {
                    discreteValueNames = dv_inr,
                    text = "INR",
                    predicate = calc_inr_1
                }
                if inr_dv then inr_dv.hidden = true end
                laboratory_studies_header:add_link(inr_dv)
            end
            laboratory_studies_header:add_discrete_value_one_of_link(dv_interleukin_6, "Interleukin 6", calc_interleukin_1)
            laboratory_studies_header:add_link(evidence.pa_o2_dv)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_platelet_count, "Platelet Count", calc_platelet_count_1)
            laboratory_studies_header:add_link(evidence.procalcitonin_dv)
            laboratory_studies_header:add_link(evidence.serum_bilirubin_dv)

            if kidney_disease_code then
                laboratory_studies_header:add_link(evidence.serum_bun_dv)
                laboratory_studies_header:add_link(evidence.serum_creatinine_dv)
            else
                if evidence.serum_bun_dv then
                    evidence.serum_bun_dv.hidden = true
                    laboratory_studies_header:add_link(evidence.serum_bun_dv)
                end
                if evidence.serum_creatinine_dv then
                    evidence.serum_creatinine_dv.hidden = true
                    laboratory_studies_header:add_link(evidence.serum_creatinine_dv)
                end
            end
            laboratory_studies_header:add_link(evidence.serum_lactate_dv)
            laboratory_studies_header:add_code_link("D69.6", "Thrombocytopenia")

            -- Medications
            treatment_and_monitoring_header:add_link(evidence.antibiotic_med)
            treatment_and_monitoring_header:add_link(evidence.antibiotic2_med)
            treatment_and_monitoring_header:add_link(evidence.antibiotic_abs)
            treatment_and_monitoring_header:add_link(evidence.antibiotic2_abs)
            treatment_and_monitoring_header:add_link(evidence.antifungal_med)
            treatment_and_monitoring_header:add_link(evidence.antifungal_abs)
            treatment_and_monitoring_header:add_link(evidence.antiviral_med)
            treatment_and_monitoring_header:add_link(evidence.antiviral_abs)
            treatment_and_monitoring_header:add_medication_link("Dobutamine", "Dobutamine")
            treatment_and_monitoring_header:add_abstraction_link("DOBUTAMINE", "Dobutamine")
            treatment_and_monitoring_header:add_medication_link("Dopamine", "Dopamine")
            treatment_and_monitoring_header:add_abstraction_link("DOPAMINE", "Dopamine")
            treatment_and_monitoring_header:add_medication_link("Epinephrine", "Epinephrine", anesthesia_med_predicate)
            treatment_and_monitoring_header:add_abstraction_link("EPINEPHRINE", "Epinephrine")
            treatment_and_monitoring_header:add_medication_link("Fluid Bolus", "Fluid Bolus")
            treatment_and_monitoring_header:add_abstraction_link("FLUID_BOLUS", "Fluid Bolus")
            treatment_and_monitoring_header:add_medication_link("Levophed", "Levophed", anesthesia_med_predicate)
            treatment_and_monitoring_header:add_abstraction_link("LEVOPHED", "Levophed")
            treatment_and_monitoring_header:add_medication_link("Methylprednisolone", "Methylprednisolone")
            treatment_and_monitoring_header:add_abstraction_link("METHYLPREDNISOLONE", "Methylprednisolone")
            treatment_and_monitoring_header:add_medication_link("Milrinone", "Milrinone")
            treatment_and_monitoring_header:add_abstraction_link("MILRINONE", "Milrinone")
            treatment_and_monitoring_header:add_medication_link("Neosynephrine", "Neosynephrine", anesthesia_med_predicate)
            treatment_and_monitoring_header:add_abstraction_link("NEOSYNEPHRINE", "Neosynephrine")
            treatment_and_monitoring_header:add_medication_link("Steroid", "Steroid")
            treatment_and_monitoring_header:add_abstraction_link("STEROIDS", "Steroid")
            treatment_and_monitoring_header:add_abstraction_link("VASOACTIVE_MEDICATION", "Vasoactive Medication")
            treatment_and_monitoring_header:add_medication_link("Vasopressin", "Vasopressin", anesthesia_med_predicate)
            treatment_and_monitoring_header:add_abstraction_link("VASOPRESSIN", "Vasopressin")

            -- Oxygen
            oxygenation_ventilation_header:add_code_link("Z99.1", "Dependence on Ventilator")
            oxygenation_ventilation_header:add_code_one_of_link({ "5A0935A", "5A0945A", "5A0955A" }, "High Flow Nasal Oxygen")
            oxygenation_ventilation_header:add_code_link("0BH17EZ", "Intubation")
            oxygenation_ventilation_header:add_code_link("5A1935Z", "Mechanical Ventilation Less than 24 hours")
            oxygenation_ventilation_header:add_code_link("5A1945Z", "Mechanical Ventilation 24 to 96 hours")
            oxygenation_ventilation_header:add_code_link("5A1955Z", "Mechanical Ventilation Greater than 96 hours")
            oxygenation_ventilation_header:add_code_one_of_link({ "5A09357", "5A09457", "5A09557" }, "Non-Invasive Ventilation")
            oxygenation_ventilation_header:add_abstraction_link("VENTILATOR_DAYS", "Ventilator Days")

            -- Vitals
            if not i9581_code and not i9589_code then
                vital_signs_intake_header:add_link(evidence.low_blood_pressure_abs)
            end
            vital_signs_intake_header:add_abstraction_link("DELAYED_CAPILLARY_REFILL", "Delayed Capillary Refill")
            vital_signs_intake_header:add_discrete_value_one_of_link(dv_urinary, "Urine Output", calc_urinary_1)
            vital_signs_intake_header:add_link(evidence.sp_o2_dv)

            -- Contributing
            if sirs_contributing then
                contributing_dx_header:add_link(evidence.k5506_prefix)
                contributing_dx_header:add_link(evidence.k5504_prefix)
                contributing_dx_header:add_link(evidence.k5502_prefix)
                contributing_dx_header:add_link(evidence.k85_prefix)
                contributing_dx_header:add_link(evidence.burn_codes)
                contributing_dx_header:add_link(evidence.aspiration_abs)
                contributing_dx_header:add_link(evidence.j69_prefix)
                contributing_dx_header:add_link(evidence.malignant_neoplasm_abs)
                contributing_dx_header:add_link(evidence.t07_prefix)
                contributing_dx_header:add_link(evidence.e883_code)
            end
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

