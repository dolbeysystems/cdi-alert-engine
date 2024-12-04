require("libs.common.dates")
local cdi_alert_link = require "cdi.link"

---------------------------------------------------------------------------------------------
--- Abstract link args class
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
--- @field predicate (fun(code_reference: CodeReferenceWithDocument): boolean)? Predicate function to filter code references
--- @field sort(fun(l: CodeReferenceWithDocument, r: CodeReferenceWithDocument): boolean)? Sort function to sort the matched values before creating links

--------------------------------------------------------------------------------
--- Build links for all codes in the account that match some criteria
---
--- @param args GetCodeLinksArgs a table of arguments
---
--- @return CdiAlertLink[] # a list of CdiAlertLink objects or a single CdiAlertLink object
--------------------------------------------------------------------------------
function GetCodeLinks(args)
    local account = args.account or Account
    local codes = args.codes or { args.code }
    local linkTemplate = args.text or ""
    local documentTypes = args.documentTypes or {}
    local predicate = args.predicate
    local sequence = args.seq or 0
    local fixed_sequence = args.fixed_seq or false
    local maxPerValue = args.maxPerValue or 9999
    local targetTable = args.target
    local includeStandardSuffix = args.includeStandardSuffix
    local sort = args.sort or function(a, b)
        return a.code_reference.code > b.code_reference.code
    end

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
            local refPair = code_reference_pairs_for_code[j]

            if predicate == nil or predicate(refPair) then
                table.insert(code_reference_pairs, refPair)
                if maxPerValue and #code_reference_pairs >= maxPerValue then
                    break
                end
            end
        end
    end

    table.sort(code_reference_pairs, sort)

    for i = 1, #code_reference_pairs do
        local ref = code_reference_pairs[i]
        local code_reference = ref.code_reference
        local document = ref.document

        if documentTypes == nil or #documentTypes == 0 then
            --- @type CdiAlertLink
            local link = cdi_alert_link()
            link.code = code_reference.code
            link.document_id = document.document_id
            link.link_text = ReplaceLinkPlaceHolders(linkTemplate or "", code_reference, document, nil, nil)
            link.sequence = sequence
            table.insert(links, link)
            if not fixed_sequence then
                sequence = sequence + 1
            end
        else
            for j = 1, #documentTypes do
                if documentTypes[j] == document.document_type then
                    local link = cdi_alert_link()
                    link.code = code_reference.code
                    link.document_id = document.document_id
                    link.link_text = ReplaceLinkPlaceHolders(linkTemplate, code_reference, document, nil, nil)
                    link.sequence = sequence
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
    end

    if targetTable then
        for i = 1, #links do
            table.insert(targetTable, links[i])
        end
    end

    return links
end

--------------------------------------------------------------------------------
--- Builds a single link for a code on the account that matches some criteria
--- 
--- @param args GetCodeLinksArgs a table of arguments
--- 
--- @return CdiAlertLink? # the link to the first code or nil if not found
-------------------------------------------------------------------------------- 
function GetCodeLink(args)
    args.maxPerValue = 1
    local links = GetCodeLinks(args)
    if #links > 0 then
        return links[1]
    else
        return nil
    end
end

--------------------------------------------------------------------------------
--- Build links for all abstractions in the account that match some criteria
--- without including the value of the abstraction
---
--- @param args GetCodeLinksArgs a table of arguments
---
--- @return CdiAlertLink[] # a list of CdiAlertLink objects or a single CdiAlertLink object
--------------------------------------------------------------------------------
function GetAbstractionLinks(args)
    if args.includeStandardSuffix == nil or args.includeStandardSuffix then
        args.includeStandardSuffix = false
        args.text = args.text .. " '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])"
    end
    return GetCodeLinks(args)
end

--------------------------------------------------------------------------------
--- Builds a single link for an abstraction on the account that matches some criteria
--- without including the value of the abstraction
--- 
--- @param args GetCodeLinksArgs a table of arguments
--- 
--- @return CdiAlertLink? # the link to the first abstraction or nil if not found
-----------------------------------------------------------------------------
function GetAbstractionLink(args)
    args.maxPerValue = 1
    local links = GetAbstractionLinks(args)
    if #links > 0 then
        return links[1]
    else
        return nil
    end
end

--------------------------------------------------------------------------------
--- Build links for all codes in the account that match some criteria with the
--- value of the abstraction included
---
--- @param args GetCodeLinksArgs a table of arguments
---
--- @return CdiAlertLink[] # a list of CdiAlertLink objects or a single CdiAlertLink object
--------------------------------------------------------------------------------
function GetAbstractionValueLinks(args)
    if args.includeStandardSuffix == nil or args.includeStandardSuffix then
        args.includeStandardSuffix = false
        args.text = args.text .. ": [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])"
    end
    return GetCodeLinks(args)
end

--------------------------------------------------------------------------------
--- Builds a single link for an abstraction on the account that matches some criteria
--- with the value of the abstraction included
--- 
--- @param args GetCodeLinksArgs a table of arguments
--- 
--- @return CdiAlertLink? # the link to the first abstraction or nil if not found
--------------------------------------------------------------------------------
function GetAbstractionValueLink(args)
    args.maxPerValue = 1
    local links = GetAbstractionValueLinks(args)
    if #links > 0 then
        return links[1]
    else
        return nil
    end
end

--- @class (exact) GetDocumentLinksArgs : LinkArgs
--- @field documentTypes string[]? List of document types to search for
--- @field documentType string? Single document type to search for
--- @field predicate (fun(document: CACDocument): boolean)? Predicate function to filter documents
--- @field sort(fun(l: CACDocument, r: CACDocument): boolean)? Sort function to sort the matched values before creating links

--------------------------------------------------------------------------------
--- Build links for all documents in the account that match some criteria
---
--- @param args GetDocumentLinksArgs a table of arguments
---
--- @return CdiAlertLink[] # a list of CdiAlertLink objects or a single CdiAlertLink object
--------------------------------------------------------------------------------
function GetDocumentLinks(args)
    local account = args.account or Account
    local documentTypes = args.documentTypes or { args.documentType }
    local linkTemplate = args.text or ""
    local predicate = args.predicate
    local sequence = args.seq or 0
    local fixed_sequence = args.fixed_seq or false
    local maxPerValue = args.maxPerValue or 9999
    local targetTable = args.target
    local includeStandardSuffix = args.includeStandardSuffix
    local sort = args.sort or function(a, b)
        return DateStringToInt(a.document_date) > DateStringToInt(b.document_date)
    end

    if includeStandardSuffix == nil or includeStandardSuffix then
        linkTemplate = linkTemplate .. " ([DOCUMENTTYPE], [DOCUMENTDATE])"
    end

    --- @type CdiAlertLink[]
    local links = {}
    --- @type CACDocument[]
    local documents = {}

    for i = 1, #documentTypes do
        local documentType = documentTypes[i]
        local documentsForType = account:find_documents(documentType)
        for j = 1, #documentsForType do
            if predicate == nil or predicate(documents[i]) then
                table.insert(documents, documentsForType[j])
                if maxPerValue and #documents >= maxPerValue then
                    break
                end
            end
        end
    end

    table.sort(documents, sort)

    for i = 1, #documents do
        local document = documents[i]
        local link = cdi_alert_link()
        link.document_id = document.document_id
        link.link_text = ReplaceLinkPlaceHolders(linkTemplate, nil, document, nil, nil)
        link.sequence = sequence
        table.insert(links, link)
        if not fixed_sequence then
            sequence = sequence + 1
        end
    end
    if targetTable then
        for i = 1, #links do
            table.insert(targetTable, links[i])
        end
    end
    return links
end

--------------------------------------------------------------------------------
--- Builds a single link for a document on the account that matches some criteria
--- 
--- @param args GetDocumentLinksArgs a table of arguments
--- 
--- @return CdiAlertLink? # the link to the first document or nil if not found
--------------------------------------------------------------------------------
function GetDocumentLink(args)
    args.maxPerValue = 1
    local links = GetDocumentLinks(args)
    if #links > 0 then
        return links[1]
    else
        return nil
    end
end

--- @class (exact) GetMedicationLinksArgs : LinkArgs
--- @field cats string[]? List of medication categories to search for
--- @field cat string? Single medication category to search for
--- @field predicate (fun(medication: Medication): boolean)? Predicate function to filter medications
--- @field sort(fun(l: Medication, r: Medication): boolean)? Sort function to sort the matched values before creating links
--- @field useCdiAlertCategoryField boolean? If true, use the cdi_alert_category field to search for medications instead of the category field
--- @field onePerDate boolean? If true, only one link will be created per date

--------------------------------------------------------------------------------
--- Build links for all medications in the account that match some criteria
---
--- @param args GetMedicationLinksArgs table of arguments
---
--- @return CdiAlertLink[] # a list of CdiAlertLink objects or a single CdiAlertLink object
--------------------------------------------------------------------------------
function GetMedicationLinks(args)
    local account = args.account or Account
    local medicationCategories = args.cats or { args.cat }
    local linkTemplate = args.text or ""
    local predicate = args.predicate
    local sequence = args.seq or 0
    local fixed_sequence = args.fixed_seq or false
    local maxPerValue = args.maxPerValue or 9999
    local targetTable = args.target
    local includeStandardSuffix = args.includeStandardSuffix
    local useCdiAlertCategoryField = args.useCdiAlertCategoryField or false
    local onePerDate = args.onePerDate or false
    local sort = args.sort or function(a, b)
        return DateStringToInt(a.start_date) > DateStringToInt(b.start_date)
    end

    if includeStandardSuffix == nil or includeStandardSuffix then
        linkTemplate = linkTemplate .. ": [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])"
    end

    --- @type CdiAlertLink[]
    local links = {}
    --- @type Medication[]
    local medications = {}

    for i = 1, #medicationCategories do
        local medicationCategory = medicationCategories[i]
        local medicationsForCategory = {}

        if useCdiAlertCategoryField then
            for _, med in ipairs(account.medications) do
                if med.cdi_alert_category == medicationCategory then
                    table.insert(medications, med)
                end
            end
        else
            medicationsForCategory = account:find_medications(medicationCategory)
        end

        if onePerDate then
            local uniqueDates = {}
            local uniqueMedications = {}
            for j = 1, #medicationsForCategory do
                local medication = medicationsForCategory[j]
                if not uniqueDates[medication.start_date] then
                    uniqueDates[medication.start_date] = true
                    table.insert(uniqueMedications, medication)
                end
            end
            medicationsForCategory = uniqueMedications
        end

        for j = 1, #medicationsForCategory do
            if predicate == nil or predicate(medicationsForCategory[j]) then
                table.insert(medications, medicationsForCategory[j])
                if maxPerValue and #medications >= maxPerValue then
                    break
                end
            end
        end
    end

    table.sort(medications, sort)
    for i = 1, #medications do
        local medication   = medications[i]
        local link         = cdi_alert_link()
        link.medication_id = medication.external_id
        link.link_text     = ReplaceLinkPlaceHolders(linkTemplate, nil, nil, nil, medication)
        link.sequence      = sequence
        table.insert(links, link)
        if not fixed_sequence then
            sequence = sequence + 1
        end
    end
    if targetTable then
        for i = 1, #links do
            table.insert(targetTable, links[i])
        end
    end
    return links
end

--------------------------------------------------------------------------------
--- Builds a single link for a medication on the account that matches some criteria
--- 
--- @param args GetMedicationLinksArgs a table of arguments
--- 
--- @return CdiAlertLink? # the link to the first medication or nil if not found
--------------------------------------------------------------------------------
function GetMedicationLink(args)
    args.maxPerValue = 1
    local links = GetMedicationLinks(args)
    if #links > 0 then
        return links[1]
    else
        return nil
    end
end

--- @class (exact) GetDiscreteValueLinksArgs : LinkArgs
--- @field discreteValueNames string[]? List of discrete value names to search for
--- @field discreteValueName string? Single discrete value name to search for
--- @field predicate (fun(discrete_value: DiscreteValue): boolean)? Predicate function to filter discrete values
--- @field sort(fun(l: DiscreteValue, r: DiscreteValue): boolean)? Sort function to sort the matched values before creating links

--------------------------------------------------------------------------------
--- Build links for all discrete values in the account that match some criteria
---
--- @param args GetDiscreteValueLinksArgs table of arguments
---
--- @return CdiAlertLink[] # a list of CdiAlertLink objects or a single CdiAlertLink object
--------------------------------------------------------------------------------
function GetDiscreteValueLinks(args)
    local account = args.account or Account
    local discreteValueNames = args.discreteValueNames or { args.discreteValueName }
    local linkTemplate = args.text or ""
    local predicate = args.predicate
    local sequence = args.seq or 0
    local fixed_sequence = args.fixed_seq or false
    local maxPerValue = args.maxPerValue or 9999
    local targetTable = args.target
    local includeStandardSuffix = args.includeStandardSuffix
    local sort = args.sort or function(a, b)
        return DateStringToInt(a.result_date) > DateStringToInt(b.result_date)
    end

    if includeStandardSuffix == nil or includeStandardSuffix then
        linkTemplate = linkTemplate .. ": [DISCRETEVALUE] (Result Date: [RESULTDATE])"
    end

    --- @type CdiAlertLink[]
    local links = {}
    --- @type DiscreteValue[]
    local discrete_values = {}

    for i = 1, #discreteValueNames do
        local discreteValueName = discreteValueNames[i]
        local discreteValuesForName = account:find_discrete_values(discreteValueName)
        for j = 1, #discreteValuesForName do
            if predicate == nil or predicate(discreteValuesForName[j]) then
                table.insert(discrete_values, discreteValuesForName[j])

                if maxPerValue and #discrete_values >= maxPerValue then
                    break
                end
            end
        end
    end

    table.sort(discrete_values, sort)

    for i = 1, #discrete_values do
        local discrete_value = discrete_values[i]
        local link = cdi_alert_link()
        link.discrete_value_name = discrete_value.name
        link.discrete_value_id = discrete_value.id
        link.link_text = ReplaceLinkPlaceHolders(linkTemplate, nil, nil, discrete_value, nil)
        link.sequence = sequence
        table.insert(links, link)
        if not fixed_sequence then
            sequence = sequence + 1
        end
    end
    if targetTable then
        for i = 1, #links do
            table.insert(targetTable, links[i])
        end
    end
    return links
end

--------------------------------------------------------------------------------
--- Builds a single link for a discrete value on the account that matches some criteria
--- 
--- @param args GetDiscreteValueLinksArgs a table of arguments
--- 
--- @return CdiAlertLink? # the link to the first discrete value or nil if not found
--------------------------------------------------------------------------------
function GetDiscreteValueLink(args)
    args.maxPerValue = 1
    local links = GetDiscreteValueLinks(args)
    if #links > 0 then
        return links[1]
    else
        return nil
    end
end

--------------------------------------------------------------------------------
--- Replace placeholders in a link template with values from the code reference,
--- document, discrete value, or medication
---
--- @param linkTemplate string the template for the link
--- @param codeReference CodeReference? the code reference to use for the link
--- @param document CACDocument? the document to use for the link
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
    local link = cdi_alert_link()
    link.link_text = headerText
    link.is_validated = true
    return link
end

--------------------------------------------------------------------------------
--- Merge links with old links
---
--- @param oldLinks CdiAlertLink[] The existing alert
--- @param newLinks CdiAlertLink[] The links to merge
---
--- @return CdiAlertLink[] - The merged links
--------------------------------------------------------------------------------
function MergeLinks(oldLinks, newLinks)
    --- @type CdiAlertLink[]
    local mergedLinks = {}

    --- @type fun(a: CdiAlertLink, b: CdiAlertLink): boolean
    local comparison_fn = function(_, _) return false end

    if #oldLinks == 0 then
        return newLinks
    elseif #newLinks == 0 then
        return oldLinks
    else
        for _, oldLink in ipairs(oldLinks) do
            if oldLink.code then
                comparison_fn = function(a, b) return a.code == b.code end
            elseif oldLink.medication_name then
                comparison_fn = function(a, b) return a.medication_name == b.medication_name end
            elseif oldLink.discrete_value_name then
                comparison_fn = function(a, b) return a.discrete_value_name == b.discrete_value_name end
            elseif oldLink.discrete_value_id then
                comparison_fn = function(a, b) return a.discrete_value_id == b.discrete_value_id end
            else
                comparison_fn = function(a, b) return a.link_text == b.link_text end
            end

            for _, newLink in ipairs(newLinks) do
                if comparison_fn(oldLink, newLink) then
                    oldLink.is_validated = newLink.is_validated
                    oldLink.sequence = newLink.sequence
                    oldLink.hidden = newLink.hidden
                    oldLink.link_text = newLink.link_text
                    oldLink.links = MergeLinks(oldLink.links, newLink.links)
                    table.insert(mergedLinks, newLink)
                end
            end
        end
        return mergedLinks
    end
end