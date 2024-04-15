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
require("libs.standard_cdi")



--------------------------------------------------------------------------------
--- Setup
--------------------------------------------------------------------------------
local alertCodeDictionary = {
    ["I48.0"] = "Paroxysmal Atrial Fibrillation",
    ["I48.11"] = "Longstanding Persistent Atrial Fibrillation",
    ["I48.19"] = "Other Persistent Atrial Fibrillation",
    ["I48.21"] = "Permanent Atrial Fibrillation",
    ["I48.20"] = "Chronic Atrial Fibrillation",
}
local accountAlertCodes = GetAccountCodesInDictionary(Account, alertCodeDictionary)

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

local ekgHeading = MakeHeaderLink("EKG")
local ekgLinks = MakeLinkArray()
--- @param docType string
--- @param text string
local function AddEKGDoc(docType, text)
    GetDocumentLinks { target=ekgLinks, documentType=docType, text=text }
end



--------------------------------------------------------------------------------
--- Alert Qualification 
--------------------------------------------------------------------------------
if not ExistingAlert or not ExistingAlert.validated then
    -- Alert triggered
    local unspecAtrialFibrillationCodeLink = GetCodeLinks { code="I48.91", text="Unspecified Atrial Fibrillation Dx Present: " }
    local atrialFibrillationAbstractionLink = GetAbstractionLinks { code="ATRIAL_FIBRILLATION", text="Atrial Fibrillation" }

    if #accountAlertCodes >= 1 then
        if ExistingAlert then
            Result.validated = true
            Result.outcome = "AUTORESOLVED"
            Result.reason = "Autoresolved due to one specified code on the account"

            --- @type CdiAlertLink[]
            local docLinks = {}

            for codeIndex = 1, #accountAlertCodes do
                local code = accountAlertCodes[codeIndex]
                local description = alertCodeDictionary[code]
                local tempCode = GetCodeLinks { code=code, text="Autoresolved Specified Code - " .. description }

                if tempCode then
                    table.insert(docLinks, tempCode)
                end
            end
            DocumentationIncludesHeader.links = docLinks
            AlertAutoResolved = true
        else
            AlertMatched = false
        end
    elseif unspecAtrialFibrillationCodeLink then
        DocumentationIncludesHeader.links = { unspecAtrialFibrillationCodeLink }
        Result.subtitle = "Unspecified Atrial Fibrillation Dx"
        AlertMatched = true
    elseif atrialFibrillationAbstractionLink then
        DocumentationIncludesHeader.links = { atrialFibrillationAbstractionLink }
        Result.subtitle = "Atrial Fibrillation only present on EKG"
        AlertMatched = true
    else
        Result.passed = false
    end
end



--------------------------------------------------------------------------------
--- Additional Link Creation
--------------------------------------------------------------------------------
if AlertMatched then
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
end



--------------------------------------------------------------------------------
--- Result Finalization 
--------------------------------------------------------------------------------
if AlertMatched or AlertAutoResolved then
    -- Attach temp link lists to headings
    ekgHeading.links = ekgLinks
    local resultLinks = GetFinalTopLinks({ ekgHeading })

    resultLinks = MergeLinksWithExisting(ExistingAlert, resultLinks)
    Result.links = resultLinks
    Result.passed = true
end

