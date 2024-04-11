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
--- Atrial fibrillation codes with descriptions
local atrialFibrillationCodeDictionary = {
    ["I48.0"] = "Paroxysmal Atrial Fibrillation",
    ["I48.11"] = "Longstanding Persistent Atrial Fibrillation",
    ["I48.19"] = "Other Persistent Atrial Fibrillation",
    ["I48.21"] = "Permanent Atrial Fibrillation",
    ["I48.20"] = "Chronic Atrial Fibrillation",
}
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

--- List of codes in dependecy map that are present on the account (codes only)
local accountAtrialFibrillationCodes = GetAccountCodesInDictionary(account, atrialFibrillationCodeDictionary)

--- Existing substance abuse alert (or nil if this alert doesn't exist currently on the account)
local existingAlert = GetExistingCdiAlert{ scriptName = "atrial_fibrillation.lua" }

--- Boolean indicating that this alert matched conditions and we should proceed with creating links
--- and marking the result as passed
local alertMatched = false

--- Boolean indicating that this alert was autoresolved and we should skip additional link creation,
--- but still mark the result as passed
local alertAutoResolved = false

--- Top-level link for holding documentation links
---
--- @type CdiAlertLink
local documentationIncludesHeading = CdiAlertLink:new()
documentationIncludesHeading.link_text = "Documentation Includes"

--- Top-level links for holding clinical evidence
---
--- @type CdiAlertLink
local clinicalEvidenceHeading = CdiAlertLink:new()
clinicalEvidenceHeading.link_text = "Clinical Evidence"

--- Top-level link for holding treatment links
---
--- @type CdiAlertLink
local treatmentHeading = CdiAlertLink:new()
treatmentHeading.link_text = "Treatment"

--- Top-level link for holding vitals links
---
--- @type CdiAlertLink
local vitalsHeading = CdiAlertLink:new()
vitalsHeading.link_text = "Vital Signs/Intake and Output Data"

--- Top-level link for holding ekg links
---
--- @type CdiAlertLink
local ekgHeading = CdiAlertLink:new()
ekgHeading.link_text = "EKG"



--------------------------------------------------------------------------------
--- Alert Qualification 
--------------------------------------------------------------------------------
if not existingAlert or not existingAlert.validated then
    -- Alert triggered
    local unspecAtrialFibrillationCodeLink = MakeCodeLink(nil, "I48.91", "Unspecified Atrial Fibrillation Dx Present: ", 0)
    local atrialFibrillationAbstractionLink = MakeAbstractionLink(nil, "ATRIAL_FIBRILLATION", "Atrial Fibrillation", 0)

    if #accountAtrialFibrillationCodes >= 1 then
        if existingAlert then
            result.validated = true
            result.outcome = "AUTORESOLVED"
            result.reason = "Autoresolved due to one specified code on the account"

            --- @type CdiAlertLink[]
            local documentationLinks = {}

            for codeIndex = 1, #accountAtrialFibrillationCodes do
                local code = accountAtrialFibrillationCodes[codeIndex]
                local description = atrialFibrillationCodeDictionary[code]
                local tempCode = MakeCodeLink(nil, code, "Autoresolved Specified Code - " .. description, 0)

                if tempCode then
                    table.insert(documentationLinks, tempCode)
                end
            end
            documentationIncludesHeading.links = documentationLinks
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
    --- Clinical Evidence Links temp table
    ---
    --- @type CdiAlertLink[]
    local clinicalEvidenceLinks = {}

    --- Treatment Links temp table
    ---
    --- @type CdiAlertLink[]
    local treatmentLinks = {}

    --- Vitals Links temp table
    ---
    --- @type CdiAlertLink[]
    local vitalsLinks = {}

    --- EKG Links temp table
    ---
    --- @type CdiAlertLink[]
    local ekgLinks = {}

    -- Clinical Evidence Links
    MakeAbstractionLink(clinicalEvidenceLinks, "ABLATION", "Ablation", 1)
    MakeCodeLink(clinicalEvidenceLinks, "I35.1", "Aortic Regurgitation ", 2)
    MakeCodeLink(clinicalEvidenceLinks, "I35.0", "Aortic Stenosis", 3)
    MakeAbstractionLink(clinicalEvidenceLinks, "CARDIOVERSION", "Cardioversion", 4)
    MakeAbstractionLink(clinicalEvidenceLinks, "DIAPHORETIC", "Diaphoretic", 5)
    MakeAbstractionLink(clinicalEvidenceLinks, "DYSPNEA_ON_EXERTION", "Dyspnea On Exertion", 6)
    MakeCodeLink(clinicalEvidenceLinks, "R53.83", "Fatigue", 7)
    MakeAbstractionLink(clinicalEvidenceLinks, "HEART_PALPITATIONS", "Heart Palpitations", 8)
    MakeAbstractionLink(clinicalEvidenceLinks, "IMPLANTABLE_CARDIAC_ASSIST_DEVICE", "Implantable Cardiac Assist Device", 9)
    MakeAbstractionLink(clinicalEvidenceLinks, "IRREGULAR_ECHO_FINDING", "Irregular Echo Findings", 10)
    MakeCodeLink(clinicalEvidenceLinks, "R42", "Light Headed", 11)
    MakeAbstractionLink(clinicalEvidenceLinks, "MAZE_PROCEDURE", "Maze Procedure", 12)
    MakeCodeLink(clinicalEvidenceLinks, "I34.0", "Mitral Regurgitation", 13)
    MakeCodeLink(clinicalEvidenceLinks, "I34.2", "Mitral Stenosis", 14)
    MakeCodeLink(clinicalEvidenceLinks, "I35.1", "Pulmonic Regurgitation", 15)
    MakeCodeLink(clinicalEvidenceLinks, "I37.0", "Pulmonic Stenosis", 16)
    MakeAbstractionLink(clinicalEvidenceLinks, "SHORTNESS_OF_BREATH", "", 17)
    MakeCodeLink(clinicalEvidenceLinks, "R55", "Syncopal", 18)
    MakeCodeLink(clinicalEvidenceLinks, "I36.1", "Tricuspid Regurgitation", 19)
    MakeCodeLink(clinicalEvidenceLinks, "I36.0", "Tricuspid Stenosis", 20)
    MakeAbstractionLink(clinicalEvidenceLinks, "WATCHMAN_PROCEDURE", "Watchman Procedure", 21)

    -- EKG Links (Document Links)
    MakeDocumentLink(ekgLinks, "EKG", "EKG", 0)
    MakeDocumentLink(ekgLinks, "Telemetry Strips", "Telemetry Strips", 0)

    -- Treatment Links (Medication Links)
    MakeMedicationLink(treatmentLinks, "Adenosine", "Adenosine", 1)
    MakeAbstractionValueLink(treatmentLinks, "ADENOSINE", "Adenosine", 2)
    MakeMedicationLink(treatmentLinks, "Antiarrhythmic", "Antiarrhythmic", 3)
    MakeAbstractionValueLink(treatmentLinks, "ANTIARRHYTHMIC", "Antiarrhythmic", 4)
    MakeMedicationLink(treatmentLinks, "Anticoagulant", "Anticoagulant", 5)
    MakeAbstractionValueLink(treatmentLinks, "ANTICOAGULANT", "Anticoagulant", 6)
    MakeMedicationLink(treatmentLinks, "Antiplatelet", "Antiplatelet", 7)
    MakeAbstractionValueLink(treatmentLinks, "ANTIPLATELET", "Antiplatelet", 8)
    MakeMedicationLink(treatmentLinks, "Beta Blocker", "Beta Blocker", 9)
    MakeAbstractionValueLink(treatmentLinks, "BETA_BLOCKER", "Beta Blocker", 10)
    MakeMedicationLink(treatmentLinks, "Calcium Channel Blocker", "Calcium Channel Blocker", 11)
    MakeAbstractionValueLink(treatmentLinks, "CALCIUM_CHANNEL_BLOCKER", "Calcium Channel Blocker", 12)
    MakeMedicationLink(treatmentLinks, "Digitalis", "Digoxin", 13)
    MakeAbstractionValueLink(treatmentLinks, "DIGOXIN", "Digoxin", 14)
    MakeCodeLink(treatmentLinks, "Z79.01", "Long Term Use of Anticoagulant", 15)
    MakeCodeLink(treatmentLinks, "Z79.02", "Long Term use of Antithrombotics/Antiplatelet", 16)

    -- Vital Links (Discete Value Links)
    MakeDiscreteValueLink(vitalsLinks, heartRateDiscreteValueNames, "Heart Rate", 1)
    MakeAbstractionValueLink(vitalsLinks, "HIGH_HEART_RATE", "Heart Rate", 1)
    MakeDiscreteValueLink(vitalsLinks, mapDiscreteValueNames, "Mean Arterial Pressure", 2)
    MakeAbstractionValueLink(vitalsLinks, "LOW_MEAN_ARTERIAL_BLOOD_PRESSURE", "Blood Pressure", 2)
    MakeDiscreteValueLink(vitalsLinks, sbpDiscreteValueNames, "Systolic Blood Pressure", 3)
    MakeAbstractionValueLink(vitalsLinks, "LOW_SYSTOLIC_BLOOD_PRESSURE", "Systolic Blood Pressure", 3)

    clinicalEvidenceHeading.links = clinicalEvidenceLinks
    ekgHeading.links = ekgLinks
    treatmentHeading.links = treatmentLinks
    vitalsHeading.links = vitalsLinks
end



--------------------------------------------------------------------------------
--- Result Finalization 
--------------------------------------------------------------------------------
if alertMatched or alertAutoResolved then
    --- Result Links temp table
    ---
    --- @type CdiAlertLink[]
    local resultLinks = {}

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

