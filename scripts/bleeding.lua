---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Bleeding
---
--- This script checks an account to see if it matches the criteria for a bleeding alert.
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
local bloodLossDvNames = {""}
local highBloodLossPredicate = function(dv) return GetDvValueNumber(dv) > 300 end
local hematocritDvNames = {"HEMATOCRIT (%)", "HEMATOCRIT"}
local hemoglobinDvNames = {"HEMOGLOBIN", "HEMOGLOBIN (g/dL)"}
local inrDvNames = {"INR"}
local highInrPedicate = function(dv) return GetDvValueNumber(dv) > 1.2 end
local ptDvNames = {"PROTIME (SEC)"}
local highPtPredicate = function(dv) return GetDvValueNumber(dv) > 13 end
local pttDvNames = {"PTT (SEC)"}
local highPttPredicate = function(dv) return GetDvValueNumber(dv) > 30.5 end


local existingAlert = GetExistingCdiAlert { scriptName = ScriptName }
local subtitle = existingAlert and existingAlert.subtitle or nil



if not existingAlert or not existingAlert.validated then
    --------------------------------------------------------------------------------
    --- Alert Variables 
    --------------------------------------------------------------------------------
    local alertCodeDictionary = {
        ["I48.0"] = "Paroxysmal Atrial Fibrillation",
        ["I48.11"] = "Longstanding Persistent Atrial Fibrillation",
        ["I48.19"] = "Other Persistent Atrial Fibrillation",
        ["I48.21"] = "Permanent Atrial Fibrillation",
        ["I48.20"] = "Chronic Atrial Fibrillation"
    }
    local accountAlertCodes = GetAccountCodesInDictionary(Account, alertCodeDictionary)



    --------------------------------------------------------------------------------
    --- Top-Level Link Header Variables
    --------------------------------------------------------------------------------
    local resultLinks = {}

    local documentedDxHeader = MakeHeaderLink("Documented Dx")
    local documentedDxLinks = {}
    local laboratoryStudiesHeader = MakeHeaderLink("Laboratory Studies")
    local laboratoryStudiesLinks = {}
    local signsOfBleedingHeader = MakeHeaderLink("Signs of Bleeding")
    local signsOfBleedingLinks = {}
    local medicationsTransfusionsHeader = MakeHeaderLink("Medication(s)/Transfusion(s)")
    local medicationsTransfusionsLinks = {}
    local treatmentAndMonitoringHeader = MakeHeaderLink("Treatment and Monitoring")
    local treatmentAndMonitoringLinks = {}
    local hemoglobinHeader = MakeHeaderLink("Hemoglobin")
    local hemoglobinLinks = {}
    local hematocritHeader = MakeHeaderLink("Hematocrit")
    local hematocritLinks = {}
    local inrHeader = MakeHeaderLink("INR")
    local inrLinks = {}
    local ptHeader = MakeHeaderLink("PT")
    local ptLinks = {}
    local pttHeader = MakeHeaderLink("PTT")
    local pttLinks = {}




    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Signs of Bleeding
    local d62CodeLink = GetCodeLink { code = "D62", text = "Acute Blood Loss Anemia", seq = 1 }
    local bleedingAbsLink = GetAbstractionLink { code = "BLEEDING", text = "Bleeding", seq = 2 }
    local bloodLossDvLink = GetDiscreteValueLink { dvNames = bloodLossDvNames, text = "Blood Loss", seq = 3, predicate = highBloodLossPredicate }
    local n99510CodeLink = GetCodeLink { code = "N99.510", text = "Cystostomy Hemorrhage", seq = 4 }
    local r040CodeLink = GetCodeLink { code = "R04.0", text = "Epistaxis", seq = 5 }
    local estBloodLossAbsLink = GetAbstractionLink { code = "ESTIMATED_BLOOD_LOSS", text = "Estimated Blood Loss", seq = 6 }
    local giBleedCodesLink = GetCodeLink {
        codes = {
            "K25.0", "K25.2", "K25.4", "K25.6", "K26.0", "K26.2", "K26.4", "K26.6", "K27.0", "K27.2", "K27.4", "K27.6", "K28.0",
            "K28.2", "K28.4", "28.6", "K29.01", "K29.21", "K29.31", "K29.41", "K29.51", "K29.61", "K29.71", "K29.81", "K29.91", "K31.811", "K31.82",
            "K55.21", "K57.01", "K57.11", "K57.13", "K57.21", "K57.31", "K57.33", "K57.41", "K57.51", "K57.53", "K57.81", "K57.91", "K57.93", "K62.5"
        },
        text = "GI Bleed",
        seq = 7
    }
    local k922_code_link = GetCodeLink { code = "K92.2", text = "GI Hemorrhage", seq = 8 }
    local k920CodeLink = GetCodeLink { code = "K92.0", text = "Hematemesis", seq = 9 }
    local hematocheziaAbsLink = GetAbstractionLink { code = "HEMATCHEZIA", text = "Hematochezia", seq = 10 }
    local hematomaAbsLink = GetAbstractionLink { code = "HEMATOMA", text = "Hematoma", seq = 11 }
    local r310CodeLink = GetCodePrefixLink { prefix = "R31%.", text = "Hematuria", seq = 12 }
    local k661CodeLink = GetCodeLink { code = "K66.1", text = "Hemoperitoneum", seq = 13 }
    local hemoptysisCodeLink = GetCodeLink { code = "R04.2", text = "Hemoptysis", seq = 14 }
    local hemorrhageAbsLink = GetAbstractionLink { code = "HEMORRHAGE", text = "Hemorrhage", seq = 15 }
    local r049CodeLink = GetCodeLink { code = "R04.9", text = "Hemorrhage from Respiratory Passages", seq = 16 }
    local r041CodeLink = GetCodeLink { code = "R04.1", text = "Hemorrhage from Throat", seq = 17 }
    local j9501CodeLink = GetCodeLink { code = "J95.01", text = "Hemorrhage from Tracheostomy Stoma", seq = 18 }
    local k921CodeLink = GetCodeLink { code = "K92.1", text = "Melena", seq = 19 }
    local i62CodesLink = GetCodePrefixLink { prefix = "I61%.", text = "Non-Traumatic Subarachnoid Hemorrhage", seq = 20 }
    local i60CodesLink = GetCodePrefixLink { prefix = "I60%.", text = "Non-Traumatic Subarachnoid Hemorrhage", seq = 21 }
    local h922CodesLink = GetCodePrefixLink { prefix = "H92.2", text = "Otorrhagia", seq = 22 }
    local r0489CodeLink = GetCodeLink { code = "R04.89", text = "Pulmonary Hemorrhage", seq = 23 }

    -- Medications
    local anticoagulantMedLink = GetMedicationLink { cat = "Anticoagulant", seq = 1 }
    local anticoagulantAbsLink = GetAbstractionLink { code = "ANTICOAGULANT", text = "Anticoagulant", seq = 2 }
    local antiplateletMedLink = GetMedicationLink { cat = "Antiplatelet", seq = 3 }
    local antiplatelet2MedLink = GetMedicationLink { cat = "Antiplatelet2", seq = 4 }
    local antiplateletAbsLink = GetAbstractionLink { code = "ANTIPLATELET", text = "Antiplatelet", seq = 5 }
    local antiplatelet2AbsLink = GetAbstractionLink { code = "ANTIPLATELET_2", text = "Antiplatelet", seq = 6 }
    local aspirinMedLink = GetMedicationLink { cat = "Aspirin", seq = 7 }
    local aspirinAbsLink = GetAbstractionLink { code = "ASPIRIN", text = "Aspirin", seq = 8 }
    local heparinMedLink = GetMedicationLink { cat = "Heparin", seq = 15 }
    local heparinAbsLink = GetAbstractionLink { code = "HEPARIN", text = "Heparin", seq = 16 }
    local z7901CodeLink = GetCodeLink { code = "Z79.01", text = "Long Term use of Anticoagulants", seq = 17 }
    local z7982CodeLink = GetCodeLink { code = "Z79.82", text = "Long-Term use of Asprin", seq = 18 }
    local z7902CodeLink = GetCodeLink { code = "Z79.02", text = "Long-term use of Antithrombotics/Antiplatelets", seq = 19 }

    local signsOfBleeding =
        d62CodeLink or 
        bleedingAbsLink or
        r041CodeLink or
        r0489CodeLink or
        r049CodeLink or
        h922CodesLink or
        i62CodesLink or
        i60CodesLink or
        n99510CodeLink or
        r040CodeLink or
        k922_code_link or
        giBleedCodesLink or
        hemorrhageAbsLink or
        j9501CodeLink or
        hematocheziaAbsLink or
        k920CodeLink or
        hematomaAbsLink or
        r310CodeLink or
        k661CodeLink or
        hemoptysisCodeLink or
        k921CodeLink or
        estBloodLossAbsLink or
        bloodLossDvLink



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    -- Autoresolve
    if #accountAlertCodes > 0 and existingAlert then
        for _, code in ipairs(accountAlertCodes) do
            local description = alertCodeDictionary[code]
            local tempCode = GetCodeLinks { code=code, text="Autoresolved Specified Code - " .. description }

            if tempCode then
                table.insert(documentedDxLinks, tempCode)
            end
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    -- Alert Bleeding with possible link to Anticoagulant
    elseif
        signsOfBleeding and
        #accountAlertCodes == 0 and (
            anticoagulantMedLink or
            anticoagulantAbsLink or
            antiplateletMedLink or
            antiplatelet2MedLink or
            antiplateletAbsLink or
            antiplatelet2AbsLink or
            aspirinMedLink or
            aspirinAbsLink or
            heparinMedLink or
            heparinAbsLink or
            z7901CodeLink or
            z7982CodeLink or
            z7902CodeLink
        )
    then
        Result.subtitle = "Bleeding with possible link to Anticoagulant"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Labs
            local gender = Account.patient and Account.patient.gender or ""
            local lowHemoglobinMultiDVLinkPairs = GetLowHemoglobinDiscreteValuePairs(gender)
            local lowHematocritMultiDVLinkPairs = GetLowHematocritDiscreteValuePairs(gender)

            for _, pair in ipairs(lowHemoglobinMultiDVLinkPairs) do
                table.insert(hemoglobinLinks, pair.hemoglobinLink)
                table.insert(hematocritLinks, pair.hematocritLink)
            end

            for _, pair in ipairs(lowHematocritMultiDVLinkPairs) do
                table.insert(hemoglobinLinks, pair.hemoglobinLink)
                table.insert(hematocritLinks, pair.hematocritLink)
            end
            GetDiscreteValueLinks { discreteValueNames = inrDvNames, predicate = highInrPedicate, text = "INR", target = inrLinks, maxPerValue = 10 }
            GetDiscreteValueLinks { discreteValueNames = ptDvNames, predicate = highPtPredicate, text = "PT", target = ptLinks, maxPerValue = 10 }
            GetDiscreteValueLinks { discreteValueNames = pttDvNames, predicate = highPttPredicate, text = "PTT", target = pttLinks, maxPerValue = 10 }

            -- Meds
            table.insert(treatmentAndMonitoringLinks, anticoagulantMedLink)
            table.insert(treatmentAndMonitoringLinks, anticoagulantAbsLink)
            table.insert(treatmentAndMonitoringLinks, antiplateletMedLink)
            table.insert(treatmentAndMonitoringLinks, antiplatelet2MedLink)
            table.insert(treatmentAndMonitoringLinks, antiplateletAbsLink)
            table.insert(treatmentAndMonitoringLinks, antiplatelet2AbsLink)
            table.insert(treatmentAndMonitoringLinks, aspirinMedLink)
            table.insert(treatmentAndMonitoringLinks, aspirinAbsLink)

            --[[
            abstractValue("CLOT_SUPPORTING_THERAPY", "Clot Supporting Therapy [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, meds, True)
            medValue("Clot Supporting Therapy Reversal Agent", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 10, meds, True)
            codeValue("30233M1", "Cryoprecipitate: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, meds, True)
            abstractValue("DESMOPRESSIN_ACETATE", "Desmopressin Acetate [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12, meds, True)
            codeValue("30233T1", "Fibrinogen Transfusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13, meds, True)
            multiCodeValue(["30233L1", "30243L1"], "Fresh Frozen Plasma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, meds, True)
            --]]
            table.insert(treatmentAndMonitoringLinks, GetAbstractionValueLink { code = "CLOT_SUPPORTING_THERAPY", text = "Clot Supporting Therapy", seq = 9 })
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

