function Hello()
	info("Hello, world!")
end


function GetCodeLinks(account, code, linkTemplate, documentTypes)
    account.find_code_references(code) .filter(function(ref_pair)
        for i = 1, documentTypes do
            if documentTypes[i] == ref_pair.document.document_type then
                return true
            end
        end
    end).map(function(ref_pair)
        local codeReference = ref_pair.code_reference
        local document = ref_pair.document

        local link = CdiAlertLink:new()
        link.code = codeReference.code
        link.document_id = document.document_id
        link.link_text = ReplaceLinkPlaceHolders(linkTemplate, codeReference, document, nil, nil)
        return link
    end)
end


function ReplaceLinkPlaceHolders(linkTemplate, codeReference, document, discreteValue, medication)
    local link = linkTemplate
    if document ~= nil then
        link = link.replace("[DOCUMENTID]", document.document_id)
        link = link.replace("[DOCUMENTDATE]", document.document_date)
        link = link.replace("[DOCUMENTTYPE]", document.document_type)
    end

    if codeReference ~= nil then
        link = link.replace("[CODE]", codeReference.code)
        link = link.replace("[ABSTRACTVALUE]", codeReference.value)
        link = link.replace("[PHRASE]", codeReference.phrase)
    end

    if discreteValue ~= nil then
        link = link.replace("[DISCRETEVALUENAME]", discreteValue.name)
        link = link.replace("[DISCRETEVALUE]", discreteValue.value)
        if discreteValue.result_datetime ~= nil then
            link = link.replace("[RESULTDATE]", discreteValue.result_datetime.to_string())
        end
    end

    if medication ~= nil then
        link = link.replace("[MEDICATIONID]", medication.external_id)
        link = link.replace("[MEDICATION]", medication.medication)
        link = link.replace("[DOSAGE]", medication.dosage)
        link = link.replace("[ROUTE]", medication.routed)
        if medication.start_date ~= nil then
            link = link.replace("[STARTDATE]", medication.start_date.to_string())
        end
        link = link.replace("[STATUS]", medication.status)
        link = link.replace("[CATEGORY]", medication.category)
    end

    if discreteValue ~= nil and discreteValue.result ~= nil then
        link = link.replace("[VALUE]", discreteValue.result)
    elseif codeReference ~= nil and codeReference.result ~= nil then
        link = link.replace("[VALUE]", codeReference.result)
    end
    return link
end

