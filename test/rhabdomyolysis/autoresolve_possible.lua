local ghost = require "ghost"
local extern = ghost.extern

extern "Accounts" {
    _id = "123457890",
    CdiAlerts = { {
        ScriptName = "rhabdomyolysis.lua",
        SubTitle = "Possible Rhabdomyolysis Dx",
        Passed = true,
        Validated = false,
    } },
    Documents = { {
        DocumentId = "1234567890",
        CodeReferences = {
            { Code = "M62.82" },
        },
    } },
}
