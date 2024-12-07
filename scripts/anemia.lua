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
local headers = require("libs.common.headers")



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
--- @diagnostic disable: unused-local
local dv_blood_loss = { "" }
local calc_blood_loss1 = function(dv, num) return num > 300 end
local dv_folate = { "" }
local calc_folate1 = function(dv, num) return num < 7.0 end
local dv_hematocrit = { "HEMATOCRIT (%)", "HEMATOCRIT" }
local calc_hematocrit3 = function(dv, num) return num < 30 end
local dv_hemoglobin = { "HEMOGLOBIN", "HEMOGLOBIN (g/dL)" }
local calc_hemoglobin1 = function(dv, num) return num < 13.5 end
local calc_hemoglobin2 = function(dv, num) return num < 12.5 end
local calc_hemoglobin3 = function(dv, num) return num < 10.0 end
local dv_map = { "Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)" }
local calc_map1 = function(dv, num) return num < 70 end
local dv_mch = { "MCH (pg)" }
local calc_mch1 = function(dv, num) return num < 25 end
local dv_mchc = { "MCHC (g/dL)" }
local calc_mchc1 = function(dv, num) return num < 32 end
local dv_mcv = { "MCV (fL)" }
local calc_mcv1 = function(dv, num) return num < 80 end
local dv_rbc = { "RBC  (10X6/uL)" }
local calc_rbc1 = function(dv, num) return num < 3.9 end
local dv_rdw = { "RDW CV (%)" }
local calc_rdw1 = function(dv, num) return num < 11 end
local dv_red_blood_cell_transfusion = { "" }
local dv_reticulocyte_count = { "" }
local calc_reticulocyte_count1 = function(dv, num) return num < 0.5 end
local dv_sbp = { "SBP 3.5 (No Calculation) (mm Hg)" }
local calc_sbp1 = function(dv, num) return num < 90 end
local dv_serum_ferritin = { "FERRITIN (ng/mL)" }
local calc_serum_ferritin1 = function(dv, num) return num < 22 end
local dv_serum_iron = { "IRON TOTAL (ug/dL)" }
local calc_serum_iron1 = function(dv, num) return num < 65 end
local dv_total_iron_binding_capacity = { "IRON BINDING" }
local calc_total_iron_binding_capacity1 = function(dv, num) return num < 246 end
local dv_transferrin = { "TRANSFERRIN" }
local calc_transferrin1 = function(dv, num) return num < 200 end
local dv_vitamin_b12 = { "VITAMIN B12 (pg/mL)" }
local calc_vitamin_b12_1 = function(dv, num) return num < 180 end
local dv_wbc = { "WBC (10x3/ul)" }
local calc_wbc1 = function(dv, num) return num < 4.5 end
local calc_gt_zero = function(dv, num) return num > 0 end

local link_text_possible_no_lows = "Possible No Low Hemoglobin, Low Hematocrit or Anemia Treatment"
local link_text_possible_no_signs_of_bleeding = "Possible No Sign of Bleeding Please Review"
local link_text_possible_no_matching_hemoglobin = "Possible No Hemoglobin Values Meeting Criteria Please Review"
local link_text_possible_no_anemia_treatment = "Possible No Anemia Treatment found"

local link_text_possible_no_lows_present = false
local link_text_possible_no_signs_of_bleeding_present = false
local link_text_possible_no_matching_hemoglobin_present = false
local link_text_possible_no_anemia_treatment_present = false
--- @diagnostic enable: unused-local



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }
local subtitle = existing_alert and existing_alert.subtitle or nil

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
    --- Header Variables and Helper Functions
    --------------------------------------------------------------------------------
    local result_links = {}
    local documented_dx_header = headers.make_header_builder("Documented Dx", 1)
    local alert_trigger_header = headers.make_header_builder("Alert Trigger", 2)
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 3)
    local vital_signs_intake_header = headers.make_header_builder("Vital Signs/Intake", 4)
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 5)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 6)
    local sign_of_bleeding_header = headers.make_header_builder("Sign of Bleeding", 7)
    local hemoglobin_header = headers.make_header_builder("Hemoglobin", 1)
    local hematocrit_header = headers.make_header_builder("Hematocrit", 2)
    local blood_loss_header = headers.make_header_builder("Blood Loss", 3)

    local function compile_links()
        sign_of_bleeding_header:add_link(blood_loss_header:build(true))
        laboratory_studies_header:add_link(hemoglobin_header:build(true))
        laboratory_studies_header:add_link(hematocrit_header:build(true))

        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, alert_trigger_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, vital_signs_intake_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))
        table.insert(result_links, sign_of_bleeding_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end



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
    local d500_code_link =
        links.get_code_link {
            code = "D50.0",
            text = "Iron deficiency anemia secondary to blood loss (chronic)"
        }
    local d62_code_link = links.get_code_link { code = "D62", text = "Acute Posthemorrhagic Anemia" }
    local blood_loss_dv_links =
        links.get_discrete_value_links {
            discreteValueNames = dv_blood_loss,
            text = "Blood Loss: [VALUE]",
            predicate = calc_blood_loss1,
            maxPerValue = 10
        }

    -- Signs of Bleeding
    local i975_code_link =
        links.get_code_link {
            codes = { "I97.51", "I97.52" },
            text = "Accidental Puncture/Laceration of Circulatory System Organ During Procedure"
        }
    local k917_code_link =
        links.get_code_link {
            codes = { "K91.71", "K91.72" },
            text = "Accidental Puncture/Laceration of Digestive System Organ During Procedure"
        }
    local j957_code_link =
        links.get_code_link {
            codes = { "J95.71", "J95.72" },
            text = "Accidental Puncture/Laceration of Respiratory System Organ During Procedure"
        }
    local k260_code_link = links.get_code_link { code = "K26.0", text = "Acute Duodenal Ulcer with Hemorrhage" }
    local k262_code_link = links.get_code_link { code = "K26.2", text = "Acute Duodenal Ulcer with Hemorrhage and Perforation" }
    local k250_code_link = links.get_code_link { code = "K25.0", text = "Acute Gastric Ulcer with Hemorrhage" }
    local k252_code_link = links.get_code_link { code = "K25.2", text = "Acute Gastric Ulcer with Hemorrhage and Perforation" }
    local k270_code_link = links.get_code_link { code = "K27.0", text = "Acute Peptic Ulcer with Hemorrhage" }
    local k272_code_link = links.get_code_link { code = "K27.2", text = "Acute Peptic Ulcer with Hemorrhage and Perforation" }
    local bleeding_abstraction_link = links.get_abstraction_link { code = "BLEEDING", text = "Bleeding" }
    local r319_code_link = links.get_code_link { code = "R31.9", text = "Bloody Urine" }
    local k264_code_link = links.get_code_link { code = "K26.4", text = "Chronic Duodenal Ulcer with Hemorrhage" }
    local k266_code_link = links.get_code_link { code = "K26.6", text = "Chronic Duodenal Ulcer with Hemorrhage and Perforation" }
    local k254_code_link = links.get_code_link { code = "K25.4", text = "Chronic Gastric Ulcer with Hemorrhage" }
    local k256_code_link = links.get_code_link { code = "K25.6", text = "Chronic Gastric Ulcer with Hemorrhage and Perforation" }
    local k276_code_link = links.get_code_link { code = "K27.6", text = "Chronic Peptic Ulcer with Hemorrhage and Perforation" }
    local n99510_code_link = links.get_code_link { code = "N99.510", text = "Cystostomy Hemorrhage" }
    local r040_code_link = links.get_code_link { code = "R04.0", text = "Epistaxis" }
    local i8501_code_link = links.get_code_link { code = "I85.01", text = "Esophageal Varices with Bleeding" }
    local ebl_abstraction_link = links.get_abstraction_link { code = "ESTIMATED_BLOOD_LOSS", text = "Estimated Blood Loss" }
    local k922_code_link = links.get_code_link { code = "K92.2", text = "GI Hemorrhage" }
    local hematoma_abstraction_link = links.get_abstraction_link { code = "HEMATOMA", text = "Hematoma" }
    local k920_code_link = links.get_code_link { code = "K92.0", text = "Hematemesis" }
    local r310_code_link = codes.get_code_prefix_link { prefix = "R31", text = "Hematuria", maxPerValue = 1 }
    local r195_code_link = links.get_code_link { code = "R19.5", text = "Heme-Positive Stool" }
    local k661_code_link = links.get_code_link { code = "K66.1", text = "Hemoperitoneum" }
    local hemorrhage_abstraction_link = links.get_abstraction_link { code = "HEMORRHAGE", text = "Hemorrhage" }
    local n3091_code_link = links.get_code_link { code = "N30.91", text = "Hemorrhagic Cystitis" }
    local j9501_code_link = links.get_code_link { code = "J95.01", text = "Hemorrhage from Tracheostomy Stoma" }
    local r042_code_link = links.get_code_link { code = "R04.2", text = "Hemoptysis" }
    local i974_code_link =
        links.get_code_link {
            codes = { "I97.410", "I97.411", "I97.418", "I97.42" },
            text = "Intraoperative Hemorrhage/Hematoma of Circulatory System Organ"
        }
    local k916_code_link = links.get_code_link { codes = { "K91.61", "K91.62" }, text = "Intraoperative Hemorrhage/Hematoma of Digestive System Organ" }
    local n99_code_link = links.get_code_link { codes = { "N99.61", "N99.62" }, text = "Intraoperative Hemorrhage/Hematoma of Genitourinary System" }
    local g9732_code_link = links.get_code_link { code = "G97.32", text = "Intraoperative Hemorrhage/Hematoma of Nervous System Organ" }
    local g9731_code_link = links.get_code_link { code = "G97.31", text = "Intraoperative Hemorrhage/Hematoma of Nervous System Procedure" }
    local j956_code_link = links.get_code_link { codes = { "J95.61", "J95.62" }, text = "Intraoperative Hemorrhage/Hematoma of Respiratory System" }
    local k921_code_link = links.get_code_link { code = "K92.1", text = "Melena" }
    local i61_code_link = codes.get_code_prefix_link { prefix = "I61", text = "Nontraumatic Intracerebral Hemorrhage" }
    local i62_code_link = codes.get_code_prefix_link { prefix = "I62", text = "Nontraumatic Intracerebral Hemorrhage" }
    local i60_code_link = codes.get_code_prefix_link { prefix = "I60", text = "Nontraumatic Subarachnoid Hemorrhage" }
    local l7632_code_link = links.get_code_link { code = "L76.32", text = "Postoperative Hematoma" }
    local k918_code_link =
        links.get_code_link {
            codes = { "K91.840", "K91.841", "K91.870", "K91.871" },
            text = "Postoperative Hemorrhage/Hematoma of Digestive System Organ"
        }
    local i976_code_link =
        links.get_code_link {
            codes = { "I97.610", "I97.611", "I97.618", "I97.620" },
            text = "Postoperative Hemorrhage/Hematoma of Circulatory System Organ"
        }
    local n991_code_link =
        links.get_code_link {
            codes = { "N99.820", "N99.821", "N99.840", "N99.841" },
            text = "Postoperative Hemorrhage/Hematoma of Genitourinary System"
        }
    local g9752_code_link = links.get_code_link { code = "G97.52", text = "Postoperative Hemorrhage/Hematoma of Nervous System Organ" }
    local g9751_code_link = links.get_code_link { code = "G97.51", text = "Postoperative Hemorrhage/Hematoma of Nervous System Procedure" }
    local j958_code_link =
        links.get_code_link {
            codes = { "J95.830", "J95.831", "J95.860", "J95.861" },
            text = "Postoperative Hemorrhage/Hematoma of Respiratory System"
        }
    local k625_code_link = links.get_code_link { code = "K62.5", text = "Rectal Bleeding" }

    -- Labs
    local gender = Account.patient and Account.patient.gender or ""
    laboratory_studies_header:add_link(
        discrete.get_discrete_value_pairs_as_combined_single_line_link {
            discreteValueNames1 = dv_hemoglobin,
            discreteValueNames2 = dv_hematocrit,
            linkTemplate = "Hemoglobin/Hematocrit: ([DATE1] - [DATE2]) - [VALUE_PAIRS]",
        }
    )
    local low_hemoglobin10_dv_link =
        links.get_discrete_value_link { discreteValueNames = dv_hemoglobin, text = "Hemoglobin", predicate = calc_hemoglobin3 }
    local low_hematocrit30_dv_link =
        links.get_discrete_value_link { discreteValueNames = dv_hematocrit, text = "Hematocrit", predicate = calc_hematocrit3 }
    local low_hemoglobin_dv_link =
        links.get_discrete_value_link {
            discreteValueNames = dv_hemoglobin,
            text = "Hemoglobin",
            predicate = gender == "F" and calc_hemoglobin2 or calc_hemoglobin1
        }

    local low_hemoglobin_multi_dv_link_pairs = blood.get_low_hemoglobin_discrete_value_pairs(gender)
    local low_hematocrit_multi_dv_link_pairs = blood.get_low_hematocrit_discrete_value_pairs(gender)

    local hematocrit_drop_dv_link_pairs = blood.get_hematocrit_drop_pairs()
    local hemoglobin_drop_dv_link_pairs = blood.get_hemoglobin_drop_pairs()

    -- Meds
    local anemia_meds_abstraction_link = links.get_abstraction_link { code = "ANEMIA_MEDICATION", text = "Anemia Medication" }
    local anemia_medication_link = links.get_medication_link { cat = "Anemia Supplements", text = "Anemia Supplements" }
    local cell_saver_abstraction_link = links.get_abstraction_link { code = "CELL_SAVER", text = "Cell Saver" }
    local hematopoetic_medication_link = links.get_medication_link { cat = "Hemopoietic Agent", text = "Hematopoietic Agent" }
    local hemtopoetic_abstraction_link = links.get_abstraction_link { code = "HEMATOPOIETIC_AGENT", text = "Hematopoietic Agent" }
    local r_blo_transfusion_code_link = links.get_code_link { codes = { "30233N1", "30243N1" }, text = "Red Blood Cell Transfusion" }
    local red_blood_cell_dv_link =
        links.get_discrete_value_link {
            discreteValueNames = dv_red_blood_cell_transfusion,
            text = "Red Blood Cell Transfusion",
            predicate = calc_gt_zero
        }

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
        #blood_loss_dv_links > 0 and
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
        (low_hemoglobin_dv_link or low_hematocrit30_dv_link)
    then
        -- Autoresolve "Anemia Dx Possibly Lacking Supporting Evidence"
        if link_text_possible_no_lows_present then
            local link = links.make_header_link(link_text_possible_no_lows)
            documented_dx_header:add_link(link)
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
            (not link_text_possible_no_matching_hemoglobin_present or low_hemoglobin_dv_link) and
            (not link_text_possible_no_anemia_treatment_present or not anemia_treatment)
        )
    then
        -- Autoresolve "Acute Blood Loss Anemia Dx Possibly Lacking Clinical Evidence"
        if low_hemoglobin_dv_link then
            low_hemoglobin_dv_link.link_text = "Autoresolved Evidence - " .. low_hemoglobin_dv_link.link_text
            documented_dx_header:add_link(low_hemoglobin_dv_link)
        end
        if link_text_possible_no_signs_of_bleeding_present then
            documented_dx_header:add_text_link(link_text_possible_no_signs_of_bleeding)
        end
        if link_text_possible_no_matching_hemoglobin_present then
            documented_dx_header:add_text_link(link_text_possible_no_matching_hemoglobin)
        end
        if link_text_possible_no_anemia_treatment_present then
            documented_dx_header:add_text_link(link_text_possible_no_anemia_treatment)
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
        documented_dx_header:add_link(d62_code_link)
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
                documented_dx_header:add_link(temp_code)
                break
            end
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.validated = true
        Result.passed = true

    elseif #account_alert_codes > 0 and not low_hemoglobin_dv_link and not low_hematocrit30_dv_link and not anemia_treatment then
        -- Alert for "Anemia Dx Possibly Lacking Supporting Evidence"
        if not low_hemoglobin_dv_link or not anemia_treatment then
            documented_dx_header:add_text_link(link_text_possible_no_lows)
        end
        for _, code in ipairs(account_alert_codes) do
            local desc = alert_code_dictionary[code]
            local temp_code = links.get_code_link { code = code, text = desc }
            if temp_code then
                documented_dx_header:add_link(temp_code)
            end
        end
        Result.subtitle = "Anemia Dx Possibly Lacking Supporting Evidence"
        Result.passed = true

    elseif d62_code_link and (not signs_of_bleeding or not low_hemoglobin_dv_link or not anemia_treatment) then
        -- Alert for "Acute Blood Loss Anemia Dx Possibly Lacking Clinical Evidence"
        documented_dx_header:add_link(d62_code_link)

        local link2 = links.make_header_link(link_text_possible_no_signs_of_bleeding)
        link2.is_validated = not (link_text_possible_no_signs_of_bleeding_present and signs_of_bleeding)
        documented_dx_header:add_link(link2)

        local link3 = links.make_header_link(link_text_possible_no_matching_hemoglobin)
        link3.is_validated = not (link_text_possible_no_matching_hemoglobin_present and low_hemoglobin_dv_link)
        documented_dx_header:add_link(link3)

        local link4 = links.make_header_link(link_text_possible_no_anemia_treatment)
        link4.is_validated = not (link_text_possible_no_anemia_treatment_present and anemia_treatment)
        documented_dx_header:add_link(link4)

        Result.subtitle = "Acute Blood Loss Anemia Dx Possibly Lacking Clinical Evidence"
        Result.passed = true

    elseif not d62_code_link and (#hematocrit_drop_dv_link_pairs > 0 or #hemoglobin_drop_dv_link_pairs > 0) then
        -- Alert for "Possible Acute Blood Loss Anemia" - Drops
        if hematocrit_drop_dv_link_pairs then
            hematocrit_header:add_link(hematocrit_drop_dv_link_pairs.hematocritDropLink)
            hematocrit_header:add_link(hematocrit_drop_dv_link_pairs.hematocritPeakLink)
            hematocrit_header:add_link(hematocrit_drop_dv_link_pairs.hemoglobinDropLink)
            hematocrit_header:add_link(hematocrit_drop_dv_link_pairs.hemoglobinPeakLink)
        end
        if hemoglobin_drop_dv_link_pairs then
            hemoglobin_header:add_link(hemoglobin_drop_dv_link_pairs.hemoglobinDropLink)
            hemoglobin_header:add_link(hemoglobin_drop_dv_link_pairs.hemoglobinPeakLink)
            hemoglobin_header:add_link(hemoglobin_drop_dv_link_pairs.hematocritDropLink)
            hemoglobin_header:add_link(hemoglobin_drop_dv_link_pairs.hematocritPeakLink)
        end
        alert_trigger_header:add_text_link(
            [[
            Possible Hemoglobin levels decreased by 2 or more or possible Hematocrit levels decreased by 6 or more,
            along with a possible presence of Bleeding. Please review Clinical Evidence.
            ]]
        )
        Result.subtitle = "Possible Acute Blood Loss Anemia"
        Result.passed = true

    elseif not d62_code_link and not low_hemoglobin_dv_link and signs_of_bleeding and anemia_treatment then
        -- Alert for "Possible Acute Blood Loss Anemia" - Low hemoglobin, sign of bleeding, and anemia treatment
        hemoglobin_header:add_link(low_hemoglobin_dv_link)
        alert_trigger_header:add_text_link(
            [[
            Possible Low Hgb or Hct, possible sign of Bleeding and Anemia Treatment present. Please review Clinical
            Evidence.
            ]]
        )
        Result.subtitle = "Possible Acute Blood Loss Anemia"
        Result.passed = true

    elseif not d62_code_link and (low_hemoglobin10_dv_link or low_hematocrit30_dv_link) and signs_of_bleeding then
        -- Alert for "Possible Acute Blood Loss Anemia" -Hgb <10 or Hct <30 and possible sign of Bleeding present
        hemoglobin_header:add_link(low_hemoglobin10_dv_link)
        hematocrit_header:add_link(low_hematocrit30_dv_link)
        alert_trigger_header:add_text_link(
            "Possible Hgb <10 or Hct <30 and possible sign of Bleeding present. Please review Clinical Evidence."
        )
        Result.subtitle = "Possible Acute Blood Loss Anemia"
        Result.passed = true

    elseif not d62_code_link and (d649_code_link or d500_code_link) and signs_of_bleeding and anemia_treatment then
        -- Alert for "Possible Acute Blood Loss Anemia" - Anemia dx and sign of bleeding and anemia treatment
        alert_trigger_header:add_text_link(
            "Possible Anemia Dx documented, possible sign of bleeding and Anemia Treatment present. Please review Clinical Evidence."
        )
        documented_dx_header:add_link(d500_code_link)
        documented_dx_header:add_link(d649_code_link)

        Result.subtitle = "Possible Acute Blood Loss Anemia"
        Result.passed = true

    elseif
        #account_alert_codes == 0 and
        not d649_code_link and
        (#low_hematocrit_multi_dv_link_pairs > 0 or #low_hemoglobin_multi_dv_link_pairs > 0) and
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
            clinical_evidence_header:add_code_link("F10.1", "Alcohol Abuse")
            clinical_evidence_header:add_code_link("F10.2", "Alcohol Dependence")
            clinical_evidence_header:add_code_link("K70.31", "Alcoholic Liver Cirrhosis")
            clinical_evidence_header:add_code_link("Z51.11", "Chemotherapy")
            clinical_evidence_header:add_code_link("N18.1", "Chronic Kidney Disease")
            clinical_evidence_header:add_code_link("K27.4", "Chronic Peptic Ulcer with Hemorrhage")
            clinical_evidence_header:add_abstraction_link("CURRENT_CHEMOTHERAPY", "Current Chemotherapy")
            clinical_evidence_header:add_abstraction_link("DYSPNEA_ON_EXERTION", "Dyspnea on Exertion")
            clinical_evidence_header:add_code_link("N18.6", "End-Stage Renal Disease")
            clinical_evidence_header:add_code_link("R53.83", "Fatigue")
            clinical_evidence_header:add_code_prefix_link("C82%.", "Follicular Lymphoma")
            clinical_evidence_header:add_code_links(
                {
                    "I50.20", "I50.22", "I50.23", "I50.30", "I50.32", "I50.33", "I50.40", "I5.42", "I50.43", "I50.810",
                    "I50.812", "I50.813", "I50.84", "I50.89", "I50.9"
                },
                "Heart Failure"
            )
            clinical_evidence_header:add_code_link("D58.0", "Hereditary Spherocytosis")
            clinical_evidence_header:add_code_link("B20", "HIV")
            clinical_evidence_header:add_code_prefix_link("C81%.", "Hodgkin Lymphoma")
            clinical_evidence_header:add_code_link("Z51.12", "Immunotherapy")
            clinical_evidence_header:add_code_link("E61.1", "Iron Deficiency")
            clinical_evidence_header:add_code_prefix_link("C95%.", "Leukemia of Unspecified Cell Type")
            clinical_evidence_header:add_code_prefix_link("C91%.", "Lymphoid Leukemia")
            clinical_evidence_header:add_code_link("K22.6", "Mallory-Weiss Tear")
            clinical_evidence_header:add_code_links(
                { "E40", "E41", "E42", "E43", "E44.0", "E44.1", "E45" },
                "Malnutrition"
            )
            clinical_evidence_header:add_code_prefix_link("C84%.", "Mature T/NK-Cell Lymphoma")
            clinical_evidence_header:add_code_prefix_link("C90%.", "Multiple Myeloma")
            clinical_evidence_header:add_code_prefix_link("C93%.", "Monocytic Leukemia")
            clinical_evidence_header:add_code_link("D46.9", "Myelodysplastic Syndrome")
            clinical_evidence_header:add_code_prefix_link("C92%.", "Myeloid Leukemia")
            clinical_evidence_header:add_code_prefix_link("C83%.", "Non-Follicular Lymphoma")
            clinical_evidence_header:add_code_prefix_link("C94%.", "Other Leukemias")
            clinical_evidence_header:add_code_prefix_link("C86%.", "Other Types of T/NK-Cell Lymphoma")
            clinical_evidence_header:add_code_link("R23.1", "Pale")
            clinical_evidence_header:add_code_link("K27.9", "Peptic Ulcer")
            clinical_evidence_header:add_code_link("F19.10", "Psychoactive Substance Abuse")
            clinical_evidence_header:add_code_link("Z51.0", "Radiation Therapy")
            clinical_evidence_header:add_code_prefix_link("M05%.", "Rheumatoid Arthritis")
            clinical_evidence_header:add_code_prefix_link("D86%.", "Sarcoidosis")
            clinical_evidence_header:add_abstraction_link("SHORTNESS_OF_BREATH", "Shortness of Breath")
            clinical_evidence_header:add_code_prefix_link("D57%.", "Sickle Cell Disorder")
            clinical_evidence_header:add_code_link("R16.1", "Splenomegaly")
            clinical_evidence_header:add_code_prefix_link("M32%.", "Systemic Lupus Erthematosus (SLE)")
            clinical_evidence_header:add_code_prefix_link("C85%.", "Unspecified Non-Hodgkin Lymphoma")
            clinical_evidence_header:add_abstraction_link("WEAKNESS", "Weakness")

            -- Labs
            laboratory_studies_header:add_discrete_value_one_of_link(dv_mch, "MCH", calc_mch1)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_mchc, "MCHC", calc_mchc1)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_mcv, "MCV", calc_mcv1)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_rbc, "RBC", calc_rbc1)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_rdw, "RDW", calc_rdw1)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_reticulocyte_count, "Reticulocyte Count", calc_reticulocyte_count1)

            local ferritin_args = {
                discreteValueNames = dv_serum_ferritin,
                text = "Serum Ferritin",
                seq = 7,
                predicate = calc_serum_ferritin1,
            }
            local constrained_ferritin = links.get_discrete_value_link(ferritin_args)
            if constrained_ferritin then
                laboratory_studies_header:add_link(constrained_ferritin)
            else
                ferritin_args.predicate = nil
                local all_ferritin  = links.get_discrete_value_link(ferritin_args)
                laboratory_studies_header:add_link(all_ferritin)
            end

            local folate_args = {
                discreteValueNames = dv_folate,
                text = "Serum Folate",
                seq = 9,
                predicate = calc_folate1,
            }
            local constrained_folate = links.get_discrete_value_link(folate_args)
            if constrained_folate then
                laboratory_studies_header:add_link(constrained_folate)
            else
                folate_args.predicate = nil
                local all_folate = links.get_discrete_value_link(folate_args)
                laboratory_studies_header:add_link(all_folate)
            end

            local iron_args = {
                discreteValueNames = dv_serum_iron,
                text = "Serum Iron",
                seq = 11,
                predicate = calc_serum_iron1,
            }
            local constrained_iron = links.get_discrete_value_link(iron_args)
            if constrained_iron then
                laboratory_studies_header:add_link(constrained_iron)
            else
                iron_args.predicate = nil
                local all_iron = links.get_discrete_value_link(iron_args)
                laboratory_studies_header:add_link(all_iron)
            end

            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_total_iron_binding_capacity,
                "Total Iron Binding Capacity",
                calc_total_iron_binding_capacity1
            )
            laboratory_studies_header:add_discrete_value_one_of_link(dv_transferrin, "Transferrin", calc_transferrin1)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_vitamin_b12, "Vitamin B12", calc_vitamin_b12_1)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_wbc, "WBC", calc_wbc1)

            -- Meds
            treatment_and_monitoring_header:add_link(anemia_meds_abstraction_link)
            treatment_and_monitoring_header:add_link(anemia_medication_link)
            treatment_and_monitoring_header:add_link(cell_saver_abstraction_link)
            treatment_and_monitoring_header:add_link(hematopoetic_medication_link)
            treatment_and_monitoring_header:add_link(hemtopoetic_abstraction_link)
            treatment_and_monitoring_header:add_link(r_blo_transfusion_code_link)
            treatment_and_monitoring_header:add_link(red_blood_cell_dv_link)

            -- Signs of Bleeding
            sign_of_bleeding_header:add_link(i975_code_link)
            sign_of_bleeding_header:add_link(k917_code_link)
            sign_of_bleeding_header:add_link(j957_code_link)
            sign_of_bleeding_header:add_link(k260_code_link)
            sign_of_bleeding_header:add_link(k262_code_link)
            sign_of_bleeding_header:add_link(k250_code_link)
            sign_of_bleeding_header:add_link(k252_code_link)
            sign_of_bleeding_header:add_link(k270_code_link)
            sign_of_bleeding_header:add_link(k272_code_link)
            sign_of_bleeding_header:add_link(bleeding_abstraction_link)
            sign_of_bleeding_header:add_link(r319_code_link)
            sign_of_bleeding_header:add_link(k264_code_link)
            sign_of_bleeding_header:add_link(k266_code_link)
            sign_of_bleeding_header:add_link(k254_code_link)
            sign_of_bleeding_header:add_link(k256_code_link)
            sign_of_bleeding_header:add_link(k276_code_link)
            sign_of_bleeding_header:add_link(n99510_code_link)
            sign_of_bleeding_header:add_link(i8501_code_link)
            sign_of_bleeding_header:add_link(k922_code_link)
            sign_of_bleeding_header:add_link(hematoma_abstraction_link)
            sign_of_bleeding_header:add_link(k920_code_link)
            sign_of_bleeding_header:add_link(r310_code_link)
            sign_of_bleeding_header:add_link(r195_code_link)
            sign_of_bleeding_header:add_link(k661_code_link)
            sign_of_bleeding_header:add_link(n3091_code_link)
            sign_of_bleeding_header:add_link(j9501_code_link)
            sign_of_bleeding_header:add_link(hemorrhage_abstraction_link)
            sign_of_bleeding_header:add_link(r042_code_link)
            sign_of_bleeding_header:add_link(i974_code_link)
            sign_of_bleeding_header:add_link(k916_code_link)
            sign_of_bleeding_header:add_link(n99_code_link)
            sign_of_bleeding_header:add_link(g9732_code_link)
            sign_of_bleeding_header:add_link(g9731_code_link)
            sign_of_bleeding_header:add_link(j956_code_link)
            sign_of_bleeding_header:add_link(k921_code_link)
            sign_of_bleeding_header:add_link(i61_code_link)
            sign_of_bleeding_header:add_link(i62_code_link)
            sign_of_bleeding_header:add_link(i60_code_link)
            sign_of_bleeding_header:add_link(l7632_code_link)
            sign_of_bleeding_header:add_link(k918_code_link)
            sign_of_bleeding_header:add_link(i976_code_link)
            sign_of_bleeding_header:add_link(n991_code_link)
            sign_of_bleeding_header:add_link(g9752_code_link)
            sign_of_bleeding_header:add_link(g9751_code_link)
            sign_of_bleeding_header:add_link(j958_code_link)
            sign_of_bleeding_header:add_link(k625_code_link)

            sign_of_bleeding_header:add_links(blood_loss_dv_links)

            -- Vitals
            vital_signs_intake_header:add_abstraction_link("LOW_BLOOD_PRESSURE", "Low Blood Pressure")
            vital_signs_intake_header:add_discrete_value_one_of_link(dv_map, "Mean Arterial Pressure", calc_map1)
            vital_signs_intake_header:add_discrete_value_one_of_link(dv_sbp, "Systolic Blood Pressure", calc_sbp1)

            -- Hemoglobin/Hematocrit
            for _, link in ipairs(low_hematocrit_multi_dv_link_pairs) do
                hematocrit_header:add_link(link.hematocritLink)
                hematocrit_header:add_link(link.hemoglobinLink)
            end
            for _, link in ipairs(low_hemoglobin_multi_dv_link_pairs) do
                hemoglobin_header:add_link(link.hemoglobinLink)
                hemoglobin_header:add_link(link.hematocritLink)
            end
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end
