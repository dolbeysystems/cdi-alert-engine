local dependenceCodesDictionary = {
    ["F10.230"] = "Alcohol Dependence with Withdrawal, Uncomplicated",
    ["F10.231"] = "Alcohol Dependence with Withdrawal Delirium",
    ["F10.232"] = "Alcohol Dependence with Withdrawal with Perceptual Disturbance",
    ["F10.239"] = "Alcohol Dependence with Withdrawal, Unspecified",
    ["F11.20"] = "Opioid Depndence, Uncomplicated",
}
local autoEvidenceText = "Autoresolved Evidence - "
local autoCodeText = "Autoresolved Code - "
local accountDependenceCodes = {}

for i = 1, #account.documents do
    local document = account.documents[i]
    for j = 1, #document.code_references do
        local codeReference = document.code_references[j]

        if dependenceCodesDictionary[codeReference.code] then
            local code = codeReference.code
            table.insert(accountDependenceCodes, code)
        end
    end
end

local existingAlert = GetExistingCdiAlert{ scriptName = "substance_abuse.lua" }
local alertTriggered = existingAlert ~= nil
local alertValidated = existingAlert ~= nil and existingAlert.validated
local outcome =  existingAlert ~= nil and existingAlert.outcome or ""
local subtitle = existingAlert ~= nil and existingAlert.subtitle or ""
local alertPassed = false
local alertConditions = false

local documentationIncludesLink = CdiAlertLink:new()
documentationIncludesLink.link_text = "Documentation Includes"

local clinicalEvidenceLink = CdiAlertLink:new()
clinicalEvidenceLink.link_text = "Clinical Evidence"

local treatmentLink = CdiAlertLink:new()
treatmentLink.link_text = "Treatment"

local f1120CodeLink, ciwaScoreAbsLink, ciwaProtocolAbsLink, methadoneClinicAbsLink, methadoneMedLink, methadoneAbsLink, suboxoneMedLink, suboxoneAbsLink

if not alertValidated then
    -- General Subtitle Declaration
    local opiodSubtitle = "Possible Opioid Dependence"
    local alcoholSubtitle = "Possible Alcohol Dependence"

    -- Negation
    f1120CodeLink = GetCodeLinks {
        code = "F1120",
        linkTemplate = "Opioid Dependence: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
        single = true,
        sequence = 0
    }

    -- Abstractions
    ciwaScoreAbsLink = GetCodeLinks {
        code = "CIWA_SCORE",
        linkTemplate = "CIWA Score: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
        single = true,
        sequence = 4
    }
    ciwaProtocolAbsLink = GetCodeLinks {
        code = "CIWA_PROTOCOL",
        linkTemplate = "CIWA Protocol: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
        single = true,
        sequence = 5
    }
    methadoneClinicAbsLink = GetCodeLinks {
        code = "METHADONE_CLINIC",
        linkTemplate = "Methadone Clinic: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
        single = true,
        sequence = 11
    }

    -- Medications
    methadoneMedLink = GetMedicationLinks {
        medication = "Methadone",
        linkTemplate = "Methadone: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])",
        single = true,
        sequence = 7
    }
    methadoneAbsLink = GetCodeLinks {
        code = "METHADONE",
        linkTemplate = "Methadone: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
        single = true,
        sequence = 8
    }
    suboxoneMedLink = GetMedicationLinks {
        medication = "Suboxone",
        linkTemplate = "Suboxone: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])",
        single = true,
        sequence = 11
    }
    suboxoneAbsLink = GetCodeLinks {
        code = "SUBOXONE",
        linkTemplate = "Suboxone: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
        single = true,
        sequence = 12
    }

    -- Algorithm
    if (#accountDependenceCodes >= 1 and subtitle == alcoholSubtitle) or (f1120CodeLink ~= nil and subtitle == opiodSubtitle) then
        debug("One specific code was on the chart, alert failed" .. account.id)
        if alertTriggered then
            if subtitle == alcoholSubtitle then
                local documentationIncludesLinks = {}
                for codeIndex = 1, #accountDependenceCodes do
                    local code = accountDependenceCodes[codeIndex]
                    local desc = dependenceCodesDictionary[code]
                    local tempCode = GetCodeLinks {
                        code = code,
                        linkTemplate = "Autoresolved Specified Code - " .. desc .. ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
                        single = true,
                    }
                    if tempCode ~= nil then
                        table.insert(documentationIncludesLinks, tempCode)
                    end
                end
                documentationIncludesLink.links = documentationIncludesLinks

            elseif subtitle == opiodSubtitle then
                f1120CodeLink.link_text = autoCodeText .. f1120CodeLink.link_text
                documentationIncludesLink.links = {f1120CodeLink}
            end
            result.outcome = "AUTORESOLVED"
            result.reason = "Autoresolved due to one Specified Code on Account"
            result.validated = true
            alertConditions = true
        else
            result.passed = false
        end

    elseif f1120CodeLink == nil and (methadoneMedLink ~= nil or methadoneAbsLink ~= nil or suboxoneMedLink ~= nil or suboxoneAbsLink ~= nil or methadoneClinicAbsLink ~= nil) then
        result.subtitle = opiodSubtitle
        alertPassed = true
    elseif #accountDependenceCodes == 0 and (ciwaScoreAbsLink ~= nil or ciwaProtocolAbsLink ~= nil) then
        result.subtitle = alcoholSubtitle
        alertPassed = true
    else
        debug("Not enough data to warrant alert, Alert Failed. " .. account.id)
        result.passed = false
    end
end

if alertPassed then
    local clinicalEvidenceLinks = {}
    local treatmentLinks = {}

    local function addClinicalEvidenceLink(link)
        if link ~= nil then
            table.insert(clinicalEvidenceLinks, link)
        end
    end
    local function addTreatmentLink(link)
        if link ~= nil then
            table.insert(treatmentLinks, link)
        end
    end

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

    for i = 1, #fcodeLinks do
        table.insert(clinicalEvidenceLinks, fcodeLinks[i])
    end

    addClinicalEvidenceLink(
        GetCodeLinks {
            code = "ALTERED_LEVEL_OF_CONSCIOUSNESS",
            linkTemplate = "Altered Mental Status: '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
            single = true,
            sequence = 2
        }
    )

    addClinicalEvidenceLink(
        GetCodeLinks {
            code = "R44.0",
            linkTemplate = "Auditory Hallucinations: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
            single = true,
            sequence = 3
        }
    )

    if ciwaScoreAbsLink ~= nil then
        addClinicalEvidenceLink(ciwaScoreAbsLink)
    end
    if ciwaProtocolAbsLink ~= nil then
        addClinicalEvidenceLink(ciwaProtocolAbsLink)
    end



    -- TODO:  Still converting...left off here



    clinicalEvidenceLink.links = clinicalEvidenceLinks
    treatmentLink.links = treatmentLinks
end

if alertPassed or alertConditions then
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
