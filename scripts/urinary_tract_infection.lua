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
local alerts = require("libs.common.alerts")
local links = require("libs.common.basic_links")
local codes = require("libs.common.codes")
local discrete = require("libs.common.discrete_values")


--------------------------------------------------------------------------------
--- Setup
--------------------------------------------------------------------------------

local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }

local function numeric_result_predicate(discrete_value)
    return discrete_value.result ~= nil and string.find(discrete_value.name, "%d+") ~= nil
end

local function presence_predicate(discrete_value)
    local normalized_case = string.lower(discrete_value.name)
    return discrete_value.result ~= nil
        and string.find(normalized_case, "negative") == nil
        and string.find(normalized_case, "trace") == nil
        and string.find(normalized_case, "not found") == nil
end

if not existing_alert or not existing_alert.validated then
    local result_links = {}
    local documented_dx_header = links.make_header_link("Documented Dx")
    local documented_dx_links = {}
    local clinical_evidence_header = links.make_header_link("Clinical Evidence")
    local clinical_evidence_links = {}
    local treatment_and_monitoring_header = links.make_header_link("Treatment and Monitoring")
    local treatment_and_monitoring_links = {}
    local urinary_devices_header = links.make_header_link("Urinary Device(s)")
    local urinary_devices_links = {}
    local laboratory_studies_header = links.make_header_link("Laboratory Studies")
    local laboratory_studies_links = {}
    local vital_signs_header = links.make_header_link("Vital Signs/Intake and Output Data")
    local vital_signs_links = {}
    local urine_analysis_header = links.make_header_link("Urine Analysis")
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
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)

    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    local uti_code = links.get_code_links {
        codes = { "T83.510A", "T83.511A", "T83.512A", "T83.518" },
        text = "UTI with Device Link Codes",
        sequence = 1,
    }
    local n390 = links.get_code_link { code = "N39.0", text = "Urinary Tract Infection" }
    local r8271 = links.get_code_link { code = "R82.71", text = "Bacteriuria", sequence = 1 }
    local r8279 = links.get_code_link { code = "R82.79", text = "Positive Urine Culture", sequence = 7 }
    local r8281 = links.get_code_link { code = "R82.81", text = "Pyuria", sequence = 8 }

    local urine_culture = links.get_discrete_value_link {
        discreteValueName = "BACTERIA (/HPF)",
        linkText = "Urine Culture",
        sequence = 4,
        predicate = function(dv)
            return dv.result ~= nil and
                (string.find(dv.result, "positive") ~= nil or string.find(dv.result, "negative") ~= nil)
        end,
    }
    local urine_bacteria = links.get_discrete_value_link {
        discreteValueName = "BACTERIA (/HPF)",
        linkText = "UA Bacteria",
        sequence = 1,
        predicate = numeric_result_predicate,
    }

    local chronic_cystostomy_catheter_abstraction_link = links.get_abstraction_value_links {
        code = "CHRONIC_CYSTOSTOMY_CATHETER",
        text = "Cystostomy Catheter",
        seq = 1
    }
    local cystostomy_catheter_abstraction_link = links.get_abstraction_value_links {
        code = "CYSTOSTOMY_CATHETER",
        text = "Cystostomy Catheter",
        seq = 2
    }
    local chronic_indwelling_urethral_catheter_abstraction_link = links.get_abstraction_value_links {
        code = "CHRONIC_INDWELLING_URETHRAL_CATHETER",
        text = "Indwelling Urethral Catheter",
        seq = 3
    }
    local indwelling_urethral_catheter_abstraction_link = links.get_abstraction_value_links {
        code = "INDWELLING_URETHRAL_CATHETER",
        text = "Indwelling Urethral Catheter",
        seq = 4
    }
    local chronic_nephrostomy_catheter_abstraction_link = links.get_abstraction_value_links {
        code = "CHRONIC_NEPHROSTOMY_CATHETER",
        text = "Nephrostomy Catheter",
        seq = 5
    }
    local nephrostomy_catheter_abstraction_link = links.get_abstraction_value_links {
        code = "NEPHROSTOMY_CATHETER",
        text = "Nephrostomy Catheter",
        seq = 6
    }
    local self_catheterization_abstraction_link = links.get_abstraction_value_links {
        code = "SELF_CATHETERIZATION",
        text = "Self Catheterization",
        seq = 7
    }
    local straight_catheterization_abstraction_link = links.get_abstraction_value_links {
        code = "STRAIGHT_CATHETERIZATION",
        text = "Straight Catheterization",
        seq = 8
    }
    local chronic_urinary_drainage_device_abstraction_link = links.get_abstraction_value_links {
        code = "CHRONIC_OTHER_URINARY_DRAINAGE_DEVICE",
        text = "Urinary Drainage Device",
        seq = 9
    }
    local urinary_drainage_device_abstraction_link = links.get_abstraction_value_links {
        code = "OTHER_URINARY_DRAINAGE_DEVICE",
        text = "Urinary Drainage Device",
        seq = 10
    }
    local chronic_ureteral_stent_abstraction_link = links.get_abstraction_value_links {
        code = "CHRONIC_URETERAL_STENT",
        text = "Ureteral Stent",
        seq = 11
    }
    local ureteral_stent_abstraction_link = links.get_abstraction_value_links {
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
        for _, lnks in pairs { ... } do
            if lnks ~= nil then
                for _, link in ipairs(lnks) do
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
        local auto_resolved_code_link = links.get_code_link { code = code, text = "Autoresolved Specified Code - " .. code_desc, seq = 1 }
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
        table.insert(clinical_evidence_links, r8271)
        table.insert(clinical_evidence_links,
            links.get_code_link { code = "R41.0", text = "Disorientation", sequence = 2 })
        table.insert(clinical_evidence_links,
            links.get_code_link { code = "R31.0", text = "Hematuria", sequence = 3 })
        table.insert(clinical_evidence_links,
            links.get_abstraction_link { code = "INCREASED_URINARY_FREQUENCY", text = "Increased Urinary Frequency", sequence = 4 })
        table.insert(clinical_evidence_links,
            links.get_code_link { code = "R82.998", text = "Positive Urine Analysis", sequence = 5 })
        table.insert(clinical_evidence_links,
            links.get_code_link { code = "R82.89", text = "Positive Urine Culture", sequence = 6 })
        table.insert(clinical_evidence_links, r8279)
        table.insert(clinical_evidence_links, r8281)
        table.insert(clinical_evidence_links,
            links.get_abstraction_value_link { code = "URINARY_PAIN", text = "Urinary Pain", sequence = 9 })
        table.insert(clinical_evidence_links,
            links.get_abstraction_value_link { code = "UTI_CAUSATIVE_AGENT", text = "UTI Causative Agent", sequence = 0 })
        table.insert(clinical_evidence_links,
            links.get_discrete_value_link {
                discreteValueName = "BLOOD",
                text = "Blood in Urine",
                predicate = function(discrete_value)
                    return discrete.get_dv_value_number(discrete_value) > 0
                end,
                sequence = 1
            }
        )
        -- Why is this discrete value name empty?
        table.insert(laboratory_studies_links,
            links.get_discrete_value_link {
                discreteValueName = "",
                text = "Pus in Urine",
                predicate = function(discrete_value)
                    return discrete.get_dv_value_number(discrete_value) > 0
                end,
                sequence = 2
            }
        )
        table.insert(laboratory_studies_links, urine_culture)
        table.insert(laboratory_studies_links,
            links.get_discrete_value_link {
                discreteValueName = "WBC (10x3/ul)",
                text = "WBC",
                predicate = function(discrete_value)
                    return discrete.get_dv_value_number(discrete_value) > 11
                end,
                sequence = 4
            }
        )
        table.insert(treatment_and_monitoring_links,
            links.get_medication_link { code = "Antibiotic", text = "Antibiotic", sequence = 1 })
        table.insert(treatment_and_monitoring_links,
            links.get_medication_link { code = "Antibiotic2", text = "Antibiotic", sequence = 2 })
        table.insert(treatment_and_monitoring_links,
            links.get_abstraction_value_link { code = "ANTIBIOTIC", text = "Antibiotic", sequence = 3 })
        table.insert(treatment_and_monitoring_links,
            links.get_abstraction_value_link { code = "ANTIBIOTIC_2", text = "Antibiotic", sequence = 4 })
        table.insert(urinary_devices_links,
            links.get_code_link { code = "0T25X0Z", text = "Nephrostomy Tube Exchange", sequence = 5 })
        table.insert(urinary_devices_links,
            links.get_code_link { code = "0T2BX0Z", text = "Suprapubic/Foley Catheter Exchange", sequence = 6 })
        local r4182 = links.get_code_link { code = "R41.82", text = "Altered Level Of Consciousness", sequence = 1 }
        local altered_level_of_consciousness = links.get_abstraction_value_link { code = "ALTERED_LEVEL_OF_CONSCIOUSNESS", text = "Altered Level Of Consciousness", sequence = 2 }
        if r4182 ~= nil then
            table.insert(vital_signs_links, r4182)
            if altered_level_of_consciousness ~= nil then
                altered_level_of_consciousness.hidden = true
            end
        end
        table.insert(vital_signs_links, altered_level_of_consciousness)
        table.insert(vital_signs_links,
            links.get_discrete_value_link {
                discreteValueName = "3.5 Neuro Glasgow Score",
                text = "Glasgow Coma Score",
                predicate = function(discrete_value)
                    return discrete.get_dv_value_number(discrete_value) < 15
                end,
                sequence = 3
            }
        )
        table.insert(vital_signs_links,
            links.get_discrete_value_link {
                discreteValueName = "Temperature Degrees C 3.5 (degrees C)",
                text = "Temperature",
                predicate = function(discrete_value)
                    return discrete.get_dv_value_number(discrete_value) > 38.3
                end,
                sequence = 4
            }
        )
        table.insert(urinary_devices_links, urine_bacteria)

        table.insert(urine_analysis_links, links.get_discrete_value_link {
            discreteValueName = "BLOOD",
            linkText = "UA Blood",
            sequence = 2,
            predicate = numeric_result_predicate,
        })
        table.insert(urine_analysis_links, links.get_discrete_value_link {
            discreteValueName = "",
            linkText = "UA Gran Cast",
            sequence = 3,
            predicate = numeric_result_predicate,
        })
        table.insert(urine_analysis_links, links.get_discrete_value_link {
            discreteValueName = "PROTEIN (mg/dL)",
            linkText = "UA Protein",
            sequence = 6,
            predicate = numeric_result_predicate,
        })
        table.insert(urine_analysis_links, links.get_discrete_value_link {
            discreteValueName = "RBC/HPF (/HPF)",
            linkText = "UA RBC",
            sequence = 7,
            predicate = function(discrete_value)
                return discrete.get_dv_value_number(discrete_value) > 3
            end,
        })
        table.insert(urine_analysis_links, links.get_discrete_value_link {
            discreteValueName = "WBC/HPF (/HPF)",
            linkText = "UA WBC",
            sequence = 7,
            predicate = function(discrete_value)
                return discrete.get_dv_value_number(discrete_value) > 5
            end,
        })
        table.insert(urine_analysis_links, links.get_discrete_value_link {
            discreteValueName = "",
            linkText = "UA Squamous Epithelias",
            sequence = 8,
            predicate = function(discrete_value)
                if discrete_value.result == nil then return false end
                local a, b = string.match(discrete_value.result, "(%d+)-(%d+)")
                return tonumber(a) > 20 or tonumber(b) > 20
            end,
        })
        table.insert(urine_analysis_links, links.get_discrete_value_link {
            discreteValueName = "HYALINE CASTS (/LPF)",
            linkText = "UA Hyaline Casts",
            sequence = 4,
            predicate = presence_predicate,
        })
        table.insert(urine_analysis_links, links.get_discrete_value_link {
            discreteValueName = "LEAK ESTERASE",
            linkText = "UA Leak Esterase",
            sequence = 5,
            predicate = presence_predicate,
        })

        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        -- #If alert passed or alert conditions was triggered add categories to result if they have links
        -- if AlertPassed or AlertConditions:
        --     if urine.Links: labs.Links.Add(urine); urineLinks = True
        --     if dc.Links: result.Links.Add(dc); dcLinks = True
        --     if abs.Links: result.Links.Add(abs); absLinks = True
        --     if labs.Links: result.Links.Add(labs); labsLinks = True
        --     if vitals.Links: result.Links.Add(vitals); vitalsLinks = True
        --     result.Links.Add(meds)
        --     if meds.Links: medsLinks = True
        --     if uti.Links: result.Links.Add(uti); utiLinks = True
        --     result.Links.Add(other)
        --     db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        --         str(result.Validated) + "; Links: Documented Dx- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks) + ", vitals- " + str(vitalsLinks) + ", meds- " + str(medsLinks) + ", Uti- " + str(utiLinks) + ", Urine- "
        --         + str(urineLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
        --     result.Passed = True
        if #urine_analysis_links > 0 then
            urine_analysis_header.links = urine_analysis_links
            table.insert(laboratory_studies_links, urine_analysis_header)
        end
        if #documented_dx_links > 0 then
            documented_dx_header.links = documented_dx_links
            table.insert(result_links, documented_dx_header)
        end
        if #clinical_evidence_links > 0 then
            clinical_evidence_header.links = clinical_evidence_links
            table.insert(result_links, clinical_evidence_header)
        end
        if #laboratory_studies_links > 0 then
            laboratory_studies_header.links = laboratory_studies_links
            table.insert(result_links, laboratory_studies_header)
        end
        if #vital_signs_links > 0 then
            vital_signs_header.links = vital_signs_links
            table.insert(result_links, vital_signs_header)
        end
        if #treatment_and_monitoring_links > 0 then
            treatment_and_monitoring_header.links = treatment_and_monitoring_links
            table.insert(result_links, treatment_and_monitoring_header)
        end
        if #urinary_devices_links > 0 then
            urinary_devices_header.links = urinary_devices_links
            table.insert(result_links, urinary_devices_header)
        end
        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end
end
