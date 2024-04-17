---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Acidosis
---
--- This script checks an account to see if it matches the criteria for an acidosis alert.
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
    ["E87.21"] = "Acute Metabolic Acidosis",
    ["E09.10"] = "Drug or chemical induced diabetes mellitus with ketoacidosis without coma",
    ["E09.11"] = "Drug or chemical induced diabetes mellitus with ketoacidosis with coma",
    ["P74.0"] = "Late metabolic acidosis of newborn",
    ["E08.10"] ="Diabetes mellitus due to underlying condition with ketoacidosis without coma",
    ["E08.11"] ="Diabetes mellitus due to underlying condition with ketoacidosis with coma",
    ["E13.10"] ="Other specified diabetes mellitus with ketoacidosis without coma",
    ["E13.11"] ="Other specified diabetes mellitus with ketoacidosis with coma",
    ["E10.10"] ="Type 1 diabetes mellitus with ketoacidosis without coma",
    ["E10.11"] ="Type 1 diabetes mellitus with ketoacidosis with coma",
    ["E11.10"] ="Type 2 diabetes mellitus with ketoacidosis without coma",
    ["E11.11"] ="Type 2 diabetes mellitus with ketoacidosis with coma",
    ["E87.4"] ="Mixed disorder of acid-base balance",
    ["E87.22"] ="Chronic Metabolic Acidosis",
    ["E87.20"] ="Acidosis Unspecified",
    ["E87.29"] ="Other Acidosis"
}
local accountAlertCodes = GetAccountCodesInDictionary(Account, alertCodeDictionary)

local oxygenHeader = MakeHeader("Oxygenation/Ventilation")
local abgHeader = MakeHeader("ABG")
local vbgHeader = MakeHeader("VBG")
local bloodHeader = MakeHeader("Blood CO2")
local phHeader = MakeHeader("PH")
local lactateHeader = MakeHeader("Lactate")

local oxygenLinks = MakeNiLinkArray()
local abgLinks = MakeNiLinkArray()
local vbgLinks = MakeNiLinkArray()
local bloodLinks = MakeNiLinkArray()
local phLinks = MakeNiLinkArray()
local lactateLinks = MakeNiLinkArray()


local e8720CodeLink = MakeNilLink()
local acuteRespAcidosisAbsLink = MakeNilLink()
local chronicRespAcidosisAbsLink = MakeNilLink()
local bloodCO2MultiDVLinks = MakeNilLinkArray()
local highSerumLactateDVLinks = MakeNilLinkArray()
local albuminMedLink = MakeNilLink()
local fluidBolusMedLink = MakeNilLink()
local fluidBolusAbsLink = MakeNilLink()
local fluidResucAbsLink = MakeNilLink()
local sodiumBicarMedLink = MakeNilLink()
local lowArterialBloodPHMultiDVLinks = MakeNilLinkArray()
local highArterialBloodC02DVLink = MakeNilLink()
local highSerumBicarbonateDVLink = MakeNilLink()
local phMultiDVLinks = MakeNilLinkArray()



--------------------------------------------------------------------------------
--- Alert Qualification 
--------------------------------------------------------------------------------
if not ExistingAlert or not ExistingAlert.validated then
--[[
#========================================
#  Discrete Value Fields and Calculations
#========================================
dvAnionGap = ["Anion Gap (mmol/L)"]
calcAnionGap1 = lambda x: x > 12
dvArterialBloodC02 = ["pCO2 Art (mmHg)"]
calcArterialBlood021 = lambda x: x > 50
calcArterialBlood022 = lambda x: x < 30
calcArterialBlood023 = lambda x: x <= 45
dvArterialBloodPH = ["pH Art (pH Units)"]
calcArterialBloodPH1 = lambda x: x < 7.32
calcArterialBloodPH2 = 7.35
calcArterialBloodPH3 = lambda x: x >= 7.35
calcArterialBloodPH4 = 7.35
dvBaseExcess = ["Base Excess Art (mmol/L)"]
calcBaseExcess1 = lambda x: x < -2
dvBloodCO2 = ["CO2 (mmol/L)"]
calcBloodCO21 = lambda x: x < 21
calcBloodCO22 = 21
dvBloodGlucose = ["Glucose Lvl (mg/dL)"]
calcBloodGlucose1 = lambda x: x > 250
dvBloodGlucosePOC = ["Glucose POC (mg/dL)"]
calcBloodGlucosePOC1 = lambda x: x > 250
dvFIO2 = ["FiO2 Art (%)"]
calcFIO21 = lambda x: x <= 100
dvGlasgowComaScale = ["Glasgow Coma Score"]
calcGlasgowComaScale1 = lambda x: x <= 14
dvHCO3 = ["HCO3 Ven (mmol/L)"]
calcHCO31 = lambda x: x >= 26
dvHeartRate = ["Peripheral Pulse Rate", "Heart Rate Monitored (bpm)", "Peripheral Pulse Rate (bpm)"]
calcHeartRate1 = lambda x: x > 90
dvMAP = ["Mean Arterial Pressure"]
calcMAP1 = lambda x: x < 70
dvOxygenFlowRate = ["Oxygen Flow Rate (L/min)"]
calcOxygenFlowRate1 = lambda x: x > 2
dvOxygenTherapy = ["Oxygen Therapy"]
dvPaO2 = ["pO2 Art (mmHg)"]
calcPAO21 = lambda x: x < 80
calcPAO22 = lambda x: x >= 80
dvPCO2 = ["pCO2 Ven (mmHg)"]
calcPCO21 = lambda x: x > 55
dvPH = ["pH Ven (pH Units)"]
calcPH1 = lambda x: x < 7.30
calcPH2 = 7.30
dvRespiratoryRate = ["Respiratory Rate", "Respiratory Rate (br/min)"]
calcRespiratoryRate1 = lambda x: x > 20
calcRespiratoryRate2 = lambda x: x < 12
dvSBP = ["Systolic Blood Pressure", "Systolic Blood Pressure (mmHg)"]
calcSBP1 = lambda x: x < 90
dvSerumBloodUreaNitrogen = ["BUN (mg/dL)"]
calcSerumBloodUreaNitrogen1 = lambda x: x > 30
dvSerumBicarbonate = ["HCO3 Art (mmol/L)"]
calcSerumBicarbonate1 = lambda x: x >= 26
calcSerumBicarbonate2 = lambda x: 22 < x < 26
calcSerumBicarbonate3 = lambda x: x < 22
dvSerumChloride = ["Chloride Lvl (mmol/L)"]
calcSerumChloride1 = lambda x: x > 107
dvSerumCreatinine = ["Creatinine Lvl (mg/dL)"]
calcSerumCreatinine1 = lambda x: x > 1.2
dvSerumLactate = ["Lactic Acid Lvl (mmol/L)"]
calcSerumLactate1 = 2
dvSPO2 = ["SpO2 (%)"]
calcSPO21 = lambda x: x < 92
calcAny = 0
dvWBC = ["WBC (10x3/uL)"]
calcWBC1 = lambda x: x > 12
dvPlateletCount = ["Platelets (10x3/uL)"]
calcPlateletCount1 = lambda x: x < 100
dvInr = ["INR"]
calcInr1 = lambda x: x > 1.5
dvSerumBilirubin = ["Bilirubin Total (mg/dL)"]
calcSerumBilirubin1 = lambda x: x > 2.0
dvCreactiveProtein = ["CRP (mg/dL)"]
calcCreactiveProtein1 = lambda x: x > 0.5

dvProcalcitonin = ["Procalcitonin (ng/mL)"]
calcProcalcitonin1 = lambda x: x > 0.49
dvTroponinT = ["hs Troponin (ng/L)"]
calcTroponinTMale1 = lambda x: x > 22
calcTroponinTFemale1 = lambda x: x > 14
dvSerumKetone = ["KETONES:SCNC:PT:BLD:QN:"]
calcSerumKetone1 = lambda x: x > 0
dvUrineKetone = ["UA Ketones"]
calcUrineKetone1 = lambda x: x > 0

dvCBlood = ["C Blood"]
dvCSepsisBlood = ["C Sepsis Blood"]
]]--

    -- Documentation Includes
    e8720CodeLink = GetCodeLinks { code = "E87.20", text = "Acidosis Unspecified" }
    acuteRespAcidosisAbsLink = GetAbstractionLinks { code = "ACUTE_RESPIRATORY_ACIDOSIS", text = "Acute Respiratory Acidosis" }
    chronicRespAcidosisAbsLink = GetAbstractionLinks { code = "CHRONIC_RESPIRATORY_ACIDOSIS", text = "Chronic Respiratory Acidosis" }

    -- Labs
    bloodCO2MultiDVLinks = GetDiscreteValueLinks {
        discreteValueNames = { "CO2 (mmol/L)" },
        text = "PH",
        predicate = function(dv)
            return dv < 21
        end,
        maxPerValue = 10
    }
    highSerumLactateDVLinks = GetDiscreteValueLinks {
        discreteValueNames = { "Lactic Acid Lvl (mmol/L)" },
        text = "Serum Lactate",
        predicate = function(dv)
            return dv > 2
        end,
        maxPerValue = 10
    }

    -- Meds
    albuminMedLink = GetMedicationLinks { cat = "Albumin",  text = "Albumin", seq = 1 }
    fluidBolusMedLink = GetMedicationLinks { cat = "Fluid Bolus",  text = "Fluid Bolus", seq = 2 }
    fluidBolusAbsLink = GetAbstractionLinks { code = "FLUID_BOLUS", text = "Fluid Bolus", seq = 3 }
    fluidResucAbsLink = GetAbstractionLinks { code = "FLUID_RESUSCITATION", text = "Fluid Resuscitation", seq = 4 }
    sodiumBicarMedLink = GetMedicationLinks { cat = "Sodium Bicarbonate",  text = "Sodium Bicarbonate", seq = 5 }

    -- ABG
    lowArterialBloodPHMultiDVLinks = GetDiscreteValueLinks {
        discreteValueNames = { "pH Art (pH Units)" },
        text = "PH",
        predicate = function(dv)
            return dv < 7.35
        end,
        maxPerValue = 10
    }
    highArterialBloodC02DVLink = GetDiscreteValueLinks {
        discreteValueName = "pCO2 Art (mmHg)",
        text = "pC02",
        predicate = function(dv)
            return dv > 50
        end,
        seq = 2
    }
    highSerumBicarbonateDVLink = GetDiscreteValueLinks {
        discreteValueName = "HCO3 Art (mmol/L)",
        text = "HC03",
        predicate = function(dv)
            return dv >= 26
        end,
        seq = 5
    }

    -- VBG
    phMultiDVLinks = GetDiscreteValueLinks {
        discreteValueNames = { "pH Ven (pH Units)" },
        text = "PH",
        predicate = function(dv)
            return dv < 7.30
        end,
        maxPerValue = 10
    }

    -- Main Algorithm
    if #accountAlertCodes >= 1 or (
        (acuteRespAcidosisAbsLink or chronicRespAcidosisAbsLink) and
        (ExistingAlert and ExistingAlert.subtitle ~= "Acidosis Unspecified Dx Present")
    ) then
        if ExistingAlert then

        else
            Result.passed = false
        end

    elseif highSerumLactateDVLinks then

    elseif (
        e8720CodeLink and
        (#lowArterialBloodPHMultiDVLinks > 0 or  #phMultiDVLinks > 0 or #bloodCO2MultiDVLinks > 0) and
        (albuminMedLink or fluidBolusMedLink or fluidBolusAbsLink or fluidResucAbsLink or sodiumBicarMedLink)
    ) then
    else
        Result.passed = false
    end


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
    if abgLinks then
        abgHeader.links = abgLinks
        table.insert(LabsLinks, abgHeader)
    end
    if vbgLinks then
        vbgHeader.links = vbgLinks
        table.insert(LabsLinks, vbgHeader)
    end
    if lactateLinks then
        lactateHeader.links = lactateLinks
        table.insert(LabsLinks, lactateHeader)
    end

    if oxygenLinks then
        oxygenHeader.links = oxygenLinks
    end

    local resultLinks = GetFinalTopLinks({ oxygenHeader })

    resultLinks = MergeLinksWithExisting(ExistingAlert, resultLinks)
    Result.links = resultLinks
    Result.passed = true
end

