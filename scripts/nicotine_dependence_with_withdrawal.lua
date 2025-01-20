---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Nicotine Dependence with Withdrawal
---
--- This script checks an account to see if it matches the criteria for a nicotine dependence with withdrawal alert.
---
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
---------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Requires 
--------------------------------------------------------------------------------
local alerts = require("libs.common.alerts")(Account)
local links = require("libs.common.basic_links")(Account)
local codes = require("libs.common.codes")(Account)
local discrete = require("libs.common.discrete_values")(Account)
local headers = require("libs.common.headers")(Account)



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }



if not existing_alert or not existing_alert.validated then
    --------------------------------------------------------------------------------
    --- Header Variables and Helper Functions
    --------------------------------------------------------------------------------
    local result_links = {}
    local documented_dx_header = headers.make_header_builder("Documented Dx", 1)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 2)
    local withdrawal_header = headers.make_header_builder("Withdrawal Symptoms", 3)

    local function compile_links()
        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))
        table.insert(result_links, withdrawal_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end


    --------------------------------------------------------------------------------
    --- Alert Variables 
    --------------------------------------------------------------------------------
    local alert_code_dictionary = {
        ["F17.203"] = "Nicotine Dependence Unspecified, With Withdrawal",
        ["F17.213"] = "Nicotine Dependence, Cigarettes, With Withdrawal",
        ["F17.223"] = "Nicotine Dependence, Chewing Tobacco, With Withdrawal",
        ["F17.293"] = "Nicotine Dependence, Other Tobacco Product, With Withdrawal"
    }
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Alert Trigger
    local f17200_code =
        links.get_code_link { code = "F17.200", text = "Nicotine Dependence, Unspecified, Uncomplicated" }
    local f17208_code =
        links.get_code_link { code = "F17.208", text = "Nicotine Dependence, Unspecified, With Other Nicotine-Induced Disorders" }
    local f17209_code =
        links.get_code_link { code = "F17.209", text = "Nicotine Dependence, Unspecified, With Unspecified Nicotine-Induced Disorders" }
    local f1721_code =
        links.get_code_link { code = "F17.21", text = "Nicotine Dependence, Cigarettes" }
    local f17210_code =
        links.get_code_link { code = "F17.210", text = "Nicotine Dependence, Cigarettes, Uncomplicated" }
    local f17218_code =
        links.get_code_link { code = "F17.218", text = "Nicotine Dependence, Cigarettes, With Other Nicotine-Induced Disorders" }
    local f17219_code =
        links.get_code_link { code = "F17.219", text = "Nicotine Dependence, Cigarettes, With Unspecified Nicotine-Induced Disorders" }
    local f1722_code =
        links.get_code_link { code = "F17.22", text = "Nicotine Dependence, Chewing Tobacco" }
    local f17220_code =
        links.get_code_link { code = "F17.220", text = "Nicotine Dependence, Chewing Tobacco, Uncomplicated" }
    local f17228_code =
        links.get_code_link { code = "F17.228", text = "Nicotine Dependence, Chewing Tobacco, With Other Nicotine-Induced Disorders" }
    local f17229_code =
        links.get_code_link { code = "F17.229", text = "Nicotine Dependence, Chewing Tobacco, With Unspecified Nicotine-Induced Disorders" }
    local f1729_code =
        links.get_code_link { code = "F17.29", text = "Nicotine Dependence, Other Tobacco Product" }
    local f17290_code =
        links.get_code_link { code = "F17.290", text = "Nicotine Dependence, Other Tobacco Product, Uncomplicated" }
    local f17298_code =
        links.get_code_link { code = "F17.298", text = "Nicotine Dependence, Other Tobacco Product, With Other Nicotine-Induced Disorders" }
    local f17299_code =
        links.get_code_link { code = "F17.299", text = "Nicotine Dependence, Other Tobacco Product, With Unspecified Nicotine-Induced Disorders" }

    -- Medications
    local nicotine_withdrawal_meds = discrete.get_medication("Nicotine Withdrawal Medication")
    local nicotine_withdrawal_meds_abs = links.get_abstraction_link {
        code = "NICOTINE_WITHDRAWAL_MEDICATION",
        text = "Nicotine Withdrawal Medication '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])"
    }

    -- Withdrawal Symptoms
    local r41840_code = links.get_code_link { code = "R41.840", text = "Difficulty Concentrating" }
    local headache_abs = links.get_abstraction_link { code = "HEADACHE", text = "Headache" }
    local r454_code = links.get_code_link { code = "R45.4", text = "Irritability" }
    local g4700_code = links.get_code_link { code = "G47.00", text = "Insomnia" }
    local r450_code = links.get_code_link { code = "R45.0", text = "Nervousness/Anxious" }
    local nicotine_cravings_abs = links.get_abstraction_link { code = "NICOTINE_CRAVINGS", text = "Nicotine Cravings" }
    local r451_code = links.get_code_link { code = "R45.1", text = "Restlessness and Agitated" }

    local code_present =
        f17200_code ~= nil or f17208_code ~= nil or f17209_code ~= nil or f1721_code ~= nil or
        f17210_code ~= nil or f17218_code ~= nil or f17219_code ~= nil or f1722_code ~= nil or
        f17220_code ~= nil or f17228_code ~= nil or f17229_code ~= nil or f1729_code ~= nil or
        f17290_code ~= nil or f17298_code ~= nil or f17299_code ~= nil

    -- Code Present Determination
    documented_dx_header:add_link(f17200_code)
    documented_dx_header:add_link(f17208_code)
    documented_dx_header:add_link(f17209_code)
    documented_dx_header:add_link(f1721_code)
    documented_dx_header:add_link(f17210_code)
    documented_dx_header:add_link(f17218_code)
    documented_dx_header:add_link(f17219_code)
    documented_dx_header:add_link(f1722_code)
    documented_dx_header:add_link(f17220_code)
    documented_dx_header:add_link(f17228_code)
    documented_dx_header:add_link(f17229_code)
    documented_dx_header:add_link(f1729_code)
    documented_dx_header:add_link(f17290_code)
    documented_dx_header:add_link(f17298_code)
    documented_dx_header:add_link(f17299_code)



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if #account_alert_codes > 0 then
        if code_present then
            if existing_alert then
                for _, code in ipairs(account_alert_codes) do
                    local desc = alert_code_dictionary[code]
                    local temp_code =
                        links.get_code_link {
                            code = code,
                            text =
                                "Autoresolved Specified Code - " .. desc .. ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])"
                        }
                    if temp_code then
                        documented_dx_header:add_link(temp_code)
                        break
                    end
                end
                Result.outcome = "AUTORESOLVED"
                Result.reason = "Autoresolved due to one Specified Code on the Account"
                Result.validated = true
                Result.passed = true
            else
                Result.passed = false
            end
        end

    elseif code_present and (nicotine_withdrawal_meds_abs or nicotine_withdrawal_meds) and
        (headache_abs or r454_code or g4700_code or r450_code or nicotine_cravings_abs or r451_code or r41840_code)
    then
        treatment_and_monitoring_header:add_link(nicotine_withdrawal_meds)
        treatment_and_monitoring_header:add_link(nicotine_withdrawal_meds_abs)
        documented_dx_header:add_link(headache_abs)
        documented_dx_header:add_link(r454_code)
        documented_dx_header:add_link(g4700_code)
        documented_dx_header:add_link(r450_code)
        documented_dx_header:add_link(nicotine_cravings_abs)
        documented_dx_header:add_link(r451_code)
        documented_dx_header:add_link(r41840_code)
        Result.subtitle = "Nicotine Dependence present with possible Withdrawal"
        Result.passed = true
    end


    if Result.passed then
        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

