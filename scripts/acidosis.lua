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
---     - Acute Respiratory Acidosis Documented Possibly Lacking Supporting Evidence
---     - Possible Lactic Acidosis
---     - Possible Acidosis
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
    local hCO31Predicate = 22
    local hCO32Predicate = 26
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
    local pAO21Predicate = 60
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

    -- Meds
    local albuminMedicationLinks = GetMedicationLinks {
        cat = "Albumin",
        text = "Albumin",
        useCdiAlertCategoryField = true,
        maxPerValue = 9999,
        predicate = acidosisMedPredicate
    }
    local fluidBolusMedicationLinks = GetMedicationLinks {
        cat = "Fluid Bolus",
        text = "Fluid Bolus",
        useCdiAlertCategoryField = true,
        maxPerValue = 9999,
        predicate = acidosisMedPredicate
    }
    local fluidBolusAbstractionLinks = GetAbstractionValueLinks {
        code = "FLUID_BOLUS",
        text = "Fluid Bolus"
    }
    local fluidResuscitationAbstractionLinks = GetAbstractionValueLinks {
        code = "FLUID_RESCUSITATION",
        text = "Fluid Resuscitation"
    }
    local sodiumBicarbonateMedLink = GetMedicationLinks {
        cat = "Sodium Bicarbonate",
        text = "Sodium Bicarbonate",
        useCdiAlertCategoryField = true,
        maxPerValue = 9999,
        predicate = acidosisMedPredicate
    }
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

    -- Auto resolve alert if it currently triggered for acute respiratory acidosis

    end



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

