local ghost = require "ghost"
local extern = ghost.extern
local time = ghost.time

extern "Accounts" {
    _id = "1234567890",
    Medications = { {
        ExternalId = "1234567890",
        CDIAlertCategory = "Methadone",
        StartDate = time.now(),
    } },
}
