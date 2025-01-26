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
local alerts = require("libs.common.alerts")(Account)
local links = require("libs.common.basic_links")(Account)
local dates = require("libs.common.dates")
local codes = require "libs.common.codes" (Account)
local discrete = require "libs.common.discrete_values" (Account)
local medications = require "libs.common.medications" (Account)
local headers = require("libs.common.headers")(Account)
local lists = require "libs.common.lists"



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local potassium_dv_names = { "POTASSIUM (mmol/L)" }
local potassium_very_low_predicate = discrete.make_lt_predicate(3.1)
local potassium_low_predicate = discrete.make_lt_predicate(3.4)
local potassium_high_predicate = discrete.make_gt_predicate(5.1)
local potassium_very_high_predicate = discrete.make_gt_predicate(5.4)
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



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = Result.script_name }
local subtitle = existing_alert and existing_alert.subtitle or nil



if not existing_alert or not existing_alert.validated then
    --------------------------------------------------------------------------------
    --- Header Variables and Helper Functions
    --------------------------------------------------------------------------------
    local result_links = {}
    local documented_dx_header = headers.make_header_builder("Documented Dx", 1)
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 2)
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 3)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 4)
    local potassium_header = headers.make_header_builder("Serum Potassium", 5)

    local function compile_links()
        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))
        table.insert(result_links, potassium_header:build(true))
        Result.links = result_links
        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    local e875_code_link = codes.make_code_link("E87.5", "Hyperkalemia Fully Specified Code")
    local e876_code_link = codes.make_code_link("E87.6", "Hypokalemia Fully Specified Code")

    local serum_potassium_dx_very_low_links =
        discrete.make_discrete_value_links(potassium_dv_names, "Serum Potassium", potassium_very_low_predicate)
    local serum_potassium_dv_low_links =
        discrete.make_discrete_value_links(potassium_dv_names, "Serum Potassium", potassium_low_predicate)
    local serum_potassium_dv_high_links =
        discrete.make_discrete_value_links(potassium_dv_names, "Serum Potassium", potassium_high_predicate)
    local serum_potassium_dv_very_high_links =
        discrete.make_discrete_value_links(potassium_dv_names, "Serum Potassium", potassium_very_high_predicate)

    local dextrose_medication_link = medications.make_medication_link(dextrose_medication_name, "Dextrose", 1)
    local hemodialysis_codes_links = codes.make_code_links({ "5A1D70Z", "5A1D80Z", "5A1D90Z" }, "Hemodialysis", 2)
    local insulin_medication_link = medications.make_medication_link(
        insulin_medication_name,
        "Insulin",
        3,
        function(med)
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
                dates.date_is_less_than_x_days_ago(med.start_date, 365)
            )
        end
    )
    local kayexalate_med_link =
        medications.make_medication_link(kayexalate_medication_name, "Kayexalate", 4)
    local potassium_replacement_med_link =
        medications.make_medication_link(potassium_replacement_medication_name, "Potassium Replacement", 5)
    local potassium_chloride_abs_link =
        codes.make_abstraction_link("POTASSIUM_CHLORIDE", "Potassium Chloride Absorption", 6)
    local potassium_phosphate_abs_link =
        codes.make_abstraction_link("POTASSIUM_PHOSPHATE", "Potassium Phosphate Absorption", 7)
    local potassium_bicarbonate_abs_link =
        codes.make_abstraction_link("POTASSIUM_BICARBONATE", "Potassium Bicarbonate Absorption", 8)



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if subtitle == possible_hyperkalemia_subtitle and e875_code_link then
        -- Auto resolve Hyperkalemia alert
        e875_code_link.link_text = "Autoresolved Code - " .. e875_code_link.link_text
        documented_dx_header:add_link(e875_code_link)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true
    elseif subtitle == possible_hypokalemia_subtitle and e876_code_link then
        -- Auto resolve Hypokalemia alert
        e876_code_link.link_text = "Autoresolved Code - " .. e876_code_link.link_text
        documented_dx_header:add_link(e876_code_link)
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
        documented_dx_header:add_link(e875_code_link)
        for _, link in ipairs(serum_potassium_dv_high_links) do
            link.link_text = "Autoresolved Evidence - " .. link.link_text
            potassium_header:add_link(link)
        end
        local review_high_potassium_link = links.make_header_link(review_high_potassium_link_text)
        review_high_potassium_link.is_validated = false
        laboratory_studies_header:add_link(review_high_potassium_link)

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
        documented_dx_header:add_link(e876_code_link)
        for _, link in ipairs(serum_potassium_dv_low_links) do
            link.link_text = "Autoresolved Evidence - " .. link.link_text
            potassium_header:add_link(link)
        end
        local review_low_potassium_link = links.make_header_link(review_low_potassium_link_text)
        review_low_potassium_link.is_validated = false
        laboratory_studies_header:add_link(review_low_potassium_link)

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
            potassium_header:add_link(link)
        end
        Result.subtitle = possible_hyperkalemia_subtitle
        Result.passed = true
    elseif
        not e876_code_link and
        #serum_potassium_dx_very_low_links > 1 and lists.some {
            potassium_replacement_med_link,
            potassium_chloride_abs_link,
            potassium_phosphate_abs_link,
            potassium_bicarbonate_abs_link
        }
    then
        -- Create Hypokalemia alert
        for _, link in ipairs(serum_potassium_dv_low_links) do
            potassium_header:add_link(link)
        end
        Result.subtitle = possible_hypokalemia_subtitle
        Result.passed = true
    elseif e875_code_link and #serum_potassium_dv_high_links == 0 then
        -- Create alert for Hyperkalemia coded, but lacking evidence in labs

        documented_dx_header:add_link(e875_code_link)
        laboratory_studies_header:add_text_link(review_high_potassium_link_text)

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
        documented_dx_header:add_link(e876_code_link)
        laboratory_studies_header:add_text_link(review_low_potassium_link_text)

        Result.subtitle = hypokalemia_lacking_evidence_subtitle
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Additional Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            clinical_evidence_header:add_code_link("E27.1", "Addison's Disease")
            clinical_evidence_header:add_code_prefix_link("E24%.", "Cushing's Syndrome")
            clinical_evidence_header:add_abstraction_link("DIARRHEA", "Diarrhea")
            clinical_evidence_header:add_abstraction_link("HYPERKALEMIA_EKG_CHANGES", "EKG Changes")
            clinical_evidence_header:add_abstraction_link("HYPOKALEMIA_EKG_CHANGES", "EKG Changes")
            clinical_evidence_header:add_code_link("R53.83", "Fatigue")
            clinical_evidence_header:add_abstraction_link("HEART_PALPITATIONS", "Heart Palpitations")
            clinical_evidence_header:add_code_one_of_link(
                {
                    "N17.0", "N17.1", "N17.2", "N18.30", "N18.31", "N18.32", "N18.1", "N18.2", "N18.30", "N18.31",
                    "N18.32", "N18.4", "N18.5", "N18.6"
                },
                "Kidney Failure"
            )
            clinical_evidence_header:add_abstraction_link("MUSCLE_CRAMPS", "Muscle Cramps")
            clinical_evidence_header:add_abstraction_link("WEAKNESS", "Muscle Weakness")
            clinical_evidence_header:add_abstraction_link("VOMITING", "Vomiting")
            clinical_evidence_header:add_link(dextrose_medication_link)
            clinical_evidence_header:add_links(unpack(hemodialysis_codes_links))
            clinical_evidence_header:add_link(insulin_medication_link)
            clinical_evidence_header:add_link(kayexalate_med_link)
            clinical_evidence_header:add_link(potassium_replacement_med_link)
            clinical_evidence_header:add_link(potassium_chloride_abs_link)
            clinical_evidence_header:add_link(potassium_phosphate_abs_link)
            clinical_evidence_header:add_link(potassium_bicarbonate_abs_link)
        end



        --------------------------------------------------------------------------------
        --- Result Finalization
        --------------------------------------------------------------------------------
        compile_links()
    end
end
