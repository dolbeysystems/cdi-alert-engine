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
--- @field predicate (fun(code_reference: CodeReferenceWithDocument): boolean)? Predicate function to filter code references
--- @field sort(fun(l: CodeReferenceWithDocument, r: CodeReferenceWithDocument): boolean)? Sort function to sort the matched values before creating links

--- @class (exact) GetDocumentLinksArgs : LinkArgs
--- @field documentTypes string[]? List of document types to search for
--- @field documentType string? Single document type to search for
--- @field predicate (fun(document: CACDocument): boolean)? Predicate function to filter documents
--- @field sort(fun(l: CACDocument, r: CACDocument): boolean)? Sort function to sort the matched values before creating links

--- @class (exact) GetMedicationLinksArgs : LinkArgs
--- @field cats string[]? List of medication categories to search for
--- @field cat string? Single medication category to search for
--- @field predicate (fun(medication: Medication): boolean)? Predicate function to filter medications
--- @field sort(fun(l: Medication, r: Medication): boolean)? Sort function to sort the matched values before creating links
--- @field useCdiAlertCategoryField boolean? If true, use the cdi_alert_category field to search for medications instead of the category field
--- @field onePerDate boolean? If true, only one link will be created per date

--- @class (exact) GetDiscreteValueLinksArgs : LinkArgs
--- @field discreteValueNames string[]? List of discrete value names to search for
--- @field discreteValueName string? Single discrete value name to search for
--- @field predicate (fun(discrete_value: DiscreteValue): boolean)? Predicate function to filter discrete values
--- @field sort(fun(l: DiscreteValue, r: DiscreteValue): boolean)? Sort function to sort the matched values before creating links

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
    local sort = args.sort or function(a, b)
        return a.document_date > b.document_date
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
    local useCdiAlertCategoryField = args.useCdiAlertCategoryField or false
    local onePerDate = args.onePerDate or false
    local sort = args.sort or function(a, b)
        return DateStringToInt(a.start_date) > DateStringToInt(b.start_date)
    end

    if includeStandardSuffix == nil or includeStandardSuffix then
        linkTemplate = linkTemplate ..  ": [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])"
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
    local sort = args.sort or function(a, b)
        return a.result_date > b.result_date
    end

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
--- Create a nmil array of links (here for quick type hinting)
---
--- @return CdiAlertLink[]? - An empty array of links
----------------{}----------------------------------------------------------------
function MakeNilLinkArray()
    return nil
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
--- Convert a date string to an integer 
---
--- @param dateString string The date string to convert
---
--- @return number - the date as an integer
--------------------------------------------------------------------------------
function DateStringToInt(dateString)
    local pattern = "(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)"
    local year, month, day, hour, min, sec, _ = dateString:match(pattern)
    return os.time({year=year, month=month, day=day, hour=hour, min=min, sec=sec})
end

--------------------------------------------------------------------------------
--- Check if a date is less than a certain number of days ago
---
--- @param dateString string The date string to check
--- @param days number The number of days to check against
---
--- @return boolean - true if the date is less than the number of days ago, false otherwise
--------------------------------------------------------------------------------
function DateIsLessThanXDaysAgo(dateString, days)
    local date = DateStringToInt(dateString)

    --- @diagnostic disable-next-line: param-type-mismatch
    local nowUtc = os.time(os.date("!*t"))
    local daysInSeconds = days * 24 * 60 * 60
    return nowUtc - date < daysInSeconds
end

--------------------------------------------------------------------------------
--- Check if a date is less than a certain number of minutes ago
---
--- @param dateString string The date string to check
--- @param minutes number The number of minutes to check against
---
--- @return boolean - true if the date is less than the number of minutes ago, false otherwise
--------------------------------------------------------------------------------
function DateIsLessThanXMinutesAgo(dateString, minutes)
    local date = DateStringToInt(dateString)

    local nowUtcStr = os.date("!*t")
    --- @diagnostic disable-next-line: param-type-mismatch
    local nowUtc = os.time(nowUtcStr)

    local minutesInSeconds = minutes * 60
    return nowUtc - date < minutesInSeconds
end

--------------------------------------------------------------------------------
--- Get the value of a discrete value as a number
---
--- @param discreteValue DiscreteValue The discrete value to get the value from
---
--- @return number? - the value of the discrete value as a number or nil if not found
--------------------------------------------------------------------------------
function GetDvValueNumber(discreteValue)
    local number = discreteValue.result
    if number == nil then
        return nil
    end
    number = string.gsub(number, "[<>]", "")
    return tonumber(number)
end

--------------------------------------------------------------------------------
--- Check if a discrete value matches a predicate
---
--- @param discreteValue DiscreteValue The discrete value to check
--- @param predicate fun(number):boolean The predicate to check the result against
---
--- @return boolean - true if the date is less than the number of hours ago, false otherwise
--------------------------------------------------------------------------------
function CheckDvResultNumber(discreteValue, predicate)
    local result = GetDvValueNumber(discreteValue)
    if result == nil then
        return false
    else
        return predicate(result)
    end
end

--- @class (exact) GetOrderedDiscreteValuesArgs 
--- @field account Account? Account object (uses global account if not provided) 
--- @field discreteValueName string The name of the discrete value to search for
--- @field daysBack number? The number of days back to search for discrete values (default 7)
--- @field predicate (fun(discrete_value: DiscreteValue):boolean)? Predicate function to filter discrete values

--------------------------------------------------------------------------------
--- Get all discrete values in the account that match some criteria and are ordered by date
---
--- @param args GetOrderedDiscreteValuesArgs a table of arguments
---
--- @return DiscreteValue[] - a list of DiscreteValue objects
--------------------------------------------------------------------------------
function GetOrderedDiscreteValues(args)
    local account = args.account or Account
    local discreteValueName = args.discreteValueName
    local daysBack = args.daysBack or 7
    local predicate = args.predicate
    -- @type DiscreteValue[]
    local discreteValues = {}

    local discreteValuesForName = account:find_discrete_values(discreteValueName)
    for i = 1, #discreteValuesForName do
        if DateIsLessThanXDaysAgo(discreteValuesForName[i].result_date, daysBack) and (predicate == nil or predicate(discreteValuesForName[i])) then
            table.insert(discreteValues, discreteValuesForName[i])
        end
    end

    table.sort(discreteValues, function(a, b)
        return a.result_date < b.result_date
    end)
    return discreteValues
end

--------------------------------------------------------------------------------
--- Get the highest discrete value in the account that matches some criteria 
---
--- @param args GetOrderedDiscreteValuesArgs a table of arguments
---
--- @return DiscreteValue? - The highest discrete value or nil if not found
--------------------------------------------------------------------------------
function GetHighestDiscreteValue(args)
    local discreteValues = GetOrderedDiscreteValues(args)
    if #discreteValues == 0 then
        return nil
    end
    local highest = discreteValues[1]
    local highestValue = GetDvValueNumber(highest)
    for i = 2, #discreteValues do
        if CheckDvResultNumber(discreteValues[i], function(v) return v > highestValue end) then
            highest = discreteValues[i]
            highestValue = GetDvValueNumber(highest)
        end
    end
    return highest
end

--------------------------------------------------------------------------------
--- Get the lowest discrete value in the account that matches some criteria
---
--- @param args GetOrderedDiscreteValuesArgs a table of arguments
---
--- @return DiscreteValue? - The lowest discrete value or nil if not found
--------------------------------------------------------------------------------
function GetLowestDiscreteValue(args)
    local discreteValues = GetOrderedDiscreteValues(args)
    if #discreteValues == 0 then
        return nil
    end
    local lowest = discreteValues[1]
    local lowestValue = GetDvValueNumber(lowest)
    for i = 2, #discreteValues do
        if CheckDvResultNumber(discreteValues[i], function(v) return v < lowestValue end) then
            lowest = discreteValues[i]
            lowestValue = GetDvValueNumber(lowest)
        end
    end
    return lowest
end



--- @class (exact) GetDiscreteValueNearestToDateArgs
--- @field account Account? Account object (uses global account if not provided) 
--- @field discreteValueName string The name of the discrete value to search for
--- @field date string The date to search for the nearest discrete value to
--- @field predicate (fun(discrete_value: DiscreteValue):boolean)? Predicate function to filter discrete values

--------------------------------------------------------------------------------
--- Get the discrete value nearest to a date
---
--- @param args GetDiscreteValueNearestToDateArgs a table of arguments
---
--- @return DiscreteValue? - the nearest discrete value or nil if not found
--------------------------------------------------------------------------------
function GetDiscreteValueNearestToDate(args)
    --- @type Account
    local account = args.account or Account
    local discreteValueName = args.discreteValueName
    local dateString = args.date
    local predicate = args.predicate

    local date = DateStringToInt(dateString)

    local discreteValuesForName = account:find_discrete_values(discreteValueName)
    --- @type DiscreteValue?
    local nearest = nil
    local nearestDiff = math.huge
    for i = 1, #discreteValuesForName do
        local discreteValueDate = DateStringToInt(discreteValuesForName[i].result_date)

        local diff = math.abs(os.difftime(date, discreteValueDate))
        if diff < nearestDiff and (predicate == nil or predicate(discreteValuesForName[i])) then
            nearest = discreteValuesForName[i]
            nearestDiff = diff
        end
    end
    return nearest
end

--- @class (exact) GetDiscreteValueNearestAfterDateArgs
--- @field account Account? Account object (uses global account if not provided) 
--- @field discreteValueName string The name of the discrete value to search for
--- @field date string The date to search for the nearest discrete value to
--- @field predicate (fun(discrete_value: DiscreteValue):boolean)? Predicate function to filter discrete values

--------------------------------------------------------------------------------
--- Get the next nearest discrete value to a date
---
--- @param args GetDiscreteValueNearestAfterDateArgs a table of arguments
---
--- @return DiscreteValue? - the nearest discrete value or nil if not found
--------------------------------------------------------------------------------
function GetDiscreteValueNearestAfterDate(args)
    --- @type Account
    local account = args.account or Account
    local discreteValueName = args.discreteValueName
    local dateString = args.date
    local predicate = args.predicate

    local date = DateStringToInt(dateString)

    local discreteValuesForName = account:find_discrete_values(discreteValueName)
    --- @type DiscreteValue?
    local nearest = nil
    local nearestDiff = math.huge
    for i = 1, #discreteValuesForName do
        local discreteValueDate = DateStringToInt(discreteValuesForName[i].result_date)

        if discreteValueDate > date and discreteValueDate - date < nearestDiff and (predicate == nil or predicate(discreteValuesForName[i])) then
            nearest = discreteValuesForName[i]
            nearestDiff = discreteValueDate - date
        end
    end
    return nearest
end

--- @class (exact) GetDiscreteValueNearestBeforeDateArgs
--- @field account Account? Account object (uses global account if not provided) 
--- @field discreteValueName string The name of the discrete value to search for
--- @field date string The date to search for the nearest discrete value to
--- @field predicate (fun(discrete_value: DiscreteValue):boolean)? Predicate function to filter discrete values

--------------------------------------------------------------------------------
--- Get the previous nearest discrete value to a date
---
--- @param args GetDiscreteValueNearestBeforeDateArgs a table of arguments
---
--- @return DiscreteValue? - the nearest discrete value or nil if not found
--------------------------------------------------------------------------------
function GetDiscreteValueNearestBeforeDate(args)
    --- @type Account
    local account = args.account or Account
    local discreteValueName = args.discreteValueName
    local dateString = args.date
    local predicate = args.predicate

    local date = DateStringToInt(dateString)

    local discreteValuesForName = account:find_discrete_values(discreteValueName)
    --- @type DiscreteValue?
    local nearest = nil
    local nearestDiff = math.huge
    for i = 1, #discreteValuesForName do
        local discreteValueDate = DateStringToInt(discreteValuesForName[i].result_date)

        if discreteValueDate < date and date - discreteValueDate < nearestDiff and (predicate == nil or predicate(discreteValuesForName[i])) then
            nearest = discreteValuesForName[i]
            nearestDiff = date - discreteValueDate
        end
    end
    return nearest
end

--------------------------------------------------------------------------------
--- Make a CDI alert link for a discrete value
---
--- @param discreteValue DiscreteValue The discrete value to create a link for
--- @param linkTemplate string The template for the link
--- @param sequence number The sequence number for the link
--- @param includeStandardSuffix boolean? If true, the standard suffix will be appended to the link text
---
--- @return CdiAlertLink - the link to the discrete value
--------------------------------------------------------------------------------
function GetLinkForDiscreteValue(discreteValue, linkTemplate, sequence, includeStandardSuffix)
    if includeStandardSuffix == nil or includeStandardSuffix then
        linkTemplate = linkTemplate ..  ": [DISCRETEVALUE] (Result Date: [RESULTDATE])"
    end

    local link = CdiAlertLink:new()
    link.discrete_value_name = discreteValue.name
    link.link_text = ReplaceLinkPlaceHolders(linkTemplate, nil, nil, discreteValue, nil)
    link.sequence = sequence
    return link
end


--------------------------------------------------------------------------------
--- Get account codes matching a prefix
---
--- @param prefix string The prefix to search for
---
--- @return string[] - a list of codes that match the prefix
--------------------------------------------------------------------------------
function GetAccountCodesByPrefix(prefix)
    --- @type Account
    local account = Account
    local codes = {}
    for _, code in ipairs(account:get_unique_code_references()) do
        if code:sub(1, #prefix) == prefix then
            table.insert(codes, code)
        end
    end
    return codes
end

--------------------------------------------------------------------------------
--- Get the first code link for a prefix
---
--- @param arguments table The arguments for the link
---
--- @return CdiAlertLink? - the link to the first code or nil if not found
--------------------------------------------------------------------------------
function GetFirstCodePrefixLink(arguments)
    local codes = GetAccountCodesByPrefix(arguments.prefix)
    if #codes == 0 then
        return nil
    end
    arguments.code = codes[1]
    local links = GetCodeLinks(arguments)
    if type(links) == "table" then
        return links[1]
    else
        return links
    end
end

--------------------------------------------------------------------------------
--- Get all code links for a prefix
---
--- @param arguments table The arguments for the link
---
--- @return CdiAlertLink[]? - a list of links to the codes or nil if not found
--------------------------------------------------------------------------------
function GetAllCodePrefixLinks(arguments)
    local codes = GetAccountCodesByPrefix(arguments.prefix)
    if #codes == 0 then
        return nil
    end
    arguments.codes = codes
    return GetCodeLinks(arguments)
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
        --- @type CACDocument
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

