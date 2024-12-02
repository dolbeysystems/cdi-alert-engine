---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Acidosis
---
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
---
--- This script checks an account to see if it matches the criteria for an acidosis alert.
---
--- Alerts:
---     - Possible Acute Respiratory Acidosis
---         Triggered if the account has no mention of acute respiratory acidosis and no code,
---         but has lab values indicating possible acute respiratory acidosis.
--- 
---         Autoresolved if the account has a specified code for acute respiratory acidosis, or if
---         acute respiratory acidosis is mentioned/abstracted
--- 
---     - Acute Respiratory Acidosis Documented Possibly Lacking Supporting Evidence
---         Triggered if the account has a specified code for acute respiratory acidosis, but no lab values
---         indicating acute respiratory acidosis.
--- 
---         Autoresolved if the account has lab values indicating acute respiratory acidosis.
--- 
---     - Possible Lactic Acidosis
---         Triggered if the account has no specified code for lactic acidosis, but has lab values indicating
---         high serum lactate levels.
--- 
---         Autoresolved if the account has a specified code for acidosis
--- 
---     - Possible Acidosis
---         Triggered if the account has no specified code for acidosis, but has lab values or medications
---         indicating possible acidosis.
--- 
---         Autoresolved if the account has a specified code for acidosis
--- 
--- Possible Links:
---     - Documented Dx
---         - Specified Codes (Code) [multiple]
---     - Clinical Evidence 
---         - Altered Level Of Consciousness (Code)
---         - Altered Level Of Consciousness (Abstraction)
---         - Azotemia (Abstraction)
---         - Bilious Vomiting (Code)
---         - Cyclical Vomiting (Code)
---         - Diarrhea (Abstraction)
---         - Disorientation (Code)
---         - Fi02 (Discrete Value)
---         - Fatigue (Code)
---         - Opioid Overdose (Abstraction)
---         - Shortness of Breath (Abstraction)
---         - Vomiting (Code)
---         - Vomiting Fecal Matter (Code)
---         - Vomiting Without Nausea (Code)
---         - Weakness (Abstraction)
---     - Laboratory Studies
---         - Anion Gap (Discrete Value)
---         - Blood Glucose (Discrete Value)
---         - Blood Glucose POC (Discrete Value)
---         - Positive Ketones In Urine (Abstraction)
---         - Serum Blood Urea Nitrogen (Discrete Value)
---         - Serum Chloride (Discrete Value)
---         - Serum Creatinine (Discrete Value)
---         - Serum Ketones (Discrete Value)
---         - Urine Ketones (Discrete Value)
---         - ABG
---             - Base Excess (Discrete Value)
---             - FIO2 (Discrete Value)
---             - PO2 (Discrete Value)
---             - paCO2
---                 - paCO2 (Discrete Value) [multiple]
---             - PCO2
---                 - PCO2 (Discrete Value) [multiple]
---             - paO2
---                 - paO2 (Discrete Value) [multiple]
---             - HCO3
---                 - HCO3 (Discrete Value) [multiple]
---         - VBG
---             - pCO2
---                 - pCO2 (Discrete Value) [multiple]
---             - hCO3
---                 - hCO3 (Discrete Value) [multiple]
---         - Blood CO2
---             - Blood CO2 (Discrete Value) [multiple]
---         - PH
---             - Low arterial blood ph (Discrete Value) [multiple]
---         - Lactate
---             - Serum Lactate Levels (Discrete Value) [multiple]
---     - Vital Signs/Intake
---         - Glasgow Coma Scale (Discrete Value)
---         - Heart Rate (Discrete Value) [multiple]
---         - Mean Arterial Pressure (Discrete Value)
---         - Respiratory Rate (Discrete Value)
---         - SpO2 (Discrete Value)
---         - Systolic Blood Pressure (Discrete Value)
---         
---     - Treatment and Monitoring
---         - Fluid Bolus (Abstraction)
---         - Fluid Resuscitation (Abstraction)
---         - Sodium Bicarbonate (Abstraction)
---         - Albumin (Medication) [multiple]
---         - Fluid Bolus (Medication) [multiple]
---         - Sodium Bicarbonate (Medication) [multiple]
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
    local anionGap1Predicate = function(dv) return GetDvValueNumber(dv) > 14 end
    --- @type string[]
    local arterialBloodPHDvName = { "pH" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local arterialBloodPH1Predicate = function(dv) return GetDvValueNumber(dv) < 7.32 end
    --- @type (fun (dv:DiscreteValue): boolean)
    local arterialBloodPH2Predicate = function (dv) return GetDvValueNumber(dv) < 7.32 end
    --- @type string[]
    local baseExcessDvName = { "BASE EXCESS (mmol/L)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local baseExcess1Predicate = function(dv) return GetDvValueNumber(dv) < -2 end
    --- @type string[]
    local bloodCO2DvName = { "CO2 (mmol/L)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local bloodCO21Predicate = function(dv) return GetDvValueNumber(dv) < 21 end
    --- @type (fun (dv:DiscreteValue): boolean)
    local bloodCO22Predicate = function(dv) return GetDvValueNumber(dv) > 32 end
    --- @type string[]
    local bloodGlucoseDvName = {  "GLUCOSE (mg/dL)", "GLUCOSE" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local bloodGlucose1Predicate = function(dv) return GetDvValueNumber(dv) > 250 end
    --- @type string[]
    local bloodGlucosePOCDvName = { "GLUCOSE ACCUCHECK (mg/dL)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local bloodGlucosePOC1Predicate = function(dv) return GetDvValueNumber(dv) > 250 end
    --- @type string[]
    local fIO2DvName = { "FIO2" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local fIO21Predicate = function(dv) return GetDvValueNumber(dv) <= 100 end
    --- @type string[]
    local glasgowComaScaleDvName = { "3.5 Neuro Glasgow Score" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local glasgowComaScale1Predicate = function(dv) return GetDvValueNumber(dv) < 15 end
    --- @type string[]
    local hCO3DvName = { "HCO3 VENOUS (meq/L)" }
    local hCO31Predicate = function(dv) return GetDvValueNumber(dv) < 22 end
    local hCO32Predicate = function(dv) return GetDvValueNumber(dv) > 26 end
    --- @type string[]
    local heartRateDvName = { "Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)", "3.5 Heart Rate (Radial) (bpm)",  "SCC Monitor Pulse (bpm)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local heartRate1Predicate = function(dv) return GetDvValueNumber(dv) > 90 end
    --- @type string[]
    local mAPDvName = { "Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local mAP1Predicate = function(dv) return GetDvValueNumber(dv) < 70 end
    --- @type string[]
    local paO2DvName = { "BLD GAS O2 (mmHg)" }
    local pAO21Predicate = function(dv) return GetDvValueNumber(dv) < 60 end
    --- @type string[]
    local pO2DvName = { "BLD GAS O2 (mmHg)", "PO2 (mmHg)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local pO21Predicate = function(dv) return GetDvValueNumber(dv) < 80 end
    --- @type string[]
    local pCO2DvName = { "BLD GAS CO2 (mmHg)", "PaCO2 (mmHg)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local pCO21Predicate = function(dv) return GetDvValueNumber(dv) > 50 end
    --- @type (fun (dv:DiscreteValue): boolean)
    local pCO22Predicate = function(dv) return GetDvValueNumber(dv) < 30 end
    --- @type string[]
    local pHDvName = { "pH (VENOUS)", "pH VENOUS" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local pH1Predicate = function(dv) return GetDvValueNumber(dv) < 7.30 end
    --- @type (fun (dv:DiscreteValue): boolean)
    local pH2Predicate = function(dv) return GetDvValueNumber(dv) < 7.30 end
    --- @type string[]
    local respiratoryRateDvName = { "3.5 Respiratory Rate (#VS I&O) (per Minute)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local respiratoryRate1Predicate = function(dv) return GetDvValueNumber(dv) > 20 end
    --- @type (fun (dv:DiscreteValue): boolean)
    local respiratoryRate2Predicate = function(dv) return GetDvValueNumber(dv) < 12 end
    --- @type string[]
    local sBPDvName = { "SBP 3.5 (No Calculation) (mm Hg)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local sBP1Predicate = function(dv) return GetDvValueNumber(dv) < 90 end
    --- @type string[]
    local serumBloodUreaNitrogenDvName = { "BUN (mg/dL)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local serumBloodUreaNitrogen1Predicate = function(dv) return GetDvValueNumber(dv) > 23 end
    --- @type string[]
    local serumBicarbonateDvName = { "HCO3 (meq/L)", "HCO3 (mmol/L)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local serumBicarbonate1Predicate = function(dv) return GetDvValueNumber(dv) > 26 end
    --- @type (fun (dv:DiscreteValue): boolean)
    local serumBicarbonate3Predicate = function(dv) return GetDvValueNumber(dv) < 22 end
    --- @type string[]
    local serumChlorideDvName = { "CHLORIDE (mmol/L)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local serumChloride1Predicate = function(dv) return GetDvValueNumber(dv) > 107 end
    --- @type string[]
    local serumCreatinineDvName = { "CREATININE (mg/dL)", "CREATININE SERUM (mg/dL)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local serumCreatinine1Predicate = function(dv) return GetDvValueNumber(dv) > 1.3 end
    --- @type string[]
    local serumLactateDvName = { "LACTIC ACID (mmol/L)", "LACTATE (mmol/L)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local serumLactate1Predicate = function(dv) return GetDvValueNumber(dv) >= 4 end
    --- @type (fun (dv:DiscreteValue): boolean)
    local serumLactate2Predicate = function(dv) return 2 < GetDvValueNumber(dv) < 4 end
    --- @type string[]
    local sPO2DvName = { "Pulse Oximetry(Num) (%)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local sPO21Predicate = function(dv) return GetDvValueNumber(dv) < 90 end
    --- @type string[]
    local venousBloodCO2DvName = { "BLD GAS CO2 VEN (mmHg)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local venousBloodCO2Predicate = function(dv) return GetDvValueNumber(dv) > 55 end
    local serumKetoneDvName = { "KETONES (mg/dL)" }
    --- @type (fun (dv:DiscreteValue): boolean)
    local serumKetone1Predicate = function(dv) return GetDvValueNumber(dv) > 0 end
    --- @type string[]
    local urineKetonesDvName = { "UR KETONES (mg/dL)", "KETONES (mg/dL)" }

    local possibleAcuteRespiratoryAcidosisSubtitle = "Possible Acute Respiratory Acidosis"
    local respiratoryAcidosisLackingEvidenceSubtitle = "Acute Respiratory Acidosis Documented Possibly Lacking Supporting Evidence"
    local possibleLacticAcidosisSubtitle = "Possible Lactic Acidosis"
    local possibleAcidosisSubtitle = "Possible Acidosis"

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
    --- Predicate function filtering a medication list to only include medications 
    --- within 12 hours of one of these three discrete values: arterialBlood, pH, blood CO2
    --- 
    --- @param med Medication Medication being filtered
    --- 
    --- @return boolean True if the medication passes, false otherwise
    --------------------------------------------------------------------------------
    local acidosisMedPredicate = function (med)
        local medDvDates = {}
        for _, date in ipairs(GetDvDates(Account, arterialBloodPHDvName)) do table.insert(medDvDates, date) end
        for _, date in ipairs(GetDvDates(Account, pHDvName)) do table.insert(medDvDates, date) end
        for _, date in ipairs(GetDvDates(Account, bloodCO2DvName)) do table.insert(medDvDates, date) end

        local medDate = DateStringToInt(med.start_date)
        for _, dvDate in ipairs(medDvDates) do
            local dvDateAfter = dvDate + 12 * 60 * 60
            local dvDateBefore = dvDate - 12 * 60 * 60
            if medDate >= dvDateBefore and medDate <= dvDateAfter then
                return true
            end
        end
        return false
    end



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
    local venousCO2Header = MakeHeaderLink("pCO2")
    local venousCO2Links = {}
    local vbhCO3Header = MakeHeaderLink("HCO3")
    local vbhCO3Links = {}
    local paO2Header = MakeHeaderLink("paO2")
    local paO2Links = {}
    local abgHCO3Header = MakeHeaderLink("HCO3")
    local abgHCO3Links = {}
    local pCO2Header = MakeHeaderLink("PCO2")
    local pCO2Links = {}
    local paCO2Header = MakeHeaderLink("paCO2")
    local paCO2Links = {}



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
    } or {}
    local highSerumLactateLevelDvLinks = GetDiscreteValueLinks {
        dvNames = serumLactateDvName,
        predicate = serumLactate1Predicate,
        text = "Serum Lactate",
        maxPerValue = 9999,
        target = lactateLinks
    } or {}

    -- ABG Subheading
    local lowArterialBloodPHMultiDiscreteValueLinks = GetDiscreteValueLinks {
        dvNames = arterialBloodPHDvName,
        predicates = arterialBloodPH2Predicate,
        text = "PH",
        maxPerValue = 9999
    } or {}
    local paco2DvLinks = GetDiscreteValueLinks {
        dvNames = pCO2DvName,
        predicate = pCO21Predicate,
        text = "paC02",
        maxPerValue = 9999
    } or {}
    local highSerumBicarbonateDvLinks = GetDiscreteValueLinks {
        dvNames = serumBicarbonateDvName,
        predicate = serumBicarbonate1Predicate,
        text = "HC03",
        maxPerValue = 9999
    } or {}
    -- VBG Subheading
    local phDvLinks = GetDiscreteValueLinks {
        dvNames = pHDvName,
        predicate = pH2Predicate,
        text = "PH",
        maxPerValue = 9999
    } or {}
    local venousCO2DvLinks = GetDiscreteValueLinks {
        dvNames = venousBloodCO2DvName,
        predicate = venousBloodCO2Predicate,
        text = "pCO2",
        maxPerValue = 9999
    } or {}

    -- Meds
    local albuminMedicationLinks = GetMedicationLinks {
        cat = "Albumin",
        text = "Albumin",
        useCdiAlertCategoryField = true,
        maxPerValue = 9999,
        predicate = acidosisMedPredicate
    } or {}
    local fluidBolusMedicationLinks = GetMedicationLinks {
        cat = "Fluid Bolus",
        text = "Fluid Bolus",
        useCdiAlertCategoryField = true,
        maxPerValue = 9999,
        predicate = acidosisMedPredicate
    } or {}
    local fluidBolusAbstractionLink = GetAbstractionValueLinks {
        code = "FLUID_BOLUS",
        text = "Fluid Bolus"
    }
    local fluidResuscitationAbstractionLink = GetAbstractionValueLinks {
        code = "FLUID_RESCUSITATION",
        text = "Fluid Resuscitation"
    }
    local sodiumBicarbonateMedLinks = GetMedicationLinks {
        cat = "Sodium Bicarbonate",
        text = "Sodium Bicarbonate",
        useCdiAlertCategoryField = true,
        maxPerValue = 9999,
        predicate = acidosisMedPredicate
    } or {}
    local sodiumBicarbonateAbstractionLinks = GetAbstractionValueLinks {
        code = "SODIUM_BICARBONATE",
        text = "Sodium Bicarbonate"
    }

    local fullSpecifiedExist =
        #accountAlertCodes >= 1 or
        chronicRepiratoryAcidosisAbstractionLink ~= nil or
        lacticAcidosisAbstractionLink ~= nil or
        metaAcidosisAbstractionLink ~= nil

    local unspecifiedExist =
        e8720CodeLink ~= nil or
        e8729CodeLink ~= nil or
        acuteAcidosisAbtractionLink ~= nil or
        chronicAcidosisAbstractionLink ~= nil



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    -- Auto resolve alert if it currently triggered for acute respiratory acidosis
    if subtitle == possibleAcuteRespiratoryAcidosisSubtitle and (acuteRespiratoryAcidosisAbstractionLink or j9602CodeLink) then
        for _, code in pairs(accountAlertCodes) do
            local codeLink = GetCodeLinks {
                code = code,
                text = "Autoresolved Specified Code - " .. alertCodeDictionary[code]
            }
            if codeLink then
                table.insert(documentedDxLinks, codeLink)
                break
            end
        end

        if j9602CodeLink then
            j9602CodeLink.link_text = "Autoresolved Evidence - " .. j9602CodeLink.link_text
            table.insert(documentedDxLinks, j9602CodeLink)
        end
        if acuteRespiratoryAcidosisAbstractionLink then
            acuteAcidosisAbtractionLink.link_text = "Autoresolved Evidence - " .. acuteRespiratoryAcidosisAbstractionLink.link_text
            table.insert(documentedDxLinks, acuteRespiratoryAcidosisAbstractionLink)
        end

        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    -- Auto resolve alert if it currently triggered for Acute Respiratory Acidosis Possibly Lacking Supporting Evidence
    elseif
        subtitle == respiratoryAcidosisLackingEvidenceSubtitle and
        (#venousCO2DvLinks > 0 or #phDvLinks > 0) and
        (#lowArterialBloodPHMultiDiscreteValueLinks > 1 or #phDvLinks > 1)
    then
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    -- Auto resolve alert if it currently triggered for Possible Lactic Acidosis or Possible Acidosis
    elseif (subtitle == possibleLacticAcidosisSubtitle or subtitle == possibleAcidosisSubtitle) and (unspecifiedExist or fullSpecifiedExist) then
        if #accountAlertCodes > 0 then
            for _, code in pairs(accountAlertCodes) do
                local codeLink = GetCodeLinks {
                    code = code,
                    text = "Autoresolved Specified Code - " .. alertCodeDictionary[code]
                }
                if codeLink then
                    table.insert(documentedDxLinks, codeLink)
                    break
                end
            end
        end
        if lacticAcidosisAbstractionLink then
            lacticAcidosisAbstractionLink.link_text = "Autoresolved Evidence - " .. lacticAcidosisAbstractionLink.link_text
            table.insert(documentedDxLinks, lacticAcidosisAbstractionLink)
        end
        if chronicRepiratoryAcidosisAbstractionLink then
            chronicRepiratoryAcidosisAbstractionLink.link_text = "Autoresolved Evidence - " .. chronicRepiratoryAcidosisAbstractionLink.link_text
            table.insert(documentedDxLinks, chronicRepiratoryAcidosisAbstractionLink)
        end
        if metaAcidosisAbstractionLink then
            metaAcidosisAbstractionLink.link_text = "Autoresolved Evidence - " .. metaAcidosisAbstractionLink.link_text
            table.insert(documentedDxLinks, metaAcidosisAbstractionLink)
        end
        if e8720CodeLink then
            e8720CodeLink.link_text = "Autoresolved Evidence - " .. e8720CodeLink.link_text
            table.insert(documentedDxLinks, e8720CodeLink)
        end
        if e8729CodeLink then
            e8729CodeLink.link_text = "Autoresolved Evidence - " .. e8729CodeLink.link_text
            table.insert(documentedDxLinks, e8729CodeLink)
        end
        if acuteAcidosisAbtractionLink then
            acuteAcidosisAbtractionLink.link_text = "Autoresolved Evidence - " .. acuteAcidosisAbtractionLink.link_text
            table.insert(documentedDxLinks, acuteAcidosisAbtractionLink)
        end
        if chronicAcidosisAbstractionLink then
            chronicAcidosisAbstractionLink.link_text = "Autoresolved Evidence - " .. chronicAcidosisAbstractionLink.link_text
            table.insert(documentedDxLinks, chronicAcidosisAbstractionLink)
        end

        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    -- Trigger alert for Possible Acute Respiratory Acidosis
    elseif
        not acuteRespiratoryAcidosisAbstractionLink and
        not j9602CodeLink and
        (#venousCO2DvLinks > 0 or #paco2DvLinks > 0) and
        (#lowArterialBloodPHMultiDiscreteValueLinks > 0 or #phDvLinks > 0)
    then
        table.insert(documentedDxLinks, e8720CodeLink)
        table.insert(documentedDxLinks, e8729CodeLink)
        table.insert(documentedDxLinks, acuteAcidosisAbtractionLink)
        table.insert(documentedDxLinks, chronicAcidosisAbstractionLink)
        Result.subtitle = possibleAcuteRespiratoryAcidosisSubtitle
        Result.passed = true


    -- Trigger alert for Acute Respiratory Acidosis Documented Possibly Lacking Supporting Evidence
    elseif
        acuteRespiratoryAcidosisAbstractionLink and
        not venousCO2DvLinks and
        not paco2DvLinks and
        #lowArterialBloodPHMultiDiscreteValueLinks == 0 and
        #phDvLinks == 0
    then
        table.insert(documentedDxLinks, acuteRespiratoryAcidosisAbstractionLink)
        Result.subtitle = respiratoryAcidosisLackingEvidenceSubtitle
        Result.passed = true
   
    -- Trigger alert for Possible Lactic Acidosis
    elseif not fullSpecifiedExist and not unspecifiedExist and #highSerumLactateLevelDvLinks > 0 then
        Result.subtitle = possibleLacticAcidosisSubtitle
        Result.passed = true
    
    -- Trigger alert for Possible Acidosis
    elseif (
        not unspecifiedExist and
        not fullSpecifiedExist and
        (#lowArterialBloodPHMultiDiscreteValueLinks >= 1 or #phDvLinks >= 1 or #bloodCO2DvLinks >= 1) or
        (
            albuminMedicationLinks or
            fluidBolusMedicationLinks or
            fluidBolusAbstractionLink or
            fluidResuscitationAbstractionLink or
            sodiumBicarbonateMedLinks or
            sodiumBicarbonateAbstractionLinks
        )
    ) then
        if fluidBolusAbstractionLink then table.insert(treatmentAndMonitoringLinks, fluidBolusAbstractionLink) end
        if fluidResuscitationAbstractionLink then table.insert(treatmentAndMonitoringLinks, fluidResuscitationAbstractionLink) end
        if sodiumBicarbonateAbstractionLinks then table.insert(treatmentAndMonitoringLinks, sodiumBicarbonateAbstractionLinks) end
        for _, item in ipairs(albuminMedicationLinks or {}) do table.insert(treatmentAndMonitoringLinks, item) end
        for _, item in ipairs(fluidBolusMedicationLinks or {}) do table.insert(treatmentAndMonitoringLinks, item) end
        for _, item in ipairs(sodiumBicarbonateMedLinks or {}) do table.insert(treatmentAndMonitoringLinks, item) end

        Result.subtitle = possibleAcidosisSubtitle
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        local resultLinks = {}

        if not Result.validated then
            -- Clinical Evidence
            local r4182CodeLink = GetCodeLinks { code = "R41.82", text = "Altered Level Of Consciousness" }
            if r4182CodeLink then
                table.insert(clinicalEvidenceLinks, r4182CodeLink)
                local alteredAbsLink = GetAbstractionLinks { code = "ALTERED_LEVEL_OF_CONSCIOUSNESS", text = "Altered Level Of Consciousness" }
                if alteredAbsLink then
                    alteredAbsLink.hidden = true
                    table.insert(clinicalEvidenceLinks, alteredAbsLink)
                end
            elseif not r4182CodeLink then
                local alteredAbsLink = GetAbstractionLinks { code = "ALTERED_LEVEL_OF_CONSCIOUSNESS", text = "Altered Level Of Consciousness" }
                table.insert(clinicalEvidenceLinks, alteredAbsLink)
            end
            GetAbstractionLinks { code = "AZOTEMIA", text = "Azotemia", target = clinicalEvidenceLinks }
            GetCodeLinks { code = "R11.14", text = "Bilious Vomiting", target = clinicalEvidenceLinks }
            GetCodeLinks { code = "R11.15", text = "Cyclical Vomiting", target = clinicalEvidenceLinks }
            GetAbstractionLinks { code = "DIARRHEA", text = "Diarrhea", target = clinicalEvidenceLinks }
            GetCodeLinks { code = "R41.0", text = "Disorientation", target = clinicalEvidenceLinks }
            GetDiscreteValueLinks { dvNames = fIO2DvName, predicate = fIO21Predicate, text = "Fi02", target = clinicalEvidenceLinks }
            GetCodeLinks { code = "R53.83", text = "Fatigue", target = clinicalEvidenceLinks }
            GetAbstractionLinks { code = "OPIOID_OVERDOSE", text = "Opioid Overdose", target = clinicalEvidenceLinks }
            GetAbstractionLinks { code = "SHORTNESS_OF_BREATH", text = "Shortness of Breath", target = clinicalEvidenceLinks }
            GetCodeLinks { code = "R11.10", text = "Vomiting", target = clinicalEvidenceLinks }
            GetCodeLinks { code = "R11.13", text = "Vomiting Fecal Matter", target = clinicalEvidenceLinks }
            GetCodeLinks { code = "R11.11", text = "Vomiting Without Nausea", target = clinicalEvidenceLinks }
            GetAbstractionLinks { code = "WEAKNESS", text = "Weakness", target = clinicalEvidenceLinks }

            -- Labs
            GetDiscreteValueLinks { dvNames = anionGapDvName, predicate = anionGap1Predicate, text = "Anion Gap", target = labsLinks }
            if not GetDiscreteValueLinks { dvNames = bloodGlucoseDvName, predicate = bloodGlucose1Predicate, text = "Blood Glucose", target = labsLinks } then
                GetDiscreteValueLinks { dvNames = bloodGlucosePOCDvName, predicate = bloodGlucosePOC1Predicate, text = "Blood Glucose POC", target = labsLinks }
            end
            GetAbstractionLinks { code = "POSITIVE_KETONES_IN_URINE", text = "Positive Ketones In Urine", target = labsLinks }
            GetDiscreteValueLinks { dvNames = serumBloodUreaNitrogenDvName, predicate = serumBloodUreaNitrogen1Predicate, text = "Serum Blood Urea Nitrogen", target = labsLinks }
            GetDiscreteValueLinks { dvNames = serumChlorideDvName, predicate = serumChloride1Predicate, text = "Serum Chloride", target = labsLinks }
            GetDiscreteValueLinks { dvNames = serumCreatinineDvName, predicate = serumCreatinine1Predicate, text = "Serum Creatinine", target = labsLinks }
            GetDiscreteValueLinks { dvNames = serumKetoneDvName, predicate = serumKetone1Predicate, text = "Serum Ketones", target = labsLinks }
            GetDiscreteValueLinks {
                dvNames = urineKetonesDvName,
                predicate = function(dv)
                    return dv.result ~= nil and dv.result:lower():find("positive") ~= nil
                end,
                text = "Urine Ketones",
                target = labsLinks
            }

            -- Lactate, ph, and blood links
            GetDiscreteValueLinks { dvNames = serumLactateDvName, predicate = serumLactate2Predicate, text = "Serum Lactate", target = lactateLinks }
            for _, entry in ipairs(highSerumLactateLevelDvLinks or {}) do
                table.insert(lactateLinks, entry)
            end
            for _, entry in ipairs(lowArterialBloodPHMultiDiscreteValueLinks) do
                table.insert(phLinks, entry)
            end
            for _, entry in ipairs(phDvLinks or {}) do
                table.insert(phLinks, entry)
            end      
            GetDiscreteValueLinks { dvNames = bloodCO2DvName, predicate = bloodCO22Predicate, text = "Blood CO2", target = bloodCO2Links }
            for _, entry in ipairs(bloodCO2DvLinks or {}) do
                table.insert(bloodCO2Links, entry)
            end

            -- Vitals
            GetDiscreteValueLinks { dvNames = glasgowComaScaleDvName, predicate = glasgowComaScale1Predicate, text = "Glasgow Coma Scale", target = vitalSignsIntakeLinks }
            GetDiscreteValueLinks { dvNames = heartRateDvName, predicate = heartRate1Predicate, text = "Heart Rate", target = vitalSignsIntakeLinks }
            GetDiscreteValueLinks { dvNames = mAPDvName, predicate = mAP1Predicate, text = "Mean Arterial Pressure", target = vitalSignsIntakeLinks }
            GetDiscreteValueLinks { dvNames = respiratoryRateDvName, predicate = respiratoryRate1Predicate, text = "Respiratory Rate", target = vitalSignsIntakeLinks }
            GetDiscreteValueLinks { dvNames = respiratoryRateDvName, predicate = respiratoryRate2Predicate, text = "Respiratory Rate", target = vitalSignsIntakeLinks }
            GetDiscreteValueLinks { dvNames = sPO2DvName, predicate = sPO21Predicate, text = "SpO2", target = vitalSignsIntakeLinks }
            GetDiscreteValueLinks { dvNames = sBPDvName, predicate = sBP1Predicate, text = "Systolic Blood Pressure", target = vitalSignsIntakeLinks }

            -- ABG
            GetDiscreteValueLinks { dvNames = baseExcessDvName, predicate = baseExcess1Predicate, text = "Base Excess", target = abgLinks }
            GetDiscreteValueLinks { dvNames = fIO2DvName, predicate = fIO21Predicate, text = "FiO2", target = abgLinks }
            GetDiscreteValueLinks { dvNames = pO2DvName, predicate = pO21Predicate, text = "pO2", target = abgLinks }
            if paco2DvLinks and #paco2DvLinks > 0 then
                for _, entry in ipairs(paco2DvLinks or {}) do
                    table.insert(paCO2Links, entry)
                end
            else
                GetDiscreteValueLinks { dvNames = pCO2DvName, predicate = pCO22Predicate, text = "paC02", target = paCO2Links }
            end
            if highSerumBicarbonateDvLinks and #highSerumBicarbonateDvLinks > 0 then
                for _, entry in ipairs(highSerumBicarbonateDvLinks or {}) do
                    table.insert(abgHCO3Links, entry)
                end
            else
                GetDiscreteValueLinks { dvNames = serumBicarbonateDvName, predicate = serumBicarbonate3Predicate, text = "HC03", target = abgHCO3Links }
            end

            -- ABG
            GetDiscreteValueLinks { dvNames = paO2DvName, predicate = pAO21Predicate, text = "Pa02", target = paO2Links, maxPerValue = 10 }

            -- VBG
            GetDiscreteValueLinks { dvNames = hCO3DvName, predicate = hCO31Predicate, text = "HC03", target = vbhCO3Links, maxPerValue = 10 }
            GetDiscreteValueLinks { dvNames = hCO3DvName, predicate = hCO32Predicate, text = "HC03", target = vbhCO3Links, maxPerValue = 10 }
            for _, entry in ipairs(venousCO2DvLinks or {}) do
                table.insert(venousCO2Links, entry)
            end
        end

        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        if #paCO2Links > 0 then
            paCO2Header.links = paCO2Links
            table.insert(abgLinks, paCO2Header)
        end
        if #pCO2Links > 0 then
            pCO2Header.links = pCO2Links
            table.insert(abgLinks, pCO2Header)
        end
        if #paO2Links > 0 then
            paO2Header.links = paO2Links
            table.insert(abgLinks, paO2Header)
        end
        if #abgHCO3Header > 0 then
            abgHCO3Header.links = abgHCO3Links
            table.insert(abgLinks, abgHCO3Header)
        end
        if #abgLinks > 0 then
            abgHeader.links = abgLinks
            table.insert(labsLinks, abgHeader)
        end

        if #vbhCO3Links > 0 then
            vbhCO3Header.links = vbhCO3Links
            table.insert(vbgLinks, vbhCO3Header)
        end
        if #venousCO2Links > 0 then
            venousCO2Header.links = venousCO2Links
            table.insert(vbgLinks, venousCO2Header)
        end
        if #vbgLinks > 0 then
            vbgHeader.links = vbgLinks
            table.insert(labsLinks, vbgHeader)
        end

        if #bloodCO2Links > 0 then
            bloodCO2Header.links = bloodCO2Links
            table.insert(labsLinks, bloodCO2Header)
        end
        if #phLinks > 0 then
            phHeader.links = phLinks
            table.insert(labsLinks, phHeader)
        end
        if #lactateLinks > 0 then
            lactateHeader.links = lactateLinks
            table.insert(labsLinks, lactateHeader)
        end

        if #documentedDxLinks > 0 then
            documentedDxHeader.links = documentedDxLinks
            table.insert(resultLinks, documentedDxHeader)
        end
        if #clinicalEvidenceLinks > 0 then
            clinicalEvidenceHeader.links = clinicalEvidenceLinks
            table.insert(resultLinks, clinicalEvidenceHeader)
        end
        if #labsLinks > 0 then
            labsHeader.links = labsLinks
            table.insert(resultLinks, labsHeader)
        end
        if #vitalSignsIntakeLinks > 0 then
            vitalSignsIntakeHeader.links = vitalSignsIntakeLinks
            table.insert(resultLinks, vitalSignsIntakeHeader)
        end
        
        treatmentAndMonitoringHeader.links = treatmentAndMonitoringLinks
        table.insert(resultLinks, treatmentAndMonitoringHeader)

        if existingAlert then
            resultLinks = MergeLinks(existingAlert.links, resultLinks)
        end
        Result.links = resultLinks
    end
end
