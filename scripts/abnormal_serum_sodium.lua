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
local sodiumDvNames = { "SODIUM (mmol/L)" }
local sodiumVeryLowPredicate = function(dv)
    return GetDvValueNumber(dv) < 131 and DateIsLessThanXDaysAgo(dv.result_date, 7)
end
local sodiumLowPredicate = function(dv)
    return GetDvValueNumber(dv) < 132 and DateIsLessThanXDaysAgo(dv.result_date, 7)
end
local sodiumHighPredicate = function(dv)
    return GetDvValueNumber(dv) > 144 and DateIsLessThanXDaysAgo(dv.result_date, 7)
end
local sodiumVeryHighPredicate = function(dv)
    return GetDvValueNumber(dv) > 145 and DateIsLessThanXDaysAgo(dv.result_date, 7)
end
local dextroseMedicationName = "Dextrose 5% in Water"
local hypertonicSalineMedicationName = "Hypertonic Saline"
local hypotonicSolutionMedicationName = "Hypotonic Solution"
local bothCodesAssignedSubtitle = "SIADH and Hyponatermia Both Assigned Seek Clarification"
local possibleHypernatermiaSubtitle = "Possible Hypernatremia Dx"
local possibleHyponatermiaSubtitle = "Possible Hyponatremia Dx"
local hypernatremiaLackingSupportingEvidenceSubtitle = "Hypernatremia Lacking Supporting Evidence"
local hyponatremiaLackingSupportingEvidenceSubtitle = "Hyponatremia Lacking Supporting Evidence"
local reviewHighSodiumLinkText = "Possible No High Serum Sodium Levels Were Found Please Review"
local reviewLowSodiumLinkText = "Possible No Low Serum Sodium Levels Were Found Please Review"

local existingAlert = GetExistingCdiAlert { scriptName = ScriptName }
local subtitle = existingAlert and existingAlert.subtitle or nil



if not existingAlert or not existingAlert.validated then
    --------------------------------------------------------------------------------
    --- Top-Level Link Header Variables
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



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    local e870CodeLink = GetCodeLinks { code = "E870", text = "Hyperosmolality and Hypernatremia", seq = 12 }
    local e871CodeLink = GetCodeLinks { code = "E871", text = "Hypoosmolality and Hyponatremia", seq = 14 }
    local e222CodeLink = GetCodeLinks { code = "E222", text = "SIADGH", seq = 20 }

    function GetSodiumDvLinks(predicate)
        return GetDiscreteValueLinks {
            dvNames = sodiumDvNames,
            predicate = predicate,
            text = "Serum Sodium",
            maxPerValue = 99999
        } or {}
    end

    local veryLowSodiumLinks = GetSodiumDvLinks(sodiumVeryLowPredicate)
    local lowSodiumLinks = GetSodiumDvLinks(sodiumLowPredicate)
    local highSodiumLinks = GetSodiumDvLinks(sodiumHighPredicate)
    local veryHighSodiumLinks = GetSodiumDvLinks(sodiumVeryHighPredicate)

    local dextroseMedicationLink = GetMedicationLinks { cat = dextroseMedicationName, text = "Dextrose", seq = 1 }
    local dextroseAbstractLink = GetAbstractionLinks { code = "DEXTROSE_5_IN_WATER", text = "Dextrose", seq = 2 }
    local fluidRestrictionAbstractionLink = GetAbstractionLinks { code = "FLUID_RESTRICTION", text = "Fluid Restriction", seq = 3 }
    local hypertonicSalineMedicationLink = GetMedicationLinks { cat = hypertonicSalineMedicationName, text = "Hypertonic Saline", seq = 4 }
    local hypertonicSalineAbstractLink = GetAbstractionLinks { code = "HYPERTONIC_SALINE", text = "Hypertonic Saline", seq = 5 }
    local hypotonicSolutionMedicationLink = GetMedicationLinks { cat = hypotonicSolutionMedicationName, text = "Hypotonic Solution", seq = 6 }
    local hypotonicSolutionAbstractLink = GetAbstractionLinks { code = "HYPOTONIC_SOLUTION", text = "Hypotonic Solution", seq = 7 }



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    -- Auto resolve SIADH and Hyponatremia both being assigned
    if
        subtitle == bothCodesAssignedSubtitle and (
            not Account.is_diagnosis_code_in_working_history("E22.2") or
            not Account.is_diagnosis_code_in_working_history("E87.1")
        )
    then
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to code no longer being assigned"
        Result.passed = true
        Result.validated = true

    -- Auto resolve Possible Hypernatremia Dx
    elseif subtitle == possibleHypernatermiaSubtitle and e870CodeLink then
        e870CodeLink.link_text = "Autoresolved Code - " .. e870CodeLink.link_text
        table.insert(clinicalEvidenceHeader, e870CodeLink)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to code no longer being assigned"
        Result.passed = true
        Result.validated = true

    -- Auto resolve Possible Hyponatremia Dx
    elseif subtitle == possibleHyponatermiaSubtitle and e871CodeLink then
        e871CodeLink.link_text = "Autoresolved Code - " .. e871CodeLink.link_text
        table.insert(clinicalEvidenceHeader, e871CodeLink)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to code no longer being assigned"
        Result.passed = true
        Result.validated = true

    -- Auto resolve Hypernatremeia Lacking Supporting Evidence
    elseif subtitle == hypernatremiaLackingSupportingEvidenceSubtitle and #highSodiumLinks > 0 and e870CodeLink then
        e870CodeLink.link_text = "Autoresolved Code - " .. e870CodeLink.link_text
        table.insert(clinicalEvidenceHeader, e870CodeLink)
        for _, link in ipairs(highSodiumLinks) do
            link.link_text = "Autoresolved Evidence - " .. link.link_text
            table.insert(serumSodiumLinks, link)
        end
        local reviewHighSodiumLink = MakeHeaderLink(reviewHighSodiumLinkText)
        reviewHighSodiumLink.is_validated = false
        table.insert(labsLinks, reviewHighSodiumLink)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.passed = true
        Result.validated = true

    -- Auto resolve Hyponatremia Lacking Supporting Evidence
    elseif subtitle == hyponatremiaLackingSupportingEvidenceSubtitle and #lowSodiumLinks > 0 and e871CodeLink then
        e871CodeLink.link_text = "Autoresolved Code - " .. e871CodeLink.link_text
        table.insert(clinicalEvidenceHeader, e871CodeLink)
        for _, link in ipairs(lowSodiumLinks) do
            link.link_text = "Autoresolved Evidence - " .. link.link_text
            table.insert(serumSodiumLinks, link)
        end
        local reviewLowSodiumLink = MakeHeaderLink(reviewLowSodiumLinkText)
        reviewLowSodiumLink.is_validated = false
        table.insert(labsLinks, reviewLowSodiumLink)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.passed = true
        Result.validated = true

    -- Alert if both SIADH (E22.2) and Hyponatermia (E87.1) are cdi assigned (in working history)
    elseif Account.is_diagnosis_code_in_working_history("E22.2") and Account.is_diagnosis_code_in_working_history("E87.1") then
        Result.subtitle = bothCodesAssignedSubtitle
        Result.passed = true

    -- Alert if possible hypernatremia
    elseif
        not e870CodeLink and
        #veryHighSodiumLinks > 1 and (
            dextroseMedicationLink or
            dextroseAbstractLink or
            hypotonicSolutionMedicationLink or
            hypotonicSolutionAbstractLink
        )
    then
        Result.subtitle = possibleHypernatermiaSubtitle
        Result.passed = true

    -- Alert if possible hyponatremia
    elseif
        not e871CodeLink and
        #veryLowSodiumLinks > 1 and (
            hypertonicSalineMedicationLink or
            hypertonicSalineAbstractLink or
            fluidRestrictionAbstractionLink
        )
    then
        Result.subtitle = possibleHyponatermiaSubtitle
        Result.passed = true

    -- Alert if hypernatremia is lacking supporting evidence
    elseif e870CodeLink and #highSodiumLinks == 0 then
        local reviewHighSodiumLink = MakeHeaderLink(reviewHighSodiumLinkText)
        table.insert(labsLinks, reviewHighSodiumLink)
        Result.subtitle = hypernatremiaLackingSupportingEvidenceSubtitle
        Result.passed = true

    -- Alert if hyponatremia is lacking supporting evidence
    elseif e871CodeLink and #lowSodiumLinks == 0 then
        local reviewLowSodiumLink = MakeHeaderLink(reviewLowSodiumLinkText)
        table.insert(labsLinks, reviewLowSodiumLink)
        Result.subtitle = hyponatremiaLackingSupportingEvidenceSubtitle
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Additional Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            local r4182CodeLink = GetCodeLinks { code = "R41.82", text = "Altered Level of Consciousness", seq = 1 }
            local alteredAbsLink = GetAbstractionLinks { code = "ALTERED_LEVEL_OF_CONSCIOUSNESS", text = "Altered Level of Consciousness", seq = 2 }

            if r4182CodeLink then
                table.insert(clinicalEvidenceHeader, r4182CodeLink)
                if alteredAbsLink then
                    alteredAbsLink.hidden = true
                    table.insert(clinicalEvidenceHeader, alteredAbsLink)
                end
            elseif alteredAbsLink then
                table.insert(clinicalEvidenceHeader, alteredAbsLink)
            end

            GetCodeLinks { code = "F10.230", text = "Beer Potomania", seq = 3, target = clinicalEvidenceHeader }
            GetCodeLinks { code = "R11.14", text = "Bilious Vomiting", seq = 4, target = clinicalEvidenceHeader }
            GetCodeLinks {
                codes = {
                    "I50.21", "I50.22", "I50.23", "I50.31", "I50.32", "I50.33", "I50.41",
                    "I50.42", "I50.43", "I50.811", "I50.812", "I50.813", "I50.814", "I50.82", "I50.83", "I50.84"
                },
                text = "Congestive Heart Failure (CHF)",
                seq = 5,
                target = clinicalEvidenceHeader
            }
            GetCodeLinks { code = "R11.15", text = "Cyclical Vomiting", seq = 6, target = clinicalEvidenceHeader }
            GetAbstractionValueLinks { code = "DIABETES_INSIPIDUS", text = "Diabetes Insipidus", seq = 7, target = clinicalEvidenceHeader }
            GetAbstractionLinks { code = "DIARRHEA", text = "Diarrhea", seq = 8, target = clinicalEvidenceHeader }
            GetCodeLinks { code = "R41.0", text = "Disorientation", seq = 9, target = clinicalEvidenceHeader }
            GetCodeLinks { code = "E86.0", text = "Dehydration", seq = 10, target = clinicalEvidenceHeader }
            GetCodeLinks { code = "R53.83", text = "Fatigue", seq = 11, target = clinicalEvidenceHeader }
            GetAbstractionValueLinks { code = "HYPEROSMOLAR_HYPERGLYCEMIA_SYNDROME", text = "Hyperosmolar Hyperglycemic Syndrome", seq = 13, target = clinicalEvidenceHeader }
            GetCodeLinks { code = "E86.1", text = "Hypovolemia", seq = 15, target = clinicalEvidenceHeader }
            GetCodeLinks {
                codes = {
                    "N17.0", "N17.1", "N17.2", "N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6"
                },
                text = "Kidney Failure",
                seq = 16,
                target = clinicalEvidenceHeader
            }
            GetAbstractionLinks { code = "MUSCLE_CRAMPS", text = "Muscle Cramps", seq = 17, target = clinicalEvidenceHeader }
            GetCodeLinks { code = "R63.1", text = "Polydipsia", seq = 18, target = clinicalEvidenceHeader }
            GetAbstractionLinks { code = "SEIZURE", text = "Seizure", seq = 19, target = clinicalEvidenceHeader }
            GetCodeLinks {
                codes = { "E05.01", "E05.11", "E05.21", "E05.41", "E05.81", "E05.91" },
                text = "Thyrotoxic Crisis Storm Code",
                seq = 21,
                target = clinicalEvidenceHeader
            }
            GetCodeLinks { code = "E86.9", text = "Volume Depletion", seq = 22, target = clinicalEvidenceHeader }
            GetCodeLinks { code = "R11.10", text = "Vomiting", seq = 23, target = clinicalEvidenceHeader }
            GetCodeLinks { code = "R11.13", text = "Vomiting Fecal Matter", seq = 24, target = clinicalEvidenceHeader }
            GetCodeLinks { code = "R11.11", text = "Vomiting Without Nausea", seq = 25, target = clinicalEvidenceHeader }
            GetAbstractionLinks { code = "WEAKNESS", text = "Muscle Weakness", seq = 26, target = clinicalEvidenceHeader }

            if not GetDiscreteValueLinks {
                dvNames = bloodGlucoseDvNames,
                predicate = bloodGlucosePredicate,
                text = "Blood Glucose",
                maxPerValue = 1,
                target = labsHeader
            } then
                GetDiscreteValueLinks {
                    dvNames = blooGlucosePocDvNames,
                    predicate = bloodGlucosePocPredicate,
                    text = "Blood Glucose POC",
                    maxPerValue = 1,
                    target = labsHeader
                }
            end
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
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
        if existingAlert then
            resultLinks = MergeLinks(existingAlert.links, resultLinks)
        end
        Result.links = resultLinks
    end
end

