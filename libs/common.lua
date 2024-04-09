---------------------------------------------------------------------------------------------
--- common.lua - A library of common functions for use in cdi alert scripts
---
--- This includes functionality previously provided by AccountWorkflowContainer, and functions
--- commonly used in previous cdi alert scripts.
---
--- You can requre this file in your cdi alert scripts by adding the following line:
--- require("libs.common")
---------------------------------------------------------------------------------------------



-- This is here because of unpack having different availability based on lua version
-- (Basically, to make LSP integration happy)
if not table.unpack then
    ---@diagnostic disable-next-line: deprecated
    table.unpack = unpack
end

-- Build links for all codes in the account that match some criteria
--
-- @param args - a table of arguments
--  args.account - the account object (defaults to the global account)
--  args.codes - a list of codes to search for (not required if args.code is provided)
--  args.code - a single code to search for (not required if args.codes is provided)
--  args.linkTemplate - the template for the link
--  args.documentTypes - an optional list of document types that the code must be found in 
--  args.predicate - an optional function that takes a code reference and a document and returns true if the link should be included
--  args.single - if true, only the first link will be returned instead of a list of links
--  args.sequence - the starting sequence number to use for the links
--  args.fixed_sequence - if true, the sequence number will not be incremented for each link
function GetCodeLinks(args)
    local account = args.account or account
    local codes = args.codes or { args.code }
    local linkTemplate = args.linkTemplate or ""
    local documentTypes = args.documentTypes or {}
    local predicate = args.predicate
    local single = args.single or false
    local sequence = args.sequence or 0
    local fixed_sequence = args.fixed_sequence or false

    local links = {}

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
            local link = CdiAlertLink:new()
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
    return links
end

-- Build links for all documents in the account that match some criteria
--
-- @param args - a table of arguments
--  args.account - the account object (defaults to the global account)
--  args.documentTypes - a list of document types to search for (not required if args.documentType is provided)
--  args.documentType - a single document type to search for (not required if args.documentTypes is provided)
--  args.linkTemplate - the template for the link
--  args.predicate - an optional function that takes a code reference and a document and returns true if the link should be included
--  args.single - if true, only the first link will be returned instead of a list of links
--  args.sequence - the starting sequence number to use for the links
--  args.fixed_sequence - if true, the sequence number will not be incremented for each link
function GetDocumentLinks(args)
    local account = args.account or account
    local documentTypes = args.documentTypes or { args.documentType }
    local linkTemplate = args.linkTemplate or ""
    local predicate = args.predicate
    local single = args.single or false
    local sequence = args.sequence or 0
    local fixed_sequence = args.fixed_sequence or false

    local links = {}
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
    return links
end

-- Build links for all medications in the account that match some criteria
--
-- @param args - a table of arguments
--  args.account - the account object (defaults to the global account)
--  args.medicationCategories - a list of medication categories to search for (not required if args.medicationCategory is provided)
--  args.medicationCategory - a single medication category to search for (not required if args.medicationCategories is provided)
--  args.linkTemplate - the template for the link
--  args.predicate - an optional function that takes a code reference and a document and returns true if the link should be included
--  args.single - if true, only the first link will be returned instead of a list of links
--  args.sequence - the starting sequence number to use for the links
--  args.fixed_sequence - if true, the sequence number will not be incremented for each link
function GetMedicationLinks(args)
    local account = args.account or account
    local medicationCategories = args.medicationCategories or { args.medicationCategory }
    local linkTemplate = args.linkTemplate or ""
    local predicate = args.predicate
    local single = args.single or false
    local sequence = args.sequence or 0
    local fixed_sequence = args.fixed_sequence or false

    local links = {}
    local medications = {}

    for i = 1, #medicationCategories do
        local medicationCategory = medicationCategories[i]
        local medicationsForCategory = account:find_medication(medicationCategory)
        for j = 1, #medicationsForCategory do
            table.insert(medications, medicationsForCategory[j])
        end
    end

    for i = 1, #medications do
        if predicate ~= nil and not predicate(medications[i]) then
            goto continue
        end
        local medication = medications[i]
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
    return links
end

-- Build links for all discrete values in the account that match some criteria
--
-- @param args - a table of arguments
--  args.account - the account object (defaults to the global account)
--  args.discreteValueNames - a list of discrete value names to search for (not required if args.discreteValueName is provided)
--  args.discreteValueName - a single discrete value name to search for (not required if args.discreteValueNames is provided)
--  args.linkTemplate - the template for the link
--  args.predicate - an optional function that takes a code reference and a document and returns true if the link should be included
--  args.single - if true, only the first link will be returned instead of a list of links
--  args.sequence - the starting sequence number to use for the links
--  args.fixed_sequence - if true, the sequence number will not be incremented for each link
function GetDiscreteValueLinks(args)
    local account = args.account or account
    local discreteValueNames = args.discreteValueNames or { args.discreteValueName }
    local linkTemplate = args.linkTemplate or ""
    local predicate = args.predicate
    local single = args.single or false
    local sequence = args.sequence or 0
    local fixed_sequence = args.fixed_sequence or false

    local links = {}
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
    return links
end

-- Replace placeholders in a link template with values from the code reference, document, discrete value, or medication
--
-- @param linkTemplate - the template for the link
-- @param codeReference - the code reference to use for the link
-- @param document - the document to use for the link
-- @param discreteValue - the discrete value to use for the link
-- @param medication - the medication to use for the link
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
        link = string.gsub(link, "%[DISCRETEVALUE%]", discreteValue.value or "")
        if discreteValue.result_datetime ~= nil then
            link = string.gsub(link, "%[RESULTDATE%]", discreteValue.result_datetime or "")
        end
    end

    if medication ~= nil then
        link = string.gsub(link, "%[MEDICATIONID%]", medication.external_id or "")
        link = string.gsub(link, "%[MEDICATION%]", medication.medication or "")
        link = string.gsub(link, "%[DOSAGE%]", medication.dosage or "")
        link = string.gsub(link, "%[ROUTE%]", medication.routed or "")
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

-- Get the existing cdi alert for a script
--
-- @param args - a table of arguments
--  args.account - the account object (defaults to the global account)
--  args.scriptName - the name of the script to match
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

