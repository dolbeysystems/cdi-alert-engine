--- @class (exact) GetExistingCdiAlertArgs
--- @field account Account? Account object (uses global account if not provided)
--- @field scriptName string The name of the script to match

--------------------------------------------------------------------------------
--- Get the existing cdi alert for a script
---
--- @param args GetExistingCdiAlertArgs a table of arguments
---
--- @return CdiAlert? - the existing cdi alert or nil if not found
--------------------------------------------------------------------------------
function GetExistingCdiAlert(args)
    local account = args.account or Account
    local scriptName = args.scriptName

    for i = 1, #account.cdi_alerts do
        local alert = account.cdi_alerts[i]
        if alert.script_name == scriptName then
            return alert
        end
    end
    return nil
end