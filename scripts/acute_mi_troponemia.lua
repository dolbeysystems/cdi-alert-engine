---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Acute MI with Troponemia
---
--- This script checks an account to see if it matches the criteria for an Acute MI with Troponemia alert.
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
    local stemicodeDictionary = {
        ["I21.01"] = "ST Elevation (STEMI) Myocardial Infarction Involving Left Main Coronary Artery",
        ["I21.02"] = "ST Elevation (STEMI) Myocardial Infarction Involving Left Anterior Descending Coronary Artery",
        ["I21.09"] = "ST Elevation (STEMI) Myocardial Infarction Involving Other Coronary Artery Of Anterior Wall",
        ["I21.11"] = "ST Elevation (STEMI) Myocardial Infarction Involving Right Coronary Artery",
        ["I21.19"] = "ST Elevation (STEMI) Myocardial Infarction Involving Other Coronary Artery Of Inferior Wall",
        ["I21.21"] = "ST Elevation (STEMI) Myocardial Infarction Involving Left Circumflex Coronary Artery",
        ["I21.29"] = "ST Elevation (STEMI) Myocardial Infarction Involving Other Sites",
        ["I21.3"] = "ST Elevation (STEMI) Myocardial Infarction of Unspecified Site"
    }
    local othercodeDictionary = {
        ["I21.A1"] = "Myocardial Infarction Type 2",
        ["I21.A9"] = "Other Myocardial Infarction Type",
        ["I21.B"] = "Myocardial Infarction with Coronary Microvascular Dysfunction",
        ["I5A"] = "Non-Ischemic Myocardial Injury (Non-Traumatic)",
    }

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
