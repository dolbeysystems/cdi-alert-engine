local ghost = require "ghost"
local extern = ghost.extern

extern "Accounts" {
    _id = "123457890",
    CdiAlerts = { {
        ScriptName = "rhabdomyolysis.lua",
        Outcome = "AUTORESOLVED",
        Passed = true,
        Validated = true,
    } },
    Documents = { {
        DocumentId = "1234567890",
        CodeReferences = {
            { Code = "M62.82" },
            { Code = "T79.6XXA" },
        },
    } },
}
