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
local calc_glomerular_filtration_rate1 = function(dv_, num) return num <= 60 end
local dv_map = { "Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)" }
local calc_map1 = function(dv_, num) return num < 70 end
local dv_sbp = { "SBP 3.5 (No Calculation) (mm Hg)" }
local calc_sbp1 = function(dv_, num) return num < 90 end
local dv_serum_blood_urea_nitrogen = { "BUN (mg/dL)" }
local calc_serum_blood_urea_nitrogen1 = function(dv_, num) return num > 23 end
local dv_serum_creatinine = { "CREATININE (mg/dL)", "CREATININE SERUM (mg/dL)" }
local calc_serum_creatinine1 = function(dv_, num) return num > 1.02 end
local calc_serum_creatinine2 = function(dv_, num) return num > 1.50 end
local dv_temperature = { "Temperature Degrees C 3.5 (degrees C)", "Temperature  Degrees C 3.5 (degrees C)",
    "TEMPERATURE (C)" }
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
--- @param discrete_value number? Discrete value names #1
--- @param discrete_value_2 number? Discrete value names #2
--- @param value number? Value
--- @param check number? check number
--- @return boolean - Whether or not check passed
local function value_comparison(discrete_value, discrete_value_2, value, check)
    check = check or 0
    if value then
        if value / discrete_value >= 1.5 then
            return true
        end
    elseif check == 1 then
        if (discrete_value_2 - discrete_value) / discrete_value >= 30 then
            return true
        end
    elseif check == 2 then
        if discrete_value ~= discrete_value_2 * 1.5 then
            return true
        end
    end
    return false
end

--- @param discrete_value_name string[] Discrete value names for urine
--- @param abs_value_name string Abstraction value name
--- @param link_text string Link text
--- @param category? header_builder Header builder
--- @param sequence? number Sequence
--- @return CdiAlertLink[]?
local function creatinine_check(discrete_value_name, abs_value_name, link_text, category, sequence)
    local abstractions = Account:find_code_references(abs_value_name)
    local abs_value = abstractions and abstractions[1] and tonumber(abstractions[1].code_reference.value) or nil
    local discrete_values = discrete.get_ordered_discrete_values { discreteValueNames = discrete_value_name }
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
                if sequence then link.sequence = sequence end
                link.link_text = links.replace_link_place_holders(link_text, nil, nil, discrete_value, nil)
                table.insert(abstraction, link)
            end
        end
    end

    -- Check 2
    if x > 1 then
        for _, discrete_value in ipairs(discrete_values) do
            local id1 = discrete_value.unique_id
            if dates.date_string_to_int(discrete_value.result_date) >= date_limit then
                for _, discrete_value_2 in ipairs(discrete_values) do
                    local id2 = discrete_value_2.unique_id
                    local date2 = dates.date_string_to_int(discrete_value_2.result_date)
                    if
                        date2 >= date_limit and
                        date2 >= dates.date_string_to_int(discrete_value.result_date) and
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
                            if sequence then link.sequence = sequence end
                            link.link_text =
                                links.replace_link_place_holders(link_text, nil, nil, discrete_value_2, nil)
                            table.insert(abstraction, link)
                            local link = cdi_alert_link()
                            link.discrete_value_id = discrete_value.unique_id
                            link.discrete_value_name = discrete_value.name
                            if sequence then link.sequence = sequence end
                            link.link_text =
                                links.replace_link_place_holders(link_text, nil, nil, discrete_value, nil)
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
                if
                    (
                        dates.date_string_to_int(item2.result_date) >=
                        dates.date_string_to_int(discrete_value.result_date)
                    ) and
                    id2 ~= id1
                then
                    if
                        value_comparison(
                            discrete.get_dv_value_number(discrete_value),
                            discrete.get_dv_value_number(item2),
                            abs_value,
                            2
                        )
                    then
                        local link = cdi_alert_link()
                        link.discrete_value_id = item2.unique_id
                        link.discrete_value_name = item2.name
                        if sequence then link.sequence = sequence end
                        link.link_text = links.replace_link_place_holders(link_text, nil, nil, item2, nil)
                        table.insert(abstraction, link)
                        local link = cdi_alert_link()
                        link.discrete_value_id = discrete_value.unique_id
                        link.discrete_value_name = discrete_value.name
                        if sequence then link.sequence = sequence end
                        link.link_text = links.replace_link_place_holders(link_text, nil, nil, discrete_value, nil)
                        table.insert(abstraction, link)
                    end
                end
            end
        end
    end

    -- Check 3
    if x > 1 then
        local abstraction = links.get_discrete_value_link {
            discreteValueNames = dv_serum_creatinine,
            text = "Serum Creatinine",
            predicate = calc_serum_creatinine2,
        }
    end
    if #abstraction > 0 then
        return abstraction
    else
        return nil
    end
end

--- @param discrete_value_name string[] Discrete value names for urine
--- @param value number Value
--- @param link_text string Link text
--- @param category header_builder? Header builder
--- @param sequence number? Sequence
--- @return CdiAlertLink[]?
local function is_value_greater_than_three_days(discrete_value_name, value, link_text, category, sequence)
    sequence = sequence or 1
    local day_one = dates.days_ago(1)
    local day_two = dates.days_ago(2)
    local day_three = dates.days_ago(3)
    local day_four = dates.days_ago(4)
    local discrete_dic_1 = {}
    local discrete_dic_2 = {}
    local discrete_dic_3 = {}
    local discrete_dic_4 = {}
    local w = 0
    local x = 0
    local y = 0
    local z = 0
    local abstraction = {}

    local discrete_values = Account.find_discrete_values(discrete_value_name)

    for _, dv in ipairs(discrete_values) do
        local dvr = discrete.get_dv_value_number(dv)
        local date = dates.date_string_to_int(dv.result_date)
        if dvr and dvr > value and date <= day_one then
            discrete_dic_1[w] = dv
        elseif dvr and dvr > value and day_two <= date and date <= day_one then
            discrete_dic_2[x] = dv
        elseif dvr and dvr > value and day_three <= date and date <= day_two then
            discrete_dic_3[y] = dv
        elseif dvr and dvr > value and day_four <= date and date <= day_three then
            discrete_dic_4[z] = dv
        end
    end

    if (w > 0 and x > 0 and y > 0) or (x > 0 and y > 0 and z > 0) then
        if w > 0 then
            local link = cdi_alert_link()
            link.discrete_value_id = discrete_dic_1[w].unique_id
            link.discrete_value_name = discrete_dic_1[w].name
            link.sequence = sequence
            link.link_text = links.replace_link_place_holders(link_text, nil, nil, discrete_dic_1[w], nil)
            table.insert(abstraction, link)
        end
        if x > 0 then
            local link = cdi_alert_link()
            link.discrete_value_id = discrete_dic_2[x].unique_id
            link.discrete_value_name = discrete_dic_2[x].name
            link.sequence = sequence
            link.link_text = links.replace_link_place_holders(link_text, nil, nil, discrete_dic_2[x], nil)
            table.insert(abstraction, link)
        end
        if y > 0 then
            local link = cdi_alert_link()
            link.discrete_value_id = discrete_dic_3[y].unique_id
            link.discrete_value_name = discrete_dic_3[y].name
            link.sequence = sequence
            link.link_text = links.replace_link_place_holders(link_text, nil, nil, discrete_dic_3[y], nil)
            table.insert(abstraction, link)
        end
        if z > 0 then
            local link = cdi_alert_link()
            link.discrete_value_id = discrete_dic_4[z].unique_id
            link.discrete_value_name = discrete_dic_4[z].name
            link.sequence = sequence
            link.link_text = links.replace_link_place_holders(link_text, nil, nil, discrete_dic_4[z], nil)
            table.insert(abstraction, link)
        end
        return abstraction
    end
    return nil
end

--- @param discrete_value_name string[] Discrete value names for urine
--- @param link_text string Link text
--- @param sequence? number Sequence
--- @param category? header_builder Header builder
--- @param abstract? boolean
--- @return CdiAlertLink?
local function dv_urine_check(discrete_value_name, link_text, sequence, category, abstract)
    sequence = sequence or 0
    abstract = abstract or false
    local abstraction = nil

    return links.get_discrete_value_link {
        discreteValueNames = discrete_value_name,
        text = link_text,
        predicate = function(dv, num)
            return num ~= nil
        end,
        category = category,
        sequence = sequence,
    }
end

--- @param discrete_value_name string[] Discrete value names for urine
--- @param link_text string Link text
--- @param sequence? number Sequence
--- @param category? header_builder Header builder
--- @param abstract? boolean
--- @return CdiAlertLink?
local function dv_urine_check_two(discrete_value_name, link_text, sequence, category, abstract)
    sequence = sequence or 0
    abstract = abstract or false

    return links.get_discrete_value_link {
        discreteValueNames = discrete_value_name,
        text = link_text,
        predicate = function(dv, num)
            return dv.result ~= nil and not string.match(dv.result, "0-5")
        end,
        category = category,
        sequence = sequence,
    }
end

--- @param discrete_value_name string[] Discrete value names for urine
--- @param link_text string Link text
--- @param sequence? number Sequence
--- @param category? header_builder Header builder
--- @param abstract? boolean
--- @return CdiAlertLink?
local function dv_urine_check_three(discrete_value_name, link_text, sequence, category, abstract)
    sequence = sequence or 0
    abstract = abstract or false
    return links.get_discrete_value_link {
        discreteValueNames = discrete_value_name,
        text = link_text,
        predicate = function(dv, num)
            return dv.result ~= nil and not string.match(dv.result, "0-4")
        end,
        category = category,
        sequence = sequence,
    }
end

--- @param discrete_value_name string[] Discrete value names for urine
--- @param link_text string Link text
--- @param sequence? number Sequence
--- @param category? header_builder Header builder
--- @param abstract? boolean
--- @return CdiAlertLink?
local function dv_urine_check_four(discrete_value_name, link_text, sequence, category, abstract)
    sequence = sequence or 0
    abstract = abstract or false
    return links.get_discrete_value_link {
        discreteValueNames = discrete_value_name,
        text = link_text,
        predicate = function(dv, num)
            local parts = dv.result:gmatch("[^\\-]")
            return dv.result ~= nil and
                ((#parts > 0 and tonumber(parts[1]) > 20) or (#parts > 1 and tonumber(parts[2]) > 20))
        end,
        sequence = sequence,
    }
end

--- @param height string[] Discrete value names for height
--- @param urine string[] Discrete value names for urine
--- @param gender string Patient gender from account
--- @param category header_builder Header builder
--- @return boolean
local function ideal_urine_calc(height, urine, gender, category)
    local height_dic = discrete.get_ordered_discrete_values { discreteValueNames = height }
    local urine_dic = discrete.get_ordered_discrete_values { discreteValueNames = urine }
    local x = #urine_dic
    local y = #height_dic

    if x > 0 and y > 0 then
        if gender == "F" then
            local output = (((tonumber(height_dic[y].Result) - 105.0) * 0.5) * 24)
            if tonumber(urine_dic[x].Result) < tonumber(output) then
                category:add_text_link("Possible Low Urine Output")
                return true
            end
        elseif gender == "M" then
            local output = (((tonumber(height_dic[y].Result) - 105.0) * 0.5) * 24)
            if tonumber(urine_dic[x].Result) < tonumber(output) then
                category:add_text_link("Possible Low Urine Output")
                return true
            end
        end
    end
    return false
end

--- @param dv1 string[] Discrete value names
--- @param sequence number Sequence
--- @param category header_builder Header builder
--- @param link_text string Link text
local function dv_look_up_all_values_single_line(dv1, sequence, category, link_text)
    category.add_link(
        discrete.get_dv_values_as_single_link {
            discreteValueNames = dv1,
            sequence = sequence,
        }
    )
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
            (n179_code and high_serum_creatinine_multi_day_dv and #account_spec_codes == 0)
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
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Negations
    local negation_kidney_failure = links.get_code_links {
        codes =
        {
            "N17.0", "N17.1", "N17.2", "N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6",
            "N18.9"
        },
        text = "Kidney Failure Codes"
    }
    local n181_code = links.get_code_link { code = "N18.1", text = "Chronic Kidney Disease, Stage 1" }
    local n182_code = links.get_code_link { code = "N18.2", text = "Chronic Kidney Disease, Stage 2 (Mild)" }
    local n1830_code = links.get_code_link { code = "N18.30", text = "Chronic Kidney Disease, Stage 3 Unspecified" }
    local n1831_code = links.get_code_link { code = "N18.31", text = "Chronic Kidney Disease, Stage 3a" }
    local n1832_code = links.get_code_link { code = "N18.32", text = "Chronic Kidney Disease, Stage 3b" }
    local n184_code = links.get_code_link { code = "N18.4", text = "Chronic Kidney Disease, Stage 4 (Severe)" }
    local n185_code = links.get_code_link { code = "N18.5", text = "Chronic Kidney Disease, Stage 5" }
    local n186_code = links.get_code_link { code = "N18.6", text = "End stage renal disease" }

    -- Alert Triggers
    local n19_code = links.get_code_link { code = "N19", text = "Unspecified Kidney Failure" }
    local n17_codes = links.get_code_links { codes = { "N17.0", "N17.1", "N17.2" }, text = "Kidney Failure Code" }
    local n189_code = links.get_code_link { code = "N18.9", text = "Chronic Kidney Disease, Unspecified" }
    local creatinine_check_dv = creatinine_check(dv_serum_creatinine, "BASELINE_CREATININE", "Serum Creatinine")
    local creatinine_multi_dv =
        links.get_discrete_value_link {
            discreteValueNames = dv_serum_creatinine,
            text = "Serum Creatinine",
        }
    local acute_chronic_unspecified_kidney_failure_abs =
        links.get_abstract_value_link {
            abstractValueName = "ACUTE_ON_CHRONIC_KIDNEY_FAILURE",
            text = "Acute and Chronic Unspecified Kidney Failure Present",
        }
    local baseline_creatinine_abs =
        links.get_abstract_value_link {
            abstractValueName = "BASELINE_CREATININE",
            text = "Baseline Creatinine",
        }
    local acute_kidney_injury_abs =
        links.get_abstract_value_link {
            abstractValueName = "ACUTE_KIDNEY_INJURY",
            text = "Acute Kidney Injury",
        }
    local acute_renal_insufficiency_abs =
        links.get_abstract_value_link {
            abstractValueName = "ACUTE_RENAL_INSUFFICIENCY",
            text = "Acute Renal Insufficiency",
        }

    -- Abs
    local dialysis_dependent_abs = links.get_abstract_value_link {
        abstractValueName = "DIALYSIS_DEPENDENT",
        text = "Dialysis Dependent",
    }
    -- Labs
    local gfr_dv = links.get_discrete_value_links {
        discreteValueNames = dv_glomerular_filtration_rate,
        text = "Glomerular Filtration",
        predicate = calc_glomerular_filtration_rate1,
    }

    -- Vitals
    local urine_calc = ideal_urine_calc(dv_height, dv_urinary, "F", vital_signs_intake_header)

    local check3 = false
    local other_checks = false

    -- Check for creatinine Check check 3
    if creatinine_check_dv then
        for _, item in ipairs(creatinine_check_dv) do
            if item.sequence == 2 then
                check3 = true
            end
            if item.sequence == 0 then
                other_checks = true
            end
        end
    end

    local creatinine_spec_check = false



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if #account_chro_codes > 1 and (n184_code or n185_code or n186_code) then
        -- 1
        for _, code in ipairs(account_chro_codes) do
            local desc = chro_code_dic[code]
            local temp_code = codes.get_first_code_link(code, desc)
            links.add_link(temp_code)
        end
        if existing_alert and existing_alert.validated then
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
            Result.validated = false
            Result.passed = true
        end

    elseif #account_spec_codes > 1 then
        -- 2
        if not gfr_dv then
            gfr_header:add_discrete_value_many_links(
                dv_glomerular_filtration_rate,
                "Glomerular Filtration",
                10,
                calc_glomerular_filtration_rate1
            )
        end
        for _, code in ipairs(account_spec_codes) do
            local desc = spec_code_dic[code]
            local temp_code = codes.get_first_code_link(code, desc)
            links.add_link(temp_code)
        end
        if existing_alert and existing_alert.validated then
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
            Result.validated = false
        end
        Result.subtitle = "Conflicting Acute Kidney Failure Dx Codes"
        Result.passed = true

    elseif subtitle == "Possible End-Stage Renal Disease" and n186_code then
        -- 3.1
        if not n186_code then
            n186_code.link_text = "Autoresolved Specified Code - " .. n186_code.text
            documented_dx_header:add_link(n186_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        existing_alert and
        (existing_alert.outcome == 'AUTORESOLVED' or existing_alert.reason == 'Previously Autoresolved') and
        (n189_code or n181_code or n182_code or n1830_code or n1831_code or n1832_code or n184_code or n185_code) and
        dialysis_dependent_abs and
        #account_chro_codes < 2 and
        not n186_code
    then
        -- 3
        documented_dx_header:add_link(n189_code)
        documented_dx_header:add_link(n181_code)
        documented_dx_header:add_link(n182_code)
        documented_dx_header:add_link(n1830_code)
        documented_dx_header:add_link(n1831_code)
        documented_dx_header:add_link(n1832_code)
        documented_dx_header:add_link(n184_code)
        documented_dx_header:add_link(n185_code)
        Result.subtitle = "Possible End-Stage Renal Disease"
        Result.passed = true

    elseif
        #account_chro_codes > 0 and
        #account_spec_codes > 0 and
        subtitle == "Acute Kidney Failure Unspecified Present Possible ATN"
    then
        -- 4.1
        if #account_chro_codes > 0 then
            for _, code in ipairs(account_chro_codes) do
                local desc = chro_code_dic[code]
                local temp_code = codes.get_first_code_link(code, desc)
                if temp_code then
                    documented_dx_header:add_link(temp_code)
                    break
                end
            end
        end
        if #account_spec_codes > 0 then
            for _, code in ipairs(account_spec_codes) do
                local desc = spec_code_dic[code]
                local temp_code = codes.get_first_code_link(code, desc)
                if temp_code then
                    documented_dx_header:add_link(temp_code)
                    break
                end
            end
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        n179_code and
        high_serum_creatinine_multi_day_dv and
        #account_chro_codes == 0 and
        #account_spec_codes == 0
    then
        -- 4
        if high_serum_creatinine_multi_day_dv then
            for _, entry in ipairs(high_serum_creatinine_multi_day_dv) do
                creatinine_header:add_link(entry)
            end
        end
        documented_dx_header:add_link(n179_code)
        documented_dx_header:add_link(baseline_creatinine_abs)
        if existing_alert and existing_alert.validated then
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
            Result.validated = false
        end
        Result.subtitle = "Acute Kidney Failure Unspecified Present Possible ATN"
        Result.passed = true

    elseif
        subtitle == "Acute Kidney Failure/AKI Present Possible Lacking Clinical Evidence" and
        creatinine_multi_dv
    then
        -- 5.1
        if high_serum_creatinine_multi_day_dv then
            for _, entry in ipairs(high_serum_creatinine_multi_day_dv) do
                creatinine_header:add_link(entry)
            end
        end
        if creatinine_check_dv then
            for _, entry in ipairs(creatinine_check_dv) do
                creatinine_header:add_link(entry)
            end
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        (n179_code or n17_codes) and
        not n181_code and not n182_code and not n1830_code and not n1831_code and
        not n1832_code and not n184_code and not n185_code and not n186_code and
        not creatinine_multi_dv
    then
        -- 5
        documented_dx_header:add_link(n179_code)
        documented_dx_header:add_link(n17_codes)
        Result.subtitle = "Acute Kidney Failure/AKI Present Possible Lacking Clinical Evidence"
        Result.passed = true

    elseif
        subtitle == "Acute Kidney Failure/AKI Present Possible Lacking Clinical Evidence" and
        (high_serum_creatinine_multi_day_dv or creatinine_check_dv)
    then
        -- 6.1
        if high_serum_creatinine_multi_day_dv then
            for _, entry in ipairs(high_serum_creatinine_multi_day_dv) do
                creatinine_header:add_link(entry)
            end
        end
        if creatinine_check_dv then
            for _, entry in ipairs(creatinine_check_dv) do
                creatinine_header:add_link(entry)
            end
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif (n179_code or n17_codes) and not high_serum_creatinine_multi_day_dv and not creatinine_check_dv then
        -- 6
        documented_dx_header:add_link(n179_code)
        documented_dx_header:add_link(n17_codes)
        Result.subtitle = "Acute Kidney Failure/AKI Present Possible Lacking Clinical Evidence"
        Result.passed = true

    elseif #account_chro_codes > 0 and subtitle == "CKD No Stage Documented" then
        -- 7.1
        for _, code in ipairs(account_chro_codes) do
            local desc = chro_code_dic[code]
            local temp_code = codes.get_first_code_link(code, desc)
            if temp_code then
                links.add_link(temp_code)
                break
            end
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif n189_code and #account_chro_codes == 0 and gfr_dv then
        -- 7
        documented_dx_header:add_link(n189_code)
        Result.subtitle = "CKD No Stage Documented"
        Result.passed = true

    elseif
        subtitle == "Kidney Failure Dx Missing Acuity" and
        (n179_code or #account_chro_codes > 0 or #account_spec_codes > 0)
    then
        -- 8.1
        if n179_code then
            n179_code.link_text = "Autoresolved Specified Code - " .. n179_code.link_text
            documented_dx_header:add_link(n179_code)
        end
        if #account_chro_codes > 0 then
            for _, code in ipairs(account_chro_codes) do
                local desc = chro_code_dic[code]
                local temp_code = codes.get_first_code_link(code, desc)
                if temp_code then
                    documented_dx_header:add_link(temp_code)
                    break
                end
            end
        end
        if #account_spec_codes > 0 then
            for _, code in ipairs(account_spec_codes) do
                local desc = spec_code_dic[code]
                local temp_code = codes.get_first_code_link(code, desc)
                if temp_code then
                    documented_dx_header:add_link(temp_code)
                    break
                end
            end
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif n19_code and #account_chro_codes == 0 and #account_spec_codes == 0 then
        -- 8
        documented_dx_header:add_link(n19_code)
        Result.subtitle = "Kidney Failure Dx Missing Acuity"
        Result.passed = true

    elseif
        (#account_spec_codes > 0 or n179_code or #account_chro_codes == 1) and
        subtitle == "Possible Acute Kidney Failure/AKI"
    then
        -- 9.1
        if #account_chro_codes > 0 then
            for _, code in ipairs(account_chro_codes) do
                local desc = chro_code_dic[code]
                local temp_code = codes.get_first_code_link(code, desc)
                if temp_code then
                    documented_dx_header:add_link(temp_code)
                    break
                end
            end
        end
        if #account_spec_codes > 0 then
            for _, code in ipairs(account_spec_codes) do
                local desc = spec_code_dic[code]
                local temp_code = codes.get_first_code_link(code, desc)
                if temp_code then
                    documented_dx_header:add_link(temp_code)
                    break
                end
            end
        end
        if n179_code then
            n179_code.link_text = "Autoresolved Specified Code - " .. n179_code.link_text
            documented_dx_header:add_link(n179_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        not n19_code and
        #account_chro_codes == 0 and
        #account_spec_codes == 0 and
        not n179_code and not n189_code and
        creatinine_check_dv
    then
        -- 9
        if creatinine_check_dv then
            for _, entry in ipairs(creatinine_check_dv) do
                creatinine_header:add_link(entry)
            end
        end
        creatinine_spec_check = true
        Result.subtitle = "Possible Acute Kidney Failure/AKI"
        Result.passed = true

    elseif
        (#account_spec_codes > 0 or n179_code) and
        subtitle == "Possible Chronic Kidney Failure with Superimposed AKI"
    then
        -- 10.1
        for _, code in ipairs(account_chro_codes) do
            local desc = chro_code_dic[code]
            local temp_code = codes.get_first_code_link(code, desc)
            if temp_code then
                documented_dx_header:add_link(temp_code)
                break
            end
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        #account_chro_codes == 1 and
        not n186_code and #account_spec_codes == 0 and
        not n179_code and creatinine_check_dv and
        (check3 == false or other_checks == true) and
        baseline_creatinine_abs
    then
        -- 10
        if baseline_creatinine_abs then creatinine_header:add_link(baseline_creatinine_abs) end
        for _, code in ipairs(account_chro_codes) do
            local desc = chro_code_dic[code]
            local temp_code = codes.get_first_code_link(code, desc)
            documented_dx_header:add_link(temp_code)
        end
        if creatinine_check_dv then
            for _, entry in ipairs(creatinine_check_dv) do
                creatinine_header:add_link(entry)
            end
        end
        creatinine_spec_check = true
        Result.subtitle = "Possible Chronic Kidney Failure with Superimposed AKI"
        Result.passed = true

    elseif
        subtitle == "Conflicting AKI and Renal Insufficiency Dx, Clarification Needed" and
        #account_spec_codes > 0
    then
        -- 11.1
        for _, code in ipairs(account_spec_codes) do
            local desc = spec_code_dic[code]
            local temp_code = codes.get_first_code_link(code, "Autoresolved Specified Code - " .. desc)
            if temp_code then
                documented_dx_header:add_link(temp_code)
                break
            end
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif acute_kidney_injury_abs and acute_renal_insufficiency_abs and #account_spec_codes == 0 then
        -- 11
        if acute_kidney_injury_abs then documented_dx_header:add_link(acute_kidney_injury_abs) end
        if acute_renal_insufficiency_abs then documented_dx_header:add_link(acute_renal_insufficiency_abs) end
        Result.subtitle = "Conflicting AKI and Renal Insufficiency Dx, Clarification Needed"
        Result.passed = true
    end


    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Clinical Evidence
            clinical_evidence_header:add_code_link("R82.998", "Abnormal Urine Findings")
            clinical_evidence_header:add_code_link("D62", "Acute Blood Loss Anemia")
            clinical_evidence_header:add_code_prefix_link("^N00%.", "Acute Nephritic Syndrome")
            clinical_evidence_header:add_code_link("N10", "Acute Pyelonephritis")
            clinical_evidence_header:add_code_link("T39.5X5A", "Adverse effect from Aminoglycoside")
            clinical_evidence_header:add_code_link("T39.395A", "Adverse effect from NSAID")
            clinical_evidence_header:add_code_link("T39.0X5A", "Adverse effect from Sulfonamide")
            clinical_evidence_header:add_abstraction_link(
                "ALTERED_LEVEL_OF_CONSCIOUSNESS",
                "Altered Level Of Consciousness"
            )
            local r4182_code = links.get_code_link { code = "R41.82", text = "Altered Level Of Consciousness" }
            local altered_abs = links.get_abstract_value_link {
                abstractValueName = "ALTERED_LEVEL_OF_CONSCIOUSNESS",
                text = "Altered Level Of Consciousness",
            }
            if r4182_code then
                clinical_evidence_header:add_link(r4182_code)
                if altered_abs then
                    altered_abs.hidden = true
                    clinical_evidence_header:add_link(altered_abs)
                end
            elseif altered_abs then
                clinical_evidence_header:add_link(altered_abs)
            end

            clinical_evidence_header:add_code_link("R60.1", "Anasarca")
            clinical_evidence_header:add_code_link("N26.1", "Atrophic Kidneys")
            clinical_evidence_header:add_abstraction_link("AZOTEMIA", "Azotemia")
            clinical_evidence_header:add_code_link("R57.0", "Cardiogenic Shock")
            clinical_evidence_header:add_code_link("5A1D90Z", "Continuous, Hemodialysis Greater than 18 Hours Per Day")
            clinical_evidence_header:add_code_link("N14.11", "Contrast Induced Nephropathy")
            clinical_evidence_header:add_code_link("T50.8X5A", "Contrast Nephropathy")

            -- 17
            clinical_evidence_header:add_abstraction_link("DECOMPENSATED_HEART_FAILURE", "Decompensated Heart Failure")
            clinical_evidence_header:add_code_link("E86.0", "Dehydration")
            clinical_evidence_header:add_code_link("R41.0", "Disorientation")
            clinical_evidence_header:add_code_link("R53.83", "Fatigue")
            clinical_evidence_header:add_abstraction_link("FLANK_PAIN", "Flank Pain")
            clinical_evidence_header:add_code_link("E87.70", "Fluid Overloaded")
            clinical_evidence_header:add_code_link("M32.14", "Glomerular Disease in SLE")
            clinical_evidence_header:add_code_links(
                { "D59.30", "D59.31", "D59.32", "D59.39" },
                "Hemolytic-Uremic Syndrome"
            )
            clinical_evidence_header:add_code_link("R31.0", "Hematuria")
            clinical_evidence_header:add_abstraction_link("HEMORRHAGE", "Hemorrhage")
            clinical_evidence_header:add_code_link("Z94.0", "History of Kidney Transplant")
            clinical_evidence_header:add_code_link("B20", "HIV")
            clinical_evidence_header:add_abstraction_link("HYDRONEPHROSIS", "Hydronephrosis")
            clinical_evidence_header:add_code_link("N13.4", "Hydroureter")
            clinical_evidence_header:add_code_link("E86.1", "Hypovolemia")
            clinical_evidence_header:add_code_link("R57.1", "Hypovolemic Shock")
            clinical_evidence_header:add_abstraction_link("INCREASED_URINARY_FREQUENCY", "Increased Urinary Frequency")
            clinical_evidence_header:add_code_link("5A1D70Z", "Intermittent Hemodialysis Less than 6 Hours Per Day")
            clinical_evidence_header:add_abstraction_link("KIDNEY_STONES", "Kidney Stones")
            clinical_evidence_header:add_code_link("N20.2", "Kidney and Ureter Stone")
            clinical_evidence_header:add_code_link("N15.9", "Kidney Infection")
            clinical_evidence_header:add_abstraction_link("LOSS_OF_APPETITE", "Loss of Appetite")
            clinical_evidence_header:add_abstraction_link("LOWER_EXTREMITY_EDEMA", "Lower Extremity Edema")
            clinical_evidence_header:add_code_link("N14.3", "Nephropathy induced by Heavy Metals")
            clinical_evidence_header:add_code_link("N14.2", "Nephropathy induced by Unspecified Drug")
            clinical_evidence_header:add_code_prefix_link("^N04%.", "Nephrotic Syndrome")
            clinical_evidence_header:add_code_links(
                { "T39.5X1A", "T39.5X2A", "T39.5X3A", "T39.5X4A" },
                "Poisoning by Aminoglycoside"
            )
            clinical_evidence_header:add_code_links(
                { "T39.391A", "T39.392A", "T39.393A", "T39.394A" },
                "Poisoning by NSAID"
            )
            clinical_evidence_header:add_code_links(
                { "T39.0X1A", "T39.0X2A", "T39.0X3A", "T39.0X4A" },
                "Poisoning by Sulfonamide"
            )
            clinical_evidence_header:add_code_link("5A1D80Z", "Prolonged Intermittent Hemodialysis 6-18 Hours Per Day")
            clinical_evidence_header:add_code_link("R80.9", "Proteinuria")
            clinical_evidence_header:add_code_link("M62.82", "Rhabdomyolysis")
            clinical_evidence_header:add_code_prefix_link("^A40%.", "Sepsis")
            clinical_evidence_header:add_code_prefix_link("^A41%.", "Sepsis")
            clinical_evidence_header:add_code_links({ "R57.8", "R57.9" }, "Shock")
            clinical_evidence_header:add_abstraction_link("SHORTNESS_OF_BREATH", "Shortness of Breath")
            clinical_evidence_header:add_code_link("N14.4", "Toxic Nephropathy")
            clinical_evidence_header:add_code_link("N12", "Tubulo-Interstital Nephritis")
            clinical_evidence_header:add_code_link("M32.15", "Tubulo-Interstitial Nephropathy in SLE")
            clinical_evidence_header:add_code_link("N20.1", "Ureter Stone")
            clinical_evidence_header:add_abstraction_link("URINE_OUTPUT", "Urine Output")
            clinical_evidence_header:add_code_link("E86.9", "Volume Depletion")
            clinical_evidence_header:add_code_link("R11.10", "Vomiting")
            clinical_evidence_header:add_code_link("R11.11", "Vomiting without Nausea")
            clinical_evidence_header:add_code_link("R28.0", "Ischemia/Infarction of Kidney")
            clinical_evidence_header:add_abstraction_link("URINARY_PAIN", "Urinary Pain")
            -- Labs
            clinical_evidence_header:add_abstraction_link("BASELINE_CREATININE", "Baseline Creatinine")
            clinical_evidence_header:add_abstraction_link(
                "BASELINE_GLOMERULAR_FILTRATION_RATE",
                "Baseline Glomerular Filtration Rate"
            )
            clinical_evidence_header:add_discrete_value_many_links(
                dv_urine_sodium,
                "Urine Sodium Concentration",
                10,
                calc_urine_sodium2
            )
            clinical_evidence_header:add_discrete_value_many_links(
                dv_urine_sodium,
                "Urine Sodium Concentration",
                10,
                calc_urine_sodium1
            )
            -- Lab Sub Categories
            dv_look_up_all_values_single_line(
                dv_serum_creatinine,
                0,
                creatinine_header,
                "Serum Creatinine: (DATE1 - DATE2) - "
            )
            if not creatinine_spec_check then
                creatinine_header:add_discrete_value_many_links(
                    dv_serum_creatinine,
                    "Serum Creatinine",
                    10,
                    calc_serum_creatinine1
                )
            end
            dv_look_up_all_values_single_line(
                dv_glomerular_filtration_rate,
                0,
                gfr_header,
                "Glomerular Filtration: (DATE1 - DATE2) - "
            )
            if gfr_dv then
                for _, entry in ipairs(gfr_dv) do
                    gfr_header:add_link(entry)
                end
            end
            dv_look_up_all_values_single_line(
                dv_serum_blood_urea_nitrogen,
                0,
                bun_header,
                "Serum Blood Urea Nitrogen: (DATE1 - DATE2) - "
            )
            bun_header:add_discrete_value_many_links(
                dv_serum_blood_urea_nitrogen,
                "Serum Blood Urea Nitrogen",
                10,
                calc_serum_blood_urea_nitrogen1
            )

            -- Meds
            treatment_and_monitoring_header:add_medication_link("Albumin", "Albumin")
            treatment_and_monitoring_header:add_abstraction_link_with_value(
                "AVOID_NEPHROTOXIC_AGENT",
                "Avoid Nephrotoxic Agent"
            )
            treatment_and_monitoring_header:add_medication_link("Bumetanide", "Bumetanide")
            treatment_and_monitoring_header:add_abstraction_link("BUMETANIDE", "Bumetanide")
            treatment_and_monitoring_header:add_medication_link("Diuretic", "Diuretic")
            treatment_and_monitoring_header:add_abstraction_link("DIURETIC", "Diuretic")
            treatment_and_monitoring_header:add_medication_link("Fluid Bolus", "Fluid Bolus")
            treatment_and_monitoring_header:add_abstraction_link("FLUID_BOLUS", "Fluid Bolus")
            treatment_and_monitoring_header:add_medication_link("Furosemide", "Furosemide")
            treatment_and_monitoring_header:add_abstraction_link("FUROSEMIDE", "Furosemide")

            -- Vitals
            vital_signs_intake_header:add_discrete_value_one_of_link(dv_temperature, "Temperature", calc_temperature1)
            vital_signs_intake_header:add_discrete_value_one_of_link(dv_map, "Mean Arterial Pressure", calc_map1)
            vital_signs_intake_header:add_discrete_value_one_of_link(dv_urinary, "Urine Output", calc_urinary1)
            vital_signs_intake_header:add_discrete_value_one_of_link(dv_sbp, "Systolic Blood Pressure", calc_sbp1)
        end



        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        compile_links()
    end
end
