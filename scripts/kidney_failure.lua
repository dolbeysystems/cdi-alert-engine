---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Kidney Failure
---
--- This script checks an account to see if it matches the criteria for a kidney failure alert.
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
local dv_glomerular_filtration_rate = { "GFR (mL/min/1.73m2)" }
local calc_glomerular_filtration_rate1 = 60
local dv_map = { "Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)" }
local calc_map1 = function(dv_, num) return num < 70 end
local dv_sbp = { "SBP 3.5 (No Calculation) (mm Hg)" }
local calc_sbp1 = function(dv_, num) return num < 90 end
local dv_serum_blood_urea_nitrogen = { "BUN (mg/dL)" }
local calc_serum_blood_urea_nitrogen1 = 23
local dv_serum_creatinine = { "CREATININE (mg/dL)", "CREATININE SERUM (mg/dL)" }
local calc_serum_creatinine1 = 1.02
local calc_serum_creatinine2 = 1.50
local dv_temperature = { "Temperature Degrees C 3.5 (degrees C)", "Temperature  Degrees C 3.5 (degrees C)", "TEMPERATURE (C)" }
local calc_temperature1 = function(dv_, num) return num > 38.3 end
local dv_urine_sodium = { "URINE SODIUM (mmol/L)" }
local calc_urine_sodium1 = function(dv_, num) return num > 40 end
local calc_urine_sodium2 = function(dv_, num) return num < 20 end
local dv_urinary = { "" }
local calc_urinary1 = function(dv_, num) return num > 0 end
local dv_height = { "" }



local spec_code_dic = {
    ["N17.0"] = "Acute Kidney Failure With Tubular Necrosis",
    ["N17.1"] = "Acute Kidney Failure With Acute Cortical Necrosis",
    ["N17.2"] = "Acute Kidney Failure With Medullary Necrosis",
    ["K76.7"] = "Hepatorenal Syndrome",
    ["K91.83"] = "Postprocedural Hepatorenal Syndrome"
}
local chro_code_dic = {
    ["N18.1"] = "Chronic Kidney Disease, Stage 1",
    ["N18.2"] = "Chronic Kidney Disease, Stage 2 (Mild)",
    ["N18.30"] = "Chronic Kidney Disease, Stage 3 Unspecified",
    ["N18.31"] = "Chronic Kidney Disease, Stage 3a",
    ["N18.32"] = "Chronic Kidney Disease, Stage 3b",
    ["N18.4"] = "Chronic Kidney Disease, Stage 4 (Severe)",
    ["N18.5"] = "Chronic Kidney Disease, Stage 5",
    ["N18.6"] = "End Stage Renal Disease"
}
local account_spec_codes = codes.get_account_codes_in_dictionary(Account, spec_code_dic)
local account_chro_codes = codes.get_account_codes_in_dictionary(Account, chro_code_dic)



--------------------------------------------------------------------------------
--- Script Specific Functions
--------------------------------------------------------------------------------
local function value_comparison(discrete_value, discrete_value_2, value, check)
    check = check or 0
    if value then
        if tonumber(value) / tonumber(discrete_value) >= 1.5 then
            return true
        end
    elseif check == 1 then
        if (tonumber(discrete_value_2) - tonumber(discrete_value)) / tonumber(discrete_value) >= 30 then
            return true
        end
    elseif check == 2 then
        if (tonumber(discrete_value) ~= tonumber(discrete_value_2) * 1.5) then
            return true
        end
    end
    return false
end

local function creatinine_check(discrete_value_name, abs_value_name, link_text, category, sequence)
    local abstractions = Account.find_code_references(abs_value_name)
    local abs_value = abstractions and abstractions[1] and tonumber(abstractions[1].code_reference.value) or nil
    local discrete_values = Account.find_discrete_values(discrete_value_name)
    local date_limit = dates.days_ago(2)
    local x = 0
    local abstraction = {}

    -- Check 1
    if abs_value then
        for _, discrete_value in ipairs(discrete_values) do
            if value_comparison(discrete.get_dv_value_number(discrete_value), nil, abs_value) then
                local link = cdi_alert_link()
                link.discrete_value_id = discrete_value.unique_id
                link.discrete_value_name = discrete_value.name
                link.sequence = sequence
                link.link_text = links.replace_link_place_holders(link_text, nil, nil, discrete_value, nil)
                table.insert(abstraction, link)
            end
        end
        if #abstraction > 0 then
            return abstraction
        end
    end

    -- Check 2
    if x > 1 then
        for _, discrete_value in ipairs(discrete_values) do
            local id1 = discrete_value.unique_id
            if dates.date_string_to_int(discrete_value.result_date) >= date_limit then
                for _, discrete_value_2 in ipairs(discrete_values) do
                    local id2 = discrete_value_2.unique_id
                    if
                        dates.date_string_to_int(discrete_value_2.result_date) >= date_limit and
                        dates.date_string_to_int(discrete_value_2.result_date) >= dates.date_string_to_int(discrete_value.result_date) and
                        id2 ~= id1 and
                        discrete.get_dv_value_number(discrete_value_2) > 1.0
                    then
                        if
                            value_comparison(
                                discrete.get_dv_value_number(discrete_value),
                                discrete.get_dv_value_number(discrete_value_2),
                                abs_value,
                                1
                            )
                        then
                            local link = cdi_alert_link()
                            link.discrete_value_id = discrete_value_2.unique_id
                            link.discrete_value_name = discrete_value_2.name
                            link.sequence = sequence
                            link.link_text = links.replace_link_place_holders(link_text, nil, nil, discrete_value_2, nil)
                            table.insert(abstraction, link)
                            local link = cdi_alert_link()
                            link.discrete_value_id = discrete_value.unique_id
                            link.discrete_value_name = discrete_value.name
                            link.sequence = sequence
                            link.link_text = links.replace_link_place_holders(link_text, nil, nil, discrete_value, nil)
                            table.insert(abstraction, link)
                        end
                    end
                end
            end

        end
    end

    -- Check 4
    if x > 1 then
        for _, discrete_value in ipairs(discrete_values) do
            local id1 = discrete_value.unique_id

            for _, item2 in ipairs(discrete_values) do
                local id2 = discrete_value.unique_id
                if dates.date_string_to_int(item2.result_date) >= dates.date_string_to_int(discrete_value.result_date) and id2 ~= id1 then
                    if value_comparison(discrete.get_dv_value_number(discrete_value), discrete.get_dv_value_number(item2), abs_value, 2) then
                        local link = cdi_alert_link()
                        link.discrete_value_id = item2.unique_id
                        link.discrete_value_name = item2.name
                        link.sequence = sequence
                        link.link_text = links.replace_link_place_holders(link_text, nil, nil, item2, nil)
                        table.insert(abstraction, link)
                        local link = cdi_alert_link()
                        link.discrete_value_id = discrete_value.unique_id
                        link.discrete_value_name = discrete_value.name
                        link.sequence = sequence
                        link.link_text = links.replace_link_place_holders(link_text, nil, nil, discrete_value, nil)
                        table.insert(abstraction, link)
                    end
                end
            end
        end
    end

    --[[
    #Check 3
    if x > 1:
        abstraction = dvValueMulti(dict(maindiscreteDic), dvSerumCreatinine, "Serum Creatinine: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumCreatinine2, gt, 2, creatinine, False, 10)
        if len(abstraction or noLabs) > 1:
            db.LogEvaluationScriptMessage("Creatinine Check 3 Passed " + str(account._id), scriptName, scriptInstance, "Debug")
            return abstraction
    return None
    --]]
    return nil
end

local function is_value_greater_than_three_days(discrete_value_name, value, link_text, category, sequence)
    sequence = sequence or 1
    --[[
    dayOne = System.DateTime.Now.AddDays(-1)
    dayTwo = System.DateTime.Now.AddDays(-2)
    dayThree = System.DateTime.Now.AddDays(-3)
    dayFour = System.DateTime.Now.AddDays(-4)
    discreteDic1 = {}
    discreteDic2 = {}
    discreteDic3 = {}
    discreteDic4 = {}
    w = 0
    x = 0
    y = 0
    z = 0
    abstraction = []
    --]]
    --[[
    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in discreteValueName and dvDic[dv]['Result'] is not None: convertedResult = dvr
        else: convertedResult = None
        if convertedResult is not None and convertedResult > value and dvDic[dv]['ResultDate'] <= dayOne:
            discreteDic1[w] = dvDic[dv]
        elif convertedResult is not None and convertedResult > value and dayTwo <= dvDic[dv]['ResultDate'] <= dayOne:
            discreteDic2[x] = dvDic[dv]
        elif convertedResult is not None and convertedResult > value and dayThree <= dvDic[dv]['ResultDate'] <= dayTwo:
            discreteDic3[y] = dvDic[dv]
        elif convertedResult is not None and convertedResult > value and dayFour <= dvDic[dv]['ResultDate'] <= dayThree:
            discreteDic4[z] = dvDic[dv]
    --]]
    --[[
    if (
        (w > 0 and x > 0 and y > 0) or
        (x > 0 and y > 0 and z > 0)
    ):
        if w > 0:
            abstraction.append(dataConversion(discreteDic1[w].ResultDate, linkText, discreteDic1[w].Result, discreteDic1[w].UniqueId or discreteDic1[w]._id, category, sequence, False))
        if x > 0:
            abstraction.append(dataConversion(discreteDic2[x].ResultDate, linkText, discreteDic2[x].Result, discreteDic2[x].UniqueId or discreteDic2[x]._id, category, sequence, False))
        if y > 0:
            abstraction.append(dataConversion(discreteDic3[y].ResultDate, linkText, discreteDic3[y].Result, discreteDic3[y].UniqueId or discreteDic3[y]._id, category, sequence, False))
        if z > 0:
            abstraction.append(dataConversion(discreteDic4[z].ResultDate, linkText, discreteDic4[z].Result, discreteDic4[z].UniqueId or discreteDic4[z]._id, category, sequence, False))
        return abstraction
    return None
    --]]
end

local function dv_urine_check(discrete_value_name, link_text, sequence, category, abstract)
    sequence = sequence or 0
    abstract = abstract or false
    local abstraction = nil
    --[[
    for dv in dvDic or []:
        if dvDic[dv]['Name'] in discreteValueName and dvDic[dv]['Result'] is not None and re.search(r'\d\+', dvDic[dv]['Result']) is not None:
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return abstraction
    --]]
    return abstraction
end

local function dv_urine_check_two(discrete_value_name, link_text, sequence, category, abstract)
    sequence = sequence or 0
    abstract = abstract or false
    --[[
    abstraction = None
    for dv in dvDic or []:
        if dvDic[dv]['Name'] in discreteValueName and dvDic[dv]['Result'] is not None and re.search(r'\b0-5\b', dvDic[dv]['Result'], re.IGNORECASE) is None:
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return abstraction
    return abstraction
    --]]
end

local function dv_urine_check_three(discrete_value_name, link_text, sequence, category, abstract)
    sequence = sequence or 0
    abstract = abstract or false
    --[[
    abstraction = None
    for dv in dvDic or []:
        if dvDic[dv]['Name'] in discreteValueName and dvDic[dv]['Result'] is not None and re.search(r'\b0-4\b', dvDic[dv]['Result'], re.IGNORECASE) is None:
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return abstraction
    return abstraction
    --]]
end

local function dv_urine_check_four(discrete_value_name, link_text, sequence, category, abstract)
    sequence = sequence or 0
    abstract = abstract or false
    --[[
    abstraction = None
    for dv in dvDic or []:
        if dvDic[dv]['Name'] in discreteValueName and dvDic[dv]['Result'] is not None:
            list = []
            list = dvDic[dv]['Result'].split('-')
            list[0]
            if list[0] > 20 or list[1] >cbc 20:
                if abstract:
                    dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                    return True
                else:
                    abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                    return abstraction
    return abstraction
    --]]
end

local function ideal_urine_calc(height, urine, gender, category)
    --[[
    LinkText1 = "Possible Low Urine Output"
    urineDic = {}
    heightDic = {}
    x = 0
    y = 0
    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in height and dvr is not None:
            y += 1
            heightDic[y] = dvDic[dv]
        elif dvDic[dv]['Name'] in urine and dvr is not None:
            x += 1
            urineDic[x] = dvDic[dv]
    if x > 0 and y > 0:
        if gender == 'F':
            output = (((float(heightDic[y].Result) - 105.0) * 0.5) * 24)
            if float(urineDic[x].Result) < float(output):
                category.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None))
                return True
            else:
                return False
        elif gender == 'M':
            output = (((float(heightDic[y].Result) - 100.0) * 0.5) * 24)
            if float(urineDic[x].Result) < float(output):
                category.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None))
                return True
            else:
                return False
        else:
            return False
    else:
            return False
--]]
end

local function dv_look_up_all_values_single_line(dv1, sequence, category, link_text)
    --[[
    date1 = None
    date2 = None
    id = None
    FirstLoop = True
    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in DV1 and dvr is not None:
            if FirstLoop:
                FirstLoop = False
                linkText = linkText + dvr 
            else:
                linkText = linkText + ", " + dvr 
            if date1 is None:
                date1 = dvDic[dv]['ResultDate']
            date2 = dvDic[dv]['ResultDate']
            if id is None:
                id = dvDic[dv]['UniqueId'] or dvDic[dv]['_id']
            
    if date1 is not None and date2 is not None:
        date1 = datetimeFromUtcToLocal(date1)
        date1 = date1.ToString("MM/dd/yyyy")
        date2 = datetimeFromUtcToLocal(date2)
        date2 = date2.ToString("MM/dd/yyyy")
        linkText = linkText.replace("DATE1", date1)
        linkText = linkText.replace("DATE2", date2)
        category.Links.Add(MatchedCriteriaLink(linkText, None, None, id, True, None, None, sequence))       
    --]]
end



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }
local subtitle = existing_alert and existing_alert.subtitle or nil

-- Alert Triggers
local n179_code = links.get_code_link { code = "N17.9", text = "Acute Kidney Failure, Unspecified" }
-- Labs
local high_serum_creatinine_multi_day_dv =
    is_value_greater_than_three_days(dv_serum_creatinine, 1.2, "Serum Creatinine Multiple Days")


if
    (not existing_alert or not existing_alert.validated) or
    (
        existing_alert and existing_alert.outcome == "AUTORESOLVED" and
        existing_alert.validated and
        (
            #account_spec_codes > 1 or
            #account_chro_codes > 1 or
            (codes.get_account_codes(Account, "N17.9") and high_serum_creatinine_multi_day_dv and #account_spec_codes == 0)
        )
    )
then
    --------------------------------------------------------------------------------
    --- Header Variables and Helper Functions
    --------------------------------------------------------------------------------
    local result_links = {}
    local documented_dx_header = headers.make_header_builder("Documented Dx", 1)
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 3)
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 5)
    local vital_signs_intake_header = headers.make_header_builder("Vital Signs/Intake", 4)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 6)
    local gfr_header = headers.make_header_builder("GFR", 89)
    local creatinine_header = headers.make_header_builder("Serum Creatinine", 90)
    local bun_header = headers.make_header_builder("Blood Urea Nitrogen", 91)

    local function compile_links()
        laboratory_studies_header:add_link(gfr_header:build(true))
        laboratory_studies_header:add_link(creatinine_header:build(true))
        laboratory_studies_header:add_link(bun_header:build(true))

        table.insert(result_links, documented_dx_header:build(true))
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

