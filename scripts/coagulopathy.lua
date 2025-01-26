-----------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Coagulopathy
---
--- This script checks an account to see if it matches the criteria for a coagulopathy alert.
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
local codes = require("libs.common.codes")(Account)
local headers = require("libs.common.headers")(Account)
local discrete = require("libs.common.discrete_values")(Account)
local medications = require("libs.common.medications")(Account)
local lists = require("libs.common.lists")



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local activated_clotting_time_dv_name = { "" }
local activated_clotting_time_predicate = discrete.make_gt_predicate(120)
local cryoprecipitate_discrete_value = { "" }
local ddimer_discrete_value = { "D-DIMER (mg/L FEU)" }
local ddimer_predicate_1 = discrete.make_gte_predicate(4)
local ddimer_predicate_2 = discrete.make_range_predicate(0.48, 4)
local fibrinogen_discrete_value = { "FIBRINOGEN (mg/dL)" }
local calc_fibrinogen1 = discrete.make_lt_predicate(200)
local dv_homocysteine_levels = { "" }
local calc_homocysteine_levels1 = discrete.make_gt_predicate(15)
local dv_inr = { "INR" }
local calc_inr3 = discrete.make_gt_predicate(1.3)
local dv_plasma_transfusion = { "Volume (mL)-Transfuse Plasma (mL)" }
local dv_partial_thromboplastin_time = { "PTT (SEC)" }
local calc_partial_thromboplastin_time1 = discrete.make_gt_predicate(30.5)
local dv_platelet_count = { "PLATELET COUNT (10x3/uL)" }
local calc_platelet_count1 = discrete.make_lt_predicate(150)
local dv_platelet_transfusion = { "" }
local dv_protein_c_resistance = { "" }
local calc_protein_c_resistance1 = discrete.make_lt_predicate(2.3)
local dv_prothrombin_time = { "PROTIME (SEC)" }
local calc_prothrombin_time1 = discrete.make_gt_predicate(13.0)
local dv_thrombin_time = { "THROMBIN CLOTTING TM" }
local calc_thrombin_time1 = discrete.make_gt_predicate(14)
local calc_any1 = discrete.make_gt_predicate(0)



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
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 2)
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 3)
    local blood_product_transfusion_header = headers.make_header_builder("Blood Product Transfusion", 4)
    local medications_header = headers.make_header_builder("Medication(s)", 5)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 6)
    local pt_header = headers.make_header_builder("PT", 7)
    local ptt_header = headers.make_header_builder("PTT", 8)
    local inr_header = headers.make_header_builder("INR", 9)
    local platelet_header = headers.make_header_builder("Platelets", 10)

    local function compile_links()
        laboratory_studies_header:add_link(pt_header:build(true))
        laboratory_studies_header:add_link(ptt_header:build(true))
        laboratory_studies_header:add_link(inr_header:build(true))
        laboratory_studies_header:add_link(platelet_header:build(true))

        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, blood_product_transfusion_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end



    --------------------------------------------------------------------------------
    --- Alert Variables
    --------------------------------------------------------------------------------
    local alert_code_dictionary = {
        ["D65"] = "Disseminated Intravascular Coagulation",
        ["D66"] = "Hereditary Factor VIII Deficiency",
        ["D67"] = "Hereditary Factor IX Deficiency",
        ["D68.0"] = "Von Willebrand Disease",
        ["D68.00"] = "Von Willebrand Disease, Unspecified",
        ["D68.01"] = "Von Willebrand Disease, Type 1",
        ["D68.02"] = "Von Willebrand Disease, Type 2",
        ["D68.020"] = "Von Willebrand Disease, Type 2A",
        ["D68.021"] = "Von Willebrand Disease, Type 2B",
        ["D68.022"] = "Von Willebrand Disease, Type 2M",
        ["D68.023"] = "Von Willebrand Disease, Type 2N",
        ["D68.03"] = "Von Willebrand Disease, Type 3",
        ["D68.04"] = "Acquired Von Willebrand Disease",
        ["D68.09"] = "Other Von Willebrand Disease",
        ["D68.1"] = "Hereditary Factor XI Deficiency",
        ["D68.2"] = "Hereditary Deficiency Of Other Clotting Factors",
        ["D68.311"] = "Acquired Hemophilia",
        ["D68.312"] = "Antiphospholipid Antibody With Hemorrhagic Disorder",
        ["D68.318"] = "Other Hemorrhagic Disorder Due To Intrinsic Circulating Anticoagulant, Antibodies, Or Inhibitors",
        ["D68.32"] = "Hemorrhagic Disorder Due To Extrinsic Circulating Anticoagulant",
        ["D68.4"] = "Acquired Coagulation Factor Deficiency",
        ["D68.5"] = "Primary Thrombophilia",
        ["D68.51"] = "Activated Protein C Resistance",
        ["D68.52"] = "Prothrombin Gene Mutation",
        ["D68.59"] = "Other Primary Thrombophilia",
        ["D68.6"] = "Other Thrombophilia",
        ["D68.61"] = "Antiphospholipid Syndrome",
        ["D68.62"] = "Lupus Anticoagulant Syndrome",
        ["D68.69"] = "Other Thrombophilia",
        ["D68.8"] = "Other Specified Coagulation Defects",
        ["D75.821"] = "Non-Immune Heparin-Induced Thrombocytopenia",
        ["D75.822"] = "Immune-Mediated Heparin-Induced Thrombocytopenia",
        ["D75.828"] = "Other Heparin-Induced Thrombocytopenia Syndrome",
        ["D75.829"] = "Heparin-Induced Thrombocytopenia, Unspecified",
        ["D68.9"] = "Coagulation Defect, Unspecified"
    }
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Negation
    local gi_bleed_codes = codes.make_code_links(
        {
            "K25.0", "K25.2", "K25.4", "K25.6", "K26.0", "K26.2", "K26.4", "K26.6", "K27.0", "K27.2", "K27.4", "K27.6",
            "K28.0", "K28.2", "K28.4", "K28.6", "K29.01", "K29.21", "K29.31", "K29.41", "K29.51", "K29.61", "K29.71",
            "K29.81", "K29.91", "K31.811", "K31.82", "K55.21", "K57.01", "K57.11", "K57.13", "K57.21", "K57.31",
            "K57.33", "K57.41", "K57.51", "K57.53", "K57.81", "K57.91", "K57.93", "K62.5", "K92.0", "K92.1", "K92.2"
        },
        "GI Bleed"
    )
    local hemorrhage_abs = codes.make_abstraction_link("HEMORRHAGE", "Hemorrhage")
    local ddimer4_dv = discrete.make_discrete_value_link(ddimer_discrete_value, "D Dimer", ddimer_predicate_1)
    local ddimer0484_dv = discrete.make_discrete_value_link(ddimer_discrete_value, "D Dimer", ddimer_predicate_2)
    local fibrinogen_dv = discrete.make_discrete_value_link(fibrinogen_discrete_value, "Fibrinogen", calc_fibrinogen1)

    -- Labs Subheadings
    local inr13_dv = discrete.make_discrete_value_links(dv_inr, "INR", calc_inr3, 10)
    local ptt_dv = discrete.make_discrete_value_links(dv_partial_thromboplastin_time, "Partial Thromboplastin Time",
        calc_partial_thromboplastin_time1, 10)
    local platelet_count150_dv = discrete.make_discrete_value_links(dv_platelet_count, "Platelet Count",
        calc_platelet_count1, 10)
    local pt_dv = discrete.make_discrete_value_links(dv_prothrombin_time, "Prothrombin Time", calc_prothrombin_time1, 10)

    -- Meds
    local anticoagulant_dv = medications.make_medication_link("Anticoagulant")
    local anticoagulant_abs = codes.make_abstraction_link("ANTICOAGULANT", "Anticoagulant")
    local antiplatelet_dv = medications.make_medication_link("Antiplatelet")
    local antiplatelet_abs = codes.make_abstraction_link("ANTIPLATELET", "Antiplatelet")
    local aspirin_dv = medications.make_medication_link("Aspirin")
    local aspirin_abs = codes.make_abstraction_link("ASPIRIN", "Aspirin")
    local heparin_dv = medications.make_medication_link("Heparin")
    local heparin_abs = codes.make_abstraction_link("HEPARIN", "Heparin")
    local z7901_code = codes.make_code_link("Z79.01", "Long Term Anticoagulants")
    local z7902_code = codes.make_code_link("Z79.02", "Long Term use of Antithrombotics/Antiplatelets")
    local z7982_code = codes.make_code_link("Z79.82", "Long Term Aspirin")
    local multi_dv_values =
        (inr13_dv and 1 or 0) +
        (pt_dv and 1 or 0) +
        (ptt_dv and 1 or 0)
    local med_check = lists.some({
        z7901_code, z7902_code, z7982_code,
        anticoagulant_abs, antiplatelet_abs, anticoagulant_dv, antiplatelet_dv,
        aspirin_abs, aspirin_dv,
        heparin_abs, heparin_dv
    })

    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if existing_alert and #account_alert_codes > 0 then
        for _, code in ipairs(account_alert_codes) do
            local desc = alert_code_dictionary[code]
            local temp_code = codes.make_code_link(code, desc)
            if temp_code then
                documented_dx_header:add_link(temp_code)
                break
            end
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the account"
        Result.validated = true
        Result.passed = true
    elseif med_check and multi_dv_values > 1 then
        Result.subtitle = "Possible Coagulopathy Dx"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            clinical_evidence_header:add_code_link("K70.30", "Alcoholic Cirrhosis of Liver without Acites")
            clinical_evidence_header:add_code_link("K70.31", "Alcoholic Cirrhosis of Liver with Acites")
            clinical_evidence_header:add_code_link("K70.41", "Alcoholic Hepatic Failure with Coma")
            clinical_evidence_header:add_code_link("K70.40", "Alcoholic Hepatic Failure without Coma")
            clinical_evidence_header:add_abstraction_link("CAUSE_OF_COAGULOPATHY", "Causes of Coagulopathy")
            clinical_evidence_header:add_code_link("K72.10", "Chronic Hepatic Failure witout Coma")
            clinical_evidence_header:add_code_link("K72.11", "Chronic Hepatic Failure with Coma")
            clinical_evidence_header:add_code_link("K72.90", "Hepatic Failure Unspecified without Coma")
            clinical_evidence_header:add_code_link("K72.91", "Hepatic Failure Unspecified with Coma")
            clinical_evidence_header:add_links(gi_bleed_codes)
            clinical_evidence_header:add_link(hemorrhage_abs)
            clinical_evidence_header:add_code_link("D61.818", "Pancytopenia")
            clinical_evidence_header:add_code_link("M32.9", "Systemic Lupus Erythematous")
            clinical_evidence_header:add_code_link("E56.1", "Vitamin K Deficiency")

            -- Blood
            blood_product_transfusion_header:add_discrete_value_one_of_link(cryoprecipitate_discrete_value,
                "Cryoprecipitate", calc_any1)
            blood_product_transfusion_header:add_code_link("30233M1", "Cryoprecipitate Transfusion")
            blood_product_transfusion_header:add_code_link("30233T1", "Fibrinogen Transfusion")
            blood_product_transfusion_header:add_code_one_of_link({ "30233L1", "30243L1" }, "Fresh Plasma Transfusion")
            blood_product_transfusion_header:add_discrete_value_one_of_link(dv_plasma_transfusion, "Plasma Transfusion",
                calc_any1)
            blood_product_transfusion_header:add_discrete_value_one_of_link(dv_platelet_transfusion,
                "Platelet Transfusion", calc_any1)

            -- Labs
            laboratory_studies_header:add_discrete_value_one_of_link(activated_clotting_time_dv_name,
                "Activated Clotting Time", activated_clotting_time_predicate)
            laboratory_studies_header:add_link(ddimer4_dv)
            laboratory_studies_header:add_link(ddimer0484_dv)
            laboratory_studies_header:add_link(fibrinogen_dv)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_homocysteine_levels, "Homocysteine Levels",
                calc_homocysteine_levels1)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_protein_c_resistance, "Protein C Resistance",
                calc_protein_c_resistance1)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_thrombin_time, "Thrombin Time",
                calc_thrombin_time1)

            -- Lab Subheadings
            laboratory_studies_header:add_links(inr13_dv)
            laboratory_studies_header:add_links(ptt_dv)
            laboratory_studies_header:add_links(platelet_count150_dv)
            laboratory_studies_header:add_links(pt_dv)

            -- Medications
            medications_header:add_link(anticoagulant_dv)
            medications_header:add_link(anticoagulant_abs)
            medications_header:add_link(antiplatelet_dv)
            medications_header:add_link(antiplatelet_abs)
            medications_header:add_medication_link("Antiplatelet2", "")
            medications_header:add_link(aspirin_dv)
            medications_header:add_link(aspirin_abs)
            medications_header:add_abstraction_link("ANTIFIBRINOLYTIC_MEDICATION", "Antifibrinolytic Medication")
            medications_header:add_abstraction_link("DESMOPRESSIN_ACETATE", "Desmopressin Acetate")
            medications_header:add_link(heparin_dv)
            medications_header:add_link(heparin_abs)
            medications_header:add_link(z7901_code)
            medications_header:add_link(z7902_code)
            medications_header:add_link(z7982_code)
            medications_header:add_abstraction_link("PLASMA_DERIVED_FACTOR_CONCENTRATE",
                "Plasma Derived Factor Concentrate")
            medications_header:add_abstraction_link("RECOMBINANT_FACTOR_CONCENTRATE", "Recombinant Factor Concentrate")
        end



        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        compile_links()
    end
end
