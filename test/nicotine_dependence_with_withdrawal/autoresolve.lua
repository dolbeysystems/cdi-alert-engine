local ghost = require "ghost"
local extern = ghost.extern
local time = ghost.time

extern "Accounts" {
    _id = "0123456789",
    Medications = { {
        ExternalId = "1234567890",
        Category = "Nicotine Withdrawal Medication",
        StartDate = time.now(),
    } },
    CdiAlerts = { {
        ScriptName = "nicotine_dependence_with_withdrawal.lua",
        Passed = true,
        Validated = false,
    } },
    Documents = { {
        DocumentId = "1234567890",
        CodeReferences = {
            { Code = "F17.200" },
            { Code = "F17.203" },
        }
    } }
}
