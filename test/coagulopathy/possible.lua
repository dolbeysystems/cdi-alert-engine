local ghost = require "ghost"
local extern = ghost.extern
local time = ghost.time

extern "Accounts" {
    _id = "1234567890",
    DiscreteValues = {
        {
            UniqueId = "1234567890",
            Name = "INR",
            Result = "2",
            ResultDate = time.now(),
        },
        {
            UniqueId = "1234567890",
            Name = "PROTIME (SEC)",
            Result = "14",
            ResultDate = time.now(),
        },
    },
    Documents = { {
        DocumentId = "1234567890",
        CodeReferences = {
            { Code = "Z79.01" },
        }
    } }
}
