---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Acute MI with Troponemia
---
--- This script checks an account to see if it matches the criteria for an Acute MI with Troponemia alert.
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
local heartRateDvNames = {
    "Heart Rate cc (bpm)",
    "3.5 Heart Rate (Apical) (bpm)",
    "3.5 Heart Rate (Other) (bpm)",
    "3.5 Heart Rate (Radial) (bpm)",
    "SCC Monitor Pulse (bpm)"
}
local highHeartRatePredicate = function(dv) return GetDvValueNumber(dv) > 90 end
local lowHeartRatePredicate = function(dv) return GetDvValueNumber(dv) < 60 end
local hematocritDvNames = { "HEMATOCRIT (%)", "HEMATOCRIT" }
local verylowHematocritPredicate = function(dv) return GetDvValueNumber(dv) < 34 end
local lowHematocritPredicate = function(dv) return GetDvValueNumber(dv) < 40 end
local hemogloblinDvNames = { "HEMOGLOBIN (g/dL)", "HEMOGLOBIN" }
local verylowHemoglobinPredicate = function(dv) return GetDvValueNumber(dv) < 13.5 end
local lowHemoglobinPredicate = function(dv) return GetDvValueNumber(dv) < 11.6 end
local mapDvNames = { "MAP Non-Invasive (Calculated) (mmHg)", "MPA Invasive (mmHg)" }
local lowMapPredicate = function(dv) return GetDvValueNumber(dv) < 70 end
local oxygenDvNames = { "DELIVERY" }
local paO2DvNames = { "BLD GAS O2 (mmHg)", "PO2 (mmHg)" }
local lowPaO2Predicate = function(dv) return GetDvValueNumber(dv) < 80 end
local sbpDvNames = { "SBP 3.5 (No Calculation) (mmHg)" }
local lowSbpPredicate = function(dv) return GetDvValueNumber(dv) < 90 end
local highSbpPredicate = function(dv) return GetDvValueNumber(dv) > 180 end
local spO2DvNames = { "Pulse Oximetry(Num) (%)" }
local lowSpO2Predicate = function(dv) return GetDvValueNumber(dv) < 90 end
local dvTroponinNames = { "TROPONIN, HIGH SENSITIVITY (ng/L)" }
local highTroponinPredicate = function(dv) return GetDvValueNumber(dv) > 59 end

local existingAlert = GetExistingCdiAlert { scriptName = ScriptName }
local subtitle = existingAlert and existingAlert.subtitle or nil

--------------------------------------------------------------------------------
--- Additional Pre-conditions
--------------------------------------------------------------------------------
local stemicodeDictionary = {
    ["I21.01"] = "ST Elevation (STEMI) Myocardial Infarction Involving Left Main Coronary Artery",
    ["I21.02"] = "ST Elevation (STEMI) Myocardial Infarction Involving Left Anterior Descending Coronary Artery",
    ["I21.09"] = "ST Elevation (STEMI) Myocardial Infarction Involving Other Coronary Artery Of Anterior Wall",
    ["I21.11"] = "ST Elevation (STEMI) Myocardial Infarction Involving Right Coronary Artery",
    ["I21.19"] = "ST Elevation (STEMI) Myocardial Infarction Involving Other Coronary Artery Of Inferior Wall",
    ["I21.21"] = "ST Elevation (STEMI) Myocardial Infarction Involving Left Circumflex Coronary Artery",
    ["I21.29"] = "ST Elevation (STEMI) Myocardial Infarction Involving Other Sites",
    ["I21.3"] = "ST Elevation (STEMI) Myocardial Infarction of Unspecified Site"
}
local othercodeDictionary = {
    ["I21.A1"] = "Myocardial Infarction Type 2",
    ["I21.A9"] = "Other Myocardial Infarction Type",
    ["I21.B"] = "Myocardial Infarction with Coronary Microvascular Dysfunction",
    ["I5A"] = "Non-Ischemic Myocardial Injury (Non-Traumatic)",
}
local accountStemiCodes = GetAccountCodesInDictionary(stemicodeDictionary, Account)
local accountOtherCodes = GetAccountCodesInDictionary(othercodeDictionary, Account)

local i214Code = GetCodeLinks { code = "I21.4", text = "Non-ST Elevation (NSTEMI) Myocardial Infarction" }
local codeCount = 0
if #accountStemiCodes > 0 then
    codeCount = codeCount + 1
end
if #accountOtherCodes > 0 then
    codeCount = codeCount + 1
end
if i214Code then
    codeCount = codeCount + 1
end
local triggerAlert = not existingAlert or (existingAlert.outcome ~= "AUTORESOLVED" and existingAlert.reason ~= "Previously Autoresolved")


if (not existingAlert or not existingAlert.validated) or
    (not existingAlert and existingAlert.outcome == "AUTORESOLVED" and existingAlert.validated and codeCount > 0)
then
    --------------------------------------------------------------------------------
    --- Top-Level Link Header Variables
    --------------------------------------------------------------------------------
    local resultLinks = {}
    local documentedDxHeader = MakeHeaderLink("Documented Dx")
    local documentedDxLinks= {}
    local laboratoryStudiesHeader = MakeHeaderLink("Laboratory Studies")
    local laboratoryStudiesLinks = {}
    local vitalSignsIntakeHeader = MakeHeaderLink("Vital Signs/Intake and Output Data")
    local vitalSignsIntakeLinks = {}
    local clinicalEvidenceHeader = MakeHeaderLink("Clinical Evidence")
    local clinicalEvidenceLinks = {}
    local oxygenationVentilationHeader = MakeHeaderLink("Oxygenation/Ventilation")
    local oxygenationVentilationLinks = {}
    local treatmentAndMonitoringHeader = MakeHeaderLink("Treatment and Monitoring")
    local treatmentAndMonitoringLinks = {}
    local ekgHeader = MakeHeaderLink("EKG")
    local ekgLinks = {}
    local echoHeader = MakeHeaderLink("Echo")
    local echoLinks = {}
    local ctHeader = MakeHeaderLink("CT")
    local ctLinks = {}
    local heartCathHeader = MakeHeaderLink("Heart Cath")
    local heartCathLinks = {}
    local otherHeader = MakeHeaderLink("Other")
    local otherLinks = {}
    local troponinHeader = MakeHeaderLink("Troponin")
    local troponinLinks = {}



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Documented Dx
    local i219CodeLink = GetCodeLinks { code = "I21.9", text = "Acute Myocardial Infarction Unspecified" }
    local r778CodeLink = GetCodeLinks { code = "R77.8", text = "Other Specified Abnormalities of Plasma Proteins" }
    local i21A1CodeLink = GetCodeLinks { code = "I21.A1", text = "Myocardial Infarction Type 2" }
    -- Clinical Evidence (Abstractions)
    local r07CodeLinks = GetCodeLinks { codes = { "R07.89", "R07.9" }, text = "Chest Pain" } or {}
    local i2489CodeLink = GetCodeLinks { code = "I24.89", text = "Demand Ischemia" }
    local irregularEKGFindingsAbstractionLink = GetAbstractionLinks { code = "IRREGULAR_EKG_FINDINGS_MI", text = "Irregular EKG Finding" }
    -- Medications
    local antiplatlet2MedicationLink = GetMedicationLinks { cat = "Antiplatelet 2" }
    local aspirinMedicationLink = GetMedicationLinks { cat = "Aspirin" }
    local heparinMedicationLink = GetMedicationLinks { cat = "Heparin" }
    local morphineMedicationLink = GetMedicationLinks { cat = "Morphine" }
    local nitroglycerinMedicationLink = GetMedicationLinks { cat = "Nitroglycerin" }
    -- Laboratory Studies
    GetDvValuesAsSingleLink {
        account = Account,
        dvNames = dvTroponinNames,
        linkText = "Troponin T High Sensitivity: (DATE1, DATE2) - ",
        target = troponinLinks
    }
    local highTroponinDiscreteValueLinks =
        GetDiscreteValueLinks { dvNames = dvTroponinNames, predicate = highTroponinPredicate, maxPerValue = 10 } or {}



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if codeCount == 1 and not i2489CodeLink or (i21A1CodeLink and i2489CodeLink) then
    elseif codeCount > 1 then
    elseif triggerAlert and i21A1CodeLink and i2489CodeLink then
    elseif
        triggerAlert and
        codeCount == 0 and
        (
            (#highTroponinDiscreteValueLinks > 0) or
            i219CodeLink
        ) and
        i2489CodeLink
    then

    
    elseif triggerAlert and codeCount > 0 and i2489CodeLink then

    -- 4
    elseif triggerAlert and i219CodeLink then

    -- 5
    elseif triggerAlert and #highTroponinDiscreteValueLinks > 0 and irregularEKGFindingsAbstractionLink then

    -- 6
    elseif
        triggerAlert and
        (#r07CodeLinks > 0 or #highTroponinDiscreteValueLinks > 0) and
        heparinMedicationLink and
        (morphineMedicationLink or nitroglycerinMedicationLink) and
        aspirinMedicationLink and
        antiplatlet2MedicationLink
    then

    -- 7
    elseif triggerAlert and #highTroponinDiscreteValueLinks > 0 then
    end






    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if Result.validated then
            -- Autoclose
        else
            -- Normal Alert
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
