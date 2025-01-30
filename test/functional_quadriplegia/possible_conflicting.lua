local ghost = require "ghost"
local extern = ghost.extern

extern "Accounts" {
    _id = "1234567890",
    Documents = { {
        DocumentId = "1234567890",
        CodeReferences = {
            { Code = "R53.2" },
            { Code = "G82.20" }
        }
    } }
}
