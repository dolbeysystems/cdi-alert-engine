require("libs.common")
Hello() -- from libs/common.lua

local codeLinks = GetCodeLinks(account, "123", "linkTemplate", { "note", "lab" })


-- info("this is "..script_filename)
info(account.patient.first_name)
-- "1" means first... don't use 0 like I did.
if account.documents[1] ~= nil and account.documents[1].code_references[1] ~= nil then
  info(account.documents[1].code_references[1].code)
else
  info("Account has no documents or code references")
end

result.passed = true
info("script passed: "..tostring(result.passed))