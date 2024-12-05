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
local alerts = require("libs.common.alerts")
local links = require("libs.common.basic_links")
local blood = require("libs.common.blood")
local codes = require("libs.common.codes")
local discrete = require("libs.common.discrete_values")



--------------------------------------------------------------------------------
--- Setup
--------------------------------------------------------------------------------
local blood_loss_dv_names = { "" }
local high_blood_loss_predicate = function(dv) return discrete.get_dv_value_number(dv) > 300 end
local inr_dv_names = { "INR" }
local high_inr_predicate = function(dv) return discrete.get_dv_value_number(dv) > 1.2 end
local pt_dv_names = { "PROTIME (SEC)" }
local high_pt_predicate = function(dv) return discrete.get_dv_value_number(dv) > 13 end
local ptt_dv_names = { "PTT (SEC)" }
local high_ptt_predicate = function(dv) return discrete.get_dv_value_number(dv) > 30.5 end


local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }



if not existing_alert or not existing_alert.validated then
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
    --- Top-Level Link Header Variables
    --------------------------------------------------------------------------------
    local result_links = {}

    local documented_dx_header = links.make_header_link("Documented Dx")
    local documented_dx_links = {}
    local laboratory_studies_header = links.make_header_link("Laboratory Studies")
    local laboratory_studies_links = {}
    local signs_of_bleeding_header = links.make_header_link("Signs of Bleeding")
    local signs_of_bleeding_links = {}
    local medications_header = links.make_header_link("Medication(s)/Transfusion(s)")
    local medications_links = {}
    local hemoglobin_header = links.make_header_link("Hemoglobin")
    local hemoglobin_links = {}
    local hematocrit_header = links.make_header_link("Hematocrit")
    local hematocrit_links = {}
    local inr_header = links.make_header_link("INR")
    local inr_links = {}
    local pt_header = links.make_header_link("PT")
    local pt_links = {}
    local ptt_header = links.make_header_link("PTT")
    local ptt_links = {}




    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Signs of Bleeding
    local d62_code_link = links.get_code_link { code = "D62", text = "Acute Blood Loss Anemia", seq = 1 }
    local bleeding_abs_link = links.get_abstraction_link { code = "BLEEDING", text = "Bleeding", seq = 2 }
    local blood_loss_dv_link = links.get_discrete_value_link { dvNames = blood_loss_dv_names, text = "Blood Loss", seq = 3, predicate = high_blood_loss_predicate }
    local n99510_code_link = links.get_code_link { code = "N99.510", text = "Cystostomy Hemorrhage", seq = 4 }
    local r040_code_link = links.get_code_link { code = "R04.0", text = "Epistaxis", seq = 5 }
    local est_blood_loss_abs_link = links.get_abstraction_link { code = "ESTIMATED_BLOOD_LOSS", text = "Estimated Blood Loss", seq = 6 }
    local gi_bleed_codes_link = links.get_code_link {
        codes = {
            "K25.0", "K25.2", "K25.4", "K25.6", "K26.0", "K26.2", "K26.4", "K26.6", "K27.0", "K27.2", "K27.4", "K27.6", "K28.0",
            "K28.2", "K28.4", "28.6", "K29.01", "K29.21", "K29.31", "K29.41", "K29.51", "K29.61", "K29.71", "K29.81", "K29.91", "K31.811", "K31.82",
            "K55.21", "K57.01", "K57.11", "K57.13", "K57.21", "K57.31", "K57.33", "K57.41", "K57.51", "K57.53", "K57.81", "K57.91", "K57.93", "K62.5"
        },
        text = "GI Bleed",
        seq = 7
    }
    local k922_code_link = links.get_code_link { code = "K92.2", text = "GI Hemorrhage", seq = 8 }
    local k920_code_link = links.get_code_link { code = "K92.0", text = "Hematemesis", seq = 9 }
    local hematochezia_abs_link = links.get_abstraction_link { code = "HEMATCHEZIA", text = "Hematochezia", seq = 10 }
    local hematoma_abs_link = links.get_abstraction_link { code = "HEMATOMA", text = "Hematoma", seq = 11 }
    local r310_code_link = codes.get_code_prefix_link { prefix = "R31%.", text = "Hematuria", seq = 12 }
    local k661_code_link = links.get_code_link { code = "K66.1", text = "Hemoperitoneum", seq = 13 }
    local hemoptysis_code_link = links.get_code_link { code = "R04.2", text = "Hemoptysis", seq = 14 }
    local hemorrhage_abs_link = links.get_abstraction_link { code = "HEMORRHAGE", text = "Hemorrhage", seq = 15 }
    local r049_code_link = links.get_code_link { code = "R04.9", text = "Hemorrhage from Respiratory Passages", seq = 16 }
    local r041_code_link = links.get_code_link { code = "R04.1", text = "Hemorrhage from Throat", seq = 17 }
    local j9501_code_link = links.get_code_link { code = "J95.01", text = "Hemorrhage from Tracheostomy Stoma", seq = 18 }
    local k921_code_link = links.get_code_link { code = "K92.1", text = "Melena", seq = 19 }
    local i62_codes_link = codes.get_code_prefix_link { prefix = "I61%.", text = "Non-Traumatic Subarachnoid Hemorrhage", seq = 20 }
    local i60_codes_link = codes.get_code_prefix_link { prefix = "I60%.", text = "Non-Traumatic Subarachnoid Hemorrhage", seq = 21 }
    local h922_codes_link = codes.get_code_prefix_link { prefix = "H92.2", text = "Otorrhagia", seq = 22 }
    local r0489_code_link = links.get_code_link { code = "R04.89", text = "Pulmonary Hemorrhage", seq = 23 }

    -- Medications
    local anticoagulant_med_link = links.get_medication_link { cat = "Anticoagulant", seq = 1 }
    local anticoagulant_abs_link = links.get_abstraction_link { code = "ANTICOAGULANT", text = "Anticoagulant", seq = 2 }
    local antiplatelet_med_link = links.get_medication_link { cat = "Antiplatelet", seq = 3 }
    local antiplatelet2_med_link = links.get_medication_link { cat = "Antiplatelet2", seq = 4 }
    local antiplatelet_abs_link = links.get_abstraction_link { code = "ANTIPLATELET", text = "Antiplatelet", seq = 5 }
    local antiplatelet2_abs_link = links.get_abstraction_link { code = "ANTIPLATELET_2", text = "Antiplatelet", seq = 6 }
    local aspirin_med_link = links.get_medication_link { cat = "Aspirin", seq = 7 }
    local aspirin_abs_link = links.get_abstraction_link { code = "ASPIRIN", text = "Aspirin", seq = 8 }
    local heparin_med_link = links.get_medication_link { cat = "Heparin", seq = 15 }
    local heparin_abs_link = links.get_abstraction_link { code = "HEPARIN", text = "Heparin", seq = 16 }
    local z7901_code_link = links.get_code_link { code = "Z79.01", text = "Long Term use of Anticoagulants", seq = 17 }
    local z7982_code_link = links.get_code_link { code = "Z79.82", text = "Long-Term use of Asprin", seq = 18 }
    local z7902_code_link = links.get_code_link { code = "Z79.02", text = "Long-term use of Antithrombotics/Antiplatelets", seq = 19 }

    local signs_of_bleeding =
        d62_code_link or
        bleeding_abs_link or
        r041_code_link or
        r0489_code_link or
        r049_code_link or
        h922_codes_link or
        i62_codes_link or
        i60_codes_link or
        n99510_code_link or
        r040_code_link or
        k922_code_link or
        gi_bleed_codes_link or
        hemorrhage_abs_link or
        j9501_code_link or
        hematochezia_abs_link or
        k920_code_link or
        hematoma_abs_link or
        r310_code_link or
        k661_code_link or
        hemoptysis_code_link or
        k921_code_link or
        est_blood_loss_abs_link or
        blood_loss_dv_link



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if #account_alert_codes > 0 and existing_alert then
        for _, code in ipairs(account_alert_codes) do
            local description = alert_code_dictionary[code]
            local temp_code = links.get_code_links { code = code, text = "Autoresolved Specified Code - " .. description }

            if temp_code then
                table.insert(documented_dx_links, temp_code)
            end
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true
    elseif
        signs_of_bleeding and
        #account_alert_codes == 0 and (
            anticoagulant_med_link or
            anticoagulant_abs_link or
            antiplatelet_med_link or
            antiplatelet2_med_link or
            antiplatelet_abs_link or
            antiplatelet2_abs_link or
            aspirin_med_link or
            aspirin_abs_link or
            heparin_med_link or
            heparin_abs_link or
            z7901_code_link or
            z7982_code_link or
            z7902_code_link
        )
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
                table.insert(hemoglobin_links, pair.hemoglobinLink)
                table.insert(hematocrit_links, pair.hematocritLink)
            end

            for _, pair in ipairs(low_hematocrit_multi_dv_link_pairs) do
                table.insert(hemoglobin_links, pair.hemoglobinLink)
                table.insert(hematocrit_links, pair.hematocritLink)
            end
            links.get_discrete_value_links { discreteValueNames = inr_dv_names, predicate = high_inr_predicate, text = "INR", target = inr_links, maxPerValue = 10 }
            links.get_discrete_value_links { discreteValueNames = pt_dv_names, predicate = high_pt_predicate, text = "PT", target = pt_links, maxPerValue = 10 }
            links.get_discrete_value_links { discreteValueNames = ptt_dv_names, predicate = high_ptt_predicate, text = "PTT", target = ptt_links, maxPerValue = 10 }

            -- Meds
            table.insert(medications_links, anticoagulant_med_link)
            table.insert(medications_links, anticoagulant_abs_link)
            table.insert(medications_links, antiplatelet_med_link)
            table.insert(medications_links, antiplatelet2_med_link)
            table.insert(medications_links, antiplatelet_abs_link)
            table.insert(medications_links, antiplatelet2_abs_link)
            table.insert(medications_links, aspirin_med_link)
            table.insert(medications_links, aspirin_abs_link)
            table.insert(medications_links, links.get_abstraction_value_link { code = "CLOT_SUPPORTING_THERAPY", text = "Clot Supporting Therapy", seq = 9 })
            table.insert(medications_links, links.get_medication_link { cat = "Clot Supporting Therapy Reversal Agent", seq = 10 })
            table.insert(medications_links, links.get_code_link { code = "30233M1", text = "Cryoprecipitate", seq = 11 })
            table.insert(medications_links, links.get_abstraction_value_link { code = "DESMOPRESSIN_ACETATE", text = "Desmopressin Acetate", seq = 12 })
            table.insert(medications_links, links.get_code_link { code = "30233T1", text = "Fibrinogen Transfusion", seq = 13 })
            table.insert(medications_links, links.get_code_link { codes = { "30233L1", "30243L1" }, text = "Fresh Frozen Plasma", seq = 14 })
            table.insert(medications_links, heparin_med_link)
            table.insert(medications_links, heparin_abs_link)
            table.insert(medications_links, z7901_code_link)
            table.insert(medications_links, z7982_code_link)
            table.insert(medications_links, z7902_code_link)
            table.insert(medications_links, links.get_abstraction_value_link { code = "PLASMA_DERIVED_FACTOR_CONCENTRATE", text = "Plasma Derived Factor Concentrate", seq = 20 })
            table.insert(medications_links, links.get_code_link { codes = { "30233R1", "30243R1" }, text = "Platelet Transfusion", seq = 21 })
            table.insert(medications_links, links.get_abstraction_value_link { code = "RECOMBINANT_FACTOR_CONCENTRATE", text = "Recombinant Factor Concentrate", seq = 22 })
            table.insert(medications_links, links.get_code_link { codes = { "30233N1", "30243N1" }, text = "Red Blood Cell Transfusion", seq = 23 })

            -- Sings of Bleeding
            table.insert(signs_of_bleeding_links, d62_code_link)
            table.insert(signs_of_bleeding_links, bleeding_abs_link)
            table.insert(signs_of_bleeding_links, blood_loss_dv_link)
            table.insert(signs_of_bleeding_links, n99510_code_link)
            table.insert(signs_of_bleeding_links, r040_code_link)
            table.insert(signs_of_bleeding_links, est_blood_loss_abs_link)
            table.insert(signs_of_bleeding_links, k922_code_link)
            table.insert(signs_of_bleeding_links, gi_bleed_codes_link)
            table.insert(signs_of_bleeding_links, hematochezia_abs_link)
            table.insert(signs_of_bleeding_links, k920_code_link)
            table.insert(signs_of_bleeding_links, hematoma_abs_link)
            table.insert(signs_of_bleeding_links, r310_code_link)
            table.insert(signs_of_bleeding_links, k661_code_link)
            table.insert(signs_of_bleeding_links, hemoptysis_code_link)
            table.insert(signs_of_bleeding_links, hemorrhage_abs_link)
            table.insert(signs_of_bleeding_links, r049_code_link)
            table.insert(signs_of_bleeding_links, j9501_code_link)
            table.insert(signs_of_bleeding_links, r041_code_link)
            table.insert(signs_of_bleeding_links, k921_code_link)
            table.insert(signs_of_bleeding_links, i62_codes_link)
            table.insert(signs_of_bleeding_links, i60_codes_link)
            table.insert(signs_of_bleeding_links, h922_codes_link)
            table.insert(signs_of_bleeding_links, r0489_code_link)
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        if #inr_links > 0 then
            inr_header.links = inr_links
            table.insert(laboratory_studies_links, inr_header)
        end
        if #pt_links > 0 then
            pt_header.links = pt_links
            table.insert(laboratory_studies_links, pt_header)
        end
        if #ptt_links > 0 then
            ptt_header.links = ptt_links
            table.insert(laboratory_studies_links, ptt_header)
        end
        if #hemoglobin_links > 0 then
            hemoglobin_header.links = hemoglobin_links
            table.insert(laboratory_studies_links, hemoglobin_header)
        end
        if #hematocrit_links > 0 then
            hematocrit_header.links = hematocrit_links
            table.insert(laboratory_studies_links, hematocrit_header)
        end
        if #documented_dx_links > 0 then
            documented_dx_header.links = documented_dx_links
            table.insert(result_links, documented_dx_header)
        end
        if #signs_of_bleeding_links > 0 then
            signs_of_bleeding_header.links = signs_of_bleeding_links
            table.insert(result_links, signs_of_bleeding_header)
        end
        if #laboratory_studies_links > 0 then
            laboratory_studies_header.links = laboratory_studies_links
            table.insert(result_links, laboratory_studies_header)
        end
        if #medications_links > 0 then
            medications_header.links = medications_links
            table.insert(result_links, medications_header)
        end

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end
end

