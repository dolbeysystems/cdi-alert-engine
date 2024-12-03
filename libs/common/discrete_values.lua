require("libs.common.dates")
require("libs.common.basic_links")
local cdi_alert_link = require "cdi.link"

--------------------------------------------------------------------------------
--- Make a CDI alert link from a DiscreteValue instance
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
        linkTemplate = linkTemplate .. ": [DISCRETEVALUE] (Result Date: [RESULTDATE])"
    end

    local link = cdi_alert_link()
    link.discrete_value_name = discreteValue.name
    link.link_text = ReplaceLinkPlaceHolders(linkTemplate, nil, nil, discreteValue, nil)
    link.sequence = sequence
    return link
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
--- Get all dates where any of a list of discrete values is present on an account
---
--- @param account Account The account to get the codes from
--- @param dvNames string[] The names of the discrete values to check against
---
--- @return number[] - List of dates in discrete values that are present on the account
--------------------------------------------------------------------------------
function GetDvDates(account, dvNames)
    local dvDates = {}
    for _, dvName in ipairs(dvNames) do
        for _, dv in ipairs(account:find_discrete_values(dvName)) do
            local dvDate = DateStringToInt(dv.result_date)
            -- check if table already contains the date
            local found = false
            for _, date in ipairs(dvDates) do
                if date == dvDate then
                    found = true
                    break
                end
            end
            if not found then table.insert(dvDates, dvDate) end
        end
    end

    return dvDates
end

---@class GetDiscreteValuesAsSingleLinkArgs
---@field account Account The account to get the discrete values from
---@field dvNames string[] The names of the discrete values to check against
---@field dvName string The name of the discrete value
---@field linkText string The text of the link_text
---@field target table The target table to insert the link into
--------------------------------------------------------------------------------
--- Get discrete values on an account and return a single link containing all
--- numeric values as one link 
--- 
--- @param params GetDiscreteValuesAsSingleLinkArgs a table of arguments
--- 
--- @return CdiAlertLink? - The link to the discrete values or nil if not found
--------------------------------------------------------------------------------
function GetDvValuesAsSingleLink(params)
    local account = params.account or Account
    local dvNames = params.dvNames or  { params.dvName }
    local linkText = params.linkText
    local targetTable = params.target
    local discreteValues = {}

    --- @type string
    local firstDate = nil
    --- @type string
    local lastDate = nil
    --- @type string
    local concatValues = ""
    --- @type string
    local id = nil

    for _, dvName in dvNames do
        local discreteValuesForName = account:find_discrete_values(dvName)
        for _, dv in discreteValuesForName do
            table.insert(discreteValues, dv) 
        end
    end
    table.sort(discreteValues, function(a, b)
        return DateStringToInt(a.result_date) > DateStringToInt(b.result_date)
    end)

    if #discreteValues == 0 then
        return nil
    end

    for _, dv in ipairs(discreteValues) do
        if firstDate == nil and dv.result_date then
            firstDate = dv.result_date
        end
        if dv.result_date then
            lastDate = dv.result_date
        end
        if id == nil and dv.unique_id then
            id = dv.unique_id
        end

        local cleanedValue = dv.result:gsub("[\\>\\>]", "")
        if tonumber(cleanedValue) then
            concatValues = concatValues .. cleanedValue .. ", "
        end
    end

    -- Remove final trailing , 
    if concatValues ~= "" then
        concatValues = concatValues:sub(1, -3)
    end

    if firstDate and lastDate then
        linkText = linkText:gsub("%[DATE1%]", firstDate)
        linkText = linkText:gsub("%[DATE2%]", lastDate)
        linkText = linkText .. concatValues
        local link = cdi_alert_link()
        link.discrete_value_name = dvNames[1]
        link.link_text = linkText
        link.discrete_value_id = id

        if targetTable then
            table.insert(targetTable, link)
        end
        return link
    end
end

--- @class (exact) DiscreteValuePair
--- @field first DiscreteValue The first discrete value
--- @field second DiscreteValue The second discrete value
--------------------------------------------------------------------------------
--- Gets two sets of discrete_values, and returns each item from the first set
--- paired with the nearest dated item from the second set, within a maximum time
--- difference.
--- 
--- @param account Account The account to get the discrete values from
--- @param discreteValueName1 string The name of the first discrete value 
--- @param discreteValueName2 string The name of the second discrete value
--- @param maxDiff number The maximum difference in time between the two values
--- 
--- @return DiscreteValuePair[] The pairs of discrete values that are closest to each other in time
--------------------------------------------------------------------------------
function GetDiscreteValuePairs(account, discreteValueName1, discreteValueName2, maxDiff)
    local firstValues = account:find_discrete_values(discreteValueName1)
    local pairs = {}

    for _, firstValue in ipairs(firstValues) do
        local secondValue = GetDiscreteValueNearestToDate {
            account = account,
            discreteValueName = discreteValueName2,
            date = firstValue.result_date,
            predicate = function(secondValue)
                return math.abs(DateStringToInt(firstValue.result_date) - DateStringToInt(secondValue.result_date)) <= maxDiff
            end
        }
        if secondValue then
            table.insert(pairs, { firstValue, secondValue })
        end
    end
    return pairs
end
