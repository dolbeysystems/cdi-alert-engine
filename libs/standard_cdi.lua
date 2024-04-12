---------------------------------------------------------------------------------------------
--- standard_cdi.lua - A library of common functions for use in cdi alert scripts
---------------------------------------------------------------------------------------------



---------------------------------------------------------------------------------------------
--- Requires
---------------------------------------------------------------------------------------------
require("libs.common")



---------------------------------------------------------------------------------------------
--- Globals
---------------------------------------------------------------------------------------------
ExistingAlert = GetExistingCdiAlert{ scriptName = ScriptName }
AlertMatched = false
AlertAutoResolved = false

DocumentationIncludesHeader = MakeHeaderLink("Documentation Includes")
ClinicalEvidenceHeader = MakeHeaderLink("Clinical Evidence")
TreatmentHeader = MakeHeaderLink("Treatment")
VitalsHeading = MakeHeaderLink("Vital Signs/Intake and Output Data")

--- @type CdiAlertLink[]
DocumentationIncludesLinks = {}

--- @type CdiAlertLink[]
ClinicalEvidenceLinks = {}

--- @type CdiAlertLink[]
TreatmentLinks = {}

--- @type CdiAlertLink[]
VitalsLinks = {}



---------------------------------------------------------------------------------------------
--- Functions
---------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--- Adds an abstraction value link to the Clinical Evidence Header Temp Links
--- @param code string
--- @param text string
--- @param seq number
--------------------------------------------------------------------------------
function AddEvidenceAbs(code, text, seq)
    GetAbstractionLinks { target=ClinicalEvidenceLinks, code=code, text=text, seq=seq }
end

--------------------------------------------------------------------------------
--- Adds a code link to the Clinical Evidence Header Temp Links
--- @param code string
--- @param text string
--- @param seq number
--------------------------------------------------------------------------------
function AddEvidenceCode(code, text, seq)
    GetCodeLinks { target=ClinicalEvidenceLinks, code=code, text=text, seq=seq }
end

--------------------------------------------------------------------------------
--- Adds a medication link to the Treatment Header Temp Links
---
--- @param cat string
--- @param text string
--- @param seq number
--------------------------------------------------------------------------------
function AddTreatmentMed(cat, text, seq)
    GetMedicationLinks { target=TreatmentLinks, cat=cat, text=text, seq=seq }
end

--------------------------------------------------------------------------------
--- Adds an abstraction value link to the Treatment Header Temp Links
---
--- @param code string
--- @param text string
--- @param seq number
--------------------------------------------------------------------------------
function AddTreatmentAbs(code, text, seq)
    GetAbstractionValueLinks { target=TreatmentLinks, code=code, text=text, seq=seq }
end

--------------------------------------------------------------------------------
--- Adds a code link to the Treatment Header Temp Links
---
--- @param code string
--- @param text string
--- @param seq number
--------------------------------------------------------------------------------
function AddTreatmentCode(code, text, seq)
    GetCodeLinks { target=TreatmentLinks, code=code, text=text, seq=seq }
end

--------------------------------------------------------------------------------
--- Adds a discrete value link to the Vitals Header Temp Links
---
--- @param dv string[]
--- @param text string
--- @param seq number
--------------------------------------------------------------------------------
function AddVitalsDv(dv, text, seq)
    GetDiscreteValueLinks { target=VitalsLinks, discreteValueNames=dv, text=text, seq=seq }
end

--------------------------------------------------------------------------------
--- Adds an abstraction value link to the Vitals Header Temp Links
---
--- @param code string
--- @param text string
--- @param seq number
--------------------------------------------------------------------------------
function AddVitalsAbs(code, text, seq)
    GetAbstractionValueLinks { target=VitalsLinks, code=code, text=text, seq=seq }
end

--------------------------------------------------------------------------------
--- Get the final top links for the CDI alert
---
--- @param additionalHeaders CdiAlertLink[] Additional headers to add to the final top links
---
--- @return CdiAlertLink[] - The final top links for the CDI alert
--------------------------------------------------------------------------------
function GetFinalTopLinks(additionalHeaders)
    local finalLinks = {}

    if #DocumentationIncludesLinks > 0 then
        DocumentationIncludesHeader.links = DocumentationIncludesLinks
        table.insert(finalLinks, DocumentationIncludesHeader)
    end
    if #ClinicalEvidenceLinks > 0 then
        ClinicalEvidenceHeader.links = ClinicalEvidenceLinks
        table.insert(finalLinks, ClinicalEvidenceHeader)
    end
    if #VitalsLinks > 0 then
        VitalsHeading.links = VitalsLinks
        table.insert(finalLinks, VitalsHeading)
    end
    if #TreatmentLinks > 0 then
        TreatmentHeader.links = TreatmentLinks
        table.insert(finalLinks, TreatmentHeader)
    end

    for _, header in ipairs(additionalHeaders) do
        table.insert(finalLinks, header)
    end
    return finalLinks
end

--------------------------------------------------------------------------------
--- Get the account codes that are present as keys in the provided dictionary
---
--- @param account Account The account to get the codes from
--- @param dictionary table<string, string> The dictionary of codes to check against
---
--- @return string[] - List of codes in dependecy map that are present on the account (codes only)
--------------------------------------------------------------------------------
function GetAccountCodesInDictionary(account, dictionary)
    --- List of codes in dependecy map that are present on the account (codes only)
    ---
    --- @type string[]
    local codes = {}

    -- Populate accountDependenceCodes list
    for i = 1, #account.documents do
        --- @type Document
        local document = account.documents[i]
        for j = 1, #document.code_references do
            local codeReference = document.code_references[j]

            if dictionary[codeReference.code] then
                local code = codeReference.code
                table.insert(codes, code)
            end
        end
    end
    return codes
end

--------------------------------------------------------------------------------
--- Merge links with links from an existing alert
---
--- @param alert CdiAlert? The existing alert
--- @param links CdiAlertLink[] The links to merge
---
--- @return CdiAlertLink[] - The merged links
--------------------------------------------------------------------------------
function MergeLinksWithExisting(alert, links)
    if not alert then
        return links
    end
    -- TODO: Implement standard merge logic
    return links
end

