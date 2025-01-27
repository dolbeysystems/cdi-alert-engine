local ghost = require "ghost"
local extern = ghost.extern
local time = ghost.time

extern "Accounts" {
    _id = "123457890",
    CdiAlerts = { {
        ScriptName = "rhabdomyolysis.lua",
        SubTitle = "Rhabdomyolysis Dx Lacking Supporting Evidence",
        Passed = true,
        Validated = false,
    } },
    DiscreteValues = {
        {
            UniqueId = "1234567890",
            Name = "CPK (U/L)",
            Result = "400",
            ResultDate = time.now(),
        }
    }
}
