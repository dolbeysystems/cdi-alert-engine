---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Atrial Fibrillation
---
--- This script checks an account to see if it matches the criteria for an atrial fibrillation alert.
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
local dvHeartRate = {
    "Heart Rate cc (bpm)",
    "3.5 Heart Rate (Apical) (bpm)",
    "3.5 Heart Rate (Other) (bpm)",
    "3.5 Heart Rate (Radial) (bpm)",
    "SCC Monitor Pulse (bpm)"
}
local highHeartRatePredicate = function(dv) return GetDvValueNumber(dv) > 90 end
local mapDvNames = { "Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)" }
local lowMAPPredicate = function(dv) return GetDvValueNumber(dv) < 70 end
local systolicBloodPressureDvNames = { "SBP 3.5 (No Calculation) (mm Hg)" }
local lowSystolicBloodPressurePredicate = function (dv) return GetDvValueNumber(dv) < 90 end

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
    local vitalSignsIntakeHeader = MakeHeaderLink("Vital Signs/Intake and Output Data")
    local vitalSignsIntakeLinks = {}
    local clinicalEvidenceHeader = MakeHeaderLink("Clinical Evidence")
    local clinicalEvidenceLinks = {}
    local treatmentAndMonitoringHeader = MakeHeaderLink("Treatment and Monitoring")
    local treatmentAndMonitoringLinks = {}
    local ekgHeader = MakeHeaderLink("EKG")
    local ekgLinks = {}




    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    local i4891CodeLink = GetCodeLinks { code="I48.91", text="Unspecified Atrial Fibrillation Dx Present" }
    local atrialFibrillationAbstractionLink = GetAbstractionLinks { code="ATRIAL_FIBRILLATION", text="Atrial Fibrillation" }
    local i480CodeLink = GetCodeLinks { code="I48.0", text="Paroxysmal Atrial Fibrillation" }
    local i4811CodeLink = GetCodeLinks { code="I48.11", text="Longstanding Persistent Atrial Fibrillation" }
    local i4819CodeLink = GetCodeLinks { code="I48.19", text="Other Persistent Atrial Fibrillation" }
    local i4820CodeLink = GetCodeLinks { code="I48.20", text="Chronic Atrial Fibrillation" }
    local i4821CodeLink = GetCodeLinks { code="I48.21", text="Permanent Atrial Fibrillation" }




    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    -- Alert Conflicting Atrial Fibrillation Dx
    if i480CodeLink and (i4819CodeLink or i4820CodeLink or i4821CodeLink) then
        table.insert(documentedDxLinks, i480CodeLink)
        table.insert(documentedDxLinks, i4819CodeLink)
        table.insert(documentedDxLinks, i4820CodeLink)
        table.insert(documentedDxLinks, i4821CodeLink)
        Result.subtitle = "Conflicting Atrial Fibrillation Dx"
        Result.passed = true

        if existingAlert and existingAlert.validated then
            Result.validated = false
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
        end

    -- Auto Resolve Unspecified Atrial Fibrillation Dx
    elseif subtitle == "Unspecified Atrial Fibrillation Dx" and #accountAlertCodes > 0 then
        for _, code in ipairs(accountAlertCodes) do
            local description = alertCodeDictionary[code]
            local tempCode = GetCodeLinks { code=code, text="Autoresolved Specified Code - " .. description }

            if tempCode then
                table.insert(documentedDxLinks, tempCode)
            end
        end
        Result.validated = true
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.passed = true

    -- Unspecified Atrial Fibrillation Dx
    elseif i4891CodeLink and #accountAlertCodes == 0 then
        table.insert(documentedDxLinks, i4891CodeLink)
        Result.subtitle = "Unspecified Atrial Fibrillation Dx"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        local resultLinks = {}

        if not Result.validated then
            -- Clinical Evidence Links
            GetAbstractionLink { code = "ABLATION", text = "Ablation", target = clinicalEvidenceLinks, seq = 1 }
            GetCodeLink { code = "I35.1", text = "Aortic Regurgitation", target = clinicalEvidenceLinks, seq = 2 }
            GetCodeLink { code = "I35.0", text = "Aortic Stenosis", target = clinicalEvidenceLinks, seq = 3 }
            GetAbstractionLink { code = "CARDIOVERSION", text = "Cardioversion", target = clinicalEvidenceLinks, seq = 4 }
            GetAbstractionValueLink { code = "DYSPNEA_ON_EXERTION", text = "Dyspnea On Exertion", target = clinicalEvidenceLinks, seq = 5 }
            GetCodeLink { code = "R53.83", text = "Fatigue", target = clinicalEvidenceLinks, seq = 6 }
            GetAbstractionLink { code = "HEART_PALPITATIONS", text = "Heart Palpitations", target = clinicalEvidenceLinks, seq = 7 }
            GetAbstractionLink { code = "IMPLANTABLE_CARDIAC_ASSIST_DEVICE", text = "Implantable Cardiac Assist Device", target = clinicalEvidenceLinks, seq = 8 }
            GetAbstractionLink { code = "IRREGULAR_ECHO_FINDING", text = "Irregular Echo Findings", target = clinicalEvidenceLinks, seq = 9 }
            GetCodeLink { code = "R42", text = "Light Headed", target = clinicalEvidenceLinks, seq = 10 }
            GetAbstractionLink { code = "MAZE_PROCEDURE", text = "Maze Procedure", target = clinicalEvidenceLinks, seq = 11 }
            GetCodeLink { code = "I34.0", text = "Mitral Regurgitation", target = clinicalEvidenceLinks, seq = 12 }
            GetCodeLink { code = "I34.2", text = "Mitral Stenosis", target = clinicalEvidenceLinks, seq = 13 }
            GetCodeLink { code = "I35.1", text = "Pulmonic Regurgitation", target = clinicalEvidenceLinks, seq = 14 }
            GetCodeLink { code = "I37.0", text = "Pulmonic Stenosis", target = clinicalEvidenceLinks, seq = 15 }
            GetAbstractionValueLink { code = "SHORTNESS_OF_BREATH", text = "Shortness of Breath", target = clinicalEvidenceLinks, seq = 16 }
            GetCodeLink { code = "R55", text = "Syncopal", target = clinicalEvidenceLinks, seq = 17 }
            GetCodeLink { code = "I36.1", text = "Tricuspid Regurgitation", target = clinicalEvidenceLinks, seq = 18 }
            GetCodeLink { code = "I36.0", text = "Tricuspid Stenosis", target = clinicalEvidenceLinks, seq = 19 }
            GetAbstractionLink { code = "WATCHMAN_PROCEDURE", text = "Watchman Procedure", target = clinicalEvidenceLinks, seq = 20 }

            -- Document Links
            GetDocumentLink { documentType = "EKG", text = "EKG", target = ekgLinks }
            GetDocumentLink { documentType = "Electrocardiogram Adult   ECGR", text = "Electrocardiogram Adult   ECGR", target = ekgLinks }
            GetDocumentLink { documentType = "ECG Adult", text = "ECG Adult", target = ekgLinks }
            GetDocumentLink { documentType = "RestingECG", text = "RestingECG", target = ekgLinks }
            GetDocumentLink { documentType = "EKG", text = "EKG", target = ekgLinks }

            -- Treatment Links
            GetMedicationLink { cat = "Adenosine", text = "", target = treatmentAndMonitoringLinks, seq = 1 }
            GetAbstractionLink { code = "ADENOSINE", text = "Adenosine", target = treatmentAndMonitoringLinks, seq = 2 }
            GetMedicationLink { cat = "Antiarrhythmic", text = "", target = treatmentAndMonitoringLinks, seq = 3 }
            GetAbstractionLink { code = "ANTIARRHYTHMIC", text = "Antiarrhythmic", target = treatmentAndMonitoringLinks, seq = 4 }
            GetMedicationLink { cat = "Anticoagulant", text = "", target = treatmentAndMonitoringLinks, seq = 5 }
            GetAbstractionLink { code = "ANTICOAGULANT", text = "Anticoagulant", target = treatmentAndMonitoringLinks, seq = 6 }
            GetMedicationLink { cat = "Antiplatelet", text = "", target = treatmentAndMonitoringLinks, seq = 7 }
            GetAbstractionLink { code = "ANTIPLATELET", text = "Antiplatelet", target = treatmentAndMonitoringLinks, seq = 8 }
            GetMedicationLink { cat = "Beta Blocker", text = "", target = treatmentAndMonitoringLinks, seq = 9 }
            GetAbstractionLink { code = "BETA_BLOCKER", text = "Beta Blocker", target = treatmentAndMonitoringLinks, seq = 10 }
            GetMedicationLink { cat = "Calcium Channel Blockers", text = "", target = treatmentAndMonitoringLinks, seq = 11 }
            GetAbstractionLink { code = "CALCIUM_CHANNEL_BLOCKER", text = "Calcium Channel Blocker", target = treatmentAndMonitoringLinks, seq = 12 }
            GetMedicationLink { cat = "Digitalis", text = "", target = treatmentAndMonitoringLinks, seq = 13 }
            GetAbstractionLink { code = "DIGOXIN", text = "Digoxin", target = treatmentAndMonitoringLinks, seq = 14 }
            GetCodeLink { code = "Z79.01", text = "Long Term Use of Z79.01", target = treatmentAndMonitoringLinks, seq = 15 }
            GetCodeLink { code = "Z79.02", text = "Long Term Use of Antithrombotics/Z79.02", target = treatmentAndMonitoringLinks, seq = 16 }

            -- Vital Links
            GetDiscreteValueLink { discreteValueNames = dvHeartRate, text = "Heart Rate", target = vitalSignsIntakeLinks, seq = 1, calc = highHeartRatePredicate }
            GetDiscreteValueLink { discreteValueNames = mapDvNames, text = "Mean Arterial Pressure", target = vitalSignsIntakeLinks, seq = 2, calc = lowMAPPredicate }
            GetDiscreteValueLink { discreteValueNames = systolicBloodPressureDvNames, text = "Systolic Blood Pressure", target = vitalSignsIntakeLinks, seq = 3, calc = lowSystolicBloodPressurePredicate }
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        if #documentedDxLinks > 0 then
            documentedDxHeader.links = documentedDxLinks
            table.insert(resultLinks, documentedDxHeader)
        end
        if #clinicalEvidenceLinks > 0 then
            clinicalEvidenceHeader.links = clinicalEvidenceLinks
            table.insert(resultLinks, clinicalEvidenceHeader)
        end
        if #vitalSignsIntakeLinks > 0 then
            vitalSignsIntakeHeader.links = vitalSignsIntakeLinks
            table.insert(resultLinks, vitalSignsIntakeHeader)
        end
        if #treatmentAndMonitoringLinks > 0 then
            treatmentAndMonitoringHeader.links = treatmentAndMonitoringLinks
            table.insert(resultLinks, treatmentAndMonitoringHeader)
        end
        if #ekgLinks > 0 then
            ekgHeader.links = ekgLinks
            table.insert(resultLinks, ekgHeader)
        end

        if existingAlert then
            resultLinks = MergeLinks(existingAlert.links, resultLinks)
        end
        Result.links = resultLinks
    end
end

