---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Abnormal Serum Potassium
---
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
---
--- This script checks an account to see if it matches the criteria for an abnormal serum potassium alert.
---
--- Alerts:
---     - Possible Hyperkalemia Dx
---         Triggered if there are no hyperkalemia codes on the account and there is account potassium value
---         greater than 5.4 mmol/L within the last 7 days and there is evidence of kayexalate or insulin and dextrose
---         or hemodialysis
---         
---         Autoresolved if there is a hyperkalemia code on the account
--- 
---     - Possible Hypokalemia Dx
---         Triggered if there are no hypokalemia codes on the account and there is account potassium value
---         less than 3.1 mmol/L within the last 7 days and there is evidence of potassium replacement or potassium
---         chloride absorption or potassium phosphate absorption or potassium bicarbonate absorption
--- 
---        Autoresolved if there is a hypokalemia code on the account
--- 
---     - Hyperkalemia Dx Documented Possibly Lacking Supporting Evidence
---         Triggered if there is a hyperkalemia code on the account and there are no account potassium values greater
---         than 5.1 mmol/L within the last 7 days
--- 
---         Autoresolved if there is a hyperkalemia code on the account and there is at least one account potassium value
---         greater than 5.1 mmol/L within the last 7 days
--- 
---     - Hypokalemia Dx Documented Possibly Lacking Supporting Evidence
---         Triggered if there is a hypokalemia code on the account and there are no account potassium values less than
---         3.4 mmol/L within the last 7 days
--- 
---         Autoresolved if there is a hypokalemia code on the account and there is at least one account potassium value
---         less than 3.4 mmol/L within the last 7 days
--- 
--- Possible Links:
---     - Documented Dx 
---         - Autoresolved Specified Code - Hyperkalemia Fully Specified Code (Code)
---         - Autoresolved Specified Code - Hypokalemia Fully Specified Code (Code)
---         - Hyperkalemia Fully Specified Code (Code)
---         - Hypokalemia Fully Specified Code (Code)
---    - Laboratory Studies
---         - Review High Serum Potassium Levels (Discrete Value)
---         - Review Low Serum Potassium Levels (Discrete Value)
---     - Clinical Evidence
---         - Addison's Disease (Code)
---         - Cushing's Syndrome (Code)
---         - Diarrhea (Abstraction)
---         - EKG Changes (Abstraction)
---         - Fatigue (Code)
---         - Heart Palpitations (Abstraction)
---         - Kidney Failure (Code)
---         - Muscle Cramps (Abstraction)
---         - Muscle Weakness (Abstraction)
---         - Vomiting (Abstraction)
---    - Treatment and Monitoring
---         - Dextrose (Medication)
---         - Hemodialysis (Code)
---         - Insulin (Medication)
---         - Kayexalate (Medication)
---         - Potassium Replacement (Medication)
---         - Potassium Chloride Absorption (Abstraction)
---         - Potassium Phosphate Absorption (Abstraction)
---         - Potassium Bicarbonate Absorption (Abstraction)
---   - Serum Potassium
---         - Serum Potassium (Discrete Value) [Multiple]
---------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Requires 
--------------------------------------------------------------------------------
require("libs.common")



--------------------------------------------------------------------------------
--- Setup
--------------------------------------------------------------------------------
local potassiumDvNames = { "POTASSIUM (mmol/L)" }
local potassiumVeryLowPredicate = function (dv)
    return GetDvValueNumber(dv) < 3.1 and DateIsLessThanXDaysAgo(dv.result_date, 7)
end
local potassiumLowPredicate = function (dv)
    return GetDvValueNumber(dv) < 3.4 and DateIsLessThanXDaysAgo(dv.result_date, 7)
end
local potassiumHighPredicate = function (dv)
    return GetDvValueNumber(dv) > 5.1 and DateIsLessThanXDaysAgo(dv.result_date, 7)
end
local potassiumVeryHighPredicate = function (dv)
    return GetDvValueNumber(dv) > 5.4 and DateIsLessThanXDaysAgo(dv.result_date, 7)
end
local dextroseMedicationName = "Dextrose 5% In Water"
local insulinMedicationName = "Insulin"
local kayexalateMedicationName = "Kayexalate"
local potassiumReplacementMedicationName = "Potassium Replacement"
local possibleHyperkalemiaSubtitle = "Possible Hyperkalemia Dx"
local possibleHypokalemiaSubtitle = "Possible Hypokalemia Dx"
local hyperkalemiaLackingSupportingEvidenceSubtitle = "Hyperkalemia Dx Documented Possibly Lacking Supporting Evidence"
local hypokalemiaLackingSupportingEvidenceSubtitle = "Hypokalemia Dx Documented Possibly Lacking Supporting Evidence"
local reviewHighPotassiumLinkText = "Possible No High Serum Potassium Levels Were Found Please Review"
local reviewLowPotassiumLinkText = "Possible No Low Serum Potassium Levels Were Found Please Review"

local existingAlert = GetExistingCdiAlert { scriptName = ScriptName }
local subtitle = existingAlert and existingAlert.subtitle or nil



if not existingAlert or not existingAlert.validated then
    --------------------------------------------------------------------------------
    --- Top-Level Link Header Variables
    --------------------------------------------------------------------------------
    local resultLinks = {}
    local documentedDxHeader = MakeHeaderLink("Documented Dx")
    local documentedDxLinks = {}
    local laboratoryStudiesHeader = MakeHeaderLink("Laboratory Studies")
    local laboratoryStudiesLinks = {}
    local clinicalEvidenceHeader = MakeHeaderLink("Clinical Evidence")
    local clinicalEvidenceLinks = {}
    local treatmentAndMonitoringHeader = MakeHeaderLink("Treatment and Monitoring")
    local treatmentAndMonitoringLinks = {}
    local potassiumHeader = MakeHeaderLink("Serum Potassium")
    local potassiumLinks = {}



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    local e875CodeLink = GetCodeLink { code = "E87.5", text = "Hyperkalemia Fully Specified Code" }
    local e876CodeLink = GetCodeLink { code = "E87.6", text = "Hypokalemia Fully Specified Code" }

    function GetPotassiumDvLinks (dvPredicate)
        return GetDiscreteValueLinks {
            discreteValueNames = potassiumDvNames,
            text = "Serum Potassium",
            predicate = dvPredicate,
        }
    end

    local serumPotassiumDvVeryLowLinks = GetPotassiumDvLinks(potassiumVeryLowPredicate)
    local serumPotassiumDvLowLinks = GetPotassiumDvLinks(potassiumLowPredicate)
    local serumPotassiumDvHighLinks = GetPotassiumDvLinks(potassiumHighPredicate)
    local serumPotassiumDvVeryHighLinks = GetPotassiumDvLinks(potassiumVeryHighPredicate)

    local dextroseMedicationLink = GetMedicationLink {
        cat = dextroseMedicationName,
        text = "Dextrose",
        seq = 1,
    }
    local hemodialysisCodesLinks = GetCodeLinks {
        codes = { "5A1D70Z", "5A1D80Z", "5A1D90Z" },
        text = "Hemodialysis",
        seq = 2,
    }
    local insulinMedicationLink = GetMedicationLink {
        cat = insulinMedicationName,
        text = "Insulin",
        predicate = function(med)
            local route_appropriate = med.route ~= nil and (string.find(med.route, "%bIntravenous%b") ~= nil  or string.find(med.route, "%bIV Push%b") ~= nil)
            local dosage = med.dosage and tonumber(string.gsub(med.dosage, "[^%d.]", ""))
            return (
                route_appropriate and
                dosage ~= nil and dosage == 10 and
                DateIsLessThanXDaysAgo(med.start_date, 365)
            )
        end,
        seq = 3,
    }
    local kayexalateMedLink = GetMedicationLink { cat = kayexalateMedicationName, text = "Kayexalate", seq = 4 }
    local potassiumReplacementMedLink = GetMedicationLink { cat = potassiumReplacementMedicationName, text = "Potassium Replacement", seq = 5 }
    local potassiumChlorideAbsLink = GetAbstractionValueLink { code = "POTASSIUM_CHLORIDE", text = "Potassium Chloride Absorption", seq = 6 }
    local potassiumPhosphateAbsLink = GetAbstractionValueLink { code = "POTASSIUM_PHOSPHATE", text = "Potassium Phosphate Absorption", seq = 7 }
    local potassiumBiCarbonateAbsLink = GetAbstractionValueLink { code = "POTASSIUM_BICARBONATE", text = "Potassium Bicarbonate Absorption", seq = 8 }



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    -- Auto resolve Hyperkalemia alert
    if subtitle == possibleHyperkalemiaSubtitle and e875CodeLink then
        e875CodeLink.link_text = "Autoresolved Code - " .. e875CodeLink.link_text
        table.insert(documentedDxLinks, e875CodeLink)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    -- Auto resolve Hypokalemia alert
    elseif subtitle == possibleHypokalemiaSubtitle and e876CodeLink then
        e876CodeLink.link_text = "Autoresolved Code - " .. e876CodeLink.link_text
        table.insert(documentedDxLinks, e876CodeLink)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    -- Auto resolve Hyperkalemia possibly lacking supporting evidence
    elseif subtitle == hyperkalemiaLackingSupportingEvidenceSubtitle and e875CodeLink and #serumPotassiumDvHighLinks > 1  then
        e875CodeLink.link_text = "Autoresolved Evidence - " .. e875CodeLink.link_text
        table.insert(documentedDxLinks, e875CodeLink)
        for _, link in ipairs(serumPotassiumDvHighLinks) do
            link.link_text = "Autoresolved Evidence - " .. link.link_text
            table.insert(potassiumLinks, link)
        end
        local reviewHighPotassiumLink = MakeHeaderLink(reviewHighPotassiumLinkText)
        reviewHighPotassiumLink.is_validated = false
        table.insert(laboratoryStudiesLinks, reviewHighPotassiumLink)

        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.validated = true
        Result.passed = true

    -- Auto resolve Hypokalemia possibly lacking supporting evidence
    elseif subtitle == hypokalemiaLackingSupportingEvidenceSubtitle and e876CodeLink and #serumPotassiumDvLowLinks > 1 then
        e876CodeLink.link_text = "Autoresolved Evidence - " .. e876CodeLink.link_text
        table.insert(documentedDxLinks, e876CodeLink)
        for _, link in ipairs(serumPotassiumDvLowLinks) do
            link.link_text = "Autoresolved Evidence - " .. link.link_text
            table.insert(potassiumLinks, link)
        end
        local reviewLowPotassiumLink = MakeHeaderLink(reviewLowPotassiumLinkText)
        reviewLowPotassiumLink.is_validated = false
        table.insert(laboratoryStudiesLinks, reviewLowPotassiumLink)

        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.validated = true
        Result.passed = true

    -- Create Hyperkalemia alert
    elseif not e875CodeLink and #serumPotassiumDvVeryHighLinks > 1 and (
        kayexalateMedLink or
        (insulinMedicationLink and dextroseMedicationLink) or
        #hemodialysisCodesLinks > 1
    ) then
        for _, link in ipairs(serumPotassiumDvHighLinks) do
            table.insert(potassiumLinks, link)
        end
        Result.subtitle = possibleHyperkalemiaSubtitle
        Result.passed = true

    -- Create Hypokalemia alert
    elseif not e876CodeLink and #serumPotassiumDvVeryLowLinks > 1 and (
        potassiumReplacementMedLink or
        potassiumChlorideAbsLink or
        potassiumPhosphateAbsLink or
        potassiumBiCarbonateAbsLink
    ) then
        for _, link in ipairs(serumPotassiumDvLowLinks) do
            table.insert(potassiumLinks, link)
        end
        Result.subtitle = possibleHypokalemiaSubtitle
        Result.passed = true

    -- Create alert for Hyperkalemia coded, but lacking evidence in labs
    elseif e875CodeLink and #serumPotassiumDvHighLinks == 0 then
        table.insert(documentedDxLinks, e875CodeLink)
        local reviewHighPotassiumLink = MakeHeaderLink(reviewHighPotassiumLinkText)
        table.insert(laboratoryStudiesLinks, reviewHighPotassiumLink)
        Result.subtitle = hyperkalemiaLackingSupportingEvidenceSubtitle
        Result.passed = true

    -- Create alert for Hypokalemia coded, but lacking evidence in labs, medications or abstractions
    elseif
        e876CodeLink and
        #serumPotassiumDvLowLinks == 0 and
        not potassiumReplacementMedLink and
        not potassiumChlorideAbsLink and
        not potassiumPhosphateAbsLink and
        not potassiumBiCarbonateAbsLink
    then
        table.insert(documentedDxLinks, e876CodeLink)
        local reviewLowPotassiumLink = MakeHeaderLink(reviewLowPotassiumLinkText)
        table.insert(laboratoryStudiesLinks, reviewLowPotassiumLink)
        Result.subtitle = hyperkalemiaLackingSupportingEvidenceSubtitle
        Result.passed = true

    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Additional Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            GetCodeLink { code = "E27.1", text = "Addison's Disease", target = clinicalEvidenceLinks }
            GetCodeLink { code = "E24.0", text = "Cushing's Syndrome", target = clinicalEvidenceLinks }
            GetCodeLink { code = "E24.1", text = "Cushing's Syndrome", target = clinicalEvidenceLinks }
            GetCodeLink { code = "E24.2", text = "Cushing's Syndrome", target = clinicalEvidenceLinks }
            GetCodeLink { code = "E24.3", text = "Cushing's Syndrome", target = clinicalEvidenceLinks }
            GetCodeLink { code = "E24.4", text = "Cushing's Syndrome", target = clinicalEvidenceLinks }
            GetCodeLink { code = "E24.8", text = "Cushing's Syndrome", target = clinicalEvidenceLinks }
            GetCodeLink { code = "E24.9", text = "Cushing's Syndrome", target = clinicalEvidenceLinks }
            GetAbstractionLink { code = "DIARRHEA", text = "Diarrhea", target = clinicalEvidenceLinks }
            GetAbstractionLink { code = "HYPERKALEMIA_EKG_CHANGES", text = "EKG Changes", target = clinicalEvidenceLinks }
            GetAbstractionLink { code = "HYPOKALEMIA_EKG_CHANGES", text = "EKG Changes", target = clinicalEvidenceLinks }
            GetCodeLink { code = "R53.83", text = "Fatigue", target = clinicalEvidenceLinks }
            GetAbstractionLink { code = "HEART_PALPITATIONS", text = "Heart Palpitations", target = clinicalEvidenceLinks }
            GetCodeLinks {
                codes = {
                    "N17.0", "N17.1", "N17.2", "N18.30", "N18.31", "N18.32",
                    "N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4",
                    "N18.5", "N18.6"
                },
                text = "Kidney Failure",
                target = clinicalEvidenceLinks
            }
            GetAbstractionLink { code = "MUSCLE_CRAMPS", text = "Muscle Cramps", target = clinicalEvidenceLinks }
            GetAbstractionLink { code = "WEAKNESS", text = "Muscle Weakness", target = clinicalEvidenceLinks }
            GetAbstractionLink { code = "VOMITING", text = "Vomiting", target = clinicalEvidenceLinks }

            table.insert(treatmentAndMonitoringLinks, dextroseMedicationLink)
            table.insert(treatmentAndMonitoringLinks, hemodialysisCodesLinks)
            table.insert(treatmentAndMonitoringLinks, insulinMedicationLink)
            table.insert(treatmentAndMonitoringLinks, kayexalateMedLink)
            table.insert(treatmentAndMonitoringLinks, potassiumReplacementMedLink)
            table.insert(treatmentAndMonitoringLinks, potassiumChlorideAbsLink)
            table.insert(treatmentAndMonitoringLinks, potassiumPhosphateAbsLink)
            table.insert(treatmentAndMonitoringLinks, potassiumBiCarbonateAbsLink)
        end



        --------------------------------------------------------------------------------
        --- Result Finalization 
        --------------------------------------------------------------------------------
        if #documentedDxHeader.links > 0 then
            table.insert(resultLinks, documentedDxHeader)
        end
        if #laboratoryStudiesLinks > 0 then
            laboratoryStudiesHeader.links = laboratoryStudiesLinks
            table.insert(resultLinks, laboratoryStudiesHeader)
        end
        if #clinicalEvidenceLinks > 0 then
            clinicalEvidenceHeader.links = clinicalEvidenceLinks
            table.insert(resultLinks, clinicalEvidenceHeader)
        end
        if #treatmentAndMonitoringLinks > 0 then
            treatmentAndMonitoringHeader.links = treatmentAndMonitoringLinks
            table.insert(resultLinks, treatmentAndMonitoringHeader)
        end
        if #potassiumLinks > 0 then
            potassiumHeader.links = potassiumLinks
            table.insert(resultLinks, potassiumHeader)
        end
        if existingAlert then
            resultLinks = MergeLinks(existingAlert.links, resultLinks)
        end
        Result.links = resultLinks
    end
end
