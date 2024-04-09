require("libs.common")

local codeLinks = GetCodeLinks(account, "I10", "This has htn code [CODE]", {})
local moreCodeLinks = GetCodeLinks(account, "E11", "This has diabetes code [CODE]", {})
local combined = {table.unpack(codeLinks), table.unpack(moreCodeLinks)}

for i = 1, #combined do
    info("CODE LINK TEXT: " .. combined[i].link_text)
end

