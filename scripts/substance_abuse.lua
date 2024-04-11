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
--- Dependency codes with descriptions
local dependenceCodesDictionary = {
    ["F10.230"] = "Alcohol Dependence with Withdrawal, Uncomplicated",
    ["F10.231"] = "Alcohol Dependence with Withdrawal Delirium",
    ["F10.232"] = "Alcohol Dependence with Withdrawal with Perceptual Disturbance",
    ["F10.239"] = "Alcohol Dependence with Withdrawal, Unspecified",
    ["F11.20"] = "Opioid Depndence, Uncomplicated",
}

--- List of codes in dependecy map that are present on the account (codes only)
local accountDependenceCodes = GetAccountCodesInDictionary(account, dependenceCodesDictionary)

--- Existing substance abuse alert (or nil if this alert doesn't exist currently on the account)
local existingAlert = GetExistingCdiAlert{ scriptName = "substance_abuse.lua" }

--- Subtitle of the existing alert (or nil if the alert doesn't exist)
local subtitle = existingAlert and existingAlert.subtitle or nil

--- Boolean indicating that this alert matched conditions and we should proceed with creating links
--- and marking the result as passed
local alertMatched = false

--- Boolean indicating that this alert was autoresolved and we should skip additional link creation,
--- but still mark the result as passed
local alertAutoResolved = false

--- Top-level link for holding documentation links
---
--- @type CdiAlertLink
local documentationIncludesLink = CdiAlertLink:new()
documentationIncludesLink.link_text = "Documentation Includes"

--- Top-level links for holding clinical evidence
---
--- @type CdiAlertLink
local clinicalEvidenceLink = CdiAlertLink:new()
clinicalEvidenceLink.link_text = "Clinical Evidence"

--- Top-level link for holding treatment links
---
--- @type CdiAlertLink
local treatmentLink = CdiAlertLink:new()
treatmentLink.link_text = "Treatment"

--- Link for F11.20 code
---
--- @type CdiAlertLink?
local f1120CodeLink

--- Link for CIWA Score
---
--- @type CdiAlertLink?
local ciwaScoreAbsLink

--- Link for CIWA Protocol
---
--- @type CdiAlertLink?
local ciwaProtocolAbsLink

--- Link for Methadone Clinic
---
--- @type CdiAlertLink?
local methadoneClinicAbsLink

--- Link for Methadone Medication
---
--- @type CdiAlertLink?
local methadoneMedLink

--- Link for Methadone Abstraction
---
--- @type CdiAlertLink?
local methadoneAbsLink

--- Link for Suboxone Medication
---
--- @type CdiAlertLink?
local suboxoneMedLink

--- Link for Suboxone Abstraction
---
--- @type CdiAlertLink?
local suboxoneAbsLink



--------------------------------------------------------------------------------
--- Alert Qualification 
--------------------------------------------------------------------------------
if not existingAlert or not existingAlert.validated then
    -- General Subtitle Declaration
    local opiodSubtitle = "Possible Opioid Dependence"
    local alcoholSubtitle = "Possible Alcohol Dependence"

    -- Negation
    f1120CodeLink = MakeCodeLink(nil, "F11.20", "Opioid Dependence", 0)

    -- Abstractions
    ciwaScoreAbsLink = MakeAbstractionValueLink(nil, "CIWA_SCORE", "CIWA Score", 4)
    ciwaProtocolAbsLink = MakeAbstractionValueLink(nil, "CIWA_PROTOCOL", "CIWA Protocol", 5)
    methadoneClinicAbsLink = MakeAbstractionValueLink(nil, "METHADONE_CLINIC", "Methadone Clinic", 11)
    -- Medications
    methadoneMedLink = MakeMedicationLink(nil, "Methadone", "Methadone", 7)
    methadoneAbsLink = MakeAbstractionValueLink(nil, "METHADONE", "Methadone", 8)
    suboxoneMedLink = MakeMedicationLink(nil, "Suboxone", "Suboxone", 11)
    suboxoneAbsLink = MakeAbstractionValueLink(nil, "SUBOXONE", "Suboxone", 12)

    -- Algorithm
    if (#accountDependenceCodes >= 1 and subtitle == alcoholSubtitle) or
       (f1120CodeLink and subtitle == opiodSubtitle) then
        debug("One specific code was on the chart, alert failed" .. account.id)
        if existingAlert then
            if subtitle == alcoholSubtitle then
                --- @type CdiAlertLink[]
                local documentationIncludesLinks = {}
                for codeIndex = 1, #accountDependenceCodes do
                    local code = accountDependenceCodes[codeIndex]
                    local desc = dependenceCodesDictionary[code]
                    local tempCode = GetCodeLinks {
                        code = code,
                        linkTemplate =
                            "Autoresolved Specified Code - " ..
                            desc ..
                            ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
                        single = true,
                    }
                    if tempCode then
                        table.insert(documentationIncludesLinks, tempCode)
                    end
                end
                documentationIncludesLink.links = documentationIncludesLinks

            elseif subtitle == opiodSubtitle and f1120CodeLink then
                f1120CodeLink.link_text = "Autoresolved Evidence - " .. f1120CodeLink.link_text
                documentationIncludesLink.links = {f1120CodeLink}
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
    --- Clinical Evidence Links temp table
    ---
    --- @type CdiAlertLink[]
    local clinicalEvidenceLinks = {}

    --- Treatment Links temp table
    ---
    --- @type CdiAlertLink[]
    local treatmentLinks = {}

    -- Abstractions
    local fcodeLinks = GetCodeLinks {
        codes = {
            "F10.20", "F10.21", "F10.220", "F10.221", "F10.229", "F10.24", "F10.250", "F10.251",
            "F10.259", "F10.26", "F10.27", "F10.280", "F10.281", "F10.282", "F10.288", "F10.29",
        },
        linkTemplate = "Alcohol Dependence: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
        sequence = 1,
        fixed_sequence = true
    }

    if fcodeLinks then
        for i = 1, #fcodeLinks do
            table.insert(clinicalEvidenceLinks, fcodeLinks[i])
        end
    end

    MakeAbstractionLink(clinicalEvidenceLinks, "ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Mental Status", 2)
    MakeAbstractionLink(clinicalEvidenceLinks, "AUDITORY_HALLUCINATIONS", "Auditory Hallucinations", 3)

    if ciwaScoreAbsLink then
        table.insert(clinicalEvidenceLinks, ciwaScoreAbsLink) -- #4
    end
    if ciwaProtocolAbsLink then
        table.insert(clinicalEvidenceLinks, ciwaProtocolAbsLink) -- #5
    end

    MakeAbstractionLink(clinicalEvidenceLinks, "COMBATIVE", "Combative", 6)
    MakeAbstractionLink(clinicalEvidenceLinks, "DELIRIUM", "Delirium", 7)
    MakeCodeLink(clinicalEvidenceLinks, "R44.3", "Hallucinations", 8)
    MakeCodeLink(clinicalEvidenceLinks, "R51.9", "Headache", 9)
    MakeCodeLink(clinicalEvidenceLinks, "R45.4", "Irritability and Anger", 10)

    if methadoneClinicAbsLink then
        table.insert(clinicalEvidenceLinks, methadoneClinicAbsLink) -- #11
    end
    -- TODO:  Still converting...left off here
    MakeCodeLink(clinicalEvidenceLinks, "R11.0", "Nausea", 12)
    MakeCodeLink(clinicalEvidenceLinks, "R45.0", "Nervousness", 13)
    MakeCodeLink(clinicalEvidenceLinks, "R11.12", "Projectile Vomiting", 14)
    MakeCodeLink(clinicalEvidenceLinks, "R45.1", "Restless and Agitation", 15)
    MakeCodeLink(clinicalEvidenceLinks, "R61", "Sweating", 16)
    MakeCodeLink(clinicalEvidenceLinks, "R25.1", "Tremor", 17)
    MakeCodeLink(clinicalEvidenceLinks, "R44.1", "Visual Hallucinations", 18)
    MakeCodeLink(clinicalEvidenceLinks, "R11.10", "Vomiting", 19)

    MakeMedicationLink(treatmentLinks, "Benzodiazepine", "Benzodiazepine", 1)
    MakeAbstractionValueLink(treatmentLinks, "BENZODIAZEPINE", "Benzodiazepine", 2)

    MakeMedicationLink(treatmentLinks, "Dexmedetomidine", "Dexmedetomidine", 3)
    MakeAbstractionValueLink(treatmentLinks, "DEXMEDETOMIDINE", "Dexmedetomidine", 4)

    MakeMedicationLink(treatmentLinks, "Lithium", "Lithium", 5)
    MakeAbstractionValueLink(treatmentLinks, "LITHIUM", "Lithium", 6)

    if methadoneMedLink then
        table.insert(treatmentLinks, methadoneMedLink) -- #7
    end
    if methadoneAbsLink then
        table.insert(treatmentLinks, methadoneAbsLink) -- #8
    end

    MakeMedicationLink(treatmentLinks, "Propofol", "Propofol", 9)
    MakeAbstractionValueLink(treatmentLinks, "PROPOFOL", "Propofol", 10)

    if suboxoneMedLink then
        table.insert(treatmentLinks, suboxoneMedLink) -- #11
    end
    if suboxoneAbsLink then
        table.insert(treatmentLinks, suboxoneAbsLink) -- #12
    end

    clinicalEvidenceLink.links = clinicalEvidenceLinks
    --treatmentLink.links = treatmentLinks
end



--------------------------------------------------------------------------------
--- Result Finalization 
--------------------------------------------------------------------------------
if alertMatched or alertAutoResolved then
    --- Result Links temp table
    ---
    --- @type CdiAlertLink[]
    local resultLinks = {}

    if documentationIncludesLink.links then
        table.insert(resultLinks, documentationIncludesLink)
    end
    if clinicalEvidenceLink.links then
        table.insert(resultLinks, clinicalEvidenceLink)
    end
    table.insert(resultLinks, treatmentLink)

    debug(
        "Alert Passed Adding Links. Alert Triggered: " .. result.subtitle .. " " ..
        "Autoresolved: " .. result.outcome .. "; " .. tostring(result.validated) .. "; " ..
        "Links: Documentation Includes- " .. tostring(#documentationIncludesLink.links > 0) .. ", " ..
        "Abs- " .. tostring(#clinicalEvidenceLink.links > 0) .. ", " ..
        "treatment- " .. tostring(#treatmentLink.links > 0) .. "; " ..
        "Acct: " .. account.id
    )
    resultLinks = MergeLinksWithExisting(existingAlert, resultLinks)
    result.links = resultLinks
    result.passed = true
end

