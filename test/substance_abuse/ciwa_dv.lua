local ghost = require "ghost"
local extern = ghost.extern
local time = ghost.time

extern "Accounts" {
    _id = "1234567890",
    DiscreteValues = { {
        UniqueId = "1234567890",
        Name = "alcohol CIWA Calc score 1112",
        Result = "10",
        ResultDate = time.now(),
    } },
}
