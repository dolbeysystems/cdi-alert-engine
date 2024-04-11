---------------------------------------------------------------------------------------------
--- common.lua - A library of common functions for use in cdi alert scripts
---
--- This includes functionality previously provided by AccountWorkflowContainer, and functions
--- commonly used in previous cdi alert scripts.
---
--- You can requre this file in your cdi alert scripts by adding the following line:
--- require("libs.common")
---------------------------------------------------------------------------------------------



---------------------------------------------------------------------------------------------
--- Requires
---------------------------------------------------------------------------------------------
require("userdata_types")



---------------------------------------------------------------------------------------------
--- Lua LS Type Definitions
---------------------------------------------------------------------------------------------
--- @class LinkArgs
--- @field account Account? Account object (uses global account if not provided)
--- @field linkTemplate string Link template
--- @field single boolean? If true, only the first link will be returned instead of a list of links
--- @field sequence number? Starting sequence number to use for the links
--- @field fixed_sequence boolean? If true, the sequence number will not be incremented for each link

--- @class GetCodeLinksArgs : LinkArgs
--- @field codes string[]? List of codes to search for 
--- @field code string? Single code to search for
--- @field documentTypes string[]? List of document types that the code must be found in
--- @field predicate (fun(code_reference: CodeReference, document: Document): boolean)? Predicate function to filter code references

--- @class GetDocumentLinksArgs : LinkArgs
--- @field documentTypes string[]? List of document types to search for
--- @field documentType string? Single document type to search for
--- @field predicate (fun(document: Document): boolean)? Predicate function to filter documents

--- @class GetMedicationLinksArgs : LinkArgs
--- @field medicationCategories string[]? List of medication categories to search for
--- @field medicationCategory string? Single medication category to search for
--- @field predicate (fun(medication: Medication): boolean)? Predicate function to filter medications

--- @class GetDiscreteValueLinksArgs : LinkArgs
--- @field discreteValueNames string[]? List of discrete value names to search for
--- @field discreteValueName string? Single discrete value name to search for
--- @field predicate (fun(discrete_value: DiscreteValue): boolean)? Predicate function to filter discrete values

--- @class GetExistingCdiAlertArgs
--- @field account Account? Account object (uses global account if not provided)
--- @field scriptName string The name of the script to match



--------------------------------------------------------------------------------
--- Global setup/configuration
--------------------------------------------------------------------------------
-- This is here because of unpack having different availability based on lua version
-- (Basically, to make LSP integration happy)
if not table.unpack then
    --- @diagnostic disable-next-line: deprecated
    table.unpack = unpack
end



--------------------------------------------------------------------------------
--- Build links for all codes in the account that match some criteria
---
--- @param args GetCodeLinksArgs a table of arguments
---
--- @return (CdiAlertLink | CdiAlertLink[] | nil) # a list of CdiAlertLink objects or a single CdiAlertLink object
--------------------------------------------------------------------------------
function GetCodeLinks(args)
    local account = args.account or account
    local codes = args.codes or { args.code }
    local linkTemplate = args.linkTemplate or ""
    local documentTypes = args.documentTypes or {}
    local predicate = args.predicate
    local single = args.single or false
    local sequence = args.sequence or 0
    local fixed_sequence = args.fixed_sequence or false

     --- @type CdiAlertLink[]
    local links = {}

    --- @type CodeReferenceWithDocument[]
    local code_reference_pairs = {}
    for i = 1, #codes do
        local code = codes[i]
        local code_reference_pairs_for_code = account:find_code_references(code)
        for j = 1, #code_reference_pairs_for_code do
            table.insert(code_reference_pairs, code_reference_pairs_for_code[j])
        end
    end

    for i = 1, #code_reference_pairs do
        local ref = code_reference_pairs[i]
        local code_reference = ref.code_reference
        local document = ref.document

        if predicate ~= nil and not predicate(code_reference, document) then
            goto continue
        end

        if documentTypes == nil or #documentTypes == 0 then
            --- @type CdiAlertLink
            local link = CdiAlertLink:new()
            link.code = code_reference.code
            link.document_id = document.document_id
            link.link_text = ReplaceLinkPlaceHolders(linkTemplate or "", code_reference, document, nil, nil)
            link.sequence = sequence
            if single then
                return link
            end
            table.insert(links, link)
            if not fixed_sequence then
                sequence = sequence + 1
            end
        else
            for j = 1, #documentTypes do
                if documentTypes[j] == document.document_type then
                    local link = CdiAlertLink:new()
                    link.code = code_reference.code
                    link.document_id = document.document_id
                    link.link_text = ReplaceLinkPlaceHolders(linkTemplate, code_reference, document, nil, nil)
                    link.sequence = sequence
                    if single then
                        return link
                    end
                    table.insert(links, link)
                    if not fixed_sequence then
                        sequence = sequence + 1
                    end
                end
            end
        end
        ::continue::
    end

    if single then
        return nil
    else
        return links
    end
end

--------------------------------------------------------------------------------
--- Build links for all documents in the account that match some criteria
---
--- @param args GetDocumentLinksArgs a table of arguments
---
--- @return (CdiAlertLink | CdiAlertLink[] | nil) # a list of CdiAlertLink objects or a single CdiAlertLink object
--------------------------------------------------------------------------------
function GetDocumentLinks(args)
    local account = args.account or account
    local documentTypes = args.documentTypes or { args.documentType }
    local linkTemplate = args.linkTemplate or ""
    local predicate = args.predicate
    local single = args.single or false
    local sequence = args.sequence or 0
    local fixed_sequence = args.fixed_sequence or false

    --- @type CdiAlertLink[]
    local links = {}
    --- @type Document[]
    local documents = {}

    for i = 1, #documentTypes do
        local documentType = documentTypes[i]
        local documentsForType = account:find_documents(documentType)
        for j = 1, #documentsForType do
            table.insert(documents, documentsForType[j])
        end
    end

    for i = 1, #documents do
        if predicate ~= nil and not predicate(documents[i]) then
            goto continue
        end
        local document = documents[i]
        --- @type CdiAlertLink
        local link = CdiAlertLink:new()
        link.document_id = document.document_id
        link.link_text = ReplaceLinkPlaceHolders(linkTemplate, nil, document, nil, nil)
        link.sequence = sequence
        if single then
            return link
        end
        table.insert(links, link)
        if not fixed_sequence then
            sequence = sequence + 1
        end
        ::continue::
    end
    if single then
        return nil
    else
        return links
    end
end

--------------------------------------------------------------------------------
--- Build links for all medications in the account that match some criteria
---
--- @param args GetMedicationLinksArgs table of arguments
---
--- @return (CdiAlertLink | CdiAlertLink[] | nil) # a list of CdiAlertLink objects or a single CdiAlertLink object
--------------------------------------------------------------------------------
function GetMedicationLinks(args)
    local account = args.account or account
    local medicationCategories = args.medicationCategories or { args.medicationCategory }
    local linkTemplate = args.linkTemplate or ""
    local predicate = args.predicate
    local single = args.single or false
    local sequence = args.sequence or 0
    local fixed_sequence = args.fixed_sequence or false

    --- @type CdiAlertLink[]
    local links = {}
    --- @type Medication[]
    local medications = {}

    for i = 1, #medicationCategories do
        local medicationCategory = medicationCategories[i]
        local medicationsForCategory = account:find_medications(medicationCategory)
        for j = 1, #medicationsForCategory do
            table.insert(medications, medicationsForCategory[j])
        end
    end

    for i = 1, #medications do
        if predicate ~= nil and not predicate(medications[i]) then
            goto continue
        end
        local medication = medications[i]
        --- @type CdiAlertLink
        local link = CdiAlertLink:new()
        link.medication_id  = medication.external_id
        link.link_text = ReplaceLinkPlaceHolders(linkTemplate, nil, nil, nil, medication)
        link.sequence = sequence
        if single then
            return link
        end
        table.insert(links, link)
        if not fixed_sequence then
            sequence = sequence + 1
        end
        ::continue::
    end
    if single then
        return nil
    else
        return links
    end
end

--------------------------------------------------------------------------------
--- Build links for all discrete values in the account that match some criteria
---
--- @param args GetDiscreteValueLinksArgs table of arguments
---
--- @return (CdiAlertLink | CdiAlertLink[] | nil) # a list of CdiAlertLink objects or a single CdiAlertLink object
--------------------------------------------------------------------------------
function GetDiscreteValueLinks(args)
    local account = args.account or account
    local discreteValueNames = args.discreteValueNames or { args.discreteValueName }
    local linkTemplate = args.linkTemplate or ""
    local predicate = args.predicate
    local single = args.single or false
    local sequence = args.sequence or 0
    local fixed_sequence = args.fixed_sequence or false

     --- @type CdiAlertLink[]
    local links = {}
    --- @type DiscreteValue[]
    local discrete_values = {}

    for i = 1, #discreteValueNames do
        local discreteValueName = discreteValueNames[i]
        local discreteValuesForName = account:find_discrete_values(discreteValueName)
        for j = 1, #discreteValuesForName do
            table.insert(discrete_values, discreteValuesForName[j])
        end
    end

    for i = 1, #discrete_values do
        if predicate ~= nil and not predicate(discrete_values[i]) then
            goto continue
        end
        local discrete_value = discrete_values[i]
        --- @type CdiAlertLink
        local link = CdiAlertLink:new()
        link.discrete_value_name = discrete_value.name
        link.link_text = ReplaceLinkPlaceHolders(linkTemplate, nil, nil, discrete_value, nil)
        link.sequence = sequence
        if single then
            return link
        end
        table.insert(links, link)
        if not fixed_sequence then
            sequence = sequence + 1
        end
        ::continue::
    end
    if single then
        return nil
    else
        return links
    end
end

--------------------------------------------------------------------------------
--- Replace placeholders in a link template with values from the code reference,
--- document, discrete value, or medication
---
--- @param linkTemplate string the template for the link
--- @param codeReference CodeReference? the code reference to use for the link
--- @param document Document? the document to use for the link
--- @param discreteValue DiscreteValue? the discrete value to use for the link
--- @param medication Medication? the medication to use for the link
---
--- @return string # the link with placeholders replaced
--------------------------------------------------------------------------------
function ReplaceLinkPlaceHolders(linkTemplate, codeReference, document, discreteValue, medication)
    local link = linkTemplate

    if codeReference ~= nil then
        link = string.gsub(link, "%[CODE%]", codeReference.code or "")
        link = string.gsub(link, "%[ABSTRACTVALUE%]", codeReference.value or "")
        link = string.gsub(link, "%[PHRASE%]", codeReference.phrase or "")
    end

    if document ~= nil then
        link = string.gsub(link, "%[DOCUMENTID%]", document.document_id or "")
        link = string.gsub(link, "%[DOCUMENTDATE%]", document.document_date or "")
        link = string.gsub(link, "%[DOCUMENTTYPE%]", document.document_type or "")
    end


    if discreteValue ~= nil then
        link = string.gsub(link, "%[DISCRETEVALUENAME%]", discreteValue.name or "")
        link = string.gsub(link, "%[DISCRETEVALUE%]", discreteValue.result or "")
        if discreteValue.result_date ~= nil then
            link = string.gsub(link, "%[RESULTDATE%]", discreteValue.result_date or "")
        end
    end

    if medication ~= nil then
        link = string.gsub(link, "%[MEDICATIONID%]", medication.external_id or "")
        link = string.gsub(link, "%[MEDICATION%]", medication.medication or "")
        link = string.gsub(link, "%[DOSAGE%]", medication.dosage or "")
        link = string.gsub(link, "%[ROUTE%]", medication.route or "")
        if medication.start_date ~= nil then
            link = string.gsub(link, "%[STARTDATE%]", medication.start_date or "")
        end
        link = string.gsub(link, "%[STATUS%]", medication.status or "")
        link = string.gsub(link, "%[CATEGORY%]", medication.category or "")
    end

    if discreteValue ~= nil and discreteValue.result ~= nil then
        link = string.gsub(link, "%[VALUE%]", discreteValue.result or "")
    elseif codeReference ~= nil and codeReference.value ~= nil then
        link = string.gsub(link, "%[VALUE%]", codeReference.value or "")
    end

    return link
end

--------------------------------------------------------------------------------
--- Get the existing cdi alert for a script
---
--- @param args GetExistingCdiAlertArgs a table of arguments
---
--- @return CdiAlert? # the existing cdi alert or nil if not found
--------------------------------------------------------------------------------
function GetExistingCdiAlert(args)
    local account = args.account or account
    local scriptName = args.scriptName

    for i = 1, #account.cdi_alerts do
        local alert = account.cdi_alerts[i]
        if alert.script_name == scriptName then
            return alert
        end
    end
    return nil
end

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
function MakeCodeLink(targetTable, code, linkPrefix, sequence)
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
function MakeAbstractionLink(targetTable, code, linkPrefix, sequence)
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
function MakeAbstractionValueLink(targetTable, code, linkPrefix, sequence)
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
function MakeMedicationLink(targetTable, medication, linkPrefix, sequence)
    local linkTemplate = linkPrefix .. ": [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])"
    local link =
        GetMedicationLinks { medication = medication, linkTemplate = linkTemplate, single = true, sequence = sequence }

    if link ~= nil and targetTable ~= nil then
        table.insert(targetTable, link)
    end
    return link
end
