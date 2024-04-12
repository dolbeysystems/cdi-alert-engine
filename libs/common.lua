---------------------------------------------------------------------------------------------
--- common.lua - A library of common functions for use in all alert scripts
---------------------------------------------------------------------------------------------



---------------------------------------------------------------------------------------------
--- Requires
---------------------------------------------------------------------------------------------
require("libs.userdata_types")



---------------------------------------------------------------------------------------------
--- Lua LS Type Definitions
---------------------------------------------------------------------------------------------
--- @class (exact) LinkArgs
--- @field account Account? Account object (uses global account if not provided)
--- @field text string Link template
--- @field maxPerValue number? The maximum number of links to create for each matched value (default 1)
--- @field seq number? Starting sequence number to use for the links
--- @field fixed_seq boolean? If true, the sequence number will not be incremented for each link
--- @field target CdiAlertLink[]? The table to add the link to
--- @field includeStandardSuffix boolean? If true, the standard suffix will be appended to the link text

--- @class (exact) GetCodeLinksArgs : LinkArgs
--- @field codes string[]? List of codes to search for 
--- @field code string? Single code to search for
--- @field documentTypes string[]? List of document types that the code must be found in
--- @field predicate (fun(code_reference: CodeReference, document: Document): boolean)? Predicate function to filter code references

--- @class (exact) GetDocumentLinksArgs : LinkArgs
--- @field documentTypes string[]? List of document types to search for
--- @field documentType string? Single document type to search for
--- @field predicate (fun(document: Document): boolean)? Predicate function to filter documents

--- @class (exact) GetMedicationLinksArgs : LinkArgs
--- @field cats string[]? List of medication categories to search for
--- @field cat string? Single medication category to search for
--- @field predicate (fun(medication: Medication): boolean)? Predicate function to filter medications

--- @class (exact) GetDiscreteValueLinksArgs : LinkArgs
--- @field discreteValueNames string[]? List of discrete value names to search for
--- @field discreteValueName string? Single discrete value name to search for
--- @field predicate (fun(discrete_value: DiscreteValue): boolean)? Predicate function to filter discrete values

--- @class (exact) GetExistingCdiAlertArgs
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
--- Build links for all abstractions in the account that match some criteria
--- without including the value of the abstraction
---
--- @param args GetCodeLinksArgs a table of arguments
---
--- @return (CdiAlertLink | CdiAlertLink[] | nil) # a list of CdiAlertLink objects or a single CdiAlertLink object
--------------------------------------------------------------------------------
function GetAbstractionLinks(args)
    if args.includeStandardSuffix == nil or args.includeStandardSuffix then
        args.includeStandardSuffix = false
        args.text = args.text .. " '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])"
    end
    return GetCodeLinks(args)
end

--------------------------------------------------------------------------------
--- Build links for all codes in the account that match some criteria with the
--- value of the abstraction included
---
--- @param args GetCodeLinksArgs a table of arguments
---
--- @return (CdiAlertLink | CdiAlertLink[] | nil) # a list of CdiAlertLink objects or a single CdiAlertLink object
--------------------------------------------------------------------------------
function GetAbstractionValueLinks(args)
    if args.includeStandardSuffix == nil or args.includeStandardSuffix then
        args.includeStandardSuffix = false
        args.text = args.text ..  ": [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])"
    end
    return GetCodeLinks(args)
end

--------------------------------------------------------------------------------
--- Build links for all codes in the account that match some criteria
---
--- @param args GetCodeLinksArgs a table of arguments
---
--- @return (CdiAlertLink | CdiAlertLink[] | nil) # a list of CdiAlertLink objects or a single CdiAlertLink object
--------------------------------------------------------------------------------
function GetCodeLinks(args)
    local account = args.account or Account
    local codes = args.codes or { args.code }
    local linkTemplate = args.text or ""
    local documentTypes = args.documentTypes or {}
    local predicate = args.predicate
    local sequence = args.seq or 0
    local fixed_sequence = args.fixed_seq or false
    local maxPerValue = args.maxPerValue or 1
    local targetTable = args.target
    local includeStandardSuffix = args.includeStandardSuffix
    local onlyOne = args.code and not args.codes and maxPerValue == 1

    if includeStandardSuffix == nil or includeStandardSuffix then
        linkTemplate = linkTemplate .. ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])"
    end

     --- @type CdiAlertLink[]
    local links = {}

    --- @type CodeReferenceWithDocument[]
    local code_reference_pairs = {}
    for i = 1, #codes do
        local code = codes[i]
        local code_reference_pairs_for_code = account:find_code_references(code)
        for j = 1, #code_reference_pairs_for_code do
            table.insert(code_reference_pairs, code_reference_pairs_for_code[j])
            if maxPerValue and #code_reference_pairs >= maxPerValue then
                break
            end
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
            if onlyOne then
                if targetTable then
                    table.insert(targetTable, link)
                end
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
                    if onlyOne then
                        if targetTable then
                            table.insert(targetTable, link)
                        end
                        return link
                    end
                    table.insert(links, link)
                    if maxPerValue and #links >= maxPerValue then
                        break
                    end
                    if not fixed_sequence then
                        sequence = sequence + 1
                    end
                end
            end
        end
        ::continue::
    end

    if targetTable then
        for i = 1, #links do
            table.insert(targetTable, links[i])
        end
    end

    if onlyOne then
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
    local account = args.account or Account
    local documentTypes = args.documentTypes or { args.documentType }
    local linkTemplate = args.text or ""
    local predicate = args.predicate
    local sequence = args.seq or 0
    local fixed_sequence = args.fixed_seq or false
    local maxPerValue = args.maxPerValue or 1
    local targetTable = args.target
    local includeStandardSuffix = args.includeStandardSuffix
    local onlyOne = args.documentType and not args.documentTypes and maxPerValue == 1

    if includeStandardSuffix == nil or includeStandardSuffix then
        linkTemplate = linkTemplate .. " ([DOCUMENTTYPE], [DOCUMENTDATE])"
    end

    --- @type CdiAlertLink[]
    local links = {}
    --- @type Document[]
    local documents = {}

    for i = 1, #documentTypes do
        local documentType = documentTypes[i]
        local documentsForType = account:find_documents(documentType)
        for j = 1, #documentsForType do
            table.insert(documents, documentsForType[j])
            if maxPerValue and #documents >= maxPerValue then
                break
            end
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
        if onlyOne then
            if targetTable then
                table.insert(targetTable, link)
            end
            return link
        end
        table.insert(links, link)
        if not fixed_sequence then
            sequence = sequence + 1
        end
        ::continue::
    end
    if targetTable then
        for i = 1, #links do
            table.insert(targetTable, links[i])
        end
    end
    if onlyOne then
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
    local account = args.account or Account
    local medicationCategories = args.cats or { args.cat }
    local linkTemplate = args.text or ""
    local predicate = args.predicate
    local sequence = args.seq or 0
    local fixed_sequence = args.fixed_seq or false
    local maxPerValue = args.maxPerValue or 1
    local targetTable = args.target
    local includeStandardSuffix = args.includeStandardSuffix
    local onlyOne = args.cat and not args.cats and maxPerValue == 1

    if includeStandardSuffix == nil or includeStandardSuffix then
        linkTemplate = linkTemplate ..  ": [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])"
    end

    --- @type CdiAlertLink[]
    local links = {}
    --- @type Medication[]
    local medications = {}

    for i = 1, #medicationCategories do
        local medicationCategory = medicationCategories[i]
        local medicationsForCategory = account:find_medications(medicationCategory)
        for j = 1, #medicationsForCategory do
            table.insert(medications, medicationsForCategory[j])
            if maxPerValue and #medications >= maxPerValue then
                break
            end
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
        if onlyOne then
            if targetTable then
                table.insert(targetTable, link)
            end
            return link
        end
        table.insert(links, link)
        if not fixed_sequence then
            sequence = sequence + 1
        end
        ::continue::
    end
    if targetTable then
        for i = 1, #links do
            table.insert(targetTable, links[i])
        end
    end
    if onlyOne then
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
    local account = args.account or Account
    local discreteValueNames = args.discreteValueNames or { args.discreteValueName }
    local linkTemplate = args.text or ""
    local predicate = args.predicate
    local sequence = args.seq or 0
    local fixed_sequence = args.fixed_seq or false
    local maxPerValue = args.maxPerValue
    local targetTable = args.target
    local includeStandardSuffix = args.includeStandardSuffix
    local onlyOne = args.discreteValueName and not args.discreteValueNames and maxPerValue == 1

    if includeStandardSuffix == nil or includeStandardSuffix then
        linkTemplate = linkTemplate ..  ": [DISCRETEVALUE] (Result Date: [RESULTDATE])"
    end

     --- @type CdiAlertLink[]
    local links = {}
    --- @type DiscreteValue[]
    local discrete_values = {}

    for i = 1, #discreteValueNames do
        local discreteValueName = discreteValueNames[i]
        local discreteValuesForName = account:find_discrete_values(discreteValueName)
        for j = 1, #discreteValuesForName do
            table.insert(discrete_values, discreteValuesForName[j])
            if maxPerValue and #discrete_values >= maxPerValue then
                break
            end
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
        if onlyOne then
            if targetTable then
                table.insert(targetTable, link)
            end
            return link
        end
        table.insert(links, link)
        if not fixed_sequence then
            sequence = sequence + 1
        end
        ::continue::
    end
    if targetTable then
        for i = 1, #links do
            table.insert(targetTable, links[i])
        end
    end
    if onlyOne then
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
--- Create a link to a header
---
--- @param headerText string The text of the header
---
--- @return CdiAlertLink - the link to the header
--------------------------------------------------------------------------------
function MakeHeaderLink(headerText)
    local link = CdiAlertLink:new()
    link.link_text = headerText
    return link
end

--------------------------------------------------------------------------------
--- Create a nil link (here for quick type hinting)
---
--- @return CdiAlertLink? - Always nil, but typed
--------------------------------------------------------------------------------
function MakeNilLink()
    return nil
end

--------------------------------------------------------------------------------
--- Create an empty array of links (here for quick type hinting)
---
--- @return CdiAlertLink[] - An empty array of links
--------------------------------------------------------------------------------
function MakeLinkArray()
    return {}
end

--------------------------------------------------------------------------------
--- Get the existing cdi alert for a script
---
--- @param args GetExistingCdiAlertArgs a table of arguments
---
--- @return CdiAlert? - the existing cdi alert or nil if not found
--------------------------------------------------------------------------------
function GetExistingCdiAlert(args)
    local account = args.account or Account
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

