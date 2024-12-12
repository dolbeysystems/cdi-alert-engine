---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - COPD
---
--- This script checks an account to see if it matches the criteria for a COPD alert.
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
local calc_heart_rate1 = function(dv, num) return num > 90 end
local dv_oxygen_flow_rate = { "Oxygen Flow Rate (L/min)" }
local calc_oxygen_flow_rate1 = function(dv, num) return num > 2 end
local dv_pa_o2 = { "BLD GAS O2 (mmHg)", "PO2 (mmHg)" }
local calc_pa_o2_1 = function(dv, num) return num < 60 end
local dv_pa_o2_fi_o2 = { "PO2/FiO2 (mmHg)" }
local calc_pa_o2_fi_o2_1 = 300
local dv_pa_op = { "" }
local calc_pa_op_1 = function(dv, num) return num > 18 end
local dv_pleural_fluid_culture = { "" }
local dv_respiratory_rate = { "3.5 Respiratory Rate (#VS I&O) (per Minute)" }
local calc_respiratory_rate1 = function(dv, num) return num > 20 end
local dv_sp_o2 = { "Pulse Oximetry(Num) (%)" }
local calc_sp_o2_1 = function(dv, num) return num < 90 end
local dv_sputum_culture = { "" }



--------------------------------------------------------------------------------
--- Script Functions
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--- Get the links for PaO2/FiO2, through various attempts
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
        -- Method #1 - Look for calculated discrete values
        pa_o2_fi_o2_ratio_links = links.get_discrete_value_links {
            discreteValueNames = dv_pa_o2_fi_o2,
            text = "PaO2/FiO2",
            predicate = function(dv, num)
                return dates.date_is_less_than_x_days_ago(dv.result_date, 1) and num < 300
            end
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
            local date = oxygen_pair.first.result_date
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
            local date = oxygen_pair.first.result_date
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
    local function create_link(date_time, link_text, result, id)
        local link = cdi_alert_link()

        if date_time then
            link_text = link_text.replace("[RESULTDATETIME]", date_time)
        else
            link_text = link_text.replace("(Result Date: [RESULTDATETIME])", "")
        end
        if result then
            link_text = link_text.replace("[VALUE]", result)
        else
            link_text = link_text.replace("[VALUE]", "")
        end
        link.link_text = link_text
        link.discrete_value_id = id
        return link
    end

    -- DV1     DV2     DV3              DV4
    -- dvSPO2, dvPaO2, dvOxygenTherapy, dvRespiratoryRate
    -- w       x       y                z
    local discrete_dic_1 = {}
    local discrete_dic_2 = {}
    local discrete_dic_3 = {}
    local discrete_dic_4 = {}
    local link_text1 = "sp02: [VALUE] (Result Date: [RESULTDATETIME])"
    local link_text2 = "pa02: [VALUE] (Result Date: [RESULTDATETIME])"
    local link_text3 = "Oxygen Therapy '[VALUE]' (Result Date: [RESULTDATETIME])"
    local link_text4 = "Respiratory Rate: [VALUE] (Result Date: [RESULTDATETIME])"
    local rr_dv = nil
    local date_limit = os.time() - 86400
    local ot_dv = nil
    local sp_dv = nil
    local pa_dv = nil
    local matching_date = nil
    local oxygen_value = nil
    local resp_rate_dv = nil
    local matched_list = {}

    discrete_dic_1 = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_sp_o2,
        predicate = function(dv)
            return dates.date_string_to_int(dv.result_date) >= date_limit and discrete.get_dv_value_number(dv) < 91
        end
    }

    discrete_dic_2 = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_pa_o2,
        predicate = function(dv)
            return dates.date_string_to_int(dv.result_date) >= date_limit and discrete.get_dv_value_number(dv) <= 60
        end
    }

    discrete_dic_3 = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_oxygen_therapy,
        predicate = function(dv)
            return dates.date_string_to_int(dv.result_date) >= date_limit and dv.result ~= nil
        end
    }

    discrete_dic_4 = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_respiratory_rate,
        predicate = function(dv)
            return dates.date_string_to_int(dv.result_date) >= date_limit and discrete.get_dv_value_number(dv) ~= nil
        end
    }

    if #discrete_dic_2 > 0 then
        for idx, item in discrete_dic_2 do
            matching_date = dates.date_string_to_int(item.result_date)
            pa_dv = idx
            if #discrete_dic_3 > 0 then
                for idx2, item2 in discrete_dic_3 do
                    if dates.date_string_to_int(item.result_date) == dates.date_string_to_int(item2.result_date) then
                        matching_date = dates.date_string_to_int(item.result_date)
                        ot_dv = idx2
                        oxygen_value = item2.result
                        break
                    end
                end
            else
                oxygen_value = "XX"
            end
            if #discrete_dic_4 > 0 then
                for idx3, item3 in discrete_dic_4 do
                    if dates.date_string_to_int(item3.result_date) == matching_date then
                        rr_dv = idx3
                        resp_rate_dv = item3.result
                        break
                    end
                end
            else
                resp_rate_dv = "XX"
            end

            matching_date = dates.date_int_to_string(matching_date)
            table.insert(
                matched_list,
                create_link(
                    nil,
                    matching_date .. " Respiratory Rate: " .. resp_rate_dv .. ", Oxygen Therapy: " .. oxygen_value ..
                    ", pa02: " .. discrete_dic_2[pa_dv].result,
                    nil,
                    discrete_dic_2[pa_dv].unique_id
                )
            )
            table.insert(
                matched_list,
                create_link(
                    discrete_dic_2[pa_dv].result_date,
                    link_text2,
                    discrete_dic_2[pa_dv].result,
                    discrete_dic_2[pa_dv].unique_id
                )
            )
            if ot_dv then
                table.insert(
                    matched_list,
                    create_link(
                        discrete_dic_3[ot_dv].result_date,
                        link_text3,
                        discrete_dic_3[ot_dv].result,
                        discrete_dic_3[ot_dv].unique_id
                    )
                )
            end
            if rr_dv then
                table.insert(
                    matched_list,
                    create_link(
                        discrete_dic_4[rr_dv].result_date,
                        link_text4,
                        discrete_dic_4[rr_dv].result,
                        discrete_dic_4[rr_dv].unique_id
                    )
                )
            end
        end
        return matched_list
    elseif #discrete_dic_1 > 0 then
        --[[
        for item in discreteDic1:
            matchingDate = discreteDic1[item].ResultDate
            spDv = item
            if y > 0:
                for item2 in discreteDic3:
                    if discreteDic1[item].ResultDate == discreteDic3[item2].ResultDate:
                        otDv = item2
                        oxygenValue = discreteDic3[item2].Result
                        break
            else:
                oxygenValue = "XX" 
            if z > 0:
                for item3 in discreteDic4:
                    if discreteDic4[item3].ResultDate == discreteDic1[item].ResultDate:
                        rrDV = item3
                        respRateDV = discreteDic4[item3].Result
                        break
            else:
                respRateDV = "XX"
            matchingDate = datetimeFromUtcToLocal(matchingDate)
            matchingDate = matchingDate.ToString("MM/dd/yyyy, HH:mm")
            matchedList.append(dataConversion(None, matchingDate + " Respiratory Rate: " + str(respRateDV) + ", Oxygen Therapy: " + str(oxygenValue) + ", sp02: " + str(discreteDic1[spDv].Result), None, discreteDic1[spDv].UniqueId or discreteDic1[spDv]._id, oxygenation, 0, False))
            matchedList.append(dataConversion(discreteDic1[spDv].ResultDate, linkText1, discreteDic1[spDv].Result, discreteDic1[spDv].UniqueId or discreteDic1[spDv]._id, spo2, 1, False))
            if otDv is not None:
                matchedList.append(dataConversion(discreteDic3[otDv].ResultDate, linkText3, discreteDic3[otDv].Result, discreteDic3[otDv].UniqueId or discreteDic3[otDv]._id, oxygenTherapy, 5, False))
            if rrDV is not None:
                matchedList.append(dataConversion(discreteDic4[rrDV].ResultDate, linkText4, discreteDic4[rrDV].Result, discreteDic4[rrDV].UniqueId or discreteDic4[rrDV]._id, rr, 7, False))
        db.LogEvaluationScriptMessage("SPO2 log message: SPO2 Found matches" + str(w) + ", PAO2 Found Matches: " + str(x)
            + ", Oxygen Therapy Found Matches: " + str(y) + ", Respiratory Found Matchs: " + str(z) + ", Matching Date: " + str(matchingDate) + " " 
            + str(account._id), scriptName, scriptInstance, "Debug")
        return matchedList
        --]]
    else
        return {}
    end
end



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }
local subtitle = existing_alert and existing_alert.subtitle or nil
local link_text_1 = "Possible Missing Signs of Low Oxygen"
local link_text_2 = "Possible Missing Signs of Respiratory Distress"
local link_text_3 = "Possible Missing COPD Exacerbation Treatment Medication"
local link_text_1_found = false
local link_text_2_found = false
local link_text_3_found = false

if existing_alert then
    for _, lnk in ipairs(existing_alert.links) do
        if lnk.link_text == link_text_1 then
            link_text_1_found = true
        elseif lnk.link_text == link_text_2 then
            link_text_2_found = true
        elseif lnk.link_text == link_text_3 then
            link_text_3_found = true
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
    local spo2_header = headers.make_header_builder("SpO2", 10)
    local pa_o2_fi_o2_header = headers.make_header_builder("PaO2/FiO2", 11)
    local spo22_header = headers.make_header_builder("SpO2", 12)
    local pa_o2_header = headers.make_header_builder("PaO2", 13)
    local fi_o2_header = headers.make_header_builder("FiO2", 14)
    local respiratory_rate_header = headers.make_header_builder("Respiratory Rate", 15)
    local oxygen_flow_rate_header = headers.make_header_builder("Oxygen Flow Rate", 16)
    local oxygen_therapy_header = headers.make_header_builder("Oxygen Therapy", 17)

    local function compile_links()
        -- TODO: Unclear at this point how the child link headers are composed
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
    --- Alert Variables 
    --------------------------------------------------------------------------------
    local alert_code_dictionary = {

    }
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)



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
        -- TODO: and now this!
        spo2_pao2_dv_links = get_pa_o2_sp_o2_links()
    end

    --[[
    #Copd Exacerbation Treatment Medication
    if respiratoryTreatmentMedicationAbs is not None: meds.Links.Add(respiratoryTreatmentMedicationAbs); RTMA += 1
    if inhaledCorticosteriodTreatmeantsAbs is not None: RTMA += 1
    if respiratoryTreatmentMedicationMed is not None: RTMA += 1
    if bronchodilatorMed is not None: RTMA += 1
    if inhaledCorticosteriodMed is not None: RTMA += 1
    #Signs of Low Oxygen
    if pao2Calc is not None: SLO += 1
    if lowPaO2DV is not None: labs.Links.Add(lowPaO2DV); SLO += 1
    if r0902Code is not None: vitals.Links.Add(r0902Code); SLO += 1
    if lowPulseOximetryDV is not None: vitals.Links.Add(lowPulseOximetryDV); SLO += 1
    #Signs of Resp Distress
    if wheezingAbs is not None: abs.Links.Add(wheezingAbs); SRD += 1
    if useOfAccessoryMusclesAbs is not None: abs.Links.Add(useOfAccessoryMusclesAbs); SRD += 1
    if shortnessOfBreathAbs is not None: abs.Links.Add(shortnessOfBreathAbs); SRD += 1
    if r0603Code is not None: abs.Links.Add(r0603Code); SRD += 1
    if highRespiratoryRateDV is not None: vitals.Links.Add(highRespiratoryRateDV); SRD += 1
    if j9801Code is not None: abs.Links.Add(j9801Code); SRD += 1
    #Oxygen Delievery Check
    if highFlowNasalCodes is not None: ODC += 1
    if invasiveMechVentCodes is not None: ODC += 1
    if nonInvasiveVentAbs is not None: ODC += 1
    if oxygenFlowRateDV is not None: ODC += 1
    if oxygenTherapyAbs is not None: ODC += 1
    --]]





    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
--[[
    #Starting Main Algorithm
    if subtitle == "Possible Chronic Obstructive Pulmonary Disease with Acute Lower Respiratory Infection" and j440Code is not None:
        if j440Code is not None: updateLinkText(j440Code, autoCodeText); dc.Links.Add(j440Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
        
    elif (
        j449Code is not None and
        (j20Codes is not None or
        j22Codes is not None or
        pneumoniaJ12 is not None or
        pneumoniaJ13 is not None or
        pneumoniaJ14 is not None or
        pneumoniaJ15 is not None or
        pneumoniaJ16 is not None or
        pneumoniaJ17 is not None or
        pneumoniaJ18 is not None or 
        j21Codes is not None) and
        j440Code is None
        ):
        result.Subtitle = "Possible Chronic Obstructive Pulmonary Disease with Acute Lower Respiratory Infection"
        AlertPassed = True
        dc.Links.Add(j449Code)
        if j20Codes is not None: dc.Links.Add(j20Codes)
        if j22Codes is not None: dc.Links.Add(j22Codes)
        if j21Codes is not None: dc.Links.Add(j21Codes)
        if pneumoniaJ12 is not None: dc.Links.Add(pneumoniaJ12)
        if pneumoniaJ13 is not None: dc.Links.Add(pneumoniaJ13)
        if pneumoniaJ14 is not None: dc.Links.Add(pneumoniaJ14)
        if pneumoniaJ15 is not None: dc.Links.Add(pneumoniaJ15)
        if pneumoniaJ16 is not None: dc.Links.Add(pneumoniaJ16)
        if pneumoniaJ17 is not None: dc.Links.Add(pneumoniaJ17)
        if pneumoniaJ18 is not None: dc.Links.Add(pneumoniaJ18)
        if respiratoryTuberculosis is not None: dc.Links.Add(respiratoryTuberculosis)
    
    elif subtitle == "Possible Chronic Obstructive Pulmonary Disease with Acute Exacerbation" and j441Code is not None:
        if j441Code is not None: updateLinkText(j441Code, autoCodeText); dc.Links.Add(j441Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    
    elif (
        j449Code is not None and
        RespiratoryCodeCheck is not None and
        opioidOverdoseAbs is None and
        j441Code is None and
        pulmonaryEmbolismNeg is None and
        j810Code is None and
        sepsis40Neg is None and
        sepsis41Neg is None and
        sepsisNeg is None and
        f410Code is None and
        pneumonthroaxNeg is None and
        HeartFailureCodeCheck is None and
        acuteMINeg is None and
        copdWithoutExacerbationAbs is None and
        (bronchodilatorMed is not None or
        respiratoryTreatmentMedicationMed is not None or
        respiratoryTreatmentMedicationAbs is not None or
        inhaledCorticosteriodMed is not None or
        inhaledCorticosteriodTreatmeantsAbs is not None)
        ):
        result.Subtitle = "Possible Chronic Obstructive Pulmonary Disease with Acute Exacerbation"
        AlertPassed = True
        dc.Links.Add(j449Code)
        dc.Links.Add(RespiratoryCodeCheck)    
    
    elif (
        j449Code is not None and
        SLO > 0 and
        SRD > 0 and
        RTMA > 0 and
        ODC > 0 and
        opioidOverdoseAbs is None and
        pulmonaryEmbolismNeg is None and
        j810Code is None and
        sepsis40Neg is None and
        sepsis41Neg is None and
        sepsisNeg is None and
        f410Code is None and
        pneumonthroaxNeg is None and
        HeartFailureCodeCheck is None and
        acuteMINeg is None and
        copdWithoutExacerbationAbs is None and
        j441Code is None
    ):
        result.Subtitle = "Possible Chronic Obstructive Pulmonary Disease with Acute Exacerbation"
        AlertPassed = True
        dc.Links.Add(j449Code)
        
    elif subtitle == "COPD with Acute Exacerbation Possibly Lacking Supporting Evidence" and SLO > 0 and SRD > 0 and RTMA > 0:
        if message1 and SLO > 0:
            vitals.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, False))
        if message2 and SRD > 0:
            abs.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None, False))
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to clinical evidence now existing on the Account"
        result.Validated = True
        AlertPassed = True
        
    elif (
        j441Code is not None and
        SLO == 0 and
        SRD == 0 and
        RTMA > 0
    ):
        if SLO < 1: vitals.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None))
        elif message1 and SLO > 0:
            vitals.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, False))
        if SRD < 1: abs.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None))
        elif message2 and SRD > 0:
            abs.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None, False))
        result.Subtitle = "COPD with Acute Exacerbation Possibly Lacking Supporting Evidence"
        AlertPassed = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False
--]]


    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        --[[
        #Abs
        abstractValue("ABNORMAL_SPUTUM", "Abnormal Sputum '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1, abs, True)
        #2
        dvBreathCheck(dict(maindiscreteDic), dvBreathSounds, "Breath Sounds '[VALUE]' (Result Date: [RESULTDATETIME])", 3, abs, True)
        multiCodeValue(["J96.01", "J96.2", "J96.21", "J96.22"], "Acute Respiratory Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, abs, True)
        if j9801Code is not None: abs.Links.Add(j9801Code) #5
        abstractValue("BRONCHOSPASM", "Bronchospasm '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, abs, True)
        codeValue("R05.9", "Cough: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, abs, True)
        codeValue("U07.1", "Covid-19: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, abs, True)
        codeValue("R53.83", "Fatigue: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8, abs, True)
        abstractValue("LOW_FORCED_EXPIRATORY_VOLUME_1", "Low Forced Expiratory Volume 1 '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, abs, True)
        abstractValue("BACTERIAL_PNEUMONIA_ORGANISM", "Possible Bacterial Pneumonia Organism '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10, abs, True)
        abstractValue("FUNGAL_PNEUMONIA_ORGANISM", "Possible Fungal Pneumonia Organism '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11, abs, True)
        abstractValue("VIRAL_PNEUMONIA_ORGANISM", "Possible Viral Pneumonia Organism '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12, abs, True)
        dvRespPatCheck(dict(maindiscreteDic), dvRespiratoryPattern, "Respiratory Pattern '[VALUE]' (Result Date: [RESULTDATETIME])", 13, abs, True)
        #14-17
        #Document Links
        documentLink("Chest  3 View", "Chest  3 View", 0, chestXRayLinks, True)
        documentLink("Chest  PA and Lateral", "Chest  PA and Lateral", 0, chestXRayLinks, True)
        documentLink("Chest  Portable", "Chest  Portable", 0, chestXRayLinks, True)
        documentLink("Chest PA and Lateral", "Chest PA and Lateral", 0, chestXRayLinks, True)
        documentLink("Chest  1 View", "Chest  1 View", 0, chestXRayLinks, True)
        #Labs
        dvPositiveCheck(dict(maindiscreteDic), dvSARSCOVID, "Covid 19 Screen: '[VALUE]' (Result Date: [RESULTDATETIME])", 2, labs, True)
        dvPositiveCheck(dict(maindiscreteDic), dvSARSCOVIDAntigen, "Covid 19 Screen: '[VALUE]' (Result Date: [RESULTDATETIME])", 3, labs, True)
        dvBloodCheck(dict(maindiscreteDic), dvInfluenzeScreenA, "Influenza A Screen: '[VALUE]' (Result Date: [RESULTDATETIME])", 4, labs, True)
        dvBloodCheck(dict(maindiscreteDic), dvInfluenzeScreenB, "Influenza B Screen: '[VALUE]' (Result Date: [RESULTDATETIME])", 5, labs, True)
        dvmrsaCheck(dict(maindiscreteDic), dvMRSASCreen, "Final Report", "MRSA Screen: '[VALUE]' (Result Date: [RESULTDATETIME])", 6, labs, True)
        dvPositiveCheck(dict(maindiscreteDic), dvPleuralFluidCulture, "Positive Pleural Fluid Culture: '[VALUE]' (Result Date: [RESULTDATETIME])", 7)
        abstractValue("POSITIVE_SPUTUM_CULTURE", "Positive Sputum Culture '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, labs, True)
        dvPositiveCheck(dict(maindiscreteDic), dvPneumococcalAntigen, "Strept Pneumonia Screen: '[VALUE]' (Result Date: [RESULTDATETIME])", 9, labs, True)
        #Meds
        medValue("Antibiotic", "Antibiotic: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, meds, True)
        abstractValue("ANTIBIOTIC", "Antibiotic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2, meds, True)
        if bronchodilatorMed is not None: meds.Links.Add(bronchodilatorMed) #3
        medValue("Dexamethasone", "Dexamethasone: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 4, meds, True)
        if inhaledCorticosteriodMed is not None: meds.Links.Add(inhaledCorticosteriodMed) #5
        if inhaledCorticosteriodTreatmeantsAbs is not None: meds.Links.Add(inhaledCorticosteriodTreatmeantsAbs) #6
        medValue("Methylprednisolone", "Methylprednisolone: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 7, meds, True)
        if respiratoryTreatmentMedicationAbs is not None: meds.Links.Add(respiratoryTreatmentMedicationAbs) #8
        if respiratoryTreatmentMedicationMed is not None: meds.Links.Add(respiratoryTreatmentMedicationMed) #9
        #10
        medValue("Steroid", "Steroid: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 11, meds, True)
        abstractValue("STEROIDS", "Steroid '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12, meds, True)
        medValue("Vasodilator", "Vasodilator: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 13, meds, True)
        #Oxygen
        codeValue("Z99.81", "Dependence On Supplemental Oxygen: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, oxygen, True)
        if z9981Code is not None: oxygen.Links.Add(z9981Code) #2
        if highFlowNasalCodes is not None: oxygen.Links.Add(highFlowNasalCodes) #3
        if invasiveMechVentCodes is not None: oxygen.Links.Add(invasiveMechVentCodes) #4
        if nonInvasiveVentAbs is not None: oxygen.Links.Add(nonInvasiveVentAbs) #5
        if oxygenFlowRateDV is not None: oxygen.Links.Add(oxygenFlowRateDV) #6
        dvOxygenCheck(dict(maindiscreteDic), dvOxygenTherapy, "Oxygen Therapy '[VALUE]' (Result Date: [RESULTDATETIME])", 7, oxygen, True)
        if oxygenTherapyAbs is not None: oxygen.Links.Add(oxygenTherapyAbs) #8
        #Vitals
        dvValue(dvHeartRate, "HR: [VALUE] (Result Date: [RESULTDATETIME])", calcHeartRate1, 1, vitals, True)
        #2-5
        #Calculated Ratio
        if pao2Calc is not None:
            for entry in pao2Calc:
                if entry.Sequence == 8:
                    calcpo2fio2.Links.Add(MatchedCriteriaLink("Verify the Calculated PF ratio, as it's generated by a computer calculation and requires verification.", None, None, None, True, None, None, 1))
                    calcpo2fio2.Links.Add(entry)
                elif entry.Sequence == 2:
                    abg.Links.Add(entry)
            if pa02Fi02.Links: calcpo2fio2.Links.Add(pa02Fi02)
        elif sp02pao2Dvs is not None:
            for entry in sp02pao2Dvs:
                if entry.Sequence == 0:
                    oxygenation.Links.Add(entry)
                if entry.Sequence == 2:
                    paO2.Links.Add(entry)
                elif entry.Sequence == 1:
                    spo22.Links.Add(entry)
                elif entry.Sequence == 3:
                    oxygenTherapy.Links.Add(entry)
                elif entry.Sequence == 4:
                    rr.Links.Add(entry)
            if paO2.Links: oxygenation.Links.Add(paO2)
            if spo22.Links: oxygenation.Links.Add(spo22)
            if oxygenTherapy.Links: oxygenation.Links.Add(oxygenTherapy)
            if rr.Links: oxygenation.Links.Add(rr)
        --]]


        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

