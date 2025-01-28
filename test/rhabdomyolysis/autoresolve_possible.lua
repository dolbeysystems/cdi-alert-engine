local ghost = require "ghost"
local extern = ghost.extern
local time = ghost.time

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
    DiscreteValues = {
        {
            UniqueId = "1234567890",
            Name = "CPK (U/L)",
            Result = "400",
            ResultDate = time.now(),
        }
    },
}
