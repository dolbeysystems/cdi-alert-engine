local ghost = require "ghost"
local extern = ghost.extern
local time = ghost.time

extern "Accounts" {
    _id = "123457890",
    DiscreteValues = {
        {
            UniqueId = "1234567890",
            Name = "CPK (U/L)",
            Result = "400",
            ResultDate = time.now(),
        }
    },
    Documents = { {
        DocumentId = "1234567890",
        CodeReferences = {
            { Code = "M62.82" },
            { Code = "T79.6XXA" },
        },
    } },
}
