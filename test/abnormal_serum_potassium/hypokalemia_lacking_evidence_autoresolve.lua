local ghost = require "ghost"
local extern = ghost.extern
local time = ghost.time

extern "Accounts" {
    _id = "123457890",
    CdiAlerts = { {
        ScriptName = "abnormal_serum_potassium.lua",
        SubTitle = "Hypokalemia Dx Documented Possibly Lacking Supporting Evidence",
        Passed = true,
        Validated = false,
    } },
    DiscreteValues = {
        {
            UniqueId = "1234567890",
            Name = "POTASSIUM (mmol/L)",
            Result = "0",
            ResultDate = time.now(),
        },
        {
            UniqueId = "6359354834",
            Name = "POTASSIUM (mmol/L)",
            Result = "1",
            ResultDate = time.now(),
        }
    },
    Documents = { {
        DocumentId = "1234567890",
        CodeReferences = {
            { Code = "E87.6" }
        }
    } }
}
