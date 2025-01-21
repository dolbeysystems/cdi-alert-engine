---@diagnostic disable-next-line:name-style-check
return function(Account)
    local module = {}
    local links = require "libs.common.basic_links" (Account)

    --------------------------------------------------------------------------------
    --- Make a medication link
    ---
    --- @param cat string The medication category (name)
    --- @param text string The text for the link
    --- @param sequence number? The sequence number of the link
    ---
    --- @return CdiAlertLink? - a link to the medication or nil if not found
    --------------------------------------------------------------------------------
    function module.make_medication_link(cat, text, sequence)
        return links.get_medication_link {
            cat = cat,
            text = text,
            seq = sequence,
        }
    end
    return module
end
