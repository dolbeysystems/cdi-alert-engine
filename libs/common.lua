-- This is here because of unpack having different availability based on lua version
-- (Basically, to make LSP integration happy)
if not table.unpack then
    ---@diagnostic disable-next-line: deprecated
    table.unpack = unpack
end


function GetCodeLinksForCode(args)
    local account = args.account or account
    local code = args.code
    local linkTemplate = args.linkTemplate or ""
    local documentTypes = args.documentTypes or {}
    local predicate = args.predicate

    local links = {}
    local code_reference_pairs = account:find_code_references(code)

    for i = 1, #code_reference_pairs do
        local ref = code_reference_pairs[i]
        local code_reference = ref.code_reference
        local document = ref.document

        if predicate ~= nil and not predicate(code_reference, document) then
            goto continue
        end

        if documentTypes == nil or #documentTypes == 0 then
            info("No document types specified, returning all code references")
            local link = CdiAlertLink:new()
            link.code = code_reference.code
            link.document_id = document.document_id
            link.link_text = ReplaceLinkPlaceHolders(linkTemplate or "", code_reference, document, nil, nil)
            table.insert(links, link)
        else
            info("Document types specified, filtering code references")
            for j = 1, #documentTypes do
                if documentTypes[j] == document.document_type then
                    local link = CdiAlertLink:new()
                    link.code = code_reference.code
                    link.document_id = document.document_id
                    link.link_text = ReplaceLinkPlaceHolders(linkTemplate, code_reference, document, nil, nil)
                    table.insert(links, link)
                end
            end
        end
        ::continue::
    end
    return links
end

function GetDocumentLinksForDocumentType(args)
    local account = args.account or account
    local documentType = args.documentType
    local linkTemplate = args.linkTemplate or ""
    local predicate = args.predicate

    local links = {}
    local documents = account:find_documents(documentType)

    for i = 1, #documents do
        if predicate ~= nil and not predicate(documents[i]) then
            goto continue
        end
        local document = documents[i]
        local link = CdiAlertLink:new()
        link.document_id = document.document_id
        link.link_text = ReplaceLinkPlaceHolders(linkTemplate, nil, document, nil, nil)
        table.insert(links, link)
        ::continue::
    end
    return links
end

function GetMedicationLinksForMedicationCategory(args)
    local account = args.account or account
    local medicationCategory = args.medicationCategory
    local linkTemplate = args.linkTemplate or ""
    local predicate = args.predicate

    local links = {}
    local medications = account:find_medication(medicationCategory)

    for i = 1, #medications do
        if predicate ~= nil and not predicate(medications[i]) then
            goto continue
        end
        local medication = medications[i]
        local link = CdiAlertLink:new()
        link.medication_id  = medication.external_id
        link.link_text = ReplaceLinkPlaceHolders(linkTemplate, nil, nil, nil, medication)
        table.insert(links, link)
        ::continue::
    end
    return links
end

function GetDiscreteValueLinksForDiscreteValueName(args)
    local account = args.account or account
    local discreteValueName = args.discreteValueName
    local linkTemplate = args.linkTemplate or ""
    local predicate = args.predicate

    local links = {}
    local discrete_values = account:find_discrete_values(discreteValueName)

    for i = 1, #discrete_values do
        if predicate ~= nil and not predicate(discrete_values[i]) then
            goto continue
        end
        local discrete_value = discrete_values[i]
        local link = CdiAlertLink:new()
        link.discrete_value_name = discrete_value.name
        link.link_text = ReplaceLinkPlaceHolders(linkTemplate, nil, nil, discrete_value, nil)
        table.insert(links, link)
        ::continue::
    end
    return links
end


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

