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
--- Script Specific Functions
--------------------------------------------------------------------------------
local function linked_greater_values()
    local dv1 = dv_dbp
    local dv2 = dv_sbp
    local value = 80
    local value2 = 120

    local s = 0
    local d = 0
    local x = 0
    local a = 0
    --[[
    discreteDic = {}
    discreteDic2 = {}
    discreteDic3 = {}
    discreteDic4 = {}
    s = 0
    d = 0
    x = 0
    a = 0
    matchedSBPList = []
    matchedDBPList = []
    DateList = []
    DateList2 = []

    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in DV1 and dvr is not None:
                x += 1
                discreteDic[x] = dvDic[dv]
        elif dvDic[dv]['Name'] in DV2 and dvr is not None:
                a += 1
                discreteDic2[a] = dvDic[dv]

    if x >= 2 and a >= 2:
        for item in discreteDic:
            if x <= 0 or a <= 0:
                break
            elif (
                discreteDic[x].ResultDate == discreteDic2[a].ResultDate and
                float(cleanNumbers(discreteDic[x].Result)) > float(value) and 
                float(cleanNumbers(discreteDic2[a].Result)) > float(value2) and
                discreteDic[x].ResultDate not in DateList and 
                discreteDic2[a].ResultDate not in DateList2
            ):
                DateList.append(discreteDic[x].ResultDate)
                d += 1
                discreteDic4[d] = discreteDic[x]
                s += 1
                discreteDic3[s] = discreteDic2[a]
                matchedDBPList.append(discreteDic[x].Result)
                matchedSBPList.append(discreteDic2[a].Result)
                x = x - 1; a = a - 1
            elif discreteDic[x].ResultDate != discreteDic2[a].ResultDate:
                for item in discreteDic2:
                    if discreteDic[x].ResultDate == discreteDic2[item].ResultDate:
                        if (    
                            float(cleanNumbers(discreteDic[x].Result)) > float(value) and 
                            float(cleanNumbers(discreteDic2[item].Result)) > float(value2) and
                            discreteDic[x].ResultDate not in DateList and 
                            discreteDic2[item].ResultDate not in DateList2
                        ):
                            DateList.append(discreteDic[x].ResultDate)
                            d += 1
                            discreteDic4[d] = discreteDic[x]
                            s += 1
                            discreteDic3[s] = discreteDic2[a]
                            matchedDBPList.append(discreteDic[x].Result)
                            matchedSBPList.append(discreteDic2[item].Result)
                            x = x - 1; a = a - 1
            else:
                x = x - 1; a = a - 1
    
    if d > 0 and s > 0:            
        bpSingleLineLookup(dict(dvDic), dict(discreteDic3), dict(discreteDic4))
    if len(matchedSBPList) == 0:
        matchedSBPList = [False]
    if len(matchedDBPList) == 0:
        matchedDBPList = [False]
    return [matchedSBPList, matchedDBPList]
    --]]
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

local function bp_single_line_lookup(sbpDic, dbpDic)
    --[[
    discreteDic1 = {}
    discreteDic2 = {}
    dbpDv = None
    hrDv = None
    mapDv = None
    matchingDate = None
    h = 0; m = 0
    matchedList = []
    dvr = None
    #Pull all values for discrete values we need
    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in dvMAP and dvr is not None:
            #Mean Arterial Blood Pressure
            m += 1
            discreteDic1[m] = dvDic[dv]
        elif dvDic[dv]['Name'] in dvHeartRate and dvr is not None:
            #Heart Rate
            h += 1
            discreteDic2[h] = dvDic[dv]

    for item in sbpDic:
        dbpDv = None
        hrDv = None
        mapDv = None
        matchingDate = sbpDic[item].ResultDate
        if m > 0:
            for item1 in discreteDic1:
                if discreteDic1[item1].ResultDate == matchingDate:
                    mapDv = discreteDic1[item1].Result
                    break
        if h > 0:
            for item2 in discreteDic2:
                if discreteDic2[item2].ResultDate == matchingDate:
                    hrDv = discreteDic2[item2].Result
                    break
        for item3 in dbpDic:
            if dbpDic[item3].ResultDate == matchingDate:
                dbpDv = dbpDic[item3].Result
                break

        if dbpDv is None:
            dbpDv = 'XX'
        if hrDv is None:
            hrDv = 'XX'
        if mapDv is None:
            mapDv = 'XX'
        matchedList.append(dataConversion(matchingDate, "[RESULTDATETIME] HR = " + str(hrDv) + ", BP = " + str(sbpDic[item].Result) + "/" + str(dbpDv) + ", MAP = " + str(mapDv), None, sbpDic[item]._id, vitals, 0, True))
    return 
    --]]
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
    local alert_trigger_header = headers.make_header_builder("Alert Trigger", 2)
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 3)
    local vital_signs_intake_header = headers.make_header_builder("Vital Signs/Intake", 4)
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 5)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 6)

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

