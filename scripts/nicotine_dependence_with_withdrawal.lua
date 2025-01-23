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
local headers = require("libs.common.headers")(Account)
local lists = require("libs.common.lists")



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = Result.script_name }



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
    local f_code_present = lists.some {
        documented_dx_header:add_code_link("F17.200", "Nicotine Dependence, Unspecified, Uncomplicated"),
        documented_dx_header:add_code_link("F17.208", "Nicotine Dependence, Unspecified, With Other Nicotine-Induced Disorders"),
        documented_dx_header:add_code_link("F17.209", "Nicotine Dependence, Unspecified, With Unspecified Nicotine-Induced Disorders"),
        documented_dx_header:add_code_link("F17.21", "Nicotine Dependence, Cigarettes"),
        documented_dx_header:add_code_link("F17.210", "Nicotine Dependence, Cigarettes, Uncomplicated"),
        documented_dx_header:add_code_link("F17.218", "Nicotine Dependence, Cigarettes, With Other Nicotine-Induced Disorders"),
        documented_dx_header:add_code_link("F17.219", "Nicotine Dependence, Cigarettes, With Unspecified Nicotine-Induced Disorders"),
        documented_dx_header:add_code_link("F17.22", "Nicotine Dependence, Chewing Tobacco"),
        documented_dx_header:add_code_link("F17.220", "Nicotine Dependence, Chewing Tobacco, Uncomplicated"),
        documented_dx_header:add_code_link("F17.228", "Nicotine Dependence, Chewing Tobacco, With Other Nicotine-Induced Disorders"),
        documented_dx_header:add_code_link("F17.229", "Nicotine Dependence, Chewing Tobacco, With Unspecified Nicotine-Induced Disorders"),
        documented_dx_header:add_code_link("F17.29", "Nicotine Dependence, Other Tobacco Product"),
        documented_dx_header:add_code_link("F17.290", "Nicotine Dependence, Other Tobacco Product, Uncomplicated"),
        documented_dx_header:add_code_link("F17.298", "Nicotine Dependence, Other Tobacco Product, With Other Nicotine-Induced Disorders"),
        documented_dx_header:add_code_link("F17.299", "Nicotine Dependence, Other Tobacco Product, With Unspecified Nicotine-Induced Disorders")
    }

    -- Medications
    local medication_present = lists.some {
        treatment_and_monitoring_header:add_medication_link("Nicotine Withdrawal Medication"),
        treatment_and_monitoring_header:add_abstraction_link("NICOTINE_WITHDRAWAL_MEDICATION", "Nicotine Withdrawal Medication")
    }

    -- Withdrawal Symptoms
    local withdrawal_symptom_present = lists.some {
        documented_dx_header:add_code_link("R41.840", "Difficulty Concentrating"),
        documented_dx_header:add_abstraction_link("HEADACHE", "Headache"),
        documented_dx_header:add_code_link("R45.4", "Irritability"),
        documented_dx_header:add_code_link("G47.00", "Insomnia"),
        documented_dx_header:add_code_link("R45.0", "Nervousness/Anxious"),
        documented_dx_header:add_abstraction_link("NICOTINE_CRAVINGS", "Nicotine Cravings"),
        documented_dx_header:add_code_link("R45.1", "Restlessness and Agitated")
    }



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if #account_alert_codes > 0 then
        if f_code_present and existing_alert then
            for _, code in ipairs(account_alert_codes) do
                if documented_dx_header:add_code_link(code, "Autoresolved Specified Code - " .. alert_code_dictionary[code]) then
                    break
                end
            end
            Result.outcome = "AUTORESOLVED"
            Result.reason = "Autoresolved due to one Specified Code on the Account"
            Result.validated = true
            Result.passed = true
        end
    elseif f_code_present and medication_present and withdrawal_symptom_present then
        Result.subtitle = "Nicotine Dependence present with possible Withdrawal"
        Result.passed = true
    end



    ----------------------------------------
    --- Result Finalization 
    ----------------------------------------
    if Result.passed then compile_links() end
end

