---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Acidosis
---
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
---
--- This script checks an account to see if it matches the criteria for an acidosis alert.
---
---------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Requires 
--------------------------------------------------------------------------------
require("libs.common")



--------------------------------------------------------------------------------
--- Setup
--------------------------------------------------------------------------------
local existingAlert = GetExistingCdiAlert { scriptName = ScriptName }
local subtitle = existingAlert and existingAlert.subtitle or nil



if not existingAlert or not existingAlert.validated then
    --------------------------------------------------------------------------------
    --- Alert Variables 
    --------------------------------------------------------------------------------
    --- @type string[]
    local anionGapDvName = { "" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local anionGap1Predicate = function(dv) return GetDvValueNumber(dv) > 14 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local arterialBloodPHDvName = { "pH" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local arterialBloodPH1Predicate = function(dv) return GetDvValueNumber(dv) < 7.32 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type (fun (dv:DiscreteValue): boolean)
    local arterialBloodPH2Predicate = function (dv) return GetDvValueNumber(dv) < 7.32 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local baseExcessDvName = { "BASE EXCESS (mmol/L)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local baseExcess1Predicate = function(dv) return GetDvValueNumber(dv) < -2 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local bloodCO2DvName = { "CO2 (mmol/L)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local bloodCO21Predicate = function(dv) return GetDvValueNumber(dv) < 21 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type (fun (dv:DiscreteValue): boolean)
    local bloodCO22Predicate = function(dv) return GetDvValueNumber(dv) > 32 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local bloodGlucoseDvName = {  "GLUCOSE (mg/dL)", "GLUCOSE" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local bloodGlucose1Predicate = function(dv) return GetDvValueNumber(dv) > 250 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local bloodGlucosePOCDvName = { "GLUCOSE ACCUCHECK (mg/dL)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local bloodGlucosePOC1Predicate = function(dv) return GetDvValueNumber(dv) > 250 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local fIO2DvName = { "FIO2" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local fIO21Predicate = function(dv) return GetDvValueNumber(dv) <= 100 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local glasgowComaScaleDvName = { "3.5 Neuro Glasgow Score" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local glasgowComaScale1Predicate = function(dv) return GetDvValueNumber(dv) < 15 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local hCO3DvName = { "HCO3 VENOUS (meq/L)" }
    local hCO31Predicate = 22
    local hCO32Predicate = 26
    --- @type string[]
    local heartRateDvName = { "Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)", "3.5 Heart Rate (Radial) (bpm)",  "SCC Monitor Pulse (bpm)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local heartRate1Predicate = function(dv) return GetDvValueNumber(dv) > 90 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local mAPDvName = { "Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local mAP1Predicate = function(dv) return GetDvValueNumber(dv) < 70 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local paO2DvName = { "BLD GAS O2 (mmHg)" }
    local pAO21Predicate = 60
    --- @type string[]
    local pO2DvName = { "BLD GAS O2 (mmHg)", "PO2 (mmHg)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local pO21Predicate = function(dv) return GetDvValueNumber(dv) < 80 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local pCO2DvName = { "BLD GAS CO2 (mmHg)", "PaCO2 (mmHg)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local pCO21Predicate = function(dv) return GetDvValueNumber(dv) > 50 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type (fun (dv:DiscreteValue): boolean)
    local pCO22Predicate = function(dv) return GetDvValueNumber(dv) < 30 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local pHDvName = { "pH (VENOUS)", "pH VENOUS" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local pH1Predicate = function(dv) return GetDvValueNumber(dv) < 7.30 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type (fun (dv:DiscreteValue): boolean)
    local pH2Predicate = function(dv) return GetDvValueNumber(dv) < 7.30 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local respiratoryRateDvName = { "3.5 Respiratory Rate (#VS I&O) (per Minute)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local respiratoryRate1Predicate = function(dv) return GetDvValueNumber(dv) > 20 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type (fun (dv:DiscreteValue): boolean)
    local respiratoryRate2Predicate = function(dv) return GetDvValueNumber(dv) < 12 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local sBPDvName = { "SBP 3.5 (No Calculation) (mm Hg)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local sBP1Predicate = function(dv) return GetDvValueNumber(dv) < 90 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local serumBloodUreaNitrogenDvName = { "BUN (mg/dL)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local serumBloodUreaNitrogen1Predicate = function(dv) return GetDvValueNumber(dv) > 23 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local serumBicarbonateDvName = { "HCO3 (meq/L)", "HCO3 (mmol/L)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local serumBicarbonate1Predicate = function(dv) return GetDvValueNumber(dv) > 26 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type (fun (dv:DiscreteValue): boolean)
    local serumBicarbonate3Predicate = function(dv) return GetDvValueNumber(dv) < 22 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local serumChlorideDvName = { "CHLORIDE (mmol/L)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local serumChloride1Predicate = function(dv) return GetDvValueNumber(dv) > 107 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local serumCreatinineDvName = { "CREATININE (mg/dL)", "CREATININE SERUM (mg/dL)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local serumCreatinine1Predicate = function(dv) return GetDvValueNumber(dv) > 1.3 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local serumLactateDvName = { "LACTIC ACID (mmol/L)", "LACTATE (mmol/L)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local serumLactate1Predicate = function(dv) return GetDvValueNumber(dv) >= 4 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type (fun (dv:DiscreteValue): boolean)
    local serumLactate2Predicate = function(dv) return 2 < GetDvValueNumber(dv) < 4 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local sPO2DvName = { "Pulse Oximetry(Num) (%)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local sPO21Predicate = function(dv) return GetDvValueNumber(dv) < 90 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local venousBloodCO2DvName = { "BLD GAS CO2 VEN (mmHg)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local venousBloodCO2Predicate = function(dv) return GetDvValueNumber(dv) > 55 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    local serumKetoneDvName = { "KETONES (mg/dL)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local serumKetone1Predicate = function(dv) return GetDvValueNumber(dv) > 0 and DateIsLessThanXDaysAgo(dv.result_date, 7) end
    --- @type string[]
    local urineKetonesDvName = { "UR KETONES (mg/dL)", "KETONES (mg/dL)" }

    
    local alertCodeDictionary = {
        ["E08.10"] = "Diabetes mellitus due to underlying condition with ketoacidosis without coma",
        ["E08.11"] = "Diabetes mellitus due to underlying condition with ketoacidosis with coma",
        ["E09.10"] = "Drug or chemical induced diabetes mellitus with ketoacidosis without coma",
        ["E09.11"] = "Drug or chemical induced diabetes mellitus with ketoacidosis with coma",
        ["E10.10"] = "Type 1 diabetes mellitus with ketoacidosis without coma",
        ["E10.11"] = "Type 1 diabetes mellitus with ketoacidosis with coma",
        ["E11.10"] = "Type 2 diabetes mellitus with ketoacidosis without coma",
        ["E11.11"] = "Type 2 diabetes mellitus with ketoacidosis with coma",
        ["E13.10"] = "Other specified diabetes mellitus with ketoacidosis without coma",
        ["E13.11"] = "Other specified diabetes mellitus with ketoacidosis with coma",
        ["E87.4"] = "Mixed disorder of acid-base balance",
        ["E87.21"] = "Acute Metabolic Acidosis",
        ["E87.22"] = "Chronic Metabolic Acidosis",
        ["P74.0"] = "Late metabolic acidosis of newborn"
    }
    local accountAlertCodes = GetAccountCodesInDictionary(Account, alertCodeDictionary)



    --------------------------------------------------------------------------------
    --- Top-Level Link Header Variables
    --------------------------------------------------------------------------------
    local resultLinks = {}
    
    local documentedDxHeader = MakeHeaderLink("Documented Dx")
    local documentedDxLinks = {}
    local labsHeader = MakeHeaderLink("Laboratory Studies")
    local labsLinks = {}
    local vitalSignsIntakeHeader = MakeHeaderLink("Vital Signs/Intake")
    local vitalSignsIntakeLinks = {}
    local clinicalEvidenceHeader = MakeHeaderLink("Clinical Evidence")
    local clinicalEvidenceLinks = {}
    local treatmentAndMonitoringHeader = MakeHeaderLink("Treatment and Monitoring")
    local treatmentAndMonitoringLinks = {}
    local otherHeader = MakeHeaderLink("Other")
    local otherLinks = {}
    local abgHeader = MakeHeaderLink("ABG")
    local abgLinks = {}
    local vbgHeader = MakeHeaderLink("VBG")
    local vbgLinks = {}
    local bloodCO2Header = MakeHeaderLink("Blood CO2")
    local bloodCO2Links = {}
    local phHeader = MakeHeaderLink("PH")
    local phLinks = {}
    local lactateHeader = MakeHeaderLink("Lactate")
    local lactateLinks = {}
    local pC02Header = MakeHeaderLink("pC02")
    local pC02Links = {}
    local hC03Header = MakeHeaderLink("HC03")
    local hC03Links = {}
    local pao2Header = MakeHeaderLink("paO2")
    local pao2Links = {}
    local hC03HeaderTwo = MakeHeaderLink("HC03")
    local hC03LinksTwo = {}
    local pC02HeaderTwo = MakeHeaderLink("PC02")
    local pC02LinksTwo = {}
    local paC02Header = MakeHeaderLink("paC02")
    local paC02Links = {}



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    local chronicRepiratoryAcidosisAbstractionLink = GetAbstractionLinks { code = "CHRONIC_RESPIRATORY_ACIDOSIS", text = "Chronic Respiratory Acidosis" }
    local metaAcidosisAbstractionLink = GetAbstractionLinks { code = "METABOLIC_ACIDOSIS", text = "Metabolic Acidosis" }
    local acuteAcidosisAbtractionLink = GetAbstractionLinks { code = "ACUTE_ACIDOSIS", text = "Acute Acidosis" }
    local chronicAcidosisAbstractionLink = GetAbstractionLinks { code = "CHRONIC_ACIDOSIS", text = "Chronic Acidosis" }
    local lacticAcidosisAbstractionLink = GetAbstractionLinks { code = "LACTIC_ACIDOSIS", text = "Lactic Acidosis" }
    local e8720CodeLink = GetCodeLinks { code = "E87.20", text = "Acidosis Unspecified" }
    local e8729CodeLink = GetCodeLinks { code = "E87.29", text = "Other Acidosis" }

    -- Documented Dx
    local acuteRespiratoryAcidosisAbstractionLink = GetAbstractionLinks { code = "ACUTE_RESPIRATORY_ACIDOSIS", text = "Acute Respiratory Acidosis" }
    local j9602CodeLink = GetCodeLinks { code = "J96.02", text = "Acute Respiratory Failure with Hypercapnia" }
    -- Labs Subheading
    local bloodCO2DvLinks = GetDiscreteValueLinks { 
        dvNames = bloodCO2DvName,
        predicate = bloodCO21Predicate,
        text = "Blood CO2",
        maxPerValue = 9999,
        target = bloodCO2Links
    }
    local highSerumLactateLevelDvLinks = GetDiscreteValueLinks {
        dvNames = serumLactateDvName,
        predicate = serumLactate1Predicate,
        text = "Serum Lactate",
        maxPerValue = 9999,
        target = lactateLinks
    }

    -- ABG Subheading
    local lowArterialBloodPHMultiDiscreteValueLinks = GetDiscreteValueLinks {
        dvNames = arterialBloodPHDvName,
        predicates = arterialBloodPH2Predicate,
        text = "PH",
        maxPerValue = 9999
    }
    local paco2DvLinks = GetDiscreteValueLinks {
        dvNames = pCO2DvName,
        predicate = pCO21Predicate,
        text = "paC02",
        maxPerValue = 9999
    }
    local highSerumBicarbonateDvLinks = GetDiscreteValueLinks {
        dvNames = serumBicarbonateDvName,
        predicate = serumBicarbonate1Predicate,
        text = "HC03",
        maxPerValue = 9999
    }
    -- VBG Subheading
    local phDvLinks = GetDiscreteValueLinks {
        dvNames = pHDvName,
        predicate = pH2Predicate,
        text = "PH",
        maxPerValue = 9999
    }
    local venousCO2DvLinks = GetDiscreteValueLinks {
        dvNames = venousBloodCO2DvName,
        predicate = venousBloodCO2Predicate,
        text = "pCO2",
        maxPerValue = 9999
    }




    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------




    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        local resultLinks = {}

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

