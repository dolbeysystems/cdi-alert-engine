---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Stroke
---
--- This script checks an account to see if it matches the criteria for a stroke alert.
---
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
---------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Requires 
--------------------------------------------------------------------------------
require("libs.common")



--------------------------------------------------------------------------------
--- Setup
--------------------------------------------------------------------------------
local existingAlert = GetExistingCdiAlert { scriptName = ScriptName }



if not existingAlert or not existingAlert.validated then
    ----------------------------------------
    --- Alert Variables 
    ----------------------------------------
    local alertCodeDictionary = {

    }
    local accountAlertCodes = GetAccountCodesInDictionary(Account, alertCodeDictionary)

    --------------------------------------------------------------------------------
    --- Alert Qualification 
    --------------------------------------------------------------------------------



    --------------------------------------------------------------------------------
    --- Link Composition and Alert Finalization
    --------------------------------------------------------------------------------
    if Result.passed then
        local resultLinks = {}

        if existingAlert then
            -- Autoclose
        else
            -- Normal Alert
        end

        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        if existingAlert then
            resultLinks = MergeLinks(existingAlert.links, resultLinks)
        end
        Result.links = resultLinks
        Result.passed = true
    end
end

