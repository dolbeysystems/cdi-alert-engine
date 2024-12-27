---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Respiratory Failure
---
--- This script checks an account to see if it matches the criteria for a respiratory failure alert.
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
local cdi_alert_link = require "cdi.link"



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local dv_arterial_blood_c02 = { "PaCO2 (mmHg)", "BLD GAS CO2 (mmHg)" }
local calc_arterial_blood_c021 = 45
local dv_arterial_blood_ph = { "pH" }
local calc_arterial_blood_ph1 = function(dv_, num) return num < 7.30 end
local calc_arterial_blood_ph2 = function(dv_, num) return num >= 7.35 end
local dv_blood_co2 = { "CO2 (mmol/L)" }
local calc_blood_co2 = function(dv_, num) return num > 32 end
local dv_fi_o2 = { "FiO2" }
local calc_fi_o21 = function(dv_, num) return num <= 100 end
local dv_glasgow_coma_scale = { "3.5 Neuro Glasgow Score" }
local calc_glasgow_coma_scale1 = function(dv_, num) return num < 15 end
local dv_heart_rate = {
    "Heart Rate cc (bpm)",
    "3.5 Heart Rate (Apical) (bpm)",
    "3.5 Heart Rate (Other) (bpm)",
    "3.5 Heart Rate (Radial) (bpm)",
    "SCC Monitor Pulse (bpm)"
}
local calc_heart_rate1 = function(dv_, num) return num > 90 end
local dv_oxygen_flow_rate = { "Resp O2 Delivery Flow Num" }
local calc_oxygen_flow_rate1 = function(dv_, num) return num >= 2 end
local dv_oxygen_therapy = { "DELIVERY" }
local dv_pa_o2 = { "BLD GAS O2 (mmHg)", "PO2 (mmHg)" }
local calc_pa_o21 = 80
local calc_pa_o22 = function(dv_, num) return num < 80 end
local dv_pa_o2_fi_o2 = { "PO2/FiO2 (mmHg)" }
local calc_pa_o2_fi_o2_1 = 300
local calc_pa_o2_fi_o2_2 = function(dv_, num) return num < 300 end
local dv_respiratory_rate = { "3.5 Respiratory Rate (#VS I&O) (per Minute)" }
local calc_respiratory_rate1 = function(dv_, num) return num > 20 end
local calc_respiratory_rate2 = function(dv_, num) return num < 12 end
local dv_serum_bicarbonate = { "HCO3 (meq/L)", "HCO3 (mmol/L)", "HCO3 VENOUS (meq/L)" }
local calc_serum_bicarbonate1 = function(dv_, num) return num < 22 end
local calc_serum_bicarbonate2 = function(dv_, num) return num > 30 end
local dv_sp_o2 = { "Pulse Oximetry(Num) (%)" }
local calc_sp_o21 = 91
local calc_sp_o22 = function(dv_, num) return num < 90 end
local dv_venous_blood_co2 = { "BLD GAS CO2 VEN (mmHg" }
local calc_venous_blood_co2 = function(dv_, num) return num > 55 end



--------------------------------------------------------------------------------
--- Script Functions
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--- Get the links for PaO2/FiO2, through various attempts
---
--- Links returned use the seq field to communicate other meaning:
--- 2 - Ratio was calcluated by site
--- 8 - Ratio was calculated by us and needs a warning added before it
--- 
--- @return CdiAlertLink[]
--------------------------------------------------------------------------------
local function get_pa_o2_fi_o2_links()
    --- Final links
    --- @type CdiAlertLink[]
    local pa_o2_fi_o2_ratio_links = {}

    --- Lookup table for converting spO2 to paO2
    local sp_o2_to_pa_o2_lookup = {
        [80] = 44, [81] = 45, [82] = 46, [83] = 47, [84] = 49,
        [85] = 50, [86] = 51, [87] = 52, [88] = 54, [89] = 56,
        [90] = 58, [91] = 60, [92] = 64, [93] = 68, [94] = 73,
        [95] = 80, [96] = 90
    }
    --- Lookup table for converting oxygen flow rate to FiO2
    local flow_rate_to_fi_o2_lookup = {
        [1] = 0.24, [2] = 0.28, [3] = 0.32, [4] = 0.36, [5] = 0.40, [6] = 0.44
    }
    --- All fi_o2 dvs from the last day
    local fi_o2_dvs = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_fi_o2,
        predicate = function(dv)
            return
                dates.date_is_less_than_x_days_ago(dv.result_date, 1) and
                tonumber(dv.result) ~= nil
        end
    }
    --- All oxygen dv pairs from the last day
    local oxygen_pairs = discrete.get_discrete_value_pairs {
        discreteValueNames1 = dv_oxygen_flow_rate,
        discreteValueNames2 = dv_oxygen_therapy,
        predicate1 = function(dv)
            return
                dates.date_is_less_than_x_days_ago(dv.result_date, 1) and
                tonumber(dv.result) ~= nil
        end,
        predicate2 = function(dv)
            return
                dates.date_is_less_than_x_days_ago(dv.result_date, 1) and
                tonumber(dv.result) ~= nil
        end
    }

    if #pa_o2_fi_o2_ratio_links == 0 then
        -- Method #1 - Look for site calculated discrete values
        pa_o2_fi_o2_ratio_links = links.get_discrete_value_links {
            discreteValueNames = dv_pa_o2_fi_o2,
            text = "PaO2/FiO2",
            predicate = function(dv, num)
                return dates.date_is_less_than_x_days_ago(dv.result_date, 1) and num < calc_pa_o2_fi_o2_1
            end,
            seq = 2
        }
    end
    if #pa_o2_fi_o2_ratio_links == 0 then
        -- Method #2 - Look through FiO2 values for matching PaO2 values
        for _, fi_o2_dv in ipairs(fi_o2_dvs) do
            local pa_o2_dv = discrete.get_discrete_value_nearest_to_date {
                discreteValueNames = dv_pa_o2,
                date = fi_o2_dv.result_date,
                predicate = function(dv)
                    return
                        dates.dates_are_less_than_x_minutes_apart(fi_o2_dv.result_date, dv.result_date, 5) and
                        tonumber(dv.result) ~= nil
                end
            }
            if pa_o2_dv then
                local fi_o2 = discrete.get_dv_value_number(fi_o2_dv)
                local pa_o2 = discrete.get_dv_value_number(pa_o2_dv)
                local ratio = pa_o2 / fi_o2
                if ratio <= 300 then
                    local resp_rate_dv = discrete.get_discrete_value_nearest_to_date {
                        discreteValueNames = dv_respiratory_rate,
                        date = fi_o2_dv.result_date,
                    }
                    -- Build links
                    local link = cdi_alert_link()
                    link.discrete_value_id = fi_o2_dv.unique_id
                    link.link_text =
                        os.date(fi_o2_dv.result_date) ..
                        " - Calculated PaO2/FiO2 from FiO2 (" .. fi_o2 ..
                        ") and PaO2 (" .. pa_o2 ..
                        ") yielding a ratio of (" .. ratio .. ")"
                    link.sequence = 8
                    if resp_rate_dv then
                        link.link_text = link.link_text .. " - Respiratory Rate: " .. discrete.get_dv_value_number(resp_rate_dv)
                    end

                    table.insert(pa_o2_fi_o2_ratio_links, link)
                end
            end
        end
    end
    if #pa_o2_fi_o2_ratio_links == 0 then
        -- Method #3 - Look through FiO2 values for matching SpO2 values
        for _, fi_o2_dv in ipairs(fi_o2_dvs) do
            local sp_o2_dv = discrete.get_discrete_value_nearest_to_date {
                discreteValueNames = dv_sp_o2,
                date = fi_o2_dv.result_date,
                predicate = function(dv)
                    return
                        dates.dates_are_less_than_x_minutes_apart(fi_o2_dv.result_date, dv.result_date, 5) and
                        tonumber(dv.result) ~= nil
                end
            }
            if sp_o2_dv then
                local fi_o2 = discrete.get_dv_value_number(fi_o2_dv)
                local sp_o2 = discrete.get_dv_value_number(sp_o2_dv)
                local pa_o2 = sp_o2_to_pa_o2_lookup[sp_o2]
                if pa_o2 then
                    local ratio = pa_o2 / fi_o2
                    if ratio <= 300 then
                        local resp_rate_dv = discrete.get_discrete_value_nearest_to_date {
                            discreteValueNames = dv_respiratory_rate,
                            date = fi_o2_dv.result_date,
                        }
                        -- Build link
                        local link = cdi_alert_link()
                        link.discrete_value_id = fi_o2_dv.unique_id
                        link.link_text =
                            os.date(fi_o2_dv.result_date) ..
                            " - Calculated PaO2/FiO2 from FiO2 (" .. fi_o2 ..
                            ") and SpO2(" .. sp_o2 ..
                            ") yielding a ratio of (" .. ratio .. ")"
                        link.sequence = 8
                        if resp_rate_dv then
                            link.link_text = link.link_text .. " - Respiratory Rate: " .. discrete.get_dv_value_number(resp_rate_dv)
                        end
                        table.insert(pa_o2_fi_o2_ratio_links, link)
                    end
                end
            end
        end
    end
    if #pa_o2_fi_o2_ratio_links == 0 then
        -- Method #4 - Look through Oxygen values for matching PaO2 values
        for _, oxygen_pair in ipairs(oxygen_pairs) do
            local oxygen_flow_rate_value = discrete.get_dv_value_number(oxygen_pair.first)
            local oxygen_therapy_value = oxygen_pair.second.result
            --- @type number?
            local fi_o2 = nil
            if oxygen_therapy_value == "Nasal Cannula" then
                fi_o2 = flow_rate_to_fi_o2_lookup[oxygen_flow_rate_value]
                if fi_o2 then
                    local pa_o2_dv = discrete.get_discrete_value_nearest_to_date {
                        discreteValueNames = dv_pa_o2,
                        date = oxygen_pair.first.result_date,
                        predicate = function(dv)
                            return
                                dates.dates_are_less_than_x_minutes_apart(oxygen_pair.first.result_date, dv.result_date, 5) and
                                tonumber(dv.result) ~= nil
                        end
                    }
                    if pa_o2_dv then
                        local pa_o2 = discrete.get_dv_value_number(pa_o2_dv)
                        local ratio = pa_o2 / fi_o2
                        if ratio <= 300 then
                            local resp_rate_dv = discrete.get_discrete_value_nearest_to_date {
                                discreteValueNames = dv_respiratory_rate,
                                date = oxygen_pair.first.result_date,
                            }
                            -- Build link 
                            local link = cdi_alert_link()
                            link.discrete_value_id = oxygen_pair.first.unique_id
                            link.link_text =
                                os.date(oxygen_pair.first.result_date) ..
                                " - Calculated PaO2/FiO2 from Oxygen Flow Rate(" .. oxygen_flow_rate_value ..
                                " - " .. oxygen_therapy_value ..
                                ") and PaO2 (" .. pa_o2 ..
                                ") yielding a ratio of (" .. ratio .. ")"
                            link.sequence = 8
                            if resp_rate_dv then
                                link.link_text = link.link_text .. " - Respiratory Rate: " .. discrete.get_dv_value_number(resp_rate_dv)
                            end
                            table.insert(pa_o2_fi_o2_ratio_links, link)
                        end
                    end
                end
            end
        end
    end
    if #pa_o2_fi_o2_ratio_links == 0 then
        -- Method #5 - Look through Oxygen values for matching SpO2 values
        for _, oxygen_pair in ipairs(oxygen_pairs) do
            local oxygen_flow_rate_value = discrete.get_dv_value_number(oxygen_pair.first)
            local oxygen_therapy_value = oxygen_pair.second.result
            --- @type number?
            local fi_o2 = nil
            if oxygen_therapy_value == "Nasal Cannula" then
                fi_o2 = flow_rate_to_fi_o2_lookup[oxygen_flow_rate_value]
                if fi_o2 then
                    local sp_o2_dv = discrete.get_discrete_value_nearest_to_date {
                        discreteValueNames = dv_sp_o2,
                        date = oxygen_pair.first.result_date,
                        predicate = function(dv)
                            return
                                dates.dates_are_less_than_x_minutes_apart(oxygen_pair.first.result_date, dv.result_date, 5) and
                                tonumber(dv.result) ~= nil
                        end
                    }
                    if sp_o2_dv then
                        local sp_o2 = discrete.get_dv_value_number(sp_o2_dv)
                        local pa_o2 = sp_o2_to_pa_o2_lookup[sp_o2]
                        if pa_o2 then
                            local ratio = pa_o2 / fi_o2
                            if ratio <= 300 then
                                local resp_rate_dv = discrete.get_discrete_value_nearest_to_date {
                                    discreteValueNames = dv_respiratory_rate,
                                    date = oxygen_pair.first.result_date,
                                }
                                -- Build link
                                local link = cdi_alert_link()
                                link.discrete_value_id = oxygen_pair.first.unique_id
                                link.link_text =
                                    os.date(oxygen_pair.first.result_date) ..
                                    " - Calculated PaO2/FiO2 from Oxygen Flow Rate(" .. oxygen_flow_rate_value ..
                                    " - " .. oxygen_therapy_value ..
                                    ") and SpO2 (" .. sp_o2 ..
                                    ") yielding a ratio of (" .. ratio .. ")"
                                link.sequence = 8
                                if resp_rate_dv then
                                    link.link_text = link.link_text .. " - Respiratory Rate: " .. discrete.get_dv_value_number(resp_rate_dv)
                                end
                                table.insert(pa_o2_fi_o2_ratio_links, link)
                            end
                        end
                    end
                end
            end
        end
    end
    return pa_o2_fi_o2_ratio_links
end

--------------------------------------------------------------------------------
--- Get fallback links for PaO2 and SpO2
--- These are gathered if the PaO2/FiO2 collection fails
--- 
--- @return CdiAlertLink[]
--------------------------------------------------------------------------------
local function get_pa_o2_sp_o2_links()
    --- @param date_time string?
    --- @param link_text string
    --- @param result string?
    --- @param id string?
    --- @param seq number
    ---
    --- @return CdiAlertLink
    local function create_link(date_time, link_text, result, id, seq)
        local link = cdi_alert_link()

        if date_time then
            link_text = link_text:gsub("[RESULTDATETIME]", date_time)
        else
            link_text = link_text:gsub("(Result Date: [RESULTDATETIME])", "")
        end
        if result then
            link_text = link_text:gsub("[VALUE]", result)
        else
            link_text = link_text:gsub("[VALUE]", "")
        end
        link.link_text = link_text
        link.discrete_value_id = id
        link.sequence = seq
        return link
    end

    local sp_o2_discrete_values = {}
    local pa_o2_discrete_values = {}
    local o2_therapy_discrete_values = {}
    local respiratory_rate_discrete_values = {}
    local sp_o2_link_text = "sp02: [VALUE] (Result Date: [RESULTDATETIME])"
    local pao2_link_text = "pa02: [VALUE] (Result Date: [RESULTDATETIME])"
    local o2_therapy_link_text = "Oxygen Therapy '[VALUE]' (Result Date: [RESULTDATETIME])"
    local respiratory_rate_link_text = "Respiratory Rate: [VALUE] (Result Date: [RESULTDATETIME])"
    local date_limit = os.time() - 86400
    local pa_dv_idx = nil
    local sp_dv_idx = nil
    local ot_dv_idx = nil
    local rr_dv_idx = nil
    local matching_date = nil
    local oxygen_value = nil
    local resp_rate_str = nil
    local matched_list = {}

    sp_o2_discrete_values = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_sp_o2,
        predicate = function(dv)
            return dates.date_string_to_int(dv.result_date) >= date_limit and discrete.get_dv_value_number(dv) < 91
        end
    }

    pa_o2_discrete_values = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_pa_o2,
        predicate = function(dv)
            return dates.date_string_to_int(dv.result_date) >= date_limit and discrete.get_dv_value_number(dv) <= 60
        end
    }

    o2_therapy_discrete_values = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_oxygen_therapy,
        predicate = function(dv)
            return dates.date_string_to_int(dv.result_date) >= date_limit and dv.result ~= nil
        end
    }

    respiratory_rate_discrete_values = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_respiratory_rate,
        predicate = function(dv)
            return dates.date_string_to_int(dv.result_date) >= date_limit and discrete.get_dv_value_number(dv) ~= nil
        end
    }

    if #pa_o2_discrete_values > 0 then
        for idx, item in pa_o2_discrete_values do
            matching_date = dates.date_string_to_int(item.result_date)
            pa_dv_idx = idx
            if #o2_therapy_discrete_values > 0 then
                for idx2, item2 in o2_therapy_discrete_values do
                    if dates.date_string_to_int(item.result_date) == dates.date_string_to_int(item2.result_date) then
                        matching_date = dates.date_string_to_int(item.result_date)
                        ot_dv_idx = idx2
                        oxygen_value = item2.result
                        break
                    end
                end
            else
                oxygen_value = "XX"
            end
            if #respiratory_rate_discrete_values > 0 then
                for idx3, item3 in respiratory_rate_discrete_values do
                    if dates.date_string_to_int(item3.result_date) == matching_date then
                        rr_dv_idx = idx3
                        resp_rate_str = item3.result
                        break
                    end
                end
            else
                resp_rate_str = "XX"
            end

            matching_date = dates.date_int_to_string(matching_date)
            table.insert(
                matched_list,
                create_link(
                    nil,
                    matching_date .. " Respiratory Rate: " .. resp_rate_str .. ", Oxygen Therapy: " .. oxygen_value ..
                    ", pa02: " .. pa_o2_discrete_values[pa_dv_idx].result,
                    nil,
                    pa_o2_discrete_values[pa_dv_idx].unique_id,
                    0
                )
            )
            table.insert(
                matched_list,
                create_link(
                    pa_o2_discrete_values[pa_dv_idx].result_date,
                    pao2_link_text,
                    pa_o2_discrete_values[pa_dv_idx].result,
                    pa_o2_discrete_values[pa_dv_idx].unique_id,
                    2
                )
            )
            if ot_dv_idx then
                table.insert(
                    matched_list,
                    create_link(
                        o2_therapy_discrete_values[ot_dv_idx].result_date,
                        o2_therapy_link_text,
                        o2_therapy_discrete_values[ot_dv_idx].result,
                        o2_therapy_discrete_values[ot_dv_idx].unique_id,
                        3
                    )
                )
            end
            if rr_dv_idx then
                table.insert(
                    matched_list,
                    create_link(
                        respiratory_rate_discrete_values[rr_dv_idx].result_date,
                        respiratory_rate_link_text,
                        respiratory_rate_discrete_values[rr_dv_idx].result,
                        respiratory_rate_discrete_values[rr_dv_idx].unique_id,
                        4
                    )
                )
            end
        end
        return matched_list
    elseif #sp_o2_discrete_values > 0 then
        for idx, item in sp_o2_discrete_values do
            matching_date = dates.date_string_to_int(item.result_date)
            sp_dv_idx = idx

            if #o2_therapy_discrete_values > 0 then
                for idx2, item2 in o2_therapy_discrete_values do
                    if dates.date_string_to_int(item.result_date) == dates.date_string_to_int(item2.result_date) then
                        matching_date = dates.date_string_to_int(item.result_date)
                        ot_dv_idx = idx2
                        oxygen_value = item2.result
                        break
                    end
                end
            else
                oxygen_value = "XX"
            end
            if #respiratory_rate_discrete_values > 0 then
                for idx3, item3 in respiratory_rate_discrete_values do
                    if dates.date_string_to_int(item3.result_date) == matching_date then
                        rr_dv_idx = idx3
                        resp_rate_str = item3.result
                        break
                    end
                end
            else
                resp_rate_str = "XX"
            end
            matching_date = dates.date_int_to_string(matching_date)
            table.insert(
                matched_list,
                create_link(
                    nil,
                    matching_date .. " Respiratory Rate: " .. resp_rate_str .. ", Oxygen Therapy: " .. oxygen_value ..
                    ", sp02: " .. sp_o2_discrete_values[sp_dv_idx].result,
                    nil,
                    sp_o2_discrete_values[sp_dv_idx].unique_id,
                    0
                )
            )
            table.insert(
                matched_list,
                create_link(
                    sp_o2_discrete_values[sp_dv_idx].result_date,
                    sp_o2_link_text,
                    sp_o2_discrete_values[sp_dv_idx].result,
                    sp_o2_discrete_values[sp_dv_idx].unique_id,
                    1
                )
            )
            if ot_dv_idx then
                table.insert(
                    matched_list,
                    create_link(
                        o2_therapy_discrete_values[ot_dv_idx].result_date,
                        o2_therapy_link_text,
                        o2_therapy_discrete_values[ot_dv_idx].result,
                        o2_therapy_discrete_values[ot_dv_idx].unique_id,
                        5
                    )
                )
            end
            if rr_dv_idx then
                table.insert(
                    matched_list,
                    create_link(
                        respiratory_rate_discrete_values[rr_dv_idx].result_date,
                        respiratory_rate_link_text,
                        respiratory_rate_discrete_values[rr_dv_idx].result,
                        respiratory_rate_discrete_values[rr_dv_idx].unique_id,
                        7
                    )
                )
            end
        end
        return matched_list
    else
        return {}
    end
end



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
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 2)
    local oxygenation_ventilation_header = headers.make_header_builder("Oxygenation/Ventilation", 3)
    local calculated_po2_fi02_header = headers.make_header_builder("Calculated P02/Fi02 Ratio", 4)
    local oxygenation_indicators_header = headers.make_header_builder("O2 Indicators", 5)
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 6)
    local vital_signs_intake_header = headers.make_header_builder("Vital Signs/Intake", 7)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 8)
    local chest_x_ray_header = headers.make_header_builder("Chest X-Ray", 9)
    local abg_header = headers.make_header_builder("ABG", 88)
    local spo2_header = headers.make_header_builder("SpO2", 89)
    local pao2_fi02_header = headers.make_header_builder("PaO2FiO2", 90)
    local spo2_2_header = headers.make_header_builder("SpO2", 91)
    local pao2_header = headers.make_header_builder("PaO2", 92)
    local fio2_header = headers.make_header_builder("FIO2", 93)
    local rr_header = headers.make_header_builder("Respiratory Rate", 94)
    local oxygen_flow_rate_header = headers.make_header_builder("Oxygen Flow Rate", 95)
    local oxygen_therapy_header = headers.make_header_builder("Oxygen Therapy", 96)
    local pco2_header = headers.make_header_builder("pCO2", 95)

    local function compile_links()
        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, oxygenation_ventilation_header:build(true))
        table.insert(result_links, calculated_po2_fi02_header:build(true))
        table.insert(result_links, oxygenation_indicators_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, vital_signs_intake_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))
        table.insert(result_links, chest_x_ray_header:build(true))
        table.insert(result_links, abg_header:build(true))
        table.insert(result_links, spo2_header:build(true))
        table.insert(result_links, pao2_fi02_header:build(true))
        table.insert(result_links, spo2_2_header:build(true))
        table.insert(result_links, pao2_header:build(true))
        table.insert(result_links, fio2_header:build(true))
        table.insert(result_links, rr_header:build(true))
        table.insert(result_links, oxygen_flow_rate_header:build(true))
        table.insert(result_links, oxygen_therapy_header:build(true))
        table.insert(result_links, pco2_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end


    --------------------------------------------------------------------------------
    --- Alert Variables 
    --------------------------------------------------------------------------------
    local spec_code_dic = {
        ["J96.01"] = "Acute Respiratory Failure With Hypoxia",
        ["J96.02"] = "Acute Respiratory Failure With Hypercapnia",
        ["J96.11"] = "Chronic Respiratory Failure With Hypoxia",
        ["J96.12"] = "Chronic Respiratory Failure With Hypercapnia",
        ["J96.21"] = "Acute And Chronic Respiratory Failure With Hypoxia",
        ["J96.22"] = "Acute And Chronic Respiratory Failure With Hypercapnia",
        ["J95.821"] = "Acute Postprocedural Respiratory Failure"
    }

    local unspec_code_dic = {
        ["J96.90"] = "Respiratory Failure, Unspecified, Unspecified Whether With Hypoxia Or Hypercapnia",
        ["J96.91"] = "Respiratory Failure, Unspecified With Hypoxia",
        ["J96.92"] = "Respiratory Failure, Unspecified With Hypercapnia",
        ["J96.00"] = "Acute Respiratory Failure, Unspecified Whether With Hypoxia Or Hypercapnia",
        ["J96.10"] = "Chronic Respiratory Failure, Unspecified Whether With Hypoxia Or Hypercapnia",
        ["J96.20"] = "Acute And Chronic Respiratory Failure, Unspecified Whether With Hypoxia Or Hypercapnia"
    }

    local account_spec_codes = codes.get_account_codes_in_dictionary(Account, spec_code_dic)
    local account_unspec_codes = codes.get_account_codes_in_dictionary(Account, unspec_code_dic)



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Normal Alert
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

