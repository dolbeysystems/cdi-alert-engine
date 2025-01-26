local ghost = require "ghost"
local extern = ghost.extern

extern "Accounts" {
    _id = "0123456789",
    CdiAlerts = { {
        ScriptName = "substance_abuse.lua",
        SubTitle = "Possible Opioid Dependence",
        Passed = true,
        Validated = false,
    } },
    Documents = { {
        DocumentId = "1234567890",
        CodeReferences = {
            { Code = "F11.20" },
        }
    } }
}
