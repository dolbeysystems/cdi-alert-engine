---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Abnormal Serum Potassium
---
--- This script checks an account to see if it matches the criteria for an abnormal serum potassium alert.
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
    local otherHeader = MakeHeaderLink("Other")
    local otherLinks = {}
    local potassiumHeader = MakeHeaderLink("Serum Potassium")
    local potassiumLinks = {}



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    local e875CodeLink = GetCodeLinks { code = "E87.5", text = "Hyperkalemia Fully Specified Code" }
    local e876CodeLink = GetCodeLinks { code = "E87.6", text = "Hypokalemia Fully Specified Code" }

    function GetPotassiumDvLinks (dvPredicate)
        return GetDiscreteValueLinks {
            discreteValueNames = potassiumDvNames,
            text = "Serum Potassium",
            predicate = dvPredicate,
            maxPerValue = 9999,
        } or {}
    end

    local serumPotassiumDvVeryLowLinks = GetPotassiumDvLinks(potassiumVeryLowPredicate)
    local serumPotassiumDvLowLinks = GetPotassiumDvLinks(potassiumLowPredicate)
    local serumPotassiumDvHighLinks = GetPotassiumDvLinks(potassiumHighPredicate)
    local serumPotassiumDvVeryHighLinks = GetPotassiumDvLinks(potassiumVeryHighPredicate)

    local dextroseMedicationLink = GetMedicationLinks {
        cat = dextroseMedicationName,
        text = "Dextrose",
        seq = 1,
    }
    local hemodialysisCodesLink = GetCodeLinks {
        codes = { "5A1D70Z", "5A1D80Z", "5A1D90Z" },
        text = "Hemodialysis",
        seq = 2,
    }
    local insulinMedicationLink = GetMedicationLinks {
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
    local kayexalateMedLink = GetMedicationLinks { cat = kayexalateMedicationName, text = "Kayexalate", seq = 4 }
    local potassiumReplacementMedLink = GetMedicationLinks { cat = potassiumReplacementMedicationName, text = "Potassium Replacement", seq = 5 }
    local potassiumChlorideAbsLink = GetAbstractionValueLinks { code = "POTASSIUM_CHLORIDE", text = "Potassium Chloride Absorption", seq = 6 }
    local potassiumPhosphateAbsLink = GetAbstractionValueLinks { code = "POTASSIUM_PHOSPHATE", text = "Potassium Phosphate Absorption", seq = 7 }
    local potassiumBiCarbonateAbsLink = GetAbstractionValueLinks { code = "POTASSIUM_BICARBONATE", text = "Potassium Bicarbonate Absorption", seq = 8 }



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
        #hemodialysisCodesLink > 1
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
            GetCodeLinks { code = "E27.1", text = "Addison's Disease", target = clinicalEvidenceLinks }
            GetCodeLinks { code = "E24.0", text = "Cushing's Syndrome", target = clinicalEvidenceLinks }
            GetCodeLinks { code = "E24.1", text = "Cushing's Syndrome", target = clinicalEvidenceLinks }
            GetCodeLinks { code = "E24.2", text = "Cushing's Syndrome", target = clinicalEvidenceLinks }
            GetCodeLinks { code = "E24.3", text = "Cushing's Syndrome", target = clinicalEvidenceLinks }
            GetCodeLinks { code = "E24.4", text = "Cushing's Syndrome", target = clinicalEvidenceLinks }
            GetCodeLinks { code = "E24.8", text = "Cushing's Syndrome", target = clinicalEvidenceLinks }
            GetCodeLinks { code = "E24.9", text = "Cushing's Syndrome", target = clinicalEvidenceLinks }
            GetAbstractionLinks { code = "DIARRHEA", text = "Diarrhea", target = clinicalEvidenceLinks }
            GetAbstractionLinks { code = "HYPERKALEMIA_EKG_CHANGES", text = "EKG Changes", target = clinicalEvidenceLinks }
            GetAbstractionLinks { code = "HYPOKALEMIA_EKG_CHANGES", text = "EKG Changes", target = clinicalEvidenceLinks }
            GetCodeLinks { code = "R53.83", text = "Fatigue", target = clinicalEvidenceLinks }
            GetAbstractionLinks { code = "HEART_PALPITATIONS", text = "Heart Palpitations", target = clinicalEvidenceLinks }
            GetCodeLinks {
                codes = {
                    "N17.0", "N17.1", "N17.2", "N18.30", "N18.31", "N18.32",
                    "N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4",
                    "N18.5", "N18.6"
                },
                text = "Kidney Failure",
                target = clinicalEvidenceLinks
            }
            GetAbstractionLinks { code = "MUSCLE_CRAMPS", text = "Muscle Cramps", target = clinicalEvidenceLinks }
            GetAbstractionLinks { code = "WEAKNESS", text = "Muscle Weakness", target = clinicalEvidenceLinks }
            GetAbstractionLinks { code = "VOMITING", text = "Vomiting", target = clinicalEvidenceLinks }

            table.insert(treatmentAndMonitoringLinks, dextroseMedicationLink)
            table.insert(treatmentAndMonitoringLinks, hemodialysisCodesLink)
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
        if #otherLinks > 0 then
            otherHeader.links = otherLinks
            table.insert(resultLinks, otherHeader)
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
