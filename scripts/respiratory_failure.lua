---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Respiratory Failure
---
--- This script checks an account to see if it matches the criteria for a respiratory failure alert.
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
local cdi_alert_link = require "cdi.link"



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local dv_arterial_blood_co2 = { "PaCO2 (mmHg)", "BLD GAS CO2 (mmHg)" }
local calc_arterial_blood_co21 = function(dv_, num) return num > 45 end
local dv_arterial_blood_ph = { "pH" }
local calc_arterial_blood_ph1 = function(dv_, num) return num < 7.30 end
local calc_arterial_blood_ph2 = function(dv_, num) return num >= 7.35 end
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
local calc_pa_o21 = function(dv_, num) return num < 80 end
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
local calc_sp_o21 = function(dv_, num) return num < 91 end
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
                        link.link_text =
                            link.link_text ..
                            " - Respiratory Rate: " ..
                            discrete.get_dv_value_number(resp_rate_dv)
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
                            link.link_text =
                                link.link_text ..
                                " - Respiratory Rate: " ..
                                discrete.get_dv_value_number(resp_rate_dv)
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
                                dates.dates_are_less_than_x_minutes_apart(
                                    oxygen_pair.first.result_date,
                                    dv.result_date,
                                    5
                                ) and
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
                                link.link_text =
                                    link.link_text ..
                                    " - Respiratory Rate: "
                                    .. discrete.get_dv_value_number(resp_rate_dv)
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
                                dates.dates_are_less_than_x_minutes_apart(
                                    oxygen_pair.first.result_date,
                                    dv.result_date,
                                    5
                                ) and
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
                                    link.link_text = link.link_text ..
                                        " - Respiratory Rate: " ..
                                        discrete.get_dv_value_number(resp_rate_dv)
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
-- Link Text for special messages for lacking
local link_text1 = "Possible Missing Respiratory Clinical Evidence"
local link_text2 = "Possible Missing Type of Ventilation or Oxygen Delivery Method"
local link_text3 = "Possible Missing Sign(s) of Hypoxia, No Low Oxygen Levels Found"
local link_text4 = "Possible Missing Sign(s) of Hypercapnia, No High Carbon Dioxide Levels Found"
local message1 = false
local message2 = false
local message3 = false
local message4 = false

if existing_alert then
    for _, link in existing_alert.links do
        if link.link_text == "Vital Signs/Intake and Output Data" then
            if link.link_text == link_text3 then
                for _, link2 in link.links do
                    if link2.link_text == link_text3 then message3 = true end
                end
            elseif link.link_text == "Laboratory Studies" then
                for _, link2 in link.links do
                    if link2.link_text == link_text4 then message4 = true end
                end
            elseif link.link_text == "Clinical Evidence" then
                for _, link2 in link.links do
                    if link2.link_text == link_text1 then message1 = true end
                end
            elseif link.link_text == "Oxygenation/Ventilation" then
                for _, link2 in link.links do
                    if link2.link_text == link_text2 then message2 = true end
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
    local oxygenation_ventilation_header = headers.make_header_builder("Oxygenation/Ventilation", 3)
    local calculated_po2_fio2_header = headers.make_header_builder("Calculated P02/Fi02 Ratio", 4)
    local oxygenation_indicators_header = headers.make_header_builder("O2 Indicators", 5)
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 6)
    local vital_signs_intake_header = headers.make_header_builder("Vital Signs/Intake", 7)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 8)
    local chest_x_ray_header = headers.make_header_builder("Chest X-Ray", 9)
    local abg_header = headers.make_header_builder("ABG", 88)
    local spo2_header = headers.make_header_builder("SpO2", 89)
    local pao2_fio2_header = headers.make_header_builder("PaO2FiO2", 90)
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
        table.insert(result_links, calculated_po2_fio2_header:build(true))
        table.insert(result_links, oxygenation_indicators_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, vital_signs_intake_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))
        table.insert(result_links, chest_x_ray_header:build(true))
        table.insert(result_links, abg_header:build(true))
        table.insert(result_links, spo2_header:build(true))
        table.insert(result_links, pao2_fio2_header:build(true))
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
    -- Negations
    local negation_acute_respiratory_failure = links.get_code_link {
        codes = {
            "J96.01", "J96.02", "J96.11", "J96.12", "J96.21", "J96.22",
            "J96.90", "J96.91", "J96.92", "J96.00", "J96.10", "J96.20"
        },
        text = "Respiratory Failure Fully Specified Code"
    }
    -- Documented Dx
    local acute_respiratory_failure_hypox = links.get_code_link {
        codes = { "J96.01", "J96.21" },
        text = "Acute Respiratory Failure with Hypoxia Fully Specified Code"
    }
    local acute_respiratory_failure_hyper = links.get_code_link {
        codes = { "J96.02", "J96.22" },
        text = "Acute Respiratory Failure with Hypercapnia Fully Specified Code"
    }
    local j9601_code = links.get_code_link {
        code = "J96.01",
        text = "Acute Respiratory Failure With Hypoxia"
    }
    local j9602_code = links.get_code_link {
        code = "J96.02",
        text = "Acute Respiratory Failure With Hypercapnia"
    }
    local j9611_code = links.get_code_link {
        code = "J96.11",
        text = "Chronic Respiratory Failure With Hypoxia"
    }
    local j9612_code = links.get_code_link {
        code = "J96.12",
        text = "Chronic Respiratory Failure With Hypercapnia"
    }
    local j9621_code = links.get_code_link {
        code = "J96.21",
        text = "Autoresolved Alert Due To Acute and Chronic Respiratory Failure with Hypoxia"
    }
    local j9622_code = links.get_code_link {
        code = "J96.22",
        text = "Autoresolved Alert Due To Acute on Chronic Respiratory Failure with Hypercapnia"
    }
    local j9690_code = links.get_code_link {
        code = "J96.90",
        text = "Respiratory Failure, Unspecified, Unspecified Whether With Hypoxia Or Hypercapnia"
    }
    local j9691_code = links.get_code_link { code = "J96.91", text = "Respiratory Failure, Unspecified With Hypoxia" }
    local j9692_code = links.get_code_link {
        code = "J96.92",
        text = "Respiratory Failure, Unspecified With Hypercapnia"
    }
    local j95821_code = links.get_code_link {
        code = "J95.821",
        text = "Acute Postprocedural Respiratory Failure (MCC)"
    }
    local j80_code = links.get_code_link { code = "J80", text = "Acute Respiratory Distress Syndrome (MCC)" }

    -- Clinical Evidence
    local paradoxical_breathing_abs = links.get_abstraction_link {
        code = "PARADOXICAL_BREATHING",
        text = "Paradoxical Breathing"
    }
    local r092_code = links.get_code_link { code = "R09.2", text = "Respiratory Arrest" };
    local retractions_abs = links.get_abstraction_link { code = "RETRACTIONS", text = "Retractions" }
    local shortness_of_breath_abs = links.get_abstraction_link {
        code = "SHORTNESS_OF_BREATH",
        text = "Shortness of Breath"
    }
    local r061_code = links.get_code_link { code = "R06.1", text = "Stridor" }
    local tripod_breathing_abs = links.get_abstraction_link { code = "TRIPOD_BREATHING", text = "Tripod Breathing" }
    local use_of_accessory_muscles_abs = links.get_abstraction_link {
        code = "USE_OF_ACCESSORY_MUSCLES",
        text = "Use of Accessory Muscles"
    }
    local wheezing_abs = links.get_code_link { code = "R06.2", text = "Wheezing" }

    -- Labs
    local high_arterial_blood_co2_abs = links.get_abstraction_link { code = "HIGH_BLOOD_C02", text = "Blood CO2" }

    -- ABG
    local high_arterial_blood_co2_dv = links.get_discrete_value_link {
        discreteValueNames = dv_arterial_blood_co2,
        text = "paCO2",
        predicate = calc_arterial_blood_co21,
    }
    local pao28o_dv = links.get_discrete_value_link {
        discreteValueNames = dv_pa_o2,
        text = "pa02",
        predicate = calc_pa_o21,
    }
    local venous_blood_dv = links.get_discrete_value_link {
        discreteValueNames = dv_venous_blood_co2,
        text = "Venous Blood C02",
        predicate = calc_venous_blood_co2,
    }

    -- Oxygen
    local baseline_abs = links.get_abstraction_link { code = "BASELINE_OXYGEN_USE", text = "Baseline Oxygen Use" }
    local ecmo_codes = links.get_code_link {
        codes = { "5A1522F", "5A1522G", "5A1522H", "5A15A2F", "5A15A2G", "5A15A2H" },
        text = "ECMO"
    }
    local z9981_code = links.get_code_link { code = "Z99.81", text = "Dependence On Supplemental Oxygen" }
    local z9911_code = links.get_code_link { code = "Z99.11", text = "Dependence On Ventilator" }
    local high_flow_nasal_codes = links.get_code_link {
        codes = { "5A0935A", "5A0945A", "5A0955A" },
        text = "High Flow Nasal Oxygen"
    }
    local intubation_code = links.get_code_link { code = "0BH17EZ", text = "Intubation" }
    local invasive_mech_vent_codes = links.get_code_link {
        codes = { "5A1935Z", "5A1945Z", "5A1955Z" },
        text = "Invasive Mechanical Ventilation"
    }
    local nasal_cannula_code = links.get_code_link { code = "3E0F7SF", text = "Nasal Cannula" }
    local non_invasive_mech_vent_codes = links.get_abstraction_link {
        code = "NON_INVASIVE_VENTILATION",
        text = "Non-Invasive Ventilation"
    }
    local oxygen_therapy_dv = links.get_discrete_value_link {
        discreteValueNames = dv_oxygen_therapy,
        text = "Oxygen Therapy",
        predicate = function(dv, num_)
            return dv.result:find("Room Air") ~= nil or dv.result:find("RA") ~= nil
        end
    }
    local oxygen_therapy_abs = links.get_abstraction_link { code = "OXYGEN_THERAPY", text = "Oxygen Therapy" }
    local z930_code = links.get_code_link { code = "Z93.0", text = "Tracheostomy" }

    -- Vitals
    local lacking_pa_o2_dv = links.get_discrete_value_link {
        discreteValueNames = dv_pa_o2,
        text = "pa02",
        predicate = calc_pa_o22,
    }
    local lacking_pa_o2_fi_o2_dv = links.get_discrete_value_link {
        discreteValueNames = dv_pa_o2_fi_o2,
        text = "P02(a)/Fi02 Ratio",
        predicate = calc_pa_o2_fi_o2_2,
    }
    local high_respiratory_rate_dv = links.get_discrete_value_link {
        discreteValueNames = dv_respiratory_rate,
        text = "Respiratory Rate",
        predicate = calc_respiratory_rate1,
    }
    local low_respiratory_rate_dv = links.get_discrete_value_link {
        discreteValueNames = dv_respiratory_rate,
        text = "Respiratory Rate",
        predicate = calc_respiratory_rate2,
    }
    local lacking_pulse_oximetry_dv = links.get_discrete_value_link {
        discreteValueNames = dv_sp_o2,
        text = "Sp02",
        predicate = calc_respiratory_rate2,
    }
    -- Vitals Subheading
    local low_pulse_oximetry_dv = links.get_discrete_value_links {
        discreteValueNames = dv_sp_o2,
        text = "Sp02",
        predicate = calc_sp_o21,
    }

    -- Calculated Po2/Fio2
    local pa_o2_calc = z9981_code and nil or get_pa_o2_fi_o2_links()
    local sp_o2_pa_o2_dvs = pa_o2_calc and get_pa_o2_sp_o2_links() or nil

    -- Clinical Indicator Check
    local ci = 0
    if use_of_accessory_muscles_abs then
        clinical_evidence_header:add_link(use_of_accessory_muscles_abs)
        ci = ci + 1
    end
    if wheezing_abs then
        clinical_evidence_header:add_link(wheezing_abs)
        ci = ci + 1
    end
    if shortness_of_breath_abs then
        clinical_evidence_header:add_link(shortness_of_breath_abs)
        ci = ci + 1
    end
    if high_respiratory_rate_dv or low_respiratory_rate_dv then
        ci = ci + 1
        laboratory_studies_header:add_link(high_respiratory_rate_dv)
        laboratory_studies_header:add_link(low_respiratory_rate_dv)
    end
    if r061_code then
        clinical_evidence_header:add_link(r061_code)
        ci = ci + 1
    end
    if tripod_breathing_abs then
        clinical_evidence_header:add_link(tripod_breathing_abs)
        ci = ci + 1
    end
    if r092_code then
        clinical_evidence_header:add_link(r092_code)
        ci = ci + 1
    end
    if paradoxical_breathing_abs then
        clinical_evidence_header:add_link(paradoxical_breathing_abs)
        ci = ci + 1
    end
    if retractions_abs then
        clinical_evidence_header:add_link(retractions_abs)
        ci = ci + 1
    end

    -- Oxygen Delivery Check
    local odc = 0
    if oxygen_therapy_dv or oxygen_therapy_abs then odc = odc + 1 end
    if intubation_code then odc = odc + 1 end
    if non_invasive_mech_vent_codes then odc = odc + 1 end
    if invasive_mech_vent_codes then odc = odc + 1 end
    if high_flow_nasal_codes then odc = odc + 1 end
    if nasal_cannula_code then odc = odc + 1 end

    -- Oxygenation Check
    local oc = 0
    if pa_o2_calc then oc = oc + 1 end
    if sp_o2_pa_o2_dvs then oc = oc + 1 end

    -- Hypercapnic Check
    local hc = 0
    if high_arterial_blood_co2_dv or high_arterial_blood_co2_abs then
        hc = hc + 1
        if high_arterial_blood_co2_abs then laboratory_studies_header:add_link(high_arterial_blood_co2_abs) end
    end
    if venous_blood_dv then hc = hc + 1 end

    -- Lacking Oxygenation Check
    local loc = 0
    if lacking_pa_o2_dv then loc = loc + 1 end
    if lacking_pa_o2_fi_o2_dv then loc = loc + 1 end
    if lacking_pulse_oximetry_dv then loc = loc + 1 end
    if pa_o2_calc then loc = loc + 1 end



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if
        subtitle == "Acute Respiratory Failure With Hypoxia Possibly Lacking Supporting Evidence" and
        (
            (message1 == false or (message1 == true and ci > 0)) and
            (message2 == false or (message2 == true and odc > 0)) and
            (message3 == false or (message3 == true and loc > 0))
        )
    then
        -- 1.1
        if message1 then clinical_evidence_header:add_link(links.get_matched_criteria_link(link_text1)) end
        if message2 then oxygenation_ventilation_header:add_link(links.get_matched_criteria_link(link_text2)) end
        if message3 then
            vital_signs_intake_header:add_link(links.get_matched_criteria_link(link_text3))
            if lacking_pa_o2_dv then vital_signs_intake_header:add_link(lacking_pa_o2_dv) end
            if lacking_pa_o2_fi_o2_dv then vital_signs_intake_header:add_link(lacking_pa_o2_fi_o2_dv) end
            if lacking_pulse_oximetry_dv then vital_signs_intake_header:add_link(lacking_pulse_oximetry_dv) end
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.validated = true
        Result.passed = true

    elseif acute_respiratory_failure_hypox and (ci == 0 or odc == 0 or loc == 0) then
        -- 1
        documented_dx_header:add_link(acute_respiratory_failure_hypox)
        if ci < 1 then clinical_evidence_header:add_link(links.get_matched_criteria_link(link_text1)) end
        if odc < 1 then oxygenation_ventilation_header:add_link(links.get_matched_criteria_link(link_text2)) end
        if loc < 1 then vital_signs_intake_header:add_link(links.get_matched_criteria_link(link_text3)) end
        if lacking_pa_o2_dv then vital_signs_intake_header:add_link(lacking_pa_o2_dv) end
        if lacking_pa_o2_fi_o2_dv then vital_signs_intake_header:add_link(lacking_pa_o2_fi_o2_dv) end
        if lacking_pulse_oximetry_dv then vital_signs_intake_header:add_link(lacking_pulse_oximetry_dv) end
        Result.subtitle = "Acute Respiratory Failure With Hypoxia Possibly Lacking Supporting Evidence"
        Result.passed = true

    elseif
        subtitle == "Acute Respiratory Failure With Hypercapnia Possibly Lacking Supporting Evidence" and
        (
            (message1 == false or (message1 == true and ci > 0)) and
            (message2 == false or (message2 == true and odc > 0)) and
            (message4 == false or (message4 == true and hc > 0))
        )
    then
        -- 2.1
        if message1 then clinical_evidence_header:add_text_link(link_text1) end
        if message2 then oxygenation_ventilation_header:add_text_link(link_text2) end
        if message4 then laboratory_studies_header:add_text_link(link_text4) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.validated = true
        Result.passed = true

    elseif acute_respiratory_failure_hyper and (ci == 0 or odc == 0 or hc == 0) then
        -- 2
        documented_dx_header:add_link(acute_respiratory_failure_hyper)
        if ci < 1 then clinical_evidence_header:add_link(links.get_matched_criteria_link(link_text1)) end
        if odc < 1 then oxygenation_ventilation_header:add_link(links.get_matched_criteria_link(link_text2)) end
        if hc < 1 then laboratory_studies_header:add_link(links.get_matched_criteria_link(link_text4)) end
        Result.subtitle = "Acute Respiratory Failure With Hypercapnia Possibly Lacking Supporting Evidence"
        Result.passed = true

    elseif
        (
            subtitle == "Respiratory Failure Dx Missing Acuity and Type" or
            subtitle == "Respiratory Failure with Hypoxia, Acuity Missing" or
            subtitle == "Respiratory Failure with Hypercapnia, Acuity Missing"
        ) and
        (j9601_code or j9602_code or j95821_code or j80_code)
    then
        -- 3.1/4.1/5.1
        if j9602_code then documented_dx_header:add_link(j9602_code) end
        if j9601_code then documented_dx_header:add_link(j9601_code) end
        if j95821_code then documented_dx_header:add_link(j95821_code) end
        if j80_code then documented_dx_header:add_link(j80_code) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specifed Code now existing on the Account"
        Result.validated = true
        Result.passed = true

    elseif j9691_code then
        -- 3
        documented_dx_header:add_link(j9691_code)
        Result.subtitle = "Respiratory Failure with Hypoxia, Acuity Missing"
        Result.passed = true

    elseif j9692_code then
        -- 4
        documented_dx_header:add_link(j9692_code)
        Result.subtitle = "Respiratory Failure with Hypercapnia, Acuity Missing"
        Result.passed = true

    elseif j9690_code then
        -- 5
        documented_dx_header:add_link(j9690_code)
        Result.subtitle = "Respiratory Failure Dx Missing Acuity and Type"
        Result.passed = true

    elseif
        subtitle == "Possible Chronic Respiratory Failure" and
        (j9601_code or j9602_code or j95821_code or j80_code or j9621_code or j9622_code or j9611_code or j9612_code)
    then
        -- 6.1
        documented_dx_header:add_link(j9602_code)
        documented_dx_header:add_link(j9601_code)
        documented_dx_header:add_link(j95821_code)
        documented_dx_header:add_link(j80_code)
        documented_dx_header:add_link(j9621_code)
        documented_dx_header:add_link(j9622_code)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specifed Code now existing on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        #account_unspec_codes == 0 and
        #account_spec_codes == 0 and
        ci >= 2 and
        odc >= 1 and
        (oc >= 1 or hc >= 1)
    then
        -- 6
        Result.subtitle = "Possible Acute Respiratory Failure"
        Result.passed = true

    elseif
        subtitle == "Possible Chronic Respiratory Failure" and
        (j9601_code or j9602_code or j95821_code or j80_code or j9621_code or j9622_code or j9611_code or j9612_code)
    then
        -- 7.1/8.1
        documented_dx_header:add_link(j9602_code)
        documented_dx_header:add_link(j9601_code)
        documented_dx_header:add_link(j95821_code)
        documented_dx_header:add_link(j80_code)
        documented_dx_header:add_link(j9621_code)
        documented_dx_header:add_link(j9622_code)
        documented_dx_header:add_link(j9611_code)
        documented_dx_header:add_link(j9612_code)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specifed Code now existing on the Account"
        Result.validated = true
        Result.passed = true

    elseif negation_acute_respiratory_failure and z930_code and (oc >= 1 or hc >= 1) then
        -- 7
        Result.subtitle = "Possible Chronic Respiratory Failure"
        Result.passed = true

    elseif z9981_code or z9911_code then
        -- 8
        Result.subtitle = "Possible Chronic Respiratory Failure"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Clinical Evidence
            clinical_evidence_header:add_code_link("R06.9", "Abnormalities of Breathing")
            local r4182_code = links.get_code_link { code = "R41.82", text = "Altered Level Of Consciousness" }
            local altered_abs = links.get_abstraction_link {
                code = "ALTERED_LEVEL_OF_CONSCIOUSNESS",
                text = "Altered Level Of Consciousness"
            }
            if r4182_code then
                clinical_evidence_header:add_link(r4182_code)
                if altered_abs then altered_abs.hidden = true; clinical_evidence_header:add_link(altered_abs) end
            else
                clinical_evidence_header:add_link(altered_abs)
            end
            clinical_evidence_header:add_code_link("G12.21", "Amyotrophic Lateral Sclerosis")
            clinical_evidence_header:add_code_link("T78.3XXA", "Angioedema")
            clinical_evidence_header:add_code_link("R06.81", "Apnea")
            clinical_evidence_header:add_code_link("J69.0", "Aspiration")
            clinical_evidence_header:add_code_links(
                { "J45.21", "J45.31", "J45.41", "J45.51", "J454.901" },
                "Asthma with Acute Exacerbation"
            )
            clinical_evidence_header:add_code_links(
                { "J45.22", "J45.32", "J45.42", "J45.52", "J45.902" },
                "Asthma with Status Asthmaticus"
            )
            clinical_evidence_header:add_code_link("J98.01", "Bronchospasm")
            clinical_evidence_header:add_code_link("J44.9", "Chronic Obstructive Pulmonary Disease")
            clinical_evidence_header:add_code_link(
                "J44.1",
                "Chronic Obstructive Pulmonary Disease With (Acute) Exacerbation"
            )
            clinical_evidence_header:add_code_link(
                "J44.0",
                "Chronic Obstructive Pulmonary Disease With (Acute) Lower Respiratory Infection"
            )
            clinical_evidence_header:add_code_link("R05.9", "Cough")
            clinical_evidence_header:add_code_link("U07.1", "COVID-19 Infection")
            clinical_evidence_header:add_abstraction_link("CYANOSIS", "Cyanosis")
            clinical_evidence_header:add_code_link("E84.0", "Cystic Fibrosis with Pulmonary Manifestations")
            clinical_evidence_header:add_code_link("E84.9", "Cystic Fibrosis")
            clinical_evidence_header:add_abstraction_link("DIAPHORETIC", "Diaphoretic")
            clinical_evidence_header:add_code_link("R41.0", "Disorientation")
            clinical_evidence_header:add_code_link("R53.83", "Fatigue")
            clinical_evidence_header:add_code_link("E87.70", "Fluid Overloaded")
            clinical_evidence_header:add_code_link("K76.7", "Hepatorenal Syndrome")
            clinical_evidence_header:add_code_link("R09.02", "Hypoxia")
            clinical_evidence_header:add_code_link("J84.9", "Interstitial Lung Disease")
            clinical_evidence_header:add_abstraction_link(
                "IRREGULAR_RADIOLOGY_REPORT_LUNGS",
                "Irregular Radiology Lungs"
            )
            clinical_evidence_header:add_code_link("N28.0", "Ischemia and Infarction of Kidney")
            clinical_evidence_header:add_code_link("G71.00", "Muscular Dystrophy")
            clinical_evidence_header:add_code_link("G70.01", "Myasthenia Gravis with Exacerbation")
            clinical_evidence_header:add_code_link("G70.00", "Myasthenia Gravis without Exacerbation")
            -- 31
            clinical_evidence_header:add_abstraction_link("OPIOID_OVERDOSE", "Opioid Overdose")
            -- 33
            clinical_evidence_header:add_abstraction_link("PLEURAL_EFFUSION", "Pleural Effusion")
            clinical_evidence_header:add_code_link("U09.9", "Post COVID-19 Condition")
            clinical_evidence_header:add_abstraction_link("PULMONARY_EDEMA", "Pulmonary Edema")
            clinical_evidence_header:add_abstraction_link("PULMONARY_TOILET", "Pulmonary Toilet")
            -- 38-43
            clinical_evidence_header:add_code_link("J95.851", "Ventilator Associated Pneumonia")
            -- 45
            -- Document Links
            clinical_evidence_header:add_document_link("Chest  3 View", "Chest  3 View")
            clinical_evidence_header:add_document_link("Chest  PA and Lateral", "Chest  PA and Lateral")
            clinical_evidence_header:add_document_link("Chest  Portable", "Chest  Portable")
            clinical_evidence_header:add_document_link("Chest PA and Lateral", "Chest PA and Lateral")
            clinical_evidence_header:add_document_link("Chest  1 View", "Chest  1 View")
            -- Laboratory Studies
            -- 2
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_serum_bicarbonate,
                "HCO3",
                calc_serum_bicarbonate1
            )
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_serum_bicarbonate,
                "HCO3",
                calc_serum_bicarbonate2
            )
            -- 4
            -- Meds
            treatment_and_monitoring_header:add_medication_link("Bronchodilator", "Bronchodilator")
            treatment_and_monitoring_header:add_abstraction_link("BRONCHODILATOR", "Bronchodilator")
            treatment_and_monitoring_header:add_medication_link("Dexamethasone", "Dexamethasone")
            treatment_and_monitoring_header:add_abstraction_link("DEXAMETHASONE", "Dexamethasone")
            treatment_and_monitoring_header:add_medication_link("Inhaled Corticosteroid", "Inhaled Corticosteroid")
            treatment_and_monitoring_header:add_abstraction_link("INHALED_CORTICOSTEROID", "Inhaled Corticosteroid")
            treatment_and_monitoring_header:add_medication_link("Methylprednisolone", "Methylprednisolone")
            treatment_and_monitoring_header:add_abstraction_link("METHYLPREDNISOLONE", "Methylprednisolone")
            treatment_and_monitoring_header:add_medication_link(
                "Respiratory Treatment Medication",
                "Respiratory Treatment Medication"
            )
            treatment_and_monitoring_header:add_abstraction_link(
                "RESPIRATORY_TREATMENT_MEDICATION",
                "Respiratory Treatment Medication"
            )
            treatment_and_monitoring_header:add_medication_link("Steroid", "Steroid")
            treatment_and_monitoring_header:add_abstraction_link("STEROIDS", "Steroid")
            treatment_and_monitoring_header:add_medication_link("Vasodilator", "Vasodilator")
            treatment_and_monitoring_header:add_abstraction_link("VASODILATOR", "Vasodilator")

            -- Oxygen
            oxygenation_indicators_header:add_link(baseline_abs)
            oxygenation_indicators_header:add_link(ecmo_codes)
            oxygenation_indicators_header:add_link(z9981_code)
            oxygenation_indicators_header:add_link(z9911_code)
            if pa_o2_calc then
                oxygenation_indicators_header:add_discrete_value_one_of_link(dv_fi_o2, "Fi02", calc_fi_o21)
            end
            oxygenation_indicators_header:add_link(high_flow_nasal_codes)
            oxygenation_indicators_header:add_link(intubation_code)
            oxygenation_indicators_header:add_link(invasive_mech_vent_codes)
            oxygenation_indicators_header:add_link(nasal_cannula_code)
            oxygenation_indicators_header:add_link(non_invasive_mech_vent_codes)
            oxygenation_indicators_header:add_discrete_value_one_of_link(
                dv_oxygen_therapy,
                "Oxygen Therapy",
                calc_oxygen_flow_rate1
            )
            oxygenation_indicators_header:add_link(oxygen_therapy_dv)
            oxygenation_indicators_header:add_link(oxygen_therapy_abs)
            oxygenation_indicators_header:add_link(z930_code)

            -- Vitals
            vital_signs_intake_header:add_discrete_value_one_of_link(
                dv_glasgow_coma_scale,
                "Glasgow Coma Score",
                calc_glasgow_coma_scale1
            )
            vital_signs_intake_header:add_discrete_value_one_of_link(dv_heart_rate, "Heart Rate", calc_heart_rate1)

            -- 3-7
            -- Vitals Sub Categories
            if low_pulse_oximetry_dv then
                for _, entry in ipairs(low_pulse_oximetry_dv) do
                    spo2_header:add_link(entry)
                end
            end

            -- ABG
            local arterial_blood_ph_dv = links.get_discrete_value_link {
                discreteValueNames = dv_arterial_blood_ph,
                text = "PH",
                predicate = calc_arterial_blood_ph1,
            }
            if arterial_blood_ph_dv then
                abg_header:add_link(arterial_blood_ph_dv)
            else
                abg_header:add_discrete_value_one_of_link(dv_arterial_blood_ph, "PH", calc_arterial_blood_ph2)
            end
            abg_header:add_link(venous_blood_dv)

            -- ABG Subheadings
            if high_arterial_blood_co2_dv then
                for _, entry in ipairs(high_arterial_blood_co2_dv) do
                    pco2_header:add_link(entry)
                end
            end
            if pao28o_dv then
                for _, entry in ipairs(pao28o_dv) do
                    pao2_header:add_link(entry)
                end
            end

            -- Caluculated Ratio
            if pa_o2_calc then
                for _, entry in ipairs(pa_o2_calc) do
                    if entry.sequence == 8 then
                        calculated_po2_fio2_header:add_text_link(
                            "Verify the Calculated PF ratio, as it's generated by a computer " ..
                            "calculation and requires verification."
                        )
                        calculated_po2_fio2_header:add_link(entry)
                    elseif entry.sequence == 2 then
                        abg_header:add_link(entry)
                    end
                end
                if sp_o2_pa_o2_dvs then
                    calculated_po2_fio2_header:add_link(sp_o2_pa_o2_dvs)
                elseif sp_o2_pa_o2_dvs then
                    for _, entry in ipairs(sp_o2_pa_o2_dvs) do
                        if entry.sequence == 0 then
                            oxygenation_indicators_header:add_link(entry)
                        end
                        if entry.sequence == 2 then
                            pao2_header:add_link(entry)
                        elseif entry.sequence == 1 then
                            spo2_header:add_link(entry)
                        elseif entry.sequence == 3 then
                            oxygenation_ventilation_header:add_link(entry)
                        elseif entry.sequence == 4 then
                            rr_header:add_link(entry)
                        end
                    end
                end
            end
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

