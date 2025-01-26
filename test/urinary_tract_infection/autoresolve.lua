local ghost = require "ghost"
local extern = ghost.extern

extern "Accounts" {
    _id = "0123456789",
    Documents = { {
        DocumentId = "1234567890",
        CodeReferences = {
            { Code = "T83.510A" },
        }
    } }
}
