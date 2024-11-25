---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Substance Abuse
---
--- This script checks an account to see if it matches the criteria for a substance abuse alert.
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
local alcoholCodeDic = {
    ["F10.130"] = "Alcohol abuse with withdrawal, uncomplicated",
    ["F10.131"] = "Alcohol abuse with withdrawal delirium",
    ["F10.132"] = "Alcohol Abuse with Withdrawal",
    ["F10.139"] = "Alcohol abuse with withdrawal, unspecified",
    ["F10.230"] = "Alcohol Dependence with Withdrawal, Uncomplicated",
    ["F10.231"] = "Alcohol Dependence with Withdrawal Delirium",
    ["F10.232"] = "Alcohol Dependence with Withdrawal with Perceptual Disturbance",
    ["F10.239"] = "Alcohol Dependence with Withdrawal, Unspecified",
    ["F10.930"] = "Alcohol use, unspecified with withdrawal, uncomplicated",
    ["F10.931"] = "Alcohol use, unspecified with withdrawal delirium",
    ["F10.932"] = "Alcohol use, unspecified with withdrawal with perceptual disturbance",
    ["F10.939"] = "Alcohol use, unspecified with withdrawal, unspecified"
}

local opioidCodeDic = {
    ["F11.20"] = "Opioid Dependence, Uncomplicated",
    ["F11.21"] = "Opioid Dependence, In Remission",
    ["F11.22"] = "Opioid Dependence with Intoxication",
    ["F11.220"] = "Opioid Dependence with Intoxication, Uncomplicated",
    ["F11.221"] = "Opioid Dependence with Intoxication, Delirium",
    ["F11.222"] = "Opioid Dependence with Intoxication, Perceptual Disturbance",
    ["F11.229"] = "Opioid Dependence with Intoxication, Unspecified",
    ["F11.23"] = "Opioid Dependence with Withdrawal",
    ["F11.24"] = "Opioid Dependence with Withdrawal Delirium",
    ["F11.25"] = "Opioid dependence with opioid-induced psychotic disorder",
    ["F11.250"] = "Opioid dependence with opioid-induced psychotic disorder with delusions",
    ["F11.251"] = "Opioid dependence with opioid-induced psychotic disorder with hallucinations",
    ["F11.259"] = "Opioid dependence with opioid-induced psychotic disorder, unspecified",
    ["F11.28"] = "Opioid dependence with other opioid-induced disorder",
    ["F11.281"] = "Opioid dependence with opioid-induced sexual dysfunction",
    ["F11.282"] = "Opioid dependence with opioid-induced sleep disorder",
    ["F11.288"] = "Opioid dependence with other opioid-induced disorder",
    ["F11.29"] = "Opioid dependence with unspecified opioid-induced disorder"
}

local accountAlcoholCodes = GetAccountCodesInDictionary(Account, alcoholCodeDic)
local accountOpioidCodes = GetAccountCodesInDictionary(Account, opioidCodeDic)
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

