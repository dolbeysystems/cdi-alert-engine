---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Immunocompromised
---
--- This script checks an account to see if it matches the criteria for an Immunocompromised alert.
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
local lists = require "libs.common.lists"
local codes = require("libs.common.codes")(Account)
local discrete = require("libs.common.discrete_values")(Account)
local medications = require("libs.common.medications")(Account)
local headers = require("libs.common.headers")(Account)



--------------------------------------------------------------------------------
--- Script Specific Functions
--------------------------------------------------------------------------------
local positive = discrete.make_match_predicate { "Positive" }
local isnt_eye = medications.make_route_no_match_predicate { "Eye", "optical", "ocular", "ophthalmic" }



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }



if not existing_alert or not existing_alert.validated then
    --------------------------------------------------------------------------------
    --- Header Variables and Helper Functions
    --------------------------------------------------------------------------------
    local result_links = {}
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
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    local d80_code = codes.make_code_prefix_link("D80.", "Immunodeficiency with Predominantly Antibody Defects", 6)
    local d81_code = codes.make_code_prefix_link("D81.", "Combined Immunodeficiencies", 6)
    local d82_code = codes.make_code_prefix_link("D82.", "Immunodeficiency Associated with other Major Defects", 6)
    local d83_code = codes.make_code_prefix_link("D83.", "Common Variable Immunodeficiency", 6)
    local d84_code = codes.make_code_prefix_link("D84.", "Other Immunodeficiencies", 6)
    local b44_code = codes.make_code_prefix_link("B44.", "Aspergillosis Infection", 1)
    local r7881_code = codes.make_code_link("R78.81", "Bacteremia", 2)
    local b40_code = codes.make_code_prefix_link("B40.", "Blastomycosis Infection", 3)
    local b43_code = codes.make_code_prefix_link("B43.", "Chromomycosis And Pheomycotic Abscess Infection", 5)
    local covid_discrete_value = discrete.make_discrete_value_link({ "SARS-CoV2 (COVID-19)" }, "Covid 19 Screen", positive, 6)
    local b45_code = codes.make_code_prefix_link("B45.", "Cryptococcosis Infection", 8)
    local b25_code = codes.make_code_prefix_link("B25.", "Cytomegaloviral Disease Code", 9)
    local infection_abs = codes.make_abstraction_link("INFECTION", "Infection", 10)
    local influenza_a_discrete_value = discrete.make_discrete_value_link({ "Influenze A" }, "Influenza A Screen", positive, 11)
    local influenza_b_discrete_value = discrete.make_discrete_value_link({ "Influenze B" }, "Influenza B Screen", positive, 12)
    local b49_code = codes.make_code_prefix_link("B49.", "Mycosis Infection", 13)
    local b96_code = codes.make_code_prefix_link("B96.", "Other Bacterial Agents As The Cause Of Diseases Infection", 14)
    local b41_code = codes.make_code_prefix_link("B41.", "Paracoccidioidomycosis Infection", 15)
    local r835_code = codes.make_code_link("R83.5", "Positive Cerebrospinal Fluid Culture", 16)
    local r845_code = codes.make_code_link("R84.5", "Positive Respiratory Culture", 17)
    local positive_would_culture_abs = codes.make_abstraction_link("POSITIVE_WOUND_CULTURE", "Positive Wound Culture", 18)
    local b42_code = codes.make_code_prefix_link("B42.", "Sporotrichosis Infection", 20)
    local b95_code = codes.make_code_prefix_link("B95.", "Streptococcus, Staphylococcus, and Enterococcus Infection", 22)
    local b46_code = codes.make_code_prefix_link("B46.", "Zygomycosis Infection", 23)
    local antimetabolites_medication = medications.make_medication_link("Antimetabolite", "", 1)
    local antimetabolites_abs = codes.make_abstraction_link("ANTIMETABOLITE", "Antimetabolites", 2)
    local z5111_code = codes.make_code_link("Z51.11", "Antineoplastic Chemotherapy", 3)
    local z5112_code = codes.make_code_link("Z51.12", "Antineoplastic Immunotherapy", 4)
    local antirejection_medication = medications.make_medication_link("Antirejection Medication", "", 5)
    local antirejection_medication_abs = codes.make_abstraction_link("ANTIREJECTION_MEDICATION", "Anti-Rejection Medication", 6)
    local a3e04305_code = codes.make_code_link("3E04305", "Chemotherapy Administration", 7)
    local interferons_medication = medications.make_medication_link("Interferon", "", 8)
    local interferons_abs = codes.make_abstraction_link("INTERFERON", "Interferon", 9)
    local z796_code = codes.make_code_prefix_link("Z79.6", "Long term Immunomodulators and Immunosuppressants", 10)
    local z7952_code = codes.make_code_link("Z79.52", "Long term Systemic Sterioids", 11)
    local monoclonal_antibodies_medication = medications.make_medication_link("Monoclonal Antibodies", "", 12)
    local monoclonal_antibodies_abs = codes.make_abstraction_link("MONOCLONAL_ANTIBODIES", "Monoclonal Antibodies", 13)
    local tumor_necrosis_medication = medications.make_medication_link("Tumor Necrosis Factor Alpha Inhibitor", "", 14)
    local tumor_necrosis_abs = codes.make_abstraction_link("TUMOR_NECROSIS_FACTOR_ALPHA_INHIBITOR", "Tumor Necrosis Factor Alpha Inhibitor", 15)
    local alcoholism_codes = codes.make_code_links(
        {
            "F10.20", "F10.220", "F10.2221", "F10.2229", "F10.230", "F10.20", "F10.231",
            "F10.232", "F10.239", "F10.24", "F10.250", "F10.251", "F10.259", "F10.26",
            "F10.27", "F10.280", "F10.281", "F10.282", "F10.288", "F10.29"
        },
        "Alcoholism",
        1
    )
    local q8901_code = codes.make_code_link("Q89.01", "Asplenia", 2)
    local z9481_code = codes.make_code_link("Z94.81", "Bone Marrow Transplant", 3)
    local e84_code = codes.make_code_prefix_link("E84.", "Cystic Fibrosis", 4)
    local k721_code = codes.make_code_prefix_link("K72.1", "End Stage Liver Disease", 5)
    local n186_code = codes.make_code_link("N18.6", "ESRD", 6)
    local c82_code = codes.make_code_prefix_link("C82.", "Follicular Lymphoma", 7)
    local z941_code = codes.make_code_link("Z94.1", "Heart Transplant", 8)
    local z943_code = codes.make_code_link("Z94.3", "Heart and Lung Transplant", 9)
    local b20_code = codes.make_code_link("B20", "HIV/AIDS", 10)
    local c81_code = codes.make_code_prefix_link("C81.", "Hodgkin Lymphoma", 11)
    local c88_code = codes.make_code_prefix_link("C88.", "Immunoproliferative Disease", 12)
    local z9482_code = codes.make_code_link("Z94.82", "Intestine Transplant", 13)
    local z940_code = codes.make_code_link("Z94.0", "Kidney Transplant", 14)
    local c95_code = codes.make_code_prefix_link("C95.", "Leukemia", 15)
    local c94_code = codes.make_code_prefix_link("C94.", "Leukemia", 16)
    local c93_code = codes.make_code_prefix_link("C93.", "Leukemia", 17)
    local c92_code = codes.make_code_prefix_link("C92.", "Leukemia", 18)
    local d72819_code = codes.make_code_link("D72.819", "Leukopenia", 19)
    local z944_code = codes.make_code_link("Z94.4", "Liver Transplant", 20)
    local z942_code = codes.make_code_link("Z94.2", "Lung Transplant", 21)
    local c91_code = codes.make_code_prefix_link("C91.", "Lymphoid Leukemia", 22)
    local c85_code = codes.make_code_prefix_link("C85.", "Lymphoma", 23)
    local c86_code = codes.make_code_prefix_link("C86.", "Lymphoma", 24)
    local m32_code = codes.make_code_prefix_link("M32.", "Lupus", 25)
    local c96_code = codes.make_code_prefix_link("C96.", "Malignant Neoplasms", 26)
    local c84_code = codes.make_code_prefix_link("C84.", "Mature T/NK-Cell  Lymphoma", 27)
    local c90_code = codes.make_code_prefix_link("C90.", "Multiple Myeloma", 28)
    local d46_code = codes.make_code_prefix_link("D46.", "Myelodysplastic Syndrome", 29)
    local c83_code = codes.make_code_prefix_link("C83.", "Non-Follicular Lymphoma", 30)
    local z9483_code = codes.make_code_link("Z94.83", "Pancreas Transplant", 31)
    local pancytopenia_codes = codes.make_code_one_of_link({ "D61.810", "D61.811", "D61.818" }, "Pancytopenia", 32)
    local hba1c_discrete_value = discrete.make_discrete_value_link(
        { "HEMOGLOBIN A1C (%)" },
        "Poorly controlled HbA1c",
        function(dv_, num) return num > 10 end,
        33
    )
    local m05_code = codes.make_code_prefix_link("M05.", "RA", 34)
    local m06_code = codes.make_code_prefix_link("M06.", "RA", 35)
    local severe_malnutrition_codes = codes.make_code_one_of_link({ "E40", "E41", "E42", "E43" }, "Severe Malnutrition", 36)
    local r161_code = codes.make_code_link("R16.1", "Splenomegaly", 37)
    local wbc_discrete_value = discrete.make_discrete_value_link(
        { "WBC (10x3/ul)" },
        "WBC",
        function(dv_, num) return num < 4.5 end
    )



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if existing_alert and lists.some { d80_code, d81_code, d82_code, d83_code, d84_code } then
        for _, v in ipairs { d80_code, d81_code, d82_code, d83_code, d84_code } do
            v.link_text = "Autoresolved Specified Code - " .. v.link_text
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one or more specified code(s) on the Account"
        Result.validated = true
    else
        local medication = lists.some {
            antimetabolites_medication, antimetabolites_abs, z5111_code, z5112_code,
            antirejection_medication, antirejection_medication_abs, a3e04305_code, interferons_medication,
            interferons_abs, z796_code, z7952_code, monoclonal_antibodies_medication,
            monoclonal_antibodies_abs, tumor_necrosis_medication, tumor_necrosis_abs
        }
        local chronic = #alcoholism_codes > 0 and lists.some {
            q8901_code, z9481_code, e84_code, k721_code, n186_code, c82_code, z941_code, z943_code, b20_code, c81_code,
            c88_code, z9482_code, z940_code, c95_code, c94_code, c93_code, c92_code, z944_code, z942_code, c91_code,
            c85_code, c86_code, m32_code, c96_code, c84_code, c90_code, d46_code, c83_code, z9483_code, r161_code,
            hba1c_discrete_value, m05_code, m06_code, severe_malnutrition_codes
        }
        if lists.some {
                b44_code, r7881_code, b40_code, b43_code, covid_discrete_value,
                b45_code, b25_code, infection_abs, influenza_a_discrete_value, influenza_b_discrete_value, b49_code,
                b96_code, b41_code, r835_code, r845_code, positive_would_culture_abs, b42_code, b95_code, b46_code
            }
        then
            local subtitle

            if medication and chronic then
                subtitle = "Infection Present with Possible Link to Immunocompromised State Due to Chronic Condition and Medication"
            elseif medication then
                subtitle = "Infection Present with Possible Link to Immunocompromised State Due to Medication"
            elseif chronic then
                subtitle = "Infection Present with Possible Link to Immunocompromised State Due to Chronic Condition"
            end

            if subtitle ~= nil then
                Result.subtitle = subtitle
                Result.passed = true
                goto alert_passed
            end
        end
        if pancytopenia_codes ~= nil or d72819_code ~= nil or wbc_discrete_value ~= nil and (medication or chronic) then
            chronic_conditions_header:add_links { d72819_code, pancytopenia_codes }
            Result.subtitle = "Possible Immunocompromised State"
            Result.passed = true
        end
    end
    ::alert_passed::



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        infectious_process_header:add_link(b44_code)
        infectious_process_header:add_link(b44_code)
        infectious_process_header:add_link(r7881_code)
        infectious_process_header:add_link(b40_code)
        infectious_process_header:add_link(b43_code)
        infectious_process_header:add_link(covid_discrete_value)
        infectious_process_header:add_link(b45_code)
        infectious_process_header:add_link(b25_code)
        infectious_process_header:add_link(infection_abs)
        infectious_process_header:add_link(influenza_a_discrete_value)
        infectious_process_header:add_link(influenza_b_discrete_value)
        infectious_process_header:add_link(b49_code)
        infectious_process_header:add_link(b96_code)
        infectious_process_header:add_link(b41_code)
        infectious_process_header:add_link(r835_code)
        infectious_process_header:add_link(r845_code)
        infectious_process_header:add_link(positive_would_culture_abs)
        infectious_process_header:add_link(b42_code)
        infectious_process_header:add_link(b95_code)
        infectious_process_header:add_link(b46_code)
        suppressive_medication_header:add_link(antimetabolites_abs)
        suppressive_medication_header:add_link(antimetabolites_medication)
        suppressive_medication_header:add_link(z5111_code)
        suppressive_medication_header:add_link(z5112_code)
        suppressive_medication_header:add_link(antirejection_medication)
        suppressive_medication_header:add_link(antirejection_medication_abs)
        suppressive_medication_header:add_link(a3e04305_code)
        suppressive_medication_header:add_link(interferons_abs)
        suppressive_medication_header:add_link(interferons_medication)
        suppressive_medication_header:add_link(z796_code)
        suppressive_medication_header:add_link(z7952_code)
        suppressive_medication_header:add_link(monoclonal_antibodies_abs)
        suppressive_medication_header:add_link(monoclonal_antibodies_medication)
        suppressive_medication_header:add_link(tumor_necrosis_abs)
        suppressive_medication_header:add_link(tumor_necrosis_medication)
        treatment_and_monitoring_header:add_medication_link("Antibiotic", "Antibiotic", isnt_eye)
        treatment_and_monitoring_header:add_medication_link("Antibiotic2", "Antibiotic", isnt_eye)
        treatment_and_monitoring_header:add_abstraction_link("ANTIBIOTIC", "Antibiotic")
        treatment_and_monitoring_header:add_abstraction_link("ANTIBIOTIC_2", "Antibiotic")
        treatment_and_monitoring_header:add_medication_link("Antifungal", "Antifungal")
        treatment_and_monitoring_header:add_abstraction_link("ANTIFUNGAL", "Antifungal")
        treatment_and_monitoring_header:add_medication_link("Antiviral", "Antiviral")
        treatment_and_monitoring_header:add_abstraction_link("ANTIVIRAL", "Antiviral")
        chronic_conditions_header:add_links(alcoholism_codes)
        chronic_conditions_header:add_link(q8901_code)
        chronic_conditions_header:add_link(z9481_code)
        chronic_conditions_header:add_link(e84_code)
        chronic_conditions_header:add_link(k721_code)
        chronic_conditions_header:add_link(n186_code)
        chronic_conditions_header:add_link(c82_code)
        chronic_conditions_header:add_link(z941_code)
        chronic_conditions_header:add_link(z943_code)
        chronic_conditions_header:add_link(b20_code)
        chronic_conditions_header:add_link(c81_code)
        chronic_conditions_header:add_link(c88_code)
        chronic_conditions_header:add_link(z9482_code)
        chronic_conditions_header:add_link(z940_code)
        chronic_conditions_header:add_link(c95_code)
        chronic_conditions_header:add_link(c94_code)
        chronic_conditions_header:add_link(c93_code)
        chronic_conditions_header:add_link(c92_code)
        chronic_conditions_header:add_link(z944_code)
        chronic_conditions_header:add_link(z942_code)
        chronic_conditions_header:add_link(c91_code)
        chronic_conditions_header:add_link(c85_code)
        chronic_conditions_header:add_link(c86_code)
        chronic_conditions_header:add_link(m32_code)
        chronic_conditions_header:add_link(c96_code)
        chronic_conditions_header:add_link(c84_code)
        chronic_conditions_header:add_link(c90_code)
        chronic_conditions_header:add_link(d46_code)
        chronic_conditions_header:add_link(c83_code)
        chronic_conditions_header:add_link(z9483_code)
        chronic_conditions_header:add_link(hba1c_discrete_value)
        chronic_conditions_header:add_link(m05_code)
        chronic_conditions_header:add_link(m06_code)
        chronic_conditions_header:add_links(severe_malnutrition_codes)
        chronic_conditions_header:add_link(r161_code)
        laboratory_studies_header:add_link(wbc_discrete_value)
        laboratory_studies_header:add_discrete_value_link(
            "ABS NEUT COUNT (10x3/uL)",
            "Absolute Neutropils: [VALUE] (Result Date: [RESULTDATETIME])",
            function(dv_, num) return num < 1.5 end
        )



        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        compile_links()
    end
end

