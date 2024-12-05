---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Anemia
---
--- This script checks an account to see if it matches the criteria for an anemia alert.
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
local dv_blood_loss = { "" }
local calc_blood_loss1 = function(dv) return discrete.get_dv_value_number(dv) > 300 end
local dv_folate = { "" }
local calc_folate1 = function(dv) return discrete.get_dv_value_number(dv) < 7.0 end
local dv_hematocrit = { "HEMATOCRIT (%)", "HEMATOCRIT" }
local calc_hematocrit3 = function(dv) return discrete.get_dv_value_number(dv) < 30 end
local dv_hemoglobin = { "HEMOGLOBIN", "HEMOGLOBIN (g/dL)" }
local calc_hemoglobin1 = function(dv) return discrete.get_dv_value_number(dv) < 13.5 end
local calc_hemoglobin2 = function(dv) return discrete.get_dv_value_number(dv) < 12.5 end
local calc_hemoglobin3 = function(dv) return discrete.get_dv_value_number(dv) < 10.0 end
local dv_map = { "Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)" }
local calc_map1 = function(dv) return discrete.get_dv_value_number(dv) < 70 end
local dv_mch = { "MCH (pg)" }
local calc_mch1 = function(dv) return discrete.get_dv_value_number(dv) < 25 end
local dv_mchc = { "MCHC (g/dL)" }
local calc_mchc1 = function(dv) return discrete.get_dv_value_number(dv) < 32 end
local dv_mcv = { "MCV (fL)" }
local calc_mcv1 = function(dv) return discrete.get_dv_value_number(dv) < 80 end
local dv_rbc = { "RBC  (10X6/uL)" }
local calc_rbc1 = function(dv) return discrete.get_dv_value_number(dv) < 3.9 end
local dv_rdw = { "RDW CV (%)" }
local calc_rdw1 = function(dv) return discrete.get_dv_value_number(dv) < 11 end
local dv_red_blood_cell_transfusion = { "" }
local dv_reticulocyte_count = { "" }
local calc_reticulocyte_count1 = function(dv) return discrete.get_dv_value_number(dv) < 0.5 end
local dv_sbp = { "SBP 3.5 (No Calculation) (mm Hg)" }
local calc_sbp1 = function(dv) return discrete.get_dv_value_number(dv) < 90 end
local dv_serum_ferritin = { "FERRITIN (ng/mL)" }
local calc_serum_ferritin1 = function(dv) return discrete.get_dv_value_number(dv) < 22 end
local dv_serum_iron = { "IRON TOTAL (ug/dL)" }
local calc_serum_iron1 = function(dv) return discrete.get_dv_value_number(dv) < 65 end
local dv_total_iron_binding_capacity = { "IRON BINDING" }
local calc_total_iron_binding_capacity1 = function(dv) return discrete.get_dv_value_number(dv) < 246 end
local dv_transferrin = { "TRANSFERRIN" }
local calc_transferrin1 = function(dv) return discrete.get_dv_value_number(dv) < 200 end
local dv_vitamin_b12 = { "VITAMIN B12 (pg/mL)" }
local calc_vitamin_b12_1 = function(dv) return discrete.get_dv_value_number(dv) < 180 end
local dv_wbc = { "WBC (10x3/ul)" }
local calc_wbc1 = function(dv) return discrete.get_dv_value_number(dv) < 4.5 end
local calc_gt_zero = function(dv) return discrete.get_dv_value_number(dv) > 0 end

local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }
local subtitle = existing_alert and existing_alert.subtitle or nil

local link_text_possible_no_lows = "Possible No Low Hemoglobin, Low Hematocrit or Anemia Treatment"
local link_text_possible_no_signs_of_bleeding = "Possible No Sign of Bleeding Please Review"
local link_text_possible_no_matching_hemoglobin = "Possible No Hemoglobin Values Meeting Criteria Please Review"
local link_text_possible_no_anemia_treatment = "Possible No Anemia Treatment found"

local link_text_possible_no_lows_present = false
local link_text_possible_no_signs_of_bleeding_present = false
local link_text_possible_no_matching_hemoglobin_present = false
local link_text_possible_no_anemia_treatment_present = false

if existing_alert and existing_alert.links then
    for _, link in ipairs(existing_alert.links) do
        if link.link_text == link_text_possible_no_lows then
            link_text_possible_no_lows_present = true
        elseif link.link_text == link_text_possible_no_signs_of_bleeding then
            link_text_possible_no_signs_of_bleeding_present = true
        elseif link.link_text == link_text_possible_no_matching_hemoglobin then
            link_text_possible_no_matching_hemoglobin_present = true
        elseif link.link_text == link_text_possible_no_anemia_treatment then
            link_text_possible_no_anemia_treatment_present = true
        end
    end
end




if not existing_alert or not existing_alert.validated then
    --------------------------------------------------------------------------------
    --- Top-Level Link Header Variables
    --------------------------------------------------------------------------------
    local result_links = {}
    local documented_dx_header = links.make_header_link("Documented Dx")
    local documented_dx_links = {}
    local alert_trigger_header = links.make_header_link("Alert Trigger")
    local alert_trigger_links = {}
    local labs_header = links.make_header_link("Laboratory Studies")
    local labs_links = {}
    local vitals_header = links.make_header_link("Vital Signs/Intake and Output Data")
    local vitals_links = {}
    local clinical_evidence_header = links.make_header_link("Clinical Evidence")
    local clinical_evidence_links = {}
    local treatment_and_monitoring_header = links.make_header_link("Treatment and Monitoring")
    local treatment_and_monitoring_links = {}
    local sign_of_bleeding_header = links.make_header_link("Sign of Bleeding")
    local sign_of_bleeding_links = {}
    local other_header = links.make_header_link("Other")
    local other_links = {}
    local hemoglobin_header = links.make_header_link("Hemoglobin")
    local hemoglobin_links = {}
    local hematocrit_header = links.make_header_link("Hematocrit")
    local hematocrit_links = {}
    local blood_loss_header = links.make_header_link("Blood Loss")
    local blood_loss_links = {}



    --------------------------------------------------------------------------------
    --- Alert Variables 
    --------------------------------------------------------------------------------
    local alert_code_dictionary = {
        ["D50.8"] = "Other Iron Deficiency Anemias",
        ["D50.9"] = "Iron Deficiency Anemia Unspecified",
        ["D51.0"] = "Vitamin B12 Deficiency Anemia due to Intrinsic Factor Deficiency",
        ["D51.1"] = "Vitamin B12 Deficiency Anemia due to Selective Vitamin B12 Malabsorption With Proteinuria",
        ["D51.2"] = "Transcobalamin II Deficiency",
        ["D51.3"] = "Other Dietary Vitamin B12 Deficiency Anemia",
        ["D51.8"] = "Other Vitamin B12 Deficiency Anemias",
        ["D51.9"] = "Vitamin B12 Deficiency Anemia, Unspecified",
        ["D52.0"] = "Dietary Folate Deficiency Anemia",
        ["D52.1"] = "Drug-Induced Folate Deficiency Anemia",
        ["D52.8"] = "Other Folate Deficiency Anemias",
        ["D52.9"] = "Folate Deficiency Anemia, Unspecified",
        ["D53.0"] = "Protein Deficiency Anemia",
        ["D53.1"] = "Other Megaloblastic Anemias, not Elsewhere Classified",
        ["D53.2"] = "Scorbutic Anemia",
        ["D53.8"] = "Other Specified Nutritional Anemias",
        ["D53.9"] = "Nutritional Anemia, Unspecified",
        ["D55.0"] = "Anemia Due to Glucose-6-Phosphate Dehydrogenase [G6pd] Deficiency",
        ["D55.1"] = "Anemia Due to Other Disorders of Glutathione Metabolism",
        ["D55.21"] = "Anemia Due to Pyruvate Kinase Deficiency",
        ["D55.29"] = "Anemia Due to Other Disorders of Glycolytic Enzymes",
        ["D55.3"] = "Anemia Due to Disorders of Nucleotide Metabolism",
        ["D55.8"] = "Other Anemias Due to Enzyme Disorders",
        ["D55.9"] = "Anemia Due to Enzyme Disorder, Unspecified",
        ["D56.0"] = "Alpha Thalassemia",
        ["D56.1"] = "Beta Thalassemia",
        ["D56.2"] = "Delta-Beta Thalassemia",
        ["D56.3"] = "Thalassemia Minor",
        ["D56.4"] = "Hereditary Persistence of Fetal Hemoglobin [Hpfh]",
        ["D56.5"] = "Hemoglobin E-Beta Thalassemia",
        ["D56.8"] = "Other Thalassemias",
        ["D56.9"] = "Thalassemia, Unspecified",
        ["D58.0"] = "Hereditary Spherocytosis",
        ["D58.1"] = "Hereditary Elliptocytosis",
        ["D58.2"] = "Other Hemoglobinopathies",
        ["D58.8"] = "Other Specified Hereditary Hemolytic Anemias",
        ["D58.9"] = "Hereditary Hemolytic Anemia, Unspecified",
        ["D59.0"] = "Drug-Induced Autoimmune Hemolytic Anemia",
        ["D59.10"] = "Autoimmune Hemolytic Anemia, Unspecified",
        ["D59.11"] = "Warm Autoimmune Hemolytic Anemia",
        ["D59.12"] = "Cold Autoimmune Hemolytic Anemia",
        ["D59.13"] = "Mixed Type Autoimmune Hemolytic Anemia",
        ["D59.19"] = "Other Autoimmune Hemolytic Anemia",
        ["D59.2"] = "Drug-Induced Nonautoimmune Hemolytic Anemia",
        ["D59.30"] = "Hemolytic-Uremic Syndrome, Unspecified",
        ["D59.31"] = "Infection-Associated Hemolytic-Uremic Syndrome",
        ["D59.32"] = "Hereditary Hemolytic-Uremic Syndrome",
        ["D59.39"] = "Other Hemolytic-Uremic Syndrome",
        ["D59.4"] = "Other Nonautoimmune Hemolytic Anemias",
        ["D59.5"] = "Paroxysmal Nocturnal Hemoglobinuria [Marchiafava-Micheli]",
        ["D59.6"] = "Hemoglobinuria Due to Hemolysis From Other External Causes",
        ["D59.8"] = "Other Acquired Hemolytic Anemias",
        ["D59.9"] = "Acquired Hemolytic Anemia, Unspecified",
        ["D60.0"] = "Chronic Acquired Pure Red Cell Aplasia",
        ["D60.1"] = "Transient Acquired Pure Red Cell Aplasia",
        ["D60.8"] = "Other Acquired Pure Red Cell Aplasias",
        ["D60.9"] = "Acquired Pure Red Cell Aplasia, Unspecified",
        ["D61.01"] = "Constitutional (Pure) Red Blood Cell Aplasia",
        ["D61.09"] = "Other Constitutional Aplastic Anemia",
        ["D61.1"] = "Drug-Induced Aplastic Anemia",
        ["D61.2"] = "Aplastic Anemia Due to Other External Agents",
        ["D61.3"] = "Idiopathic Aplastic Anemia",
        ["D61.810"] = "Antineoplastic Chemotherapy Induced Pancytopenia",
        ["D61.811"] = "Other Drug-Induced Pancytopenia",
        ["D61.818"] = "Other Pancytopenia",
        ["D61.82"] = "Myelophthisis",
        ["D61.89"] = "Other Specified Aplastic Anemias and Other Bone Marrow Failure Syndromes",
        ["D61.9"] = "Aplastic Anemia, Unspecified",
        ["D62"] = "Acute Posthemorrhagic Anemia",
        ["D63.0"] = "Anemia in Neoplastic Disease",
        ["D63.1"] = "Anemia in Chronic Kidney Disease",
        ["D63.8"] = "Anemia in Other Chronic Diseases Classified Elsewhere",
        ["D64.0"] = "Hereditary Sideroblastic Anemia",
        ["D64.1"] = "Secondary Sideroblastic Anemia due to Disease",
        ["D64.2"] = "Secondary Sideroblastic Anemia due to Drugs And Toxins",
        ["D64.3"] = "Other Sideroblastic Anemias",
        ["D64.4"] = "Congenital Dyserythropoietic Anemia",
        ["D64.81"] = "Anemia due to Antineoplastic Chemotherapy",
        ["D64.89"] = "Other Specified Anemias"
    }
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Documented Dx
    local d649_code_link = links.get_code_link { code = "D64.9", text = "Unspecified Anemia" }
    local d500_code_link = links.get_code_link { code = "D50.0", text = "Iron deficiency anemia secondary to blood loss (chronic)" }
    local d62_code_link = links.get_code_link { code = "D62", text = "Acute Posthemorrhagic Anemia" }
    local blood_loss_d_v_links = links.get_discrete_value_links {
        discreteValueNames = dv_blood_loss,
        text = "Blood Loss: [VALUE]",
        predicate = calc_blood_loss1,
        maxPerValue = 10
    }

    -- Signs of Bleeding
    local i975_code_link = links.get_code_link { codes = { "I97.51", "I97.52" }, text = "Accidental Puncture/Laceration of Circulatory System Organ During Procedure", seq = 1 } or {}
    local k917_code_link = links.get_code_link { codes = { "K91.71", "K91.72" }, text = "Accidental Puncture/Laceration of Digestive System Organ During Procedure", seq = 2 } or {}
    local j957_code_link = links.get_code_link { codes = { "J95.71", "J95.72" }, text = "Accidental Puncture/Laceration of Respiratory System Organ During Procedure", seq = 3 } or {}
    local k260_code_link = links.get_code_link { code = "K26.0", text = "Acute Duodenal Ulcer with Hemorrhage", seq = 4 }
    local k262_code_link = links.get_code_link { code = "K26.2", text = "Acute Duodenal Ulcer with Hemorrhage and Perforation", seq = 5 }
    local k250_code_link = links.get_code_link { code = "K25.0", text = "Acute Gastric Ulcer with Hemorrhage", seq = 6 }
    local k252_code_link = links.get_code_link { code = "K25.2", text = "Acute Gastric Ulcer with Hemorrhage and Perforation", seq = 7 }
    local k270_code_link = links.get_code_link { code = "K27.0", text = "Acute Peptic Ulcer with Hemorrhage", seq = 8 }
    local k272_code_link = links.get_code_link { code = "K27.2", text = "Acute Peptic Ulcer with Hemorrhage and Perforation", seq = 9 }
    local bleeding_abstraction_link = links.get_abstraction_link { code = "BLEEDING", text = "Bleeding", seq = 10 }
    local r319_code_link = links.get_code_link { code = "R31.9", text = "Bloody Urine", seq = 11 }
    local k264_code_link = links.get_code_link { code = "K26.4", text = "Chronic Duodenal Ulcer with Hemorrhage", seq = 12 }
    local k266_code_link = links.get_code_link { code = "K26.6", text = "Chronic Duodenal Ulcer with Hemorrhage and Perforation", seq = 13 }
    local k254_code_link = links.get_code_link { code = "K25.4", text = "Chronic Gastric Ulcer with Hemorrhage", seq = 14 }
    local k256_code_link = links.get_code_link { code = "K25.6", text = "Chronic Gastric Ulcer with Hemorrhage and Perforation", seq = 15 }
    local k276_code_link = links.get_code_link { code = "K27.6", text = "Chronic Peptic Ulcer with Hemorrhage and Perforation", seq = 16 }
    local n99510_code_link = links.get_code_link { code = "N99.510", text = "Cystostomy Hemorrhage", seq = 17 }
    local r040_code_link = links.get_code_link { code = "R04.0", text = "Epistaxis", seq = 18 }
    local i8501_code_link = links.get_code_link { code = "I85.01", text = "Esophageal Varices with Bleeding", seq = 19 }
    local ebl_abstraction_link = links.get_abstraction_link { code = "ESTIMATED_BLOOD_LOSS", text = "Estimated Blood Loss", seq = 20 }
    local k922_code_link = links.get_code_link { code = "K92.2", text = "GI Hemorrhage", seq = 21 }
    local hematoma_abstraction_link = links.get_abstraction_link { code = "HEMATOMA", text = "Hematoma", seq = 22 }
    local k920_code_link = links.get_code_link { code = "K92.0", text = "Hematemesis", seq = 23 }
    local r310_code_link = codes.get_code_prefix_link { prefix = "R31", text = "Hematuria", seq = 24, maxPerValue = 1 }
    local r195_code_link = links.get_code_link { code = "R19.5", text = "Heme-Positive Stool", seq = 25 }
    local k661_code_link = links.get_code_link { code = "K66.1", text = "Hemoperitoneum", seq = 26 }
    local hemorrhage_abstraction_link = links.get_abstraction_link { code = "HEMORRHAGE", text = "Hemorrhage", seq = 27 }
    local n3091_code_link = links.get_code_link { code = "N30.91", text = "Hemorrhagic Cystitis", seq = 28 }
    local j9501_code_link = links.get_code_link { code = "J95.01", text = "Hemorrhage from Tracheostomy Stoma", seq = 29 }
    local r042_code_link = links.get_code_link { code = "R04.2", text = "Hemoptysis", seq = 30 }
    local i974_code_link = links.get_code_link { codes = { "I97.410", "I97.411", "I97.418", "I97.42" }, text = "Intraoperative Hemorrhage/Hematoma of Circulatory System Organ", seq = 31 }
    local k916_code_link = links.get_code_link { codes = { "K91.61", "K91.62" }, text = "Intraoperative Hemorrhage/Hematoma of Digestive System Organ", seq = 32 } or {}
    local n99_code_link = links.get_code_link { codes = { "N99.61", "N99.62" }, text = "Intraoperative Hemorrhage/Hematoma of Genitourinary System", seq = 33 } or {}
    local g9732_code_link = links.get_code_link { code = "G97.32", text = "Intraoperative Hemorrhage/Hematoma of Nervous System Organ", seq = 34 }
    local g9731_code_link = links.get_code_link { code = "G97.31", text = "Intraoperative Hemorrhage/Hematoma of Nervous System Procedure", seq = 35 }
    local j956_code_link = links.get_code_link { codes = { "J95.61", "J95.62" }, text = "Intraoperative Hemorrhage/Hematoma of Respiratory System", seq = 36 } or {}
    local k921_code_link = links.get_code_link { code = "K92.1", text = "Melena", seq = 37 }
    local i61_code_link = codes.get_code_prefix_link { prefix = "I61", text = "Nontraumatic Intracerebral Hemorrhage", seq = 38 }
    local i62_code_link = codes.get_code_prefix_link { prefix = "I62", text = "Nontraumatic Intracerebral Hemorrhage", seq = 39 }
    local i60_code_link = codes.get_code_prefix_link { prefix = "I60", text = "Nontraumatic Subarachnoid Hemorrhage", seq = 40 }
    local l7632_code_link = links.get_code_link { code = "L76.32", text = "Postoperative Hematoma", seq = 41 }
    local k918_code_link = links.get_code_link { codes = { "K91.840", "K91.841", "K91.870", "K91.871" }, text = "Postoperative Hemorrhage/Hematoma of Digestive System Organ", seq = 42 }
    local i976_code_link = links.get_code_link { codes = { "I97.610", "I97.611", "I97.618", "I97.620" }, text = "Postoperative Hemorrhage/Hematoma of Circulatory System Organ", seq = 43 }
    local n991_code_link = links.get_code_link { codes = { "N99.820", "N99.821", "N99.840", "N99.841" }, text = "Postoperative Hemorrhage/Hematoma of Genitourinary System", seq = 44 }
    local g9752_code_link = links.get_code_link { code = "G97.52", text = "Postoperative Hemorrhage/Hematoma of Nervous System Organ", seq = 45 }
    local g9751_code_link = links.get_code_link { code = "G97.51", text = "Postoperative Hemorrhage/Hematoma of Nervous System Procedure", seq = 46 }
    local j958_code_link = links.get_code_link { codes = { "J95.830", "J95.831", "J95.860", "J95.861" }, text = "Postoperative Hemorrhage/Hematoma of Respiratory System", seq = 47 }
    local k625_code_link = links.get_code_link { code = "K62.5", text = "Rectal Bleeding", seq = 48 }

    -- Labs
    local gender = Account.patient and Account.patient.gender or ""
    table.insert(
        labs_links,
        discrete.get_discrete_value_pairs_as_combined_single_line_link {
            discreteValueNames1 = dv_hemoglobin,
            discreteValueNames2 = dv_hematocrit,
            linkTemplate = "Hemoglobin/Hematocrit: ([DATE1] - [DATE2]) - [VALUE_PAIRS]",
        }
    )
    local low_hemoglobin10_d_v_link = links.get_discrete_value_link { discreteValueNames = dv_hemoglobin, text = "Hemoglobin", predicate = calc_hemoglobin3 }
    local low_hematocrit30_d_v_link = links.get_discrete_value_link { discreteValueNames = dv_hematocrit, text = "Hematocrit", predicate = calc_hematocrit3 }
    local low_hemoglobin_d_v_link =
        links.get_discrete_value_link {
            discreteValueNames = dv_hemoglobin,
            text = "Hemoglobin",
            predicate = gender == "F" and calc_hemoglobin2 or calc_hemoglobin1
        }

    local low_hemoglobin_multi_d_v_link_pairs = blood.get_low_hemoglobin_discrete_value_pairs(gender)
    local low_hematocrit_multi_d_v_link_pairs = blood.get_low_hematocrit_discrete_value_pairs(gender)

    local hematocrit_drop_d_v_link_pairs = blood.get_hematocrit_drop_pairs()
    local hemoglobin_drop_d_v_link_pairs = blood.get_hemoglobin_drop_pairs()

    -- Meds
    local anemia_meds_abstraction_link = links.get_abstraction_link { code = "ANEMIA_MEDICATION", text = "Anemia Medication", seq = 1 }
    local anemia_medication_link = links.get_medication_link { cat = "Anemia Supplements", text = "Anemia Supplements", seq = 2 }
    local cell_saver_abstraction_link = links.get_abstraction_link { code = "CELL_SAVER", text = "Cell Saver", seq = 3 }
    local hematopoetic_medication_link = links.get_medication_link { cat = "Hemopoietic Agent", text = "Hematopoietic Agent", seq = 4 }
    local hemtopoetic_abstraction_link = links.get_abstraction_link { code = "HEMATOPOIETIC_AGENT", text = "Hematopoietic Agent", seq = 5 }
    local r_blo_transfusion_code_link = links.get_code_link { codes = { "30233N1", "30243N1" }, text = "Red Blood Cell Transfusion", seq = 6 }
    local red_blood_cell_d_v_link = links.get_discrete_value_link { discreteValueNames = dv_red_blood_cell_transfusion, text = "Red Blood Cell Transfusion", predicate = calc_gt_zero, seq = 7 }

    local signs_of_bleeding =
        i975_code_link and
        k917_code_link and
        j957_code_link and
        k260_code_link and
        k262_code_link and
        k250_code_link and
        k252_code_link and
        k270_code_link and
        k272_code_link and
        k264_code_link and
        k266_code_link and
        k254_code_link and
        k256_code_link and
        k276_code_link and
        n99510_code_link and
        i8501_code_link and
        k922_code_link and
        hematoma_abstraction_link and
        k920_code_link and
        r310_code_link and
        k661_code_link and
        n3091_code_link and
        j9501_code_link and
        r042_code_link and
        i974_code_link and
        k916_code_link and
        n99_code_link and
        g9732_code_link and
        g9731_code_link and
        j956_code_link and
        k921_code_link and
        l7632_code_link and
        k918_code_link and
        i976_code_link and
        n991_code_link and
        g9752_code_link and
        g9751_code_link and
        j958_code_link and
        k625_code_link and
        r319_code_link and
        r040_code_link and
        r195_code_link and
        i61_code_link and
        i62_code_link and
        i60_code_link and
        #blood_loss_d_v_links > 0 and
        ebl_abstraction_link and
        bleeding_abstraction_link and
        hemorrhage_abstraction_link

    local anemia_treatment =
        anemia_meds_abstraction_link and
        anemia_medication_link and
        hematopoetic_medication_link and
        hemtopoetic_abstraction_link and
        r_blo_transfusion_code_link and
        cell_saver_abstraction_link



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if
        subtitle == "Anemia Dx Possibly Lacking Supporting Evidence" and
        #account_alert_codes > 0 and
        (low_hemoglobin_d_v_link or low_hematocrit30_d_v_link)
    then
        -- Autoresolve "Anemia Dx Possibly Lacking Supporting Evidence"
        if link_text_possible_no_lows_present then
            local link = links.make_header_link(link_text_possible_no_lows)
            table.insert(documented_dx_links, link)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        subtitle == "Acute Blood Loss Anemia Dx Possibly Lacking Clinical Evidence" and
        d62_code_link and
        (
            (not link_text_possible_no_signs_of_bleeding_present or signs_of_bleeding) and
            (not link_text_possible_no_matching_hemoglobin_present or low_hemoglobin_d_v_link) and
            (not link_text_possible_no_anemia_treatment_present or not anemia_treatment)
        )
    then
        -- Autoresolve "Acute Blood Loss Anemia Dx Possibly Lacking Clinical Evidence"
        if low_hemoglobin_d_v_link then
            low_hemoglobin_d_v_link.link_text = "Autoresolved Evidence - " .. low_hemoglobin_d_v_link.link_text
            table.insert(documented_dx_links, low_hemoglobin_d_v_link)
        end
        if link_text_possible_no_signs_of_bleeding_present then
            local link = links.make_header_link(link_text_possible_no_signs_of_bleeding)
            table.insert(documented_dx_links, link)
        end
        if link_text_possible_no_matching_hemoglobin_present then
            local link = links.make_header_link(link_text_possible_no_matching_hemoglobin)
            table.insert(documented_dx_links, link)
        end
        if link_text_possible_no_anemia_treatment_present then
            local link = links.make_header_link(link_text_possible_no_anemia_treatment)
            table.insert(documented_dx_links, link)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        subtitle == "Possible Acute Blood Loss Anemia" and
        d62_code_link
    then
        -- Autoresolve "Possible Acute Blood Loss Anemia"
        table.insert(documented_dx_links, d62_code_link)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        subtitle == "Possible Anemia Dx" and
        #account_alert_codes > 0
    then
        -- Autoresolve "Possible Anemia Dx"
        for _, code in ipairs(account_alert_codes) do
            local desc = alert_code_dictionary[code]
            local temp_code = links.get_code_link { code = code, text = "Autoresolved Specified Code - " .. desc }
            if temp_code then
                table.insert(documented_dx_links, temp_code)
                break
            end
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.validated = true
        Result.passed = true

    elseif #account_alert_codes > 0 and not low_hemoglobin_d_v_link and not low_hematocrit30_d_v_link and not anemia_treatment then
        -- Alert for "Anemia Dx Possibly Lacking Supporting Evidence"
        if not low_hemoglobin_d_v_link or not anemia_treatment then
            local link = links.make_header_link(link_text_possible_no_lows)
            table.insert(documented_dx_links, link)
        end
        for _, code in ipairs(account_alert_codes) do
            local desc = alert_code_dictionary[code]
            local temp_code = links.get_code_link { code = code, text = desc }
            if temp_code then
                table.insert(documented_dx_links, temp_code)
            end
        end
        Result.subtitle = "Anemia Dx Possibly Lacking Supporting Evidence"
        Result.passed = true

    elseif d62_code_link and (not signs_of_bleeding or not low_hemoglobin_d_v_link or not anemia_treatment) then
        -- Alert for "Acute Blood Loss Anemia Dx Possibly Lacking Clinical Evidence"
        table.insert(documented_dx_links, d62_code_link)

        local link2 = links.make_header_link(link_text_possible_no_signs_of_bleeding)
        link2.is_validated = not (link_text_possible_no_signs_of_bleeding_present and signs_of_bleeding)
        table.insert(documented_dx_links, link2)

        local link3 = links.make_header_link(link_text_possible_no_matching_hemoglobin)
        link3.is_validated = not (link_text_possible_no_matching_hemoglobin_present and low_hemoglobin_d_v_link)
        table.insert(documented_dx_links, link3)

        local link4 = links.make_header_link(link_text_possible_no_anemia_treatment)
        link4.is_validated = not (link_text_possible_no_anemia_treatment_present and anemia_treatment)
        table.insert(documented_dx_links, link4)

        Result.subtitle = "Acute Blood Loss Anemia Dx Possibly Lacking Clinical Evidence"
        Result.passed = true

    elseif not d62_code_link and (#hematocrit_drop_d_v_link_pairs > 0 or #hemoglobin_drop_d_v_link_pairs > 0) then
        -- Alert for "Possible Acute Blood Loss Anemia" - Drops
        if hematocrit_drop_d_v_link_pairs then
            table.insert(hematocrit_links, hematocrit_drop_d_v_link_pairs.hematocritDropLink)
            table.insert(hematocrit_links, hematocrit_drop_d_v_link_pairs.hematocritPeakLink)
            table.insert(hematocrit_links, hematocrit_drop_d_v_link_pairs.hemoglobinDropLink)
            table.insert(hematocrit_links, hematocrit_drop_d_v_link_pairs.hemoglobinPeakLink)
        end
        if hemoglobin_drop_d_v_link_pairs then
            table.insert(hemoglobin_links, hemoglobin_drop_d_v_link_pairs.hemoglobinDropLink)
            table.insert(hemoglobin_links, hemoglobin_drop_d_v_link_pairs.hemoglobinPeakLink)
            table.insert(hemoglobin_links, hemoglobin_drop_d_v_link_pairs.hematocritDropLink)
            table.insert(hemoglobin_links, hemoglobin_drop_d_v_link_pairs.hematocritPeakLink)
        end
        table.insert(alert_trigger_links, links.make_header_link("Possible Hemoglobin levels decreased by 2 or more or possible Hematocrit levels decreased by 6 or more, along with a possible presence of Bleeding. Please review Clinical Evidence."))
        Result.subtitle = "Possible Acute Blood Loss Anemia"
        Result.passed = true

    elseif not d62_code_link and not low_hemoglobin_d_v_link and signs_of_bleeding and anemia_treatment then
        -- Alert for "Possible Acute Blood Loss Anemia" - Low hemoglobin, sign of bleeding, and anemia treatment
        table.insert(hemoglobin_links, low_hemoglobin_d_v_link)
        table.insert(alert_trigger_links, links.make_header_link("Possible Low Hgb or Hct, possible sign of Bleeding and Anemia Treatment present."))
        Result.subtitle = "Possible Acute Blood Loss Anemia"
        Result.passed = true

    elseif not d62_code_link and (low_hemoglobin10_d_v_link or low_hematocrit30_d_v_link) and signs_of_bleeding then
        -- Alert for "Possible Acute Blood Loss Anemia" -Hgb <10 or Hct <30 and possible sign of Bleeding present
        table.insert(hemoglobin_links, low_hemoglobin10_d_v_link)
        table.insert(hematocrit_links, low_hematocrit30_d_v_link)
        table.insert(alert_trigger_links, links.make_header_link("Possible Hgb <10 or Hct <30 and possible sign of Bleeding present."))
        Result.subtitle = "Possible Acute Blood Loss Anemia"
        Result.passed = true

    elseif not d62_code_link and (d649_code_link or d500_code_link) and signs_of_bleeding and anemia_treatment then
        -- Alert for "Possible Acute Blood Loss Anemia" - Anemia dx and sign of bleeding and anemia treatment
        table.insert(alert_trigger_links, links.make_header_link("Anemia Dx documented, possible sign of bleeding and Anemia Treatment present."))
        table.insert(documented_dx_links, d500_code_link)
        table.insert(documented_dx_links, d649_code_link)
        Result.subtitle = "Possible Acute Blood Loss Anemia"
        Result.passed = true

    elseif
        #account_alert_codes == 0 and
        not d649_code_link and
        (#low_hematocrit_multi_d_v_link_pairs > 0 or #low_hemoglobin_multi_d_v_link_pairs > 0) and
        anemia_treatment
    then
        -- Alert for "Possible Acute Blood Loss Anemia" - Low pairs and anemia treatment
        Result.subtitle = "Possible Anemia Dx"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Abstractions
            table.insert(clinical_evidence_links, links.get_code_link { code = "T45.1X5A", text = "Adverse Effect of Antineoplastic and Immunosuppressive Drug", seq = 1 })
            table.insert(clinical_evidence_links, codes.get_code_prefix_link { prefix = "F10.1", text = "Alcohol Abuse", seq = 2 })
            table.insert(clinical_evidence_links, codes.get_code_prefix_link { prefix = "F10.2", text = "Alcohol Dependence", seq = 3 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "K70.31", text = "Alcoholic Liver Cirrhosis", seq = 4 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "Z51.11", text = "Chemotherapy", seq = 5 })
            table.insert(clinical_evidence_links, links.get_code_link { codes = { "N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.9" }, text = "Chronic Kidney Disease", seq = 6 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "K27.4", text = "Chronic Peptic Ulcer with Hemorrhage", seq = 7 })
            table.insert(clinical_evidence_links, links.get_abstraction_link { code = "CURRENT_CHEMOTHERAPY", text = "Current Chemotherapy", seq = 8 })
            table.insert(clinical_evidence_links, links.get_abstraction_link { code = "DYSPNEA_ON_EXERTION", text = "Dyspnea on Exertion", seq = 9 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "N18.6", text = "End-Stage Renal Disease", seq = 10 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "R53.83", text = "Fatigue", seq = 11 })
            table.insert(clinical_evidence_links, codes.get_code_prefix_link { prefix = "C82.", text = "Follicular Lymphoma", seq = 12 })
            table.insert(clinical_evidence_links, links.get_code_link { codes = { "I50.20", "I50.22", "I50.23", "I50.30", "I50.32", "I50.33", "I50.40", "I5.42", "I50.43", "I50.810", "I50.812", "I50.813", "I50.84", "I50.89", "I50.9" }, text = "Heart Failure", seq = 13 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "D58.0", text = "Hereditary Spherocytosis", seq = 14 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "B20", text = "HIV", seq = 15 })
            table.insert(clinical_evidence_links, codes.get_code_prefix_link { prefix = "C81.", text = "Hodgkin Lymphoma", seq = 16 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "Z51.12", text = "Immunotherapy", seq = 17 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "E61.1", text = "Iron Deficiency", seq = 18 })
            table.insert(clinical_evidence_links, codes.get_code_prefix_link { prefix = "C95.", text = "Leukemia of Unspecified Cell Type", seq = 19 })
            table.insert(clinical_evidence_links, codes.get_code_prefix_link { prefix = "C91.", text = "Lymphoid Leukemia", seq = 20 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "K22.6", text = "Mallory-Weiss Tear", seq = 21 })
            table.insert(clinical_evidence_links, links.get_code_link { codes = { "E40", "E41", "E42", "E43", "E44.0", "E44.1", "E45" }, text = "Malnutrition", seq = 22 })
            table.insert(clinical_evidence_links, codes.get_code_prefix_link { prefix = "C84.", text = "Mature T/NK-Cell Lymphoma", seq = 23 })
            table.insert(clinical_evidence_links, codes.get_code_prefix_link { prefix = "C90.", text = "Multiple Myeloma", seq = 24 })
            table.insert(clinical_evidence_links, codes.get_code_prefix_link { prefix = "C93.", text = "Monocytic Leukemia", seq = 25 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "D46.9", text = "Myelodysplastic Syndrome", seq = 26 })
            table.insert(clinical_evidence_links, codes.get_code_prefix_link { prefix = "C92.", text = "Myeloid Leukemia", seq = 27 })
            table.insert(clinical_evidence_links, codes.get_code_prefix_link { prefix = "C83.", text = "Non-Follicular Lymphoma", seq = 28 })
            table.insert(clinical_evidence_links, codes.get_code_prefix_link { prefix = "C94.", text = "Other Leukemias", seq = 29 })
            table.insert(clinical_evidence_links, codes.get_code_prefix_link { prefix = "C86.", text = "Other Types of T/NK-Cell Lymphoma", seq = 30 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "R23.1", text = "Pale", seq = 31 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "K27.9", text = "Peptic Ulcer", seq = 32 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "F19.10", text = "Psychoactive Substance Abuse", seq = 33 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "Z51.0", text = "Radiation Therapy", seq = 34 })
            table.insert(clinical_evidence_links, codes.get_code_prefix_link { prefix = "M05.", text = "Rheumatoid Arthritis", seq = 35 })
            table.insert(clinical_evidence_links, codes.get_code_prefix_link { prefix = "D86.", text = "Sarcoidosis", seq = 36 })
            table.insert(clinical_evidence_links, links.get_abstraction_link { code = "SHORTNESS_OF_BREATH", text = "Shortness of Breath", seq = 37 })
            table.insert(clinical_evidence_links, codes.get_code_prefix_link { prefix = "D57.", text = "Sickle Cell Disorder", seq = 38 })
            table.insert(clinical_evidence_links, links.get_code_link { code = "R16.1", text = "Splenomegaly", seq = 39 })
            table.insert(clinical_evidence_links, codes.get_code_prefix_link { prefix = "M32.", text = "Systemic Lupus Erthematosus (SLE)", seq = 40 })
            table.insert(clinical_evidence_links, codes.get_code_prefix_link { prefix = "C85.", text = "Unspecified Non-Hodgkin Lymphoma", seq = 41 })
            table.insert(clinical_evidence_links, links.get_abstraction_link { code = "WEAKNESS", text = "Weakness", seq = 42 })

            -- Labs
            table.insert(labs_links, links.get_discrete_value_link { discreteValueNames = dv_mch, text = "MCH", predicate = calc_mch1, seq = 1 })
            table.insert(labs_links, links.get_discrete_value_link { discreteValueNames = dv_mchc, text = "MCHC", predicate = calc_mchc1, seq = 2 })
            table.insert(labs_links, links.get_discrete_value_link { discreteValueNames = dv_mcv, text = "MCV", predicate = calc_mcv1, seq = 3 })
            table.insert(labs_links, links.get_discrete_value_link { discreteValueNames = dv_rbc, text = "RBC", predicate = calc_rbc1, seq = 4 })
            table.insert(labs_links, links.get_discrete_value_link { discreteValueNames = dv_rdw, text = "RDW", predicate = calc_rdw1, seq = 5 })
            table.insert(labs_links, links.get_discrete_value_link { discreteValueNames = dv_reticulocyte_count, text = "Reticulocyte Count", predicate = calc_reticulocyte_count1, seq = 6 })

            local ferritin_args = {
                discreteValueNames = dv_serum_ferritin,
                text = "Serum Ferritin",
                seq = 7,
                predicate = calc_serum_ferritin1,
            }
            local constrained_ferritin = links.get_discrete_value_link(ferritin_args)
            if constrained_ferritin then
                table.insert(labs_links, constrained_ferritin)
            else
                ferritin_args.predicate = nil
                local all_ferritin  = links.get_discrete_value_link(ferritin_args)
                table.insert(labs_links, all_ferritin)
            end

            local folate_args = {
                discreteValueNames = dv_folate,
                text = "Serum Folate",
                seq = 9,
                predicate = calc_folate1,
            }
            local constrained_folate = links.get_discrete_value_link(folate_args)
            if constrained_folate then
                table.insert(labs_links, constrained_folate)
            else
                folate_args.predicate = nil
                local all_folate = links.get_discrete_value_link(folate_args)
                table.insert(labs_links, all_folate)
            end

            local iron_args = {
                discreteValueNames = dv_serum_iron,
                text = "Serum Iron",
                seq = 11,
                predicate = calc_serum_iron1,
            }
            local constrained_iron = links.get_discrete_value_link(iron_args)
            if constrained_iron then
                table.insert(labs_links, constrained_iron)
            else
                iron_args.predicate = nil
                local all_iron = links.get_discrete_value_link(iron_args)
                table.insert(labs_links, all_iron)
            end

            table.insert(labs_links, links.get_discrete_value_link { discreteValueNames = dv_total_iron_binding_capacity, text = "Total Iron Binding Capacity", predicate = calc_total_iron_binding_capacity1, seq = 13 })
            table.insert(labs_links, links.get_discrete_value_link { discreteValueNames = dv_transferrin, text = "Transferrin", predicate = calc_transferrin1, seq = 14 })
            table.insert(labs_links, links.get_discrete_value_link { discreteValueNames = dv_vitamin_b12, text = "Vitamin B12", predicate = calc_vitamin_b12_1, seq = 15 })
            table.insert(labs_links, links.get_discrete_value_link { discreteValueNames = dv_wbc, text = "WBC", predicate = calc_wbc1, seq = 16 })

            -- Meds
            table.insert(treatment_and_monitoring_links, anemia_meds_abstraction_link)
            table.insert(treatment_and_monitoring_links, anemia_medication_link)
            table.insert(treatment_and_monitoring_links, cell_saver_abstraction_link)
            table.insert(treatment_and_monitoring_links, hematopoetic_medication_link)
            table.insert(treatment_and_monitoring_links, hemtopoetic_abstraction_link)
            table.insert(treatment_and_monitoring_links, r_blo_transfusion_code_link)
            table.insert(treatment_and_monitoring_links, red_blood_cell_d_v_link)

            -- Signs of Bleeding
            table.insert(sign_of_bleeding_links, i975_code_link)
            table.insert(sign_of_bleeding_links, k917_code_link)
            table.insert(sign_of_bleeding_links, j957_code_link)
            table.insert(sign_of_bleeding_links, k260_code_link)
            table.insert(sign_of_bleeding_links, k262_code_link)
            table.insert(sign_of_bleeding_links, k250_code_link)
            table.insert(sign_of_bleeding_links, k252_code_link)
            table.insert(sign_of_bleeding_links, k270_code_link)
            table.insert(sign_of_bleeding_links, k272_code_link)
            table.insert(sign_of_bleeding_links, bleeding_abstraction_link)
            table.insert(sign_of_bleeding_links, r319_code_link)
            table.insert(sign_of_bleeding_links, k264_code_link)
            table.insert(sign_of_bleeding_links, k266_code_link)
            table.insert(sign_of_bleeding_links, k254_code_link)
            table.insert(sign_of_bleeding_links, k256_code_link)
            table.insert(sign_of_bleeding_links, k276_code_link)
            table.insert(sign_of_bleeding_links, n99510_code_link)
            table.insert(sign_of_bleeding_links, i8501_code_link)
            table.insert(sign_of_bleeding_links, k922_code_link)
            table.insert(sign_of_bleeding_links, hematoma_abstraction_link)
            table.insert(sign_of_bleeding_links, k920_code_link)
            table.insert(sign_of_bleeding_links, r310_code_link)
            table.insert(sign_of_bleeding_links, r195_code_link)
            table.insert(sign_of_bleeding_links, k661_code_link)
            table.insert(sign_of_bleeding_links, n3091_code_link)
            table.insert(sign_of_bleeding_links, j9501_code_link)
            table.insert(sign_of_bleeding_links, hemorrhage_abstraction_link)
            table.insert(sign_of_bleeding_links, r042_code_link)
            table.insert(sign_of_bleeding_links, i974_code_link)
            table.insert(sign_of_bleeding_links, k916_code_link)
            table.insert(sign_of_bleeding_links, n99_code_link)
            table.insert(sign_of_bleeding_links, g9732_code_link)
            table.insert(sign_of_bleeding_links, g9731_code_link)
            table.insert(sign_of_bleeding_links, j956_code_link)
            table.insert(sign_of_bleeding_links, k921_code_link)
            table.insert(sign_of_bleeding_links, i61_code_link)
            table.insert(sign_of_bleeding_links, i62_code_link)
            table.insert(sign_of_bleeding_links, i60_code_link)
            table.insert(sign_of_bleeding_links, l7632_code_link)
            table.insert(sign_of_bleeding_links, k918_code_link)
            table.insert(sign_of_bleeding_links, i976_code_link)
            table.insert(sign_of_bleeding_links, n991_code_link)
            table.insert(sign_of_bleeding_links, g9752_code_link)
            table.insert(sign_of_bleeding_links, g9751_code_link)
            table.insert(sign_of_bleeding_links, j958_code_link)
            table.insert(sign_of_bleeding_links, k625_code_link)
            for _, link in ipairs(blood_loss_d_v_links) do
                table.insert(sign_of_bleeding_links, link)
            end

            -- Vitals
            table.insert(vitals_links, links.get_abstraction_link { code = "LOW_BLOOD_PRESSURE", text = "Blood Pressure", seq = 1 })
            table.insert(vitals_links, links.get_discrete_value_link { discreteValueNames = dv_map, text = "Mean Arterial Pressure", predicate = calc_map1, seq = 2 })
            table.insert(vitals_links, links.get_discrete_value_link { discreteValueNames = dv_sbp, text = "Systolic Blood Pressure", predicate = calc_sbp1, seq = 3 })

            -- Hemoglobin/Hematocrit
            for _, link in ipairs(low_hematocrit_multi_d_v_link_pairs) do
                table.insert(hematocrit_links, link.hematocritLink)
                table.insert(hemoglobin_links, link.hemoglobinLink)
            end
            for _, link in ipairs(low_hemoglobin_multi_d_v_link_pairs) do
                table.insert(hemoglobin_links, link.hemoglobinLink)
                table.insert(hematocrit_links, link.hematocritLink)
            end
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        if #blood_loss_links > 0 then
            blood_loss_header.links = blood_loss_links
            table.insert(sign_of_bleeding_links, blood_loss_header)
        end
        if #hemoglobin_links > 0 then
            hemoglobin_header.links = hemoglobin_links
            table.insert(labs_links, hemoglobin_header)
        end
        if #hematocrit_links > 0 then
            hematocrit_header.links = hematocrit_links
            table.insert(labs_links, hematocrit_header)
        end
        if #documented_dx_links > 0 then
            documented_dx_header.links = documented_dx_links
            table.insert(result_links, documented_dx_header)
        end
        if #alert_trigger_links > 0 then
            alert_trigger_header.links = alert_trigger_links
            table.insert(result_links, alert_trigger_header)
        end
        if #clinical_evidence_links > 0 then
            clinical_evidence_header.links = clinical_evidence_links
            table.insert(result_links, clinical_evidence_header)
        end
        if #labs_links > 0 then
            labs_header.links = labs_links
            table.insert(result_links, labs_header)
        end
        if #vitals_links > 0 then
            vitals_header.links = vitals_links
            table.insert(result_links, vitals_header)
        end
        if #treatment_and_monitoring_links > 0 then
            treatment_and_monitoring_header.links = treatment_and_monitoring_links
            table.insert(result_links, treatment_and_monitoring_header)
        end
        if #sign_of_bleeding_links > 0 then
            sign_of_bleeding_header.links = sign_of_bleeding_links
            table.insert(result_links, sign_of_bleeding_header)
        end
        if #other_links > 0 then
            other_header.links = other_links
            table.insert(result_links, other_header)
        end


        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end
end
