---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Immunocompromised
---
--- This script checks an account to see if it matches the criteria for an Immunocompromised alert.
---
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
---------------------------------------------------------------------------------------------------------------------
---@diagnostic disable: unused-local, empty-block -- Remove once the script is filled out



--------------------------------------------------------------------------------
--- Requires
--------------------------------------------------------------------------------
local alerts = require("libs.common.alerts")(Account)
local links = require("libs.common.basic_links")(Account)
local codes = require("libs.common.codes")(Account)
local dates = require("libs.common.dates")
local discrete = require("libs.common.discrete_values")(Account)
local headers = require("libs.common.headers")(Account)



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------

-- dvAbsoluteNeutrophil = ["ABS NEUT COUNT (10x3/uL)"]
-- calcAbsoluteNeutrophil1 = lambda x: x < 1.5
-- dvHematocrit = ["HEMATOCRIT (%)", "HEMATOCRIT"]
-- calcHematocrit1 = lambda x: x < 34
-- calcHematocrit2 = lambda x: x < 40
-- dvHemoglobin = ["HEMOGLOBIN", "HEMOGLOBIN (g/dL)"]
-- calcHemoglobin1 = lambda x: x < 13.5
-- calcHemoglobin2 = lambda x: x < 12.5
-- dvPlateletCount = ["PLATELET COUNT (10x3/uL)"]
-- calcPlateletCount1 = lambda x: x < 150
-- dvWBC = ["WBC (10x3/ul)"]
-- calcWBC1 = lambda x: x < 4.5
-- calcWBC2 = lambda x: x > 11

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
    -- dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
    -- infectonProcess = MatchedCriteriaLink("Infectious Process", None, "Infectious Process", None, True, None, None, 2)
    -- medIS = MatchedCriteriaLink("Medication that can suppress the immune system", None, "Medication that can suppress the immune system", None, True, None, None, 3)
    -- chronic = MatchedCriteriaLink("Chronic Conditions", None, "Chronic Conditions", None, True, None, None, 4)
    -- labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 5)
    -- treatment = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 6)
    -- other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 7)
    local documented_dx_header = headers.make_header_builder("Documented Dx", 1)
    local infectious_process_header = headers.make_header_builder("Infectious Process", 2)
    local suppressive_medication_header = headers.make_header_builder("Medication that can suppress the immune system", 3)
    local chronic_conditions_header = headers.make_header_builder("Chronic Conditions", 4)
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 5)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 6)

    local function compile_links()
        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, infectious_process_header:build(true))
        table.insert(result_links, suppressive_medication_header:build(true))
        table.insert(result_links, chronic_conditions_header:build(true))
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

    local medications = links.get_medication_links { cats = { "Antibiotic", "Antibiotic2" } }
    local discrete_values = links.get_discrete_value_links { discreteValueNames = {
        "SARS-CoV2 (COVID-19)", "Influenza A", "Influenza B"
    } }

    local d80_codes = codes.get_code_prefix_link { prefix = "D80.", text = "Immunodeficiency with Predominantly Antibody Defects", sequence = 6 }
    local d81_codes = codes.get_code_prefix_link { prefix = "D81.", text = "Combined Immunodeficiencies", sequence = 6 }
    local d82_codes = codes.get_code_prefix_link { prefix = "D82.", text = "Immunodeficiency Associated with other Major Defects", sequence = 6 }
    local d83_codes = codes.get_code_prefix_link { prefix = "D83.", text = "Common Variable Immunodeficiency", sequence = 6 }
    local d84_codes = codes.get_code_prefix_link { prefix = "D84.", text = "Other Immunodeficiencies", sequence = 6 }
    local b44_codes = codes.get_code_prefix_link { prefix = "B44.", text = "Aspergillosis Infection", sequence = 1 }
    local r7881_code = links.get_code_link { code = "R78.81", text = "Bacteremia", sequence = 2 }
    local b40_codes = codes.get_code_prefix_link { prefix = "B40.", text = "Blastomycosis Infection", sequence = 3 }
    -- cBlood_discrete_value = dvPositiveCheck(dict(maindiscreteDic), dvCBlood, "Blood Culture Result", sequence = 4)
    local b43_codes = codes.get_code_prefix_link { prefix = "B43.", text = "Chromomycosis And Pheomycotic Abscess Infection", sequence = 5 }
    -- covid_discrete_value = dvPositiveCheck(dict(maindiscreteDic), dvSARSCOVID, "Covid 19 Screen", sequence = 6)
    -- covidAnti_discrete_value = dvPositiveCheck(dict(maindiscreteDic), dvSARSCOVIDAntigen, "Covid 19 Screen", sequence = 7)
    local b45_codes = codes.get_code_prefix_link { prefix = "B45.", text = "Cryptococcosis Infection", sequence = 8 }
    local b25_codes = codes.get_code_prefix_link { prefix = "B25.", text = "Cytomegaloviral Disease Code", sequence = 9 }
    local infection_abs = links.get_abstraction_link { code = "INFECTION", text = "Infection", sequence = 10 }
    -- influenzeA_discrete_value = dvPositiveCheck(dict(maindiscreteDic), dvInfluenzeScreenA, "Influenza A Screen", sequence = 11)
    -- influenzeB_discrete_value = dvPositiveCheck(dict(maindiscreteDic), dvInfluenzeScreenB, "Influenza B Screen", sequence = 12)
    local b49_codes = codes.get_code_prefix_link { prefix = "B49.", text = "Mycosis Infection", sequence = 13 }
    local b96_codes = codes.get_code_prefix_link { prefix = "B96.", text = "Other Bacterial Agents As The Cause Of Diseases Infection", sequence = 14 }
    local b41_codes = codes.get_code_prefix_link { prefix = "B41.", text = "Paracoccidioidomycosis Infection", sequence = 15 }
    local r835_code = links.get_code_link { code = "R83.5", text = "Positive Cerebrospinal Fluid Culture", sequence = 16 }
    local r845_code = links.get_code_link { code = "R84.5", text = "Positive Respiratory Culture", sequence = 17 }
    local positive_would_culture_abs = links.get_abstraction_link { code = "POSITIVE_WOUND_CULTURE", text = "Positive Wound Culture", sequence = 18 }
    -- cResp_discrete_value = dvmrsaCheck(dict(maindiscreteDic), dvCResp, "Final Report", "Respiratory Blood Culture Result", sequence = 19)
    local b42_codes = codes.get_code_prefix_link { prefix = "B42.", text = "Sporotrichosis Infection", sequence = 20 }
    -- pneumococcalAnti_discrete_value = dvPositiveCheck(dict(maindiscreteDic), dvPneumococcalAntigen, "Strept Pneumonia Screen", sequence = 21)
    local b95_codes = codes.get_code_prefix_link { prefix = "B95.", text = "Streptococcus, Staphylococcus, and Enterococcus Infection", sequence = 22 }
    local b46_codes = codes.get_code_prefix_link { prefix = "B46.", text = "Zygomycosis Infection", sequence = 23 }
    local antimetabolites_medication = links.get_medication_link { medication = "Antimetabolite", text = "", sequence = 1 }
    local antimetabolites_abs = links.get_abstraction_link { code = "ANTIMETABOLITE", text = "Antimetabolites", sequence = 2 }
    local z5111_code = links.get_code_link { code = "Z51.11", text = "Antineoplastic Chemotherapy", sequence = 3 }
    local z5112_code = links.get_code_link { code = "Z51.12", text = "Antineoplastic Immunotherapy", sequence = 4 }
    local antirejection_medication = links.get_medication_link { medication = "Antirejection Medication", text = "", sequence = 5 }
    local antirejection_medication_abs = links.get_abstraction_link { code = "ANTIREJECTION_MEDICATION", text = "Anti-Rejection Medication", sequence = 6 }
    local a3e04305_code = links.get_code_link { code = "3E04305", text = "Chemotherapy Administration", sequence = 7 }
    local interferons_medication = links.get_medication_link { medication = "Interferon", text = "", sequence = 8 }
    local interferons_abs = links.get_abstraction_link { code = "INTERFERON", text = "Interferon", sequence = 9 }
    local z796_codes = codes.get_code_prefix_link { prefix = "Z79.6", text = "Long term Immunomodulators and Immunosuppressants", sequence = 10 }
    local z7952_code = links.get_code_link { code = "Z79.52", text = "Long term Systemic Sterioids", sequence = 11 }
    local monoclonal_antibodies_medication = links.get_medication_link { medication = "Monoclonal Antibodies", text = "", sequence = 12 }
    local monoclonal_antibodies_abs = links.get_abstraction_link { code = "MONOCLONAL_ANTIBODIES", text = "Monoclonal Antibodies", sequence = 13 }
    local tumor_necrosis_medication = links.get_medication_link { medication = "Tumor Necrosis Factor Alpha Inhibitor", text = "", sequence = 14 }
    local tumor_necrosis_abs = links.get_abstraction_link { code = "TUMOR_NECROSIS_FACTOR_ALPHA_INHIBITOR", text = "Tumor Necrosis Factor Alpha Inhibitor", sequence = 15 }
    local alcoholism_codes = links.get_code_links {
        codes = {
            "F10.20", "F10.220", "F10.2221", "F10.2229", "F10.230", "F10.20", "F10.231",
            "F10.232", "F10.239", "F10.24", "F10.250", "F10.251", "F10.259", "F10.26",
            "F10.27", "F10.280", "F10.281", "F10.282", "F10.288", "F10.29"
        },
        text = "Alcoholism: [CODE]",
        sequence = 1
    }
    local q8901_code = links.get_code_link { code = "Q89.01", text = "Asplenia", sequence = 2 }
    local z9481_code = links.get_code_link { code = "Z94.81", text = "Bone Marrow Transplant", sequence = 3 }
    local e84_codes = codes.get_code_prefix_link { prefix = "E84.", text = "Cystic Fibrosis", sequence = 4 }
    local k721_codes = codes.get_code_prefix_link { prefix = "K72.1", text = "End Stage Liver Disease", sequence = 5 }
    local n186_code = links.get_code_link { code = "N18.6", text = "ESRD", sequence = 6 }
    local c82_codes = codes.get_code_prefix_link { prefix = "C82.", text = "Follicular Lymphoma", sequence = 7 }
    local z941_code = links.get_code_link { code = "Z94.1", text = "Heart Transplant", sequence = 8 }
    local z943_code = links.get_code_link { code = "Z94.3", text = "Heart and Lung Transplant", sequence = 9 }
    local b20_code = links.get_code_link { code = "B20", text = "HIV/AIDS", sequence = 10 }
    local c81_codes = codes.get_code_prefix_link { prefix = "C81.", text = "Hodgkin Lymphoma", sequence = 11 }
    local c88_codes = codes.get_code_prefix_link { prefix = "C88.", text = "Immunoproliferative Disease", sequence = 12 }
    local z9482_code = links.get_code_link { code = "Z94.82", text = "Intestine Transplant", sequence = 13 }
    local z940_code = links.get_code_link { code = "Z94.0", text = "Kidney Transplant", sequence = 14 }
    local c95_codes = codes.get_code_prefix_link { prefix = "C95.", text = "Leukemia", sequence = 15 }
    local c94_codes = codes.get_code_prefix_link { prefix = "C94.", text = "Leukemia", sequence = 16 }
    local c93_codes = codes.get_code_prefix_link { prefix = "C93.", text = "Leukemia", sequence = 17 }
    local c92_codes = codes.get_code_prefix_link { prefix = "C92.", text = "Leukemia", sequence = 18 }
    local d72819_code = links.get_code_link { code = "D72.819", text = "Leukopenia", sequence = 19 }
    local z944_code = links.get_code_link { code = "Z94.4", text = "Liver Transplant", sequence = 20 }
    local z942_code = links.get_code_link { code = "Z94.2", text = "Lung Transplant", sequence = 21 }
    local c91_codes = codes.get_code_prefix_link { prefix = "C91.", text = "Lymphoid Leukemia", sequence = 22 }
    local c85_codes = codes.get_code_prefix_link { prefix = "C85.", text = "Lymphoma", sequence = 23 }
    local c86_codes = codes.get_code_prefix_link { prefix = "C86.", text = "Lymphoma", sequence = 24 }
    local m32_codes = codes.get_code_prefix_link { prefix = "M32.", text = "Lupus", sequence = 25 }
    local c96_codes = codes.get_code_prefix_link { prefix = "C96.", text = "Malignant Neoplasms", sequence = 26 }
    local c84_codes = codes.get_code_prefix_link { prefix = "C84.", text = "Mature T/NK-Cell  Lymphoma", sequence = 27 }
    local c90_codes = codes.get_code_prefix_link { prefix = "C90.", text = "Multiple Myeloma", sequence = 28 }
    local d46_codes = codes.get_code_prefix_link { prefix = "D46.", text = "Myelodysplastic Syndrome", sequence = 29 }
    local c83_codes = codes.get_code_prefix_link { prefix = "C83.", text = "Non-Follicular Lymphoma", sequence = 30 }
    local z9483_code = links.get_code_link { code = "Z94.83", text = "Pancreas Transplant", sequence = 31 }
    local pancytopenia_codes = links.get_code_links { codes = { "D61.810", "D61.811", "D61.818" }, text = "Pancytopenia", sequence = 32 }
    local hba1c_discrete_value = links.get_discrete_value_link {
        discreteValueName = "HEMOGLOBIN A1C (%)",
        text = "Poorly controlled HbA1c",
        predicate = function(dv, num)
            return num > 10
        end,
        sequence = 33
    }
    local m05_codes = codes.get_code_prefix_link { prefix = "M05.", text = "RA", sequence = 34 }
    local m06_codes = codes.get_code_prefix_link { prefix = "M06.", text = "RA", sequence = 35 }
    local severe_malnutrition_codes = links.get_code_links { codes = { "E40", "E41", "E42", "E43" }, text = "Severe Malnutrition", sequence = 36 }
    local r161_code = links.get_code_link { code = "R16.1", text = "Splenomegaly", sequence = 37 }
    -- wbc_discrete_value = dvValue(dvWBC, "WBC", calcWBC1, sequence = 2)

    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Normal Alert
        end



        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        compile_links()
    end
end
