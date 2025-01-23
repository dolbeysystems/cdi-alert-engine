---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Bleeding
---
--- This script checks an account to see if it matches the criteria for a bleeding alert.
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
local blood = require("libs.common.blood")(Account)
local codes = require("libs.common.codes")(Account)
local discrete = require("libs.common.discrete_values")(Account)
local medications = require("libs.common.medications")(Account)
local headers = require("libs.common.headers")(Account)
local lists = require("libs.common.lists")



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local blood_loss_dv_names = { "" }
local high_blood_loss_predicate = discrete.make_gt_predicate(300)
local inr_dv_names = { "INR" }
local high_inr_predicate = discrete.make_gt_predicate(1.2)
local pt_dv_names = { "PROTIME (SEC)" }
local high_pt_predicate = discrete.make_gt_predicate(13)
local ptt_dv_names = { "PTT (SEC)" }
local high_ptt_predicate = discrete.make_gt_predicate(30.5)



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
    local signs_of_bleeding_header = headers.make_header_builder("Signs of Bleeding", 3)
    local medications_header = headers.make_header_builder("Medication(s)/Transfusion(s)", 4)
    local hemoglobin_header = headers.make_header_builder("Hemoglobin", 1)
    local hematocrit_header = headers.make_header_builder("Hematocrit", 2)
    local inr_header = headers.make_header_builder("INR", 3)
    local pt_header = headers.make_header_builder("PT", 4)
    local ptt_header = headers.make_header_builder("PTT", 5)

    local function compile_links()
        laboratory_studies_header:add_link(hemoglobin_header:build(true))
        laboratory_studies_header:add_link(hematocrit_header:build(true))
        laboratory_studies_header:add_link(inr_header:build(true))
        laboratory_studies_header:add_link(pt_header:build(true))
        laboratory_studies_header:add_link(ptt_header:build(true))

        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, signs_of_bleeding_header:build(true))
        table.insert(result_links, medications_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end



    --------------------------------------------------------------------------------
    --- Alert Variables 
    --------------------------------------------------------------------------------
    local alert_code_dictionary = {
        ["I48.0"] = "Paroxysmal Atrial Fibrillation",
        ["I48.11"] = "Longstanding Persistent Atrial Fibrillation",
        ["I48.19"] = "Other Persistent Atrial Fibrillation",
        ["I48.21"] = "Permanent Atrial Fibrillation",
        ["I48.20"] = "Chronic Atrial Fibrillation"
    }
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Signs of Bleeding
    local d62_code_link = codes.make_code_link("D62", "Acute Blood Loss Anemia", 1)
    local bleeding_abs_link = codes.make_abstraction_link("BLEEDING", "Bleeding", 2)
    local blood_loss_dv_link =
        discrete.make_discrete_value_link(blood_loss_dv_names, "Blood Loss", high_blood_loss_predicate, 3)
    local n99510_code_link = codes.make_code_link("N99.510", "Cystostomy Hemorrhage", 4)
    local r040_code_link = codes.make_code_link("R04.0", "Epistaxis", 5)
    local est_blood_loss_abs_link = codes.make_abstraction_link("ESTIMATED_BLOOD_LOSS", "Estimated Blood Loss", 6)
    local gi_bleed_codes_link = codes.make_code_one_of_link(
        {
            "K25.0", "K25.2", "K25.4", "K25.6", "K26.0", "K26.2", "K26.4", "K26.6", "K27.0", "K27.2", "K27.4",
            "K27.6", "K28.0", "K28.2", "K28.4", "28.6", "K29.01", "K29.21", "K29.31", "K29.41", "K29.51", "K29.61",
            "K29.71", "K29.81", "K29.91", "K31.811", "K31.82", "K55.21", "K57.01", "K57.11", "K57.13", "K57.21",
            "K57.31", "K57.33", "K57.41", "K57.51", "K57.53", "K57.81", "K57.91", "K57.93", "K62.5"
        },
        "GI Bleed",
        7
    )
    local k922_code_link = codes.make_code_link("K92.2", "GI Hemorrhage", 8)
    local k920_code_link = codes.make_code_link("K92.0", "Hematemesis", 9)
    local hematochezia_abs_link = codes.make_abstraction_link("HEMATCHEZIA", "Hematochezia", 10)
    local hematoma_abs_link = codes.make_abstraction_link("HEMATOMA", "Hematoma", 11)
    local r310_code_link = codes.make_code_prefix_link("R31%.", "Hematuria", 12)
    local k661_code_link = codes.make_code_link("K66.1", "Hemoperitoneum", 13)
    local hemoptysis_code_link = codes.make_code_link("R04.2", "Hemoptysis", 14)
    local hemorrhage_abs_link = codes.make_abstraction_link("HEMORRHAGE", "Hemorrhage", 15)
    local r049_code_link = codes.make_code_link("R04.9", "Hemorrhage from Respiratory Passages", 16)
    local r041_code_link = codes.make_code_link("R04.1", "Hemorrhage from Throat", 17)
    local j9501_code_link = codes.make_code_link("J95.01", "Hemorrhage from Tracheostomy Stoma", 18)
    local k921_code_link = codes.make_code_link("K92.1", "Melena", 19)
    local i62_codes_link = codes.make_code_prefix_link("I61%.", "Non-Traumatic Subarachnoid Hemorrhage", 20)
    local i60_codes_link = codes.make_code_prefix_link("I60%.", "Non-Traumatic Subarachnoid Hemorrhage", 21)
    local h922_codes_link = codes.make_code_prefix_link("H92.2", "Otorrhagia", 22)
    local r0489_code_link = codes.make_code_link("R04.89", "Pulmonary Hemorrhage", 23)

    -- Medications
    local anticoagulant_med_link = medications.make_medication_link("Anticoagulant", "", 1)
    local anticoagulant_abs_link = codes.make_abstraction_link("ANTICOAGULANT", "Anticoagulant", 2)
    local antiplatelet_med_link = medications.make_medication_link("Antiplatelet", "", 3)
    local antiplatelet2_med_link = medications.make_medication_link("Antiplatelet2", "", 4)
    local antiplatelet_abs_link = codes.make_abstraction_link("ANTIPLATELET", "Antiplatelet", 5)
    local antiplatelet2_abs_link = codes.make_abstraction_link("ANTIPLATELET_2", "Antiplatelet", 6)
    local aspirin_med_link = medications.make_medication_link("Aspirin", "", 7)
    local aspirin_abs_link = codes.make_abstraction_link("ASPIRIN", "Aspirin", 8)
    local heparin_med_link = medications.make_medication_link("Heparin", "", 15)
    local heparin_abs_link = codes.make_abstraction_link("HEPARIN", "Heparin", 16)
    local z7901_code_link = codes.make_code_link("Z79.01", "Long Term use of Anticoagulants", 17)
    local z7982_code_link = codes.make_code_link("Z79.82", "Long-Term use of Asprin", 18)
    local z7902_code_link = codes.make_code_link("Z79.02", "Long-term use of Antithrombotics/Antiplatelets", 19)

    local signs_of_bleeding = lists.some {
        d62_code_link, bleeding_abs_link, r041_code_link, r0489_code_link, r049_code_link, h922_codes_link,
        i62_codes_link, i60_codes_link, n99510_code_link, r040_code_link, k922_code_link, gi_bleed_codes_link,
        hemorrhage_abs_link, j9501_code_link, hematochezia_abs_link, k920_code_link, hematoma_abs_link, r310_code_link,
        k661_code_link, hemoptysis_code_link, k921_code_link, est_blood_loss_abs_link, blood_loss_dv_link
    }



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if #account_alert_codes > 0 and existing_alert then
        for _, code in ipairs(account_alert_codes) do
            documented_dx_header:add_code_link(code, "Autoresolved Specified Code - " .. alert_code_dictionary[code])
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true
    elseif
        signs_of_bleeding and
        #account_alert_codes == 0 and
        lists.some {
            anticoagulant_med_link, anticoagulant_abs_link,
            antiplatelet_med_link, antiplatelet_abs_link,
            antiplatelet2_med_link, antiplatelet2_abs_link,
            aspirin_med_link, aspirin_abs_link,
            heparin_med_link, heparin_abs_link,
            z7901_code_link, z7982_code_link, z7902_code_link
        }
    then
        Result.subtitle = "Bleeding with possible link to Anticoagulant"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Labs
            local gender = Account.patient and Account.patient.gender or ""
            local low_hemoglobin_multi_dv_link_pairs = blood.get_low_hemoglobin_discrete_value_pairs(gender)
            local low_hematocrit_multi_dv_link_pairs = blood.get_low_hematocrit_discrete_value_pairs(gender)

            for _, pair in ipairs(low_hemoglobin_multi_dv_link_pairs) do
                hemoglobin_header:add_link(pair.hemoglobinLink)
                hemoglobin_header:add_link(pair.hematocritLink)
            end

            for _, pair in ipairs(low_hematocrit_multi_dv_link_pairs) do
                hematocrit_header:add_link(pair.hematocritLink)
                hematocrit_header:add_link(pair.hemoglobinLink)
            end

            inr_header:add_discrete_value_many_links(inr_dv_names, "INR", 10, high_inr_predicate)
            pt_header:add_discrete_value_many_links(pt_dv_names, "PT", 10, high_pt_predicate)
            ptt_header:add_discrete_value_many_links(ptt_dv_names, "PTT", 10, high_ptt_predicate)

            -- Meds
            medications_header:add_link(anticoagulant_med_link)
            medications_header:add_link(anticoagulant_abs_link)
            medications_header:add_link(antiplatelet_med_link)
            medications_header:add_link(antiplatelet2_med_link)
            medications_header:add_link(antiplatelet_abs_link)
            medications_header:add_link(antiplatelet2_abs_link)
            medications_header:add_link(aspirin_med_link)
            medications_header:add_link(aspirin_abs_link)
            medications_header:add_abstraction_link_with_value("CLOT_SUPPORTING_THERAPY", "Clot Supporting Therapy")
            medications_header:add_medication_link("Clot Supporting Therapy Reversal Agent", "")
            medications_header:add_code_link("30233M1", "Cryoprecipitate")
            medications_header:add_abstraction_link_with_value("DESMOPRESSIN_ACETATE", "Desmopressin Acetate")
            medications_header:add_code_link("30233T1", "Fibrinogen Transfusion")
            medications_header:add_code_link("30233L1", "Fresh Frozen Plasma")
            medications_header:add_link(heparin_med_link)
            medications_header:add_link(heparin_abs_link)
            medications_header:add_link(z7901_code_link)
            medications_header:add_link(z7982_code_link)
            medications_header:add_link(z7902_code_link)
            medications_header:add_abstraction_link_with_value(
                "PLASMA_DERIVED_FACTOR_CONCENTRATE",
                "Plasma Derived Factor Concentrate"
            )
            medications_header:add_code_one_of_link({ "30233R1", "30243R1" }, "Platelet Transfusion")
            medications_header:add_abstraction_link_with_value(
                "RECOMBINANT_FACTOR_CONCENTRATE",
                "Recombinant Factor Concentrate"
            )
            medications_header:add_code_one_of_link({ "30233N1", "30243N1" }, "Red Blood Cell Transfusion")

            -- Sings of Bleeding
            signs_of_bleeding_header:add_link(d62_code_link)
            signs_of_bleeding_header:add_link(bleeding_abs_link)
            signs_of_bleeding_header:add_link(blood_loss_dv_link)
            signs_of_bleeding_header:add_link(n99510_code_link)
            signs_of_bleeding_header:add_link(r040_code_link)
            signs_of_bleeding_header:add_link(est_blood_loss_abs_link)
            signs_of_bleeding_header:add_link(k922_code_link)
            signs_of_bleeding_header:add_link(gi_bleed_codes_link)
            signs_of_bleeding_header:add_link(hematochezia_abs_link)
            signs_of_bleeding_header:add_link(k920_code_link)
            signs_of_bleeding_header:add_link(hematoma_abs_link)
            signs_of_bleeding_header:add_link(r310_code_link)
            signs_of_bleeding_header:add_link(k661_code_link)
            signs_of_bleeding_header:add_link(hemoptysis_code_link)
            signs_of_bleeding_header:add_link(hemorrhage_abs_link)
            signs_of_bleeding_header:add_link(r049_code_link)
            signs_of_bleeding_header:add_link(j9501_code_link)
            signs_of_bleeding_header:add_link(r041_code_link)
            signs_of_bleeding_header:add_link(k921_code_link)
            signs_of_bleeding_header:add_link(i62_codes_link)
            signs_of_bleeding_header:add_link(i60_codes_link)
            signs_of_bleeding_header:add_link(h922_codes_link)
            signs_of_bleeding_header:add_link(r0489_code_link)
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

