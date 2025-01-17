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
local headers = require("libs.common.headers")(Account)



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
    --- Alert Variables
    --------------------------------------------------------------------------------
    ---@param dv DiscreteValue
    ---@return boolean
    local function positive(dv)
        -- string:find returns a truthy value only when successful
        -- `not not` normalizes the return value to be a boolean rather than falsy or truthy.
        return dv.result ~= nil and not not dv.result:find("positive")
    end

    local d80_code = codes.get_code_prefix_link { prefix = "D80.", text = "Immunodeficiency with Predominantly Antibody Defects", sequence = 6 }
    local d81_code = codes.get_code_prefix_link { prefix = "D81.", text = "Combined Immunodeficiencies", sequence = 6 }
    local d82_code = codes.get_code_prefix_link { prefix = "D82.", text = "Immunodeficiency Associated with other Major Defects", sequence = 6 }
    local d83_code = codes.get_code_prefix_link { prefix = "D83.", text = "Common Variable Immunodeficiency", sequence = 6 }
    local d84_code = codes.get_code_prefix_link { prefix = "D84.", text = "Other Immunodeficiencies", sequence = 6 }
    local b44_code = codes.get_code_prefix_link { prefix = "B44.", text = "Aspergillosis Infection", sequence = 1 }
    local r7881_code = links.get_code_link { code = "R78.81", text = "Bacteremia", sequence = 2 }
    local b40_code = codes.get_code_prefix_link { prefix = "B40.", text = "Blastomycosis Infection", sequence = 3 }
    local b43_code = codes.get_code_prefix_link { prefix = "B43.", text = "Chromomycosis And Pheomycotic Abscess Infection", sequence = 5 }
    local covid_discrete_value = links.get_discrete_value_link { code = "SARS-CoV2 (COVID-19)", text = "Covid 19 Screen", predicate = positive, sequence = 6 }
    local b45_code = codes.get_code_prefix_link { prefix = "B45.", text = "Cryptococcosis Infection", sequence = 8 }
    local b25_code = codes.get_code_prefix_link { prefix = "B25.", text = "Cytomegaloviral Disease Code", sequence = 9 }
    local infection_abs = links.get_abstraction_link { code = "INFECTION", text = "Infection", sequence = 10 }
    local influenza_a_discrete_value = links.get_discrete_value_link { code = "Influenze A", text = "Influenza A Screen", predicate = positive, sequence = 11 }
    local influenza_b_discrete_value = links.get_discrete_value_link { code = "Influenze B", text = "Influenza B Screen", predicate = positive, sequence = 12 }
    local b49_code = codes.get_code_prefix_link { prefix = "B49.", text = "Mycosis Infection", sequence = 13 }
    local b96_code = codes.get_code_prefix_link { prefix = "B96.", text = "Other Bacterial Agents As The Cause Of Diseases Infection", sequence = 14 }
    local b41_code = codes.get_code_prefix_link { prefix = "B41.", text = "Paracoccidioidomycosis Infection", sequence = 15 }
    local r835_code = links.get_code_link { code = "R83.5", text = "Positive Cerebrospinal Fluid Culture", sequence = 16 }
    local r845_code = links.get_code_link { code = "R84.5", text = "Positive Respiratory Culture", sequence = 17 }
    local positive_would_culture_abs = links.get_abstraction_link { code = "POSITIVE_WOUND_CULTURE", text = "Positive Wound Culture", sequence = 18 }
    local b42_code = codes.get_code_prefix_link { prefix = "B42.", text = "Sporotrichosis Infection", sequence = 20 }
    local b95_code = codes.get_code_prefix_link { prefix = "B95.", text = "Streptococcus, Staphylococcus, and Enterococcus Infection", sequence = 22 }
    local b46_code = codes.get_code_prefix_link { prefix = "B46.", text = "Zygomycosis Infection", sequence = 23 }
    local antimetabolites_medication = links.get_medication_link { medication = "Antimetabolite", text = "", sequence = 1 }
    local antimetabolites_abs = links.get_abstraction_link { code = "ANTIMETABOLITE", text = "Antimetabolites", sequence = 2 }
    local z5111_code = links.get_code_link { code = "Z51.11", text = "Antineoplastic Chemotherapy", sequence = 3 }
    local z5112_code = links.get_code_link { code = "Z51.12", text = "Antineoplastic Immunotherapy", sequence = 4 }
    local antirejection_medication = links.get_medication_link { medication = "Antirejection Medication", text = "", sequence = 5 }
    local antirejection_medication_abs = links.get_abstraction_link { code = "ANTIREJECTION_MEDICATION", text = "Anti-Rejection Medication", sequence = 6 }
    local a3e04305_code = links.get_code_link { code = "3E04305", text = "Chemotherapy Administration", sequence = 7 }
    local interferons_medication = links.get_medication_link { medication = "Interferon", text = "", sequence = 8 }
    local interferons_abs = links.get_abstraction_link { code = "INTERFERON", text = "Interferon", sequence = 9 }
    local z796_code = codes.get_code_prefix_link { prefix = "Z79.6", text = "Long term Immunomodulators and Immunosuppressants", sequence = 10 }
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
        text = "Alcoholism",
        sequence = 1
    }
    local q8901_code = links.get_code_link { code = "Q89.01", text = "Asplenia", sequence = 2 }
    local z9481_code = links.get_code_link { code = "Z94.81", text = "Bone Marrow Transplant", sequence = 3 }
    local e84_code = codes.get_code_prefix_link { prefix = "E84.", text = "Cystic Fibrosis", sequence = 4 }
    local k721_code = codes.get_code_prefix_link { prefix = "K72.1", text = "End Stage Liver Disease", sequence = 5 }
    local n186_code = links.get_code_link { code = "N18.6", text = "ESRD", sequence = 6 }
    local c82_code = codes.get_code_prefix_link { prefix = "C82.", text = "Follicular Lymphoma", sequence = 7 }
    local z941_code = links.get_code_link { code = "Z94.1", text = "Heart Transplant", sequence = 8 }
    local z943_code = links.get_code_link { code = "Z94.3", text = "Heart and Lung Transplant", sequence = 9 }
    local b20_code = links.get_code_link { code = "B20", text = "HIV/AIDS", sequence = 10 }
    local c81_code = codes.get_code_prefix_link { prefix = "C81.", text = "Hodgkin Lymphoma", sequence = 11 }
    local c88_code = codes.get_code_prefix_link { prefix = "C88.", text = "Immunoproliferative Disease", sequence = 12 }
    local z9482_code = links.get_code_link { code = "Z94.82", text = "Intestine Transplant", sequence = 13 }
    local z940_code = links.get_code_link { code = "Z94.0", text = "Kidney Transplant", sequence = 14 }
    local c95_code = codes.get_code_prefix_link { prefix = "C95.", text = "Leukemia", sequence = 15 }
    local c94_code = codes.get_code_prefix_link { prefix = "C94.", text = "Leukemia", sequence = 16 }
    local c93_code = codes.get_code_prefix_link { prefix = "C93.", text = "Leukemia", sequence = 17 }
    local c92_code = codes.get_code_prefix_link { prefix = "C92.", text = "Leukemia", sequence = 18 }
    local d72819_code = links.get_code_link { code = "D72.819", text = "Leukopenia", sequence = 19 }
    local z944_code = links.get_code_link { code = "Z94.4", text = "Liver Transplant", sequence = 20 }
    local z942_code = links.get_code_link { code = "Z94.2", text = "Lung Transplant", sequence = 21 }
    local c91_code = codes.get_code_prefix_link { prefix = "C91.", text = "Lymphoid Leukemia", sequence = 22 }
    local c85_code = codes.get_code_prefix_link { prefix = "C85.", text = "Lymphoma", sequence = 23 }
    local c86_code = codes.get_code_prefix_link { prefix = "C86.", text = "Lymphoma", sequence = 24 }
    local m32_code = codes.get_code_prefix_link { prefix = "M32.", text = "Lupus", sequence = 25 }
    local c96_code = codes.get_code_prefix_link { prefix = "C96.", text = "Malignant Neoplasms", sequence = 26 }
    local c84_code = codes.get_code_prefix_link { prefix = "C84.", text = "Mature T/NK-Cell  Lymphoma", sequence = 27 }
    local c90_code = codes.get_code_prefix_link { prefix = "C90.", text = "Multiple Myeloma", sequence = 28 }
    local d46_code = codes.get_code_prefix_link { prefix = "D46.", text = "Myelodysplastic Syndrome", sequence = 29 }
    local c83_code = codes.get_code_prefix_link { prefix = "C83.", text = "Non-Follicular Lymphoma", sequence = 30 }
    local z9483_code = links.get_code_link { code = "Z94.83", text = "Pancreas Transplant", sequence = 31 }
    local pancytopenia_codes = links.get_code_links { codes = { "D61.810", "D61.811", "D61.818" }, text = "Pancytopenia", sequence = 32 }
    local hba1c_discrete_value = links.get_discrete_value_link {
        discreteValueName = "HEMOGLOBIN A1C (%)",
        text = "Poorly controlled HbA1c",
        predicate = function(dv, num) ---@diagnostic disable-line:unused-local
            return num > 10
        end,
        sequence = 33
    }
    local m05_code = codes.get_code_prefix_link { prefix = "M05.", text = "RA", sequence = 34 }
    local m06_code = codes.get_code_prefix_link { prefix = "M06.", text = "RA", sequence = 35 }
    local severe_malnutrition_codes = links.get_code_links { codes = { "E40", "E41", "E42", "E43" }, text = "Severe Malnutrition", sequence = 36 }
    local r161_code = links.get_code_link { code = "R16.1", text = "Splenomegaly", sequence = 37 }
    local wbc_discrete_value = links.get_discrete_value_link {
        discreteValueName = "WBC (10x3/ul)",
        text = "WBC",
        predicate = function(dv, num) ---@diagnostic disable-line:unused-local
            return num < 4.5
        end
    }

    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
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
            q8901_code, z9481_code,
            e84_code, k721_code, n186_code, c82_code, z941_code,
            z943_code, b20_code, c81_code, c88_code, z9482_code,
            z940_code, c95_code, c94_code, c93_code,
            c92_code, z944_code, z942_code, c91_code, c85_code,
            c86_code, m32_code, c96_code, c84_code, c90_code,
            d46_code, c83_code, z9483_code, r161_code,
            hba1c_discrete_value, m05_code, m06_code, severe_malnutrition_codes
        }
        if lists.some {
                b44_code, r7881_code, b40_code, b43_code, covid_discrete_value,
                b45_code, b25_code, infection_abs, influenza_a_discrete_value, influenza_b_discrete_value, b49_code, b96_code, b41_code, r835_code,
                r845_code, positive_would_culture_abs, b42_code, b95_code, b46_code
            } then
            local subtitle
            if medication and chronic then
                subtitle =
                "Infection Present with Possible Link to Immunocompromised State Due to Chronic Condition and Medication"
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

    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------

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
        local function isnt_eye(dv)
            return dv.route ~= nil
                and not dv.route:find("Eye")
                and not dv.route:find("optical")
                and not dv.route:find("ocular")
                and not dv.route:find("ophthalmic")
        end
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
            function(dv, num) return num < 1.5 end ---@diagnostic disable-line:unused-local
        )

        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        compile_links()
    end
end
