local module = {}
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
function module.get_existing_cdi_alert(args)
    local account = args.account or Account
    local script_name = args.scriptName

    for i = 1, #account.cdi_alerts do
        local alert = account.cdi_alerts[i]
        if alert.script_name == script_name then
            return alert
        end
    end
    return nil
end

return module
