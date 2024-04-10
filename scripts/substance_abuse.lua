---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Substance Abuse
---
--- This script checks an account to see if it matches the criteria for a Substance Abuse alert.
---
--- Date: 10/15/2021
--- Version: 1.0
--- Site: (Default)
---------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Requires 
--------------------------------------------------------------------------------
require("libs.common")



--------------------------------------------------------------------------------
--- Script Local Functions
--------------------------------------------------------------------------------
---
--------------------------------------------------------------------------------
--- Creates a single link for a code reference, optionally adding it to a target
--- table.
---
--- @param targetTable CdiAlertLink[]? The table to add the link to.
--- @param code string The code to create a link for.
--- @param linkPrefix string The first part of the link template.
--- @param sequence number The sequence number to use for the link.
---
--- @return CdiAlertLink? # The link object.
--------------------------------------------------------------------------------
local function makeCodeLink(targetTable, code, linkPrefix, sequence)
    local linkTemplate = linkPrefix .. ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])"
    local link = GetCodeLinks { code = code, linkTemplate = linkTemplate, single = true, sequence = sequence }

    if link ~= nil and targetTable ~= nil then
        table.insert(targetTable, link)
    end
    return link
end

--------------------------------------------------------------------------------
--- Creates a single link for an abstraction value, optionally adding it to a
--- target table.
---
--- @param targetTable CdiAlertLink[]? The table to add the link to.
--- @param code string The code to create a link for.
--- @param linkPrefix string The first part of the link template.
--- @param sequence number The sequence number to use for the link.
---
--- @return CdiAlertLink? # The link object.
--------------------------------------------------------------------------------
local function makeAbstractionLink(targetTable, code, linkPrefix, sequence)
    local linkTemplate = linkPrefix .. " '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])"
    local link = GetCodeLinks { code = code, linkTemplate = linkTemplate, single = true, sequence = sequence }

    if link ~= nil and targetTable ~= nil then
        table.insert(targetTable, link)
    end
    return link
end

--------------------------------------------------------------------------------
--- Creates a single link for an abstraction value, optionally adding it to a
--- target table.
---
--- @param targetTable CdiAlertLink[]? The table to add the link to.
--- @param code string The code to create a link for.
--- @param linkPrefix string The first part of the link template.
--- @param sequence number The sequence number to use for the link.
---
--- @return CdiAlertLink? # The link object.
--------------------------------------------------------------------------------
local function makeAbstractionValueLink(targetTable, code, linkPrefix, sequence)
    local linkTemplate = linkPrefix .. ": [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])"
    local link = GetCodeLinks { code = code, linkTemplate = linkTemplate, single = true, sequence = sequence }

    if link ~= nil and targetTable ~= nil then
        table.insert(targetTable, link)
    end
    return link
end

--------------------------------------------------------------------------------
--- Creates a single link for a medication, optionally adding it to a target 
--- table.
---
--- @param targetTable CdiAlertLink[]? The table to add the link to.
--- @param medication string The medication to create a link for.
--- @param linkPrefix string The first part of the link template.
--- @param sequence number The sequence number to use for the link.
---
--- @return CdiAlertLink? # The link object.
--------------------------------------------------------------------------------
local function makeMedicationLink(targetTable, medication, linkPrefix, sequence)
    local linkTemplate = linkPrefix .. ": [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])"
    local link =
        GetMedicationLinks { medication = medication, linkTemplate = linkTemplate, single = true, sequence = sequence }

    if link ~= nil and targetTable ~= nil then
        table.insert(targetTable, link)
    end
    return link
end



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
---
--- @type string[]
local accountDependenceCodes = {}

-- Populate accountDependenceCodes list
for i = 1, #account.documents do
    --- @type Document
    local document = account.documents[i]
    for j = 1, #document.code_references do
        local codeReference = document.code_references[j]

        if dependenceCodesDictionary[codeReference.code] then
            local code = codeReference.code
            table.insert(accountDependenceCodes, code)
        end
    end
end

--- Existing substance abuse alert (or nil if this alert doesn't exist currently on the account)
local existingAlert = GetExistingCdiAlert{ scriptName = "substance_abuse.lua" }

--- Subtitle of the existing alert (or nil if the alert doesn't exist)
local subtitle = existingAlert ~= nil and existingAlert.subtitle or nil

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
if existingAlert == nil or not existingAlert.validated then
    -- General Subtitle Declaration
    local opiodSubtitle = "Possible Opioid Dependence"
    local alcoholSubtitle = "Possible Alcohol Dependence"

    -- Negation
    f1120CodeLink = makeCodeLink(nil, "F11.20", "Opioid Dependence", 0)

    -- Abstractions
    ciwaScoreAbsLink = makeAbstractionValueLink(nil, "CIWA_SCORE", "CIWA Score", 4)
    ciwaProtocolAbsLink = makeAbstractionValueLink(nil, "CIWA_PROTOCOL", "CIWA Protocol", 5)
    methadoneClinicAbsLink = makeAbstractionValueLink(nil, "METHADONE_CLINIC", "Methadone Clinic", 11)

    -- Medications
    methadoneMedLink = makeMedicationLink(nil, "Methadone", "Methadone", 7)
    methadoneAbsLink = makeAbstractionValueLink(nil, "METHADONE", "Methadone", 8)
    suboxoneMedLink = makeMedicationLink(nil, "Suboxone", "Suboxone", 11)
    suboxoneAbsLink = makeAbstractionValueLink(nil, "SUBOXONE", "Suboxone", 12)

    -- Algorithm
    if (#accountDependenceCodes >= 1 and subtitle == alcoholSubtitle) or
       (f1120CodeLink ~= nil and subtitle == opiodSubtitle) then
        debug("One specific code was on the chart, alert failed" .. account.id)
        if existingAlert ~= nil then
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
                    if tempCode ~= nil then
                        table.insert(documentationIncludesLinks, tempCode)
                    end
                end
                documentationIncludesLink.links = documentationIncludesLinks

            elseif subtitle == opiodSubtitle and f1120CodeLink ~= nil then
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

    elseif f1120CodeLink == nil and (
            methadoneMedLink ~= nil or
            methadoneAbsLink ~= nil or
            suboxoneMedLink ~= nil or
            suboxoneAbsLink ~= nil or
            methadoneClinicAbsLink ~= nil
        ) then
        result.subtitle = opiodSubtitle
        alertMatched = true
    elseif #accountDependenceCodes == 0 and (ciwaScoreAbsLink ~= nil or ciwaProtocolAbsLink ~= nil) then
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

    if fcodeLinks ~= nil then
        for i = 1, #fcodeLinks do
            table.insert(clinicalEvidenceLinks, fcodeLinks[i])
        end
    end

    makeAbstractionLink(clinicalEvidenceLinks, "ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Mental Status", 2)
    makeAbstractionLink(clinicalEvidenceLinks, "AUDITORY_HALLUCINATIONS", "Auditory Hallucinations", 3)

    if ciwaScoreAbsLink ~= nil then
        table.insert(clinicalEvidenceLinks, ciwaScoreAbsLink) -- #4
    end
    if ciwaProtocolAbsLink ~= nil then
        table.insert(clinicalEvidenceLinks, ciwaProtocolAbsLink) -- #5
    end

    makeAbstractionLink(clinicalEvidenceLinks, "COMBATIVE", "Combative", 6)
    makeAbstractionLink(clinicalEvidenceLinks, "DELIRIUM", "Delirium", 7)
    makeCodeLink(clinicalEvidenceLinks, "R44.3", "Hallucinations", 8)
    makeCodeLink(clinicalEvidenceLinks, "R51.9", "Headache", 9)
    makeCodeLink(clinicalEvidenceLinks, "R45.4", "Irritability and Anger", 10)

    if methadoneClinicAbsLink ~= nil then
        table.insert(clinicalEvidenceLinks, methadoneClinicAbsLink) -- #11
    end
    -- TODO:  Still converting...left off here
    makeCodeLink(clinicalEvidenceLinks, "R11.0", "Nausea", 12)
    makeCodeLink(clinicalEvidenceLinks, "R45.0", "Nervousness", 13)
    makeCodeLink(clinicalEvidenceLinks, "R11.12", "Projectile Vomiting", 14)
    makeCodeLink(clinicalEvidenceLinks, "R45.1", "Restless and Agitation", 15)
    makeCodeLink(clinicalEvidenceLinks, "R61", "Sweating", 16)
    makeCodeLink(clinicalEvidenceLinks, "R25.1", "Tremor", 17)
    makeCodeLink(clinicalEvidenceLinks, "R44.1", "Visual Hallucinations", 18)
    makeCodeLink(clinicalEvidenceLinks, "R11.10", "Vomiting", 19)

    makeMedicationLink(treatmentLinks, "Benzodiazepine", "Benzodiazepine", 1)
    makeAbstractionValueLink(treatmentLinks, "BENZODIAZEPINE", "Benzodiazepine", 2)

    makeMedicationLink(treatmentLinks, "Dexmedetomidine", "Dexmedetomidine", 3)
    makeAbstractionValueLink(treatmentLinks, "DEXMEDETOMIDINE", "Dexmedetomidine", 4)

    makeMedicationLink(treatmentLinks, "Lithium", "Lithium", 5)
    makeAbstractionValueLink(treatmentLinks, "LITHIUM", "Lithium", 6)

    if methadoneMedLink ~= nil then
        table.insert(treatmentLinks, methadoneMedLink) -- #7
    end
    if methadoneAbsLink ~= nil then
        table.insert(treatmentLinks, methadoneAbsLink) -- #8
    end

    makeMedicationLink(treatmentLinks, "Propofol", "Propofol", 9)
    makeAbstractionValueLink(treatmentLinks, "PROPOFOL", "Propofol", 10)

    if suboxoneMedLink ~= nil then
        table.insert(treatmentLinks, suboxoneMedLink) -- #11
    end
    if suboxoneAbsLink ~= nil then
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

    if documentationIncludesLink.links ~= nil then
        table.insert(resultLinks, documentationIncludesLink)
    end
    if clinicalEvidenceLink.links ~= nil then
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
    result.links = resultLinks
    result.passed = true
end

