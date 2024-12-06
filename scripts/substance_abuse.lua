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
local alerts = require("libs.common.alerts")
local links = require("libs.common.basic_links")
local codes = require("libs.common.codes")
local discrete = require("libs.common.discrete_values")



--------------------------------------------------------------------------------
--- Setup
-------------------------------------------------------------------------------- 
local ciwa_score_dv_name = "alcohol CIWA Calc score 1112"
local ciwa_score_dv_predicate = function(dv) return discrete.get_dv_value_number(dv) > 9 end
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
    local documented_dx_header = links.make_header_link("Documented Dx")
    local documented_dx_links = {}
    local clinical_evidence_header = links.make_header_link("Clinical Evidence")
    local clinical_evidence_links = {}
    local treatment_and_monitoring_header = links.make_header_link("Treatment and Monitoring")
    local treatment_and_monitoring_links = {}
    local pain_team_consult_header = links.make_header_link("Pain Team Consult")
    local pain_team_consult_links = {}
    --- @param link CdiAlertLink?
    local function add_clinical_evidence_link(link)
        table.insert(clinical_evidence_links, link)
    end
    --- @param code string
    --- @param text string
    local function add_clinical_evidence_code(code, text)
        add_clinical_evidence_link(links.get_code_link { code = code, text = text })
    end
    --- @param prefix string
    --- @param text string
    local function add_clinical_evidence_code_prefix(prefix, text)
        add_clinical_evidence_link(codes.get_code_prefix_link { prefix = prefix, text = text })
    end
    --- @param code_set string[]
    --- @param text string
    local function add_clinical_evidence_any_code(code_set, text)
        add_clinical_evidence_link(links.get_code_link { codes = code_set, text = text })
    end
    --- @param code string
    --- @param text string
    local function add_clinical_evidence_abstraction(code, text)
        add_clinical_evidence_link(links.get_abstraction_link { code = code, text = text })
    end
    local function compile_links()
        if #documented_dx_links > 0 then
            documented_dx_header.links = documented_dx_links
            table.insert(result_links, documented_dx_header)
        end
        if #clinical_evidence_links > 0 then
            clinical_evidence_header.links = clinical_evidence_links
            table.insert(result_links, clinical_evidence_header)
        end
        if #treatment_and_monitoring_links > 0 then
            treatment_and_monitoring_header.links = treatment_and_monitoring_links
            table.insert(result_links, treatment_and_monitoring_header)
        end
        if #pain_team_consult_links > 0 then
            pain_team_consult_header.links = pain_team_consult_links
            table.insert(result_links, pain_team_consult_header)
        end

        -- Merge links if we need to
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
    local ciwa_score_dv_link = links.get_discrete_value_links {
        discreteValueName = ciwa_score_dv_name,
        text = "CIWA Score",
        seq = 5,
        predicate = ciwa_score_dv_predicate
    }
    local ciwa_score_abstraction_link = links.get_abstraction_value_link { code = "CIWA_SCORE", text = "CIWA Score", seq = 6 }
    local ciwa_protocol_abstraction_link = links.get_abstraction_value_link { code = "CIWA_PROTOCOL", text = "CIWA Protocol", seq = 7 }
    local methadone_medication_links = links.get_medication_links {
        cat = methadone_medication_name,
        text = "Methadone",
        seq = 9,
        useCdiAlertCategoryField = true,
        onePerDate = true,
        maxPerValue = 9999,
    } or {}
    local methadone_abstraction_link = links.get_abstraction_value_link { code = "METHADONE", text = "Methadone", seq = 8 }
    local suboxone_medication_link = links.get_medication_link {
        cat = suboxone_medication_name,
        text = "Suboxone",
        seq = 11,
        useCdiAlertCategoryField = true,
        onlyOne = true,
    }
    local suboxone_abstraction_link = links.get_abstraction_value_link { code = "SUBOXONE", text = "Suboxone", seq = 12 }
    local methadone_clinic_abstraction_link = links.get_abstraction_link { code = "METHADONE_CLINIC", text = "Methadone Clinic", seq = 13 }



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if subtitle == alcohol_withdrawal_subtitle and #account_alcohol_codes > 0 then
        -- Auto resolve alert if it currently triggered for alcohol but now has alcohol codes
        local code = account_alcohol_codes[1]
        local code_desc = alcohol_code_dic[code]
        local auto_resolved_code_link = links.get_code_links { code = code, text = "Autoresolved Specified Code - " .. code_desc, seq = 1 }
        table.insert(documented_dx_links, auto_resolved_code_link)

        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif subtitle == opioid_dependence_subtitle and #account_opioid_codes > 0 then
        -- Auto resolve alert if it currently triggered for opioids but now has opioid codes
        local code = account_opioid_codes[1]
        local code_desc = opioid_code_dic[code]
        local auto_resolved_code_link = links.get_code_links { code = code, text = "Autoresolved Specified Code - " .. code_desc, seq = 1 }
        table.insert(documented_dx_links, auto_resolved_code_link)

        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif #account_alcohol_codes == 0 and (ciwa_score_dv_link or ciwa_score_abstraction_link or ciwa_protocol_abstraction_link) then
        -- Trigger alert if it has no alcohol code, but has a ciwa score dv of 10 or greater, or a ciwa score abstraction, or a ciwa protcol abstraction
        Result.subtitle = alcohol_withdrawal_subtitle
        Result.passed = true

    elseif #account_opioid_codes == 0 and (#methadone_medication_links > 0 or methadone_abstraction_link or suboxone_medication_link or suboxone_abstraction_link or methadone_clinic_abstraction_link) then
        -- Trigger alert if it has no opioid code, but has a methadone medication, or a methadone abstraction, or a suboxone medication, or a suboxone abstraction, or a methadone clinic abstraction
        Result.subtitle = opioid_dependence_subtitle
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Additional Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            table.insert(
                clinical_evidence_links,
                links.get_code_link {
                    codes = {
                        "F10.20", "F10.21", "F10.220", "F10.221", "F10.229", "F10.24", "F10.250", "F10.251",
                        "F10.259", "F10.26", "F10.27", "F10.280", "F10.281", "F10.282", "F10.288", "F10.29"
                    },
                    text = "Alcohol Dependence",
                    sequence = 1,
                }
            )
            local r4182_code_link = links.get_code_link { code = "R41.82", text = "Altered Level of Consciousness", seq = 2 }
            local altered_abs = links.get_abstraction_link { code = "ALTERED_LEVEL_OF_CONSCIOUSNESS", text = "Altered Level of Consciousness", seq = 3 }
            if r4182_code_link then
                altered_abs.hidden = true
            end
            table.insert(clinical_evidence_links, r4182_code_link)
            table.insert(clinical_evidence_links, altered_abs)

            table.insert(clinical_evidence_links, links.get_code_links { code = "R44.8", text = "Auditory Hallucinations", seq = 4 })

            table.insert(clinical_evidence_links, ciwa_score_dv_link)
            table.insert(clinical_evidence_links, ciwa_score_abstraction_link)
            table.insert(clinical_evidence_links, ciwa_protocol_abstraction_link)

            table.insert(clinical_evidence_links, links.get_abstraction_links { code = "COMBATIVE", text = "Combative", seq = 8 })
            table.insert(clinical_evidence_links, links.get_abstraction_links { code = "DELIRIUM", text = "Delirium", seq = 9 })
            table.insert(clinical_evidence_links, links.get_code_links { code = "R44.3", text = "Hallucinations", seq = 10 })
            table.insert(clinical_evidence_links, links.get_code_links { code = "R51.9", text = "Headache", seq = 11 })
            table.insert(clinical_evidence_links, links.get_code_links { code = "R45.4", text = "Irritability and Anger", seq = 12 })

            table.insert(clinical_evidence_links, methadone_clinic_abstraction_link)

            table.insert(clinical_evidence_links, links.get_code_links { code = "R11.0", text = "Nausea", seq = 14 })
            table.insert(clinical_evidence_links, links.get_code_links { code = "R45.0", text = "Nervousness", seq = 15 })
            table.insert(clinical_evidence_links, links.get_abstraction_links { code = "ONE_TO_ONE_SUPERVISION", text = "One to One Supervision", seq = 16 })
            table.insert(clinical_evidence_links, links.get_code_links { code = "R11.12", text = "Projectile Vomiting", seq = 17 })
            table.insert(clinical_evidence_links, links.get_code_links { code = "R45.1", text = "Restlessness and Agitation", seq = 18 })
            table.insert(clinical_evidence_links, links.get_code_links { code = "R61", text = "Sweating", seq = 19 })
            table.insert(clinical_evidence_links, links.get_code_links { code = "R25.1", text = "Tremor", seq = 20 })
            table.insert(clinical_evidence_links, links.get_code_links { code = "R44.1", text = "Visual Hallucinations", seq = 21 })
            table.insert(clinical_evidence_links, links.get_code_links { code = "R11.10", text = "Vomiting", seq = 22 })

            table.insert(treatment_and_monitoring_links, links.get_medication_links { cat = benzodiazepine_medication_name, text = "Benzodiazepine", seq = 1, useCdiAlertCategoryField = true, onlyOne = true })
            table.insert(treatment_and_monitoring_links, links.get_abstraction_links { code = "BENZODIAZEPINE", text = "Benzodiazepine", seq = 2 })
            table.insert(treatment_and_monitoring_links, links.get_medication_links { cat = dexmedetomidine_medication_name, text = "Dexmedetomidine", seq = 3, useCdiAlertCategoryField = true, onlyOne = true })
            table.insert(treatment_and_monitoring_links, links.get_abstraction_links { code = "DEXMEDETOMIDINE", text = "Dexmedetomidine", seq = 4 })
            table.insert(treatment_and_monitoring_links, links.get_medication_links { cat = lithium_medication_name, text = "Lithium", seq = 5, useCdiAlertCategoryField = true, onlyOne = true })
            table.insert(treatment_and_monitoring_links, links.get_abstraction_links { code = "LITHIUM", text = "Lithium", seq = 6 })
            for _, link in ipairs(methadone_medication_links) do
                table.insert(treatment_and_monitoring_links, link)
            end

            table.insert(treatment_and_monitoring_links, methadone_abstraction_link)

            table.insert(treatment_and_monitoring_links, links.get_medication_links { cat = propofol_medication_name, text = "Propofol", seq = 10, useCdiAlertCategoryField = true, onlyOne = true })
            table.insert(treatment_and_monitoring_links, links.get_abstraction_links { code = "PROPOFOL", text = "Propofol", seq = 11 })

            table.insert(treatment_and_monitoring_links, suboxone_medication_link)
            table.insert(treatment_and_monitoring_links, suboxone_abstraction_link)

            for i, doc_type in ipairs(pain_document_types) do
                table.insert(pain_team_consult_links, links.get_document_links { documentType = doc_type, text = doc_type, seq = i })
            end
        end



        --------------------------------------------------------------------------------
        --- Result Finalization 
        --------------------------------------------------------------------------------
        compile_links()
    end
end

