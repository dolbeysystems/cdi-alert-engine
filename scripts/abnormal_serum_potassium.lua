-----------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Abnormal Serum Potassium
---
--- This script checks an account to see if it matches the criteria for an abnormal serum potassium alert.
---
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
-----------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Requires 
--------------------------------------------------------------------------------
local alerts = require("libs.common.alerts")
local codes = require("libs.common.codes")
local links = require("libs.common.basic_links")
local dates = require("libs.common.dates")
local discrete = require("libs.common.discrete_values")



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local potassium_dv_names = { "POTASSIUM (mmol/L)" }
local potassium_very_low_predicate = function(dv)
    return discrete.get_dv_value_number(dv) < 3.1 and dates.date_is_less_than_x_days_ago(dv.result_date, 7)
end
local potassium_low_predicate = function(dv)
    return discrete.get_dv_value_number(dv) < 3.4 and dates.date_is_less_than_x_days_ago(dv.result_date, 7)
end
local potassium_high_predicate = function(dv)
    return discrete.get_dv_value_number(dv) > 5.1 and dates.date_is_less_than_x_days_ago(dv.result_date, 7)
end
local potassium_very_high_predicate = function(dv)
    return discrete.get_dv_value_number(dv) > 5.4 and dates.date_is_less_than_x_days_ago(dv.result_date, 7)
end
local dextrose_medication_name = "Dextrose 5% In Water"
local insulin_medication_name = "Insulin"
local kayexalate_medication_name = "Kayexalate"
local potassium_replacement_medication_name = "Potassium Replacement"
local possible_hyperkalemia_subtitle = "Possible Hyperkalemia Dx"
local possible_hypokalemia_subtitle = "Possible Hypokalemia Dx"
local hyperkalemia_lacking_evidence_subtitle = "Hyperkalemia Dx Documented Possibly Lacking Supporting Evidence"
local hypokalemia_lacking_evidence_subtitle = "Hypokalemia Dx Documented Possibly Lacking Supporting Evidence"
local review_high_potassium_link_text = "Possible No High Serum Potassium Levels Were Found Please Review"
local review_low_potassium_link_text = "Possible No Low Serum Potassium Levels Were Found Please Review"

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
    local potassium_header = links.make_header_link("Serum Potassium")
    local potassium_links = {}

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
    --- @param link CdiAlertLink?
    local function add_potassium_link(link)
        table.insert(potassium_links, link)
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
        if #potassium_links > 0 then
            potassium_header.links = potassium_links
            table.insert(result_links, potassium_header)
        end
        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    local e875_code_link = links.get_code_link { code = "E87.5", text = "Hyperkalemia Fully Specified Code" }
    local e876_code_link = links.get_code_link { code = "E87.6", text = "Hypokalemia Fully Specified Code" }

    --------------------------------------------------------------------------------
    --- Potassium Dv Link Retrieval Function
    ---
    --- @param dv_predicate function The predicate to filter the discrete values
    ---
    --- @return CdiAlertLink[] The discrete value links
    --------------------------------------------------------------------------------
    local function get_potassium_dv_links(dv_predicate)
        return links.get_discrete_value_links {
            discreteValueNames = potassium_dv_names,
            text = "Serum Potassium",
            predicate = dv_predicate,
        }
    end

    local serum_potassium_dx_very_low_links = get_potassium_dv_links(potassium_very_low_predicate)
    local serum_potassium_dv_low_links = get_potassium_dv_links(potassium_low_predicate)
    local serum_potassium_dv_high_links = get_potassium_dv_links(potassium_high_predicate)
    local serum_potassium_dv_very_high_links = get_potassium_dv_links(potassium_very_high_predicate)

    local dextrose_medication_link = links.get_medication_link {
        cat = dextrose_medication_name,
        text = "Dextrose",
        seq = 1,
    }
    local hemodialysis_codes_links = links.get_code_links {
        codes = { "5A1D70Z", "5A1D80Z", "5A1D90Z" },
        text = "Hemodialysis",
        seq = 2,
    }
    local insulin_medication_link = links.get_medication_link {
        cat = insulin_medication_name,
        text = "Insulin",
        predicate = function(med)
            local route_appropriate =
                med.route ~= nil and
                (
                    string.find(med.route, "%bIntravenous%b") ~= nil or
                    string.find(med.route, "%bIV Push%b") ~= nil
                )
            local dosage = med.dosage and tonumber(string.gsub(med.dosage, "[^%d.]", ""))
            return (
                route_appropriate and
                dosage ~= nil and dosage == 10 and
                dates.DateIsLessThanXDaysAgo(med.start_date, 365)
            )
        end,
        seq = 3,
    }
    local kayexalate_med_link =
        links.get_medication_link {
            cat = kayexalate_medication_name,
            text = "Kayexalate",
            seq = 4
        }
    local potassium_replacement_med_link =
        links.get_medication_link {
            cat = potassium_replacement_medication_name,
            text = "Potassium Replacement",
            seq = 5
        }
    local potassium_chloride_abs_link =
        links.get_abstraction_value_link {
            code = "POTASSIUM_CHLORIDE",
            text = "Potassium Chloride Absorption",
            seq = 6
        }
    local potassium_phosphate_abs_link =
        links.get_abstraction_value_link {
            code = "POTASSIUM_PHOSPHATE",
            text = "Potassium Phosphate Absorption",
            seq = 7
        }
    local potassium_bicarbonate_abs_link =
        links.get_abstraction_value_link {
            code = "POTASSIUM_BICARBONATE",
            text = "Potassium Bicarbonate Absorption",
            seq = 8
        }



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if subtitle == possible_hyperkalemia_subtitle and e875_code_link then
        -- Auto resolve Hyperkalemia alert
        e875_code_link.link_text = "Autoresolved Code - " .. e875_code_link.link_text
        add_documented_dx_link(e875_code_link)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif subtitle == possible_hypokalemia_subtitle and e876_code_link then
        -- Auto resolve Hypokalemia alert
        e876_code_link.link_text = "Autoresolved Code - " .. e876_code_link.link_text
        add_documented_dx_link(e876_code_link)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        subtitle == hyperkalemia_lacking_evidence_subtitle and
        e875_code_link and
        #serum_potassium_dv_high_links > 1
    then
        -- Auto resolve Hyperkalemia possibly lacking supporting evidence
        e875_code_link.link_text = "Autoresolved Evidence - " .. e875_code_link.link_text
        add_documented_dx_link(e875_code_link)
        for _, link in ipairs(serum_potassium_dv_high_links) do
            link.link_text = "Autoresolved Evidence - " .. link.link_text
            add_potassium_link(link)
        end
        local review_high_potassium_link = links.make_header_link(review_high_potassium_link_text)
        review_high_potassium_link.is_validated = false
        add_potassium_link(review_high_potassium_link)

        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        subtitle == hypokalemia_lacking_evidence_subtitle and
        e876_code_link and
        #serum_potassium_dv_low_links > 1
    then
        -- Auto resolve Hypokalemia possibly lacking supporting evidence
        e876_code_link.link_text = "Autoresolved Evidence - " .. e876_code_link.link_text
        add_documented_dx_link(e876_code_link)
        for _, link in ipairs(serum_potassium_dv_low_links) do
            link.link_text = "Autoresolved Evidence - " .. link.link_text
            add_potassium_link(link)
        end
        local review_low_potassium_link = links.make_header_link(review_low_potassium_link_text)
        review_low_potassium_link.is_validated = false
        add_lab_study_link(review_low_potassium_link)

        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.validated = true
        Result.passed = true

    elseif not
        e875_code_link and
        #serum_potassium_dv_very_high_links > 1
        and (
            kayexalate_med_link or
            (insulin_medication_link and dextrose_medication_link) or
            #hemodialysis_codes_links > 1
        )
    then
        -- Create Hyperkalemia alert
        for _, link in ipairs(serum_potassium_dv_high_links) do
            add_potassium_link(link)
        end
        Result.subtitle = possible_hyperkalemia_subtitle
        Result.passed = true

    elseif
        not e876_code_link and
        #serum_potassium_dx_very_low_links > 1 and (
            potassium_replacement_med_link or
            potassium_chloride_abs_link or
            potassium_phosphate_abs_link or
            potassium_bicarbonate_abs_link
        )
    then
        -- Create Hypokalemia alert
        for _, link in ipairs(serum_potassium_dv_low_links) do
            add_potassium_link(link)
        end
        Result.subtitle = possible_hypokalemia_subtitle
        Result.passed = true

    elseif e875_code_link and #serum_potassium_dv_high_links == 0 then
        -- Create alert for Hyperkalemia coded, but lacking evidence in labs
        add_documented_dx_link(e875_code_link)
        add_lab_study_text(review_high_potassium_link_text)

        Result.subtitle = hyperkalemia_lacking_evidence_subtitle
        Result.passed = true

    elseif
        e876_code_link and
        #serum_potassium_dv_low_links == 0 and
        not potassium_replacement_med_link and
        not potassium_chloride_abs_link and
        not potassium_phosphate_abs_link and
        not potassium_bicarbonate_abs_link
    then
        -- Create alert for Hypokalemia coded, but lacking evidence in labs, medications or abstractions
        add_documented_dx_link(e876_code_link)
        add_lab_study_text(review_low_potassium_link_text)

        Result.subtitle = hyperkalemia_lacking_evidence_subtitle
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Additional Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            add_clinical_evidence_code("E27.1", "Addison's Disease")
            add_clinical_evidence_code_prefix("E24%.", "Cushing's Syndrome")
            add_clinical_evidence_abstraction("DIARRHEA", "Diarrhea")
            add_clinical_evidence_abstraction("HYPERKALEMIA_EKG_CHANGES", "EKG Changes")
            add_clinical_evidence_abstraction("HYPOKALEMIA_EKG_CHANGES", "EKG Changes")
            add_clinical_evidence_code("R53.83", "Fatigue")
            add_clinical_evidence_abstraction("HEART_PALPITATIONS", "Heart Palpitations")
            add_clinical_evidence_any_code(
                {
                    "N17.0", "N17.1", "N17.2", "N18.30", "N18.31", "N18.32", "N18.1", "N18.2", "N18.30", "N18.31",
                    "N18.32", "N18.4", "N18.5", "N18.6"
                },
                "Kidney Failure"
            )
            add_clinical_evidence_abstraction("MUSCLE_CRAMPS", "Muscle Cramps")
            add_clinical_evidence_abstraction("WEAKNESS", "Muscle Weakness")
            add_clinical_evidence_abstraction("VOMITING", "Vomiting")

            add_treatment_and_monitoring_link(dextrose_medication_link)
            add_treatment_and_monitoring_link(hemodialysis_codes_links)
            add_treatment_and_monitoring_link(insulin_medication_link)
            add_treatment_and_monitoring_link(kayexalate_med_link)
            add_treatment_and_monitoring_link(potassium_replacement_med_link)
            add_treatment_and_monitoring_link(potassium_chloride_abs_link)
            add_treatment_and_monitoring_link(potassium_phosphate_abs_link)
            add_treatment_and_monitoring_link(potassium_bicarbonate_abs_link)
        end



        --------------------------------------------------------------------------------
        --- Result Finalization 
        --------------------------------------------------------------------------------
        compile_links()
    end
end
