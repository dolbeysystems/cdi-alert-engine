local ghost = require "ghost"
local extern = ghost.extern

extern "Accounts" {
    _id = "0123456789",
    Documents = { {
        DocumentId = "1234567890",
        CodeReferences = {
            { Code = "N39.0" },
        },
        AbstractionReferences = {
            { Code = "NEPHROSTOMY_CATHETER" }
        },
    } }
}
