-----------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Abnormal Serum Sodium
---
--- This script checks an account to see if it matches the criteria for a abnormal serum sodium alert.
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
local codes = require "libs.common.codes" (Account)
local discrete = require "libs.common.discrete_values" (Account)
local medications = require "libs.common.medications" (Account)
local headers = require("libs.common.headers")(Account)



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local blood_glucose_dv_names = { "GLUCOSE (mg/dL)", "GLUCOSE" }
local blood_glucose_predicate = discrete.make_gt_predicate(600)
local blood_glucose_poc_dv_names = { "GLUCOSE ACCUCHECK (mg/dL)" }
local blood_glucose_poc_predicate = discrete.make_gt_predicate(600)
local sodium_dv_names = { "SODIUM (mmol/L)" }
local sodium_very_low_predicate = discrete.make_lt_predicate(131)
local sodium_low_predicate = discrete.make_lt_predicate(132)
local sodium_high_predicate = discrete.make_gt_predicate(144)
local sodium_very_high_predicate = discrete.make_gt_predicate(145)
local dextrose_medication_name = "Dextrose 5% in Water"
local hypertonic_saline_medication_name = "Hypertonic Saline"
local hypotonic_solution_medication_name = "Hypotonic Solution"
local both_codes_assigned_subtitle = "SIADH and Hyponatermia Both Assigned Seek Clarification"
local possible_hypernatermia_subtitle = "Possible Hypernatremia Dx"
local possible_hyponatermia_subtitle = "Possible Hyponatremia Dx"
local hypernatremia_lacking_supporting_evidence_subtitle = "Hypernatremia Lacking Supporting Evidence"
local hyponatremia_lacking_supporting_evidence_subtitle = "Hyponatremia Lacking Supporting Evidence"
local review_high_sodium_link_text = "Possible No High Serum Sodium Levels Were Found Please Review"
local review_low_sodium_link_text = "Possible No Low Serum Sodium Levels Were Found Please Review"



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
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 1)
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 2)
    local sodium_header = headers.make_header_builder("Serum Potassium", 3)

    local function compile_links()
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, sodium_header:build(true))
        Result.links = result_links
        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    local e870_code_link = codes.make_code_link("E870", "Hyperosmolality and Hypernatremia", 12)
    local e871_code_link = codes.make_code_link("E871", "Hypoosmolality and Hyponatremia", 14)

    local very_low_sodium_links = discrete.make_discrete_value_links(sodium_dv_names, "Serum Sodium", sodium_very_low_predicate)
    local low_sodium_links = discrete.make_discrete_value_links(sodium_dv_names, "Serum Sodium", sodium_low_predicate)
    local high_sodium_links = discrete.make_discrete_value_links(sodium_dv_names, "Serum Sodium", sodium_high_predicate)
    local very_high_sodium_links = discrete.make_discrete_value_links(sodium_dv_names, "Serum Sodium", sodium_very_high_predicate)

    local dextrose_medication_link = medications.make_medication_link(dextrose_medication_name, "Dextrose", 1)
    local dextrose_abstract_link = codes.make_abstraction_link("DEXTROSE_5_IN_WATER", "Dextrose", 2)
    local fluid_restriction_abstraction_link = codes.make_abstraction_link("FLUID_RESTRICTION", "Fluid Restriction", 3)
    local hypertonic_saline_medication_link = medications.make_medication_link(hypertonic_saline_medication_name, "Hypertonic Saline", 4)
    local hypertonic_saline_abstract_link = codes.make_abstraction_link("HYPERTONIC_SALINE", "Hypertonic Saline", 5)
    local hypotonic_solution_medication_link = medications.make_medication_link(hypotonic_solution_medication_name, "Hypotonic Solution", 6)
    local hypotonic_solution_abstract_link = codes.make_abstraction_link("HYPOTONIC_SOLUTION", "Hypotonic Solution", 7)



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if
        subtitle == both_codes_assigned_subtitle and (
            not Account:is_diagnosis_code_in_working_history("E22.2") or
            not Account:is_diagnosis_code_in_working_history("E87.1")
        )
    then
        -- Auto resolve SIADH and Hyponatremia both being assigned
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to code no longer being assigned"
        Result.passed = true
        Result.validated = true

    elseif
        subtitle == possible_hypernatermia_subtitle and
        e870_code_link
    then
        -- Auto resolve Possible Hypernatremia Dx
        e870_code_link.link_text = "Autoresolved Code - " .. e870_code_link.link_text
        clinical_evidence_header:add_link(e870_code_link)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to code no longer being assigned"
        Result.passed = true
        Result.validated = true

    elseif subtitle == possible_hyponatermia_subtitle and e871_code_link then
        -- Auto resolve Possible Hyponatremia Dx
        e871_code_link.link_text = "Autoresolved Code - " .. e871_code_link.link_text
        clinical_evidence_header:add_link(e871_code_link)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to code no longer being assigned"
        Result.passed = true
        Result.validated = true

    elseif
        subtitle == hypernatremia_lacking_supporting_evidence_subtitle and
        #high_sodium_links > 0 and
        e870_code_link
    then
        -- Auto resolve Hypernatremeia Lacking Supporting Evidence
        e870_code_link.link_text = "Autoresolved Code - " .. e870_code_link.link_text
        clinical_evidence_header:add_link(e870_code_link)
        for _, link in ipairs(high_sodium_links) do
            link.link_text = "Autoresolved Evidence - " .. link.link_text
            sodium_header:add_link(link)
        end
        local review_high_sodium_link = links.make_header_link(review_high_sodium_link_text)
        review_high_sodium_link.is_validated = false
        laboratory_studies_header:add_link(review_high_sodium_link)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.passed = true
        Result.validated = true

    elseif
        subtitle == hyponatremia_lacking_supporting_evidence_subtitle and
        #low_sodium_links > 0 and
        e871_code_link
    then
        -- Auto resolve Hyponatremia Lacking Supporting Evidence
        e871_code_link.link_text = "Autoresolved Code - " .. e871_code_link.link_text
        clinical_evidence_header:add_link(e871_code_link)
        for _, link in ipairs(low_sodium_links) do
            link.link_text = "Autoresolved Evidence - " .. link.link_text
            sodium_header:add_link(link)
        end
        local review_low_sodium_link = links.make_header_link(review_low_sodium_link_text)
        review_low_sodium_link.is_validated = false
        laboratory_studies_header:add_link(review_low_sodium_link)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.passed = true
        Result.validated = true

    elseif
        Account:is_diagnosis_code_in_working_history("E22.2") and
        Account:is_diagnosis_code_in_working_history("E87.1")
    then
        -- Alert if both SIADH (E22.2) and Hyponatermia (E87.1) are cdi assigned (in working history)
        Result.subtitle = both_codes_assigned_subtitle
        Result.passed = true

    elseif
        not e870_code_link and
        #very_high_sodium_links > 1 and (
            dextrose_medication_link or
            dextrose_abstract_link or
            hypotonic_solution_medication_link or
            hypotonic_solution_abstract_link
        )
    then
        -- Alert if possible hypernatremia
        Result.subtitle = possible_hypernatermia_subtitle
        Result.passed = true

    elseif
        not e871_code_link and
        #very_low_sodium_links > 1 and (
            hypertonic_saline_medication_link or
            hypertonic_saline_abstract_link or
            fluid_restriction_abstraction_link
        )
    then
        -- Alert if possible hyponatremia
        Result.subtitle = possible_hyponatermia_subtitle
        Result.passed = true

    elseif
        e870_code_link and
        #high_sodium_links == 0
    then
        -- Alert if hypernatremia is lacking supporting evidence
        laboratory_studies_header:add_text_link(review_high_sodium_link_text)
        Result.subtitle = hypernatremia_lacking_supporting_evidence_subtitle
        Result.passed = true

    elseif
        e871_code_link and
        #low_sodium_links == 0
    then
        -- Alert if hyponatremia is lacking supporting evidence
        laboratory_studies_header:add_text_link(review_low_sodium_link_text)
        Result.subtitle = hyponatremia_lacking_supporting_evidence_subtitle
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Additional Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            local r4182_code_link = codes.make_code_link("R41.82", "Altered Level of Consciousness", 1)
            local altered_abs_link = codes.make_abstraction_link("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level of Consciousness", 2)

            if r4182_code_link then
                clinical_evidence_header:add_link(r4182_code_link)
                if altered_abs_link then
                    altered_abs_link.hidden = true
                    clinical_evidence_header:add_link(altered_abs_link)
                end
            elseif altered_abs_link then
                clinical_evidence_header:add_link(altered_abs_link)
            end

            clinical_evidence_header:add_code_link("F10.230", "Beer Potomania")
            clinical_evidence_header:add_code_link("R11.14", "Bilious Vomiting")
            clinical_evidence_header:add_code_one_of_link(
                {
                    "I50.21", "I50.22", "I50.23", "I50.31", "I50.32", "I50.33", "I50.41",
                    "I50.42", "I50.43", "I50.811", "I50.812", "I50.813", "I50.814", "I50.82", "I50.83", "I50.84"
                },
                "Congestive Heart Failure (CHF)"
            )
            clinical_evidence_header:add_code_link("R11.15", "Cyclical Vomiting")
            clinical_evidence_header:add_abstraction_link_with_value("DIABETES_INSIPIDUS", "Diabetes Insipidus")
            clinical_evidence_header:add_abstraction_link("DIARRHEA", "Diarrhea")
            clinical_evidence_header:add_code_link("R41.0", "Disorientation")
            clinical_evidence_header:add_code_link("E86.0", "Dehydration")
            clinical_evidence_header:add_code_link("R53.83", "Fatigue")
            clinical_evidence_header:add_abstraction_link_with_value(
                "HYPEROSMOLAR_HYPERGLYCEMIA_SYNDROME",
                "Hyperosmolar Hyperglycemic Syndrome"
            )
            clinical_evidence_header:add_code_link("E86.1", "Hypovolemia")
            clinical_evidence_header:add_code_one_of_link(
                {
                    "N17.0", "N17.1", "N17.2", "N18.1", "N18.2", "N18.30",
                    "N18.31", "N18.32", "N18.4", "N18.5", "N18.6"
                },
                "Kidney Failure"
            )
            clinical_evidence_header:add_abstraction_link("MUSCLE_CRAMPS", "Muscle Cramps")
            clinical_evidence_header:add_code_link("R63.1", "Polydipsia")
            clinical_evidence_header:add_abstraction_link("SEIZURE", "Seizure")
            clinical_evidence_header:add_code_one_of_link(
                { "E05.01", "E05.11", "E05.21", "E05.41", "E05.81", "E05.91" },
                "Thyrotoxic Crisis Storm Code"
            )
            clinical_evidence_header:add_code_link("E86.9", "Volume Depletion")
            clinical_evidence_header:add_code_link("R11.10", "Vomiting")
            clinical_evidence_header:add_code_link("R11.13", "Vomiting Fecal Matter")
            clinical_evidence_header:add_code_link("R11.11", "Vomiting Without Nausea")
            clinical_evidence_header:add_abstraction_link("WEAKNESS", "Muscle Weakness")

            local blood_glucose_links = discrete.make_discrete_value_links(blood_glucose_dv_names, "Blood Glucose", blood_glucose_predicate, 1)
            laboratory_studies_header:add_links(blood_glucose_links)

            if #blood_glucose_links == 0 then
                laboratory_studies_header:add_discrete_value_one_of_link(blood_glucose_poc_dv_names, "Blood Glucose", blood_glucose_poc_predicate)
            end
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

