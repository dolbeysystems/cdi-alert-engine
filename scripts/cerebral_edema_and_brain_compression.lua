---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Cerebral Edema and Brain Compression
---
--- This script checks an account to see if it matches the criteria for a cerebral edema and brain compression alert.
---
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
---------------------------------------------------------------------------------------------------------------------
---@diagnostic disable: unused-local, empty-block, unused-function -- Remove once the script is filled out



--------------------------------------------------------------------------------
--- Requires 
--------------------------------------------------------------------------------
local alerts = require("libs.common.alerts")
local links = require("libs.common.basic_links")
local codes = require("libs.common.codes")
local dates = require("libs.common.dates")
local discrete = require("libs.common.discrete_values")



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }
local subtitle = existing_alert and existing_alert.subtitle or nil



if not existing_alert or not existing_alert.validated then
    --------------------------------------------------------------------------------
    --- Header Variables and Helper Functions
    --------------------------------------------------------------------------------
    local result_links = {}
    local documented_dx_header = links.make_header_link("Documented Dx")
    local documented_dx_links = {}
    local laboratory_studies_header = links.make_header_link("Laboratory Studies")
    local laboratory_studies_links = {}
    local clinical_evidence_header = links.make_header_link("Clinical Evidence")
    local clinical_evidence_links = {}
    local treatment_and_monitoring_header = links.make_header_link("Treatment and Monitoring")
    local treatment_and_monitoring_links = {}

    --- @param link CdiAlertLink?
    local function add_documented_dx_link(link)
        table.insert(documented_dx_links, link)
    end
    --- @param link CdiAlertLink?
    local function add_lab_study_link(link)
        table.insert(laboratory_studies_links, link)
    end
    --- @param text string
    local function add_lab_study_text(text)
        table.insert(laboratory_studies_links, links.make_header_link(text))
    end
    --- @param link CdiAlertLink?
    local function add_clinical_evidence_link(link)
        table.insert(clinical_evidence_links, link)
    end
    --- @param code string
    --- @param text string
    local function add_clinical_evidence_code(code, text)
        add_clinical_evidence_link(links.get_code_link { code = code, text = text })
    end
    --- @param prefix string
    --- @param text string
    local function add_clinical_evidence_code_prefix(prefix, text)
        add_clinical_evidence_link(codes.get_code_prefix_link { prefix = prefix, text = text })
    end
    --- @param code_set string[]
    --- @param text string
    local function add_clinical_evidence_any_code(code_set, text)
        add_clinical_evidence_link(links.get_code_link { codes = code_set, text = text })
    end
    --- @param code string
    --- @param text string
    local function add_clinical_evidence_abstraction(code, text)
        add_clinical_evidence_link(links.get_abstraction_link { code = code, text = text })
    end
    --- @param link CdiAlertLink?
    local function add_treatment_and_monitoring_link(link)
        table.insert(treatment_and_monitoring_links, link)
    end
    local function compile_links()
        if #documented_dx_header.links > 0 then
            table.insert(result_links, documented_dx_header)
        end
        if #laboratory_studies_links > 0 then
            laboratory_studies_header.links = laboratory_studies_links
            table.insert(result_links, laboratory_studies_header)
        end
        if #clinical_evidence_links > 0 then
            clinical_evidence_header.links = clinical_evidence_links
            table.insert(result_links, clinical_evidence_header)
        end
        if #treatment_and_monitoring_links > 0 then
            treatment_and_monitoring_header.links = treatment_and_monitoring_links
            table.insert(result_links, treatment_and_monitoring_header)
        end
        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end


    --------------------------------------------------------------------------------
    --- Alert Variables 
    --------------------------------------------------------------------------------
    local alert_code_dictionary = {

    }
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)



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
        if not Result.validated then
            -- Normal Alert
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

