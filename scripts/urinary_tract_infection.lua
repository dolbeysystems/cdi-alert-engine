---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Urinary Tract Infection
---
--- This script checks an account to see if it matches the criteria for a Urinary Tract Infection alert.
---
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
---------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Requires
--------------------------------------------------------------------------------
local alerts = require "libs.common.alerts" (Account)
local links = require "libs.common.basic_links" (Account)
local codes = require "libs.common.codes" (Account)
local discrete = require "libs.common.discrete_values" (Account)
local headers = require "libs.common.headers" (Account)



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }



--------------------------------------------------------------------------------
--- Script Specific Functions
--------------------------------------------------------------------------------
local function numeric_result_predicate(dv, num_)
    return dv.result ~= nil and string.find(dv.name, "%d+") ~= nil
end

local function presence_predicate(dv, num_)
    local normalized_case = string.lower(dv.name)
    return dv.result ~= nil
        and string.find(normalized_case, "negative") == nil
        and string.find(normalized_case, "trace") == nil
        and string.find(normalized_case, "not found") == nil
end



if not existing_alert or not existing_alert.validated then
    --------------------------------------------------------------------------------
    --- Header Variables and Helper Functions
    --------------------------------------------------------------------------------
    local result_links = {}
    local documented_dx_header = headers.make_header_builder("Documented Dx", 1)
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 2)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 3)
    local urinary_devices_header = headers.make_header_builder("Urinary Device(s)", 4)
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 5)
    local vital_signs_header = headers.make_header_builder("Vital Signs/Intake and Output Data", 6)
    local urine_analysis_header = headers.make_header_builder("Urine Analysis", 7)

    local function compile_links()
        laboratory_studies_header:add_link(urine_analysis_header:build(true))

        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))
        table.insert(result_links, urinary_devices_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, vital_signs_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end



    --------------------------------------------------------------------------------
    --- Alert Variables
    --------------------------------------------------------------------------------
    local alert_code_dictionary = {
        ["T83.510A"] = "Infection And Inflammatory Reaction Due To Cystostomy Catheter",
        ["T83.510D"] = "Infection And Inflammatory Reaction Due To Cystostomy Catheter",
        ["T83.510S"] = "Infection And Inflammatory Reaction Due To Cystostomy Catheter",
        ["T83.511A"] = "Infection And Inflammatory Reaction Due To Indwelling Urethral Catheter",
        ["T83.511D"] = "Infection And Inflammatory Reaction Due To Indwelling Urethral Catheter",
        ["T83.511S"] = "Infection And Inflammatory Reaction Due To Indwelling Urethral Catheter",
        ["T83.512A"] = "Infection And Inflammatory Reaction Due To Nephrostomy Catheter",
        ["T83.512D"] = "Infection And Inflammatory Reaction Due To Nephrostomy Catheter",
        ["T83.512S"] = "Infection And Inflammatory Reaction Due To Nephrostomy Catheter",
        ["T83.518A"] = "Infection And Inflammatory Reaction Due To Other Urinary Catheter",
        ["T83.518D"] = "Infection And Inflammatory Reaction Due To Other Urinary Catheter",
        ["T83.518S"] = "Infection And Inflammatory Reaction Due To Other Urinary Catheter"
    }
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    local uti_code =
        codes.make_code_links({ "T83.510A", "T83.511A", "T83.512A", "T83.518" }, "UTI with Device Link Codes")
    local n390 = codes.make_code_link("N39.0", "Urinary Tract Infection")
    local r8271 = codes.make_code_link("R82.71", "Bacteriuria")
    local r8279 = codes.make_code_link("R82.79", "Positive Urine Culture")
    local r8281 = codes.make_code_link("R82.81", "Pyuria")

    local urine_culture = discrete.make_discrete_value_link({ "BACTERIA (/HPF)" }, "Urine Culture", discrete.make_match_predicate { "positive", "negative" })
    local urine_bacteria = discrete.make_discrete_value_link({ "BACTERIA (/HPF)" }, "UA Bacteria", numeric_result_predicate)

    local chronic_cystostomy_catheter_abstraction_link = codes.make_abstraction_link_with_value("CHRONIC_CYSTOSTOMY_CATHETER", "Cystostomy Catheter")
    local cystostomy_catheter_abstraction_link = codes.make_abstraction_link_with_value("CYSTOSTOMY_CATHETER", "Cystostomy Catheter")
    local chronic_indwelling_urethral_catheter_abstraction_link = codes.make_abstraction_link_with_value("CHRONIC_INDWELLING_URETHRAL_CATHETER", "Indwelling Urethral Catheter")
    local indwelling_urethral_catheter_abstraction_link = codes.make_abstraction_link_with_value("INDWELLING_URETHRAL_CATHETER", "Indwelling Urethral Catheter")
    local chronic_nephrostomy_catheter_abstraction_link = codes.make_abstraction_link_with_value("CHRONIC_NEPHROSTOMY_CATHETER", "Nephrostomy Catheter")
    local nephrostomy_catheter_abstraction_link = codes.make_abstraction_link_with_value("NEPHROSTOMY_CATHETER", "Nephrostomy Catheter")
    local self_catheterization_abstraction_link = codes.make_abstraction_link_with_value("SELF_CATHETERIZATION", "Self Catheterization")
    local straight_catheterization_abstraction_link = codes.make_abstraction_link_with_value("STRAIGHT_CATHETERIZATION", "Straight Catheterization")
    local chronic_urinary_drainage_device_abstraction_link = codes.make_abstraction_link_with_value("CHRONIC_OTHER_URINARY_DRAINAGE_DEVICE", "Urinary Drainage Device")
    local urinary_drainage_device_abstraction_link = codes.make_abstraction_link_with_value("OTHER_URINARY_DRAINAGE_DEVICE", "Urinary Drainage Device")
    local chronic_ureteral_stent_abstraction_link = codes.make_abstraction_link_with_value("CHRONIC_URETERAL_STENT", "Ureteral Stent")
    local ureteral_stent_abstraction_link = codes.make_abstraction_link_with_value("URETERAL_STENT", "Ureteral Stent")



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if #account_alert_codes > 0 then
        local code = account_alert_codes[1]
        local code_desc = alert_code_dictionary[code]
        local auto_resolved_code_link = codes.make_code_link(code, "Autoresolved Specified Code - " .. code_desc, 1)
        documented_dx_header:add_link(auto_resolved_code_link)

        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true
    elseif uti_code == nil and n390 ~= nil then
        if documented_dx_header:add_links(chronic_cystostomy_catheter_abstraction_link, cystostomy_catheter_abstraction_link) then
            documented_dx_header:add_link(n390)
            Result.subtitle = "UTI Dx Possible Link To Cystostomy Catheter"
            Result.passed = true
        elseif documented_dx_header:add_links(chronic_indwelling_urethral_catheter_abstraction_link, indwelling_urethral_catheter_abstraction_link) then
            documented_dx_header:add_link(n390)
            Result.subtitle = "UTI Dx Possible Link To Indwelling Urethral Catheter"
            Result.passed = true
        elseif documented_dx_header:add_links(chronic_nephrostomy_catheter_abstraction_link, nephrostomy_catheter_abstraction_link) then
            documented_dx_header:add_link(n390)
            Result.subtitle = "UTI Dx Possible Link To Nephrostomy Catheter"
            Result.passed = true
            -- #5
        elseif documented_dx_header:add_links(chronic_urinary_drainage_device_abstraction_link, urinary_drainage_device_abstraction_link) then
            documented_dx_header:add_link(n390)
            Result.subtitle = "UTI Dx Possible Link To Other Urinary Drainage Device"
            Result.passed = true
            -- #6
        elseif documented_dx_header:add_links(chronic_ureteral_stent_abstraction_link, ureteral_stent_abstraction_link) then
            documented_dx_header:add_link(n390)
            Result.subtitle = "UTI Dx Possible Link To Ureteral Stent"
            Result.passed = true
            -- #7
        elseif documented_dx_header:add_links(self_catheterization_abstraction_link, straight_catheterization_abstraction_link) then
            documented_dx_header:add_link(n390)
            Result.subtitle = "UTI Dx Possible Link To Intermittent Catheterization"
            Result.passed = true
        end
    elseif urine_culture or r8271 or r8279 or r8281 or urine_bacteria then
        if n390 == nil then
            if documented_dx_header:add_link(chronic_cystostomy_catheter_abstraction_link) then
                Result.subtitle = "Possible UTI with Possible Link to Cystostomy Catheter"
                Result.passed = true
            elseif documented_dx_header:add_link(chronic_indwelling_urethral_catheter_abstraction_link) then
                Result.subtitle = "Possible UTI With Possible Link to Indwelling Urethral Catheter"
                Result.passed = true
            elseif documented_dx_header:add_link(chronic_nephrostomy_catheter_abstraction_link) then
                Result.subtitle = "Possible UTI With Possible Link to Nephrostomy Catheter"
                Result.passed = true
            elseif documented_dx_header:add_link(chronic_urinary_drainage_device_abstraction_link) then
                Result.subtitle = "Possible UTI With Possible Link to Other Urinary Drainage Device"
                Result.passed = true
            end
        elseif documented_dx_header:add_links(chronic_ureteral_stent_abstraction_link, ureteral_stent_abstraction_link) then
            documented_dx_header:add_link(urine_bacteria)
            documented_dx_header:add_link(r8271)
            Result.subtitle = "Possible UTI with Possible Link to Ureteral Stent"
            Result.passed = true
        elseif documented_dx_header:add_links(self_catheterization_abstraction_link, straight_catheterization_abstraction_link) then
            documented_dx_header:add_link(urine_bacteria)
            documented_dx_header:add_link(r8271)
            Result.subtitle = "Possible UTI with Possible Link to Intermittent Catheterization"
            Result.passed = true
        end
    elseif #account_alert_codes == 0 and n390 == nil and (urine_culture or urine_bacteria) then --TODO
        Result.subtitle = "Possible UTI"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        clinical_evidence_header:add_link(r8271)
        clinical_evidence_header:add_code_link("R41.0", "Disorientation")
        clinical_evidence_header:add_code_link("R31.0", "Hematuria")
        clinical_evidence_header:add_abstraction_link("INCREASED_URINARY_FREQUENCY", "Increased Urinary Frequency")
        clinical_evidence_header:add_code_link("R82.998", "Positive Urine Analysis")
        clinical_evidence_header:add_code_link("R82.89", "Positive Urine Culture")
        clinical_evidence_header:add_link(r8279)
        clinical_evidence_header:add_link(r8281)
        clinical_evidence_header:add_abstraction_link_with_value("URINARY_PAIN", "Urinary Pain")
        clinical_evidence_header:add_abstraction_link_with_value("UTI_CAUSATIVE_AGENT", "UTI Causative Agent")
        clinical_evidence_header:add_discrete_value_link("BLOOD", "Blood in Urine", function(dv_, num) return num > 0 end)

        -- Why is this discrete value name empty?
        laboratory_studies_header:add_discrete_value_link("", "Pus in Urine", function(dv_, num) return num > 0 end)
        laboratory_studies_header:add_link(urine_culture)
        laboratory_studies_header:add_discrete_value_link("WBC (10x3/ul)", "WBC", function(dv_, num) return num > 11 end)

        laboratory_studies_header:add_medication_link("Antibiotic", "Antibiotic")
        laboratory_studies_header:add_medication_link("Antibiotic2", "Antibiotic")
        laboratory_studies_header:add_abstraction_link_with_value("ANTIBIOTIC", "Antibiotic")
        laboratory_studies_header:add_abstraction_link_with_value("ANTIBIOTIC_2", "Antibiotic")
        laboratory_studies_header:add_code_link("0T25X0Z", "Nephrostomy Tube Exchange")
        laboratory_studies_header:add_code_link("0T2BX0Z", "Suprapubic/Foley Catheter Exchange")

        local r4182 = codes.make_code_link("R41.82", "Altered Level Of Consciousness")
        local altered_level_of_consciousness = codes.make_abstraction_link("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level Of Consciousness")
        if r4182 ~= nil then
            vital_signs_header:add_link(r4182)
            if altered_level_of_consciousness ~= nil then
                altered_level_of_consciousness.hidden = true
            end
        end
        vital_signs_header:add_link(altered_level_of_consciousness)
        vital_signs_header:add_discrete_value_link("3.5 Neuro Glasgow Score", "Glasgow Coma Score", discrete.make_gt_predicate(15))
        vital_signs_header:add_discrete_value_link("Temperature Degrees C 3.5 (degrees C)", "Temperature", discrete.make_gt_predicate(38.3))

        urinary_devices_header:add_link(urine_bacteria)
        urinary_devices_header:add_discrete_value_link("BLOOD", "UA Blood", numeric_result_predicate)
        urinary_devices_header:add_discrete_value_link("", "UA Gran Cast", numeric_result_predicate)
        urinary_devices_header:add_discrete_value_link("PROTEIN (mg/dL)", "UA Protein", numeric_result_predicate)
        urinary_devices_header:add_discrete_value_link("RBC/HPF (/HPF)", "UA RBC", discrete.make_gt_predicate(3))
        urinary_devices_header:add_discrete_value_link("WBC/HPF (/HPF)", "UA WBC", discrete.make_gt_predicate(5))
        urinary_devices_header:add_discrete_value_link("", "UA Squamous Epithelias", function(dv, num_)
            if dv.result == nil then return false end
            local a, b = string.match(dv.result, "(%d+)-(%d+)")
            return tonumber(a) > 20 or tonumber(b) > 20
        end)
        urinary_devices_header:add_discrete_value_link("HYALINE CASTS (/LPF)", "UA Hyaline Casts", presence_predicate)
        urinary_devices_header:add_discrete_value_link("LEAK ESTERASE", "UA Leak Esterase", presence_predicate)



        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        compile_links()
    end
end
