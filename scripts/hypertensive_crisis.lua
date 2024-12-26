---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Hypertensive Crisis
---
--- This script checks an account to see if it matches the criteria for a hypertensive crisis alert.
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
local dv_alanine_transaminase = { "ALT", "ALT/SGPT (U/L)	16-61" }
local calc_alanine_transaminase1 = function(dv_, num) return num > 61 end
local dv_aspartate_transaminase = { "AST", "AST/SGOT (U/L)" }
local calc_aspartate_transaminase1 = function(dv_, num) return num > 35 end
local dv_dbp = { "BP Arterial Diastolic cc (mm Hg)", "DBP 3.5 (No Calculation) (mmhg)", "DBP 3.5 (No Calculation) (mm Hg)" }
local calc_dbp1 = function(dv_, num) return num > 120 end
local dv_glasgow_coma_scale = { "3.5 Neuro Glasgow Score" }
local calc_glasgow_coma_scale1 = function(dv_, num) return num < 15 end
local dv_heart_rate = { "Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)", "3.5 Heart Rate (Radial) (bpm)",  "SCC Monitor Pulse (bpm)" }
local dv_map = { "Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)" }
local dv_sbp = { "SBP 3.5 (No Calculation) (mm Hg)" }
local calc_sbp1 = function(dv_, num) return num > 180 end
local dv_serum_blood_urea_nitrogen = { "BUN (mg/dL)" }
local calc_serum_blood_urea_nitrogen1 = function(dv_, num) return num > 23 end
local dv_serum_creatinine = { "CREATININE (mg/dL)", "CREATININE SERUM (mg/dL)" }
local calc_serum_creatinine1 = function(dv_, num) return num > 1.30 end
local dv_serum_lactate = { "Lactate Bld-sCnc (mmol/L)", "LACTIC ACID (SAH) (mmol/L)" }
local calc_serum_lactate1 = function(dv_, num) return num >= 4 end
local dv_troponin_t = { "TROPONIN, HIGH SENSITIVITY (ng/L)" }
local calc_troponin_t1 = function(dv_, num) return num > 59 end
local dv_ts_amphetamine = { "AMP/METH UR", "AMPHETAMINE URINE" }
local dv_ts_cocaine = { "COCAINE URINE", "COCAINE UR CONF" }



--------------------------------------------------------------------------------
--- Header Variables and Helper Functions
--------------------------------------------------------------------------------
local result_links = {}
local documented_dx_header = headers.make_header_builder("Documented Dx", 1)
local alert_trigger_header = headers.make_header_builder("Alert Trigger", 2)
local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 3)
local vital_signs_intake_header = headers.make_header_builder("Vital Signs/Intake", 4)
local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 5)
local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 6)



--------------------------------------------------------------------------------
--- Script Specific Functions
--------------------------------------------------------------------------------
--- @param sbp_dic DiscreteValue[]
--- @param dbp_dic DiscreteValue[]
local function bp_single_line_lookup(sbp_dic, dbp_dic)
    local map_discrete_values = discrete.get_ordered_discrete_values(dv_map)
    local heart_rate_discrete_values = discrete.get_ordered_discrete_values(dv_heart_rate)
    local dbp_dv = nil
    local hr_dv = nil
    local map_dv = nil
    local matching_date = nil
    local h = #heart_rate_discrete_values
    local m = #map_discrete_values
    local matched_list = {}
    local dvr = nil

    for _, item in ipairs(sbp_dic) do
        dbp_dv = nil
        hr_dv = nil
        map_dv = nil
        matching_date = dates.date_string_to_int(item.result_date)
        if m > 0 then
            for _, item1 in map_discrete_values do
                if dates.date_string_to_int(item1.result_date) == matching_date then
                    map_dv = item1.result
                    break
                end
            end
        end
        if h > 0 then
            for _, item2 in heart_rate_discrete_values do
                if dates.date_string_to_int(item2.result_date) == matching_date then
                    hr_dv = item2.result
                    break
                end
            end
        end
        for _, item3 in ipairs(dbp_dic) do
            if dates.date_string_to_int(item3.result_date) == matching_date then
                dbp_dv = item3.result
                break
            end
        end

        if not dbp_dv then dbp_dv = "XX" end
        if not hr_dv then hr_dv = "XX" end
        if not map_dv then map_dv = "XX" end

        local link = cdi_alert_link()
        link.discrete_value_id = item.unique_id
        link.link_text =
            item.result_date .. " HR = " .. hr_dv .. ", BP = " .. item.result .. "/" .. dbp_dv .. ", MAP = " .. map_dv
        vital_signs_intake_header:add_link(link)
    end
end

local function linked_greater_values()
    local value = 80
    local value2 = 120

    local dbp_discrete_values = discrete.get_ordered_discrete_values(dv_dbp)
    local sbp_discrete_values = discrete.get_ordered_discrete_values(dv_sbp)
    local discrete_dic3 = {}
    local discrete_dic4 = {}
    local matched_dbp_list = {}
    local matched_sbp_list = {}


    local s = 0
    local d = 0
    local x = #dbp_discrete_values
    local a = #sbp_discrete_values
    local date_list = {}
    local date_list2 = {}

    if x >= 2 and a >= 2 then
        for _, item in ipairs(dbp_discrete_values) do
            local x_item = dbp_discrete_values[x]
            local a_item = sbp_discrete_values[a]

            local x_date = dates.date_string_to_int(x_item.result_date)
            local a_date = dates.date_string_to_int(a_item.result_date)

            if s <= 0 or a <= 0 then
                break
            elseif
                x_date == a_date and
                x_item.result > value and
                a_item.result > value2 and
                not date_list[x_date] and
                not date_list2[a_date]
            then
                date_list[x_date] = true
                d = d + 1
                discrete_dic4[d] = x_item
                s = s + 1
                discrete_dic3[s] = a_item
                table.insert(matched_dbp_list, x_item.result)
                table.insert(matched_sbp_list, a_item.result)
                x = x - 1
                a = a - 1
            elseif x_date ~= a_date then
                for _, item2 in ipairs(sbp_discrete_values) do
                    if x_item.result_date == item2.result_date then
                        if
                            tonumber(x_item.result) > value and
                            tonumber(item2.result) > value2 and
                            not date_list[x_date] and
                            not date_list2[a_date]
                        then
                            date_list[x_date] = true
                            d = d + 1
                            discrete_dic4[d] = x_item
                            s = s + 1
                            discrete_dic3[s] = item2
                            table.insert(matched_dbp_list, x_item.result)
                            table.insert(matched_sbp_list, item2.result)
                            x = x - 1
                            a = a - 1
                        end
                    end
                end
            else
                x = x - 1
                a = a - 1
            end
        end
    end

    if d > 0 and s > 0 then
        bp_single_line_lookup(discrete_dic3, discrete_dic4)
    end
    if #matched_sbp_list == 0 then
        matched_sbp_list = { false }
    end
    if #matched_dbp_list == 0 then
        matched_dbp_list = { false }
    end
    return matched_sbp_list, matched_dbp_list
end

local function non_linked_greater_values()
    local dv1 = dv_dbp
    local dv2 = dv_sbp
    local value = 80
    local value2 = 120
    
    --[[
    discreteDic = {}
    discreteDic2 = {}
    discreteDic3 = {}
    s = 0
    d = 0
    x = 0
    idList = []

    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in DV1 and dvr is not None:
                x += 1
                discreteDic[x] = dvDic[dv]
        elif dvDic[dv]['Name'] in DV2 and dvr is not None:
                x += 1
                discreteDic[x] = dvDic[dv]

    if x > 0:
        for item in discreteDic:
            if (
                discreteDic[item]['Name'] in DV1 and
                float(cleanNumbers(discreteDic[item].Result)) > float(value) and
                discreteDic[item]._id not in idList
            ):
                d += 1
                discreteDic3[d] = discreteDic[item]
                idList.append(discreteDic[item]._id)
                for item2 in discreteDic:
                    if (
                        discreteDic[item].ResultDate == discreteDic[item2].ResultDate and 
                        discreteDic[item2]['Name'] in DV2 and
                        discreteDic[item2]._id not in idList
                    ):
                        s += 1
                        discreteDic2[s] = discreteDic[item2]
                        idList.append(discreteDic[item2]._id)
            elif (
                discreteDic[item]['Name'] in DV2 and
                float(cleanNumbers(discreteDic[item].Result)) > float(value2) and
                discreteDic[x]._id not in idList
            ):
                s += 1
                discreteDic2[s] = discreteDic[item]
                idList.append(discreteDic[item]._id)
                for item2 in discreteDic:
                    if (
                        discreteDic[item].ResultDate == discreteDic[item2].ResultDate and 
                        discreteDic[item2]['Name'] in DV1 and
                        discreteDic[item2]._id not in idList
                    ):
                        d += 1
                        discreteDic3[d] = discreteDic[item2]
                        idList.append(discreteDic[item2]._id)

    if d > 0 or s > 0:            
        bpSingleLineLookup(dict(dvDic), dict(discreteDic2), dict(discreteDic3))
    return 
    --]]
end



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }
local subtitle = existing_alert and existing_alert.subtitle or nil



if not existing_alert or not existing_alert.validated then
    local function compile_links()
        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, alert_trigger_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, vital_signs_intake_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))

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

