local ghost = require "ghost"
local extern = ghost.extern

extern "Accounts" {
    _id = "123457890",
    CdiAlerts = { {
        ScriptName = "functional_quadriplegia.lua",
        SubTitle = "Possible Functional Quadriplegia Dx",
        Passed = true,
        Validated = false,
    } },
    Documents = { {
        DocumentId = "1234567890",
        CodeReferences = {
            { Code = "G82.20" },
        },
        AbstractionReferences = {
            { Code = "MOVES_ALL_EXTREMITIES" },
        },
    } }
}
