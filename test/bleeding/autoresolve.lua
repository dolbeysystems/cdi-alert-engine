local ghost = require "ghost"
local extern = ghost.extern

extern "Accounts" {
    _id = "123457890",
    CdiAlerts = { {
        ScriptName = "bleeding.lua",
        Passed = true,
        Validated = false,
    } },
    Documents = { {
        DocumentId = "1234567890",
        CodeReferences = {
            { Code = "I48.0" }
        }
    } }
}
