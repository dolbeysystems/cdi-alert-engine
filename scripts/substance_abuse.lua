---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Substance Abuse
---
--- This script checks an account to see if it matches the criteria for a Substance Abuse alert.
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
    ["F10.230"] = "Alcohol Dependence with Withdrawal, Uncomplicated",
    ["F10.231"] = "Alcohol Dependence with Withdrawal Delirium",
    ["F10.232"] = "Alcohol Dependence with Withdrawal with Perceptual Disturbance",
    ["F10.239"] = "Alcohol Dependence with Withdrawal, Unspecified",
    ["F11.20"] = "Opioid Depndence, Uncomplicated",
}
local accountAlertCodes = GetAccountCodesInDictionary(Account, alertCodeDictionary)

local f1120CodeLink = MakeNilLink()
local ciwaScoreAbsLink = MakeNilLink()
local ciwaProtocolAbsLink = MakeNilLink()
local methadoneClinicAbsLink = MakeNilLink()
local methadoneMedLink = MakeNilLink()
local methadoneAbsLink = MakeNilLink()
local suboxoneMedLink = MakeNilLink()
local suboxoneAbsLink = MakeNilLink()



--------------------------------------------------------------------------------
--- Alert Qualification 
--------------------------------------------------------------------------------
if not ExistingAlert or not ExistingAlert.validated then
    -- General Subtitle Declaration
    local opiodSubtitle = "Possible Opioid Dependence"
    local alcoholSubtitle = "Possible Alcohol Dependence"

    -- Negation
    f1120CodeLink = GetCodeLinks { code="F11.20", text="Opiod Dependence" }

    -- Abstractions
    ciwaScoreAbsLink = GetAbstractionLinks { code="CIWA_SCORE", text="CIWA Score", seq=4 }
    ciwaProtocolAbsLink = GetAbstractionValueLinks { code="CIWA_PROTOCOL", text="CIWA Protocol", seq=5 }
    methadoneClinicAbsLink = GetAbstractionValueLinks { code ="METHADONE_CLINIC", text="Methadone Clinic", seq=11 }

    -- Medications
    methadoneMedLink = GetMedicationLinks { cat="Methadone", text="Methadone", seq=7 }
    methadoneAbsLink = GetAbstractionValueLinks { code ="METHADONE", text="Methadone", seq=8 }
    suboxoneMedLink = GetMedicationLinks { cat="Suboxone", text="Suboxone", seq=11 }
    suboxoneAbsLink = GetAbstractionValueLinks { code ="SUBOXONE", text="Suboxone", seq=12 }

    -- Algorithm
    if (#accountAlertCodes >= 1 and ExistingAlert and ExistingAlert.subtitle == alcoholSubtitle) or
       (f1120CodeLink and ExistingAlert and ExistingAlert.subtitle == opiodSubtitle) then
        debug("One specific code was on the chart, alert failed" .. Account.id)
        if ExistingAlert then
            if ExistingAlert and ExistingAlert.subtitle == alcoholSubtitle then
                for codeIndex = 1, #accountAlertCodes do
                    local code=accountAlertCodes[codeIndex]
                    local desc = alertCodeDictionary[code]
                    local tempCode = GetCodeLinks {
                        code=code,
                        linkTemplate =
                            "Autoresolved Specified Code - " .. desc,
                    }
                    if tempCode then
                        table.insert(DocumentationIncludesLinks, tempCode)
                    end
                end

            elseif ExistingAlert and ExistingAlert.subtitle == opiodSubtitle and f1120CodeLink then
                f1120CodeLink.link_text = "Autoresolved Evidence - " .. f1120CodeLink.link_text
                table.insert(DocumentationIncludesLinks, f1120CodeLink)
            end
            Result.outcome = "AUTORESOLVED"
            Result.reason = "Autoresolved due to one Specified Code on Account"
            Result.validated = true
            AlertAutoResolved = true
        else
            Result.passed = false
        end

    elseif not f1120CodeLink and (methadoneMedLink or methadoneAbsLink or suboxoneMedLink or suboxoneAbsLink or methadoneClinicAbsLink) then
        Result.subtitle = opiodSubtitle
        AlertMatched = true
    elseif #accountAlertCodes == 0 and (ciwaScoreAbsLink or ciwaProtocolAbsLink) then
        Result.subtitle = alcoholSubtitle
        AlertMatched = true
    else
        debug("Not enough data to warrant alert, Alert Failed. " .. Account.id)
        Result.passed = false
    end
end



--------------------------------------------------------------------------------
--- Additional Link Creation
--------------------------------------------------------------------------------
if AlertMatched then
    -- Abstractions
    local fcodeLinks = GetCodeLinks {
        codes = {
            "F10.20", "F10.21", "F10.220", "F10.221", "F10.229", "F10.24", "F10.250", "F10.251",
            "F10.259", "F10.26", "F10.27", "F10.280", "F10.281", "F10.282", "F10.288", "F10.29",
        },
        text="Alcohol Dependence",
        seq=1,
        fixed_seq=true,
        max = 999,
    }

    if fcodeLinks then
        for i = 1, #fcodeLinks do
            table.insert(ClinicalEvidenceLinks, fcodeLinks[i])
        end
    end

    AddEvidenceAbs("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Mental Status", 2)
    AddEvidenceAbs("AUDITORY_HALLUCINATIONS", "Auditory Hallucinations", 3)

    if ciwaScoreAbsLink then
        table.insert(ClinicalEvidenceLinks, ciwaScoreAbsLink) -- #4
    end
    if ciwaProtocolAbsLink then
        table.insert(ClinicalEvidenceLinks, ciwaProtocolAbsLink) -- #5
    end

    AddEvidenceAbs("COMBATIVE", "Combative", 6)
    AddEvidenceAbs("DELIRIUM", "Delirium", 7)
    AddEvidenceCode("R44.3", "Hallucinations", 8)
    AddEvidenceCode("R51.9", "Headache", 9)
    AddEvidenceCode("R45.4", "Irritability and Anger", 10)

    if methadoneClinicAbsLink then
        table.insert(ClinicalEvidenceLinks, methadoneClinicAbsLink) -- #11
    end

    AddEvidenceCode("R11.0", "Nausea", 12)
    AddEvidenceCode("R45.0", "Nervousness", 13)
    AddEvidenceCode("R11.12", "Projectile Vomiting", 14)
    AddEvidenceCode("R45.1", "Restless and Agitation", 15)
    AddEvidenceCode("R61", "Sweating", 16)
    AddEvidenceCode("R25.1", "Tremor", 17)
    AddEvidenceCode("R44.1", "Visual Hallucinations", 18)
    AddEvidenceCode("R11.10", "Vomiting", 19)

    AddTreatmentMed("Benzodiazipine", "Benzodiazepine", 1)
    AddTreatmentAbs("BENZODIAZEPINE", "Benzodiazepine", 2)
    AddTreatmentMed("Dexmedetomidine", "Dexmedetomidine", 3)
    AddTreatmentAbs("DEXMEDETOMIDINE", "Dexmedetomidine", 4)
    AddTreatmentMed("Lithium", "Lithium", 5)
    AddTreatmentAbs("LITHIUM", "Lithium", 6)

    if methadoneMedLink then
        table.insert(TreatmentLinks, methadoneMedLink) -- #7
    end
    if methadoneAbsLink then
        table.insert(TreatmentLinks, methadoneAbsLink) -- #8
    end

    AddTreatmentMed("Propofol", "Propofol", 9)
    AddTreatmentAbs("PROPOFOL", "Propofol", 10)

    if suboxoneMedLink then
        table.insert(TreatmentLinks, suboxoneMedLink) -- #11
    end
    if suboxoneAbsLink then
        table.insert(TreatmentLinks, suboxoneAbsLink) -- #12
    end
end



--------------------------------------------------------------------------------
--- Result Finalization 
--------------------------------------------------------------------------------
if AlertMatched or AlertAutoResolved then
    local resultLinks = GetFinalTopLinks({})

    debug(
        "Alert Passed Adding Links. Alert Triggered: " .. Result.subtitle .. " " ..
        "Autoresolved: " .. Result.outcome .. "; " .. tostring(Result.validated) .. "; " ..
        "Links: Documentation Includes- " .. tostring(#DocumentationIncludesHeader.links > 0) .. ", " ..
        "Abs- " .. tostring(#ClinicalEvidenceHeader.links > 0) .. ", " ..
        "treatment- " .. tostring(#TreatmentHeader.links > 0) .. "; " ..
        "Acct: " .. Account.id
    )
    resultLinks = MergeLinksWithExisting(ExistingAlert, resultLinks)
    Result.links = resultLinks
    Result.passed = true
end

