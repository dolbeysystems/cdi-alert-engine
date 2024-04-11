---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Atrial Fibrillation
---
--- This script checks an account to see if it matches the criteria for an atrial fibrillation alert.
---
--- Date: 4/10/2024
--- Version: 1.0
--- Site: (Default)
---------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Requires 
--------------------------------------------------------------------------------
require("libs.common")



--------------------------------------------------------------------------------
--- Setup
--------------------------------------------------------------------------------
--- Atrial fibrillation codes with descriptions
local atrialFibrillationCodeDictionary = {
    ["I48.0"] = "Paroxysmal Atrial Fibrillation",
    ["I48.11"] = "Longstanding Persistent Atrial Fibrillation",
    ["I48.19"] = "Other Persistent Atrial Fibrillation",
    ["I48.21"] = "Permanent Atrial Fibrillation",
    ["I48.20"] = "Chronic Atrial Fibrillation",
}
local heartRateDiscreteValueNames = {
    "Peripheral Pulse Rate",
    "Heart Rate Monitored (bpn)",
    "Peripheral Pulse Rate (bpn)",
}
local mapDiscreteValueNames = {
    "MAP"
}
local sbpDiscreteValueNames = {
    "Systolic Blood Pressure",
    "Systolic Blood Pressure (mmHg)",
}

--- List of codes in dependecy map that are present on the account (codes only)
---
--- @type string[]
local accountAtrialFibrillationCodes = {}

-- Populate accountAtrialFibrillationCodes list
for i = 1, #account.documents do
    --- @type Document
    local document = account.documents[i]
    for j = 1, #document.code_references do
        local codeReference = document.code_references[j]

        if atrialFibrillationCodeDictionary[codeReference.code] then
            local code = codeReference.code
            table.insert(accountAtrialFibrillationCodes, code)
        end
    end
end

--- Existing substance abuse alert (or nil if this alert doesn't exist currently on the account)
local existingAlert = GetExistingCdiAlert{ scriptName = "atrial_fibrillation.lua" }



--------------------------------------------------------------------------------
--- Alert Qualification 
--------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Additional Link Creation
--------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Result Finalization 
--------------------------------------------------------------------------------

