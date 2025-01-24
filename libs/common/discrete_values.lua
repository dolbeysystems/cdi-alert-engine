---@diagnostic disable-next-line:name-style-check
return function(Account)
    local module = {}
    local links = require "libs.common.basic_links" (Account)
    local lists = require "libs.common.lists"
    local cdi_alert_link = require "cdi.link"

    --------------------------------------------------------------------------------
    --- Make a CDI alert link from a DiscreteValue instance
    ---
    --- @param discrete_value DiscreteValue The discrete value to create a link for
    --- @param link_template string The template for the link
    --- @param sequence number The sequence number for the link
    --- @param include_standard_suffix boolean? If true, the standard suffix will be appended to the link text
    ---
    --- @return CdiAlertLink - the link to the discrete value
    --------------------------------------------------------------------------------
    function module.get_link_for_discrete_value(discrete_value, link_template, sequence, include_standard_suffix)
        if include_standard_suffix == nil or include_standard_suffix then
            link_template = link_template .. ": [DISCRETEVALUE] (Result Date: [RESULTDATE])"
        end

        local link = cdi_alert_link()
        link.discrete_value_name = discrete_value.name
        link.link_text = links.replace_link_place_holders(link_template, nil, nil, discrete_value, nil)
        link.sequence = sequence
        return link
    end

    --------------------------------------------------------------------------------
    --- Get the value of a discrete value as a number
    ---
    --- @param discrete_value DiscreteValue The discrete value to get the value from
    ---
    --- @return number? - the value of the discrete value as a number or nil if not found
    --------------------------------------------------------------------------------
    function module.get_dv_value_number(discrete_value)
        local number = discrete_value.result
        if number == nil then
            return nil
        end
        number = string.gsub(number, "[<>]", "")
        return tonumber(number)
    end

    --------------------------------------------------------------------------------
    --- Check if a discrete value matches a predicate
    ---
    --- @param discrete_value DiscreteValue The discrete value to check
    --- @param predicate (fun(discrete_value: DiscreteValue, num: number?):boolean)? Predicate function to filter discrete values
    ---
    --- @return boolean - true if the date is less than the number of hours ago, false otherwise
    --------------------------------------------------------------------------------
    function module.check_dv_result_number(discrete_value, predicate)
        local result = module.get_dv_value_number(discrete_value)
        if result == nil then
            return false
        else
            if predicate == nil then
                return true
            else
                return predicate(discrete_value, result)
            end
        end
    end

    --- @class (exact) GetOrderedDiscreteValuesArgs
    --- @field account Account? Account object (uses global account if not provided)
    --- @field discreteValueName? string The name of the discrete value to search for
    --- @field discreteValueNames? string[] The names of the discrete values to search for
    --- @field daysBack number? The number of days back to search for discrete values (default 7)
    --- @field predicate (fun(discrete_value: DiscreteValue, num: number?):boolean)? Predicate function to filter discrete values

    --------------------------------------------------------------------------------
    --- Get all discrete values in the account that match some criteria and are ordered by date
    ---
    --- @param args GetOrderedDiscreteValuesArgs a table of arguments
    ---
    --- @return DiscreteValue[] - a list of DiscreteValue objects
    --------------------------------------------------------------------------------
    function module.get_ordered_discrete_values(args)
        local account = args.account or Account
        local discrete_value_names = args.discreteValueNames or { args.discreteValueName }
        local days_back = args.daysBack or 7
        local predicate = args.predicate
        --- @type DiscreteValue[]
        local discrete_values = {}

        for _, dv_name in ipairs(discrete_value_names) do
            local discrete_values_for_name = account:find_discrete_values(dv_name)
            for i = 1, #discrete_values_for_name do
                local dv = discrete_values_for_name[i]
                local result_as_number =
                    dv.result and
                    tonumber(string.gsub(dv.result, "[<>]", "")) or
                    nil
                if module.DateIsLessThanXDaysAgo(discrete_values_for_name[i].result_date, days_back) and (predicate == nil or predicate(dv, result_as_number)) then
                    table.insert(discrete_values, discrete_values_for_name[i])
                end
            end
        end

        table.sort(discrete_values, function(a, b)
            return a.result_date < b.result_date
        end)
        return discrete_values
    end

    --------------------------------------------------------------------------------
    --- Get the highest discrete value in the account that matches some criteria
    ---
    --- @param args GetOrderedDiscreteValuesArgs a table of arguments
    ---
    --- @return DiscreteValue? - The highest discrete value or nil if not found
    --------------------------------------------------------------------------------
    function module.get_highest_discrete_value(args)
        local discrete_values = module.get_ordered_discrete_values(args)
        if #discrete_values == 0 then
            return nil
        end
        local highest = discrete_values[1]
        local highest_value = module.get_dv_value_number(highest)
        for i = 2, #discrete_values do
            if module.check_dv_result_number(discrete_values[i], function(v) return v > highest_value end) then
                highest = discrete_values[i]
                highest_value = module.get_dv_value_number(highest)
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
    function module.get_lowest_discrete_value(args)
        local discrete_values = module.get_ordered_discrete_values(args)
        if #discrete_values == 0 then
            return nil
        end
        local lowest = discrete_values[1]
        local lowest_value = module.get_dv_value_number(lowest)
        for i = 2, #discrete_values do
            if module.check_dv_result_number(discrete_values[i], function(v) return v < lowest_value end) then
                lowest = discrete_values[i]
                lowest_value = module.get_dv_value_number(lowest)
            end
        end
        return lowest
    end

    --- @class (exact) GetDiscreteValueNearestToDateArgs
    --- @field account Account? Account object (uses global account if not provided)
    --- @field discreteValueName? string The name of the discrete value to search for
    --- @field discreteValueNames? string[] The names of the discrete values to search for
    --- @field date integer The date to search for the nearest discrete value to
    --- @field predicate (fun(discrete_value: DiscreteValue, num: number?):boolean)? Predicate function to filter discrete values

    --------------------------------------------------------------------------------
    --- Get the discrete value nearest to a date
    ---
    --- @param args GetDiscreteValueNearestToDateArgs a table of arguments
    ---
    --- @return DiscreteValue? - the nearest discrete value or nil if not found
    --------------------------------------------------------------------------------
    function module.get_discrete_value_nearest_to_date(args)
        --- @type Account
        local account = args.account or Account
        local discrete_value_names = args.discreteValueNames or { args.discreteValueName }
        local date = args.date
        local predicate = args.predicate

        --- @type DiscreteValue[]
        local discrete_values_for_name = {}
        for _, dv_name in ipairs(discrete_value_names) do
            for _, dv in ipairs(account:find_discrete_values(dv_name)) do
                table.insert(discrete_values_for_name, dv)
            end
        end

        --- @type DiscreteValue?
        local nearest = nil
        local nearest_diff = math.huge
        for i = 1, #discrete_values_for_name do
            local diff = math.abs(date - discrete_values_for_name[i].result_date)
            local result_as_number =
                discrete_values_for_name[i].result and
                tonumber(string.gsub(discrete_values_for_name[i].result, "[<>]", "")) or
                nil
            if diff < nearest_diff and (predicate == nil or predicate(discrete_values_for_name[i], result_as_number)) then
                nearest = discrete_values_for_name[i]
                nearest_diff = diff
            end
        end
        return nearest
    end

    --- @class (exact) GetDiscreteValueNearestAfterDateArgs
    --- @field account Account? Account object (uses global account if not provided)
    --- @field discreteValueName string The name of the discrete value to search for
    --- @field date integer The date to search for the nearest discrete value to
    --- @field predicate (fun(discrete_value: DiscreteValue, num: number?):boolean)? Predicate function to filter discrete values

    --------------------------------------------------------------------------------
    --- Get the next nearest discrete value to a date
    ---
    --- @param args GetDiscreteValueNearestAfterDateArgs a table of arguments
    ---
    --- @return DiscreteValue? - the nearest discrete value or nil if not found
    --------------------------------------------------------------------------------
    function module.get_discrete_value_nearest_after_date(args)
        --- @type Account
        local account = args.account or Account
        local discrete_value_name = args.discreteValueName
        local date = args.date
        local predicate = args.predicate

        local discrete_values_for_name = account:find_discrete_values(discrete_value_name)
        --- @type DiscreteValue?
        local nearest = nil
        local nearest_diff = math.huge
        for i = 1, #discrete_values_for_name do
            local discrete_value_date = discrete_values_for_name[i].result_date
            local result_as_number =
                discrete_values_for_name[i].result and
                tonumber(string.gsub(discrete_values_for_name[i].result, "[<>]", "")) or
                nil

            if discrete_value_date > date and discrete_value_date - date < nearest_diff and (predicate == nil or predicate(discrete_values_for_name[i], result_as_number)) then
                nearest = discrete_values_for_name[i]
                nearest_diff = discrete_value_date - date
            end
        end
        return nearest
    end

    --- @class (exact) GetDiscreteValueNearestBeforeDateArgs
    --- @field account Account? Account object (uses global account if not provided)
    --- @field discreteValueName string The name of the discrete value to search for
    --- @field date string The date to search for the nearest discrete value to
    --- @field predicate (fun(discrete_value: DiscreteValue, num: number?):boolean)? Predicate function to filter discrete values

    --------------------------------------------------------------------------------
    --- Get the previous nearest discrete value to a date
    ---
    --- @param args GetDiscreteValueNearestBeforeDateArgs a table of arguments
    ---
    --- @return DiscreteValue? # the nearest discrete value or nil if not found
    --------------------------------------------------------------------------------
    function module.get_discrete_value_nearest_before_date(args)
        --- @type Account
        local account = args.account or Account
        local discrete_value_name = args.discreteValueName
        local date = args.date
        local predicate = args.predicate

        local discrete_values_for_name = account:find_discrete_values(discrete_value_name)
        --- @type DiscreteValue?
        local nearest = nil
        local nearest_diff = math.huge
        for i = 1, #discrete_values_for_name do
            local discrete_value_date = discrete_values_for_name[i].result_date
            local result_as_number =
                discrete_values_for_name[i].result and
                tonumber(string.gsub(discrete_values_for_name[i].result, "[<>]", "")) or
                nil

            if discrete_value_date < date and date - discrete_value_date < nearest_diff and (predicate == nil or predicate(discrete_values_for_name[i], result_as_number)) then
                nearest = discrete_values_for_name[i]
                nearest_diff = date - discrete_value_date
            end
        end
        return nearest
    end

    --------------------------------------------------------------------------------
    --- Get all dates where any of a list of discrete values is present on an account
    ---
    --- @param account Account The account to get the codes from
    --- @param dv_names string[] The names of the discrete values to check against
    ---
    --- @return number[] # List of dates in discrete values that are present on the account
    --------------------------------------------------------------------------------
    function module.get_dv_dates(account, dv_names)
        --- @type number[]
        local dv_dates = {}
        for _, dv_name in ipairs(dv_names) do
            for _, dv in ipairs(account:find_discrete_values(dv_name)) do
                -- check if table already contains the date
                local found = false
                for _, date in ipairs(dv_dates) do
                    if date == dv.result_date then
                        found = true
                        break
                    end
                end
                if not found then table.insert(dv_dates, dv.result_date) end
            end
        end

        return dv_dates
    end

    ---@class GetDiscreteValuesAsSingleLinkArgs
    ---@field account Account? The account to get the discrete values from
    ---@field dvNames string[]? The names of the discrete values to check against
    ---@field dvName string? The name of the discrete value
    ---@field linkText string? The text of the link_text
    --------------------------------------------------------------------------------
    --- Get discrete values on an account and return a single link containing all
    --- numeric values as one link
    ---
    --- @param params GetDiscreteValuesAsSingleLinkArgs a table of arguments
    ---
    --- @return CdiAlertLink? # The link to the discrete values or nil if not found
    --------------------------------------------------------------------------------
    function module.get_dv_values_as_single_link(params)
        local account = params.account or Account
        local dv_names = params.dvNames or { params.dvName }
        local link_text = params.linkText or ""
        --- @type DiscreteValue[]
        local discrete_values = {}

        --- @type integer?
        local first_date = nil
        --- @type integer?
        local last_date = nil
        --- @type string
        local concat_values = ""
        --- @type string
        local id = nil

        for _, dv_name in ipairs(dv_names) do
            local discrete_values_for_name = account:find_discrete_values(dv_name)
            for _, dv in ipairs(discrete_values_for_name) do
                table.insert(discrete_values, dv)
            end
        end
        table.sort(discrete_values, function(a, b)
            return a.result_date > b.result_date
        end)

        if #discrete_values == 0 then
            return nil
        end

        for _, dv in ipairs(discrete_values) do
            if first_date == nil and dv.result_date then
                first_date = dv.result_date
            end
            if dv.result_date then
                last_date = dv.result_date
            end
            if id == nil and dv.unique_id then
                id = dv.unique_id
            end

            local cleaned_value = dv.result:gsub("[\\>\\>]", "")
            if tonumber(cleaned_value) then
                concat_values = concat_values .. cleaned_value .. ", "
            end
        end

        -- Remove final trailing ,
        if concat_values ~= "" then
            --- @type string
            concat_values = concat_values:sub(1, -3)
        end

        if first_date and last_date then
            link_text = link_text:gsub("%[DATE1%]", first_date)
            link_text = link_text:gsub("%[DATE2%]", last_date)
            link_text = link_text .. concat_values
            local link = cdi_alert_link()
            link.discrete_value_name = dv_names[1]
            link.link_text = link_text
            link.discrete_value_id = id

            return link
        end
    end

    --- @class (exact) DiscreteValuePair
    --- @field first DiscreteValue The first discrete value
    --- @field second DiscreteValue The second discrete value

    --- @class (exact) CdiAlertLinkPair
    --- @field first CdiAlertLink The first link
    --- @field second CdiAlertLink The second link

    --- @class (exact) GetDiscreteValuePairsArgs
    --- @field account Account? The account to get the discrete values from
    --- @field discreteValueNames1 string[]? The names of the first discrete value
    --- @field discreteValueNames2 string[]? The names of the second discrete value
    --- @field discreteValueName1 string? The name of the first discrete value
    --- @field discreteValueName2 string? The name of the second discrete value
    --- @field maxDiff number? The maximum difference in time between the two values
    --- @field predicate1 (fun(discrete_value: DiscreteValue, num: number?):boolean)? Predicate function to filter the first discrete values
    --- @field predicate2 (fun(discrete_value: DiscreteValue, num: number?):boolean)? Predicate function to filter the second discrete values
    --- @field joinPredicate (fun(first: DiscreteValue, second: DiscreteValue, first_num: number?, second_num: number?):boolean)? Predicate function to filter the pairs
    --- @field max number? The maximum number of pairs to return

    --------------------------------------------------------------------------------
    --- Gets two sets of discrete_values, and returns each item from the first set
    --- paired with the nearest dated item from the second set, within a maximum time
    --- difference.
    ---
    --- @param args GetDiscreteValuePairsArgs a table of arguments
    ---
    --- @return DiscreteValuePair[] # The pairs of discrete values that are closest to each other in time
    --------------------------------------------------------------------------------
    function module.get_discrete_value_pairs(args)
        local account = args.account or Account
        local discrete_value_names1 = args.discreteValueNames1 or { args.discreteValueName1 }
        local discrete_value_names2 = args.discreteValueNames2 or { args.discreteValueName2 }
        local max_diff = args.maxDiff or 0
        local predicate1 = args.predicate1 or function() return true end
        local predicate2 = args.predicate2 or function() return true end
        local join_predicate = args.joinPredicate or function() return true end
        local max = args.max

        --- @type DiscreteValue[]
        local first_values_unfiltered = {}
        for _, dv_name in ipairs(discrete_value_names1) do
            for _, dv in ipairs(account:find_discrete_values(dv_name)) do
                table.insert(first_values_unfiltered, dv)
            end
        end

        --- @type DiscreteValue[]
        local first_values = {}
        for _, dv in ipairs(first_values_unfiltered) do
            local result_as_number = module.get_dv_value_number(dv)
            if predicate1(dv, result_as_number) then
                table.insert(first_values, dv)
            end
        end

        local pairs = {}

        for _, first_value in ipairs(first_values) do
            local first_num = module.get_dv_value_number(first_value)
            local second_value = module.get_discrete_value_nearest_to_date {
                account = account,
                discreteValueNames = discrete_value_names2,
                date = first_value.result_date,
                predicate = function(second_value, second_num)
                    return (
                            math.abs(first_value.result_date - second_value.result_date) <= max_diff
                        ) and predicate2(second_value, second_num) and
                        join_predicate(first_value, second_value, first_num, second_num)
                end
            }
            if second_value then
                table.insert(pairs, { first_value, second_value })
                if #pairs == max then break end
            end
        end
        return pairs
    end

    --------------------------------------------------------------------------------
    --- Gets two sets of discrete_values, and returns the first pair of discrete values
    --- where the second value is the nearest dated item from the second set, within a
    --- maximum time difference.
    ---
    --- @param args GetDiscreteValuePairsArgs a table of arguments
    ---
    --- @return DiscreteValuePair? # The pair of discrete values that are closest to each other in time
    --------------------------------------------------------------------------------
    function module.get_discrete_value_pair(args)
        args.max = 1
        local pairs = module.get_discrete_value_pairs(args)
        if #pairs > 0 then
            return pairs[1]
        end
        return nil
    end

    --------------------------------------------------------------------------------
    --- Get a pair of links for a pair of discrete values
    ---
    --- @param dv_pair DiscreteValuePair The pair of discrete values
    --- @param link_template1 string The template for the first link text
    --- @param link_template2 string The template for the second link text
    ---
    --- @return CdiAlertLinkPair # The links to the pair of discrete values
    --------------------------------------------------------------------------------
    function module.discrete_value_pair_to_link_pair(dv_pair, link_template1, link_template2)
        local first_value = dv_pair.first
        local second_value = dv_pair.second

        local link1 = cdi_alert_link()
        link1.discrete_value_name = first_value.name
        link1.discrete_value_id = first_value.unique_id
        link1.link_text = links.replace_link_place_holders(link_template1, nil, nil, first_value, nil)

        local link2 = cdi_alert_link()
        link2.discrete_value_name = second_value.name
        link2.discrete_value_id = second_value.unique_id
        link2.link_text = links.replace_link_place_holders(link_template2, nil, nil, second_value, nil)

        return { first = link1, second = link2 }
    end

    --- @class (exact) GetDiscreteValuePairsAsLinkPairsArgs: GetDiscreteValuePairsArgs
    --- @field linkTemplate1 string The template for the first link text
    --- @field linkTemplate2 string The template for the second link text

    --------------------------------------------------------------------------------
    --- Get all links for pairs of discrete values
    ---
    --- @param args GetDiscreteValuePairsAsLinkPairsArgs table of arguments
    ---
    --- @return CdiAlertLinkPair[] # The links to the pairs of discrete values
    --------------------------------------------------------------------------------
    function module.get_discrete_value_pairs_as_link_pairs(args)
        local dv_pairs = module.get_discrete_value_pairs(args)
        local link_pairs = {}
        for _, dv_pair in ipairs(dv_pairs) do
            table.insert(link_pairs,
                module.discrete_value_pair_to_link_pair(dv_pair, args.linkTemplate1, args.linkTemplate2))
        end
        return link_pairs
    end

    --------------------------------------------------------------------------------
    --- Get a pair of links for a pair of discrete values
    ---
    --- @param args GetDiscreteValuePairsAsLinkPairsArgs a table of arguments
    ---
    --- @return CdiAlertLinkPair? # The links to the pair of discrete values or nil if not found
    --------------------------------------------------------------------------------
    function module.get_first_discrete_value_pair_as_link_pair(args)
        local dv_pair = module.get_discrete_value_pair(args)
        if dv_pair then
            return module.discrete_value_pair_to_link_pair(dv_pair, args.linkTemplate1, args.linkTemplate2)
        end
        return nil
    end

    --------------------------------------------------------------------------------
    --- Get a single link for a pair of discrete values
    ---
    --- @param dv_pair DiscreteValuePair The pair of discrete values
    --- @param link_template string The template for the link text
    ---
    --- @return CdiAlertLink # The link to the pair of discrete values
    --------------------------------------------------------------------------------
    function module.discrete_value_pair_to_single_line_link(dv_pair, link_template)
        local first_value = dv_pair.first
        local second_value = dv_pair.second

        local link = cdi_alert_link()
        link.discrete_value_name = first_value.name
        link.discrete_value_id = first_value.unique_id
        link.link_text = links.replace_link_place_holders(link_template, nil, nil, first_value, nil)
        link.link_text = link.link_text:gsub("%[DATE1%]", first_value.result_date)
        link.link_text = link.link_text:gsub("%[DATE2%]", second_value.result_date)
        return link
    end

    --- @class (exact) GetDiscreteValuePairsAsSingleLineLinksArgs : GetDiscreteValuePairsArgs
    --- @field linkTemplate string The template for the link text

    --------------------------------------------------------------------------------
    --- Get all links for pairs of discrete values
    ---
    --- @param args GetDiscreteValuePairsAsSingleLineLinksArgs a table of arguments
    ---
    --- @return CdiAlertLink[] # The links to the pairs of discrete values
    --------------------------------------------------------------------------------
    function module.get_discrete_value_pairs_as_single_line_links(args)
        local dv_pairs = module.get_discrete_value_pairs(args)
        local link_pairs = {}
        for _, dv_pair in ipairs(dv_pairs) do
            table.insert(link_pairs, module.discrete_value_pair_to_single_line_link(dv_pair, args.linkTemplate))
        end
        return link_pairs
    end

    --------------------------------------------------------------------------------
    --- Get a single link for a pair of discrete values
    ---
    --- @param args GetDiscreteValuePairsAsSingleLineLinksArgs a table of arguments
    ---
    --- @return CdiAlertLink? # The link to the pair of discrete values or nil if not found
    --------------------------------------------------------------------------------
    function module.get_first_discrete_value_pair_as_single_line_link(args)
        local dv_pair = module.get_discrete_value_pair(args)
        if dv_pair then
            return module.discrete_value_pair_to_single_line_link(dv_pair, args.linkTemplate)
        end
        return nil
    end

    --- @class (exact) GetDiscreteValuePairsAsCombinedSingleLineLinkArgs : GetDiscreteValuePairsArgs
    --- @field linkTemplate string The template for the link text

    --------------------------------------------------------------------------------
    --- Get a single link for all pairs of discrete values
    ---
    --- @param args GetDiscreteValuePairsAsCombinedSingleLineLinkArgs a table of arguments
    ---
    --- @return CdiAlertLink? # The link to the pairs of discrete values
    --------------------------------------------------------------------------------
    function module.get_discrete_value_pairs_as_combined_single_line_link(args)
        local dv_pairs = module.get_discrete_value_pairs(args)
        local values_text = ""

        if #dv_pairs == 0 then
            return nil
        end

        local first_date = dv_pairs[1].first.result_date or ""
        local last_date = dv_pairs[#dv_pairs].first.result_date or ""

        for _, dv_pair in ipairs(dv_pairs) do
            values_text = values_text .. dv_pair.first.result .. "/" .. dv_pair.second.result .. ", "
        end
        values_text = values_text:sub(1, -3)

        local link = cdi_alert_link()
        link.discrete_value_id = dv_pairs[1].first.unique_id
        link.discrete_value_name = dv_pairs[1].first.name
        link.link_text = links.replace_link_place_holders(args.linkTemplate, nil, nil, dv_pairs[1].first, nil)
        link.link_text = link.link_text:gsub("%[VALUE_PAIRS%]", values_text)
        link.link_text = link.link_text:gsub("%[DATE1%]", first_date)
        link.link_text = link.link_text:gsub("%[DATE2%]", last_date)

        return link
    end

    --------------------------------------------------------------------------------
    --- Make a discrete value link
    ---
    --- @param dvs string[] The discrete values to search for
    --- @param text string The text for the link
    --- @param predicate (fun(discrete_value: DiscreteValue, num: number?):boolean)? Predicate function to filter discrete values
    --- @param sequence number? The sequence number of the link
    ---
    --- @return CdiAlertLink? - a link to the discrete value or nil if not found
    --------------------------------------------------------------------------------
    function module.make_discrete_value_link(dvs, text, predicate, sequence)
        return links.get_discrete_value_link {
            discreteValueNames = dvs,
            text = text,
            predicate = predicate,
            seq = sequence,
        }
    end

    --------------------------------------------------------------------------------
    --- Make a discrete value link
    ---
    --- @param dvs string[] The discrete values to search for
    --- @param text string The text for the link
    --- @param predicate (fun(discrete_value: DiscreteValue, num: number?):boolean)? Predicate function to filter discrete values
    --- @param max_per_value number? The sequence number of the link
    ---
    --- @return CdiAlertLink[] - a link to the discrete value or nil if not found
    --------------------------------------------------------------------------------
    function module.make_discrete_value_links(dvs, text, predicate, max_per_value)
        return links.get_discrete_value_links {
            discreteValueNames = dvs,
            text = text,
            predicate = predicate,
            max_per_value = max_per_value,
        }
    end

    --------------------------------------------------------------------------------
    --- Make a predicate to check that a discrete value is less than some number
    ---
    --- @param value number The value to compare against
    --- @return fun(discrete_value: DiscreteValue, num: number?):boolean - the predicate function
    --------------------------------------------------------------------------------
    function module.make_lt_predicate(value)
        return function(dv_, num)
            return num < value
        end
    end

    --------------------------------------------------------------------------------
    --- Make a predicate to check that a discrete value is less than or equal to some number
    ---
    --- @param value number The value to compare against
    --- @return fun(discrete_value: DiscreteValue, num: number?):boolean - the predicate function
    --------------------------------------------------------------------------------
    function module.make_lte_predicate(value)
        return function(dv_, num)
            return num <= value
        end
    end

    --------------------------------------------------------------------------------
    --- Make a predicate to check that a discrete value is greater than some number
    ---
    --- @param value number The value to compare against
    --- @return fun(discrete_value: DiscreteValue, num: number?):boolean - the predicate function
    --------------------------------------------------------------------------------
    function module.make_gt_predicate(value)
        return function(dv_, num)
            return num > value
        end
    end

    --------------------------------------------------------------------------------
    --- Make a predicate to check that a discrete value is greater than or equal to some number
    ---
    --- @param value number The value to compare against
    --- @return fun(discrete_value: DiscreteValue, num: number?):boolean - the predicate function
    --------------------------------------------------------------------------------
    function module.make_gte_predicate(value)
        return function(dv_, num)
            return num >= value
        end
    end

    --------------------------------------------------------------------------------
    --- Make a predicate to check that a discrete value falls within a range
    ---
    --- @param min number The minimum value to compare against
    --- @param max number The maximum value to compare against
    --- @param lower_inclusive boolean? If true, the lower bound is inclusive (default true)
    --- @param upper_inclusive boolean? If true, the upper bound is inclusive (default false)
    --- @return fun(discrete_value: DiscreteValue, num: number?):boolean - the predicate function
    --------------------------------------------------------------------------------
    function module.make_range_predicate(min, max, lower_inclusive, upper_inclusive)
        if lower_inclusive == nil then lower_inclusive = true end
        if upper_inclusive == nil then upper_inclusive = false end

        if lower_inclusive and upper_inclusive then
            return function(dv_, num)
                return num >= min and num <= max
            end
        elseif lower_inclusive and not upper_inclusive then
            return function(dv_, num)
                return num >= min and num < max
            end
        elseif not lower_inclusive and upper_inclusive then
            return function(dv_, num)
                return num > min and num <= max
            end
        else
            return function(dv_, num)
                return num > min and num < max
            end
        end
    end

    --------------------------------------------------------------------------------
    --- Make a predicate to check that a discrete value matches any of a list of patterns
    ---
    --- @param patterns string[] The patterns to compare against
    --- @return fun(discrete_value: DiscreteValue, num: number?):boolean - the predicate function
    --------------------------------------------------------------------------------
    function module.make_match_predicate(patterns)
        return function(dv, num_)
            return lists.any(patterns, function(pattern)
                return string.match(dv.result, pattern)
            end)
        end
    end

    --------------------------------------------------------------------------------
    --- Make a predicate to check that a discrete value does not match any of a list of patterns
    ---
    --- @param patterns string[] The patterns to compare against
    --- @return fun(discrete_value: DiscreteValue, num: number?):boolean - the predicate function
    --------------------------------------------------------------------------------
    function module.make_no_match_predicate(patterns)
        return function(dv, num_)
            return not lists.any(patterns, function(pattern)
                return string.match(dv.result, pattern)
            end)
        end
    end

    return module
end
