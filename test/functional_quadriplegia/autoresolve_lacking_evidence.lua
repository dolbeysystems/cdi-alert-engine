local ghost = require "ghost"
local extern = ghost.extern

extern "Accounts" {
    _id = "1234567890",
    CdiAlerts = { {
        ScriptName = "functional_quadriplegia.lua",
        SubTitle = "Functional Quadriplegia Dx Possibly Lacking Supporting Evidence",
        Passed = true,
        Validated = false,
    } },
    Documents = { {
        DocumentId = "1234567890",
        CodeReferences = {
            { Code = "Z74.01" },
        }

    } }
}
