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
local dates = require("libs.common.dates")
local discrete = require("libs.common.discrete_values")(Account)
local headers = require("libs.common.headers")(Account)

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

    local d80_code = codes.get_code_prefix_link { prefix = "D80.", text = "Immunodeficiency with Predominantly Antibody Defects", sequence = 6 }
    local d81_code = codes.get_code_prefix_link { prefix = "D81.", text = "Combined Immunodeficiencies", sequence = 6 }
    local d82_code = codes.get_code_prefix_link { prefix = "D82.", text = "Immunodeficiency Associated with other Major Defects", sequence = 6 }
    local d83_code = codes.get_code_prefix_link { prefix = "D83.", text = "Common Variable Immunodeficiency", sequence = 6 }
    local d84_code = codes.get_code_prefix_link { prefix = "D84.", text = "Other Immunodeficiencies", sequence = 6 }
    local b44_code = codes.get_code_prefix_link { prefix = "B44.", text = "Aspergillosis Infection", sequence = 1 }
    local r7881_code = links.get_code_link { code = "R78.81", text = "Bacteremia", sequence = 2 }
    local b40_code = codes.get_code_prefix_link { prefix = "B40.", text = "Blastomycosis Infection", sequence = 3 }
    -- cBlood_discrete_value = dvPositiveCheck(dict(maindiscreteDic), dvCBlood, "Blood Culture Result", sequence = 4)
    local b43_code = codes.get_code_prefix_link { prefix = "B43.", text = "Chromomycosis And Pheomycotic Abscess Infection", sequence = 5 }
    -- covid_discrete_value = dvPositiveCheck(dict(maindiscreteDic), dvSARSCOVID, "Covid 19 Screen", sequence = 6)
    -- covidAnti_discrete_value = dvPositiveCheck(dict(maindiscreteDic), dvSARSCOVIDAntigen, "Covid 19 Screen", sequence = 7)
    local b45_code = codes.get_code_prefix_link { prefix = "B45.", text = "Cryptococcosis Infection", sequence = 8 }
    local b25_code = codes.get_code_prefix_link { prefix = "B25.", text = "Cytomegaloviral Disease Code", sequence = 9 }
    local infection_abs = links.get_abstraction_link { code = "INFECTION", text = "Infection", sequence = 10 }
    -- influenzeA_discrete_value = dvPositiveCheck(dict(maindiscreteDic), dvInfluenzeScreenA, "Influenza A Screen", sequence = 11)
    -- influenzeB_discrete_value = dvPositiveCheck(dict(maindiscreteDic), dvInfluenzeScreenB, "Influenza B Screen", sequence = 12)
    local b49_code = codes.get_code_prefix_link { prefix = "B49.", text = "Mycosis Infection", sequence = 13 }
    local b96_code = codes.get_code_prefix_link { prefix = "B96.", text = "Other Bacterial Agents As The Cause Of Diseases Infection", sequence = 14 }
    local b41_code = codes.get_code_prefix_link { prefix = "B41.", text = "Paracoccidioidomycosis Infection", sequence = 15 }
    local r835_code = links.get_code_link { code = "R83.5", text = "Positive Cerebrospinal Fluid Culture", sequence = 16 }
    local r845_code = links.get_code_link { code = "R84.5", text = "Positive Respiratory Culture", sequence = 17 }
    local positive_would_culture_abs = links.get_abstraction_link { code = "POSITIVE_WOUND_CULTURE", text = "Positive Wound Culture", sequence = 18 }
    -- cResp_discrete_value = dvmrsaCheck(dict(maindiscreteDic), dvCResp, "Final Report", "Respiratory Blood Culture Result", sequence = 19)
    local b42_code = codes.get_code_prefix_link { prefix = "B42.", text = "Sporotrichosis Infection", sequence = 20 }
    -- pneumococcalAnti_discrete_value = dvPositiveCheck(dict(maindiscreteDic), dvPneumococcalAntigen, "Strept Pneumonia Screen", sequence = 21)
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
        predicate = function(dv, num)
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
        predicate = function(dv, num)
            return num < 4.5
        end
    }

    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------

    if lists.some { d80_code, d81_code, d82_code, d83_code, d84_code } and existing_alert then
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
                b44_code, r7881_code, b40_code, blood_culture_discrete_value, b43_code, covidDv, covidAntiDV,
                b45_code, b25_code, infection_abs, influenzeADV, influenzeBDV, b48_code, b96_code, b41_code, r835_code,
                r845_code, positive_would_culture_abs, cRespDV, b42_code, pneumococcalAntiDV, b95_code, b46_code
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
        if not Result.validated then
            -- Normal Alert
        end



        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        compile_links()
    end
end
