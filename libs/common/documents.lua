---@diagnostic disable-next-line:name-style-check
return function(Account)
    local module = {}
    local links = require "libs.common.basic_links" (Account)

    --------------------------------------------------------------------------------
    --- Make a discrete value link
    ---
    --- @param document_type string The document type to make a link for
    --- @param text string? The text for the link
    --- @param sequence number? The sequence number of the link
    ---
    --- @return CdiAlertLink? - a link to the discrete value or nil if not found
    --------------------------------------------------------------------------------
    function module.make_document_link(document_type, text, sequence)
        text = text or document_type
        return links.get_document_link {
            documentType = document_type,
            text = text,
            seq = sequence,
        }
    end

    return module
end

