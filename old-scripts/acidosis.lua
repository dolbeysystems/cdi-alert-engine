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
local dvTrigger = false

local oxygenHeader = MakeHeaderLink("Oxygenation/Ventilation")
local abgHeader = MakeHeaderLink("ABG")
local vbgHeader = MakeHeaderLink("VBG")
local bloodHeader = MakeHeaderLink("Blood CO2")
local phHeader = MakeHeaderLink("PH")
local lactateHeader = MakeHeaderLink("Lactate")

local oxygenLinks = MakeLinkArray()
local abgLinks = MakeLinkArray()
local vbgLinks = MakeLinkArray()
local bloodLinks = MakeLinkArray()
local phLinks = MakeLinkArray()
local lactateLinks = MakeLinkArray()

local e8720CodeLink = MakeNilLink()
local acuteRespAcidosisAbsLink = MakeNilLink()
local chronicRespAcidosisAbsLink = MakeNilLink()
local bloodCO2MultiDVLinks = MakeLinkArray()
local highSerumLactateDVLinks = MakeLinkArray()
local albuminMedLink = MakeNilLink()
local fluidBolusMedLink = MakeNilLink()
local fluidBolusAbsLink = MakeNilLink()
local fluidResucAbsLink = MakeNilLink()
local sodiumBicarMedLink = MakeNilLink()
local lowArterialBloodPHMultiDVLinks = MakeLinkArray()
local highArterialBloodC02DVLink = MakeNilLink()
local highSerumBicarbonateDVLink = MakeNilLink()
local phMultiDVLinks = MakeLinkArray()



--------------------------------------------------------------------------------
--- Alert Qualification 
--------------------------------------------------------------------------------
if not ExistingAlert or not ExistingAlert.validated then
    -- Documentation Includes
    e8720CodeLink = GetCodeLinks { code = "E87.20", text = "Acidosis Unspecified" }
    acuteRespAcidosisAbsLink = GetAbstractionLinks { code = "ACUTE_RESPIRATORY_ACIDOSIS", text = "Acute Respiratory Acidosis" }
    chronicRespAcidosisAbsLink = GetAbstractionLinks { code = "CHRONIC_RESPIRATORY_ACIDOSIS", text = "Chronic Respiratory Acidosis" }

    -- Labs
    bloodCO2MultiDVLinks = GetDiscreteValueLinks {
        discreteValueNames = { "CO2 (mmol/L)" },
        text = "PH",
        predicate = function(dv)
            return CheckDvResultNumber(dv, function(v) return v < 21 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        maxPerValue = 10
    } or {}
    highSerumLactateDVLinks = GetDiscreteValueLinks {
        discreteValueNames = { "Lactic Acid Lvl (mmol/L)" },
        text = "Serum Lactate",
        predicate = function(dv)
            return CheckDvResultNumber(dv, function(v) return v > 2 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        maxPerValue = 10
    } or {}

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
            return CheckDvResultNumber(dv, function(v) return v < 7.35 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        seq = 1,
        maxPerValue = 10
    } or {}
    highArterialBloodC02DVLink = GetDiscreteValueLinks {
        discreteValueName = "pCO2 Art (mmHg)",
        text = "pC02",
        predicate = function(dv)
            return CheckDvResultNumber(dv, function(v) return v > 50 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        seq = 2
    }
    highSerumBicarbonateDVLink = GetDiscreteValueLinks {
        discreteValueName = "HCO3 Art (mmol/L)",
        text = "HC03",
        predicate = function(dv)
            return CheckDvResultNumber(dv, function(v) return v >= 26 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        seq = 5
    }

    -- VBG
    phMultiDVLinks = GetDiscreteValueLinks {
        discreteValueNames = { "pH Ven (pH Units)" },
        text = "PH",
        predicate = function(dv)
            return CheckDvResultNumber(dv, function(v) return v < 7.30 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        maxPerValue = 10
    } or {}

    -- Main Algorithm
    if #accountAlertCodes >= 1 or (
        (acuteRespAcidosisAbsLink or chronicRespAcidosisAbsLink) and
        (ExistingAlert and ExistingAlert.subtitle ~= "Acidosis Unspecified Dx Present")
    ) then
        if ExistingAlert then
            if #accountAlertCodes == 1 then
                for _, code in ipairs(accountAlertCodes) do
                    local desc = alertCodeDictionary[code]
                    GetCodeLinks { target = DocumentationIncludesLinks, code = code, text = "Autoresolved Specified Code - " + desc }
                end
            end
            if acuteRespAcidosisAbsLink then
               table.insert(DocumentationIncludesLinks, acuteRespAcidosisAbsLink)
            end
            if chronicRespAcidosisAbsLink then
               table.insert(DocumentationIncludesLinks, chronicRespAcidosisAbsLink)
            end
            Result.outcome = "AUTORESOLVED"
            Result.reason = "Autoresolved due to one Specified Code on the Account"
            Result.validated = true
            AlertAutoResolved = true
        else
            Result.passed = false
        end
    elseif #highSerumLactateDVLinks > 0 then
        --- @cast highSerumLactateDVLinks CdiAlertLink[]
        for _, link in ipairs(highSerumLactateDVLinks) do
            table.insert(DocumentationIncludesLinks, link)
        end
        Result.subtitle = "Possible Lactic Acidosis"
        AlertMatched = true
    elseif (
        e8720CodeLink and
        (#lowArterialBloodPHMultiDVLinks > 0 or  #phMultiDVLinks > 0 or #bloodCO2MultiDVLinks > 0) and
        (albuminMedLink or fluidBolusMedLink or fluidBolusAbsLink or fluidResucAbsLink or sodiumBicarMedLink)
    ) then
        if #lowArterialBloodPHMultiDVLinks > 0 then
            --- @cast lowArterialBloodPHMultiDVLinks CdiAlertLink[]
            for _, link in ipairs(lowArterialBloodPHMultiDVLinks) do
                --- @cast phLinks CdiAlertLink[]
                table.insert(phLinks, link)
            end
        end
        if #phMultiDVLinks > 0 then
            --- @cast phMultiDVLinks CdiAlertLink[]
            for _, link in ipairs(phMultiDVLinks) do
                --- @cast phLinks CdiAlertLink[]
                table.insert(phLinks, link)
            end
        end
        if bloodCO2MultiDVLinks and #bloodCO2MultiDVLinks > 0 then
            --- @cast bloodCO2MultiDVLinks CdiAlertLink[]
            for _, link in ipairs(bloodCO2MultiDVLinks) do
                --- @cast bloodLinks CdiAlertLink[]
                table.insert(bloodLinks, link)
            end
        end
        if bloodLinks and #bloodLinks > 0 then
            bloodHeader.links = bloodLinks
            table.insert(DocumentationIncludesLinks, bloodHeader)
        end
        if phLinks and #phLinks > 0 then
            phHeader.links = phLinks
            table.insert(DocumentationIncludesLinks, phHeader)
        end
        if albuminMedLink then table.insert(DocumentationIncludesLinks, albuminMedLink) end
        if fluidBolusMedLink then table.insert(DocumentationIncludesLinks, fluidBolusMedLink) end
        if fluidBolusAbsLink then table.insert(DocumentationIncludesLinks, fluidBolusAbsLink) end
        if fluidResucAbsLink then table.insert(DocumentationIncludesLinks, fluidResucAbsLink) end
        if sodiumBicarMedLink then table.insert(DocumentationIncludesLinks, sodiumBicarMedLink) end
        table.insert(DocumentationIncludesLinks, e8720CodeLink)
        dvTrigger = true
        Result.subtitle = "Acidosis Unspecified Dx Present"
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
    AddEvidenceCode("R41.82", "Altered Level of Consciousness", 1)
    AddEvidenceAbs("AZOTEMIA", "Azotemia", 2)
    AddEvidenceCode("R11.14", "Bilious Vomiting", 3)
    AddEvidenceCode("R11.15", "Cyclical Vomiting", 4)
    AddEvidenceAbs("DIARRHEA", "Diarrhea", 5)
    AddEvidenceCode("R53.83", "Fatigue", 6)
    AddEvidenceCode("E16.2", "Hypoglycemia", 7)
    AddEvidenceCode("R09.02", "Hypoxemia", 8)
    AddEvidenceAbs("OPIOID_OVERDOSE", "Opioid Overdose", 9)
    AddEvidenceCode("R11.12", "Projectile Vomiting", 10)
    AddEvidenceAbs("SHORTNESS_OF_BREATH", "Shortness of Breath", 11)
    AddEvidenceCode("R11.10", "Vomiting", 12)
    AddEvidenceCode("R11.13", "Vomiting Fecal Matter", 13)
    AddEvidenceCode("R11.11", "Vomiting Without Nausea", 14)
    AddEvidenceAbs("WEAKNESS", "Weakness", 15)

    -- Labs
    AddLabsDv("Anion Gap (mmol/L)", "Anion Gap", 1, function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 12 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)
    AddLabsAbs("HIGH_ANION_GAP", "Anion Gap", 2)
    AddLabsAbs("LOW_BLOOD_PH", "Blood PH", 3)
    AddLabsAbs("HIGH_BLOOD_C02", "Aterial Blood Carbon Dioxide", 4)
    AddLabsDv("Base Excess Art (mmol/L)", "Base Excess", 5, function(dv)
        return CheckDvResultNumber(dv, function(v) return v < -2 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)
    AddLabsAbs("LOW_BASE_EXCESS", "Base Excess", 6)
    AddLabsDv("Bilirubin Total (mg/dL)", "Bilirubin", 7, function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 2.0 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)

    AddLabsDv("C Blood", "Blood Culture Result", 8, function(dv)
        return dv.result ~= nil and string.find(dv.result, "%bPositive%b") ~= nil and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)
    AddLabsDv("C Sepsis Blood", "Sepsis Blood Culture Result", 9, function(dv)
        return dv.result ~= nil and string.find(dv.result, "%bPositive%b") ~= nil and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)

    local glucoseLink = AddLabsDv("Blood Glucose Lvl (mg/dL)", "Blood Glucose", 10, function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 250 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)
    if not glucoseLink then
        AddLabsDv("Blood Glucose POC (mg/dL)", "Blood Glucose POC", 11, function(dv)
            return CheckDvResultNumber(dv, function(v) return v > 250 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end)
    end
    AddLabsDv("CRP (mg/dL)", "C Reactive Protein", 12, function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 0.5 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)
    AddLabsDv("INR", "INR", 13, function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 1.5 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)
    AddLabsDv("Platelets (10x3/uL)", "Platelet Count", 14, function(dv)
        return CheckDvResultNumber(dv, function(v) return v < 100 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)
    AddLabsDv("Procalcitonin (ng/mL)", "Procalcitonin", 15, function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 0.49 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)
    AddLabsDv("SpO2 (%)", "Pulse Oxygen", 16, function(dv)
        return CheckDvResultNumber(dv, function(v) return v < 92 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)
    AddLabsDv("BUN (mg/dL)", "Serum Blood Urea Nitrogen", 17, function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 30 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)
    AddLabsAbs("HIGH_SERUM_BLOOD_UREA_NITROGEN", "Serum Blood Urea Nitrogen", 18)
    AddLabsAbs("NORMAL_SERUM_BICARBONATE", "Serum Bicarbonate", 19)
    AddLabsAbs("HIGH_SERUM_BICARBONATE", "Serum Bicarbonate", 20)
    AddLabsAbs("LOW_SERUM_BICARBONATE", "Serum Bicarbonate", 21)
    AddLabsDv("Chloride Lvl (mmol/L)", "Serum Chloride", 22, function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 107 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)
    AddLabsAbs("HIGH_SERUM_CHLORIDE", "Serum Chloride", 23)
    AddLabsDv("Creatinine Lvl (mg/dL)", "Serum Creatinine", 24, function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 1.2 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)
    AddLabsAbs("HIGH_SERUM_CREATININE", "Serum Creatinine", 25)
    AddLabsAbs("HIGH_SERUM_LACTATE", "Serum Lactate", 26)
    AddLabsDv("KETONES:SCNC:PT:BLD:QN:", "Serum Ketones", 27, function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 0 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)
    if Account.patient.gender == "F" then
        AddLabsDv("hs Troponin (ng/L)", "Troponin T High Sensitivity Female", 28, function(dv)
            return CheckDvResultNumber(dv, function(v) return v > 14 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end)
        AddLabsAbs("ELEVATED_TROPONIN_T_HIGH_SENSITIVITY_FEMALE", "Troponin T High Sensitivity Female", 29)
    elseif Account.patient.gender == "M" then
        AddLabsDv("hs Troponin (ng/L)", "Troponin T High Sensitivity Male", 28, function(dv)
            return CheckDvResultNumber(dv, function(v) return v > 22 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end)
        AddLabsAbs("ELEVATED_TROPONIN_T_HIGH_SENSITIVITY_MALE", "Troponin T High Sensitivity Male", 29)
    end
    AddLabsDv("UA Ketones", "Urine Ketones", 30, function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 0 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)
    AddLabsDv("WBC (10x3/uL)", "WBC", 31, function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 12 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)

    -- Labs Subheadings
    if not dvTrigger then
        if lowArterialBloodPHMultiDVLinks and #lowArterialBloodPHMultiDVLinks > 0 then
            for _, link in ipairs(lowArterialBloodPHMultiDVLinks) do
                --- @cast phLinks CdiAlertLink[]
                table.insert(phLinks, link)
            end
        end
        if phMultiDVLinks and #phMultiDVLinks > 0 then
            for _, link in ipairs(phMultiDVLinks) do
                --- @cast phLinks CdiAlertLink[]
                table.insert(phLinks, link)
            end
        end
        if bloodCO2MultiDVLinks and #bloodCO2MultiDVLinks > 0 then
            for _, link in ipairs(bloodCO2MultiDVLinks) do
                --- @cast bloodLinks CdiAlertLink[]
                table.insert(bloodLinks, link)
            end
        end

        -- Merge in the ABG and VBG links subheadings
        if bloodLinks and #bloodLinks > 0 then
            bloodHeader.links = bloodLinks
            table.insert(LabsLinks, bloodHeader)
        end
        if phLinks and #phLinks > 0 then
            phHeader.links = phLinks
            table.insert(LabsLinks, phHeader)
        end
    end

    -- Oxygen
    GetCodeLinks { target = oxygenLinks, codes = { "5A1522F", "5A1522G", "5A1522H", "5A15A2F", "5A15A2G", "5A15A2H" }, text = "ECMO Code", seq = 5 }
    GetCodeLinks { target = oxygenLinks, codes = { "5A0935A", "5A0945A", "5A0955A" }, text = "High Flow Nasal Oxygen", seq = 2 }
    GetCodeLinks { target = oxygenLinks, code = "0BH17EZ", text = "Intubation", seq = 7 }
    GetCodeLinks { target = oxygenLinks, codes = { "5A1935Z", "5A1945Z", "5A1955Z" }, text = "Invasive Mechanical Ventilation", seq = 3 }
    GetAbstractionLinks { target = oxygenLinks, code = "NON_INVASIVE_VENTILATION", text = "Non-Invasive Ventilation", seq = 4 }
    GetDiscreteValueLinks { target = oxygenLinks, discreteValueNames = { "Oxygen Flow Rate (L/min)" }, text = "Oxygen Flow Rate", predicate = function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 2 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end, seq = 6 }
    GetDiscreteValueLinks { target = oxygenLinks, discreteValueNames = { "Oxygen Therapy" }, text = "Oxygen Therapy", predicate = function(dv)
        return (
            dv.result ~= nil and
            string.find(dv.result, "%bRoom Air%b") == nil and
            string.find(dv.result, "%bRA%b") == nil and
            DateIsLessThanXDaysAgo(dv.result_date, 365)
        )
    end, seq = 3 }

    -- Vitals
    AddVitalsDv("Glasgow Coma Score", "Glasgow Coma Score", 1, function(dv)
        return CheckDvResultNumber(dv, function(v) return v <= 14 end)
    end)
    AddVitalsAbs("LOW_GLASGOW_COMA_SCORE", "Glasgow Coma Score", 2)
    AddVitalsDvs({ "Peripheral Pulse Rate", "Heart Rate Monitored (bpm)", "Peripheral Pulse Rate (bpm)" }, "Heart Rate", 3, function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 90 end)
    end)
    AddVitalsAbs("HIGH_HEART_RATE", "Heart Rate", 4)
    AddVitalsDv("Mean Arterial Pressure", "Mean Arterial Pressure", 5, function(dv)
        return CheckDvResultNumber(dv, function(v) return v < 70 end)
    end)
    AddVitalsAbs("LOW_MEAN_ARTERIAL_BLOOD_PRESSURE", "Mean Arterial Pressure", 6)
    AddVitalsDvs({ "Respiratory Rate", "Respiratory Rate (br/min)" }, "Respiratory Rate", 7, function(dv)
        return CheckDvResultNumber(dv, function(v) return v < 12 end)
    end)
    AddVitalsAbs("LOW_RESPIRATORY_RATE", "Respiratory Rate", 8)
    AddVitalsDvs({ "Respiratory Rate", "Respiratory Rate (br/min)" }, "Respiratory Rate", 9, function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 20 end)
    end)
    AddVitalsAbs("HIGH_RESPIRATORY_RATE", "Respiratory Rate", 10)
    AddVitalsDvs({ "Systolic Blood Pressure", "Systolic Blood Pressure (mmHg)" }, "Systolic Blood Pressure", 11, function(dv)
        return CheckDvResultNumber(dv, function(v) return v < 90 end)
    end)
    AddVitalsAbs("LOW_SYSTOLIC_BLOOD_PRESSURE", "Systolic Blood Pressure", 12)

    -- ABG
    if highArterialBloodC02DVLink then
        --- @cast abgLinks CdiAlertLink[]
        table.insert(abgLinks, highArterialBloodC02DVLink)
    else
        local dvArterialBloodC02Link = GetDiscreteValueLinks {
            target = abgLinks,
            discreteValueName = "pCO2 Art (mmHg)",
            text = "pC02",
            predicate = function(dv)
                return CheckDvResultNumber(dv, function(v) return v < 30 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
            end,
            seq = 2
        }
        if not dvArterialBloodC02Link then
            dvArterialBloodC02Link = GetDiscreteValueLinks {
                target = abgLinks,
                discreteValueName = "pCO2 Art (mmHg)",
                text = "pC02",
                predicate = function(dv)
                    return CheckDvResultNumber(dv, function(v) return v <= 45 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
                end,
                seq = 2
            }
        end
    end
    local dvPaO2Link = GetDiscreteValueLinks {
        target = abgLinks,
        discreteValueName = "pO2 Art (mmHg)",
        text = "p02",
        predicate = function(dv)
            return CheckDvResultNumber(dv, function(v) return v < 80 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        seq = 3
    }
    if not dvPaO2Link then
        GetDiscreteValueLinks {
            target = abgLinks,
            discreteValueName = "pO2 Art (mmHg)",
            text = "p02",
            predicate = function(dv)
                return CheckDvResultNumber(dv, function(v) return v >= 80 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
            end,
            seq = 3
        }
    end

    GetDiscreteValueLinks {
        target = abgLinks,
        discreteValueName = "FiO2 Art (%)",
        text = "Fi02",
        predicate = function(dv)
            return CheckDvResultNumber(dv, function(v) return v <= 100 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        seq = 4
    }

    if highSerumBicarbonateDVLink then
        --- @cast abgLinks CdiAlertLink[]
        table.insert(abgLinks, highSerumBicarbonateDVLink)
    else
        local dvSerumBicarbonateLink = GetDiscreteValueLinks {
            target = abgLinks,
            discreteValueName = "HCO3 Art (mmol/L)",
            text = "HC03",
            predicate = function(dv)
                return CheckDvResultNumber(dv, function(v) return v < 26 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
            end,
            seq = 5
        }
        if not dvSerumBicarbonateLink then
            dvSerumBicarbonateLink = GetDiscreteValueLinks {
                target = abgLinks,
                discreteValueName = "HCO3 Art (mmol/L)",
                text = "HC03",
                predicate = function(dv)
                    return CheckDvResultNumber(dv, function(v) return v < 22 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
                end,
                seq = 5
            }
        end
    end

    -- VBG
    if #abgLinks <= 0 then
        GetDiscreteValueLinks {
            target = vbgLinks,
            discreteValueName = "HCO3 Ven (mmol/L)",
            text = "HC03",
            predicate = function(dv)
                return CheckDvResultNumber(dv, function(v) return v >= 26 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
            end,
            seq = 1
        }
        GetDiscreteValueLinks {
            target = vbgLinks,
            discreteValueName = "pCO2 Ven (mmHg)",
            text = "pC02",
            predicate = function(dv)
                return CheckDvResultNumber(dv, function(v) return v > 55 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
            end,
            seq = 2
        }
    end
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

