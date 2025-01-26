local ghost = require "ghost"
local extern = ghost.extern
local time = ghost.time

extern "Accounts" {
    _id = "1234567890",
    CdiAlerts = { {
        ScriptName = "coagulopathy.lua",
        Passed = true,
        Validated = false,
    } },
    Documents = { {
        DocumentId = "1234567890",
        CodeReferences = {
            { Code = "D65" },
        }
    } }
}
