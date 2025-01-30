local ghost = require "ghost"
local extern = ghost.extern

extern "Accounts" {
    _id = "1234567890",
    Documents = { {
        DocumentId = "1234567890",
        CodeReferences = {
            { Code = "Z51.11" },
            { Code = "Q89.01" },
            { Code = "B44.0" },
            { Code = "F10.20" }
        }
    } }
}
