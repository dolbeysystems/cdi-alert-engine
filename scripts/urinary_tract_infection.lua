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
require("libs.common")



--------------------------------------------------------------------------------
--- Setup
--------------------------------------------------------------------------------
local alert_subtitle = "Urinary Tract Infection"

local existing_alert = GetExistingCdiAlert { scriptName = ScriptName }
local subtitle = existing_alert and existing_alert.subtitle or nil

local function numeric_result_predicate(discrete_value)
    return discrete_value.name ~= nil and string.find(discrete_value.name, "%d+") ~= nil
end

if not existing_alert or not existing_alert.validated then
    local result_links = {}
    local documented_dx_header = MakeHeaderLink("Documented Dx")
    local documented_dx_links = {}
    local clinical_evidence_header = MakeHeaderLink("Clinical Evidence")
    local clinical_evidence_links = {}
    local treatment_and_monitoring_header = MakeHeaderLink("Treatment and Monitoring")
    local treatment_and_monitoring_links = {}
    local urinary_devices_header = MakeHeaderLink("Treatment and Monitoring")
    local urinary_devices_links = {}
    local laboratory_studies_header = MakeHeaderLink("Treatment and Monitoring")
    local laboratory_studies_links = {}
    local vital_signs_header = MakeHeaderLink("Treatment and Monitoring")
    local vitals_sign_links = {}
    local other_header = MakeHeaderLink("Treatment and Monitoring")
    local other_links = {}
    local urine_analysis_header = MakeHeaderLink("Treatment and Monitoring")
    local urine_analysis_links = {}

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
    local account_alert_codes = GetAccountCodesInDictionary(Account, alert_code_dictionary)

    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    local uti_code = GetCodeLinks {
        codes = { "T83.510A", "T83.511A", "T83.512A", "T83.518" },
        text = "UTI with Device Link Codes",
        sequence = 1,
    }
    local n390 = GetCodeLink { code = "N39.0", text = "Urinary Tract Infection" }
    local r8271 = GetCodeLink { code = "R82.71", text = "Bacteriuria", sequence = 1 }
    local r8279 = GetCodeLink { code = "R82.79", text = "Positive Urine Culture", sequence = 7 }
    local r8281 = GetCodeLink { code = "R82.81", text = "Pyuria", sequence = 8 }

    local urine_culture = GetDiscreteValueLink {
        discreteValueName = "BACTERIA (/HPF)",
        linkText = "Urine Culture",
        sequence = 4,
        predicate = function(discrete_value)
            return discrete_value.result ~= nil and
                (string.find(discrete_value.result, "positive") ~= nil or string.find(discrete_value.result, "negative") ~= nil)
        end,
    }
    local urine_bacteria = GetDiscreteValueLink {
        discreteValueName = "BACTERIA (/HPF)",
        linkText = "UA Bacteria",
        sequence = 1,
        predicate = numeric_result_predicate,
    }

    local chronic_cystostomy_catheter_abstraction_link = GetAbstractionValueLinks {
        code = "CHRONIC_CYSTOSTOMY_CATHETER",
        text = "Cystostomy Catheter",
        seq = 1
    }
    local cystostomy_catheter_abstraction_link = GetAbstractionValueLinks {
        code = "CYSTOSTOMY_CATHETER",
        text = "Cystostomy Catheter",
        seq = 2
    }
    local chronic_indwelling_urethral_catheter_abstraction_link = GetAbstractionValueLinks {
        code = "CHRONIC_INDWELLING_URETHRAL_CATHETER",
        text = "Indwelling Urethral Catheter",
        seq = 3
    }
    local indwelling_urethral_catheter_abstraction_link = GetAbstractionValueLinks {
        code = "INDWELLING_URETHRAL_CATHETER",
        text = "Indwelling Urethral Catheter",
        seq = 4
    }
    local chronic_nephrostomy_catheter_abstraction_link = GetAbstractionValueLinks {
        code = "CHRONIC_NEPHROSTOMY_CATHETER",
        text = "Nephrostomy Catheter",
        seq = 5
    }
    local nephrostomy_catheter_abstraction_link = GetAbstractionValueLinks {
        code = "NEPHROSTOMY_CATHETER",
        text = "Nephrostomy Catheter",
        seq = 6
    }
    local self_catheterization_abstraction_link = GetAbstractionValueLinks {
        code = "SELF_CATHETERIZATION",
        text = "Self Catheterization",
        seq = 7
    }
    local straight_catheterization_abstraction_link = GetAbstractionValueLinks {
        code = "STRAIGHT_CATHETERIZATION",
        text = "Straight Catheterization",
        seq = 8
    }
    local chronic_urinary_drainage_device_abstraction_link = GetAbstractionValueLinks {
        code = "CHRONIC_OTHER_URINARY_DRAINAGE_DEVICE",
        text = "Urinary Drainage Device",
        seq = 9
    }
    local urinary_drainage_device_abstraction_link = GetAbstractionValueLinks {
        code = "OTHER_URINARY_DRAINAGE_DEVICE",
        text = "Urinary Drainage Device",
        seq = 10
    }
    local chronic_ureteral_stent_abstraction_link = GetAbstractionValueLinks {
        code = "CHRONIC_URETERAL_STENT",
        text = "Ureteral Stent",
        seq = 11
    }
    local ureteral_stent_abstraction_link = GetAbstractionValueLinks {
        code = "URETERAL_STENT",
        text = "Ureteral Stent",
        seq = 12
    }

    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------

    --- This function returns false if all of its parameters are nil,
    --- in order to make it usable as a condition.
    ---@param ... CdiAlertLink[]?
    ---@return boolean
    local function add_links(...)
        local had_non_nil = false
        for _, links in pairs { ... } do
            if links ~= nil then
                for _, link in ipairs(links) do
                    table.insert(documented_dx_links, link)
                end
                had_non_nil = true
            end
        end
        return had_non_nil
    end

    if #account_alert_codes > 0 then
        local code = account_alert_codes[1]
        local code_desc = alert_code_dictionary[code]
        local auto_resolved_code_link = GetCodeLink { code = code, text = "Autoresolved Specified Code - " .. code_desc, seq = 1 }
        table.insert(documented_dx_links, auto_resolved_code_link)

        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true
    elseif uti_code == nil and n390 ~= nil then
        if add_links(chronic_cystostomy_catheter_abstraction_link, cystostomy_catheter_abstraction_link) then
            table.insert(documented_dx_links, n390)
            Result.subtitle = "UTI Dx Possible Link To Cystostomy Catheter"
            Result.passed = true
        elseif add_links(chronic_indwelling_urethral_catheter_abstraction_link, indwelling_urethral_catheter_abstraction_link) then
            table.insert(documented_dx_links, n390)
            Result.subtitle = "UTI Dx Possible Link To Indwelling Urethral Catheter"
            Result.passed = true
        elseif add_links(chronic_nephrostomy_catheter_abstraction_link, nephrostomy_catheter_abstraction_link) then
            table.insert(documented_dx_links, n390)
            Result.subtitle = "UTI Dx Possible Link To Nephrostomy Catheter"
            Result.passed = true
            -- #5
        elseif add_links(chronic_urinary_drainage_device_abstraction_link, urinary_drainage_device_abstraction_link) then
            table.insert(documented_dx_links, n390)
            Result.subtitle = "UTI Dx Possible Link To Other Urinary Drainage Device"
            Result.passed = true
            -- #6
        elseif add_links(chronic_ureteral_stent_abstraction_link, ureteral_stent_abstraction_link) then
            table.insert(documented_dx_links, n390)
            Result.subtitle = "UTI Dx Possible Link To Ureteral Stent"
            Result.passed = true
            -- #7
        elseif add_links(self_catheterization_abstraction_link, straight_catheterization_abstraction_link) then
            table.insert(documented_dx_links, n390)
            Result.subtitle = "UTI Dx Possible Link To Intermittent Catheterization"
            Result.passed = true
        end
    elseif urine_culture or r8271 or r8279 or r8281 or urine_bacteria then
        if n390 == nil then
            if add_links(chronic_cystostomy_catheter_abstraction_link) then
                Result.subtitle = "Possible UTI with Possible Link to Cystostomy Catheter"
                Result.passed = true
            elseif add_links(chronic_indwelling_urethral_catheter_abstraction_link) then
                Result.subtitle = "Possible UTI With Possible Link to Indwelling Urethral Catheter"
                Result.passed = true
            elseif add_links(chronic_nephrostomy_catheter_abstraction_link) then
                Result.subtitle = "Possible UTI With Possible Link to Nephrostomy Catheter"
                Result.passed = true
            elseif add_links(chronic_urinary_drainage_device_abstraction_link) then
                Result.subtitle = "Possible UTI With Possible Link to Other Urinary Drainage Device"
                Result.passed = true
            end
        elseif add_links(chronic_ureteral_stent_abstraction_link, ureteral_stent_abstraction_link) then
            add_links(urine_bacteria)
            add_links(r8271)
            Result.subtitle = "Possible UTI with Possible Link to Ureteral Stent"
            Result.passed = true
        elseif add_links(self_catheterization_abstraction_link, straight_catheterization_abstraction_link) then
            add_links(urine_bacteria)
            add_links(r8271)
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
        local result_links = {}

        if Result.validated then
            -- Autoclose
        else
            -- Normal Alert
        end



        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        if existing_alert then
            result_links = MergeLinks(existing_alert.links, result_links)
        end
        Result.links = result_links
    end
end
