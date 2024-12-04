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

--- @class (exact) GetCodeLinkWithPrefixArgs : GetCodeLinksArgs
--- @field prefix string The prefix to search for

--------------------------------------------------------------------------------
--- Get the first code link for a prefix
---
--- @param arguments GetCodeLinkWithPrefixArgs a table of arguments
---
--- @return CdiAlertLink? - the link to the first code or nil if not found
--------------------------------------------------------------------------------
function GetCodePrefixLink(arguments)
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
--- @param arguments GetCodeLinkWithPrefixArgs The arguments for the link
---
--- @return CdiAlertLink[]? - a list of links to the codes or nil if not found
--------------------------------------------------------------------------------
function GetCodePrefixLinks(arguments)
    local codes = GetAccountCodesByPrefix(arguments.prefix)
    if #codes == 0 then
        return nil
    end
    arguments.codes = codes
    return GetCodeLinks(arguments)
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