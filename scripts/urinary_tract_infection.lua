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
local headers = require "libs.common.headers" (Account)

--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }

--- @diagnostic disable: unused-local
local function numeric_result_predicate(discrete_value, num)
    return discrete_value.result ~= nil and string.find(discrete_value.name, "%d+") ~= nil
end

local function presence_predicate(discrete_value, num)
    local normalized_case = string.lower(discrete_value.name)
    return discrete_value.result ~= nil
        and string.find(normalized_case, "negative") == nil
        and string.find(normalized_case, "trace") == nil
        and string.find(normalized_case, "not found") == nil
end
--- @diagnostic enable: unused-local



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
        links.get_code_links { codes = { "T83.510A", "T83.511A", "T83.512A", "T83.518" }, text = "UTI with Device Link Codes" }
    local n390 = links.get_code_link { code = "N39.0", text = "Urinary Tract Infection" }
    local r8271 = links.get_code_link { code = "R82.71", text = "Bacteriuria" }
    local r8279 = links.get_code_link { code = "R82.79", text = "Positive Urine Culture" }
    local r8281 = links.get_code_link { code = "R82.81", text = "Pyuria" }

    local urine_culture = links.get_discrete_value_link {
        discreteValueName = "BACTERIA (/HPF)",
        text = "Urine Culture",
        ---@diagnostic disable-next-line: unused-local
        predicate = function(dv, num)
            return dv.result ~= nil and
                (string.find(dv.result, "positive") ~= nil or string.find(dv.result, "negative") ~= nil)
        end,
    }
    local urine_bacteria = links.get_discrete_value_link {
        discreteValueName = "BACTERIA (/HPF)",
        text = "UA Bacteria",
        predicate = numeric_result_predicate,
    }

    local chronic_cystostomy_catheter_abstraction_link =
        links.get_abstraction_value_links { code = "CHRONIC_CYSTOSTOMY_CATHETER", text = "Cystostomy Catheter" }
    local cystostomy_catheter_abstraction_link =
        links.get_abstraction_value_links { code = "CYSTOSTOMY_CATHETER", text = "Cystostomy Catheter" }
    local chronic_indwelling_urethral_catheter_abstraction_link =
        links.get_abstraction_value_links { code = "CHRONIC_INDWELLING_URETHRAL_CATHETER", text = "Indwelling Urethral Catheter" }
    local indwelling_urethral_catheter_abstraction_link =
        links.get_abstraction_value_links { code = "INDWELLING_URETHRAL_CATHETER", text = "Indwelling Urethral Catheter" }
    local chronic_nephrostomy_catheter_abstraction_link =
        links.get_abstraction_value_links { code = "CHRONIC_NEPHROSTOMY_CATHETER", text = "Nephrostomy Catheter" }
    local nephrostomy_catheter_abstraction_link =
        links.get_abstraction_value_links { code = "NEPHROSTOMY_CATHETER", text = "Nephrostomy Catheter" }
    local self_catheterization_abstraction_link =
        links.get_abstraction_value_links { code = "SELF_CATHETERIZATION", text = "Self Catheterization" }
    local straight_catheterization_abstraction_link =
        links.get_abstraction_value_links { code = "STRAIGHT_CATHETERIZATION", text = "Straight Catheterization" }
    local chronic_urinary_drainage_device_abstraction_link =
        links.get_abstraction_value_links { code = "CHRONIC_OTHER_URINARY_DRAINAGE_DEVICE", text = "Urinary Drainage Device" }
    local urinary_drainage_device_abstraction_link =
        links.get_abstraction_value_links { code = "OTHER_URINARY_DRAINAGE_DEVICE", text = "Urinary Drainage Device" }
    local chronic_ureteral_stent_abstraction_link =
        links.get_abstraction_value_links { code = "CHRONIC_URETERAL_STENT", text = "Ureteral Stent" }
    local ureteral_stent_abstraction_link =
        links.get_abstraction_value_links { code = "URETERAL_STENT", text = "Ureteral Stent" }



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------

    --------------------------------------------------------------------------------
    --- Adds several links to the `documented_dx_header` and returns whether any of
    --- the parameters were non-nil.
    ---
    ---@param ... CdiAlertLink[]?
    ---
    ---@return boolean
    --------------------------------------------------------------------------------
    local function add_many_dx_links(...)
        local had_non_nil = false
        for _, lnks in pairs { ... } do
            if lnks ~= nil then
                for _, link in ipairs(lnks) do
                    documented_dx_header:add_link(link)
                end
                had_non_nil = true
            end
        end
        return had_non_nil
    end

    if #account_alert_codes > 0 then
        local code = account_alert_codes[1]
        local code_desc = alert_code_dictionary[code]
        local auto_resolved_code_link = links.get_code_link { code = code, text = "Autoresolved Specified Code - " .. code_desc, seq = 1 }
        documented_dx_header:add_link(auto_resolved_code_link)

        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true
    elseif uti_code == nil and n390 ~= nil then
        if add_many_dx_links(chronic_cystostomy_catheter_abstraction_link, cystostomy_catheter_abstraction_link) then
            documented_dx_header:add_link(n390)
            Result.subtitle = "UTI Dx Possible Link To Cystostomy Catheter"
            Result.passed = true
        elseif add_many_dx_links(chronic_indwelling_urethral_catheter_abstraction_link, indwelling_urethral_catheter_abstraction_link) then
            documented_dx_header:add_link(n390)
            Result.subtitle = "UTI Dx Possible Link To Indwelling Urethral Catheter"
            Result.passed = true
        elseif add_many_dx_links(chronic_nephrostomy_catheter_abstraction_link, nephrostomy_catheter_abstraction_link) then
            documented_dx_header:add_link(n390)
            Result.subtitle = "UTI Dx Possible Link To Nephrostomy Catheter"
            Result.passed = true
            -- #5
        elseif add_many_dx_links(chronic_urinary_drainage_device_abstraction_link, urinary_drainage_device_abstraction_link) then
            documented_dx_header:add_link(n390)
            Result.subtitle = "UTI Dx Possible Link To Other Urinary Drainage Device"
            Result.passed = true
            -- #6
        elseif add_many_dx_links(chronic_ureteral_stent_abstraction_link, ureteral_stent_abstraction_link) then
            documented_dx_header:add_link(n390)
            Result.subtitle = "UTI Dx Possible Link To Ureteral Stent"
            Result.passed = true
            -- #7
        elseif add_many_dx_links(self_catheterization_abstraction_link, straight_catheterization_abstraction_link) then
            documented_dx_header:add_link(n390)
            Result.subtitle = "UTI Dx Possible Link To Intermittent Catheterization"
            Result.passed = true
        end
    elseif urine_culture or r8271 or r8279 or r8281 or urine_bacteria then
        if n390 == nil then
            if add_many_dx_links(chronic_cystostomy_catheter_abstraction_link) then
                Result.subtitle = "Possible UTI with Possible Link to Cystostomy Catheter"
                Result.passed = true
            elseif add_many_dx_links(chronic_indwelling_urethral_catheter_abstraction_link) then
                Result.subtitle = "Possible UTI With Possible Link to Indwelling Urethral Catheter"
                Result.passed = true
            elseif add_many_dx_links(chronic_nephrostomy_catheter_abstraction_link) then
                Result.subtitle = "Possible UTI With Possible Link to Nephrostomy Catheter"
                Result.passed = true
            elseif add_many_dx_links(chronic_urinary_drainage_device_abstraction_link) then
                Result.subtitle = "Possible UTI With Possible Link to Other Urinary Drainage Device"
                Result.passed = true
            end
        elseif add_many_dx_links(chronic_ureteral_stent_abstraction_link, ureteral_stent_abstraction_link) then
            add_many_dx_links(urine_bacteria)
            add_many_dx_links(r8271)
            Result.subtitle = "Possible UTI with Possible Link to Ureteral Stent"
            Result.passed = true
        elseif add_many_dx_links(self_catheterization_abstraction_link, straight_catheterization_abstraction_link) then
            add_many_dx_links(urine_bacteria)
            add_many_dx_links(r8271)
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
        ---@diagnostic disable-next-line: unused-local
        clinical_evidence_header:add_discrete_value_link("BLOOD", "Blood in Urine", function(dv, num) return num > 0 end)

        -- Why is this discrete value name empty?
        ---@diagnostic disable-next-line: unused-local
        laboratory_studies_header:add_discrete_value_link("", "Pus in Urine", function(dv, num) return num > 0 end)
        laboratory_studies_header:add_link(urine_culture)
        ---@diagnostic disable-next-line: unused-local
        laboratory_studies_header:add_discrete_value_link("WBC (10x3/ul)", "WBC", function(dv, num) return num > 11 end)

        laboratory_studies_header:add_medication_link("Antibiotic", "Antibiotic")
        laboratory_studies_header:add_medication_link("Antibiotic2", "Antibiotic")
        laboratory_studies_header:add_abstraction_link_with_value("ANTIBIOTIC", "Antibiotic")
        laboratory_studies_header:add_abstraction_link_with_value("ANTIBIOTIC_2", "Antibiotic")
        laboratory_studies_header:add_code_link("0T25X0Z", "Nephrostomy Tube Exchange")
        laboratory_studies_header:add_code_link("0T2BX0Z", "Suprapubic/Foley Catheter Exchange")

        local r4182 = links.get_code_link { code = "R41.82", text = "Altered Level Of Consciousness" }
        local altered_level_of_consciousness = links.get_abstraction_value_link { code = "ALTERED_LEVEL_OF_CONSCIOUSNESS", text = "Altered Level Of Consciousness" }
        if r4182 ~= nil then
            vital_signs_header:add_link(r4182)
            if altered_level_of_consciousness ~= nil then
                altered_level_of_consciousness.hidden = true
            end
        end
        vital_signs_header:add_link(altered_level_of_consciousness)
        ---@diagnostic disable: unused-local
        vital_signs_header:add_discrete_value_link("3.5 Neuro Glasgow Score", "Glasgow Coma Score",
            function(dv, num) return num < 15 end)
        vital_signs_header:add_discrete_value_link("Temperature Degrees C 3.5 (degrees C)", "Temperature",
            function(dv, num) return num > 38.3 end)
        ---@diagnostic enable: unused-local

        urinary_devices_header:add_link(urine_bacteria)
        urinary_devices_header:add_discrete_value_link("BLOOD", "UA Blood", numeric_result_predicate)
        urinary_devices_header:add_discrete_value_link("", "UA Gran Cast", numeric_result_predicate)
        urinary_devices_header:add_discrete_value_link("PROTEIN (mg/dL)", "UA Protein", numeric_result_predicate)
        ---@diagnostic disable: unused-local
        urinary_devices_header:add_discrete_value_link("RBC/HPF (/HPF)", "UA RBC", function(dv, num) return num > 3 end)
        urinary_devices_header:add_discrete_value_link("WBC/HPF (/HPF)", "UA WBC", function(dv, num) return num > 5 end)
        urinary_devices_header:add_discrete_value_link("", "UA Squamous Epithelias", function(dv, num)
            if dv.result == nil then return false end
            local a, b = string.match(dv.result, "(%d+)-(%d+)")
            return tonumber(a) > 20 or tonumber(b) > 20
        end)
        ---@diagnostic enable: unused-local
        urinary_devices_header:add_discrete_value_link("HYALINE CASTS (/LPF)", "UA Hyaline Casts", presence_predicate)
        urinary_devices_header:add_discrete_value_link("LEAK ESTERASE", "UA Leak Esterase", presence_predicate)



        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        compile_links()
    end
end
