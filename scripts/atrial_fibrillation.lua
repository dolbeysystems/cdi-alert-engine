---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Atrial Fibrillation
---
--- This script checks an account to see if it matches the criteria for an atrial fibrillation alert.
---
--- Date: 4/11/2024
--- Version: 1.0
--- Site: (Default)
---------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Requires 
--------------------------------------------------------------------------------
require("libs.common")



--------------------------------------------------------------------------------
--- Setup
--------------------------------------------------------------------------------
local heartRateDiscreteValueNames = {
    "Peripheral Pulse Rate",
    "Heart Rate Monitored (bpn)",
    "Peripheral Pulse Rate (bpn)",
}
local mapDiscreteValueNames = {
    "MAP"
}
local sbpDiscreteValueNames = {
    "Systolic Blood Pressure",
    "Systolic Blood Pressure (mmHg)",
}
local atrialFibrillationCodeDictionary = {
    ["I48.0"] = "Paroxysmal Atrial Fibrillation",
    ["I48.11"] = "Longstanding Persistent Atrial Fibrillation",
    ["I48.19"] = "Other Persistent Atrial Fibrillation",
    ["I48.21"] = "Permanent Atrial Fibrillation",
    ["I48.20"] = "Chronic Atrial Fibrillation",
}
local accountAtrialFibrillationCodes = GetAccountCodesInDictionary(account, atrialFibrillationCodeDictionary)

local existingAlert = GetExistingCdiAlert{ scriptName = "atrial_fibrillation.lua" }
local alertMatched = false
local alertAutoResolved = false

local documentationIncludesHeading = MakeHeaderLink("Documentation Includes")
local clinicalEvidenceHeading = MakeHeaderLink("Clinical Evidence")
local treatmentHeading = MakeHeaderLink("Treatment")
local vitalsHeading = MakeHeaderLink("Vital Signs/Intake and Output Data")
local ekgHeading = MakeHeaderLink("EKG")


--------------------------------------------------------------------------------
--- Alert Qualification 
--------------------------------------------------------------------------------
if not existingAlert or not existingAlert.validated then
    -- Alert triggered
    local unspecAtrialFibrillationCodeLink = GetCodeLinks { code="I48.91", text="Unspecified Atrial Fibrillation Dx Present: " }
    local atrialFibrillationAbstractionLink = GetAbstractionLinks { code="ATRIAL_FIBRILLATION", text="Atrial Fibrillation" }

    if #accountAtrialFibrillationCodes >= 1 then
        if existingAlert then
            result.validated = true
            result.outcome = "AUTORESOLVED"
            result.reason = "Autoresolved due to one specified code on the account"

            --- @type CdiAlertLink[]
            local docLinks = {}

            for codeIndex = 1, #accountAtrialFibrillationCodes do
                local code = accountAtrialFibrillationCodes[codeIndex]
                local description = atrialFibrillationCodeDictionary[code]
                local tempCode = GetCodeLinks { code=code, text="Autoresolved Specified Code - " .. description }

                if tempCode then
                    table.insert(docLinks, tempCode)
                end
            end
            documentationIncludesHeading.links = docLinks
            alertAutoResolved = true
        else
            alertMatched = false
        end
    elseif unspecAtrialFibrillationCodeLink then
        documentationIncludesHeading.links = { unspecAtrialFibrillationCodeLink }
        result.subtitle = "Unspecified Atrial Fibrillation Dx"
        alertMatched = true
    elseif atrialFibrillationAbstractionLink then
        documentationIncludesHeading.links = { atrialFibrillationAbstractionLink }
        result.subtitle = "Atrial Fibrillation only present on EKG"
        alertMatched = true
    else
        result.passed = false
    end
end



--------------------------------------------------------------------------------
--- Additional Link Creation
--------------------------------------------------------------------------------
if alertMatched then
    local evidenceLinks = MakeLinkArray()
    local treatmentLinks = MakeLinkArray()
    local vitalsLinks = MakeLinkArray()
    local ekgLinks = MakeLinkArray()

    -- Convenience functions for adding links
    --- @param code string
    --- @param text string
    --- @param seq number
    local function AddEvidenceAbs(code, text, seq)
        GetAbstractionLinks { target=evidenceLinks, code=code, text=text, seq=seq }
    end

    --- @param code string
    --- @param text string
    --- @param seq number
    local function AddEvidenceCode(code, text, seq)
        GetCodeLinks { target=evidenceLinks, code=code, text=text, seq=seq }
    end

    --- @param cat string
    --- @param text string
    --- @param seq number
    local function AddTreatmentMed(cat, text, seq)
        GetMedicationLinks { target=treatmentLinks, cat=cat, text=text, seq=seq }
    end

    --- @param code string
    --- @param text string
    --- @param seq number
    local function AddTreatmentAbs(code, text, seq)
        GetAbstractionValueLinks { target=treatmentLinks, code=code, text=text, seq=seq }
    end

    --- @param code string
    --- @param text string
    --- @param seq number
    local function AddTreatmentCode(code, text, seq)
        GetCodeLinks { target=treatmentLinks, code=code, text=text, seq=seq }
    end

    --- @param dv string[]
    --- @param text string
    --- @param seq number
    local function AddVitalsDv(dv, text, seq)
        GetDiscreteValueLinks { target=vitalsLinks, discreteValueNames=dv, text=text, seq=seq }
    end

    --- @param code string
    --- @param text string
    --- @param seq number
    local function AddVitalsAbs(code, text, seq)
        GetAbstractionValueLinks { target=vitalsLinks, code=code, text=text, seq=seq }
    end

    --- @param docType string
    --- @param text string
    local function AddEKGDoc(docType, text)
        GetDocumentLinks { target=ekgLinks, documentType=docType, text=text }
    end

    -- Clinical Evidence Links
    AddEvidenceAbs("ABLATION", "Ablation", 1)
    AddEvidenceCode("I35.1", "Aortic Regurgitation", 2)
    AddEvidenceCode("I35.0", "Aortic Stenosis", 3)
    AddEvidenceAbs("CARDIOVERSION", "Cardioversion", 4)
    AddEvidenceAbs("DIAPHORETIC", "Diaphoretic", 5)
    AddEvidenceAbs("DYSPNEA_ON_EXERTION", "Dyspnea On Exertion", 6)
    AddEvidenceCode("R53.83", "Fatigue", 7)
    AddEvidenceAbs("HEART_PALPITATIONS", "Heart Palpitations", 8)
    AddEvidenceAbs("IMPLANTABLE_CARDIAC_ASSIST_DEVICE", "Implantable Cardiac Assist Device", 9)
    AddEvidenceAbs("IRREGULAR_ECHO_FINDING", "Irregular Echo Findings", 10)
    AddEvidenceCode("R42", "Light Headed", 11)
    AddEvidenceAbs("MAZE_PROCEDURE", "Maze Procedure", 12)
    AddEvidenceCode("I34.0", "Mitral Regurgitation", 13)
    AddEvidenceCode("I34.2", "Mitral Stenosis", 14)
    AddEvidenceCode("I35.1", "Pulmonic Regurgitation", 15)
    AddEvidenceCode("I37.0", "Pulmonic Stenosis", 16)
    AddEvidenceAbs("SHORTNESS_OF_BREATH", "Shortness of breath", 17)
    AddEvidenceCode("R55", "Syncopal", 18)
    AddEvidenceCode("I36.1", "Tricuspid Regurgitation", 19)
    AddEvidenceCode("I36.0", "Tricuspid Stenosis", 20)
    AddEvidenceAbs("WATCHMAN_PROCEDURE", "Watchman Procedure", 21)

    -- EKG Links (Document Links)
    AddEKGDoc("EKG", "EKG")
    AddEKGDoc("Telemetry Strips", "Telemetry Strips")

    -- Treatment Links (Medication Links)
    AddTreatmentMed("Adenosine", "Adenosine", 1)
    AddTreatmentAbs("ADENOSINE", "Adenosine", 2)
    AddTreatmentMed("Antiarrhythmic", "Antiarrhythmic", 3)
    AddTreatmentAbs("ANTIARRHYTHMIC", "Antiarrhythmic", 4)
    AddTreatmentMed("Anticoagulant", "Anticoagulant", 5)
    AddTreatmentAbs("ANTICOAGULANT", "Anticoagulant", 6)
    AddTreatmentMed("Antiplatelet", "Antiplatelet", 7)
    AddTreatmentAbs("ANTIPLATELET", "Antiplatelet", 8)
    AddTreatmentMed("Beta Blocker", "Beta Blocker", 9)
    AddTreatmentAbs("BETA_BLOCKER", "Beta Blocker", 10)
    AddTreatmentMed("Calcium Channel Blocker", "Calcium Channel Blocker", 11)
    AddTreatmentAbs("CALCIUM_CHANNEL_BLOCKER", "Calcium Channel Blocker", 12)
    AddTreatmentMed("Digitalis", "Digoxin", 13)
    AddTreatmentAbs("DIGOXIN", "Digoxin", 14)
    AddTreatmentCode("Z79.01", "Long Term Use of Anticoagulant", 15)
    AddTreatmentCode("Z79.02", "Long Term use of Antithrombotics/Antiplatelet", 16)

    -- Vital Links (Discete Value Links)
    AddVitalsDv(heartRateDiscreteValueNames, "Heart Rate", 1)
    AddVitalsAbs("HIGH_HEART_RATE", "Heart Rate", 1)
    AddVitalsDv(mapDiscreteValueNames, "Mean Arterial Pressure", 2)
    AddVitalsAbs("LOW_MEAN_ARTERIAL_BLOOD_PRESSURE", "Blood Pressure", 2)
    AddVitalsDv(sbpDiscreteValueNames, "Systolic Blood Pressure", 3)
    AddVitalsAbs("LOW_SYSTOLIC_BLOOD_PRESSURE", "Systolic Blood Pressure", 3)

    -- Attach temp link lists to headings
    clinicalEvidenceHeading.links = evidenceLinks
    ekgHeading.links = ekgLinks
    treatmentHeading.links = treatmentLinks
    vitalsHeading.links = vitalsLinks
end



--------------------------------------------------------------------------------
--- Result Finalization 
--------------------------------------------------------------------------------
if alertMatched or alertAutoResolved then
    local resultLinks = MakeLinkArray()

    if #documentationIncludesHeading.links > 0 then
        table.insert(resultLinks, documentationIncludesHeading)
    end
    if #clinicalEvidenceHeading.links > 0 then
        table.insert(resultLinks, clinicalEvidenceHeading)
    end
    if #vitalsHeading.links > 0 then
        table.insert(resultLinks, vitalsHeading)
    end
    table.insert(resultLinks, treatmentHeading)
    if #ekgHeading.links > 0 then
        table.insert(resultLinks, ekgHeading)
    end

    debug(
        "Alert Passed Adding Links. Alert Triggered: " .. result.subtitle .. " " ..
        "Autoresolved: " .. result.outcome .. "; " .. tostring(result.validated) .. "; " ..
        "Links: Documentation Includes- " .. tostring(#documentationIncludesHeading.links > 0) .. ", " ..
        "Abs- " .. tostring(#clinicalEvidenceHeading.links > 0) .. ", " ..
        "vitals- " .. tostring(#vitalsHeading.links > 0) .. ", " ..
        "treatment- " .. tostring(#treatmentHeading.links > 0) .. "; " ..
        "Acct: " .. account.id
    )
    resultLinks = MergeLinksWithExisting(existingAlert, resultLinks)
    result.links = resultLinks
    result.passed = true
end

