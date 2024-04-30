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
local ionCalciumHeader = MakeHeaderLink("Ionized Calcium")
local serumCalciumHeader = MakeHeaderLink("Serum Calcium")
local ionCalciumLinks = MakeLinkArray()
local serumCalciumLinks = MakeLinkArray()
local bisphosphonateMedLink = MakeNilLink()
local bisphosphonateAbsLink = MakeNilLink()
local calReplacementMedLink = MakeNilLink()
local calCarbonateAbsLink = MakeNilLink()
local calChlorideAbsLink = MakeNilLink()
local calCitrateAbsLink = MakeNilLink()
local calGluconateAbsLink = MakeNilLink()
local calLactateAbsLink = MakeNilLink()
local fluidBolusMedLink = MakeNilLink()
local fluidBolusAbsLink = MakeNilLink()
local vdReplacementMedLink = MakeNilLink()
local vdReplacementAbsLink = MakeNilLink()



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
            -- CheckDvResultNumber(dv, function(v) return v.result < 90 end)
            return count <= 1 and CheckDvResultNumber(dv, function(v) return v >= 10.5 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
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
            return count <= 1 and CheckDvResultNumber(dv, function(v) return v <= 8.4 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        maxPerValue = 10
    }
    local ionizedCalciumLinks = GetDiscreteValueLinks {
        text="Ionized Calcium",
        discreteValueNames = { "Calcium Ionized (mg/dL)" },
        predicate = function (dv)
            local resultValue = string.gsub(dv.result, "[\\<\\>]", "")
            local _, count = string.gsub(resultValue, "%.", "")
            return count <= 1 and CheckDvResultNumber(dv, function(v) return v <= 4.65 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        maxPerValue = 10
    }

    -- Meds
    bisphosphonateMedLink = GetMedicationLinks { cat="Bisphosphonate", text="Bisphosphonate" }
    bisphosphonateAbsLink = GetAbstractionLinks { code="BISPHOSPHONATE", text="Bisphosphonate" }
    calReplacementMedLink = GetMedicationLinks { cat="Calcium Replacement", text="Calcium Replacement" }
    calCarbonateAbsLink = GetAbstractionLinks { code="CALCIUM_CARBONATE", text="Calcium Carbonate" }
    calChlorideAbsLink = GetAbstractionLinks { code="CALCIUM_CHLORIDE", text="Calcium Chloride" }
    calCitrateAbsLink = GetAbstractionLinks { code="CALCIUM_CITRATE", text="Calcium Citrate" }
    calGluconateAbsLink = GetAbstractionLinks { code="CALCIUM_GLUCONATE", text="Calcium Gluconate" }
    calLactateAbsLink = GetAbstractionLinks { code="CALCIUM_LACTATE", text="Calcium Lactate" }
    fluidBolusMedLink = GetMedicationLinks { cat="Fluid Bolus", text="Fluid Bolus" }
    fluidBolusAbsLink = GetAbstractionLinks { code="FLUID_BOLUS", text="Fluid Bolus" }
    vdReplacementMedLink = GetMedicationLinks { cat="Vitamin D Replacement", text="Vitamin D Replacement" }
    vdReplacementAbsLink = GetAbstractionLinks { code="VITAMIN_D_REPLACEMENT", text="Vitamin D Replacement" }

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
            serumCalciumLinks = serumCalciumHighLinks
        else
            serumCalciumLinks = { serumCalciumHighLinks }
        end
        Result.subtitle = "Possible Hypercalcemia Dx"
        AlertMatched = true
    elseif not e8351Link and (#serumCalciumLowLinks  > 0 or #ionizedCalciumLinks > 0) and
        (calCarbonateAbsLink or calChlorideAbsLink or calCitrateAbsLink or calGluconateAbsLink or
         calLactateAbsLink or calReplacementMedLink or vdReplacementAbsLink or vdReplacementMedLink) then

        if type(serumCalciumLowLinks) == "table" then
            serumCalciumLinks = serumCalciumLowLinks
        else
            serumCalciumLinks = { serumCalciumLowLinks }
        end
        if type(ionizedCalciumLinks) == "table" then
            ionCalciumLinks = ionizedCalciumLinks
        else
            ionCalciumLinks = { ionizedCalciumLinks }
        end
        Result.subtitle = "Possible Hypocalcemia Dx"
        AlertMatched = true
    else
        Result.passed = true
    end
end



--------------------------------------------------------------------------------
--- Additional Link Creation
--------------------------------------------------------------------------------
if AlertMatched then
    -- Abstractions
    AddEvidenceAbs("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level of Consciousness", 1)
    AddEvidenceCode("R11.14", "Bilous Vomiting", 2)
    GetCodeLinks {
        codes = { "N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6" },
        text = "Chronic Kidney Disease",
        seq = 3,
        targetTable = ClinicalEvidenceLinks
    }
    AddEvidenceCode("R11.15", "Cyclic Vomiting", 4)
    AddEvidenceCode("E58", "Dietary Calcium Deficiency", 5)
    AddEvidenceAbs("EXTREME_THIRST", "Excessive Thirst", 6)
    AddEvidenceCode("R53.83", "Fatigue", 7)
    AddEvidenceAbs("HEART_PALPITATIONS", "Heart Palpitations", 8)
    AddEvidenceCode("E21.3", "Hyperparathyroidism", 9)
    AddEvidenceCode("E83.42", "Hypomagnesemia", 10)
    AddEvidenceCode("E20.9", "Hypoparathyroidism", 11)
    AddEvidenceAbs("INCREASED_URINARY_FREQUENCY", "Frequent Urination", 12)
    AddEvidenceAbs("MUSCLE_CRAMPS", "Muscle Cramps", 13)
    AddEvidenceCode("K85.90", "Pancreatitis", 14)
    AddEvidenceCode("R11.12", "Projectile Vomiting", 15)
    AddEvidenceAbs("SEIZURE", "Seizure", 16)
    AddEvidenceCode("E55.9", "Vitamin D Deficiency", 17)
    AddEvidenceCode("R11.10", "Vomiting", 18)
    AddEvidenceCode("R11.13", "Vomiting Fecal Matter", 19)
    AddEvidenceCode("R11.11", "Vomiting Without Nausea", 20)
    AddEvidenceAbs("WEAKNESS", "Weakness", 21)

    -- Labs
    GetAbstractionValueLinks { code = "HIGH_SERUM_CALCIUM", text = "Serum Calcium", targetTable = LabsLinks, seq = 4 }
    GetAbstractionValueLinks { code = "LOW_SERUM_CALCIUM", text = "Serum Calcium", targetTable = LabsLinks, seq = 5 }

    -- Meds
    if bisphosphonateMedLink then table.insert(TreatmentLinks, bisphosphonateMedLink) end
    if bisphosphonateAbsLink then table.insert(TreatmentLinks, bisphosphonateAbsLink) end
    if calReplacementMedLink then table.insert(TreatmentLinks, calReplacementMedLink) end
    if calCarbonateAbsLink then table.insert(TreatmentLinks, calCarbonateAbsLink) end
    if calChlorideAbsLink then table.insert(TreatmentLinks, calChlorideAbsLink) end
    if calCitrateAbsLink then table.insert(TreatmentLinks, calCitrateAbsLink) end
    if calGluconateAbsLink then table.insert(TreatmentLinks, calGluconateAbsLink) end
    if calLactateAbsLink then table.insert(TreatmentLinks, calLactateAbsLink) end
    if fluidBolusMedLink then table.insert(TreatmentLinks, fluidBolusMedLink) end
    if fluidBolusAbsLink then table.insert(TreatmentLinks, fluidBolusAbsLink) end
    if vdReplacementMedLink then table.insert(TreatmentLinks, vdReplacementMedLink) end
    if vdReplacementAbsLink then table.insert(TreatmentLinks, vdReplacementAbsLink) end

    -- Vitals
    AddVitalsDv("Glasgow Coma Scale", "Glasgow Coma Score", 1, function (dv)
        return CheckDvResultNumber(dv, function(v) return v < 15 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)
    AddVitalsAbs("LOW_GLASGOW_COMA_SCORE", "Glasgow Coma Score", 2)
end



--------------------------------------------------------------------------------
--- Result Finalization 
--------------------------------------------------------------------------------
if AlertMatched or AlertAutoResolved then
    -- Compose the labs subheaders/links
    if ionCalciumLinks then
        ionCalciumHeader.links = ionCalciumLinks
        table.insert(DocumentationIncludesLinks, ionCalciumHeader)
    end

    if serumCalciumLinks then
        serumCalciumHeader.links = serumCalciumLinks
        table.insert(DocumentationIncludesLinks, serumCalciumHeader)
    end

    local resultLinks = GetFinalTopLinks({})

    resultLinks = MergeLinksWithExisting(ExistingAlert, resultLinks)
    Result.links = resultLinks
    Result.passed = true
end

