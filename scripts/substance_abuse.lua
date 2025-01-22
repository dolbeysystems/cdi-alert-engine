---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Substance Abuse
---
--- This script checks an account to see if it matches the criteria for a substance abuse alert.
---
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
---------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Requires
--------------------------------------------------------------------------------
local alerts = require "libs.common.alerts" (Account)
local links = require "libs.common.basic_links" (Account)
local codes = require "libs.common.codes" (Account)
local discrete = require("libs.common.discrete_values")(Account)
local headers = require "libs.common.headers" (Account)
local lists = require "libs.common.lists"



--------------------------------------------------------------------------------
--- Setup
--------------------------------------------------------------------------------
local ciwa_score_dv_name = { "alcohol CIWA Calc score 1112" }
local ciwa_score_dv_predicate = discrete.make_gt_predicate(9)
local methadone_medication_name = "Methadone"
local suboxone_medication_name = "Suboxone"
local benzodiazepine_medication_name = "Benzodiazepine"
local dexmedetomidine_medication_name = "Dexmedetomidine"
local lithium_medication_name = "Lithium"
local propofol_medication_name = "Propofol"
local pain_document_types = { "Pain Team Consultation Note", "zzPain Team Consultation Note", "Pain Team Progress Note" }
local opioid_dependence_subtitle = "Possible Opioid Dependence"
local alcohol_withdrawal_subtitle = "Possible Alcohol Withdrawal"



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName, account = Account }
local subtitle = existing_alert and existing_alert.subtitle or nil



if not existing_alert or not existing_alert.validated then
    --------------------------------------------------------------------------------
    --- Header Variables and Helper Functions
    --------------------------------------------------------------------------------
    local result_links = {}
    local documented_dx_header = headers.make_header_builder("Documented Dx", 1)
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 2)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 3)
    local pain_team_consult_header = headers.make_header_builder("Pain Team Consult", 4)

    local function compile_links()
        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))
        table.insert(result_links, pain_team_consult_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end



    --------------------------------------------------------------------------------
    --- Alert Variables
    --------------------------------------------------------------------------------
    local alcohol_code_dic = {
        ["F10.130"] = "Alcohol abuse with withdrawal, uncomplicated",
        ["F10.131"] = "Alcohol abuse with withdrawal delirium",
        ["F10.132"] = "Alcohol Abuse with Withdrawal",
        ["F10.139"] = "Alcohol abuse with withdrawal, unspecified",
        ["F10.230"] = "Alcohol Dependence with Withdrawal, Uncomplicated",
        ["F10.231"] = "Alcohol Dependence with Withdrawal Delirium",
        ["F10.232"] = "Alcohol Dependence with Withdrawal with Perceptual Disturbance",
        ["F10.239"] = "Alcohol Dependence with Withdrawal, Unspecified",
        ["F10.930"] = "Alcohol use, unspecified with withdrawal, uncomplicated",
        ["F10.931"] = "Alcohol use, unspecified with withdrawal delirium",
        ["F10.932"] = "Alcohol use, unspecified with withdrawal with perceptual disturbance",
        ["F10.939"] = "Alcohol use, unspecified with withdrawal, unspecified"
    }

    local opioid_code_dic = {
        ["F11.20"] = "Opioid Dependence, Uncomplicated",
        ["F11.21"] = "Opioid Dependence, In Remission",
        ["F11.22"] = "Opioid Dependence with Intoxication",
        ["F11.220"] = "Opioid Dependence with Intoxication, Uncomplicated",
        ["F11.221"] = "Opioid Dependence with Intoxication, Delirium",
        ["F11.222"] = "Opioid Dependence with Intoxication, Perceptual Disturbance",
        ["F11.229"] = "Opioid Dependence with Intoxication, Unspecified",
        ["F11.23"] = "Opioid Dependence with Withdrawal",
        ["F11.24"] = "Opioid Dependence with Withdrawal Delirium",
        ["F11.25"] = "Opioid dependence with opioid-induced psychotic disorder",
        ["F11.250"] = "Opioid dependence with opioid-induced psychotic disorder with delusions",
        ["F11.251"] = "Opioid dependence with opioid-induced psychotic disorder with hallucinations",
        ["F11.259"] = "Opioid dependence with opioid-induced psychotic disorder, unspecified",
        ["F11.28"] = "Opioid dependence with other opioid-induced disorder",
        ["F11.281"] = "Opioid dependence with opioid-induced sexual dysfunction",
        ["F11.282"] = "Opioid dependence with opioid-induced sleep disorder",
        ["F11.288"] = "Opioid dependence with other opioid-induced disorder",
        ["F11.29"] = "Opioid dependence with unspecified opioid-induced disorder"
    }

    -- Get the alcohol and opioid codes on the account
    local account_alcohol_codes = codes.get_account_codes_in_dictionary(Account, alcohol_code_dic)
    local account_opioid_codes = codes.get_account_codes_in_dictionary(Account, opioid_code_dic)



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    local ciwa_score_dv_link =
        discrete.make_discrete_value_link(ciwa_score_dv_name, "CIWA Score", ciwa_score_dv_predicate, 5)
    local ciwa_score_abstraction_link = codes.make_abstraction_link_with_value("CIWA_SCORE", "CIWA Score", 6)
    local ciwa_protocol_abstraction_link = codes.make_abstraction_link_with_value("CIWA_PROTOCOL", "CIWA Protocol", 7)
    local methadone_medication_links = links.get_medication_links {
        cat = methadone_medication_name,
        text = "Methadone",
        seq = 9,
        useCdiAlertCategoryField = true,
        onePerDate = true,
        maxPerValue = 9999,
    } or {}
    local methadone_abstraction_link = codes.make_abstraction_link_with_value("METHADONE", "Methadone", 8)
    local suboxone_medication_link = links.get_medication_link {
        cat = suboxone_medication_name,
        text = "Suboxone",
        seq = 11,
        useCdiAlertCategoryField = true,
        onlyOne = true,
    }
    local suboxone_abstraction_link = codes.make_abstraction_link_with_value("SUBOXONE", "Suboxone", 12)
    local methadone_clinic_abstraction_link = codes.make_abstraction_link("METHADONE_CLINIC", "Methadone Clinic", 13)



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if subtitle == alcohol_withdrawal_subtitle and #account_alcohol_codes > 0 then
        -- Auto resolve alert if it currently triggered for alcohol but now has alcohol codes
        local code = account_alcohol_codes[1]
        documented_dx_header:add_code_link(code, "Autoresolved Specified Code - " .. alcohol_code_dic[code])

        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true
    elseif subtitle == opioid_dependence_subtitle and #account_opioid_codes > 0 then
        -- Auto resolve alert if it currently triggered for opioids but now has opioid codes
        local code = account_opioid_codes[1]
        documented_dx_header:add_code_link(code, "Autoresolved Specified Code - " .. opioid_code_dic[code])

        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true
    elseif
        #account_alcohol_codes == 0 and
        (ciwa_score_dv_link or ciwa_score_abstraction_link or ciwa_protocol_abstraction_link)
    then
        -- Trigger alert if it has no alcohol code, but has a ciwa score dv of 10 or greater,
        -- or a ciwa score abstraction, or a ciwa protcol abstraction
        Result.subtitle = alcohol_withdrawal_subtitle
        Result.passed = true
    elseif
        #account_opioid_codes == 0 and
        (
            #methadone_medication_links > 0 or
            lists.some {
                methadone_abstraction_link, suboxone_medication_link, suboxone_abstraction_link,
                methadone_clinic_abstraction_link
            }
        )
    then
        -- Trigger alert if it has no opioid code, but has a methadone medication, or a methadone abstraction,
        -- or a suboxone medication, or a suboxone abstraction, or a methadone clinic abstraction
        Result.subtitle = opioid_dependence_subtitle
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Additional Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            clinical_evidence_header:add_code_one_of_link(
                {
                    "F10.20", "F10.21", "F10.220", "F10.221", "F10.229", "F10.24", "F10.250", "F10.251",
                    "F10.259", "F10.26", "F10.27", "F10.280", "F10.281", "F10.282", "F10.288", "F10.29"
                },
                "Alcohol Dependence"
            )
            local r4182_code_link = codes.make_code_link("R41.82", "Altered Level of Consciousness", 2)
            local altered_abs = codes.make_abstraction_link("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level of Consciousness", 3)
            if r4182_code_link then
                altered_abs.hidden = true
            end
            clinical_evidence_header:add_link(r4182_code_link)
            clinical_evidence_header:add_link(altered_abs)
            clinical_evidence_header:add_code_link("R44.8", "Auditory Hallucinations")

            clinical_evidence_header:add_link(ciwa_score_dv_link)
            clinical_evidence_header:add_link(ciwa_score_abstraction_link)
            clinical_evidence_header:add_link(ciwa_protocol_abstraction_link)

            clinical_evidence_header:add_abstraction_link("COMBATIVE", "Combative")
            clinical_evidence_header:add_abstraction_link("DELIRIUM", "Delirium")
            clinical_evidence_header:add_code_link("R44.3", "Hallucinations")
            clinical_evidence_header:add_code_link("R51.9", "Headache")
            clinical_evidence_header:add_code_link("R45.4", "Irritability and Anger")

            clinical_evidence_header:add_link(methadone_clinic_abstraction_link)

            clinical_evidence_header:add_code_link("R11.0", "Nausea")
            clinical_evidence_header:add_code_link("R45.0", "Nervousness")
            clinical_evidence_header:add_abstraction_link("ONE_TO_ONE_SUPERVISION", "One to One Supervision")
            clinical_evidence_header:add_code_link("R11.12", "Projectile Vomiting")
            clinical_evidence_header:add_code_link("R45.1", "Restlessness and Agitation")
            clinical_evidence_header:add_code_link("R61", "Sweating")
            clinical_evidence_header:add_code_link("R25.1", "Tremor")
            clinical_evidence_header:add_code_link("R44.1", "Visual Hallucinations")
            clinical_evidence_header:add_code_link("R11.10", "Vomiting")

            treatment_and_monitoring_header:add_medication_link(benzodiazepine_medication_name, "Benzodiazepine")
            treatment_and_monitoring_header:add_abstraction_link("BENZODIAZEPINE", "Benzodiazepine")
            treatment_and_monitoring_header:add_medication_link(dexmedetomidine_medication_name, "Dexmedetomidine")
            treatment_and_monitoring_header:add_abstraction_link("DEXMEDETOMIDINE", "Dexmedetomidine")
            treatment_and_monitoring_header:add_medication_link(lithium_medication_name, "Lithium")
            treatment_and_monitoring_header:add_abstraction_link("LITHIUM", "Lithium")

            treatment_and_monitoring_header:add_links(methadone_medication_links)

            treatment_and_monitoring_header:add_link(methadone_abstraction_link)

            treatment_and_monitoring_header:add_medication_link(propofol_medication_name, "Propofol")
            treatment_and_monitoring_header:add_abstraction_link("PROPOFOL", "Propofol")

            treatment_and_monitoring_header:add_link(suboxone_medication_link)
            treatment_and_monitoring_header:add_link(suboxone_abstraction_link)

            for _, doc_type in ipairs(pain_document_types) do
                pain_team_consult_header:add_document_link(doc_type, doc_type)
            end
        end



        --------------------------------------------------------------------------------
        --- Result Finalization
        --------------------------------------------------------------------------------
        compile_links()
    end
end
