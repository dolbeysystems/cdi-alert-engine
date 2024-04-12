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



--------------------------------------------------------------------------------
--- Setup
--------------------------------------------------------------------------------
local dependenceCodesDictionary = {
    ["F10.230"] = "Alcohol Dependence with Withdrawal, Uncomplicated",
    ["F10.231"] = "Alcohol Dependence with Withdrawal Delirium",
    ["F10.232"] = "Alcohol Dependence with Withdrawal with Perceptual Disturbance",
    ["F10.239"] = "Alcohol Dependence with Withdrawal, Unspecified",
    ["F11.20"] = "Opioid Depndence, Uncomplicated",
}
local accountDependenceCodes = GetAccountCodesInDictionary(account, dependenceCodesDictionary)

local existingAlert = GetExistingCdiAlert{ scriptName = "substance_abuse.lua" }
local subtitle = existingAlert and existingAlert.subtitle or nil
local alertMatched = false
local alertAutoResolved = false

local documentationIncludesHeader = MakeHeaderLink("Documentation Includes")
local clinicalEvidenceHeader = MakeHeaderLink("Clinical Evidence")
local treatmentHeader = MakeHeaderLink("Treatment")

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
if not existingAlert or not existingAlert.validated then
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
    if (#accountDependenceCodes >= 1 and subtitle == alcoholSubtitle) or
       (f1120CodeLink and subtitle == opiodSubtitle) then
        debug("One specific code was on the chart, alert failed" .. account.id)
        if existingAlert then
            if subtitle == alcoholSubtitle then
                local docLinks = MakeLinkArray()
                for codeIndex = 1, #accountDependenceCodes do
                    local code=accountDependenceCodes[codeIndex]
                    local desc = dependenceCodesDictionary[code]
                    local tempCode = GetCodeLinks {
                        code=code,
                        linkTemplate =
                            "Autoresolved Specified Code - " .. desc,
                    }
                    if tempCode then
                        table.insert(docLinks, tempCode)
                    end
                end
                documentationIncludesHeader.links = docLinks

            elseif subtitle == opiodSubtitle and f1120CodeLink then
                f1120CodeLink.link_text = "Autoresolved Evidence - " .. f1120CodeLink.link_text
                documentationIncludesHeader.links = {f1120CodeLink}
            end
            result.outcome = "AUTORESOLVED"
            result.reason = "Autoresolved due to one Specified Code on Account"
            result.validated = true
            alertAutoResolved = true
        else
            result.passed = false
        end

    elseif not f1120CodeLink and (methadoneMedLink or methadoneAbsLink or suboxoneMedLink or suboxoneAbsLink or methadoneClinicAbsLink) then
        result.subtitle = opiodSubtitle
        alertMatched = true
    elseif #accountDependenceCodes == 0 and (ciwaScoreAbsLink or ciwaProtocolAbsLink) then
        result.subtitle = alcoholSubtitle
        alertMatched = true
    else
        debug("Not enough data to warrant alert, Alert Failed. " .. account.id)
        result.passed = false
    end
end



--------------------------------------------------------------------------------
--- Additional Link Creation
--------------------------------------------------------------------------------
if alertMatched then
    local evidenceLinks = MakeLinkArray()
    local treatmentLinks = MakeLinkArray()

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
            table.insert(evidenceLinks, fcodeLinks[i])
        end
    end

    AddEvidenceAbs("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Mental Status", 2)
    AddEvidenceAbs("AUDITORY_HALLUCINATIONS", "Auditory Hallucinations", 3)

    if ciwaScoreAbsLink then
        table.insert(evidenceLinks, ciwaScoreAbsLink) -- #4
    end
    if ciwaProtocolAbsLink then
        table.insert(evidenceLinks, ciwaProtocolAbsLink) -- #5
    end

    AddEvidenceAbs("COMBATIVE", "Combative", 6)
    AddEvidenceAbs("DELIRIUM", "Delirium", 7)
    AddEvidenceCode("R44.3", "Hallucinations", 8)
    AddEvidenceCode("R51.9", "Headache", 9)
    AddEvidenceCode("R45.4", "Irritability and Anger", 10)

    if methadoneClinicAbsLink then
        table.insert(evidenceLinks, methadoneClinicAbsLink) -- #11
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
        table.insert(treatmentLinks, methadoneMedLink) -- #7
    end
    if methadoneAbsLink then
        table.insert(treatmentLinks, methadoneAbsLink) -- #8
    end

    AddTreatmentMed("Propofol", "Propofol", 9)
    AddTreatmentAbs("PROPOFOL", "Propofol", 10)

    if suboxoneMedLink then
        table.insert(treatmentLinks, suboxoneMedLink) -- #11
    end
    if suboxoneAbsLink then
        table.insert(treatmentLinks, suboxoneAbsLink) -- #12
    end

    clinicalEvidenceHeader.links = evidenceLinks
    treatmentHeader.links = treatmentLinks
end



--------------------------------------------------------------------------------
--- Result Finalization 
--------------------------------------------------------------------------------
if alertMatched or alertAutoResolved then
    local resultLinks = MakeLinkArray()

    if documentationIncludesHeader.links then
        table.insert(resultLinks, documentationIncludesHeader)
    end
    if clinicalEvidenceHeader.links then
        table.insert(resultLinks, clinicalEvidenceHeader)
    end
    table.insert(resultLinks, treatmentHeader)

    debug(
        "Alert Passed Adding Links. Alert Triggered: " .. result.subtitle .. " " ..
        "Autoresolved: " .. result.outcome .. "; " .. tostring(result.validated) .. "; " ..
        "Links: Documentation Includes- " .. tostring(#documentationIncludesHeader.links > 0) .. ", " ..
        "Abs- " .. tostring(#clinicalEvidenceHeader.links > 0) .. ", " ..
        "treatment- " .. tostring(#treatmentHeader.links > 0) .. "; " ..
        "Acct: " .. account.id
    )
    resultLinks = MergeLinksWithExisting(existingAlert, resultLinks)
    result.links = resultLinks
    result.passed = true
end

