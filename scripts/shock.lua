---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Shock
---
--- This script checks an account to see if it matches the criteria for a shock alert.
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
local dates = require("libs.common.dates")
local discrete = require("libs.common.discrete_values")(Account)
local headers = require("libs.common.headers")(Account)
local lists = require("libs.common.lists")
local cdi_alert_link = require "cdi.link"



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local dv_alanine_aminotransferase = { "ALT (unit/L)" }
local function calc_alanine_aminotransferase_1(dv_, num) return num > 56 end

local dv_aspartate_aminotransferase = { "AST (unit/L)" }
local function calc_aspartate_aminotransferase_1(dv_, num) return num > 35 end

local dv_blood_loss = { "" }
local function calc_blood_loss_1(dv_, num) return num > 300 end

local dv_cardiac_index = { "Cardiac Index CAL cc" }
local function calc_cardiac_index_1(dv_, num) return num < 1.8 end

local dv_cardiac_output = { "Cardiac Output cc" }
local function calc_cardiac_output_1(dv_, num) return num < 4 end

local dv_central_venous_pressure = { "CVP cc" }
local function calc_central_venous_pressure_1(dv_, num) return num < 18 end

local dv_dbp = { "BP Arterial Diastolic cc (mm Hg)", "DBP 3.5 (No Calculation) (mmhg)",
    "DBP 3.5 (No Calculation) (mm Hg)" }

local dv_glasgow_coma_scale = { "3.5 Neuro Glasgow Score" }
local function calc_glasgow_coma_scale_1(dv_, num) return num < 15 end

local dv_heart_rate = { "Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)",
    "3.5 Heart Rate (Radial) (bpm)", "SCC Monitor Pulse (bpm)" }
local function calc_heart_rate_1(dv_, num) return num > 90 end
local function calc_heart_rate_2(dv_, num) return num < 60 end

local dv_hematocrit = { "HEMATOCRIT (%)", "HEMATOCRIT" }
local function calc_hematocrit_1(dv_, num) return num < 35 end
local function calc_hematocrit_2(dv_, num) return num < 40 end

local dv_hemoglobin = { "HEMOGLOBIN", "HEMOGLOBIN (g/dL)" }
local function calc_hemoglobin_1(dv_, num) return num < 13.5 end
local function calc_hemoglobin_2(dv_, num) return num < 11.6 end

local dv_map = { "Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)" }
local calc_map_1 = 70

local dv_oxygen_therapy = { "DELIVERY" }

local dv_pao2 = { "BLD GAS O2 (mmHg)", "PO2 (mmHg)" }
local function calc_pao2_1(dv_, num) return num < 80 end

local dv_paop = { "" }
local function calc_paop_1(dv_, num) return num >= 6 and num <= 12 end

local dv_plasma_transfusion = { "" }

local dv_pvr = { "" }
local function calc_pvr_1(dv_, num) return num > 200 end

local dv_red_blood_cell_transfusion = { "Volume (mL)-Transfuse Red Blood Cells (mL)",
    "Volume (mL)-Transfuse Red Blood Cells, Irradiated (mL)" }

local dv_respiratory_rate = { "3.5 Respiratory Rate (#VS I&O) (per Minute)" }
local function calc_respiratory_rate_1(dv_, num) return num > 20 end

local dv_sbp = { "SBP 3.5 (No Calculation) (mm Hg)" }
local calc_sbp_1 = 90

local dv_serum_blood_urea_nitrogen = { "BUN (mg/dL)" }
local function calc_serum_blood_urea_nitrogen_1(dv_, num) return num > 23 end

local dv_serum_creatinine = { "CREATININE (mg/dL)", "CREATININE SERUM (mg/dL)" }
local function calc_serum_creatinine_1(dv_, num) return num > 1.3 end

local dv_serum_lactate = { "LACTIC ACID (mmol/L)" }
local function calc_serum_lactate_1(dv_, num) return num >= 4 end

local dv_systemic_vascular_resistance = { "" }
local function calc_systemic_vascular_resistance_1(dv_, num) return num < 800 end

local dv_temperature = { "Temperature Degrees C 3.5 (degrees C)", "Temperature  Degrees C 3.5 (degrees C)",
    "TEMPERATURE (C)" }
local function calc_temperature_1(dv_, num) return num > 38.3 end
local function calc_temperature_2(dv_, num) return num < 36.0 end

local function calc_any_1(dv_, num) return num > 0 end



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = Result.script_name }
local subtitle = existing_alert and existing_alert.subtitle or nil



--------------------------------------------------------------------------------
--- Header Variables and Helper Functions
--------------------------------------------------------------------------------
local result_links = {}
local documented_dx_header = headers.make_header_builder("Documented Dx", 1)
local vital_signs_intake_header = headers.make_header_builder("Vital Signs/Intake and Output Data", 2)
local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 3)
local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 4)
local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 5)
local oxygenation_ventilation_header = headers.make_header_builder("Oxygenation/Ventilation", 6)

local function compile_links()
    table.insert(result_links, documented_dx_header:build(true))
    table.insert(result_links, clinical_evidence_header:build(true))
    table.insert(result_links, laboratory_studies_header:build(true))
    table.insert(result_links, vital_signs_intake_header:build(true))
    table.insert(result_links, treatment_and_monitoring_header:build(true))
    table.insert(result_links, oxygenation_ventilation_header:build(true))

    if existing_alert then
        result_links = links.merge_links(existing_alert.links, result_links)
    end
    Result.links = result_links
end



--------------------------------------------------------------------------------
--- Script Specific Functions
--------------------------------------------------------------------------------
--- @return table
local function blood_pressure_lookup()
    local med_search_list = { "Dobutamine", "Dopamine", "Epinephrine", "Levophed", "Milrinone", "Neosynephrine" }
    local discrete_dic1 = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_dbp,
        predicate = function(dv_, num) return num ~= nil end,
    }
    local discrete_dic2 = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_heart_rate,
        predicate = function(dv_, num) return num ~= nil end,
    }
    local dv_sbp_and_map = {}
    for _, dv_sbp in discrete_dic1 do table.insert(dv_sbp_and_map, dv_sbp) end
    for _, dv_map in discrete_dic2 do table.insert(dv_sbp_and_map, dv_map) end
    local discrete_dic3 = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_sbp_and_map,
        predicate = function(dv_, num) return num ~= nil end,
    }
    local a = 0
    local w = #discrete_dic1
    local x = #discrete_dic2
    local sm = #discrete_dic3
    local sbp_list = {}
    local map_list = {}
    local med_dic = {}

    for _, med in ipairs(Account.medications) do
        table.insert(med_dic, med)
    end

    for _, mv in ipairs(med_dic) do
        if
            mv.route and mv.dosage and
            lists.includes(med_search_list, mv.cdi_alert_category) and
            (string.find(mv.route, "Intravenous") or string.find(mv.route, "IV Push"))
        then
            a = a + 1
            med_dic[a] = mv
        end
    end
    if sm > 0 then
        local abstracted_list = {}
        local med_list = {}

        for _, item in ipairs(discrete_dic3) do
            local dbp_dv = nil
            local sbp_dv = nil
            local hr_dv = nil
            local map_dv = nil
            local id = nil
            local first_med_name = nil
            local first_med_dosage = nil
            local matching_date = nil

            if
                lists.includes(dv_sbp, item.name) and
                discrete.get_dv_value(item) < calc_sbp_1 and
                not lists.includes(abstracted_list, item.unique_id)
            then
                table.insert(sbp_list, item.result)
                matching_date = dates.date_string_to_int(item.result_date)
                sbp_dv = item.result
                table.insert(abstracted_list, item.unique_id)
                id = item.unique_id

                for _, item1 in ipairs(discrete_dic3) do
                    if
                        dates.date_string_to_int(item1.result_date) == matching_date and
                        lists.includes(dv_map, item1.name)
                    then
                        if discrete.get_dv_value(item1) < calc_map_1 then
                            table.insert(map_list, item1.result)
                        end
                        map_dv = item1.result
                        table.insert(abstracted_list, item1.unique_id)
                        break
                    end
                end
            elseif
                lists.includes(dv_map, item.name) and
                discrete.get_dv_value(item) < calc_map_1 and
                not lists.includes(abstracted_list, item.unique_id)
            then
                table.insert(map_list, item.result)
                matching_date = dates.date_string_to_int(item.result_date)
                map_dv = item.result
                table.insert(abstracted_list, item.unique_id)
                id = item.unique_id

                for _, item1 in ipairs(discrete_dic3) do
                    if
                        dates.date_string_to_int(item1.result_date) == matching_date and
                        lists.includes(dv_sbp, item1.name)
                    then
                        if discrete.get_dv_value(item1) < calc_sbp_1 then
                            table.insert(sbp_list, item1.result)
                        end
                        sbp_dv = item1.result
                        table.insert(abstracted_list, item1.unique_id)
                        break
                    end
                end
            end


            if w > 0 then
                for _, item2 in ipairs(discrete_dic1) do
                    if dates.date_string_to_int(item2.result_date) == matching_date then
                        dbp_dv = item2.result
                        break
                    end
                end
            end
            if x > 0 then
                for _, item3 in ipairs(discrete_dic2) do
                    if dates.date_string_to_int(item3.result_date) == matching_date then
                        hr_dv = item3.result
                        break
                    end
                end
            end
            if a > 0 and matching_date then
                local date_limit = matching_date + (24 * 60 * 60)

                for _, med in pairs(med_dic) do
                    local med_start_date = dates.date_string_to_int(med.start_date)
                    if matching_date <= med_start_date and med_start_date <= date_limit then
                        if not lists.includes(med_list, med.external_id) then
                            table.insert(med_list, med.external_id)
                            first_med_name = med.medication
                            first_med_dosage = med.dosage
                            break
                        end
                    end
                    if matching_date <= med_start_date and med_start_date <= date_limit then
                        if not lists.includes(med_list, med.external_id) then
                            table.insert(med_list, med.external_id)
                            first_med_name = med.medication
                            first_med_dosage = med.dosage
                            break
                        end
                    end
                end
            end

            dbp_dv = dbp_dv or "XX"
            hr_dv = hr_dv or "XX"
            map_dv = map_dv or "XX"
            sbp_dv = sbp_dv or "XX"

            if first_med_name and matching_date then
                local link = cdi_alert_link()
                link.discrete_value_id = id
                link.link_text = links.replace_link_place_holders(
                    "[RESULTDATETIME] HR = " .. hr_dv .. ", BP = " .. sbp_dv .. "/" .. dbp_dv .. ", MAP = " ..
                    map_dv .. ", Vasopressor:  = " .. first_med_name .. " @ " .. first_med_dosage
                )
                vital_signs_intake_header:add_link(link)
            elseif matching_date then
                local link = cdi_alert_link()
                link.discrete_value_id = id
                link.link_text = links.replace_link_place_holders(
                    "[RESULTDATETIME] HR = " .. hr_dv .. ", BP = " .. sbp_dv .. "/" .. dbp_dv .. ", MAP = " .. map_dv
                )
                vital_signs_intake_header:add_link(link)
            end
        end
    end

    -- Return the 7 days of low for alert triggers or return false for nothing for trigger purposes
    if #sbp_list == 0 then sbp_list = { false } end
    if #map_list == 0 then map_list = { false } end
    return { sbp_list, map_list }
end






if not existing_alert or not existing_alert.validated then
    --------------------------------------------------------------------------------
    --- Alert Variables
    --------------------------------------------------------------------------------
    local alert_code_dictionary = {
        ["A48.3"] = "Toxic Shock Syndrome",
        ["R57.0"] = "Cardiogenic Shock",
        ["R57.1"] = "Hypovolemic Shock",
        ["R57.8"] = "Other Shock",
        ["R65.21"] = "Severe Sepsis with Septic Shock",
        ["T78.2XXA"] = "Anaphylactic Shock",
        ["T79.4XXA"] = "Traumatic Shock, Initial Encounter",
        ["T81.10XA"] = "Postprocedural Shock Unspecified, Initial Encounter",
        ["T81.11XA"] = "Postprocedural Cardiogenic Shock, Initial Encounter",
        ["T81.11XD"] = "Postprocedural Cardiogenic Shock, Subsequent Encounter",
        ["T75.01XA"] = "Shock Due to Being Struck by Lightning, Initial Encounter",
        ["T81.12XA"] = "Postprocedural Septic Shock, Initial Encounter",
        ["T81.12XD"] = "Postprocedural Septic Shock, Subsequent Encounter",
        ["T81.12XS"] = "Postprocedural Septic Shock, Sequela",
        ["T81.19XA"] = "Other Postprocedural Shock, Initial Encounter",
        ["T81.19XD"] = "Other Postprocedural Shock, Subsequent Encounter"
    }
    local alert_code_dictionary2 = {
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
        ["R57.0"] = "Cardiogenic shock",
        ["R57.1"] = "Hypovolemic shock",
        ["R57.8"] = "Other shock",
        ["R57.9"] = "Shock, unspecified",
        ["R65.21"] = "Severe sepsis with septic shock",
        ["A48.3"] = "Toxic shock syndrome",
        ["T75.01XA"] = "Shock due to being struck by lightning, initial encounter",
        ["T78.2XXA"] = "Anaphylactic shock, unspecified, initial encounter",
        ["T79.4XXA"] = "Traumatic shock, initial encounter",
        ["T81.10XA"] = "Postprocedural shock unspecified, initial encounter",
        ["T81.11XA"] = "Postprocedural cardiogenic shock, initial encounter",
        ["T81.11XD"] = "Postprocedural cardiogenic shock, subsequent encounter",
        ["T81.12XA"] = "Postprocedural septic shock, initial encounter",
        ["T81.12XD"] = "Postprocedural septic shock, subsequent encounter",
        ["T81.12XS"] = "Postprocedural septic shock, sequela",
        ["T81.19XA"] = "Other postprocedural shock, initial encounter",
        ["T81.19XD"] = "Other postprocedural shock, subsequent encounter"
    }
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)
    local account_alert_codes2 = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary2)



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Negations
    local allergy_code = links.get_code_link {
        codes = {
            "T78.00xA", "T78.01xA", "T78.02xA", "T78.03xA", "T78.04xA", "T78.05xA",
            "T78.06xA", "T78.07xA", "T78.08xA", "T78.09xA", "T88.6xxA"
        },
        text = "Allergic Reaction Code Present",
    }
    local sepsis_code = links.get_code_link {
        codes = {
            "A40.0", "A40.1", "A40.8", "A40.9", "A41", "A41.0", "A41.01", "A41.02 ", "A41.1", "A41.2 ", "A41.3",
            "A41.4", "A41.5", "A41.50", "A41.51", "A41.52", "A41.53", "A41.54", "A41.59", "A41.8", "A41.81", "A41.89",
            "A41.9", "A42.7", "A22.7", "B37.7", "A26.7", "A54.86", "B00.7", "A32.7", "A24.1", "A20.7", "R65.20 ",
            "R65.21 ", "T81.44"
        },
        text = "Sepsis Code Present",
    }
    local spinal_cord_injury_code = links.get_code_link {
        codes = {
            "S14.0", "S14.1", "S14.10", "S14.101", "S14.102", "S14.103", "S14.104", "S14.105", "S14.106", "S14.107",
            "S14.108", "S14.109", "S14.11", "S14.111", "S14.112", "S14.113", "S14.114", "S14.115", "S14.116",
            "S14.117", "S14.118", "S14.119", "S14.12", "S14.121", "S14.122", "S14.123", "S14.124", "S14.125",
            "S14.126", "S14.127", "S14.128", "S14.129", "S14.13", "S14.131", "S14.132", "S14.133", "S24.104",
            "S24.109", "S24.11", "S24.111", "S24.112", "S24.113", "S24.114", "S24.119", "S24.13", "S24.131",
            "S24.132", "S24.133", "S24.134", "S24.139", "S24.14", "S24.141", "S24.142", "S24.143", "S24.144",
            "S24.149", "S24.15", "S24.151", "S24.152", "S24.153", "S24.154", "S24.159", "S34.0", "S34.01", "S34.02",
            "S34.1", "S34.10", "S34.101", "S34.102", "S34.109", "S34.11", "S34.111", "S34.112", "S34.119", "S34.12",
            "S34.121", "S34.122"
        },
        text = "Spinal Cord Injury Code Present",
    }
    local burn_code = links.get_code_link {
        codes = {
            "T31.1", "T31.10", "T31.11", "T31.2", "T31.20", "T31.21", "T31.22", "T31.3", "T31.30", "T31.31",
            "T31.32", "T31.33", "T31.4", "T31.40", "T31.42", "T31.43", "T31.44", "T31.5", "T31.50", "T31.51",
            "T31.52", "T31.53", "T31.54", "T31.55", "T31.6", "T31.60", "T31.61", "T31.62", "T31.63", "T31.64",
            "T31.65", "T31.66", "T31.7", "T31.71", "T31.72", "T31.73", "T31.74", "T31.75", "T31.76", "T31.77",
            "T31.8", "T31.81", "T31.82", "T31.83", "T31.84", "T31.85", "T31.86", "T31.87", "T31.88", "T31.9",
            "T31.91", "T31.92", "T31.93", "T31.94", "T31.95", "T31.96", "T31.97", "T31.98", "T31.99", "T32.1",
            "T32.11", "T32.2", "T32.20", "T32.21", "T32.22", "T32.3", "T32.30", "T32.31", "T32.32", "T32.33",
            "T32.4", "T32.41", "T32.42", "T32.43", "T32.44", "T32.5", "T32.50", "T32.51", "T32.52", "T32.53",
            "T32.54", "T32.55", "T32.6", "T32.60", "T32.61", "T32.62", "T32.63", "T32.64", "T32.65", "T32.66",
            "T32.7", "T32.70", "T32.71", "T32.72", "T32.73", "T32.74", "T32.75", "T32.76", "T32.77", "T32.8",
            "T32.81", "T32.82", "T32.83", "T32.84", "T32.85", "T32.86", "T32.87", "T32.88", "T32.9", "T32.91",
            "T32.92", "T32.93", "T32.94", "T32.95", "T32.96", "T32.97", "T32.98", "T32.99"
        },
        text = "Burn Code Present",
    }
    local r578_code = links.get_code_link { code = "R57.8", text = "Other shock" }
    local r571_code = links.get_code_link { code = "R57.1", text = "Hypovolemic shock" }
    local r570_code = links.get_code_link { code = "R57.0", text = "Cardiogenic shock" }
    local t782_xxa_code = links.get_code_link {
        code = "T78.2XXA",
        text = "Anaphylactic Shock, Unspecified, Initial encounter"
    }
    -- Alert Trigger
    local r579_code = links.get_code_link { code = "R57.9", text = "Unspecified Shock Code Present" }
    local blood_loss_dv = links.get_discrete_value_link {
        discreteValueNames = dv_blood_loss,
        text = "Blood Loss",
        predicate = calc_blood_loss_1,
    }
    -- Clinical Evidence
    local i314_code = links.get_code_link { code = "I31.4", text = "Cardiac Tamponade" }
    local diarrhea_abs = links.get_abstraction_link { code = "DIARRHEA", text = "Diarrhea" }
    local endocarditis_code = links.get_multi_code_link {
        codes = { "I33.0", "I33.9", "I38", "I39" },
        text = "Endocarditis",
    }
    local r232_code = links.get_code_link { code = "R23.2", text = "Flushed Skin" }
    local hf_code = links.get_multi_code_link {
        codes = {
            "I50.1", "I50.2", "I50.20", "I50.21", "I50.22", "I50.23", "I50.3", "I50.30", "I50.31", "I50.32",
            "I50.33", "I50.4", "I50.40", "I50.41", "I50.42", "I50.43", "I50.8", "I50.81", "I50.810", "I50.811",
            "I50.812", "I50.813", "I50.814", "I50.82", "I50.83", "I50.84", "I50.89", "I50.9"
        },
        text = "Heart Failure",
    }
    local hemorrhage_abs = links.get_abstraction_link { code = "HEMORRHAGE", text = "Hemorrhage" }
    local mi_code = links.get_multi_code_link {
        codes = {
            "I21.0", "I21.01", "I21.02", "I21.09", "I21.1", "I21.11", "I21.19", "I21.2", "I21.2", "I21.21",
            "I21.29", "I21.3", "I21.4", "I21.A1", "I21.A9"
        },
        text = "Myocardial Infarction",
    }
    local myocarditis_code = links.get_multi_code_link {
        codes = { "I40.0", "I40.1", "I40.8", "I40.9", "I41", "I51.4" },
        text = "Myocarditis",
    }
    local e860_code = links.get_code_link { code = "E86.0", text = "Severe Dehydration" }
    local e869_code = links.get_code_link { code = "E86.9", text = "Volume Depletion" }
    local vomiting_abs = links.get_abstraction_link { code = "VOMITING", text = "Vomiting" }

    -- Laboratory Studies
    local serum_lactate_dv = links.get_dv_link {
        discreteValueNames = dv_serum_lactate,
        text = "Serum Lactate",
        predicate = calc_serum_lactate_1
    }

    -- Treatment and Monitoring
    local dobutamine_med = links.get_medication_link { cat = "Dobutamine", text = "Dobutamine Medication" }
    local dobutamine_abs = links.get_abstraction_link { code = "DOBUTAMINE", text = "Dobutamine" }
    local dopamine_med = links.get_medication_link { cat = "Dopamine", text = "Dopamine Medication" }
    local dopamine_abs = links.get_abstraction_link { code = "DOPAMINE", text = "Dopamine" }
    local epinephrine_med = links.get_medication_link { cat = "Epinephrine", text = "Epinephrine Medication" }
    local epinephrine_abs = links.get_abstraction_link { code = "EPINEPHRINE", text = "Epinephrine" }
    local fluid_bolus_med = links.get_medication_link { cat = "Fluid Bolus", text = "Fluid Bolus Medication" }
    local fluid_bolus_abs = links.get_abstraction_link { code = "FLUID_BOLUS", text = "Fluid Bolus" }
    local levophed_med = links.get_medication_link { cat = "Levophed", text = "Levophed Medication" }
    local levophed_abs = links.get_abstraction_link { code = "LEVOPHED", text = "Levophed" }
    local milrinone_med = links.get_medication_link { cat = "Milrinone", text = "Milrinone Medication" }
    local milrinone_abs = links.get_abstraction_link { code = "MILRINONE", text = "Milrinone" }
    local neosynephrine_med = links.get_medication_link { cat = "Neosynephrine", text = "Neosynephrine Medication" }
    local neosynephrine_abs = links.get_abtraction_link { code = "NEOSYNEPHRINE", text = "Neosynephrine" }
    local vasoactive_medication_abs = links.get_abstraction_link {
        code = "VASOACTIVE_MEDICATION",
        text = "Vasoactive Medication"
    }

    -- Vitals
    local low_cardiac_index_dv = links.get_discrete_value_link {
        discreteValueNames = dv_cardiac_index,
        text = "Cardiac Index",
        predicate = calc_cardiac_index_1,
    }
    local low_cardiac_index_abs = links.get_abstraction_link {
        code = "LOW_CARDIAC_INDEX",
        text = "Cardiac Index",
    }
    local low_cardiac_output_dv = links.get_discrete_value_link {
        discreteValueNames = dv_cardiac_output,
        text = "Cardiac Output",
        predicate = calc_cardiac_output_1,
    }
    local low_cardiac_output_abs = links.get_abstraction_link {
        code = "LOW_CARDIAC_OUTPUT",
        text = "Cardiac Output",
    }
    local low_heart_rate_dv = links.get_discrete_value_link {
        discreteValueNames = dv_heart_rate,
        text = "Heart Rate",
        predicate = calc_heart_rate_2,
    }
    local el_pulmonary_art_occulsive_pres_dv = links.get_discrete_value_link {
        discreteValueNames = dv_paop,
        text = "Pulmonary Artery Occulsive Pressure",
        predicate = calc_paop_1,
    }
    local el_pulmonary_art_occulsive_pres_abs = links.get_abstraction_link {
        code = "ELEVATED_PULMONARY_ARTERY_OCCULSIVE_PRESSURE",
        text = "Pulmonary Artery Occulsive Pressure",
    }
    local low_systemic_vascular_res_dv = links.get_discrete_value_link {
        discreteValueNames = dv_systemic_vascular_resistance,
        text = "Systemic Vascular Resistance",
        predicate = calc_systemic_vascular_resistance_1,
    }
    local low_systemic_vascular_res_abs = links.get_abstraction_link {
        code = "LOW_SYSTEMIC_VASCULAR_RESISTANCE",
        text = "Systemic Vascular Resistance",
    }
    local low_temp_dv = links.get_discrete_value_link {
        discreteValueNames = dv_temperature,
        text = "Temperature",
        predicate = calc_temperature_2,
    }
    local high_temp_dv = links.get_discrete_value_link {
        discreteValueNames = dv_temperature,
        text = "Temperature",
        predicate = calc_temperature_1,
    }
    -- Blood Pressure
    local bp_values_dv = blood_pressure_lookup()

    -- Calculating all Clinical Indicator Counts
    local sci =
        ((bp_values_dv[1][1] and #bp_values_dv[1] > 2) or (bp_values_dv[2][1] and #bp_values_dv[2] > 2)) or
        ((bp_values_dv[1][1] and #bp_values_dv[1] > 1) or (bp_values_dv[2][1] and #bp_values_dv[2] > 1)) and
        (
            serum_lactate_dv or
            vasoactive_medication_abs or
            dobutamine_med or
            dobutamine_abs or
            dopamine_med or
            dopamine_abs or
            epinephrine_med or
            epinephrine_abs or
            fluid_bolus_med or
            fluid_bolus_abs or
            levophed_med or
            levophed_abs or
            milrinone_med or
            milrinone_abs or
            neosynephrine_med or
            neosynephrine_abs
        ) and 1 or 0

    local nci =
        low_heart_rate_dv and 1 or 0 +
        high_temp_dv and 1 or 0 +
        low_temp_dv and 1 or 0 +
        r232_code and 1 or 0 +
        low_systemic_vascular_res_dv and low_systemic_vascular_res_abs and 1 or 0

    local ccc =
        endocarditis_code and 1 or 0 +
        myocarditis_code and 1 or 0 +
        i314_code and 1 or 0 +
        hf_code and 1 or 0 +
        mi_code and 1 or 0

    local cci =
        low_cardiac_output_dv and low_cardiac_output_abs and 1 or 0 +
        low_cardiac_index_dv and low_cardiac_index_abs and 1 or 0 +
        el_pulmonary_art_occulsive_pres_dv and el_pulmonary_art_occulsive_pres_abs and 1 or 0

    local hci =
        vomiting_abs and 1 or 0 +
        diarrhea_abs and 1 or 0 +
        e860_code and 1 or 0 +
        e869_code and 1 or 0

    -- Determining Negation Checks
    local allergy = allergy_code and true or false
    local sepsis = sepsis_code and true or false
    local spinal = spinal_cord_injury_code and true or false
    local burns = burn_code and true or false



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    local hemorrhagic = false
    local hypovolemic = false
    local cardiogenic = false
    local neurogenic = false

    if #account_alert_codes == 1 then
        if existing_alert then
            for _, code in ipairs(account_alert_codes) do
                local desc = alert_code_dictionary[code]
                local temp_code = links.get_code_link {
                    code = code,
                    text = "Autoresolved Specified Code - " .. desc
                }
                if temp_code then
                    documented_dx_header:add_link(temp_code)
                    break
                end
            end
            Result.outcome = "AUTORESOLVED"
            Result.reason = "Autoresolved due to one Specified Code on the Account"
            Result.validated = true
            Result.passed = true
        end
    elseif #account_alert_codes >= 2 then
        for _, code in ipairs(account_alert_codes) do
            local desc = alert_code_dictionary[code]
            local temp_code = links.get_code_link {
                code = code,
                text = "Autoresolved Specified Code - " .. desc
            }
            if temp_code then
                documented_dx_header:add_link(temp_code)
            end
        end
        Result.subtitle = "Possible Conflicting Shock Dx"
        if existing_alert and existing_alert.validated then
            Result.validated = false
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
        end
        Result.passed = true
    elseif subtitle == "Possible Hemorrhagic Shock" and r571_code then
        -- 1.1/2.1
        if r571_code then
            r571_code.link_text = "Autoresolved Specified Code - " .. r571_code.link_text
            documented_dx_header:add_link(r571_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true
    elseif r579_code and (blood_loss_dv or hemorrhage_abs) and not r571_code then
        -- 1.0
        documented_dx_header:add_link(hemorrhage_abs)
        documented_dx_header:add_link(blood_loss_dv)
        Result.subtitle = "Possible Hemorrhagic Shock"
        Result.passed = true
        hemorrhagic = true
    elseif not r579_code and sci >= 1 and (blood_loss_dv or hemorrhage_abs) and not r578_code then
        -- 2.0
        documented_dx_header:add_link(hemorrhage_abs)
        documented_dx_header:add_link(blood_loss_dv)
        Result.subtitle = "Possible Hemorrhagic Shock"
        Result.passed = true
        hemorrhagic = true
    elseif subtitle == "Possible Hypovolemic Shock" and r571_code then
        -- 3.1/4.1
        if r571_code then
            r571_code.link_text = "Autoresolved Specified Code - " .. r571_code.link_text
            documented_dx_header:add_link(r571_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true
    elseif
        not hemorrhage_abs and
        not sepsis and
        not spinal and
        ccc == 0 and
        (burns or hci >= 1) and
        r579_code and
        not r571_code
    then
        -- 3.0
        if burns then documented_dx_header:add_link(burn_code) end
        documented_dx_header:add_link(r579_code)
        Result.subtitle = "Possible Hypovolemic Shock"
        Result.passed = true
        hypovolemic = true
    elseif
        #account_alert_codes == 0 and
        not r579_code and
        not hemorrhage_abs and
        not sepsis and
        not spinal and
        ccc == 0 and
        sci >= 1 and
        (burns or hci >= 1) and
        not r571_code
    then
        -- 4.0
        if burns then documented_dx_header:add_link(burn_code) end
        Result.subtitle = "Possible Hypovolemic Shock"
        Result.passed = true
        hypovolemic = true
    elseif subtitle == "Possible Cardiogenic Shock" and r570_code then
        -- 5.1/6.1
        if r570_code then
            r570_code.link_text = "Autoresolved Specified Code - " .. r570_code.link_text
            documented_dx_header:add_link(r570_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true
    elseif not hemorrhage_abs and not sepsis and ccc > 1 and cci >= 2 and r579_code and not r570_code then
        -- 5.0
        documented_dx_header:add_link(r579_code)
        Result.subtitle = "Possible Cardiogenic Shock"
        Result.passed = true
        cardiogenic = true
    elseif
        #account_alert_codes == 0 and
        not r579_code and
        not hemorrhage_abs and
        not sepsis and
        not burns and
        not spinal and
        hci == 0 and
        sci >= 1 and
        ccc > 1 and
        cci >= 2 and
        not r570_code
    then
        -- 6.0
        Result.subtitle = "Possible Cardiogenic Shock"
        Result.passed = true
        cardiogenic = true
    elseif subtitle == "Possible Neurogenic Shock" and r578_code then
        -- 7.1/8.1
        if r578_code then
            r578_code.link_text = "Autoresolved Specified Code - " .. r578_code.link_text
            documented_dx_header:add_link(r578_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true
    elseif
        r579_code and
        not hemorrhage_abs and
        not sepsis and
        not burns and
        spinal and
        not r578_code and
        ccc == 0 and
        hci == 0
    then
        -- 7.0
        Result.subtitle = "Possible Neurogenic Shock"
        Result.passed = true
        neurogenic = true
    elseif
        #account_alert_codes == 0 and
        r579_code and
        not hemorrhage_abs and
        not sepsis and
        not burns and
        spinal and
        ccc == 0 and
        hci == 0 and
        nci >= 2 and
        not r578_code
    then
        -- 8.0
        Result.subtitle = "Possible Neurogenic Shock"
        Result.passed = true
        neurogenic = true
    elseif subtitle == "Possible Anaphylactic Shock" and t782_xxa_code then
        -- 9.1/10.1
        if t782_xxa_code then
            t782_xxa_code.link_text = "Autoresolved Specified Code - " .. t782_xxa_code.link_text
            documented_dx_header:add_link(t782_xxa_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true
    elseif
        not spinal and
        not burns and
        not sepsis and
        ccc == 0 and
        hci == 0 and
        allergy and
        not hemorrhage_abs and
        r579_code and
        not t782_xxa_code
    then
        -- 9.0
        documented_dx_header:add_link(r579_code)
        Result.subtitle = "Possible Anaphylactic Shock"
        Result.passed = true
    elseif
        #account_alert_codes == 0 and
        not r579_code and
        not hemorrhage_abs and
        not sepsis and
        not burns and
        not spinal and
        allergy and
        ccc == 0 and
        hci == 0 and
        sci >= 2 and
        not t782_xxa_code
    then
        -- 10.0
        Result.subtitle = "Possible Anaphylactic Shock"
        Result.passed = true
    elseif subtitle == "Possible Shock" and #account_alert_codes2 > 0 then
        -- 11.1
        for code2 in account_alert_codes2 do
            local desc2 = alert_code_dictionary2[code2]
            local temp_code = links.get_code_link {
                code = code2,
                text = "Autoresolved Specified Code - " .. desc2
            }
            if temp_code then
                documented_dx_header:add_link(temp_code)
                break
            end
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code(s) on the Account"
        Result.validated = true
        Result.passed = true
    elseif sci >= 2 and #account_alert_codes2 == 0 and not sepsis_code then
        -- 11.0
        Result.subtitle = "Possible Shock"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Clinical Evidence
            clinical_evidence_header:add_code_link("J81.0", "Acute Pulmonary Edema")
            clinical_evidence_header:add_code_link("E27.40", "Adrenal Insufficiency")
            clinical_evidence_header:add_code_link("N17.9", "AKI")
            local r4182_code = links.get_code_link { code = "R41.82", text = "Altered Level Of Consciousness" }
            local altered_abs = links.get_abstraction_link {
                code = "ALTERED_LEVEL_OF_CONSCIOUSNESS",
                text = "Altered Level Of Consciousness",
            }
            if r4182_code then
                vital_signs_intake_header:add_link(r4182_code)
                if altered_abs then
                    altered_abs.hidden = true
                    vital_signs_intake_header:add_link(altered_abs)
                end
            end
            vital_signs_intake_header:add_link(altered_abs)
            clinical_evidence_header:add_code_one_of_link(
                { "T31.10", "T31.11" },
                "Burns Involving 10-19 Percent of Body Surface Area"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "T31.20", "T31.21", "T31.22" },
                "Burns Involving 20-29 Percent of Body Surface Area"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "T31.30", "T31.31", "T31.32", "T31.33" },
                "Burns Involving 30-39 Percent of Body Surface Area"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "T31.40", "T31.41", "T31.42", "T31.43", "T31.44" },
                "Burns Involving 40-49 Percent of Body Surface Area"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "T31.50", "T31.51", "T31.52", "T31.53", "T31.54", "T31.55" },
                "Burns Involving 50-59 Percent of Body Surface Area"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "T31.60", "T31.61", "T31.62", "T31.63", "T31.64", "T31.65", "T31.66" },
                "Burns Involving 60-69 Percent of Body Surface Area"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "T31.70", "T31.71", "T31.72", "T31.73", "T31.74", "T31.75", "T31.76", "T31.77" },
                "Burns Involving 70-79 Percent of Body Surface Area"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "T31.80", "T31.81", "T31.82", "T31.83", "T31.84", "T31.85", "T31.86", "T31.87", "T31.88" },
                "Burns Involving 80-89 Percent of Body Surface Area"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "T31.90", "T31.91", "T31.92", "T31.93", "T31.94", "T31.95", "T31.96", "T31.97", "T31.98", "T31.99" },
                "Burns Involving 90 Percent or More of Body Surface Area"
            )
            if cardiogenic and i314_code then
                clinical_evidence_header:add_link(i314_code)
            end
            clinical_evidence_header:add_code_one_of_link(
                { "T32.10", "T32.11" },
                "Corrosions Involving 10-19 Percent of Body Surface Area"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "T32.20", "T32.21", "T32.22" },
                "Corrosions Involving 20-29 Percent of Body Surface Area"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "T32.30", "T32.31", "T32.32", "T32.33" },
                "Corrosions Involving 30-39 Percent of Body Surface Area"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "T32.40", "T32.41", "T32.42", "T32.43", "T32.44" },
                "Corrosions Involving 40-49 Percent of Body Surface Area"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "T32.50", "T32.51", "T32.52", "T32.53", "T32.54", "T32.55" },
                "Corrosions Involving 50-59 Percent of Body Surface Area"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "T32.60", "T32.61", "T32.62", "T32.63", "T32.64", "T32.65", "T32.66" },
                "Corrosions Involving 60-69 Percent of Body Surface Area"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "T32.70", "T32.71", "T32.72", "T32.73", "T32.74", "T32.75", "T32.76", "T32.77" },
                "Corrosions Involving 70-79 Percent of Body Surface Area")
            clinical_evidence_header:add_code_one_of_link(
                { "T32.80", "T32.81", "T32.82", "T32.83", "T32.84", "T32.85", "T32.86", "T32.87", "T32.88" },
                "Corrosions Involving 80-89 Percent of Body Surface Area"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "T32.90", "T32.91", "T32.92", "T32.93", "T32.94", "T32.95", "T32.96", "T32.97", "T32.98", "T32.99" },
                "Corrosions Involving 90 Percent or More of Body Surface Area"
            )
            clinical_evidence_header:add_abstraction_link("DECREASED_EXTREMITY_PERFUSION",
                "Decreased Extremity Perfusion")
            clinical_evidence_header:add_abstraction_link("DELAYED_CAPILLARY_REFILL", "Delayed Capillary Refill")
            if hypovolemic and diarrhea_abs then clinical_evidence_header:add_link(diarrhea_abs) end
            if endocarditis_code then clinical_evidence_header:add_link(endocarditis_code) end
            clinical_evidence_header:add_code_one_of_link(
                { "5A15223", "FA1522F", "5A1522G", "FA1522H", "5A15A2F", "5A15A2G", "5A15A2H" },
                "Extracorporeal Membrane Oxygenation (ECMO)"
            )
            if neurogenic and r232_code then clinical_evidence_header:add_link(r232_code) end
            if cardiogenic and hf_code then clinical_evidence_header:add_link(hf_code) end
            if hemorrhagic and hemorrhage_abs then clinical_evidence_header:add_link(hemorrhage_abs) end
            if hypovolemic then clinical_evidence_header:add_code_link("E86.1", "Hypovolemia") end
            clinical_evidence_header:add_code_one_of_link({ "5A0211D", "5A0221D" }, "Impella Device")
            clinical_evidence_header:add_code_one_of_link({ "02HA3QZ", "02HA0QZ" }, "Implantable Heart Assist Device")
            clinical_evidence_header:add_code_one_of_link({ "5A02110", "5A02210" }, "Intra-Aortic Balloon Pump")
            if cardiogenic then
                clinical_evidence_header:add_link(mi_code)
                clinical_evidence_header:add_link(myocarditis_code)
            end
            clinical_evidence_header:add_code_link("I51.2", "Papillary Muscle Rupture")
            clinical_evidence_header:add_abstraction_link("PULMONARY_ARTERY_SATURATION", "Pulmonary Artery Saturation")
            clinical_evidence_header:add_code_one_of_link(
                { "I26.01", "I26.02", "I26.09", "I26.90", "I26.92", "I26.93", "I26.94", "I26.99" },
                "Pulmonary Embolism Code Present"

            )
            clinical_evidence_header:add_code_prefix_link("I71.3", "Ruptured Aortic Aneurysm")
            clinical_evidence_header:add_code_prefix_link("I71.1", "Ruptured Thoracic Aortic Aneurysm")
            clinical_evidence_header:add_code_prefix_link("I71.5", "Ruptured Thoracoabdominal Aortic Aneurysm")
            if hypovolemic and e860_code then clinical_evidence_header:add_link(e860_code) end
            clinical_evidence_header:add_code_one_of_link(
                { "02HA0RJ", "02HA0RS", "02HA0RZ", "02HA3RJ", "02HA3RS", "02HA3RZ", "02HA4QZ", "02HA4RJ", "02HA4RS",
                    "02HA4RZ" },
                "Short-Term Heart Assist Device"
            )
            if hypovolemic and e869_code then clinical_evidence_header:add_link(e869_code) end
            if hypovolemic and vomiting_abs then clinical_evidence_header:add_link(vomiting_abs) end

            -- Laboratories
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_alanine_aminotransferase,
                "Alanine Aminotransferase (ALT)",
                calc_alanine_aminotransferase_1
            )
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_aspartate_aminotransferase,
                "Aspartate Aminotransferase (AST)",
                calc_aspartate_aminotransferase_1
            )
            if Account.patient and Account.patient.gender == "F" then
                laboratory_studies_header:add_discrete_value_one_of_link(
                    dv_hematocrit,
                    "Hematocrit",
                    calc_hematocrit_1
                )
                laboratory_studies_header:add_discrete_value_one_of_link(
                    dv_hemoglobin,
                    "Hemoglobin",
                    calc_hemoglobin_2
                )
            else
                laboratory_studies_header:add_discrete_value_one_of_link(
                    dv_hematocrit,
                    "Hematocrit",
                    calc_hematocrit_2
                )
                laboratory_studies_header:add_discrete_value_one_of_link(
                    dv_hemoglobin,
                    "Hemoglobin",
                    calc_hemoglobin_1
                )
            end
            laboratory_studies_header:add_discrete_value_one_of_link(dv_pao2, "pa02", calc_pao2_1)
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_serum_blood_urea_nitrogen,
                "Serum Blood Urea Nitrogen",
                calc_serum_blood_urea_nitrogen_1
            )
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_serum_creatinine,
                "Serum Creatinine",
                calc_serum_creatinine_1
            )
            if serum_lactate_dv then laboratory_studies_header:add_link(serum_lactate_dv) end

            -- Medications
            treatment_and_monitoring_header:add_medication_link("Albumin", "Albumin")
            treatment_and_monitoring_header:add_code_one_of_link({ "30233N1", "30243N1" }, "Blood Transfusion")
            treatment_and_monitoring_header:add_link(dobutamine_med)
            treatment_and_monitoring_header:add_link(dobutamine_abs)
            treatment_and_monitoring_header:add_link(dopamine_med)
            treatment_and_monitoring_header:add_link(dopamine_abs)
            treatment_and_monitoring_header:add_link(epinephrine_med)
            treatment_and_monitoring_header:add_link(epinephrine_abs)
            treatment_and_monitoring_header:add_link(fluid_bolus_med)
            treatment_and_monitoring_header:add_link(fluid_bolus_abs)
            treatment_and_monitoring_header:add_link(levophed_med)
            treatment_and_monitoring_header:add_link(levophed_abs)
            treatment_and_monitoring_header:add_link(milrinone_med)
            treatment_and_monitoring_header:add_link(milrinone_abs)
            treatment_and_monitoring_header:add_link(neosynephrine_med)
            treatment_and_monitoring_header:add_link(neosynephrine_abs)
            treatment_and_monitoring_header:add_code_one_of_link({ "30233R1", "30243R1" }, "Platelet Transfusion")
            treatment_and_monitoring_header:add_code_one_of_link({ "30233L1", "30243L1" }, "Plasma Transfusion")
            treatment_and_monitoring_header:add_discrete_value_one_of_link(dv_plasma_transfusion, "Plasma Transfusion",
                calc_any_1)
            treatment_and_monitoring_header:add_discrete_value_one_of_link(dv_red_blood_cell_transfusion,
                "Plasma Transfusion", calc_any_1)
            if vasoactive_medication_abs then treatment_and_monitoring_header:add_link(vasoactive_medication_abs) end
            treatment_and_monitoring_header:add_medication_link("Vasopressin", "Vasopressin")
            treatment_and_monitoring_header:add_abstraction_link("VASOPRESSIN", "Vasopressin")

            -- Oxygen
            oxygenation_ventilation_header:add_code_one_of_link(
                { "5A0935A", "5A0945A", "5A0955A" },
                "High Flow Nasal Oxygen"
            )
            oxygenation_ventilation_header:add_code_link("5A1945Z", "Mechanical Ventilation 24 to 96 hours")
            oxygenation_ventilation_header:add_code_link("5A1955Z", "Mechanical Ventilation Greater than 96 hours")
            oxygenation_ventilation_header:add_code_link("5A1935Z", "Mechanical Ventilation Less than 24 hours")
            oxygenation_ventilation_header:add_abstraction_link("NON_INVASIVE_VENTILATION", "Non-Invasive Ventilation")
            oxygenation_ventilation_header:add_discrete_value_one_of_link(
                dv_oxygen_therapy,
                "Oxygen Therapy",
                function(dv, num_)
                    return dv.result:lower():find("ra") ~= nil or dv.result:lower():find("room air") ~= nil
                end
            )
            oxygenation_ventilation_header:add_abstraction_link("OXYGEN_THERAPY", "Oxygen Therapy")

            -- Vitals
            if cardiogenic then
                vital_signs_intake_header:add_link(low_cardiac_index_dv)
                vital_signs_intake_header:add_link(low_cardiac_index_abs)
                vital_signs_intake_header:add_link(low_cardiac_output_dv)
                vital_signs_intake_header:add_link(low_cardiac_output_abs)
            end
            vital_signs_intake_header:add_discrete_value_one_of_link(
                dv_central_venous_pressure,
                "Central Venous Pressure",
                calc_central_venous_pressure_1
            )
            vital_signs_intake_header:add_abstraction_link("LOW_CENTRAL_VENOUS_PRESSURE", "Central Venous Pressure")
            clinical_evidence_header:add_code_link("R41.0", "Disorientation")
            vital_signs_intake_header:add_discrete_value_one_of_link(
                dv_glasgow_coma_scale,
                "Glasgow Coma Score",
                calc_glasgow_coma_scale_1
            )
            if neurogenic then vital_signs_intake_header:add_link(low_heart_rate_dv) end
            vital_signs_intake_header:add_discrete_value_one_of_link(
                dv_heart_rate,
                "Heart Rate",
                calc_heart_rate_1
            )
            clinical_evidence_header:add_code_link("R09.02", "Hypoxemia")
            if cardiogenic then
                vital_signs_intake_header:add_link(el_pulmonary_art_occulsive_pres_dv)
                vital_signs_intake_header:add_link(el_pulmonary_art_occulsive_pres_abs)
            end
            vital_signs_intake_header:add_discrete_value_one_of_link(
                dv_pvr,
                "Pulmonary Vascular Resistance",
                calc_pvr_1
            )
            vital_signs_intake_header:add_abstraction_link("ELEVATED_PULMONARY_VASCULAR_RESISTANCE",
                "Pulmonary Vascular Resistance")
            vital_signs_intake_header:add_discrete_value_one_of_link(
                dv_respiratory_rate,
                "Respiratory Rate",
                calc_respiratory_rate_1
            )
            vital_signs_intake_header:add_discrete_value_one_of_link(
                dv_pvr,
                "Right Ventricle Systolic Pressure",
                calc_pvr_1
            )
            vital_signs_intake_header:add_abstraction_link("ELEVATED_RIGHT_VENTRICLE_SYSTOLIC_PRESSURE",
                "Right Ventricle Systolic Pressure")
            if neurogenic then
                vital_signs_intake_header:add_link(low_systemic_vascular_res_dv)
                vital_signs_intake_header:add_link(low_systemic_vascular_res_abs)
                vital_signs_intake_header:add_link(low_temp_dv)
                vital_signs_intake_header:add_link(high_temp_dv)
            end
        end



        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        compile_links()
    end
end
