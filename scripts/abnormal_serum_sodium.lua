---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Abnormal Serum Sodium
---
--- This script checks an account to see if it matches the criteria for an abnormal serum sodium alert.
---
--- Date: 4/10/2024
--- Version: 1.0
--- Site: (Default)
---------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Requires 
--------------------------------------------------------------------------------
require "libs.common" 
require "libs.standard_cdi" 



--------------------------------------------------------------------------------
--- Setup
--------------------------------------------------------------------------------
local sodiumHeader = MakeHeaderLink("Serum Sodium")
local sodiumLinks = MakeLinkArray()

local e870CodeLink = MakeNilLink()
local e871CodeLink = MakeNilLink()
local serumSodiumLowLinks = MakeLinkArray()
local serumSodiumHighLinks = MakeLinkArray()

local sodiumReplacementMedLink = MakeNilLink()
local sodiumPhosphateAbsLink = MakeNilLink()
local dextroseMedLink = MakeNilLink()
local dextroseAbsLink = MakeNilLink()
local fluidRestrictionAbsLink = MakeNilLink()
local hypertonicSalineMedLink = MakeNilLink()
local hypertonicSalineAbsLink = MakeNilLink()
local hypotonicSolutionMedLink = MakeNilLink()
local hypotonicSolutionAbsLink = MakeNilLink()
local sodiumChlorideMedLink = MakeNilLink()

--------------------------------------------------------------------------------
--- Alert Qualification 
--------------------------------------------------------------------------------
if not ExistingAlert or not ExistingAlert.validated then

    -- Alert Trigger
    e870CodeLink = GetCodeLinks { code = "E87.0", text = "Hypernatremia Fully Specified Code" }
    e871CodeLink = GetCodeLinks { code = "E87.1", text = "Hyponatremia Fully Specified Code" }

    -- Labs
    serumSodiumLowLinks = GetDiscreteValueLinks {
        discreteValueNames = { "Sodium Lvl (mmol/L)" },
        text = "Serum Sodium",
        predicate = function(dv)
           return CheckDvResultNumber(dv, function(v) return v <= 135 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        maxPerValue = 10
    } or {}
    serumSodiumHighLinks = GetDiscreteValueLinks {
        discreteValueNames = { "Sodium Lvl (mmol/L)" },
        text = "Serum Sodium",
        predicate = function(dv)
           return CheckDvResultNumber(dv, function(v) return v >= 146 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        maxPerValue = 10
    } or {}

    -- Meds
    sodiumReplacementMedLink = GetMedicationLinks { cat = "Sodium Replacement", text = "Sodium Replacement", seq = 1 }
    sodiumPhosphateAbsLink = GetAbstractionValueLinks { code = "SODIUM_PHOSPHATE", text = "Sodium Phosphate", seq = 2 }

    -- Treatment
    dextroseMedLink = GetMedicationLinks { cat = "Dextrose 5% in Water", text = "Dextrose 5% in Water", seq = 1 }
    dextroseAbsLink = GetAbstractionValueLinks { code = "DEXTROSE_5_IN_WATER", text = "Dextrose 5% in Water", seq = 2 }
    fluidRestrictionAbsLink = GetAbstractionValueLinks { code = "FLUID_RESTRICTION", text = "Fluid Restriction", seq = 3 }
    hypertonicSalineMedLink = GetMedicationLinks { cat = "Hypertonic Saline", text = "Hypertonic Saline", seq = 4 }
    hypertonicSalineAbsLink = GetAbstractionValueLinks { code = "HYPERTONIC_SALINE", text = "Hypertonic Saline", seq = 5 }
    hypotonicSolutionMedLink = GetMedicationLinks { cat = "Hypotonic Solution", text = "Hypotonic Solution", seq = 6 }
    hypotonicSolutionAbsLink = GetAbstractionValueLinks { code = "HYPOTONIC_SOLUTION", text = "Hypotonic Solution", seq = 7 }
    sodiumChlorideMedLink = GetMedicationLinks { cat = "Sodium Chloride", text = "Sodium Chloride", seq = 8 }

    -- Main Algorithm
    if (
        (e870CodeLink and (not ExistingAlert or ExistingAlert.subtitle == "Possible Hypernatremia Dx")) or
        (e871CodeLink and (not ExistingAlert or ExistingAlert.subtitle == "Possible Hyponatremia Dx"))
    ) then
        if ExistingAlert then
            AutoResolved = true

            AddDocumentationCode("E87.0", "Autoresloved Specified Code - Hypernatremia", 0)
            AddDocumentationCode("E87.1", "Autoresloved Specified Code - Hyponatremia", 0)

            Result.outcome = "AUTORESOLVED"
            Result.reason = "Autoresolved Specified Code"
            Result.validated = true
        else
            Result.passed = false
        end
    elseif (
        not e870CodeLink and
        #serumSodiumHighLinks > 0 and
        (dextroseMedLink or dextroseAbsLink or hypotonicSolutionMedLink or hypotonicSolutionAbsLink)
    ) then
        if dextroseMedLink then table.insert(DocumentationIncludesLinks, dextroseMedLink) end
        if dextroseAbsLink then table.insert(DocumentationIncludesLinks, dextroseAbsLink) end
        if hypotonicSolutionMedLink then table.insert(DocumentationIncludesLinks, hypotonicSolutionMedLink) end
        if hypotonicSolutionAbsLink then table.insert(DocumentationIncludesLinks, hypotonicSolutionAbsLink) end
        if serumSodiumHighLinks then
            for _, link in ipairs(serumSodiumHighLinks.links) do
                table.insert(sodiumLinks, link)
            end
        end
        Result.subtitle = "Possible Hypernatremia Dx"
        AlertMatched = true
    elseif (
        not e871CodeLink and
        #serumSodiumLowLinks > 0 and
        (hypertonicSalineMedLink or hypertonicSalineAbsLink or sodiumChlorideMedLink)
    ) then
        if fluidRestrictionAbsLink then table.insert(DocumentationIncludesLinks, fluidRestrictionAbsLink) end
        if hypertonicSalineMedLink then table.insert(DocumentationIncludesLinks, hypertonicSalineMedLink) end
        if hypertonicSalineAbsLink then table.insert(DocumentationIncludesLinks, hypertonicSalineAbsLink) end
        if sodiumChlorideMedLink then table.insert(DocumentationIncludesLinks, sodiumChlorideMedLink) end
        if serumSodiumLowLinks then
            for _, link in ipairs(serumSodiumLowLinks.links) do
                table.insert(sodiumLinks, link)
            end
        end
        Result.subtitle = "Possible Hyponatremia Dx"
        AlertMatched = true
    else
       Result.passed = false
    end
end



--------------------------------------------------------------------------------
--- Additional Link Creation
--------------------------------------------------------------------------------
if AlertMatched then
    -- Clinical Evidence
    AddEvidenceAbs("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level of Consciousness", 1)
    AddEvidenceCode("F10.230", "Beer Potomania", 2)
    AddEvidenceCode("R11.14", "Bilious Vomiting", 3)
    GetCodeLinks {
        codes = {
            "I50.21", "I50.22", "I50.23", "I50.31", "I50.32", "I50.33", "I50.41",
            "I50.42", "I50.43", "I50.811", "I50.812", "I50.813", "I50.814",
            "I50.82", "I50.83", "I50.84"
        },
        text = "Congestive Heart Failure (CHF)",
        seq = 4,
        fixed_seq = true,
        target = ClinicalEvidenceLinks
    }
    AddEvidenceCode("R11.15", "Cyclical Vomiting", 5)
    AddEvidenceAbs("DIABETES_INSIPIDUS", "Diabetes Insipidus", 6)
    AddEvidenceAbs("DIARRHEA", "Diarrhea", 7)
    AddEvidenceAbs("DIURETIC", "Diuretic", 8)
    AddEvidenceCode("R53.83", "Fatigue", 9)
    AddEvidenceAbs("HYPEROSMOLAR_HYPERGLYCEMIA_SYNDROME", "Hyperosmolar Hyperglycemia Syndrome", 10)
    GetCodeLinks {
        codes = {
        },
        text = "Kidney Failure",
        seq = 11,
        fixed_seq = true,
        target = ClinicalEvidenceLinks
    }
    AddEvidenceAbs("MUSCLE_CRAMPS", "Muscle Cramps", 12)
    AddEvidenceAbs("WEAKNESS", "Muscle Weakness", 13)
    AddEvidenceCode("R63.1", "Polydipsia", 14)
    AddEvidenceCode("R11.12", "Projectile Vomiting", 15)
    AddEvidenceAbs("SEIZURE", "Seizure", 16)
    GetCodeLinks {
        codes = { "E05.01", "E05.11", "E05.21", "E05.41", "E05.81", "E05.91" },
        text = "Thyrotoxic Crisis Storm Code",
        seq = 17,
        fixed_seq = true,
        target = ClinicalEvidenceLinks
    }
    AddEvidenceCode("R11.10", "Vomiting", 18)
    AddEvidenceCode("R11.13", "Vomiting Fecal Matter", 19)
    AddEvidenceCode("R11.11", "Vomiting Without Nausea", 20)
    AddEvidenceCode("E86.0", "Dehydration", 21)
    AddEvidenceCode("E86.1", "Hypovolemia", 22)
    AddEvidenceCode("E86.9", "Volume Depletion", 23)

    -- Labs
    AddLabsAbs("LOW_SERUM_SODIUM", "Serum Sodium", 3)
    AddLabsAbs("HIGH_SERUM_SODIUM", "Serum Sodium", 4)
    local glucoseLink = GetDiscreteValueLinks {
        target = LabsLinks,
        discreteValueName =  "Blood Glucose (mg/dL)",
        text = "Blood Glucose",
        seq = 5,
        predicate = function(dv)
            return CheckDvResultNumber(dv, function(v) return v > 600 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end
    }
    if not glucoseLink then
        GetDiscreteValueLinks {
            target = LabsLinks,
            discreteValueName = "Blood Glucose POC (mg/dL)",
            text = "Blood Glucose POC",
            seq = 5,
            predicate = function(dv)
                return CheckDvResultNumber(dv, function(v) return v > 600 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
            end
        }
    end
    AddLabsAbs("HIGH_BLOOD_GLUCOSE_HHNS", "Blood Glucose", 6)

    -- Medications
    if sodiumReplacementMedLink then table.insert(TreatmentLinks, sodiumReplacementMedLink) end
    if sodiumPhosphateAbsLink then table.insert(TreatmentLinks, sodiumPhosphateAbsLink) end

    -- Vitals
    GetDiscreteValueLinks {
        target = VitalsLinks,
        discreteValueName = "Glasgow Coma Score",
        text = "Glasgow Coma Score",
        predicate = function(dv)
            return CheckDvResultNumber(dv, function(v) return v <= 14 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end
    }
    AddVitalsAbs("LOW_GLASGOW_COMA_SCORE", "Glasgow Coma Score", 6)
end



--------------------------------------------------------------------------------
--- Result Finalization 
--------------------------------------------------------------------------------
if AlertMatched or AlertAutoResolved then
    if sodiumLinks then
        sodiumHeader.links = sodiumLinks
        table.insert(DocumentationIncludesLinks, sodiumHeader)
    end

    local resultLinks = GetFinalTopLinks({})

    resultLinks = MergeLinksWithExisting(ExistingAlert, resultLinks)
    Result.links = resultLinks
    Result.passed = true
end

