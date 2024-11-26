---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Acidosis
---
--- This script checks an account to see if it matches the criteria for a acidosis alert.
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
local subtitle = existingAlert and existingAlert.subtitle or nil



if not existingAlert or not existingAlert.validated then
    --------------------------------------------------------------------------------
    --- Alert Variables 
    --------------------------------------------------------------------------------
    local alertCodeDictionary = {
        ["E08.10"] = "Diabetes mellitus due to underlying condition with ketoacidosis without coma",
        ["E08.11"] = "Diabetes mellitus due to underlying condition with ketoacidosis with coma",
        ["E09.10"] = "Drug or chemical induced diabetes mellitus with ketoacidosis without coma",
        ["E09.11"] = "Drug or chemical induced diabetes mellitus with ketoacidosis with coma",
        ["E10.10"] = "Type 1 diabetes mellitus with ketoacidosis without coma",
        ["E10.11"] = "Type 1 diabetes mellitus with ketoacidosis with coma",
        ["E11.10"] = "Type 2 diabetes mellitus with ketoacidosis without coma",
        ["E11.11"] = "Type 2 diabetes mellitus with ketoacidosis with coma",
        ["E13.10"] = "Other specified diabetes mellitus with ketoacidosis without coma",
        ["E13.11"] = "Other specified diabetes mellitus with ketoacidosis with coma",
        ["E87.4"] = "Mixed disorder of acid-base balance",
        ["E87.21"] = "Acute Metabolic Acidosis",
        ["E87.22"] = "Chronic Metabolic Acidosis",
        ["P74.0"] = "Late metabolic acidosis of newborn"
    }
    local accountAlertCodes = GetAccountCodesInDictionary(Account, alertCodeDictionary)



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------




    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        local resultLinks = {}

        if Result.validated then
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
    end
end

