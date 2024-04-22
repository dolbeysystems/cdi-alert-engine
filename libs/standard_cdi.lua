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
ExistingAlert = GetExistingCdiAlert { scriptName = ScriptName }
AlertMatched = false
AlertAutoResolved = false

DocumentationIncludesHeader = MakeHeaderLink("Documentation Includes")
ClinicalEvidenceHeader = MakeHeaderLink("Clinical Evidence")
TreatmentHeader = MakeHeaderLink("Treatment")
VitalsHeading = MakeHeaderLink("Vital Signs/Intake and Output Data")
LabsHeading = MakeHeaderLink("Laboratory Studies")

--- @type CdiAlertLink[]
DocumentationIncludesLinks = {}

--- @type CdiAlertLink[]
ClinicalEvidenceLinks = {}

--- @type CdiAlertLink[]
TreatmentLinks = {}

--- @type CdiAlertLink[]
VitalsLinks = {}

--- @type CdiAlertLink[]
LabsLinks = {}



---------------------------------------------------------------------------------------------
--- Functions
---------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--- Adds an abstraction value link to the Documentation Includes Header Temp Links
---
--- @param code string The code to link
--- @param text string The text to display in the link
--- @param seq number The sequence number for the link
---
--- @return CdiAlertLink - The discrete value link
--------------------------------------------------------------------------------
function AddDocumentationAbs(code, text, seq)
    local link = GetAbstractionLinks { target=DocumentationIncludesLinks, code=code, text=text, seq=seq }

    --- @cast link CdiAlertLink 
    return link
end

--------------------------------------------------------------------------------
--- Adds a code link to the Documentation Includes Header Temp Links
--- @param code string The code to link
--- @param text string The text to display in the link
--- @param seq number The sequence number for the link
---
--- @return CdiAlertLink - The discrete value link
--------------------------------------------------------------------------------
function AddDocumentationCode(code, text, seq)
    local link = GetCodeLinks { target=DocumentationIncludesLinks, code=code, text=text, seq=seq }

    --- @cast link CdiAlertLink 
    return link
end

--------------------------------------------------------------------------------
--- Adds an abstraction value link to the Clinical Evidence Header Temp Links
--- @param code string The code to link
--- @param text string The text to display in the link
--- @param seq number The sequence number for the link
---
--- @return CdiAlertLink - The discrete value link
--------------------------------------------------------------------------------
function AddEvidenceAbs(code, text, seq)
    local link = GetAbstractionLinks { target=ClinicalEvidenceLinks, code=code, text=text, seq=seq }

    --- @cast link CdiAlertLink 
    return link
end

--------------------------------------------------------------------------------
--- Adds a code link to the Clinical Evidence Header Temp Links
--- @param code string The code to link
--- @param text string The text to display in the link
--- @param seq number The sequence number for the link
---
--- @return CdiAlertLink - The discrete value link
--------------------------------------------------------------------------------
function AddEvidenceCode(code, text, seq)
    local link = GetCodeLinks { target=ClinicalEvidenceLinks, code=code, text=text, seq=seq }

    --- @cast link CdiAlertLink 
    return link
end

--------------------------------------------------------------------------------
--- Adds a medication link to the Treatment Header Temp Links
---
--- @param cat string The category of the medication
--- @param text string The text to display in the link
--- @param seq number The sequence number for the link
---
--- @return CdiAlertLink - The discrete value link
--------------------------------------------------------------------------------
function AddTreatmentMed(cat, text, seq)
    local link = GetMedicationLinks { target=TreatmentLinks, cat=cat, text=text, seq=seq }

    --- @cast link CdiAlertLink 
    return link
end

--------------------------------------------------------------------------------
--- Adds an abstraction value link to the Treatment Header Temp Links
---
--- @param code string The code to link
--- @param text string The text to display in the link
--- @param seq number The sequence number for the link
---
--- @return CdiAlertLink - The discrete value link
--------------------------------------------------------------------------------
function AddTreatmentAbs(code, text, seq)
    local link = GetAbstractionValueLinks { target=TreatmentLinks, code=code, text=text, seq=seq }

    --- @cast link CdiAlertLink 
    return link
end

--------------------------------------------------------------------------------
--- Adds a code link to the Treatment Header Temp Links
---
--- @param code string The code to link
--- @param text string The text to display in the link
--- @param seq number The sequence number for the link
---
--- @return CdiAlertLink - The discrete value link
--------------------------------------------------------------------------------
function AddTreatmentCode(code, text, seq)
    local link = GetCodeLinks { target=TreatmentLinks, code=code, text=text, seq=seq }

    --- @cast link CdiAlertLink 
    return link
end

--------------------------------------------------------------------------------
--- Adds a discrete value link to the Vitals Header Temp Links
---
--- @param dv string The discrete value names to link
--- @param text string The text to display in the link
--- @param seq number The sequence number for the link
--- @param predicate (fun(discrete_value: DiscreteValue): boolean) Predicate function to filter discrete values
---
--- @return CdiAlertLink - The discrete value link
--------------------------------------------------------------------------------
function AddVitalsDv(dv, text, seq, predicate)
    local link = GetDiscreteValueLinks { target=VitalsLinks, discreteValueName=dv, text=text, seq=seq, predicate=predicate }

    --- @cast link CdiAlertLink 
    return link
end

--------------------------------------------------------------------------------
--- Adds a discrete value link to the Vitals Header Temp Links
---
--- @param dv string[] The discrete value names to link
--- @param text string The text to display in the link
--- @param seq number The sequence number for the link
--- @param predicate (fun(discrete_value: DiscreteValue): boolean) Predicate function to filter discrete values
---
--- @return CdiAlertLink[] - The discrete value link
--------------------------------------------------------------------------------
function AddVitalsDvs(dv, text, seq, predicate)
    local links = GetDiscreteValueLinks { target=VitalsLinks, discreteValueNames=dv, text=text, seq=seq, predicate=predicate }

    --- @cast links CdiAlertLink[]
    return links
end

--------------------------------------------------------------------------------
--- Adds an abstraction value link to the Vitals Header Temp Links
---
--- @param code string The code to link
--- @param text string The text to display in the link
--- @param seq number The sequence number for the link
---
--- @return CdiAlertLink - The discrete value link
--------------------------------------------------------------------------------
function AddVitalsAbs(code, text, seq)
    local link = GetAbstractionValueLinks { target=VitalsLinks, code=code, text=text, seq=seq }

    --- @cast link CdiAlertLink 
    return link
end

--------------------------------------------------------------------------------
--- Adds a discrete value link to the Labs Header Temp Links
---
--- @param dv string The discrete value names to link
--- @param text string The text to display in the link
--- @param seq number The sequence number for the link
--- @param predicate (fun(discrete_value: DiscreteValue): boolean) Predicate function to filter discrete values
---
--- @return CdiAlertLink - The discrete value link
--------------------------------------------------------------------------------
function AddLabsDv(dv, text, seq, predicate)
    local link = GetDiscreteValueLinks { target=LabsLinks, discreteValueName=dv, text=text, seq=seq, predicate=predicate }

    --- @cast link CdiAlertLink 
    return link
end

--------------------------------------------------------------------------------
--- Adds a discrete value link to the Labs Header Temp Links
---
--- @param dv string[] The discrete value names to link
--- @param text string The text to display in the link
--- @param seq number The sequence number for the link
--- @param predicate (fun(discrete_value: DiscreteValue): boolean) Predicate function to filter discrete values
---
--- @return CdiAlertLink[] - The discrete value link
--------------------------------------------------------------------------------
function AddLabsDvs(dv, text, seq, predicate)
    local links = GetDiscreteValueLinks { target=LabsLinks, discreteValueNames=dv, text=text, seq=seq, predicate=predicate }

    --- @cast links CdiAlertLink[]
    return links
end

--------------------------------------------------------------------------------
--- Adds an abstraction value link to the Labs Header Temp Links
---
--- @param code string The code to link
--- @param text string The text to display in the link
--- @param seq number The sequence number for the link
---
--- @return CdiAlertLink - The abstraction value link
--------------------------------------------------------------------------------
function AddLabsAbs(code, text, seq)
    local link = GetAbstractionValueLinks { target=LabsLinks, code=code, text=text, seq=seq }

    --- @cast link CdiAlertLink 
    return link
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
    if #LabsLinks > 0 then
        LabsHeading.links = LabsLinks
        table.insert(finalLinks, LabsHeading)
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
        if header.links ~= nil and  #header.links > 0 then
            table.insert(finalLinks, header)
        end
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

