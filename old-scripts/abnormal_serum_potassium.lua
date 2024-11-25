---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Abnormal Serum Potassium
---
--- This script checks an account to see if it matches the criteria for an abnormal serum potassium alert.
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
local potassiumHeader = MakeHeaderLink("Serum Potassium")
local potassiumLinks = MakeLinkArray()

local n186CodeLink = MakeNilLink()
local e875CodeLink = MakeNilLink()
local e876CodeLink = MakeNilLink()
local hemodialysisCodesLink = MakeNilLink()
local serumPotassiumLowLinks = MakeLinkArray()
local serumPotassiumHighLinks = MakeLinkArray()
local serumPotassiumVeryHighLinks = MakeLinkArray()
local dextroseMedLink = MakeNilLink()
local insulinMedLink = MakeNilLink()
local kayexalateMedLink = MakeNilLink()
local sodiumBicarbMedLink = MakeNilLink()
local potassiumReplacementMedLink = MakeNilLink()
local potassiumChlorideAbsLink = MakeNilLink()
local potassiumPhosphateAbsLink = MakeNilLink()
local potassiumBiCarbonateAbsLink = MakeNilLink()



--------------------------------------------------------------------------------
--- Alert Qualification 
--------------------------------------------------------------------------------
if not ExistingAlert or not ExistingAlert.validated then
    -- Negations
    n186CodeLink = GetCodeLinks { code = "N186", text = "Chronic Kidney Disease, Negation", seq = 1 }

    -- Alert Trigger
    e875CodeLink = GetCodeLinks { code = "E87.5", text = "Hyperkalemia Fully Specified Code", seq = 2 }
    e876CodeLink = GetCodeLinks { code = "E87.6", text = "Hypokalemia Fully Specified Code", seq = 3 }

    -- Abstractions
    hemodialysisCodesLink = GetCodeLinks { codes = { "5A1D70Z", "5A1D80Z", "5A1D90Z" }, text = "Hemodialysis", seq = 4 }

    -- Labs
    serumPotassiumLowLinks = GetDiscreteValueLinks {
        discreteValueNames = { "Potassium Lvl (mmol/L)" },
        text = "Serum Potassium Low",
        predicate = function(dv)
           return CheckDvResultNumber(dv, function(v) return v <= 3.1 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        seq = 5,
        maxPerValue = 10
    } or {}

    serumPotassiumHighLinks = GetDiscreteValueLinks {
        discreteValueNames = { "Potassium Lvl (mmol/L)" },
        text = "Serum Potassium High",
        predicate = function(dv)
           return CheckDvResultNumber(dv, function(v) return v >= 5.4 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        seq = 6,
        maxPerValue = 10
    } or {}

    if n186CodeLink then
        serumPotassiumVeryHighLinks = GetDiscreteValueLinks {
            discreteValueNames = { "Potassium Lvl (mmol/L)" },
            text = "Serum Potassium Very High",
            predicate = function(dv)
               return CheckDvResultNumber(dv, function(v) return v >= 6.0 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
            end,
            seq = 7,
            maxPerValue = 10
        } or {}
    end

    -- Medications
    dextroseMedLink = GetMedicationLinks { cat = "Dextrose50%", text = "Dextrose", seq = 1 }
    insulinMedLink = GetMedicationLinks {
        cat = "Insulin",
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
        seq = 2
    }
    kayexalateMedLink = GetMedicationLinks { cat = "Kayexalate", text = "Kayexalate", seq = 3 }
    sodiumBicarbMedLink = GetMedicationLinks { cat = "Sodium Bicarb", text = "Sodium Bicarb", seq = 4 }
    potassiumReplacementMedLink = GetMedicationLinks { cat = "Potassium Replacement", text = "Potassium Replacement", seq = 5 }
    potassiumChlorideAbsLink = GetAbstractionValueLinks { code = "POTASSIUM_CHLORIDE", text = "Potassium Chloride Absorption", seq = 6 }
    potassiumPhosphateAbsLink = GetAbstractionValueLinks { code = "POTASSIUM_PHOSPHATE", text = "Potassium Phosphate Absorption", seq = 7 }
    potassiumBiCarbonateAbsLink = GetAbstractionValueLinks { code = "POTASSIUM_BICARBONATE", text = "Potassium Bicarbonate Absorption", seq = 8 }

    -- Main Algorithm
    if e875CodeLink or e876CodeLink then
        if ExistingAlert then
            AutoResolved = true
            AddDocumentationCode("E87.5", "Autoresolved Specified Code - Hyperkalemia", 0)
            AddDocumentationCode("E87.6", "Autoresolved Specified Code - Hypokalemia", 1)
            Result.outcome = "AUTORESOLVED"
            Result.reason = "Autoresolved due to one Specified Code on the Account"
            Result.validated = true
        else
            Result.passed = false
        end
    elseif (
        not e875CodeLink and
        (#serumPotassiumHighLinks > 0 or #serumPotassiumVeryHighLinks > 0) and
        (kayexalateMedLink or (insulinMedLink and dextroseMedLink) or hemodialysisCodesLink)
    ) then
        if serumPotassiumHighLinks and n186CodeLink then
            for _, link in ipairs(serumPotassiumHighLinks.links) do
                table.insert(potassiumLinks, link)
            end
        end
        if serumPotassiumVeryHighLinks and n186CodeLink then
            for _, link in ipairs(serumPotassiumVeryHighLinks.links) do
                table.insert(potassiumLinks, link)
            end
        end
        if sodiumBicarbMedLink then
            table.insert(TreatmentLinks, sodiumBicarbMedLink)
        end
        Result.subtitle = "Possible Hyperkalemia Dx"
        AlertMatched = true
    elseif (
        not e876CodeLink and
        serumPotassiumLowLinks and
        #serumPotassiumLowLinks > 0 and
        (potassiumReplacementMedLink or potassiumChlorideAbsLink or potassiumPhosphateAbsLink or potassiumBiCarbonateAbsLink)
    ) then
        for _, link in ipairs(serumPotassiumLowLinks.links) do
            table.insert(potassiumLinks, link)
        end
        Result.subtitle = "Possible Hypokalemia Dx"
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
    AddEvidenceCode("E27.1", "Addison's Disease", 1)
    GetCodeLinks {
        target = ClinicalEvidenceLinks,
        codes = { "E24.0", "E24.1", "E24.2", "E24.3", "E24.4", "E24.8", "E24.9" },
        text = "Cushing's Syndrome",
        seq = 2
    }
    AddEvidenceAbs("DIARRHEA", "Diarrhea", 3)
    if hemodialysisCodesLink then table.insert(ClinicalEvidenceLinks, hemodialysisCodesLink) end
    AddEvidenceAbs("HYPERKALEMIA_EKG_CHANGES", "EKG Changes", 5)
    AddEvidenceAbs("HYPOKALEMIA_EKG_CHANGES", "EKG Changes", 6)
    AddEvidenceCode("R53.83", "Fatigue", 7)
    AddEvidenceAbs("HEART_PALPITATIONS", "Heart Palpitations", 8)
    GetCodeLinks {
        target = ClinicalEvidenceLinks,
        codes = { "N17.0", "N17.1", "N17.2", "N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6" },
        text = "Kidney Failure",
        seq = 9
    }
    AddEvidenceAbs("MUSCLE_CRAMPS", "Muscle Cramps", 10)
    AddEvidenceAbs("WEAKNESS", "Muscle Weakness", 11)
    AddEvidenceAbs("VOMITING", "Vomiting", 12)

    -- Labs
    AddLabsAbs("LOW_SERUM_POTASSIUM", "Serum Potassium", 2)
    AddLabsAbs("HIGH_SERUM_POTASSIUM", "Serum Potassium", 4)

    -- Medications
    if dextroseMedLink then table.insert(TreatmentLinks, dextroseMedLink) end
    if insulinMedLink then table.insert(TreatmentLinks, insulinMedLink) end
    if kayexalateMedLink then table.insert(TreatmentLinks, kayexalateMedLink) end

    if potassiumReplacementMedLink then table.insert(TreatmentLinks, potassiumReplacementMedLink) end
    if potassiumChlorideAbsLink then table.insert(TreatmentLinks, potassiumChlorideAbsLink) end
    if potassiumPhosphateAbsLink then table.insert(TreatmentLinks, potassiumPhosphateAbsLink) end
    if potassiumBiCarbonateAbsLink then table.insert(TreatmentLinks, potassiumBiCarbonateAbsLink) end
end



--------------------------------------------------------------------------------
--- Result Finalization 
--------------------------------------------------------------------------------
if AlertMatched or AlertAutoResolved then
    -- Compose labs subheader
    if potassiumLinks then
        potassiumHeader.links = potassiumLinks
        table.insert(DocumentationIncludesLinks, potassiumHeader)
    end
    local resultLinks = GetFinalTopLinks({})

    resultLinks = MergeLinksWithExisting(ExistingAlert, resultLinks)
    Result.links = resultLinks
    Result.passed = true
end

