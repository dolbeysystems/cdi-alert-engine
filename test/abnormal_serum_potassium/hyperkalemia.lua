local ghost = require "ghost"
local extern = ghost.extern
local time = ghost.time

extern "Accounts" {
    _id = "123457890",
    DiscreteValues = {
        {
            UniqueId = "1234567890",
            Name = "POTASSIUM (mmol/L)",
            Result = "10",
            ResultDate = time.now(),
        },
        {
            UniqueId = "6359354834",
            Name = "POTASSIUM (mmol/L)",
            Result = "10",
            ResultDate = time.now(),
        }
    },
    Documents = { {
        DocumentId = "1234567890",
        CodeReferences = {
            { Code = "5A1D70Z" },
            { Code = "5A1D80Z" },
        }
    } }
}
