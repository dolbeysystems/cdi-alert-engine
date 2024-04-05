require("libs.common")
hello() -- from libs/common.lua

link = CdiAlertLink:new()
info("Created link: "..link.)

-- info("this is "..script_filename)

info(account.patient.first_name)
-- "1" means first... don't use 0 like I did.
info(account.documents[1].code_references[1].code)

result.passed = true
info("script passed: "..tostring(result.passed))
