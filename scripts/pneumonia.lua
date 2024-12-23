---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Pneumonia
---
--- This script checks an account to see if it matches the criteria for a pneumonia alert.
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
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 2)
    local vital_signs_header = headers.make_header_builder("Vital Signs/Intake and Output Data", 3)
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 4)
    local oxygen_ventilation_header = headers.make_header_builder("Oxygenation/Ventilation", 5)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 6)
    local ct_chest_header = headers.make_header_builder("CT Chest", 7)
    local chest_x_ray_header = headers.make_header_builder("Chest X-Ray", 8)
    local speech_and_language_pathologist_header = headers.make_header_builder("Speech and Language Pathologist Notes", 9)
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

    -- def dvOxygenCheck(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    --     abstraction = None
    --     for dv in dvDic or []:
    --         if (
    --             dvDic[dv]['Name'] in discreteValueName and
    --             dvDic[dv]['Result'] is not None and
    --             not re.search(r'\bRoom Air\b', dvDic[dv]['Result'], re.IGNORECASE) and
    --             not re.search(r'\bRA\b', dvDic[dv]['Result'], re.IGNORECASE)
    --         ):
    --             if abstract:
    --                 dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, True)
    --                 return True
    --             else:
    --                 abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, False)
    --                 return abstraction
    --     return abstraction

    -- def dvPositiveCheck(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    --     abstraction = None
    --     for dv in dvDic or []:
    --         if (
    --             dvDic[dv]['Name'] in discreteValueName and
    --             dvDic[dv]['Result'] is not None and
    --             (re.search(r'\bpositive\b', dvDic[dv]['Result'], re.IGNORECASE) is not None or
    --             re.search(r'\bDetected\b', dvDic[dv]['Result'], re.IGNORECASE) is not None)
    --         ):
    --             if abstract:
    --                 dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, True)
    --                 return True
    --             else:
    --                 abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, False)
    --                 return abstraction
    --     return abstraction

    -- def ivMedValue(medDic, med_name, link_text, sequence=0, category=None, abstract=False):
    --     for mv in medDic or []:
    --         if (
    --             medDic[mv]['Route'] is not None and
    --             medDic[mv]['Category'] == med_name and
    --             (re.search(r'\bIntravenous\b', medDic[mv]['Route'], re.IGNORECASE) or
    --             re.search(r'\bIV Push\b', medDic[mv]['Route'], re.IGNORECASE)) and
    --             (re.search(r'\bEye\b', medDic[mv]['Route'], re.IGNORECASE) is None and
    --             re.search(r'\btopical\b', medDic[mv]['Route'], re.IGNORECASE) is None and
    --             re.search(r'\bocular\b', medDic[mv]['Route'], re.IGNORECASE) is None and
    --             re.search(r'\bophthalmic\b', medDic[mv]['Route'], re.IGNORECASE) is None)
    --         ):
    --             if abstract == True:
    --                 medDataConversion(medDic[mv]['StartDate'], link_text, medDic[mv]['Medication'], medDic[mv]['ExternalId'], medDic[mv]['Dosage'], medDic[mv]['Route'], category, sequence)
    --                 return True
    --             elif abstract == False:
    --                 abstraction = medDataConversion(medDic[mv]['StartDate'], link_text, medDic[mv]['Medication'], medDic[mv]['ExternalId'], medDic[mv]['Dosage'], medDic[mv]['Route'], category, sequence, abstract)
    --                 return abstraction
    --     return None

    -- def antiboticMedValue(medDic, med_name, link_text, sequence=0, category=None, abstract=False):
    --     for mv in medDic or []:
    --         if (
    --             medDic[mv]['Route'] is not None and
    --             medDic[mv]['Category'] == med_name and
    --             (re.search(r'\bEye\b', medDic[mv]['Route'], re.IGNORECASE) is None and
    --             re.search(r'\btopical\b', medDic[mv]['Route'], re.IGNORECASE) is None and
    --             re.search(r'\bocular\b', medDic[mv]['Route'], re.IGNORECASE) is None and
    --             re.search(r'\bophthalmic\b', medDic[mv]['Route'], re.IGNORECASE) is None)
    --         ):
    --             if abstract == True:
    --                 medDataConversion(medDic[mv]['StartDate'], link_text, medDic[mv]['Medication'], medDic[mv]['ExternalId'], medDic[mv]['Dosage'], medDic[mv]['Route'], category, sequence)
    --                 return True
    --             elif abstract == False:
    --                 abstraction = medDataConversion(medDic[mv]['StartDate'], link_text, medDic[mv]['Medication'], medDic[mv]['ExternalId'], medDic[mv]['Dosage'], medDic[mv]['Route'], category, sequence, abstract)
    --                 return abstraction
    --     return None

    -- def medDataConversion(datetime, linkText, med, id, dosage, route, category, sequence, abstract=True):
    --     date_time = datetimeFromUtcToLocal(datetime)
    --     date_time = date_time.ToString("MM/dd/yyyy, HH:mm")
    --     linkText = linkText.replace("[STARTDATE]", date_time)
    --     linkText = linkText.replace("[MEDICATION]", med)
    --     linkText = linkText.replace("[DOSAGE]", dosage)
    --     if route is not None: linkText = linkText.replace("[ROUTE]", route)
    --     else: linkText = linkText.replace(", Route [ROUTE]", "")
    --     if abstract == True:
    --         abstraction = MatchedCriteriaLink(linkText, None, None, None, True, None, None, sequence)
    --         abstraction.MedicationId = id
    --         category.Links.Add(abstraction)
    --     elif abstract == False:
    --         abstraction = MatchedCriteriaLink(linkText, None, None, None, True, None, None, sequence)
    --         abstraction.MedicationId = id
    --         return abstraction
    --     return

    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------

    local unspecified_codes = links.get_code_links {
        codes = { "J12.89", "J12.9", "J16.8", "J18", "J18.0", "J18.1", "J18.2", "J18.8", "J18.9", "J15.69", "J15.8", "J15.9" },
        text = "Unspecified Pneumonia Dx",
    }

    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------

    -- TODO: I don't know how to translate this
    -- #Determine if alert was triggered before and if lacking had been triggered
    -- for alert in account.MatchedCriteriaGroups or []:
    --     if alert.CriteriaGroup == 'Pneumonia':
    --         alertTriggered = True
    --         validated = alert.IsValidated
    --         outcome = alert.Outcome
    --         subtitle = alert.Subtitle
    --         reason = alert.Reason
    --         if outcome == 'AUTORESOLVED' or reason == 'Previously Autoresolved':
    --             triggerAlert = False
    --         for alertLink in alert.Links:
    --             if alertLink.LinkText == 'Documentation Includes':
    --                 for links in alertLink.Links:
    --                     if re.search(r'\bAssigned\b', links.LinkText, re.IGNORECASE):
    --                         assignedCode = True
    --         break

    -- Why greater than 1??
    if #account_alert_codes > 1 or #unspecified_codes > 0 then
        -- Concatenate antibiotic categories. Lua doesn't have a function for this.
        local antibiotics = Account:find_medications("Antibiotic")
        for _, antibiotic in ipairs(Account:find_medications("Antibiotic2")) do
            table.insert(antibiotics, antibiotic)
        end

        table.sort(
            antibiotics,
            function(a, b)
                return dates.date_string_to_int(a.start_date) > dates.date_string_to_int(b.start_date)
            end
        )

        local discrete_value_names = {
            "MRSA DNA",
            "SARS-CoV2 (COVID-19)",
            "Influenza A",
            "Influenza B",
            "DELIVERY",
            "Respiratory syncytial virus",
            "Resp O2 Delivery Flow Num",
            "C REACTIVE PROTEIN (mg/dL)",
            "3.5 Neuro Glasgow Score",
            "INTERLEUKIN 6",
            "BLD GAS O2 (mmHg)", "PO2 (mmHg)",
            "PROCALCITONIN (ng/mL)",
            "3.5 Respiratory Rate (#VS I&O) (per Minute)",
            "Temperature Degrees C 3.5 (degrees C)", "Temperature  Degrees C 3.5 (degrees C)", "TEMPERATURE (C)",
            "WBC (10x3/ul)",
        }
        local discrete_values = {}

        for _, discrete_value in ipairs(discrete_value_names) do
            for _, discrete_value in ipairs(Account:find_discrete_values(discrete_value)) do
                table.insert(discrete_values, discrete_value)
            end
        end

        table.sort(
            discrete_values,
            function(a, b)
                return dates.date_string_to_int(a.start_date) > dates.date_string_to_int(b.start_date)
            end
        )
    end

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
