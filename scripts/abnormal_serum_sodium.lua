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
local alerts = require("libs.common.alerts")
local links = require("libs.common.basic_links")
local dates = require("libs.common.dates")
local discrete = require("libs.common.discrete_values")



--------------------------------------------------------------------------------
--- Setup
--------------------------------------------------------------------------------
local blood_glucose_dv_names = { "GLUCOSE (mg/dL)", "GLUCOSE" }
local blood_glucose_predicate = function(dv) return discrete.get_dv_value_number(dv) > 600 end
local blood_glucose_poc_dv_names = { "GLUCOSE ACCUCHECK (mg/dL)" }
local blood_glucose_poc_predicate = function(dv) return discrete.get_dv_value_number(dv) > 600 end
local sodium_dv_names = { "SODIUM (mmol/L)" }
local sodium_very_low_predicate = function(dv)
    return discrete.get_dv_value_number(dv) < 131 and dates.date_is_less_than_x_days_ago(dv.result_date, 7)
end
local sodium_low_predicate = function(dv)
    return discrete.get_dv_value_number(dv) < 132 and dates.date_is_less_than_x_days_ago(dv.result_date, 7)
end
local sodium_high_predicate = function(dv)
    return discrete.get_dv_value_number(dv) > 144 and dates.date_is_less_than_x_days_ago(dv.result_date, 7)
end
local sodium_very_high_predicate = function(dv)
    return discrete.get_dv_value_number(dv) > 145 and dates.date_is_less_than_x_days_ago(dv.result_date, 7)
end
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

local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }
local subtitle = existing_alert and existing_alert.subtitle or nil



if not existing_alert or not existing_alert.validated then
    --------------------------------------------------------------------------------
    --- Top-Level Link Header Variables
    --------------------------------------------------------------------------------
    local result_links = {}
    local labs_header = links.make_header_link("Laboratory Studies")
    local labs_links = {}
    local clinical_evidence_header = links.make_header_link("Clinical Evidence")
    local clinical_evidence_links = {}
    local serum_sodium_header = links.make_header_link("Serum Sodium")
    local serum_sodium_links = {}



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    local e870_code_link = links.get_code_link { code = "E870", text = "Hyperosmolality and Hypernatremia", seq = 12 }
    local e871_code_link = links.get_code_link { code = "E871", text = "Hypoosmolality and Hyponatremia", seq = 14 }

    --------------------------------------------------------------------------------
    --- Get Serum Sodium Links
    ---
    --- @param predicate function Filtering function
    ---
    --- @return CdiAlertLink[] Serum Sodium Links
    -------------------------------------------------------------------------------- 
    local function get_sodium_dv_links(predicate)
        return links.get_discrete_value_links {
            dvNames = sodium_dv_names,
            predicate = predicate,
            text = "Serum Sodium",
            maxPerValue = 99999
        }
    end

    local very_low_sodium_links = get_sodium_dv_links(sodium_very_low_predicate)
    local low_sodium_links = get_sodium_dv_links(sodium_low_predicate)
    local high_sodium_links = get_sodium_dv_links(sodium_high_predicate)
    local very_high_sodium_links = get_sodium_dv_links(sodium_very_high_predicate)

    local dextrose_medication_link =
        links.get_medication_link { cat = dextrose_medication_name, text = "Dextrose", seq = 1 }
    local dextrose_abstract_link =
        links.get_abstraction_link { code = "DEXTROSE_5_IN_WATER", text = "Dextrose", seq = 2 }
    local fluid_restriction_abstraction_link =
        links.get_abstraction_link { code = "FLUID_RESTRICTION", text = "Fluid Restriction", seq = 3 }
    local hypertonic_saline_medication_link =
        links.get_medication_link { cat = hypertonic_saline_medication_name, text = "Hypertonic Saline", seq = 4 }
    local hypertonic_saline_abstract_link =
        links.get_abstraction_link { code = "HYPERTONIC_SALINE", text = "Hypertonic Saline", seq = 5 }
    local hypotonic_solution_medication_link =
        links.get_medication_link { cat = hypotonic_solution_medication_name, text = "Hypotonic Solution", seq = 6 }
    local hypotonic_solution_abstract_link =
        links.get_abstraction_link { code = "HYPOTONIC_SOLUTION", text = "Hypotonic Solution", seq = 7 }



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

    elseif subtitle == possible_hypernatermia_subtitle and e870_code_link then
        -- Auto resolve Possible Hypernatremia Dx
        e870_code_link.link_text = "Autoresolved Code - " .. e870_code_link.link_text
        table.insert(clinical_evidence_header, e870_code_link)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to code no longer being assigned"
        Result.passed = true
        Result.validated = true

    elseif subtitle == possible_hyponatermia_subtitle and e871_code_link then
        -- Auto resolve Possible Hyponatremia Dx
        e871_code_link.link_text = "Autoresolved Code - " .. e871_code_link.link_text
        table.insert(clinical_evidence_header, e871_code_link)
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
        table.insert(clinical_evidence_header, e870_code_link)
        for _, link in ipairs(high_sodium_links) do
            link.link_text = "Autoresolved Evidence - " .. link.link_text
            table.insert(serum_sodium_links, link)
        end
        local review_high_sodium_link = links.make_header_link(review_high_sodium_link_text)
        review_high_sodium_link.is_validated = false
        table.insert(labs_links, review_high_sodium_link)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.passed = true
        Result.validated = true

    elseif
        subtitle == hyponatremia_lacking_supporting_evidence_subtitle and
        #low_sodium_links > 0 and e871_code_link
    then
        -- Auto resolve Hyponatremia Lacking Supporting Evidence
        e871_code_link.link_text = "Autoresolved Code - " .. e871_code_link.link_text
        table.insert(clinical_evidence_header, e871_code_link)
        for _, link in ipairs(low_sodium_links) do
            link.link_text = "Autoresolved Evidence - " .. link.link_text
            table.insert(serum_sodium_links, link)
        end
        local review_low_sodium_link = links.make_header_link(review_low_sodium_link_text)
        review_low_sodium_link.is_validated = false
        table.insert(labs_links, review_low_sodium_link)
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

    elseif e870_code_link and #high_sodium_links == 0 then
        -- Alert if hypernatremia is lacking supporting evidence
        local review_high_sodium_link = links.make_header_link(review_high_sodium_link_text)
        table.insert(labs_links, review_high_sodium_link)
        Result.subtitle = hypernatremia_lacking_supporting_evidence_subtitle
        Result.passed = true

    elseif e871_code_link and #low_sodium_links == 0 then
        -- Alert if hyponatremia is lacking supporting evidence
        local review_low_sodium_link = links.make_header_link(review_low_sodium_link_text)
        table.insert(labs_links, review_low_sodium_link)
        Result.subtitle = hyponatremia_lacking_supporting_evidence_subtitle
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Additional Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            local r4182_code_link =
                links.get_code_link { code = "R41.82", text = "Altered Level of Consciousness", seq = 1 }
            local altered_abs_link =
                links.get_abstraction_link {
                    code = "ALTERED_LEVEL_OF_CONSCIOUSNESS",
                    text = "Altered Level of Consciousness",
                    seq = 2
                }

            if r4182_code_link then
                table.insert(clinical_evidence_links, r4182_code_link)
                if altered_abs_link then
                    altered_abs_link.hidden = true
                    table.insert(clinical_evidence_links, altered_abs_link)
                end
            elseif altered_abs_link then
                table.insert(clinical_evidence_links, altered_abs_link)
            end

            table.insert(
                clinical_evidence_links,
                links.get_code_link { code = "F10.230", text = "Beer Potomania", seq = 3 }
            )
            table.insert(
                clinical_evidence_links,
                links.get_code_link { code = "R11.14", text = "Bilious Vomiting", seq = 4 }
            )
            table.insert(
                clinical_evidence_links,
                links.get_code_link {
                    codes = {
                        "I50.21", "I50.22", "I50.23", "I50.31", "I50.32", "I50.33", "I50.41",
                        "I50.42", "I50.43", "I50.811", "I50.812", "I50.813", "I50.814", "I50.82", "I50.83", "I50.84"
                    },
                    text = "Congestive Heart Failure (CHF)",
                    seq = 5,
                }
            )
            table.insert(
                clinical_evidence_links,
                links.get_code_link { code = "R11.15", text = "Cyclical Vomiting", seq = 6 }
            )
            table.insert(
                clinical_evidence_links,
                links.get_abstraction_value_link { code = "DIABETES_INSIPIDUS", text = "Diabetes Insipidus", seq = 7 }
            )
            table.insert(
                clinical_evidence_links,
                links.get_abstraction_link { code = "DIARRHEA", text = "Diarrhea", seq = 8 }
            )
            table.insert(
                clinical_evidence_links,
                links.get_code_link { code = "R41.0", text = "Disorientation", seq = 9 }
            )
            table.insert(
                clinical_evidence_links,
                links.get_code_link { code = "E86.0", text = "Dehydration", seq = 10 }
            )
            table.insert(
                clinical_evidence_links,
                links.get_code_link { code = "R53.83", text = "Fatigue", seq = 11 }
            )
            table.insert(
                clinical_evidence_links,
                links.get_abstraction_value_link {
                    code = "HYPEROSMOLAR_HYPERGLYCEMIA_SYNDROME",
                    text = "Hyperosmolar Hyperglycemic Syndrome",
                    seq = 13
                }
            )
            table.insert(
                clinical_evidence_links,
                links.get_code_link { code = "E86.1", text = "Hypovolemia", seq = 15 }
            )
            table.insert(
                clinical_evidence_links,
                links.get_code_link {
                    codes = {
                        "N17.0", "N17.1", "N17.2", "N18.1", "N18.2", "N18.30",
                        "N18.31", "N18.32", "N18.4", "N18.5", "N18.6"
                    },
                    text = "Kidney Failure",
                    seq = 16,
                }
            )
            table.insert(
                clinical_evidence_links,
                links.get_abstraction_link { code = "MUSCLE_CRAMPS", text = "Muscle Cramps", seq = 17 }
            )
            table.insert(
                clinical_evidence_links,
                links.get_code_link { code = "R63.1", text = "Polydipsia", seq = 18 }
            )
            table.insert(
                clinical_evidence_links,
                links.get_abstraction_link { code = "SEIZURE", text = "Seizure", seq = 19 }
            )
            table.insert(
                clinical_evidence_links,
                links.get_code_link {
                    codes = { "E05.01", "E05.11", "E05.21", "E05.41", "E05.81", "E05.91" },
                    text = "Thyrotoxic Crisis Storm Code",
                    seq = 21,
                }
            )
            table.insert(
                clinical_evidence_links,
                links.get_code_link { code = "E86.9", text = "Volume Depletion", seq = 22 }
            )
            table.insert(
                clinical_evidence_links,
                links.get_code_link { code = "R11.10", text = "Vomiting", seq = 23 }
            )
            table.insert(
                clinical_evidence_links,
                links.get_code_link { code = "R11.13", text = "Vomiting Fecal Matter", seq = 24 }
            )
            table.insert(
                clinical_evidence_links,
                links.get_code_link { code = "R11.11", text = "Vomiting Without Nausea", seq = 25 }
            )
            table.insert(
                clinical_evidence_links,
                links.get_abstraction_link { code = "WEAKNESS", text = "Muscle Weakness", seq = 26 }
            )

            local blood_glucose_links = links.get_discrete_value_links {
                dvNames = blood_glucose_dv_names,
                predicate = blood_glucose_predicate,
                text = "Blood Glucose",
                maxPerValue = 1,
            }
            table.insert(labs_links, blood_glucose_links)

            if #blood_glucose_links == 0 then
                table.insert(
                    labs_links,
                    links.get_discrete_value_link {
                        dvNames = blood_glucose_poc_dv_names,
                        predicate = blood_glucose_poc_predicate,
                        text = "Blood Glucose POC",
                        maxPerValue = 1,
                    }
                )
            end
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        if #labs_links > 0 then
            labs_header.links = labs_links
            table.insert(result_links, labs_header)
        end
        if #clinical_evidence_links > 0 then
            clinical_evidence_header.links = clinical_evidence_links
            table.insert(result_links, clinical_evidence_header)
        end
        if #serum_sodium_links > 0 then
            serum_sodium_header.links = serum_sodium_links
            table.insert(result_links, serum_sodium_header)
        end
        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end
end

