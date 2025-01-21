---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Pneumonia
---
--- This script checks an account to see if it matches the criteria for a pneumonia alert.
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
local headers = require("libs.common.headers")(Account)



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local dv_c_blood = { "" }
local dv_resp_culture = { "" }
local dv_mrsa_screen = { "MRSA DNA" }
local dv_sars_covid = { "SARS-CoV2 (COVID-19)" }
local dv_influenze_screen_a = { "Influenza A" }
local dv_influenze_screen_b = { "Influenza B" }
local dv_oxygen_therapy = { "DELIVERY" }
local dv_rsv = { "Respiratory syncytial virus" }
local dv_c_reactive_protein = { "C REACTIVE PROTEIN (mg/dL)" }
local calc_creactive_protein1 = function(dv_, num) return num > 0.3 end
local dv_glasgow_coma_scale = { "3.5 Neuro Glasgow Score" }
local calc_glasgow_coma_scale1 = function(dv_, num) return num < 15 end
local dv_interleukin6 = { "INTERLEUKIN 6" }
local calc_interleukin61 = function(dv_, num) return num > 7.0 end
local dv_pa_o2 = { "BLD GAS O2 (mmHg)", "PO2 (mmHg)" }
local calc_pa_o21 = function(dv_, num) return num < 80 end
local dv_pleural_fluid_culture = { "" }
local dv_procalcitonin = { "PROCALCITONIN (ng/mL)" }
local calc_procalcitonin1 = function(dv_, num) return num > 0.50 end
local dv_respiratory_rate = { "3.5 Respiratory Rate (#VS I&O) (per Minute)" }
local calc_respiratory_rate1 = function(dv_, num) return num > 20 end
local dv_sputum_culture = { "" }
local dv_temperature = { "Temperature Degrees C 3.5 (degrees C)", "Temperature  Degrees C 3.5 (degrees C)",
    "TEMPERATURE (C)" }
local calc_temperature1 = function(dv_, num) return num > 38.3 end
local dv_wbc = { "WBC (10x3/ul)" }
local calc_wbc1 = function(dv_, num) return num > 11 end
local calc_wbc2 = function(dv_, num) return num < 4.5 end



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }
local subtitle = existing_alert and existing_alert.subtitle or nil


-- Alert trigger
local unspecified_codes = links.get_code_link {
    codes = {
        "J12.89", "J12.9", "J16.8", "J18", "J18.0", "J18.1", "J18.2", "J18.8", "J18.9", "J15.69", "J15.8", "J15.9"
    },
    text = "Unspecified Pneumonia Dx",
}

if not existing_alert or not existing_alert.validated then
    --------------------------------------------------------------------------------
    --- Header Variables and Helper Functions
    --------------------------------------------------------------------------------
    local result_links = {}

    local documented_dx_header = headers.make_header_builder("Documented Dx", 1)
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 2)
    local vital_signs_header = headers.make_header_builder("Vital Signs/Intake and Output Data", 3)
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 4)
    local oxygen_ventilation_header = headers.make_header_builder("Oxygenation/Ventilation", 5)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 6)
    local ct_chest_header = headers.make_header_builder("CT Chest", 7)
    local chest_x_ray_header = headers.make_header_builder("Chest X-Ray", 8)
    local speech_and_language_pathologist_header =
        headers.make_header_builder("Speech and Language Pathologist Notes", 9)
    local pneumonia_panel_header = headers.make_header_builder("Pneumonia Panel", 10)

    local function compile_links()
        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, vital_signs_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, oxygen_ventilation_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))
        table.insert(result_links, ct_chest_header:build(true))
        table.insert(result_links, chest_x_ray_header:build(true))
        table.insert(result_links, speech_and_language_pathologist_header:build(true))
        table.insert(result_links, pneumonia_panel_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end


    --------------------------------------------------------------------------------
    --- Alert Variables
    --------------------------------------------------------------------------------
    local alert_code_dictionary = {
        ["A01.03"] = "Typhoid Pneumonia",
        ["A02.22"] = "Salmonella Pneumonia",
        ["A21.2"] = "Pulmonary Tularemia ",
        ["A22.1"] = "Pulmonary Anthrax",
        ["A42.0"] = "Pulmonary Actinomycosis",
        ["A43.0"] = "Pulmonary Nocardiosis",
        ["A54.84"] = "Gonococcal Pneumonia",
        ["B01.2"] = "Varicella Pneumonia",
        ["B05.2"] = "Measles Complicated By Pneumonia",
        ["B06.81"] = "Rubella Pneumonia",
        ["B25.0"] = "Cytomegaloviral Pneumonitis",
        ["B37.1"] = "Pulmonary Candidiasis",
        ["B38.0"] = "Acute Pulmonary Coccidioidomycosis",
        ["B39.0"] = "Acute Pulmonary Histoplasmosis Capsulati",
        ["B44.0"] = "Invasive Pulmonary Aspergillosis",
        ["B44.1"] = "Other Pulmonary Aspergillosis",
        ["B58.3"] = "Pulmonary Toxoplasmosis",
        ["B59"] = "Pneumocystosis",
        ["B77.81"] = "Ascariasis Pneumonia",
        ["J12.0"] = "Adenoviral Pneumonia",
        ["J12.1"] = "Respiratory Syncytial Virus Pneumonia",
        ["J12.2"] = "Parainfluenza Virus Pneumonia",
        ["J12.3"] = "Human Metapneumovirus Pneumonia",
        ["J12.81"] = "Pneumonia Due To SARS-Associated Coronavirus",
        ["J12.82"] = "Pneumonia Due To Coronavirus Disease 2019",
        ["J14"] = "Pneumonia Due To Hemophilus Influenzae",
        ["J15.0"] = "Pneumonia Due To Klebsiella Pneumoniae",
        ["J15.1"] = "Pneumonia Due To Pseudomonas",
        ["J15.20"] = "Pneumonia Due To Staphylococcus, Unspecified",
        ["J15.211"] = "Pneumonia Due To Methicillin Susceptible Staphylococcus Aureus",
        ["J15.212"] = "Pneumonia Due To Methicillin Resistant Staphylococcus Aureus",
        ["J15.3"] = "Pneumonia Due To Streptococcus, Group B",
        ["J15.4"] = "Pneumonia Due To Other Streptococci",
        ["J15.5"] = "Pneumonia Due To Escherichia Coli",
        ["J15.6"] = "Pneumonia Due To Other Gram-Negative Bacteria",
        ["J15.61"] = "Pneumonia due to Acinetobacter Baumannii",
        ["J15.7"] = "Pneumonia Due To Mycoplasma Pneumoniae",
        ["J16.0"] = "Chlamydial Pneumonia",
        ["J69.0"] = "Aspiration Pneumonia",
        ["J69.1"] = "Pneumonitis Due To Inhalation Of Oils And Essences",
        ["J69.8"] = "Pneumonitis Due To Inhalation Of Other Solids And Liquids",
        ["A15.0"] = "Tuberculous Pneumonia",
        ["J13"] = "Pneumonia due to Streptococcus Pneumoniae",
    }
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    local trigger_alert =
        existing_alert == nil or
        (existing_alert.outcome ~= "AUTORESOLVED" and existing_alert.reason ~= "Previously Autoresolved")


    -- Conflicting Codes Gram Negative Bacteria
    local j156_code =
        links.get_code_link { code = "J15.6", text = "Pneumonia due to Other Gram-negative bacteria" }
    local a0103_code = links.get_code_link { code = "A01.03", text = "Typhoid Pneumonia" }
    local a0222_code = links.get_code_link { code = "A02.22", text = "Salmonella Pneumonia" }
    local a212_code = links.get_code_link { code = "A21.2", text = "Tularemia Pneumonia" }
    local a5484_code = links.get_code_link { code = "A54.84", text = "Gonococcal Pneumonia" }
    local a698_code = links.get_code_link { code = "A69.8", text = "Spirochetal Pneumonia" }
    local b440_code = links.get_code_link { code = "B44.0", text = "Aspergillosis Pneumonia" }
    local b4411_code = links.get_code_link { code = "B44.11", text = "Aspergillosis Pneumonia Other" }
    local b583_code = links.get_code_link { code = "B58.3", text = "Toxoplasmosis Pneumonia" }
    local b59_code = links.get_code_link {
        code = "B59",
        text = "Pneumonia due to Pneumocystis Carinii, Pneumonia due to Pneumocystis Jiroveci"
    }
    local j150_code = links.get_code_link { code = "J15.0", text = "Pneumonia due to Klebsiella Pneumoniae" }
    local j151_code = links.get_code_link { code = "J15.1", text = "Pneumonia due to Pseudomonas" }
    local j155_code = links.get_code_link { code = "J15.5", text = "Pneumonia due to Escherichia coli" }
    local j1561_code = links.get_code_link { code = "J15.61", text = "Pneumonia due to Acinetobacter Baumannii" }
    local j157_code = links.get_code_link { code = "J15.7", text = "Pneumonia due to Mycoplasma pneumoniae" }
    local j160_code = links.get_code_link { code = "J16.0", text = "Chlamydial pneumonia" }

    -- Conflicting Codes Gram Postive Bacteria
    local j159_code = links.get_code_link { code = "J15.9", text = "Pneumonia due to due to gram-positive bacteria" }
    local j152_code = links.get_code_link { code = "J15.2", text = "Pneumonia due to staphylococcus" }
    local j1521_code = links.get_code_link { code = "J15.21", text = "Pneumonia due to staphylococcus aureus" }
    local a221_code = links.get_code_link { code = "A22.1", text = "Anthrax Pneumonia" }
    local a420_code = links.get_code_link { code = "A42.0", text = "Actinomycosis Pneumonia" }
    local a430_code = links.get_code_link { code = "A43.0", text = "Nocardiosis Pneumonia" }
    local j13_code = links.get_code_link { code = "J13", text = "Pneumonia due to Streptococcus pneumoniae" }
    local j15211_code = links.get_code_link {
        code = "J15.211",
        text = "Pneumonia due to Methicillin susceptible Staphylococcus aureus"
    }
    local j15212_code = links.get_code_link {
        code = "J15.212",
        text = "Pneumonia due to Methicillin resistant Staphylococcus aureus"
    }
    local j153_code = links.get_code_link { code = "J15.3", text = "Pneumonia due to streptococcus, group B" }
    local j154_code = links.get_code_link { code = "J15.4", text = "Pneumonia due to Other Streptococci" }

    -- Conflicting Codes Other Full Spec Codes
    local b012_code = links.get_code_link { code = "B01.2", text = "Varicella Pneumonia" }
    local b052_code = links.get_code_link { code = "B05.2", text = "Measles Complicated By Pneumonia" }
    local b0681_code = links.get_code_link { code = "B06.81", text = "Rubella Pneumonia" }
    local b250_code = links.get_code_link { code = "B25.0", text = "Cytomegaloviral Pneumonitis" }
    local b371_code = links.get_code_link { code = "B37.1", text = "Pulmonary Candidiasis" }
    local b380_code = links.get_code_link { code = "B38.0", text = "Acute Pulmonary Coccidioidomycosis" }
    local b390_code = links.get_code_link { code = "B39.0", text = "Acute Pulmonary Histoplasmosis Capsulati" }
    local b441_code = links.get_code_link { code = "B44.1", text = "Other Pulmonary Aspergillosis" }
    local b7781_code = links.get_code_link { code = "B77.81", text = "Ascariasis Pneumonia" }
    local j120_code = links.get_code_link { code = "J12.0", text = "Adenoviral Pneumonia" }
    local j121_code = links.get_code_link { code = "J12.1", text = "Respiratory Syncytial Virus Pneumonia" }
    local j122_code = links.get_code_link { code = "J12.2", text = "Parainfluenza Virus Pneumonia" }
    local j123_code = links.get_code_link { code = "J12.3", text = "Human Metapneumovirus Pneumonia" }
    local j1281_code = links.get_code_link { code = "J12.81", text = "Pneumonia Due To SARS-Associated Coronavirus" }
    local j1282_code = links.get_code_link { code = "J12.82", text = "Pneumonia Due To Coronavirus Disease 2019" }
    local j14_code = links.get_code_link { code = "J14", text = "Pneumonia Due To Hemophilus Influenzae" }
    local j1520_code = links.get_code_link { code = "J15.20", text = "Pneumonia Due To Staphylococcus, Unspecified" }
    local j1569_code = links.get_code_link { code = "J15.69", text = "Pneumonia due to Other Gram-Negative Bacteria" }
    local j158_code = links.get_code_link { code = "J15.8", text = "Pneumonia Due To Other Specified Bacteria" }
    local j690_code = links.get_code_link { code = "J69.0", text = "Aspiration Pneumonia" }
    local j691_code =
        links.get_code_link { code = "J69.1", text = "Pneumonitis Due To Inhalation Of Oils And Essences" }
    local j698_code =
        links.get_code_link { code = "J69.8", text = "Pneumonitis Due To Inhalation Of Other Solids And Liquids" }

    -- Alert Trigger
    local t17_gastic_codes = links.get_code_link {
        codes = { "T17.310", "T17.308" },
        text = "Gastric Contents in Larynx",
    }
    local t17_food_codes = links.get_code_link {
        codes = { "T17.320", "T17.328" },
        text = "Food in Larynx",
    }

    -- Clinical Evidence
    local abnormal_sputum_abs = links.get_abstraction_link {
        code = "ABNORMAL_SPUTUM",
        text = "Abnormal Sputum",
    }
    local r4182_code = links.get_code_link { code = "R41.82", text = "Altered Level of Consciousness" }
    local altered_abs = links.get_abstraction_link {
        code = "ALTERED_LEVEL_OF_CONSCIOUSNESS",
        text = "Altered Level of Consciousness",
    }
    local aspiration_abs = links.get_abstraction_link { code = "ASPIRATION", text = "Aspiration" }
    local bacterial_pneumonia_organism_abs = links.get_abstraction_link {
        code = "BACTERIAL_PNEUMONIA_ORGANISM",
        text = "Possible Bacterial Pneumonia Organism",
    }
    local r059_code = links.get_code_link { code = "R05.9", text = "Cough" }
    local crackles_abs = links.get_abstraction_link { code = "CRACKLES", text = "Crackles" }
    local r131_codes = links.get_code_link { code = "^R13.1", text = "Dysphagia" }
    local swallow_study_abs =
        links.get_abstraction_link { code = "FAILED_SWALLOW_STUDY", text = "Failed Swallow study" }
    local glascow_coma_scale_dv = links.get_discrete_value_link {
        discreteValues = dv_glasgow_coma_scale,
        text = "Glascow Coma Scale",
        predicate = calc_glasgow_coma_scale1,
    }
    local glascow_coma_scale_abs = links.get_abstraction_value_link {
        code = "GLASCOW_COMA_SCALE",
        text = "Glascow Coma Scale",
    }
    local gag_reflex_abs = links.get_abstraction_link { code = "IMPAIRED_GAG_REFLEX", text = "Impaired Gag Reflex" }
    local irregular_rad_rep_pneumonia_abs = links.get_abstraction_link {
        code = "IRREGULAR_RADIOLOGY_REPORT_PNEUMONIA",
        text = "Irregular Radiology Report Lungs",
    }
    local pleural_rub_abs = links.get_abstraction_link { code = "PLEURAL_RUB", text = "Pleural Rub" }
    local fungal_pneumonia_organism_abs = links.get_abstraction_link {
        code = "FUNGAL_PNEUMONIA_ORGANISM",
        text = "Possible Fungal Pneumonia Organism",
    }
    local viral_pneumonia_organism_abs = links.get_abstraction_link {
        code = "VIRAL_PNEUMONIA_ORGANISM",
        text = "Possible Viral Pneumonia Organism",
    }
    local rhonchi_abs = links.get_abstraction_link { code = "RHONCHI", text = "Rhonchi" }
    local sob_abs = links.get_abstraction_link { code = "SHORTNESS_OF_BREATH", text = "Shortness of Breath" }
    local accessory_muscles_abs = links.get_abstraction_link {
        code = "USE_OF_ACCESSORY_MUSCLES",
        text = "Use of Accessory Muscles",
    }
    local wheezing_abs = links.get_abstraction_link { code = "WHEEZING", text = "Wheezing" }

    -- Labs
    local c_blood_dv = links.get_discrete_value_link {
        discreteValues = dv_c_blood,
        text = "Blood Culture",
        predicate = function(dv, num_)
            return dv.result:lower():find("positive") ~= nil or dv.result:lower():find("detected") ~= nil
        end

    }
    local c_reactive_protein_elev_dv = links.get_discrete_value_link {
        discreteValues = dv_c_reactive_protein,
        text = "C Reactive Protein",
        predicate = calc_creactive_protein1,
    }
    local sars_covid_dv = links.get_discrete_value_link {
        discreteValues = dv_sars_covid,
        text = "Covid 19 Screen",
        predicate = function(dv, num_)
            return dv.result:lower():find("positive") ~= nil or dv.result:lower():find("detected") ~= nil
        end
    }
    local r0902_code = links.get_code_link { code = "R09.02", text = "Hypoxemia" }
    local interleukin6_elev_dv = links.get_discrete_value_link {
        discreteValues = dv_interleukin6,
        text = "Interleukin 6",
        predicate = calc_interleukin61,
    }
    local mrsa_screen_dv = links.get_discrete_value_link {
        discreteValues = dv_mrsa_screen,
        text = "MRSA Screen",
        predicate = function(dv, num_)
            return dv.result:lower():find("positive") ~= nil or dv.result:lower():find("detected") ~= nil
        end
    }
    local pa_o2_dv = links.get_discrete_value_link {
        discreteValues = dv_pa_o2,
        text = "pa02",
        predicate = calc_pa_o21,
    }
    local pleural_fluid_culture_dv = links.get_discrete_value_link {
        discreteValues = dv_pleural_fluid_culture,
        text = "Positive Pleural Fluid Culture",
        predicate = function(dv, num_)
            return dv.result:lower():find("positive") ~= nil or dv.result:lower():find("detected") ~= nil
        end
    }
    local r845_code = links.get_code_link { code = "R84.5", text = "Positive Respiratory Culture" }
    local positive_sputum_culture_dv = links.get_discrete_value_link {
        discreteValues = dv_sputum_culture,
        text = "Positive Sputum Culture",
        predicate = function(dv, num_)
            return dv.result:lower():find("positive") ~= nil or dv.result:lower():find("detected") ~= nil
        end
    }
    local procalcitonin_dv = links.get_disc_value_link {
        discreteValues = dv_procalcitonin,
        text = "Procalcitonin",
        predicate = calc_procalcitonin1,
    }
    local resp_culture_dv = links.get_discrete_value_link {
        discreteValues = dv_resp_culture,
        text = "Respiratory Culture",
        predicate = function(dv, num_)
            return dv.result:lower():find("positive") ~= nil or dv.result:lower():find("detected") ~= nil
        end
    }
    local influenze_screen_a_dv = links.get_discrete_value_link {
        discreteValues = dv_influenze_screen_a,
        text = "Respiratory Pathogen Panel (Influenza A)",
        predicate = function(dv, num_)
            return dv.result:lower():find("positive") ~= nil or dv.result:lower():find("detected") ~= nil
        end
    }
    local influenze_screen_b_dv = links.get_discrete_value_link {
        discreteValues = dv_influenze_screen_b,
        text = "Respiratory Pathogen Panel (Influenza B)",
        predicate = function(dv, num_)
            return dv.result:lower():find("positive") ~= nil or dv.result:lower():find("detected") ~= nil
        end
    }
    local rsv_dv = links.get_discrete_value_link {
        discreteValues = dv_rsv,
        text = "Respiratory Pathogen Panel (RSV)",
        predicate = function(dv, num_)
            return dv.result:lower():find("positive") ~= nil or dv.result:lower():find("detected") ~= nil
        end
    }
    -- 16
    local high_wbc_dv = links.get_discrete_value_link {
        discreteValues = dv_wbc,
        text = "White Blood Cell Count",
        predicate = calc_wbc1,
    }
    local low_wbc_dv = links.get_discrete_value_link {
        discreteValues = dv_wbc,
        text = "White Blood Cell Count",
        predicate = calc_wbc2,
    }

    -- Meds
    local antibiotic_med = links.get_medication_link {
        cat = "Antibiotic",
        text = "Antibiotic",
        predicate = function(med)
            return med.route:lower():find("Eye") == nil or
                med.route:lower():find("topical") == nil or
                med.route:lower():find("ocular") == nil or
                med.route:lower():find("ophthalmic") == nil
        end
    }
    local antibiotic2_med = links.get_medication_link {
        cat = "Antibiotic2",
        text = "Antibiotic2",
        predicate = function(med)
            return med.route:lower():find("Intravenous") ~= nil or
                med.route:lower():find("IV push") ~= nil or
                med.route:lower():find("Eye") == nil or
                med.route:lower():find("topical") == nil or
                med.route:lower():find("ocular") == nil or
                med.route:lower():find("ophthalmic") == nil
        end
    }
    local antibiotic_abs = links.get_abstraction_link { code = "ANTIBIOTIC", text = "Antibiotic" }
    local antibiotic2_abs = links.get_abstraction_link { code = "ANTIBIOTIC_2", text = "Antibiotic2" }
    local antifungal_med = links.get_medication_link { cat = "Antifungal", text = "Antifungal" }
    local antifungal_abs = links.get_abstraction_link { code = "ANTIFUNGAL", text = "Antifungal" }
    local antiviral_med = links.get_medication_link { cat = "Antiviral", text = "Antiviral" }
    local antiviral_abs = links.get_abstraction_link { code = "ANTIVIRAL", text = "Antiviral" }

    -- Oxygen
    local oxygen_therapy = links.get_discrete_value_link {
        discreteValues = dv_oxygen_therapy,
        text = "Oxygen Therapy",
        predicate = function(dv, num_)
            return dv.result:lower():find("room air") ~= nil or dv.result:lower():find("RA") ~= nil
        end
    }
    local oxygen_therapy_abs = links.get_abstraction_link { code = "OXYGEN_THERAPY", text = "Oxygen Therapy" }

    -- Vitals
    local respiratory_rate_dv = links.get_discrete_value_link {
        discreteValues = dv_respiratory_rate,
        text = "Respiratory Rate",
        predicate = calc_respiratory_rate1,
    }
    local high_temp_dv = links.get_discrete_value_link {
        discreteValues = dv_temperature,
        text = "Temperature",
        predicate = calc_temperature1,
    }

    -- Checking Clinical Indicators
    local ci = 0
    if bacterial_pneumonia_organism_abs then
        clinical_evidence_header:add_link(bacterial_pneumonia_organism_abs)
        ci = ci + 1
    end
    if viral_pneumonia_organism_abs then
        clinical_evidence_header:add_link(viral_pneumonia_organism_abs)
        ci = ci + 1
    end
    if fungal_pneumonia_organism_abs then
        clinical_evidence_header:add_link(fungal_pneumonia_organism_abs)
        ci = ci + 1
    end
    if high_temp_dv then
        ci = ci + 1
        vital_signs_header:add_link(high_temp_dv)
    end
    if high_wbc_dv or low_wbc_dv then
        ci = ci + 1
        if high_wbc_dv then laboratory_studies_header:add_link(high_wbc_dv) end
        if low_wbc_dv then laboratory_studies_header:add_link(low_wbc_dv) end
    end
    if interleukin6_elev_dv then
        laboratory_studies_header:add_link(interleukin6_elev_dv)
        ci = ci + 1
    end
    if c_reactive_protein_elev_dv then
        laboratory_studies_header:add_link(c_reactive_protein_elev_dv)
        ci = ci + 1
    end
    if procalcitonin_dv then
        laboratory_studies_header:add_link(procalcitonin_dv)
        ci = ci + 1
    end
    if glascow_coma_scale_dv or glascow_coma_scale_abs then
        ci = ci + 1
        if glascow_coma_scale_dv then laboratory_studies_header:add_link(glascow_coma_scale_dv) end
        if glascow_coma_scale_abs then laboratory_studies_header:add_link(glascow_coma_scale_abs) end
    end
    if r4182_code or altered_abs then
        if r4182_code then
            clinical_evidence_header:add_link(r4182_code)
            if altered_abs then
                altered_abs.hidden = true
                clinical_evidence_header:add_link(altered_abs)
            end
        elseif not r4182_code and altered_abs then
            clinical_evidence_header:add_link(altered_abs)
        end
        ci = ci + 1
    end
    if pa_o2_dv or r0902_code then
        ci = ci + 1
        laboratory_studies_header:add_link(pa_o2_dv)
        laboratory_studies_header:add_link(r0902_code)
    end
    if r059_code then
        clinical_evidence_header:add_link(r059_code)
        ci = ci + 1
    end
    if sob_abs then
        clinical_evidence_header:add_link(sob_abs)
        ci = ci + 1
    end
    if respiratory_rate_dv then
        ci = ci + 1
        vital_signs_header:add_link(respiratory_rate_dv)
    end
    if crackles_abs then
        clinical_evidence_header:add_link(crackles_abs)
        ci = ci + 1
    end
    if rhonchi_abs then
        clinical_evidence_header:add_link(rhonchi_abs)
        ci = ci + 1
    end
    if abnormal_sputum_abs then
        clinical_evidence_header:add_link(abnormal_sputum_abs)
        ci = ci + 1
    end
    if pleural_rub_abs then
        clinical_evidence_header:add_link(pleural_rub_abs)
        ci = ci + 1
    end
    if positive_sputum_culture_dv then
        ci = ci + 1
        laboratory_studies_header:add_link(positive_sputum_culture_dv)
    end
    if pleural_fluid_culture_dv then
        ci = ci + 1
        laboratory_studies_header:add_link(pleural_fluid_culture_dv)
    end
    if oxygen_therapy or oxygen_therapy_abs then
        if oxygen_therapy then oxygen_ventilation_header:add_link(oxygen_therapy) end
        if oxygen_therapy_abs then oxygen_ventilation_header:add_link(oxygen_therapy_abs) end
        ci = ci + 1
    end
    if r131_codes then
        clinical_evidence_header:add_link(r131_codes)
        ci = ci + 1
    end
    if swallow_study_abs then
        clinical_evidence_header:add_link(swallow_study_abs)
        ci = ci + 1
    end
    if gag_reflex_abs then
        clinical_evidence_header:add_link(gag_reflex_abs)
        ci = ci + 1
    end
    if accessory_muscles_abs then
        clinical_evidence_header:add_link(accessory_muscles_abs)
        ci = ci + 1
    end
    if wheezing_abs then
        clinical_evidence_header:add_link(wheezing_abs)
        ci = ci + 1
    end
    if irregular_rad_rep_pneumonia_abs then
        clinical_evidence_header:add_link(irregular_rad_rep_pneumonia_abs)
        ci = ci + 1
    end

    -- Treatment Indicators
    local ti = 0
    if antiviral_abs or antiviral_med then
        if antiviral_abs then treatment_and_monitoring_header:add_link(antiviral_abs) end
        if antiviral_med then treatment_and_monitoring_header:add_link(antiviral_med) end
        ti = ti + 1
    end
    if antibiotic_abs or antibiotic_med or antibiotic2_med or antibiotic2_abs then
        if antibiotic_abs then treatment_and_monitoring_header:add_link(antibiotic_abs) end
        if antibiotic_med then treatment_and_monitoring_header:add_link(antibiotic_med) end
        if antibiotic2_med then treatment_and_monitoring_header:add_link(antibiotic2_med) end
        if antibiotic2_abs then treatment_and_monitoring_header:add_link(antibiotic2_abs) end
        ti = ti + 1
    end
    if antifungal_abs or antifungal_med then
        if antifungal_abs then treatment_and_monitoring_header:add_link(antifungal_abs) end
        if antifungal_med then treatment_and_monitoring_header:add_link(antifungal_med) end
        ti = ti + 1
    end

    local gram_negative =
        a0103_code and 1 or 0 +
        a0222_code and 1 or 0 +
        a212_code and 1 or 0 +
        a5484_code and 1 or 0 +
        a698_code and 1 or 0 +
        b440_code and 1 or 0 +
        b4411_code and 1 or 0 +
        b583_code and 1 or 0 +
        b59_code and 1 or 0 +
        j150_code and 1 or 0 +
        j151_code and 1 or 0 +
        j155_code and 1 or 0 +
        j1561_code and 1 or 0 +
        j157_code and 1 or 0 +
        j160_code and 1 or 0

    local gram_positive =
        j159_code and 1 or 0 +
        j152_code and 1 or 0 +
        j1521_code and 1 or 0 +
        a221_code and 1 or 0 +
        a420_code and 1 or 0 +
        a430_code and 1 or 0 +
        j13_code and 1 or 0 +
        j15211_code and 1 or 0 +
        j15212_code and 1 or 0 +
        j153_code and 1 or 0 +
        j154_code and 1 or 0

    local full_spec =
        b012_code and 1 or 0 +
        b052_code and 1 or 0 +
        b0681_code and 1 or 0 +
        b250_code and 1 or 0 +
        b371_code and 1 or 0 +
        b380_code and 1 or 0 +
        b390_code and 1 or 0 +
        b441_code and 1 or 0 +
        b7781_code and 1 or 0 +
        j120_code and 1 or 0 +
        j121_code and 1 or 0 +
        j122_code and 1 or 0 +
        j123_code and 1 or 0 +
        j1281_code and 1 or 0 +
        j1282_code and 1 or 0 +
        j14_code and 1 or 0 +
        j1520_code and 1 or 0 +
        j1569_code and 1 or 0 +
        j158_code and 1 or 0 +
        j690_code and 1 or 0 +
        j691_code and 1 or 0 +
        j698_code and 1 or 0

    -- Admit Source Translation
    local admit_trans = nil
    if Account.admit_source == "4" then
        admit_trans = "Transferred from Another Hospital"
    elseif Account.admit_source == "5" then
        admit_trans = "Transfer from Skilled Nursing"
    elseif Account.admit_source == "6" then
        admit_trans = "Transfer from Another Health Care Center"
    end


    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    -- Main Algorithm 
    local unspecified_dx = false
    if
        trigger_alert and
        (account_alert_codes or gram_negative > 0 or gram_positive > 0) and
        (
            (Account.admit_source == "TH" or Account.admit_source == "TE" or Account.admit_source == "TA") and
            not admit_trans
        )
    then
        if #account_alert_codes == 1 then
            for _, code in account_alert_codes do
                local desc = alert_code_dictionary[code]
                local temp_code = links.get_code_link {
                    code = code,
                    text = desc .. ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])"
                }
                if temp_code then
                    documented_dx_header:add_link(temp_code)
                    break
                end
            end
        end
        documented_dx_header:add_link(unspecified_codes)
        documented_dx_header:add_text_link("Admit Source: " .. admit_trans)
        Result.subtitle = "Possible Hospital Acquired Pneumonia"
        Result.passed = true

    elseif #account_alert_codes == 1 then
        if existing_alert then
            for _, code in account_alert_codes do
                local desc = alert_code_dictionary[code]
                local temp_code = links.get_code_link {
                    code = code,
                    text = "Autoresolved Specified Code  - " .. desc
                }
                if temp_code then
                    documented_dx_header:add_link(temp_code)
                    break
                end
            end
            Result.outcome = "AUTORESOLVED"
            Result.reason = "Autoresolved due to one Specified Code on the Account"
            Result.validated = true
            Result.passed = true
        else
            Result.passed = false
        end

    elseif
        (
            (j156_code and (full_spec > 0 or gram_positive > 0 or gram_negative > 2)) or
            (j156_code and full_spec > 0 and (gram_positive > 0 or gram_negative > 0))
        ) or
        (
            (j159_code and (full_spec > 0 or gram_positive > 2 or gram_negative > 0)) or
            (j159_code and full_spec > 0 and (gram_positive > 0 or gram_negative > 0))
        ) or
        (
            (j15211_code and not j1521_code and (full_spec > 0 or gram_positive > 2 or gram_negative > 0)) or
            (not j15211_code and j1521_code and (full_spec > 0 or gram_positive > 2 or gram_negative > 0)) or
            (j15211_code and j1521_code and (full_spec > 0 or gram_positive > 3 or gram_negative > 0))
        ) or
        (
            (j158_code and (full_spec > 0 or gram_positive > 2 or gram_negative > 0)) or
            (j158_code and full_spec > 0 and (gram_positive > 0 or gram_negative > 0))
        ) or
        (full_spec > 1)
    then
        local code_list_string = ": "

        if b012_code then
            code_list_string = code_list_string .. b012_code.code .. ", "
            documented_dx_header:add_link(b012_code)
        end
        if b052_code then
            code_list_string = code_list_string .. b052_code.code .. ", "
            documented_dx_header:add_link(b052_code)
        end
        if b0681_code then
            code_list_string = code_list_string .. b0681_code.code .. ", "
            documented_dx_header:add_link(b0681_code)
        end
        if b250_code then
            code_list_string = code_list_string .. b250_code.code .. ", "
            documented_dx_header:add_link(b250_code)
        end
        if b371_code then
            code_list_string = code_list_string .. b371_code.code .. ", "
            documented_dx_header:add_link(b371_code)
        end
        if b380_code then
            code_list_string = code_list_string .. b380_code.code .. ", "
            documented_dx_header:add_link(b380_code)
        end
        if b390_code then
            code_list_string = code_list_string .. b390_code.code .. ", "
            documented_dx_header:add_link(b390_code)
        end
        if b441_code then
            code_list_string = code_list_string .. b441_code.code .. ", "
            documented_dx_header:add_link(b441_code)
        end
        if b7781_code then
            code_list_string = code_list_string .. b7781_code.code .. ", "
            documented_dx_header:add_link(b7781_code)
        end
        if j120_code then
            code_list_string = code_list_string .. j120_code.code .. ", "
            documented_dx_header:add_link(j120_code)
        end
        if j121_code then
            code_list_string = code_list_string .. j121_code.code .. ", "
            documented_dx_header:add_link(j121_code)
        end
        if j122_code then
            code_list_string = code_list_string .. j122_code.code .. ", "
            documented_dx_header:add_link(j122_code)
        end
        if j123_code then
            code_list_string = code_list_string .. j123_code.code .. ", "
            documented_dx_header:add_link(j123_code)
        end
        if j1281_code then
            code_list_string = code_list_string .. j1281_code.code .. ", "
            documented_dx_header:add_link(j1281_code)
        end
        if j1282_code then
            code_list_string = code_list_string .. j1282_code.code .. ", "
            documented_dx_header:add_link(j1282_code)
        end
        if j14_code then
            code_list_string = code_list_string .. j14_code.code .. ", "
            documented_dx_header:add_link(j14_code)
        end
        if j1520_code then
            code_list_string = code_list_string .. j1520_code.code .. ", "
            documented_dx_header:add_link(j1520_code)
        end
        if j1569_code then
            code_list_string = code_list_string .. j1569_code.code .. ", "
            documented_dx_header:add_link(j1569_code)
        end
        if j158_code then
            code_list_string = code_list_string .. j158_code.code .. ", "
            documented_dx_header:add_link(j158_code)
        end
        if j690_code then
            code_list_string = code_list_string .. j690_code.code .. ", "
            documented_dx_header:add_link(j690_code)
        end
        if j691_code then
            code_list_string = code_list_string .. j691_code.code .. ", "
            documented_dx_header:add_link(j691_code)
        end
        if j698_code then
            code_list_string = code_list_string .. j698_code.code .. ", "
            documented_dx_header:add_link(j698_code)
        end
        if j159_code then
            code_list_string = code_list_string .. j159_code.code .. ", "
            documented_dx_header:add_link(j159_code)
        end
        if j152_code then
            code_list_string = code_list_string .. j152_code.code .. ", "
            documented_dx_header:add_link(j152_code)
        end
        if j1521_code then
            code_list_string = code_list_string .. j1521_code.code .. ", "
            documented_dx_header:add_link(j1521_code)
        end
        if a221_code then
            code_list_string = code_list_string .. a221_code.code .. ", "
            documented_dx_header:add_link(a221_code)
        end
        if a420_code then
            code_list_string = code_list_string .. a420_code.code .. ", "
            documented_dx_header:add_link(a420_code)
        end
        if a430_code then
            code_list_string = code_list_string .. a430_code.code .. ", "
            documented_dx_header:add_link(a430_code)
        end
        if j13_code then
            code_list_string = code_list_string .. j13_code.code .. ", "
            documented_dx_header:add_link(j13_code)
        end
        if j15211_code then
            code_list_string = code_list_string .. j15211_code.code .. ", "
            documented_dx_header:add_link(j15211_code)
        end
        if j15212_code then
            code_list_string = code_list_string .. j15212_code.code .. ", "
            documented_dx_header:add_link(j15212_code)
        end
        if j153_code then
            code_list_string = code_list_string .. j153_code.code .. ", "
            documented_dx_header:add_link(j153_code)
        end
        if j154_code then
            code_list_string = code_list_string .. j154_code.code .. ", "
            documented_dx_header:add_link(j154_code)
        end
        if j156_code then
            code_list_string = code_list_string .. j156_code.code .. ", "
            documented_dx_header:add_link(j156_code)
        end
        if a0103_code then
            code_list_string = code_list_string .. a0103_code.code .. ", "
            documented_dx_header:add_link(a0103_code)
        end
        if a0222_code then
            code_list_string = code_list_string .. a0222_code.code .. ", "
            documented_dx_header:add_link(a0222_code)
        end
        if a212_code then
            code_list_string = code_list_string .. a212_code.code .. ", "
            documented_dx_header:add_link(a212_code)
        end
        if a5484_code then
            code_list_string = code_list_string .. a5484_code.code .. ", "
            documented_dx_header:add_link(a5484_code)
        end
        if a698_code then
            code_list_string = code_list_string .. a698_code.code .. ", "
            documented_dx_header:add_link(a698_code)
        end
        if b440_code then
            code_list_string = code_list_string .. b440_code.code .. ", "
            documented_dx_header:add_link(b440_code)
        end
        if b4411_code then
            code_list_string = code_list_string .. b4411_code.code .. ", "
            documented_dx_header:add_link(b4411_code)
        end
        if b583_code then
            code_list_string = code_list_string .. b583_code.code .. ", "
            documented_dx_header:add_link(b583_code)
        end
        if b59_code then
            code_list_string = code_list_string .. b59_code.code .. ", "
            documented_dx_header:add_link(b59_code)
        end
        if j150_code then
            code_list_string = code_list_string .. j150_code.code .. ", "
            documented_dx_header:add_link(j150_code)
        end
        if j151_code then
            code_list_string = code_list_string .. j151_code.code .. ", "
            documented_dx_header:add_link(j151_code)
        end
        if j155_code then
            code_list_string = code_list_string .. j155_code.code .. ", "
            documented_dx_header:add_link(j155_code)
        end
        if j1561_code then
            code_list_string = code_list_string .. j1561_code.code .. ", "
            documented_dx_header:add_link(j1561_code)
        end
        if j157_code then
            code_list_string = code_list_string .. j157_code.code .. ", "
            documented_dx_header:add_link(j157_code)
        end
        if j160_code then
            code_list_string = code_list_string .. j160_code.code .. ", "
            documented_dx_header:add_link(j160_code)
        end
        Result.subtitle = "Pneumonia Conflicting Dx" .. code_list_string
        if existing_alert and existing_alert.validated then
            Result.validated = false
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
        end

    elseif trigger_alert and unspecified_codes and (aspiration_abs or t17_gastic_codes or t17_food_codes) then
        documented_dx_header:add_link(unspecified_codes)
        documented_dx_header:add_link(aspiration_abs)
        documented_dx_header:add_link(t17_gastic_codes)
        documented_dx_header:add_link(t17_food_codes)
        Result.subtitle = "Possible Aspiration Pneumonia"
        Result.passed = true

    elseif
        unspecified_codes and
        (
            r845_code or
            c_blood_dv or
            resp_culture_dv or
            mrsa_screen_dv or
            sars_covid_dv or
            influenze_screen_a_dv or
            influenze_screen_b_dv or
            rsv_dv or
            viral_pneumonia_organism_abs or
            bacterial_pneumonia_organism_abs or
            fungal_pneumonia_organism_abs or
            #pneumonia_panel_header.links > 0
        )
    then
        documented_dx_header:add_link(unspecified_codes)
        documented_dx_header:add_link(r845_code)
        documented_dx_header:add_link(c_blood_dv)
        documented_dx_header:add_link(resp_culture_dv)
        documented_dx_header:add_link(mrsa_screen_dv)
        documented_dx_header:add_link(sars_covid_dv)
        documented_dx_header:add_link(influenze_screen_a_dv)
        documented_dx_header:add_link(influenze_screen_b_dv)
        documented_dx_header:add_link(rsv_dv)
        Result.subtitle = "Pneumonia Dx Unspecified"
        Result.passed = true
        unspecified_dx = true

    elseif
        trigger_alert and
        not unspecified_codes and
        ci >= 2 and
        irregular_rad_rep_pneumonia_abs and
        (aspiration_abs or t17_gastic_codes or t17_food_codes)
    then
        documented_dx_header:add_link(irregular_rad_rep_pneumonia_abs)
        documented_dx_header:add_link(aspiration_abs)
        documented_dx_header:add_link(t17_gastic_codes)
        documented_dx_header:add_link(t17_food_codes)
        Result.subtitle = "Possible Aspiration Pneumonia"
        Result.passed = true

    elseif unspecified_codes and antibiotic2_med then
        documented_dx_header:add_link(unspecified_codes)
        Result.subtitle = "Possible Complex Pneumonia"
        Result.passed = true

    elseif subtitle == "Possible Pneumonia Dx" and unspecified_codes then
        unspecified_codes.link_text = "Autoresolved Code - " .. unspecified_codes.link_text
        documented_dx_header:add_link(unspecified_codes)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        trigger_alert and
        ci >= 2 and
        ti >= 1 and
        (irregular_rad_rep_pneumonia_abs or unspecified_codes)
    then
        documented_dx_header:add_link(irregular_rad_rep_pneumonia_abs)
        Result.subtitle = "Possible Pneumonia Dx"
        Result.passed = true
    end


    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Clinical Evidence
            clinical_evidence_header:add_abstraction_link("RESPIRATORY_BREATH_SOUNDS", "Respiratory Breath Sounds")
            -- Document Links
            chest_x_ray_header:add_document_link("Chest  3 View", "Chest  3 View")
            chest_x_ray_header:add_document_link("Chest  PA and Lateral", "Chest  PA and Lateral")
            chest_x_ray_header:add_document_link("Chest  Portable", "Chest  Portable")
            chest_x_ray_header:add_document_link("Chest PA and Lateral", "Chest PA and Lateral")
            chest_x_ray_header:add_document_link("Chest  1 View", "Chest  1 View")
            ct_chest_header:add_document_link("CT Thorax W", "CT Thorax W")
            ct_chest_header:add_document_link("CTA Thorax Aorta", "CTA Thorax Aorta")
            ct_chest_header:add_document_link("CT Thorax WO-Abd WO-Pel WO", "CT Thorax WO-Abd WO-Pel WO")
            ct_chest_header:add_document_link("CT Thorax WO", "CT Thorax WO")
            speech_and_language_pathologist_header:add_document_link(
                "OP SLP Evaluation - Clinical Swallow (Dysphagia), Speech and Cognitive",
                "OP SLP Evaluation - Clinical Swallow (Dysphagia), Speech and Cognitive"
            )
            speech_and_language_pathologist_header:add_document_link(
                "OP SLP Evaluation - Clinical Swallow (Dysphagia), Motor Speech and Voice",
                "OP SLP Evaluation - Clinical Swallow (Dysphagia), Motor Speech and Voice"
            )
            speech_and_language_pathologist_header:add_document_link(
                "OP SLP Evaluation - Language -Motor Speech-Dysphagia",
                "OP SLP Evaluation - Language -Motor Speech-Dysphagia"
            )
            speech_and_language_pathologist_header:add_document_link(
                "OP SLP Evaluation - Motor Speech-Dysphagia",
                "OP SLP Evaluation - Motor Speech-Dysphagia"
            )

            -- Laboratory Studies
            if r845_code and not unspecified_dx then laboratory_studies_header:add_link(r845_code) end
            -- Oxygen Ventilation
            oxygen_ventilation_header:add_code_one_of_link({ "5A0935A", "5A0945A", "5A0955A" }, "Flow Nasal Oxygen")
            oxygen_ventilation_header:add_code_link("5A1945Z", "Mechanical Ventilation 24 to 96 hours")
            oxygen_ventilation_header:add_code_link("5A1955Z", "Mechanical Ventilation Greater than 96 hours")
            oxygen_ventilation_header:add_code_link("Z99.1", "Mechanical Ventilation/Invasive Ventilation")
            oxygen_ventilation_header:add_code_link("5A1935Z", "Mechanical Ventilation Less than 24 hours")
            oxygen_ventilation_header:add_abstraction_link("NON_INVASIVE_VENTILATION", "Non-Invasive Ventilation")
            -- 7-8
        end



        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        compile_links()
    end
end

