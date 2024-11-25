---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Abnormal Serum Sodium
---
--- This script checks an account to see if it matches the criteria for a abnormal serum sodium alert.
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
local alertCodeDictionary = {}
local accountAlertCodes = GetAccountCodesInDictionary(Account, alertCodeDictionary)
local alertMatched = false
local alertAutoResolved = false
local existingAlert = GetExistingCdiAlert { scriptName = ScriptName }



--------------------------------------------------------------------------------
--- Alert Qualification 
--------------------------------------------------------------------------------
if not existingAlert or not existingAlert.validated then
end



--------------------------------------------------------------------------------
--- Link Creation
--------------------------------------------------------------------------------
if alertMatched then
end



--------------------------------------------------------------------------------
--- Result Finalization 
--------------------------------------------------------------------------------
if alertMatched or alertAutoResolved then
    local resultLinks = {}

    if existingAlert then
        resultLinks = MergeLinks(existingAlert.links, resultLinks)
    end
    Result.links = resultLinks
    Result.passed = true
end

