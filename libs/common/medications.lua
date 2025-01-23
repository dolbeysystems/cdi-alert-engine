---@diagnostic disable-next-line:name-style-check
return function(Account)
    local module = {}
    local links = require "libs.common.basic_links" (Account)
    local lists = require "libs.common.lists"

    --------------------------------------------------------------------------------
    --- Make a medication link
    ---
    --- @param cat string The medication category (name)
    --- @param text string? The text for the link
    --- @param sequence number? The sequence number of the link
    --- @param predicate (fun(med: Medication):boolean?)? A predicate to filter the medications
    ---
    --- @return CdiAlertLink? - a link to the medication or nil if not found
    --------------------------------------------------------------------------------
    function module.make_medication_link(cat, text, sequence, predicate)
        text = text or cat
        return links.get_medication_link {
            cat = cat,
            text = text,
            seq = sequence,
            predicate = predicate
        }
    end

    --------------------------------------------------------------------------------
    --- Make a predicate to check that a medication route matches any of a list of patterns
    ---
    --- @param ... string The patterns to compare against
    --- @return fun(med: Medication):boolean - the predicate function
    --------------------------------------------------------------------------------
    function module.make_route_match_predicate(...)
        local patterns = { ... }
        return function(med)
            return lists.any(patterns, function(pattern)
                return string.match(med.route, pattern)
            end)
        end
    end

    --------------------------------------------------------------------------------
    --- Make a predicate to check that a medication route matches any of a list of patterns
    ---
    --- @param ... string The patterns to compare against
    --- @return fun(med: Medication):boolean - the predicate function
    --------------------------------------------------------------------------------
    function module.make_route_no_match_predicate(...)
        local patterns = { ... }
        return function(med)
            return not lists.any(patterns, function(pattern)
                return string.match(med.route, pattern)
            end)
        end
    end

    return module
end
