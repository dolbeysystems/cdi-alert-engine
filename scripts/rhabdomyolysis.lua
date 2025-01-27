---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Rhabdomyolysis
---
--- This script checks an account to see if it matches the criteria for a rhabdomyolysis alert.
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
local discrete = require "libs.common.discrete_values" (Account)
local headers = require("libs.common.headers")(Account)



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local dv_aldolase = { "ALDOLASE" }
local calc_aldolase1 = discrete.make_gt_predicate(7.7)
local dv_ckmb = { "CKMB (ng/mL)" }
local calc_ckmb1 = discrete.make_gt_predicate(5)
local dv_ckmb_index = { "" }
local calc_ckmb_index1 = discrete.make_gt_predicate(2.5)
local dv_glasgow_coma_scale = { "3.5 Neuro Glasgow Score" }
local calc_glasgow_coma_scale1 = discrete.make_lt_predicate(15)
local dv_heart_rate = {
    "Heart Rate cc (bpm)",
    "3.5 Heart Rate (Apical) (bpm)",
    "3.5 Heart Rate (Other) (bpm)",
    "3.5 Heart Rate (Radial) (bpm)",
    "SCC Monitor Pulse (bpm)"
}
local calc_heart_rate1 = discrete.make_gt_predicate(90)
local dv_kinase = { "CPK (U/L)" }
local calc_greater_kinase = discrete.make_gt_predicate(1500)
local calc_lesser_kinase = discrete.make_gt_predicate(308)
local dv_map = { "Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)" }
local calc_map1 = discrete.make_lt_predicate(70)
local dv_sbp = { "SBP 3.5 (No Calculation) (mm Hg)" }
local calc_sbp1 = discrete.make_lt_predicate(90)
local dv_serum_blood_urea_nitrogen = { "BUN (mg/dL)" }
local calc_serum_blood_urea_nitrogen1 = discrete.make_gt_predicate(23)
local dv_serum_creatinine = { "CREATININE (mg/dL)", "CREATININE SERUM (mg/dL)" }
local calc_serum_creatinine1 = discrete.make_gt_predicate(1.3)
local dv_serum_potassium = { "POTASSIUM (mmol/L)" }
local calc_serum_potassium1 = discrete.make_gt_predicate(5.1)
local dv_temperature = { "Temperature Degrees C 3.5 (degrees C)", "Temperature  Degrees C 3.5 (degrees C)",
    "TEMPERATURE (C)" }
local calc_temperature1 = discrete.make_gt_predicate(38.3)
local calc_temperature2 = discrete.make_lt_predicate(36.0)



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = Result.script_name }
local subtitle = existing_alert and existing_alert.subtitle or nil
local trigger_alert =
    existing_alert and
    (existing_alert.outcome ~= "AUTORESOLVED" or existing_alert.reason ~= "Previously Autoresolved")

--------------------------------------------------------------------------------
--- Alert Variables
--------------------------------------------------------------------------------
local alert_code_dictionary = {
    ["M62.82"] = "Rhabdomyolysis",
    ["T79.6XXA"] = "Traumatic ischemia of muscle, initial encounter (Truamatic Rhabdomyolysis)",
    ["T79.6XXD"] = "Traumatic ischemia of muscle, subsequent encounter (Truamatic Rhabdomyolysis)",
    ["T79.6XXS"] = "Traumatic ischemia of muscle, sequela (Truamatic Rhabdomyolysis)"
}
local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)


if
    not (existing_alert and existing_alert.validated) or
    (
        existing_alert and
        existing_alert.outcome == "AUTORESOLVED" and
        existing_alert.validated and
        #account_alert_codes > 1
    )
then
    --------------------------------------------------------------------------------
    --- Header Variables and Helper Functions
    --------------------------------------------------------------------------------
    local result_links = {}
    local documented_dx_header = headers.make_header_builder("Documented Dx", 1)
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 2)
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 3)
    local vital_signs_intake_header = headers.make_header_builder("Vital Signs/Intake", 4)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 5)
    local contributing_dx_header = headers.make_header_builder("Contributing Dx", 6)

    local function compile_links()
        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, contributing_dx_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))
        table.insert(result_links, vital_signs_intake_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end





    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Negations
    local negation_kidney_failure = codes.make_code_one_of_link(
        { "N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6" },
        "Kidney Failure Codes"
    )

    -- Labs
    local greater_kinase_dv = discrete.make_discrete_value_link(dv_kinase, "Creatine Kinase", calc_greater_kinase)
    local lesser_kinase_dv = discrete.make_discrete_value_link(dv_kinase, "Creatine Kinase", calc_lesser_kinase)



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------

    -- TODO: The following two conditions seem to cause a loop. Lack of evidence depends on autoresolve depends on lack of evidence

    if subtitle == "Rhabdomyolysis Dx Lacking Supporting Evidence" and lesser_kinase_dv then
        lesser_kinase_dv.link_text = lesser_kinase_dv.link_text ..
            " - Autoresolved due to Evidence Existing on the Account"
        laboratory_studies_header:add_link(lesser_kinase_dv)

        Result.passed = true
        Result.validated = true
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Evidence Existing on the Account"
    elseif trigger_alert and #account_alert_codes == 1 and not lesser_kinase_dv then
        for _, code in ipairs(account_alert_codes) do
            local desc = alert_code_dictionary[code]
            local temp_code = codes.make_code_link(code, desc)
            documented_dx_header:add_link(temp_code)
        end
        Result.subtitle = "Rhabdomyolysis Dx Lacking Supporting Evidence"
        Result.passed = true
    elseif #account_alert_codes > 1 then
        for _, code in ipairs(account_alert_codes) do
            local desc = alert_code_dictionary[code]
            local temp_code = codes.make_code_link(code, desc)
            documented_dx_header:add_link(temp_code)
        end
        -- TODO: This isn't checking if the existing alert is AUTORESOLVED/validated (see atrial_fibrillation.lua for an example).
        if existing_alert and existing_alert.validated then
            Result.validated = false
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
        end
        Result.passed = true
        Result.subtitle = "Conflicting Rhabdomyolysis Dx Codes - " .. table.concat(account_alert_codes, ", ")
    elseif subtitle == "Possible Rhabdomyolysis Dx" and #account_alert_codes > 0 then
        for _, code in ipairs(account_alert_codes) do
            local desc = alert_code_dictionary[code]
            local temp_code = codes.make_code_link(code, desc)
            if temp_code then
                documented_dx_header:add_link(temp_code)
                break
            end
        end
        Result.validated = true
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Dx on the Account"
        Result.passed = true
    elseif trigger_alert and #account_alert_codes == 0 and greater_kinase_dv then -- TODO: impossible condition, see above
        Result.subtitle = "Possible Rhabdomyolysis Dx"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Clinical Evidence
            clinical_evidence_header:add_code_one_of_link(
                { "N17.0", "N17.1", "N17.2", "N17.8", "N17.9" },
                "Acute Kidney Failure"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "I46.2", "I46.8", "I46.9" },
                "Cardiac Arrest"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "F14.920", "F14.921", "F14.922", "F14.929" },
                "Cocaine Intoxication"
            )
            clinical_evidence_header:add_abstraction_link("DARK_COLORED_URINE", "Dark Colored Urine")
            clinical_evidence_header:add_code_link("R41.0", "Disorientation")
            clinical_evidence_header:add_code_prefix_link("D65%.", "Disseminated Intravascular Coagulation (DIC)")
            clinical_evidence_header:add_code_one_of_link(
                {
                    "W06", "W07", "W08", "W09.0", "W09.1", "W09.2", "W09.8", "W10.0", "W10.1", "W10.2", "W11", "W12",
                    "W13.0", "W13.2", "W13.3", "W13.4", "W13.8", "W13.9", "W14", "W15", "W17.0", "W17.2", "W17.3",
                    "W17.4", "W17.81", "W17.82", "W17.89", "W18.00", "W18.01", "W18.02", "W18.09", "W18.11", "W18.12",
                    "W18.2", "W18.30", "W18.31", "W18.39", "W19"
                },
                "Fall"
            )
            clinical_evidence_header:add_code_link("R53.83", "Fatigue")
            clinical_evidence_header:add_abstraction_link("FLUID_BOLUS", "Fluid Bolus")
            clinical_evidence_header:add_code_link("R57.1", "Hypovolemic Shock")
            clinical_evidence_header:add_abstraction_link("MUSCLE_CRAMPS", "Muscle Cramps")
            clinical_evidence_header:add_code_link("M79.10", "Myalgia")
            clinical_evidence_header:add_code_link("R82.1", "Myoglobinuria")
            clinical_evidence_header:add_abstraction_link("LOW_URINE_OUTPUT", "Oliguria")
            clinical_evidence_header:add_code_link("R29.6", "Repeated Falls")
            clinical_evidence_header:add_code_link("R56.9", "Seizure")
            clinical_evidence_header:add_code_link("E86.0", "Severe Dehydration")
            clinical_evidence_header:add_code_link("R57.9", "Shock")
            clinical_evidence_header:add_code_one_of_link(
                { "F15.120", "F15.121", "F15.122", "F15.129" },
                "Stimulant Intoxication"
            )
            clinical_evidence_header:add_code_link("E86.9", "Volume Depleted")
            clinical_evidence_header:add_code_link("R11.10", "Vomiting")
            clinical_evidence_header:add_abstraction_link("WEAKNESS", "Weakness")

            -- Contributing Dx
            contributing_dx_header:add_code_prefix_link("T79%.A", "Compartment Syndrome")
            contributing_dx_header:add_code_prefix_link("G71%.2", "Congenital Myopathy")
            contributing_dx_header:add_code_link("T88.3XXA", "Malignant Hyperthermia")
            contributing_dx_header:add_code_link("G74.04", "McArdle's Disease")
            contributing_dx_header:add_code_prefix_link("T07%.", "Multiple Injuries")
            contributing_dx_header:add_code_prefix_link("G71%.0", "Muscular Dystrophy")
            contributing_dx_header:add_code_link("G35", "Multiple Sclerosis")
            contributing_dx_header:add_code_prefix_link("G72%.", "Myopathy")
            contributing_dx_header:add_code_prefix_link("T31%.1", "Third Degree Burn")
            contributing_dx_header:add_code_prefix_link("T31%.2", "Third Degree Burn")
            contributing_dx_header:add_code_prefix_link("T31%.3", "Third Degree Burn")
            contributing_dx_header:add_code_prefix_link("T31%.4", "Third Degree Burn")
            contributing_dx_header:add_code_prefix_link("T31%.5", "Third Degree Burn")
            contributing_dx_header:add_code_prefix_link("T31%.6", "Third Degree Burn")
            contributing_dx_header:add_code_prefix_link("T31%.7", "Third Degree Burn")
            contributing_dx_header:add_code_prefix_link("T31%.8", "Third Degree Burn")
            contributing_dx_header:add_code_prefix_link("T31%.9", "Third Degree Burn")
            contributing_dx_header:add_code_prefix_link("T32%.1", "Third Degree Corrosion Burn")
            contributing_dx_header:add_code_prefix_link("T32%.2", "Third Degree Corrosion Burn")
            contributing_dx_header:add_code_prefix_link("T32%.3", "Third Degree Corrosion Burn")
            contributing_dx_header:add_code_prefix_link("T32%.4", "Third Degree Corrosion Burn")
            contributing_dx_header:add_code_prefix_link("T32%.5", "Third Degree Corrosion Burn")
            contributing_dx_header:add_code_prefix_link("T32%.6", "Third Degree Corrosion Burn")
            contributing_dx_header:add_code_prefix_link("T32%.7", "Third Degree Corrosion Burn")
            contributing_dx_header:add_code_prefix_link("T32%.8", "Third Degree Corrosion Burn")
            contributing_dx_header:add_code_prefix_link("T32%.9", "Third Degree Corrosion Burn")

            -- Labs
            laboratory_studies_header:add_discrete_value_one_of_link(dv_aldolase, "Aldolase", calc_aldolase1)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_ckmb, "CK-MB", calc_ckmb1)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_ckmb_index, "CK-MB Index", calc_ckmb_index1)
            laboratory_studies_header:add_link(greater_kinase_dv)

            if not negation_kidney_failure then
                laboratory_studies_header:add_discrete_value_one_of_link(
                    dv_serum_blood_urea_nitrogen,
                    "Serum Blood Urea Nitrogen",
                    calc_serum_blood_urea_nitrogen1
                )
            end
            if not negation_kidney_failure then
                laboratory_studies_header:add_discrete_value_one_of_link(
                    dv_serum_creatinine,
                    "Serum Creatinine",
                    calc_serum_creatinine1
                )
            end
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_serum_potassium,
                "Serum Potassium",
                calc_serum_potassium1
            )

            -- Meds
            treatment_and_monitoring_header:add_medication_link("Albumin", "Albumin")
            treatment_and_monitoring_header:add_medication_link("Fluid Bolus", "Fluid Bolus")

            -- Vitals
            local r4182_code = codes.make_code_link("R41.82", "Altered Level Of Consciousness")
            local altered_abs = codes.make_abstraction_link("ALTERED_LEVEL_OF_CONSCIOUSNESS",
                "Altered Level Of Consciousness")
            if r4182_code then
                vital_signs_intake_header:add_link(r4182_code)
                if altered_abs then
                    altered_abs.hidden = true
                    vital_signs_intake_header:add_link(altered_abs)
                end
            elseif not r4182_code and altered_abs then
                vital_signs_intake_header:add_link(altered_abs)
            end
            vital_signs_intake_header:add_abstraction_link("LOW_BLOOD_PRESSURE", "Low Blood Pressure")
            vital_signs_intake_header:add_discrete_value_one_of_link(
                dv_glasgow_coma_scale,
                "Glasgow Coma Scale",
                calc_glasgow_coma_scale1
            )
            vital_signs_intake_header:add_discrete_value_one_of_link(dv_heart_rate, "Heart Rate", calc_heart_rate1)
            vital_signs_intake_header:add_discrete_value_one_of_link(dv_map, "Mean Arterial Pressure", calc_map1)
            vital_signs_intake_header:add_discrete_value_one_of_link(dv_sbp, "Systolic Blood Pressure", calc_sbp1)
            vital_signs_intake_header:add_discrete_value_one_of_link(dv_temperature, "Temperature", calc_temperature1)
            vital_signs_intake_header:add_discrete_value_one_of_link(dv_temperature, "Temperature", calc_temperature2)
        end



        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        compile_links()
    end
end
