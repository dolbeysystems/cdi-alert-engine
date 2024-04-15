---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Abnormal Serum
---
--- This script checks an account to see if it matches the criteria for an abnormal serum alert.
---
--- Date: 4/10/2024
--- Version: 1.0
--- Site: (Default)
---------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Requires 
--------------------------------------------------------------------------------
require("libs.common")
require("libs.standard_cdi")



--------------------------------------------------------------------------------
--- Setup
--------------------------------------------------------------------------------
local alertCodeDictionary = {
    ["E83.51"] = "Hypocalcemia",
    ["E83.52"] = "Hypercalcemia"
}
local accountAlertCodes = GetAccountCodesInDictionary(Account, alertCodeDictionary)
local ionCalciumHeader = MakeHeaderLink("Ionized Calcium")
local serumCalciumHeader = MakeHeaderLink("Serum Calcium")



--------------------------------------------------------------------------------
--- Alert Qualification 
--------------------------------------------------------------------------------
if not ExistingAlert or not ExistingAlert.validated then
    -- Alert Trigger
    local e8351Link = GetAbstractionLinks { text="Hypocalcemia Fully Specified Code" }
    local e8352Link = GetAbstractionLinks { text="Hypercalcemia Fully Specified Code" }

    local serumCalciumHighLinks = GetDiscreteValueLinks {
        text="Serum Calcium",
        discreteValueNames = { "Calcium Lvl (mg/dL)" },
        predicate = function (dv)
            local resultValue = string.gsub(dv.result, "[\\<\\>]", "")
            local _, count = string.gsub(resultValue, "%.", "")
            return count <= 1 and tonumber(resultValue) ~= nil and tonumber(resultValue) >= 10.5
        end,
        maxPerValue = 10
    }

    -- Labs
    local serumCalciumLowLinks = GetDiscreteValueLinks {
        text="Serum Calcium",
        discreteValueNames = { "Calcium Lvl (mg/dL)" },
        predicate = function (dv)
            local resultValue = string.gsub(dv.result, "[\\<\\>]", "")
            local _, count = string.gsub(resultValue, "%.", "")
            return count <= 1 and tonumber(resultValue) ~= nil and tonumber(resultValue) <= 8.4
        end,
        maxPerValue = 10
    }
    local ionizedCalciumLinks = GetDiscreteValueLinks {
        text="Ionized Calcium",
        discreteValueNames = { "Calcium Ionized (mg/dL)" },
        predicate = function (dv)
            local resultValue = string.gsub(dv.result, "[\\<\\>]", "")
            local _, count = string.gsub(resultValue, "%.", "")
            return count <= 1 and tonumber(resultValue) ~= nil and tonumber(resultValue) <= 4.65
        end,
        maxPerValue = 10
    }

    -- Meds
    local bisphosphonateMedLink = GetMedicationLinks { cat="Bisphosphonate", text="Bisphosphonate" }
    local bisphosphonateAbsLink = GetAbstractionLinks { code="BISPHOSPHONATE", text="Bisphosphonate" }
    local calReplacementMedLink = GetMedicationLinks { cat="Calcium Replacement", text="Calcium Replacement" }
    local calCarbonateAbsLink = GetAbstractionLinks { code="CALCIUM_CARBONATE", text="Calcium Carbonate" }
    local calChlorideAbsLink = GetAbstractionLinks { code="CALCIUM_CHLORIDE", text="Calcium Chloride" }
    local calCitrateAbsLink = GetAbstractionLinks { code="CALCIUM_CITRATE", text="Calcium Citrate" }
    local calGluconateAbsLink = GetAbstractionLinks { code="CALCIUM_GLUCONATE", text="Calcium Gluconate" }
    local calLactateAbsLink = GetAbstractionLinks { code="CALCIUM_LACTATE", text="Calcium Lactate" }
    local fluidBolusMedLink = GetMedicationLinks { cat="Fluid Bolus", text="Fluid Bolus" }
    local fluidBolusAbsLink = GetAbstractionLinks { code="FLUID_BOLUS", text="Fluid Bolus" }
    local vdReplacementMedLink = GetMedicationLinks { cat="Vitamin D Replacement", text="Vitamin D Replacement" }
    local vdReplacementAbsLink = GetAbstractionLinks { code="VITAMIN_D_REPLACEMENT", text="Vitamin D Replacement" }

    if (e8352Link and (not ExistingAlert or ExistingAlert.subtitle ~= "Possible Hypercalcemia Dx")) or
       (e8351Link and (not ExistingAlert or ExistingAlert.subtitle ~= "Possible Hypocalcemia Dx"))
    then
        if ExistingAlert then
            AddDocumentationCode("E83.51", "Hypercalcemia", 0)
            AddDocumentationCode("E83.52", "Hypocalcemia", 0)

            Result.outcome = "AUTORESOLVED"
            Result.reason = "Autoresolved due to on Specified Code on the Account"
            Result.validated = true
            AutoResolved = true
        else
            Result.passed = false
        end
    elseif not e8352Link and #serumCalciumHighLinks > 0 and
        (bisphosphonateMedLink or bisphosphonateAbsLink or fluidBolusMedLink or fluidBolusAbsLink) then


        if type(serumCalciumHighLinks) == "table" then
            serumCalciumHeader.links = serumCalciumHighLinks
        else
            serumCalciumHeader.links = { serumCalciumHighLinks }
        end
        Result.subtitle = "Possible Hypercalcemia Dx"
        AlertMatched = true
    elseif not e8351Link and (#serumCalciumLowLinks  > 0 or #ionizedCalciumLinks > 0) and
        (calCarbonateAbsLink or calChlorideAbsLink or calCitrateAbsLink or calGluconateAbsLink or
         calLactateAbsLink or calReplacementMedLink or vdReplacementAbsLink or vdReplacementMedLink) then

        if type(serumCalciumLowLinks) == "table" then
            serumCalciumHeader.links = serumCalciumLowLinks
        else
            serumCalciumHeader.links = { serumCalciumLowLinks }
        end
        if type(ionizedCalciumLinks) == "table" then
            ionCalciumHeader.links = ionizedCalciumLinks
        else
            ionCalciumHeader.links = { ionizedCalciumLinks }
        end
        Result.subtitle = "Possible Hypocalcemia Dx"
        AlertMatched = true
    else
        Result.passed = true
    end
end

if #ionCalciumHeader.links > 0 then
    table.insert(LabsLinks, ionCalciumHeader)
end
if #serumCalciumHeader.links > 0 then
    table.insert(LabsLinks, serumCalciumHeader)
end



--------------------------------------------------------------------------------
--- Additional Link Creation
--------------------------------------------------------------------------------
if AlertMatched then

end



--------------------------------------------------------------------------------
--- Result Finalization 
--------------------------------------------------------------------------------
if AlertMatched or AlertAutoResolved then
    local resultLinks = GetFinalTopLinks({})

    resultLinks = MergeLinksWithExisting(ExistingAlert, resultLinks)
    Result.links = resultLinks
    Result.passed = true
end

