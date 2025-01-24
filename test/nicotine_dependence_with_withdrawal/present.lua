local ghost = require "ghost"
local extern = ghost.extern
local time = ghost.time

extern "Accounts" {
    _id = "1234567890",
    Medications = { {
        ExternalId = "1234567890",
        Category = "Nicotine Withdrawal Medication",
        StartDate = time.now(),
    } },
    Documents = { {
        DocumentId = "1234567890",
        CodeReferences = {
            { Code = "F17.200" },
            { Code = "R41.840" },
        }
    } }
}
