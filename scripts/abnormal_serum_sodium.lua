---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Abnormal Serum Sodium
---
--- This script checks an account to see if it matches the criteria for a abnormal serum sodium alert.
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
local bloodGlucoseDvNames = { "GLUCOSE (mg/dL)", "GLUCOSE" }
local bloodGlucosePredicate = function(dv) return GetDvValueNumber(dv) > 600 end
local blooGlucosePocDvNames = { "GLUCOSE ACCUCHECK (mg/dL)" }
local bloodGlucosePocPredicate = function(dv) return GetDvValueNumber(dv) > 600 end
local glasgowComaScaleDvNames = { "3.5 Neuro Glasgow Score" }
local glasgowComaScalePredicate = function(dv) return GetDvValueNumber(dv) < 15 end
local dvSerumSodiumNames = { "SODIUM (mmol/L)" }
local dvSerumSodiumVeryLowPredicate = function(dv) return GetDvValueNumber(dv) < 131 end
local dvSerumSodiumLowPredicate = function(dv) return GetDvValueNumber(dv) < 132 end
local dvSerumSodiumHighPredicate = function(dv) return GetDvValueNumber(dv) > 144 end
local dvSerumSodiumVeryHighPredicate = function(dv) return GetDvValueNumber(dv) > 145 end
local dextroseMedicationName = "Dextrose 5% in Water"
local hypertonicSalineMedicationName = "Hypertonic Saline"
local hypotonicSolutionMedicationName = "Hypotonic Solution"
local bothCodesAssignedSubtitle = "SIADH and Hyponatermia Both Assigned Seek Clarification"
local possibleHypernatermiaSubtitle = "Possible Hypernatremia Dx"
local possibleHyponatermiaSubtitle = "Possible Hyponatremia Dx"

local existingAlert = GetExistingCdiAlert { scriptName = ScriptName }
local subtitle = existingAlert and existingAlert.subtitle or nil



if not existingAlert or not existingAlert.validated then
    --------------------------------------------------------------------------------
    --- Alert Variables 
    --------------------------------------------------------------------------------



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    local e870CodeLink = GetCodeLinks { code = "E870", text = "Hyperosmolality and Hypernatremia", seq = 12 }
    local e871CodeLink = GetCodeLinks { code = "E871", text = "Hypoosmolality and Hyponatremia", seq = 14 }
    local e222CodeLink = GetCodeLinks { code = "E222", text = "SIADGH", seq = 20 }

    local veryLowSodiumLinks = GetDiscreteValueLinks {
        dvNames = dvSerumSodiumNames,
        predicate = dvSerumSodiumVeryLowPredicate,
        text = "Serum Sodium",
        seq = 2
    }
    local lowSodiumLinks = GetDiscreteValueLinks {
        dvNames = dvSerumSodiumNames,
        predicate = dvSerumSodiumLowPredicate,
        text = "Serum Sodium",
        seq = 1
    }
    local highSodiumLinks = GetDiscreteValueLinks {
        dvNames = dvSerumSodiumNames,
        predicate = dvSerumSodiumHighPredicate,
        text = "Serum Sodium",
        seq = 3
    }
    local veryHighSodiumLinks = GetDiscreteValueLinks {
        dvNames = dvSerumSodiumNames,
        predicate = dvSerumSodiumVeryHighPredicate,
        text = "Serum Sodium",
        seq = 4
    }
    local dextroseMedicationLink = GetMedicationLinks { cat = dextroseMedicationName, text = "Dextrose", seq = 1 }
    local dextroseAbstractLink = GetAbstractionLinks { code = "DEXTROSE_5_IN_WATER", text = "Dextrose", seq = 2 }
    local fluidRestrictionAbstractionLink = GetAbstractionLinks { code = "FLUID_RESTRICTION", text = "Fluid Restriction", seq = 3 }
    local hypertonicSalineMedicationLink = GetMedicationLinks { cat = hypertonicSalineMedicationName, text = "Hypertonic Saline", seq = 4 }
    local hypertonicSalineAbstractLink = GetAbstractionLinks { code = "HYPERTONIC_SALINE", text = "Hypertonic Saline", seq = 5 }
    local hypotonicSolutionMedicationLink = GetMedicationLinks { cat = hypotonicSolutionMedicationName, text = "Hypotonic Solution", seq = 6 }
    local hypotonicSolutionAbstractLink = GetAbstractionLinks { code = "HYPOTONIC_SOLUTION", text = "Hypotonic Solution", seq = 7 }

    -- Auto resolve SIADH and Hyponatremia both being assigned
    if
        subtitle == bothCodesAssignedSubtitle and
        not Account.is_diagnosis_code_in_working_history("E22.2") and
        not Account.is_diagnosis_code_in_working_history("E87.1")
    then
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to code no longer being assigned"
        Result.passed = true
        Result.validated = true

    -- Auto resolve Possible Hypernatremia Dx
    elseif subtitle == possibleHypernatermiaSubtitle and e870CodeLink then
        e870CodeLink.link_text = "Autoresolved Code - " .. e870CodeLink.link_text
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to code no longer being assigned"
        Result.passed = true
        Result.validated = true

    -- Auto resolve Possible Hyponatremia Dx
    elseif subtitle == possibleHyponatermiaSubtitle and e871CodeLink then
        e871CodeLink.link_text = "Autoresolved Code - " .. e871CodeLink.link_text
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to code no longer being assigned"
        Result.passed = true
        Result.validated = true

    -- Auto resolve Hyponatremeia Lacking Supporting Evidence

    -- Auto resolve Hypernatremia Lacking Supporting Evidence


    end


    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        local resultLinks = {}
        local labsHeader = MakeHeaderLink("Laboratory Studies")
        local labsLinks = {}
        local clinicalEvidenceHeader = MakeHeaderLink("Clinical Evidence")
        local clinicalEvidenceLinks = {}
        local treatmentAndMonitoringHeader = MakeHeaderLink("Treatment and Monitoring")
        local treatmentAndMonitoringLinks = {}
        local otherHeader = MakeHeaderLink("Other")
        local otherLinks = {}
        local serumSodiumHeader = MakeHeaderLink("Serum Sodium")
        local serumSodiumLinks = {}

        if Result.validated then
            -- Autoclose
        else
            -- Normal Alert
        end

        if #labsLinks > 0 then
            labsHeader.links = labsLinks
            table.insert(resultLinks, labsHeader)
        end
        if #clinicalEvidenceLinks > 0 then
            clinicalEvidenceHeader.links = clinicalEvidenceLinks
            table.insert(resultLinks, clinicalEvidenceHeader)
        end
        if #treatmentAndMonitoringLinks > 0 then
            treatmentAndMonitoringHeader.links = treatmentAndMonitoringLinks
            table.insert(resultLinks, treatmentAndMonitoringHeader)
        end
        if #otherLinks > 0 then
            otherHeader.links = otherLinks
            table.insert(resultLinks, otherHeader)
        end
        if #serumSodiumLinks > 0 then
            serumSodiumHeader.links = serumSodiumLinks
            table.insert(resultLinks, serumSodiumHeader)
        end

        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        if existingAlert then
            resultLinks = MergeLinks(existingAlert.links, resultLinks)
        end
        Result.links = resultLinks
    end
end

