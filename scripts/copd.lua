---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - COPD
---
--- This script checks an account to see if it matches the criteria for a COPD alert.
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
local dv_mrsa_screen = { "MRSA DNA" }
local dv_sars_covid = { "SARS-CoV2 (COVID-19)" }
local dv_sars_covid_antigen = { "" }
local dv_pneumococcal_antigen = { "" }
local dv_influenze_screen_a = { "Influenza A" }
local dv_influenze_screen_b = { "Influenza B" }
local dv_breath_sounds = { "" }
local dv_oxygen_therapy = { "DELIVERY" }
local dv_respiratory_pattern = { "" }
local dv_fi_o2 = { "FI02" }
local dv_heart_rate = { "Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)", "3.5 Heart Rate (Radial) (bpm)", "SCC Monitor Pulse (bpm)" }
local calc_heart_rate1 = function(dv_, num) return num > 90 end
local dv_oxygen_flow_rate = { "Oxygen Flow Rate (L/min)" }
local calc_oxygen_flow_rate1 = function(dv_, num) return num > 2 end
local dv_pa_o2 = { "BLD GAS O2 (mmHg)", "PO2 (mmHg)" }
local calc_pa_o2_1 = function(dv_, num) return num < 60 end
local dv_pa_o2_fi_o2 = { "PO2/FiO2 (mmHg)" }
local calc_pa_o2_fi_o2_1 = 300
local dv_pleural_fluid_culture = { "" }
local dv_respiratory_rate = { "3.5 Respiratory Rate (#VS I&O) (per Minute)" }
local calc_respiratory_rate1 = function(dv_, num) return num > 20 end
local dv_sp_o2 = { "Pulse Oximetry(Num) (%)" }
local calc_sp_o2_1 = function(dv_, num) return num < 90 end
local dv_sputum_culture = { "" }



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
local existing_alert = alerts.get_existing_cdi_alert { scriptName = Result.script_name }
local subtitle = existing_alert and existing_alert.subtitle or nil
local link_text_1 = "Possible Missing Signs of Low Oxygen"
local link_text_2 = "Possible Missing Signs of Respiratory Distress"
local link_text_1_found = false
local link_text_2_found = false

if existing_alert then
    for _, lnk in ipairs(existing_alert.links) do
        if lnk.link_text == link_text_1 then
            link_text_1_found = true
        elseif lnk.link_text == link_text_2 then
            link_text_2_found = true
        end
    end
end



if not existing_alert or not existing_alert.validated then
    --------------------------------------------------------------------------------
    --- Header Variables and Helper Functions
    --------------------------------------------------------------------------------
    local result_links = {}
    local documented_dx_header = headers.make_header_builder("Documented Dx", 1)
    local vital_signs_intake_header = headers.make_header_builder("Vital Signs/Intake", 2)
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 3)
    local oxygenation_ventilation_header = headers.make_header_builder("Oxygenation/Ventilation", 4)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 5)
    local calculated_po2_fio2_header = headers.make_header_builder("Calculated PaO2/FiO2", 6)
    local o2_indicators_header = headers.make_header_builder("O2 Indicators", 7)
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 8)
    local chest_x_ray_header = headers.make_header_builder("Chest X-Ray", 9)

    local pa_o2_header = headers.make_header_builder("PaO2", 13)
    local sp_o2_header = headers.make_header_builder("SpO2", 12)
    local oxygen_therapy_header = headers.make_header_builder("Oxygen Therapy", 17)
    local respiratory_rate_header = headers.make_header_builder("Respiratory Rate", 15)
    local pa_o2_fi_o2_header = headers.make_header_builder("PaO2/FiO2", 11)

    local function compile_links()
        o2_indicators_header:add_link(pa_o2_header:build(true))
        o2_indicators_header:add_link(sp_o2_header:build(true))
        o2_indicators_header:add_link(oxygen_therapy_header:build(true))
        o2_indicators_header:add_link(respiratory_rate_header:build(true))

        laboratory_studies_header:add_link(o2_indicators_header:build(true))

        calculated_po2_fio2_header:add_link(pa_o2_fi_o2_header:build(true))

        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, oxygenation_ventilation_header:build(true))
        table.insert(result_links, vital_signs_intake_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))
        table.insert(result_links, calculated_po2_fio2_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, chest_x_ray_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Negations
    local opioid_overdose_abs = links.get_abstraction_link { code = "OPIOID_OVERDOSE", text = "Opioid Overdose" }
    local heart_failure_code_check = links.get_code_link {
        codes = { "I50.21", "I50.23", "I50.31", "I50.33", "I50.41", "I50.43" },
        text = "Acute Heart Failure Codes present"
    }
    local j440_code = links.get_code_link {
        code = "J44.0",
        text = "Chronic Obstructive Pulmonary Disease With (Acute) Lower Respiratory Infection"
    }
    local j441_code = links.get_code_link {
        code = "J44.1",
        text = "Chronic Obstructive Pulmonary Disease With (Acute) Exacerbation"
    }
    local pulmonary_embolism_neg = codes.get_code_prefix_link { prefix = "I26%.", text = "Pulmonary Embolism" }
    local j810_code = links.get_code_link { code = "J81.0", text = "Acute Pulmonary Edema" }
    local sepsis40_neg = codes.get_code_prefix_link { prefix = "A40%.", text = "Sepsis" }
    local sepsis41_neg = codes.get_code_prefix_link { prefix = "A41%.", text = "Sepsis" }
    local sepsis_neg = links.get_code_link {
        codes = { "A42.7", "A22.7", "B37.7", "A26.7", "A54.86", "B00.7", "A32.7", "A24.1", "A20.7", "T81.44XA", "T81.44XD" },
        text = "Sepsis"
    }
    local f410_code = links.get_code_link { code = "F41.0", text = "Panic Attack" }
    local pneumonthroax_neg = codes.get_code_prefix_link { prefix = "J93%.", text = "Pneumothroax" }
    local acute_mi_neg = codes.get_code_prefix_link { prefix = "I21%.", text = "Acute MI" }
    local copd_without_exacerbation_abs = links.get_abstraction_link {
        code = "COPD_WITHOUT_EXACERBATION",
        text = "COPD without Exacerbation abstraction"
    }

    -- Documented Dx
    local respiratory_code_check = links.get_code_link {
        codes = { "J96.00", "J96.01", "J96.02" },
        text = "Acute Respiratory Failure Codes present"
    }
    local j449_code = links.get_code_link {
        code = "J44.9",
        text = "Chronic Obstructive Pulmonary Disease, Unspecified"
    }
    local j20_codes = codes.get_code_prefix_link { prefix = "J20%.", text = "Acute Bronchitis" }
    local j22_codes = codes.get_code_prefix_link {
        prefix = "J22%.",
        text = "Unspecified Acute Lower Respiratory Infection"
    }
    local pneumonia_j12 = codes.get_code_prefix_link { prefix = "J12%.", text = "Pneumonia" }
    local pneumonia_j13 = codes.get_code_prefix_link { prefix = "J13%.", text = "Pneumonia" }
    local pneumonia_j14 = codes.get_code_prefix_link { prefix = "J14%.", text = "Pneumonia" }
    local pneumonia_j15 = codes.get_code_prefix_link { prefix = "J15%.", text = "Pneumonia" }
    local pneumonia_j16 = codes.get_code_prefix_link { prefix = "J16%.", text = "Pneumonia" }
    local pneumonia_j17 = codes.get_code_prefix_link { prefix = "J17%.", text = "Pneumonia" }
    local pneumonia_j18 = codes.get_code_prefix_link { prefix = "J18%.", text = "Pneumonia" }
    local respiratory_tuberculosis = codes.get_code_prefix_link { prefix = "A15%.", text = "Respiratory Tuberculosis" }
    local j21_codes = codes.get_code_prefix_link { prefix = "J21%.", text = "Acute Bronchitis" }

    -- Clinical Evidence
    local r0603_code = links.get_code_link { code = "R06.03", text = "Acute Respiratory Distress" }
    local j9801_code = links.get_code_link { code = "J98.01", text = "Bronchospasm" }
    local shortness_of_breath_abs = links.get_abstraction_link { code = "SHORTNESS_OF_BREATH", text = "Shortness of Breath" }
    local use_of_accessory_muscles_abs = links.get_abstraction_link { code = "USE_OF_ACCESSORY_MUSCLES", text = "Use of Accessory Muscles" }
    local wheezing_abs = links.get_abstraction_link { code = "WHEEZING", text = "Wheezing" }

    -- Meds
    local bronchodilator_med = links.get_medication_link { cat = "Bronchodilator", text = "Bronchodilator" }
    local inhaled_corticosteriod_med = links.get_medication_link { cat = "Inhaled Corticosteroid", text = "Inhaled Corticosteroid" }
    local inhaled_corticosteriod_treatmeants_abs = links.get_abstraction_link {
        code = "INHALED_CORTICOSTERIOD_TREATMENTS",
        text = "Inhaled Corticosteriod Treatmeants"
    }
    local respiratory_treatment_medication_med = links.get_medication_link {
        cat = "Respiratory Treatment Medication",
        text = "Respiratory Treatment Medication"
    }
    local respiratory_treatment_medication_abs = links.get_abstraction_link {
        code = "RESPIRATORY_TREATMENT_MEDICATION",
        text = "Respiratory Treatment Medication"
    }

    -- Oxygen
    local high_flow_nasal_codes = links.get_code_link {
        codes = { "5A0935A", "5A0945A", "5A0955A" },
        text = "High Flow Nasal Oxygen"
    }
    local invasive_mech_vent_codes = links.get_code_link {
        codes = { "5A1935Z", "5A1945Z", "5A1955Z" },
        text = "Invasive Mechanical Ventilation"
    }
    local non_invasive_vent_abs = links.get_abstraction_link { code = "NON_INVASIVE_VENTILATION", text = "Non-Invasive Ventilation" }
    local oxygen_flow_rate_dv = links.get_discrete_value_link {
        dv = dv_oxygen_flow_rate,
        text = "Oxygen Flow Rate",
        calculation = calc_oxygen_flow_rate1
    }
    local oxygen_therapy_abs = links.get_abstraction_link { code = "OXYGEN_THERAPY", text = "Oxygen Therapy" }

    -- Vital Signs
    local r0902_code = links.get_code_link { code = "R09.02", text = "Hypoxemia" }
    local low_pa_o2_dv = links.get_discrete_value_link {
        dv = dv_pa_o2,
        text = "pa02",
        calculation = calc_pa_o2_1
    }
    local low_pulse_oximetry_dv = links.get_discrete_value_link {
        dv = dv_sp_o2,
        text = "Sp02",
        calculation = calc_sp_o2_1
    }
    local high_respiratory_rate_dv = links.get_discrete_value_link {
        dv = dv_respiratory_rate,
        text = "Respiratory Rate",
        calculation = calc_respiratory_rate1
    }

    -- Calculated PaO2/FiO2
    local z9981_code = links.get_code_link { code = "Z99.81", text = "Dependence On Supplemental Oxygen" }
    --- @type CdiAlertLink[]
    local pa_o2_fi_o2_ratio_links = {}
    --- @type CdiAlertLink[]
    local spo2_pao2_dv_links = {}

    if not z9981_code then
        pa_o2_fi_o2_ratio_links = get_pa_o2_fi_o2_links()
    end
    if not pa_o2_fi_o2_ratio_links then
        spo2_pao2_dv_links = get_pa_o2_sp_o2_links()
    end

    -- COPD Exacerbation Treatment Medication
    local rtma =
        (respiratory_treatment_medication_abs and 1 or 0) +
        (inhaled_corticosteriod_treatmeants_abs and 1 or 0) +
        (respiratory_treatment_medication_med and 1 or 0) +
        (bronchodilator_med and 1 or 0) +
        (inhaled_corticosteriod_med and 1 or 0)
    treatment_and_monitoring_header:add_link(respiratory_treatment_medication_abs)

    -- Signs of Low Oxygen
    local slo =
        (pa_o2_fi_o2_ratio_links and 1 or 0) +
        (low_pa_o2_dv and 1 or 0) +
        (r0902_code and 1 or 0) +
        (low_pulse_oximetry_dv and 1 or 0)
    laboratory_studies_header:add_link(low_pa_o2_dv)
    vital_signs_intake_header:add_link(r0902_code)
    vital_signs_intake_header:add_link(low_pulse_oximetry_dv)

    -- Signs of Resp Distress
    local srd =
        (wheezing_abs and 1 or 0) +
        (use_of_accessory_muscles_abs and 1 or 0) +
        (shortness_of_breath_abs and 1 or 0) +
        (r0603_code and 1 or 0) +
        (high_respiratory_rate_dv and 1 or 0) +
        (j9801_code and 1 or 0)
    clinical_evidence_header:add_link(wheezing_abs)
    clinical_evidence_header:add_link(use_of_accessory_muscles_abs)
    clinical_evidence_header:add_link(shortness_of_breath_abs)
    clinical_evidence_header:add_link(r0603_code)
    vital_signs_intake_header:add_link(high_respiratory_rate_dv)
    clinical_evidence_header:add_link(j9801_code)

    -- Oxygen Delievery Check
    local odc =
        (high_flow_nasal_codes and 1 or 0) +
        (invasive_mech_vent_codes and 1 or 0) +
        (non_invasive_vent_abs and 1 or 0) +
        (oxygen_flow_rate_dv and 1 or 0) +
        (oxygen_therapy_abs and 1 or 0)




    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if subtitle == "Possible Chronic Obstructive Pulmonary Disease with Acute Lower Respiratory Infection" and j440_code then
        if j440_code then
            j440_code.link_text = "Autoresolved Specified Code - " .. j440_code.link_text
            documented_dx_header:add_link(j440_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
    elseif
        j449_code and (
            j20_codes or
            j22_codes or
            pneumonia_j12 or
            pneumonia_j13 or
            pneumonia_j14 or
            pneumonia_j15 or
            pneumonia_j16 or
            pneumonia_j17 or
            pneumonia_j18 or
            j21_codes
        ) and not j440_code
    then
        Result.subtitle = "Possible Chronic Obstructive Pulmonary Disease with Acute Lower Respiratory Infection"
        Result.passed = true
        documented_dx_header:add_link(j449_code)
        documented_dx_header:add_link(j20_codes)
        documented_dx_header:add_link(j22_codes)
        documented_dx_header:add_link(j21_codes)
        documented_dx_header:add_link(pneumonia_j12)
        documented_dx_header:add_link(pneumonia_j13)
        documented_dx_header:add_link(pneumonia_j14)
        documented_dx_header:add_link(pneumonia_j15)
        documented_dx_header:add_link(pneumonia_j16)
        documented_dx_header:add_link(pneumonia_j17)
        documented_dx_header:add_link(pneumonia_j18)
        documented_dx_header:add_link(respiratory_tuberculosis)
    elseif subtitle == "Possible Chronic Obstructive Pulmonary Disease with Acute Exacerbation" and j441_code then
        if j441_code then
            j441_code.link_text = "Autoresolved Specified Code - " .. j441_code.link_text
            documented_dx_header:add_link(j441_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
    elseif
        j449_code and
        respiratory_code_check and
        not opioid_overdose_abs and
        not j441_code and
        not pulmonary_embolism_neg and
        not j810_code and
        not sepsis40_neg and
        not sepsis41_neg and
        not sepsis_neg and
        not f410_code and
        not pneumonthroax_neg and
        not heart_failure_code_check and
        not acute_mi_neg and
        not copd_without_exacerbation_abs and
        (
            bronchodilator_med or
            respiratory_treatment_medication_med or
            respiratory_treatment_medication_abs or
            inhaled_corticosteriod_med or
            inhaled_corticosteriod_treatmeants_abs
        )
    then
        Result.subtitle = "Possible Chronic Obstructive Pulmonary Disease with Acute Exacerbation"
        Result.passed = true
        documented_dx_header:add_link(j449_code)
        documented_dx_header:add_link(respiratory_code_check)
    elseif
        j449_code and
        slo > 0 and
        srd > 0 and
        rtma > 0 and
        odc > 0 and
        not opioid_overdose_abs and
        not pulmonary_embolism_neg and
        not j810_code and
        not sepsis40_neg and
        not sepsis41_neg and
        not sepsis_neg and
        not f410_code and
        not pneumonthroax_neg and
        not heart_failure_code_check and
        not acute_mi_neg and
        not copd_without_exacerbation_abs and
        not j441_code
    then
        Result.subtitle = "Possible Chronic Obstructive Pulmonary Disease with Acute Exacerbation"
        Result.passed = true
        documented_dx_header:add_link(j449_code)
    elseif subtitle == "COPD with Acute Exacerbation Possibly Lacking Supporting Evidence" and slo > 0 and srd > 0 and rtma > 0 then
        if link_text_1_found and slo > 0 then
            vital_signs_intake_header:add_link(links.make_header_link(link_text_1))
        end
        if link_text_2_found and srd > 0 then
            clinical_evidence_header:add_link(links.make_header_link(link_text_2))
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.validated = true
        Result.passed = true
    elseif j441_code and slo < 1 and srd < 1 and rtma > 0 then
        if slo < 1 then
            vital_signs_intake_header:add_link(links.make_header_link(link_text_1))
        elseif link_text_1_found and slo > 0 then
            vital_signs_intake_header:add_link(links.make_header_link(link_text_1, false))
        end
        if srd < 1 then
            clinical_evidence_header:add_link(links.make_header_link(link_text_2))
        elseif link_text_2_found and srd > 0 then
            clinical_evidence_header:add_link(links.make_header_link(link_text_2, false))
        end
        Result.subtitle = "COPD with Acute Exacerbation Possibly Lacking Supporting Evidence"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        -- Vitals
        vital_signs_intake_header:add_discrete_value_one_of_link(dv_heart_rate, "HR", calc_heart_rate1)

        -- Clinical Evidence
        clinical_evidence_header:add_abstraction_link("ABNORMAL_SPUTUM", "Abnormal Sputum")
        clinical_evidence_header:add_discrete_value_one_of_link(
            dv_breath_sounds,
            "Breath Sounds",
            function(dv, num_) return not string.match(dv.result, "clear") end
        )
        clinical_evidence_header:add_code_one_of_link(
            { "J96.01", "J96.2", "J96.21", "J96.22" },
            "Acute Respiratory Failure"
        )
        clinical_evidence_header:add_link(j9801_code)
        clinical_evidence_header:add_abstraction_link("BRONCHOSPASM", "Bronchospasm")
        clinical_evidence_header:add_code_link("R05.9", "Cough")
        clinical_evidence_header:add_code_link("U07.1", "Covid-19")
        clinical_evidence_header:add_code_link("R53.83", "Fatigue")
        clinical_evidence_header:add_abstraction_link("LOW_FORCED_EXPIRATORY_VOLUME_1", "Low Forced Expiratory Volume 1")
        clinical_evidence_header:add_abstraction_link("BACTERIAL_PNEUMONIA_ORGANISM", "Possible Bacterial Pneumonia Organism")
        clinical_evidence_header:add_abstraction_link("FUNGAL_PNEUMONIA_ORGANISM", "Possible Fungal Pneumonia Organism")
        clinical_evidence_header:add_abstraction_link("VIRAL_PNEUMONIA_ORGANISM", "Possible Viral Pneumonia Organism")
        clinical_evidence_header:add_discrete_value_one_of_link(
            dv_respiratory_pattern,
            "Respiratory Pattern",
            function(dv, num_) return not string.match(dv.result, "regular") end
        )

        -- Document Links
        chest_x_ray_header:add_document_link("Chest  3 View", "Chest  3 View")
        chest_x_ray_header:add_document_link("Chest  PA and Lateral", "Chest  PA and Lateral")
        chest_x_ray_header:add_document_link("Chest  Portable", "Chest  Portable")
        chest_x_ray_header:add_document_link("Chest PA and Lateral", "Chest PA and Lateral")
        chest_x_ray_header:add_document_link("Chest  1 View", "Chest  1 View")

        -- Labs
        laboratory_studies_header:add_discrete_value_one_of_link(
            dv_mrsa_screen,
            "MRSA Screen",
            function(dv, num_) return string.match(dv.result, "positive") or string.match(dv.result, "detected") end
        )
        laboratory_studies_header:add_discrete_value_one_of_link(
            dv_sars_covid,
            "Covid 19 Screen",
            function(dv, num_) return string.match(dv.result, "positive") or string.match(dv.result, "detected") end
        )
        laboratory_studies_header:add_discrete_value_one_of_link(
            dv_sars_covid_antigen,
            "Covid 19 Screen",
            function(dv, num_) return string.match(dv.result, "positive") or string.match(dv.result, "detected") end
        )
        laboratory_studies_header:add_discrete_value_one_of_link(
            dv_pneumococcal_antigen,
            "Strept Pneumonia Screen",
            function(dv, num_) return string.match(dv.result, "positive") or string.match(dv.result, "detected") end
        )
        laboratory_studies_header:add_discrete_value_one_of_link(
            dv_influenze_screen_a,
            "Influenza A Screen",
            function(dv, num_) return string.match(dv.result, "positive") or string.match(dv.result, "detected") end
        )
        laboratory_studies_header:add_discrete_value_one_of_link(
            dv_influenze_screen_b,
            "Influenza B Screen",
            function(dv, num_) return string.match(dv.result, "positive") or string.match(dv.result, "detected") end
        )
        laboratory_studies_header:add_discrete_value_one_of_link(
            dv_pleural_fluid_culture,
            "Pleural Fluid Culture",
            function(dv, num_) return string.match(dv.result, "positive") end
        )
        laboratory_studies_header:add_abstraction_link("POSITIVE_PLEURAL_FLUID_CULTURE", "Positive Pleural Fluid Culture")
        laboratory_studies_header:add_discrete_value_one_of_link(
            dv_sputum_culture,
            "Sputum Culture",
            function(dv, num_) return string.match(dv.result, "positive") end
        )
        laboratory_studies_header:add_abstraction_link("POSITIVE_SPUTUM_CULTURE", "Positive Sputum Culture")

        -- Oxygen
        oxygenation_ventilation_header:add_link(high_flow_nasal_codes)
        oxygenation_ventilation_header:add_link(invasive_mech_vent_codes)
        oxygenation_ventilation_header:add_link(non_invasive_vent_abs)
        oxygenation_ventilation_header:add_link(oxygen_flow_rate_dv)
        oxygenation_ventilation_header:add_discrete_value_one_of_link(
            dv_oxygen_therapy,
            "Oxygen Therapy",
            function(dv, num_)
                return not string.match(dv.result, "room air") and not string.match(dv.result, "RA")
            end
        )
        oxygenation_ventilation_header:add_link(oxygen_therapy_abs)

        -- Meds
        treatment_and_monitoring_header:add_medication_link("Antibiotic", "Antibiotic")
        treatment_and_monitoring_header:add_abstraction_link("ANTIBIOTIC", "Antibiotic")
        treatment_and_monitoring_header:add_link(bronchodilator_med)
        treatment_and_monitoring_header:add_medication_link("Dexamethasone", "Dexamethasone")
        treatment_and_monitoring_header:add_link(inhaled_corticosteriod_med)
        treatment_and_monitoring_header:add_link(inhaled_corticosteriod_treatmeants_abs)
        treatment_and_monitoring_header:add_medication_link("Methylprednisolone", "Methylprednisolone")
        treatment_and_monitoring_header:add_link(respiratory_treatment_medication_abs)
        treatment_and_monitoring_header:add_link(respiratory_treatment_medication_med)
        treatment_and_monitoring_header:add_medication_link("Steroid", "Steroid")
        treatment_and_monitoring_header:add_abstraction_link("STEROIDS", "Steroid")
        treatment_and_monitoring_header:add_medication_link("Vasodilator", "Vasodilator")

        if pa_o2_fi_o2_ratio_links then
            for _, entry in ipairs(pa_o2_fi_o2_ratio_links) do
                if entry.sequence == 8 then
                    calculated_po2_fio2_header:add_text_link(
                        "Verify the Calculated PF ratio, " ..
                        "as it's generated by a computer calculation and requires verification"
                    )
                    calculated_po2_fio2_header:add_link(entry)
                elseif entry.sequence == 2 then
                    oxygenation_ventilation_header:add_link(entry)
                end
            end
        elseif spo2_pao2_dv_links then
            for _, entry in ipairs(spo2_pao2_dv_links) do
                if entry.sequence == 0 then
                    oxygenation_ventilation_header:add_link(entry)
                elseif entry.sequence == 2 then
                    pa_o2_header:add_link(entry)
                elseif entry.sequence == 1 then
                    sp_o2_header:add_link(entry)
                elseif entry.sequence == 3 then
                    oxygen_therapy_header:add_link(entry)
                elseif entry.sequence == 4 then
                    respiratory_rate_header:add_link(entry)
                end
            end
        end

        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

