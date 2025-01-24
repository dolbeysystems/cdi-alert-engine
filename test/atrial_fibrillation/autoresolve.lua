local ghost = require "ghost"
local extern = ghost.extern

extern "Accounts" {
    _id = "0123456789",
    CdiAlerts = { {
        ScriptName = "atrial_fibrillation.lua",
        SubTitle = "Unspecified Atrial Fibrillation Dx",
        Passed = true,
        Validated = false,
    } },
    Documents = { {
        DocumentId = "1234567890",
        CodeReferences = {
            { Code = "I48.0" },
        }
    } }
}
