---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Pancytopenia
---
--- This script checks an account to see if it matches the criteria for a pancytopenia alert.
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
local discrete = require("libs.common.discrete_values")(Account)
local headers = require("libs.common.headers")(Account)



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local dv_absolute_basophil = { "" }
local calc_absolute_basophil1 = function(dv_, num) return num > 200 end
local dv_basophil_auto = { "BASOPHILS (%)", "BASOS (%)" }
local dv_absolute_eosinophil = { "EOSIN ABSOLUTE (10X3/uL)" }
local calc_absolute_eosinophil1 = function(dv_, num) return num > 500 end
local dv_eosinophil_auto = { "EOS (%)" }
local dv_absolute_lymphocyte = { "" }
local calc_absolute_lymphocyte1 = function(dv_, num) return num < 1000 end
local dv_lymphocyte_auto = { "LYMPHS (%)" }
local dv_absolute_monocyte = { "" }
local calc_absolute_monocyte1 = function(dv_, num) return num < 200 end
local dv_monocyte_auto = { "MONOS (%)" }
local dv_absolute_neutrophil = { "ABS NEUT COUNT (10x3/uL)" }
local calc_absolute_neutrophil1 = function(dv_, num) return num < 1.5 end
local dv_neutrophil_auto = { "" }
local calc_dbc1 = function(dv_, num) return num >= 0.0 end
local dv_hematocrit = { "HEMATOCRIT (%)", "HEMATOCRIT" }
local dv_hemoglobin = { "HEMOGLOBIN", "HEMOGLOBIN (g/dL)" }
local dv_platelet_count = { "PLATELET COUNT (10x3/uL)" }
local calc_platelet_count1 = function(dv_, num) return num < 150 end
local dv_platelet_transfusion = { "" }
local dv_rbc = { "" }
local calc_rbc1 = function(dv_, num) return num > 4.4 end
local dv_red_blood_cell_transfusion = { "" }
local dv_serum_folate = { "" }
local dv_vitamin_b12 = { "VITAMIN B12 (pg/mL)" }
local calc_vitamin_b121 = function(dv_, num) return num < 180 end
local dv_wbc = { "WBC (10x3/ul)" }
local calc_wbc1 = function(dv_, num) return num < 4.5 end



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
    local documented_dx_header = headers.make_header_builder("Documented Dx", 1)
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 3)
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 5)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 6)
    local wbc_header = headers.make_header_builder("White Blood Cells", 90)
    local hemoglobin_header = headers.make_header_builder("Hemoglobin", 91)
    local hematocrit_header = headers.make_header_builder("Hematocrit", 92)
    local platelet_header = headers.make_header_builder("Platelet", 93)
    local dbc_header = headers.make_header_builder("Differential Blood Count (Auto Diff)", 94)

    local function compile_links()
        laboratory_studies_header:add_link(dbc_header:build(true))
        laboratory_studies_header:add_link(hematocrit_header:build(true))
        laboratory_studies_header:add_link(hemoglobin_header:build(true))
        laboratory_studies_header:add_link(platelet_header:build(true))
        laboratory_studies_header:add_link(wbc_header:build(true))

        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
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
        ["D61.810"] = "Antineoplastic Chemotherapy Induced Pancytopenia",
        ["D61.811"] = "Other Drug-Induced Pancytopenia",
        ["D61.818"] = "Other Pancytopenia"
    }
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Negations
    local d62_code =
        links.get_code_link { code = "D62", text = "Acute Posthemorrhagic Anemia" }
    local hemorrhage_abs =
        links.get_abstract_value_link { abstractValue = "HEMORRHAGE", text = "Hemorrhage" }

    -- Documented Dx
    local d61810_code =
        links.get_code_link { code = "D61.810", text = "Antineoplastic chemotherapy induced pancytopenia" }
    local d61811_code =
        links.get_code_link { code = "D61.811", text = "Other drug-induced pancytopenia" }
    local d61818_code =
        links.get_code_link { code = "D61.818", text = "Other pancytopenia" }

    -- Abs
    local a3e04305_code =
        links.get_code_link { code = "3E04305", text = "Chemotherapy Medication Administration" }
    local current_chemotherapy_abs =
        links.get_abstract_value_link { abstractValue = "CURRENT_CHEMOTHERAPY", linkTemplate = "Current Chemotherapy" }

    -- Meds
    local z5111_code =
        links.get_code_link { code = "Z51.11", text = "Antineoplastic Chemotherapy" }

    -- Hemoglobin/Hematocrit
    local low_hemoglobin_multi_dv = discrete.get_discrete_value_pairs_as_link_pairs {
        discreteValueNames1 = dv_hemoglobin,
        discreteValueNames2 = dv_hematocrit,
        predicate1 = function(dv) return dv < (Account.patient.gender == "F" and 11.6 or 13.5) end,
        linkTemplate1 = "Hemoglobin",
        linkTemplate2 = "Hematocrit",
        maxPairs = 10
    }

    -- Platlet
    local low_platelet_dv = links.get_discrete_value_links {
        discreteValueNames = dv_platelet_count,
        text = "Platelet Count",
        predicate = calc_platelet_count1,
        max_per_value = 10
    }

    -- WBC
    local low_wbc_dv = links.get_discrete_value_links {
        discreteValueNames = dv_wbc,
        text = "WBC",
        predicate = calc_wbc1,
        max_per_value = 10
    }



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if
        subtitle == "Panyctopenia Dx Lacking Supporting Evidence" and
        #low_hemoglobin_multi_dv > 0 and
        #low_wbc_dv > 0 and
        #low_platelet_dv > 0
    then
        if #low_hemoglobin_multi_dv > 0 then
            documented_dx_header:add_text_link("Possibly No Low Hemoglobin Values Found", false)
        end
        if #low_wbc_dv > 0 then
            documented_dx_header:add_text_link("Possibly No Low White Blood Cell Values Found", false)
        end
        if #low_platelet_dv > 0 then
            documented_dx_header:add_text_link("Possibly No Low Platelet Values Found", false)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif #account_alert_codes > 0 and #low_hemoglobin_multi_dv == 0 and #low_wbc_dv == 0 and #low_platelet_dv == 0 then
        for _, code in ipairs(account_alert_codes) do
            local desc = alert_code_dictionary[code]
            local temp_code = links.get_code_link { code = code, text = desc }
            documented_dx_header:add_link(temp_code)
        end
        if #low_hemoglobin_multi_dv == 0 then
            documented_dx_header:add_text_link("No Low Hemoglobin Values Found", true)
        end
        if #low_wbc_dv == 0 then
            documented_dx_header:add_text_link("No Low White Blood Cell Values Found", true)
        end
        if #low_platelet_dv == 0 then
            documented_dx_header:add_text_link("No Low Platelet Values Found", true)
        end
        Result.subtitle = "Pancytopenia Dx Lacking Supporting Evidence"
        Result.passed = true

    elseif (d61810_code or d61811_code) and subtitle == "Pancytopenia with Possible Link to Chemotherapy" then
        if d61810_code then
            d61810_code.link_text = "Autoresolved Specified Code - " .. d61810_code.link_text
            documented_dx_header:add_link(d61810_code)
        end
        if d61811_code then
            d61811_code.link_text = "Autoresolved Specified Code - " .. d61811_code.link_text
            documented_dx_header:add_link(d61811_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif not d61810_code and not d61811_code and d61818_code and (z5111_code or a3e04305_code or current_chemotherapy_abs) then
        documented_dx_header:add_link(d61818_code)
        Result.subtitle = "Pancytopenia with Possible Link to Chemotherapy"
        Result.passed = true

    elseif #account_alert_codes > 0 and subtitle == "Possible Pancytopenia Dx" then
        for _, code in ipairs(account_alert_codes) do
            local desc = alert_code_dictionary[code]
            local temp_code = links.get_code_link { code = code, text = desc }
            if temp_code then
                documented_dx_header:add_link(temp_code)
                break
            end
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        #account_alert_codes == 0 and
        not d62_code and
        not hemorrhage_abs and
        #low_wbc_dv > 1 and
        #low_platelet_dv > 1 and
        #low_hemoglobin_multi_dv > 1
    then
        Result.subtitle = "Possible Pancytopenia Dx"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Clinical Evidence
            clinical_evidence_header:add_code_prefix_link("B15%.", "Acute Hepatitis A")
            clinical_evidence_header:add_code_prefix_link("B16%.", "Acute Hepatitis B")
            clinical_evidence_header:add_code_prefix_link("B17%.", "Acute Hepatitis Viral Hepatitis")
            clinical_evidence_header:add_code_link("T45.1X5A", "Adverse Effect of Antineoplastic and Immunosuppressive Drug")
            clinical_evidence_header:add_code_link("F10.20", "Alcohol Abuse")
            clinical_evidence_header:add_code_link("D61.9", "Aplastic Anemia")
            if a3e04305_code then
                clinical_evidence_header:add_link(a3e04305_code)
            end
            clinical_evidence_header:add_code_prefix_link("B18%.", "Chronic Viral Hepatitis")
            clinical_evidence_header:add_code_one_of_link(
                { "N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.9" },
                "Chronic Kidney Disease"
            )
            if current_chemotherapy_abs then
                clinical_evidence_header:add_link(current_chemotherapy_abs)
            end
            clinical_evidence_header:add_code_link("N18.6", "End-Stage Renal Disease")
            clinical_evidence_header:add_code_link("R53.83", "Fatigue")
            clinical_evidence_header:add_code_prefix_link("C82%.", "Follicular Lymphoma")
            clinical_evidence_header:add_code_link("E75.22", "Gauchers Disease")
            clinical_evidence_header:add_code_link("D76.1", "Hemophagocytic Lymphohistiocytosis")
            clinical_evidence_header:add_code_link("D76.2", "Hemophagocytic Syndrome")
            clinical_evidence_header:add_code_link("B20%.", "HIV")
            clinical_evidence_header:add_code_link("C81%.", "Hodgkin Lymphoma")
            clinical_evidence_header:add_code_link("Z51.12", "Immunotherapy")
            clinical_evidence_header:add_abstraction_link_with_value("INFECTION", "Infection")
            clinical_evidence_header:add_code_prefix_link("C95%.", "Leukemia of Unspecified Cell Type")
            clinical_evidence_header:add_code_link("K74.60", "Liver Cirrhosis")
            clinical_evidence_header:add_code_prefix_link("C91%.", "Lymphoid Leukemia")
            clinical_evidence_header:add_code_prefix_link("C84%.", "Mature T/NK-Cell Lymphoma")
            clinical_evidence_header:add_code_prefix_link("C93%.", "Monocytic Leukemia")
            clinical_evidence_header:add_code_prefix_link("C90%.", "Multiple Myeloma")
            clinical_evidence_header:add_code_link("D46.9", "Myelodysplastic Syndrome")
            clinical_evidence_header:add_code_prefix_link("C92%.", "Myeloid Leukemia")
            clinical_evidence_header:add_code_prefix_link("C83%.", "Non-Follicular Lymphoma")
            clinical_evidence_header:add_code_prefix_link("C94%.", "Other Leukemias")
            clinical_evidence_header:add_code_prefix_link("C86%.", "Other Types of T/NK-Cell Lymphoma")
            clinical_evidence_header:add_code_link("R23.3", "Petechiae")
            clinical_evidence_header:add_code_link("Z51.0", "Radiation Therapy")
            clinical_evidence_header:add_code_prefix_link("M05%.", "Rheumatoid Arthritis")
            clinical_evidence_header:add_code_prefix_link("M06%.", "Rheumatoid Arthritis")
            clinical_evidence_header:add_code_one_of_link(
                {
                    "A41.2", "A41.3", "A41.4", "A41.50", "A41.51", "A41.52", "A41.53", "A41.59", "A41.81", "A41.89", "A41.9",
                    "A42.7", "A22.7", "B37.7", "A26.7", "A54.86", "B00.7", "A32.7", "A24.1", "A20.7", "T81.44XA", "T81.44XD"
                },
                "Sepsis"
            )
            clinical_evidence_header:add_abstraction_link("SHORTNESS_OF_BREATH", "Shortness of Breath")
            clinical_evidence_header:add_code_link("R16.1", "Splenomegaly")
            clinical_evidence_header:add_code_prefix_link("M32%.", "Systemic Lupus Erythematosus")
            clinical_evidence_header:add_code_prefix_link("C85%.", "Unspecified Non-Hodgkin Lymphoma")
            clinical_evidence_header:add_code_prefix_link("B19%.", "Unspecified Viral Hepatitis")
            clinical_evidence_header:add_abstraction_link("WEAKNESS", "Weakness")

            -- DBC
            dbc_header:add_discrete_value_one_of_link(dv_absolute_basophil, "Absolute Basophil Count", calc_absolute_basophil1)
            dbc_header:add_discrete_value_one_of_link(dv_basophil_auto, "Basophil %", calc_dbc1)
            dbc_header:add_discrete_value_one_of_link(dv_absolute_eosinophil, "Absolute Eosinophil Count", calc_absolute_eosinophil1)
            dbc_header:add_discrete_value_one_of_link(dv_eosinophil_auto, "Eosinophil %", calc_dbc1)
            dbc_header:add_discrete_value_one_of_link(dv_absolute_lymphocyte, "Absolute Lymphocyte Count", calc_absolute_lymphocyte1)
            dbc_header:add_discrete_value_one_of_link(dv_lymphocyte_auto, "Lymphocyte %", calc_absolute_lymphocyte1)
            dbc_header:add_discrete_value_one_of_link(dv_absolute_monocyte, "Absolute Monocyte Count", calc_absolute_monocyte1)
            dbc_header:add_discrete_value_one_of_link(dv_monocyte_auto, "Monocyte %", calc_dbc1)
            dbc_header:add_discrete_value_one_of_link(dv_absolute_neutrophil, "Absolute Neutrophil Count", calc_absolute_neutrophil1)
            dbc_header:add_discrete_value_one_of_link(dv_neutrophil_auto, "Neutrophil %", calc_dbc1)

            -- Labs
            laboratory_studies_header:add_discrete_value_one_of_link(dv_rbc, "RBC", calc_rbc1)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_serum_folate, "Serum Folate")
            laboratory_studies_header:add_discrete_value_one_of_link(dv_vitamin_b12, "Vitamin B12", calc_vitamin_b121)

            -- Lab Subheadings
            for _, entry in ipairs(low_platelet_dv) do
                platelet_header:add_link(entry)
            end
            for _, entry in ipairs(low_wbc_dv) do
                wbc_header:add_link(entry)
            end
            for _, entry in ipairs(low_hemoglobin_multi_dv) do
                hemoglobin_header:add_link(entry.first)
                hematocrit_header:add_link(entry.second)
            end

            -- Meds
            treatment_and_monitoring_header:add_medication_link("Antimetabolite", "Antimetabolite")
            treatment_and_monitoring_header:add_abstraction_link("ANTIMETABOLITE", "Antimetabolite")
            if z5111_code then treatment_and_monitoring_header:add_link(z5111_code) end
            treatment_and_monitoring_header:add_code_link("Z51.12", "Antineoplastic Immunotherapy")
            treatment_and_monitoring_header:add_medication_link("Antirejection Medication", "Antirejection Medication")
            treatment_and_monitoring_header:add_abstraction_link("ANTIREJECTION_MEDICATION", "Antirejection Medication")
            treatment_and_monitoring_header:add_code_link("3E04305", "Chemotherapy Administration")
            treatment_and_monitoring_header:add_medication_link("Hemopoietic Agent", "Hemopoietic Agent")
            treatment_and_monitoring_header:add_abstraction_link("HEMATOPOIETIC_AGENT", "Hematopoietic Agent")
            treatment_and_monitoring_header:add_medication_link("Interferon", "Interferon")
            treatment_and_monitoring_header:add_abstraction_link("INTERFERON", "Interferon")
            treatment_and_monitoring_header:add_code_prefix_link("Z79%.6", "Long term Immunomodulators and Immunosuppressants")
            treatment_and_monitoring_header:add_code_link("Z79.52", "Long term Systemic Steroids")
            treatment_and_monitoring_header:add_medication_link("Monoclonal Antibodies", "Monoclonal Antibodies")
            treatment_and_monitoring_header:add_abstraction_link("MONOCLONAL_ANTIBODIES", "Monoclonal Antibodies")
            treatment_and_monitoring_header:add_code_one_of_link({ "30233R1", "30243R1" }, "Platelet Transfusion")
            treatment_and_monitoring_header:add_discrete_value_one_of_link(dv_platelet_transfusion, "Platelet Transfusion")
            treatment_and_monitoring_header:add_code_one_of_link({ "30233N1", "30243N1" }, "Red Blood Cell Transfusion")
            treatment_and_monitoring_header:add_discrete_value_one_of_link(dv_red_blood_cell_transfusion, "Red Blood Cell Transfusion")
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

