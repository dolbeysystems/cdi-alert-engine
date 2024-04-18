---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Acute MI Troponemia
---
--- This script checks an account to see if it matches the criteria for an acute MI troponemia alert.
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
    ["I21.01"] = "ST Elevation (STEMI) Myocardial Infarction Involving Left Main Coronary Artery",
    ["I21.02"] = "ST Elevation (STEMI) Myocardial Infarction Involving Left Anterior Descending Coronary Artery",
    ["I21.09"] = "ST Elevation (STEMI) Myocardial Infarction Involving Other Coronary Artery Of Anterior Wall",
    ["I21.11"] = "ST Elevation (STEMI) Myocardial Infarction Involving Right Coronary Artery",
    ["I21.19"] = "ST Elevation (STEMI) Myocardial Infarction Involving Other Coronary Artery Of Inferior Wall",
    ["I21.21"] = "ST Elevation (STEMI) Myocardial Infarction Involving Left Circumflex Coronary Artery",
    ["I21.29"] = "ST Elevation (STEMI) Myocardial Infarction Involving Other Sites",
    ["I21.A1"] = "Myocardial Infarction Type 2",
    ["I21.A9"] = "Other Myocardial Infarction Type",
    ["I21.B"] = "Myocardial Infarction with Coronary Microvascular Dysfunction",
    ["I5A"] = "Non-Ischemic Myocardial Injury (Non-Traumatic)"
}
local accountAlertCodes = GetAccountCodesInDictionary(Account, alertCodeDictionary)

local oxygenHeader = MakeHeaderLink("Oxygenation/Ventilation")
local ekgHeader = MakeHeaderLink("EKG")
local echoHeader = MakeHeaderLink("Echo")
local heartCathHeader = MakeHeaderLink("Heart Cath")
local ctHeader = MakeHeaderLink("CT")
local troponinHeader = MakeHeaderLink("Troponin")

local oxygenLinks = MakeNilLinkArray()
local ekgLinks = MakeNilLinkArray()
local echoLinks = MakeNilLinkArray()
local heartCathLinks = MakeNilLinkArray()
local ctLinks = MakeNilLinkArray()
local troponinLinks = MakeNilLinkArray()

local i214Code = MakeNilLink()
local i219Code = MakeNilLink()
local i213Code = MakeNilLink()
local elevatedTroponinIDV = MakeNilLink()
local troponinTDV = MakeNilLink()
local troponinTAbs = MakeNilLink()
local irregularEKGFindingsAbs = MakeNilLink()
local r07Codes = MakeNilLink()
local i2489Code = MakeNilLink()
local antiplatlet2Med = MakeNilLink()
local aspirinMed = MakeNilLink()
local heparinMed = MakeNilLink()
local morphineMed = MakeNilLink()
local nitroglycerinMed = MakeNilLink()



--[[
dvDBP = ["Diastolic Blood Pressure"]
calcDBP1 = lambda x: x > 120
dvGlomerularFiltrationRate = ["eGFR Non-AA (mL/min/1.73 m2)"]
calcGlomerularFiltrationRate1 = lambda x: x <= 60
dvHeartRate = ["Peripheral Pulse Rate", "Heart Rate Monitored (bpm)", "Peripheral Pulse Rate (bpm)"]
calcHeartRate1 = lambda x: x > 90
calcHeartRate2 = lambda x: x < 60
dvHematocrit = ["Hct (%)"]
calcHematocrit1 = lambda x: x < 35
calcHematocrit2 = lambda x: x < 40
dvHemoglobin = ["Hgb (g/dL)"]
calcHemoglobin1 = lambda x: x < 13.5
calcHemoglobin2 = lambda x: x < 12
dvMAP = ["Mean Arterial Pressure"]
calcMAP1 = lambda x: x < 65
dvPaO2 = ["pO2 Art (mmHg)"]
calcPAO21 = lambda x: x < 80
dvSBP = ["Systolic Blood Pressure", "Systolic Blood Pressure (mmHg)"]
calcSBP1 = lambda x: x < 90
calcSBP2 = lambda x: x > 180
dvSerumCreatinine = ["Creatinine Lvl (mg/dL)"]
calcSerumCreatinine1 = lambda x: x > 1.2
dvSPO2 = ["SpO2 (%)"]
calcSPO21 = lambda x: x < 90
dvTroponinI = ["Elevated Troponin I"]
calcTroponinI1 = lambda x: x > 0.04
dvTroponinT = ["hs Troponin (ng/L)"]
calcTroponinTMale1 = 22
calcTroponinTFemale1 = 14
calcAny = 0
--]]

--------------------------------------------------------------------------------
--- Alert Qualification 
--------------------------------------------------------------------------------
if not ExistingAlert or not ExistingAlert.validated then
    -- Documentation Includes
    i214Code = GetCodeLinks { code="I21.4", text="Non-ST Elevation (NSTEMI) Myocardial Infarction: " }
    i219Code = GetCodeLinks { code="I21.9", text="Acute MI Dx: " }
    i213Code = GetCodeLinks { code="I21.3", text="ST Elevation (STEMI) Myocardial Infarction Of Unspecified Site: " }
    elevatedTroponinIDV = GetDiscreteValueLinks {
        discreteValue="Elevated Troponin I",
        text="Troponin I",
        predicate = function(dv)
            return CheckDvResultNumber(dv, function(v) return v.result > 0.04 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end
    }
    if Account.patient.gender == "M" then
        troponinTDV = GetDiscreteValueLinks {
            discreteValue="hs Troponin (ng/L)",
            text="Troponin T High Sensitivity Male",
            predicate = function(dv)
                return CheckDvResultNumber(dv, function(v) return v.result > 22 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
            end
        }
        troponinTAbs = GetAbstractionValueLinks { code="ELEVATED_TROPONIN_T_HIGH_SENSITIVITY_MALE", text="Troponin T High Sensitivity Male" }
    elseif Account.patient.gender =="F" then
        troponinTDV = GetDiscreteValueLinks {
            discreteValue="hs Troponin (ng/L)",
            text="Troponin T High Sensitivity Female",
            predicate = function(dv)
                return CheckDvResultNumber(dv, function(v) return v.result > 14 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
            end
        }
        troponinTAbs = GetAbstractionValueLinks { code="ELEVATED_TROPONIN_T_HIGH_SENSITIVITY_FEMALE", text="Troponin T High Sensitivity Female" }
    end
    irregularEKGFindingsAbs = GetAbstractionValueLinks { code="IRREGULAR_EKG_FINDINGS_MI", text="Irregular EKG Finding" }
    r07Codes = GetCodeLinks { codes={"R07.89", "R07.9"}, text="Chest Pain" }

    -- Abs
    i2489Code = GetCodeLinks { code="I24.89", text="Demand Ischemia", seq=19 }

    -- Meds
    antiplatlet2Med = GetMedicationLinks { cat="Antiplatlet2", text="Antiplatlet2", seq=7 }
    aspirinMed = GetMedicationLinks { cat="Aspirin", text="Aspirin", seq=9 }
    heparinMed = GetMedicationLinks { cat="Heparin", text="Heparin", seq=14 }
    morphineMed = GetMedicationLinks { cat="Morphine", text="Morphine", seq=16 }
    nitroglycerinMed = GetMedicationLinks { cat="Nitroglycerin", text="Nitroglycerin", seq=17 }

    -- Starting Main Algorithm
    if #accountAlertCodes > 0 then
        if ExistingAlert then
            Result.outcome = "AUTORESOLVED"
            Result.reason = "Autoresolved due to one specified code on the account"
            Result.validated = true

            for codeIndex = 1, #accountAlertCodes do
                local code = accountAlertCodes[codeIndex]
                local description = alertCodeDictionary[code]
                GetCodeLinks { target=DocumentationIncludesLinks, code=code, text="Autoresolved Specified Code - " .. description }
            end
            AlertAutoResolved = true
        else
            Result.passed = false
        end
    elseif #accountAlertCodes == 0 and i214Code then
        if i214Code then
            table.insert(DocumentationIncludesLinks, i214Code)
        end
        Result.subtitle = "NSTEMI Present Confirm if Further Specification of Type Needed"
        AlertMatched = true
    elseif #accountAlertCodes == 0 and i219Code then
--[[
        if i219Code is not None: di.Links.Add(i219Code)
        result.Subtitle = "Acute MI Unspecified Present Confirm if Further Specification of Type Needed"
        AlertPassed = True        
--]]
    elseif #accountAlertCodes == 0 and (troponinTDV or troponinTAbs) and i2489Code then
--[[
        if i2489Code is not None: di.Links.Add(i2489Code)
        if troponinTDV is not None:
            for entry in troponinTDV:
               troponin.Links.Add(entry)
        if troponinTAbs is not None: di.Links.Add(troponinTAbs)
        result.Subtitle = "Possible Acute MI Type 2"
        AlertPassed = True
--]]
    elseif #accountAlertCodes == 0 and (troponinTDV or troponinTAbs) and irregularEKGFindingsAbs then
--[[
        if irregularEKGFindingsAbs is not None: di.Links.Add(irregularEKGFindingsAbs)
        if troponinTDV is not None:
            for entry in troponinTDV:
               troponin.Links.Add(entry)
        if troponinTAbs is not None: di.Links.Add(troponinTAbs)
        result.Subtitle = "Possible Acute MI or Injury"
        AlertPassed = True
--]]
    elseif (r07Codes or (troponinTDV or troponinTAbs)) and heparinMed and (morphineMed or nitroglycerinMed) and aspirinMed and antiplatlet2Med then
--[[
        if heparinMed is not None: di.Links.Add(heparinMed)
        if morphineMed is not None: di.Links.Add(morphineMed)
        if nitroglycerinMed is not None: di.Links.Add(nitroglycerinMed)
        if r07Codes is not None: di.Links.Add(r07Codes)
        if aspirinMed is not None: di.Links.Add(aspirinMed)
        if antiplatlet2Med is not None: di.Links.Add(antiplatlet2Med)
        if troponinTDV is not None:
            for entry in troponinTDV:
                troponin.Links.Add(entry)
        if troponinTAbs is not None: di.Links.Add(troponinTAbs)
        result.Subtitle = "Possible Acute MI or Injury"
        AlertPassed = True
--]]
    elseif #accountAlertCodes == 0 and (troponinTDV or troponinTAbs) then
--[[
        if troponinTDV is not None:
            for entry in troponinTDV:
               troponin.Links.Add(entry)
        if troponinTAbs is not None: di.Links.Add(troponinTAbs)
        result.Subtitle = "Elevated Troponins Present"
        AlertPassed = True
--]]
    elseif (troponinTDV or elevatedTroponinIDV or troponinTAbs) then
--[[
        if troponinTDV is not None:
            for entry in troponinTDV:
               troponin.Links.Add(entry)
        if troponinTAbs is not None: di.Links.Add(troponinTAbs)
        if elevatedTroponinIDV is not None: di.Links.Add(elevatedTroponinIDV)
        abstractValue("ELEVATED_TROPONIN_I", "Troponin I: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0, di, True)
        result.Subtitle = "Elevated Troponins Present"
        AlertPassed = True
--]]
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
    local resultLinks = GetFinalTopLinks({})

    resultLinks = MergeLinksWithExisting(ExistingAlert, resultLinks)
    Result.links = resultLinks
    Result.passed = true
end

