require("libs.common")

local codeLinks = GetCodeLinks{ code = "I10", linkTemplate = "This has htn code [CODE]" }
local moreCodeLinks = GetCodeLinks { code = "E11", linkTemplate = "This has diabetes code [CODE]" }
local combinedCodeLinks = { table.unpack(codeLinks), table.unpack(moreCodeLinks) }

for i = 1, #combinedCodeLinks do
    info("CODE LINK TEXT: " .. combinedCodeLinks[i].link_text)
end

