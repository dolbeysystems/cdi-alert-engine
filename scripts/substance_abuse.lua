---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Substance Abuse
--- 
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
---
--- This script checks an account to see if it matches the criteria for a substance abuse alert.
---
--- Alerts:
---     - Possible Alcohol Withdrawal: 
---         Triggered if the account has no alcohol codes, but has a CIWA score DV of 10 or greater, 
---         or a CIWA score abstraction, or a CIWA protocol abstraction.
--- 
---         Autoresolved if the account gets an alcohol code.
--- 
---    - Possible Opioid Dependence:
---         Triggered if the account has no opioid codes, but has a methadone medication, or a methadone abstraction,
---         or a suboxone medication, or a suboxone abstraction, or a methadone clinic abstraction.
--- 
---         Autoresolved if the account gets an opioid code.
--- 
--- Possible Links:
---     - Documented Dx (Only if auto-resolved):
---         - Autoresolved Specified Code (Code)
---     - Clinical Evidence:
---         - Alcohol Dependence (Code)
---         - Altered Level of Consciousness (Code)
---         - Altered Level of Consciousness (Abstraction)
---         - Auditory Hallucinations (Code)
---         - CIWA Score (Discrete Value)
---         - CIWA Score (Abstraction)
---         - CIWA Protocol (Abstraction)
---         - Combative (Abstraction)
---         - Delirium (Abstraction)
---         - Hallucinations (Code)
---         - Headache (Code)
---         - Irritability and Anger (Code)
---         - Methadone Clinic (Abstraction)
---         - Nausea (Code)
---         - Nervousness (Code)
---         - One to One Supervision (Abstraction)
---         - Projectile Vomiting (Code)
---         - Restlessness and Agitation (Code)
---         - Sweating (Code)
---         - Tremor (Code)
---         - Visual Hallucinations (Code)
---         - Vomiting (Code)
---    - Treatment and Monitoring:
---         - Benzodiazepine (Medication)
---         - Benzodiazepine (Abstraction)
---         - Dexmedetomidine (Medication)
---         - Dexmedetomidine (Abstraction)
---         - Lithium (Medication)
---         - Lithium (Abstraction)
---         - Methadone (Medication) [Multiple]
---         - Methadone (Abstraction)
---         - Propofol (Medication)
---         - Propofol (Abstraction)
---         - Suboxone (Medication)
---         - Suboxone (Abstraction)
---    - Pain Team Consult:
---         - Pain Team Consultation Note
---         - zzPain Team Consultation Note
---         - Pain Team Progress Note
---         
---------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Requires 
--------------------------------------------------------------------------------
require("libs.common")



--------------------------------------------------------------------------------
--- Setup
-------------------------------------------------------------------------------- 
-- Site variables
local ciwa_score_dv_name = "alcohol CIWA Calc score 1112"
local ciwa_score_dv_predicate = function(dv) return GetDvValueNumber(dv) > 9 end
local methadone_medication_name = "Methadone"
local suboxone_medication_name = "Suboxone"
local benzodiazepine_medication_name = "Benzodiazepine"
local dexmedetomidine_medication_name = "Dexmedetomidine"
local lithium_medication_name = "Lithium"
local propofol_medication_name = "Propofol"
local pain_document_types = { "Pain Team Consultation Note", "zzPain Team Consultation Note", "Pain Team Progress Note" }
local opioid_dependence_subtitle = "Possible Opioid Dependence"
local alcohol_withdrawal_subtitle = "Possible Alcohol Withdrawal"

-- Get the existing alert and its subtitle (if any)
local existing_alert = GetExistingCdiAlert { scriptName = ScriptName, account = Account }
local subtitle = existing_alert and existing_alert.subtitle or nil



if not existing_alert or not existing_alert.validated then
    --------------------------------------------------------------------------------
    --- Top-Level Link Header Variables
    --------------------------------------------------------------------------------
    local result_links = {}
    local documented_dx_header = MakeHeaderLink("Documented Dx")
    local documented_dx_links = {}
    local clinical_evidence_header = MakeHeaderLink("Clinical Evidence")
    local clinical_evidence_links = {}
    local treatment_and_monitoring_header = MakeHeaderLink("Treatment and Monitoring")
    local treatment_and_monitoring_links = {}
    local pain_team_consult_header = MakeHeaderLink("Pain Team Consult")
    local pain_team_consult_links = {}



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
    local account_alcohol_codes = GetAccountCodesInDictionary(Account, alcohol_code_dic)
    local account_opioid_codes = GetAccountCodesInDictionary(Account, opioid_code_dic)



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    local ciwa_score_dv_link = GetDiscreteValueLinks {
        discreteValueName = ciwa_score_dv_name,
        text = "CIWA Score",
        seq = 5,
        predicate = ciwa_score_dv_predicate
    }
    local ciwa_score_abstraction_link = GetAbstractionValueLink { code = "CIWA_SCORE", text = "CIWA Score", seq = 6 }
    local ciwa_protocol_abstraction_link = GetAbstractionValueLink { code = "CIWA_PROTOCOL", text = "CIWA Protocol", seq = 7 }
    local methadone_medication_links = GetMedicationLinks {
        cat = methadone_medication_name,
        text = "Methadone",
        seq = 9,
        useCdiAlertCategoryField = true,
        onePerDate = true,
        maxPerValue = 9999,
    } or {}
    local methadone_abstraction_link = GetAbstractionValueLink { code = "METHADONE", text = "Methadone", seq = 8 }
    local suboxone_medication_link = GetMedicationLink {
        cat = suboxone_medication_name,
        text = "Suboxone",
        seq = 11,
        useCdiAlertCategoryField = true,
        onlyOne = true,
    }
    local suboxone_abstraction_link = GetAbstractionValueLink { code = "SUBOXONE", text = "Suboxone", seq = 12 }
    local methadone_clinic_abstraction_link = GetAbstractionLink { code = "METHADONE_CLINIC", text = "Methadone Clinic", seq = 13 }



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    -- Auto resolve alert if it currently triggered for alcohol but now has alcohol codes
    if subtitle == alcohol_withdrawal_subtitle and #account_alcohol_codes > 0 then
        local code = account_alcohol_codes[1]
        local code_desc = alcohol_code_dic[code]
        local auto_resolved_code_link = GetCodeLinks { code = code, text = "Autoresolved Specified Code - " .. code_desc, seq = 1 }
        table.insert(documented_dx_links, auto_resolved_code_link)

        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif subtitle == opioid_dependence_subtitle and #account_opioid_codes > 0 then
        -- Auto resolve alert if it currently triggered for opioids but now has opioid codes
        local code = account_opioid_codes[1]
        local code_desc = opioid_code_dic[code]
        local auto_resolved_code_link = GetCodeLinks { code = code, text = "Autoresolved Specified Code - " .. code_desc, seq = 1 }
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
        --- Additional Link Collection (Get___Links with target table)
        --------------------------------------------------------------------------------
        if not Result.validated then
            GetCodeLink {
                codes = {
                    "F10.20", "F10.21", "F10.220", "F10.221", "F10.229", "F10.24", "F10.250", "F10.251",
                    "F10.259", "F10.26", "F10.27", "F10.280", "F10.281", "F10.282", "F10.288", "F10.29"
                },
                text = "Alcohol Dependence",
                sequence = 1,
                target = clinical_evidence_links,
            }
            local r4182_code_link = GetCodeLink { code = "R41.82", text = "Altered Level of Consciousness", seq = 2, target = clinical_evidence_links }
            local altered_abs = GetAbstractionLink { code = "ALTERED_LEVEL_OF_CONSCIOUSNESS", text = "Altered Level of Consciousness", seq = 3, target = clinical_evidence_links }
            if r4182_code_link then
                altered_abs.hidden = true
            end
            GetCodeLinks { code = "R44.8", text = "Auditory Hallucinations", seq = 4, target = clinical_evidence_links }

            table.insert(clinical_evidence_links, ciwa_score_dv_link)
            table.insert(clinical_evidence_links, ciwa_score_abstraction_link)
            table.insert(clinical_evidence_links, ciwa_protocol_abstraction_link)

            GetAbstractionLinks { code = "COMBATIVE", text = "Combative", seq = 8, target = clinical_evidence_links }
            GetAbstractionLinks { code = "DELIRIUM", text = "Delirium", seq = 9, target = clinical_evidence_links }
            GetCodeLinks { code = "R44.3", text = "Hallucinations", seq = 10, target = clinical_evidence_links }
            GetCodeLinks { code = "R51.9", text = "Headache", seq = 11, target = clinical_evidence_links }
            GetCodeLinks { code = "R45.4", text = "Irritability and Anger", seq = 12, target = clinical_evidence_links }

            table.insert(clinical_evidence_links, methadone_clinic_abstraction_link)

            GetCodeLinks { code = "R11.0", text = "Nausea", seq = 14, target = clinical_evidence_links }
            GetCodeLinks { code = "R45.0", text = "Nervousness", seq = 15, target = clinical_evidence_links }
            GetAbstractionLinks { code = "ONE_TO_ONE_SUPERVISION", text = "One to One Supervision", seq = 16, target = clinical_evidence_links }
            GetCodeLinks { code = "R11.12", text = "Projectile Vomiting", seq = 17, target = clinical_evidence_links }
            GetCodeLinks { code = "R45.1", text = "Restlessness and Agitation", seq = 18, target = clinical_evidence_links }
            GetCodeLinks { code = "R61", text = "Sweating", seq = 19, target = clinical_evidence_links }
            GetCodeLinks { code = "R25.1", text = "Tremor", seq = 20, target = clinical_evidence_links }
            GetCodeLinks { code = "R44.1", text = "Visual Hallucinations", seq = 21, target = clinical_evidence_links }
            GetCodeLinks { code = "R11.10", text = "Vomiting", seq = 22, target = clinical_evidence_links }

            GetMedicationLinks { cat = benzodiazepine_medication_name, text = "Benzodiazepine", seq = 1, useCdiAlertCategoryField = true, onlyOne = true, target = treatment_and_monitoring_links }
            GetAbstractionLinks { code = "BENZODIAZEPINE", text = "Benzodiazepine", seq = 2, target = treatment_and_monitoring_links }
            GetMedicationLinks { cat = dexmedetomidine_medication_name, text = "Dexmedetomidine", seq = 3, useCdiAlertCategoryField = true, onlyOne = true, target = treatment_and_monitoring_links }
            GetAbstractionLinks { code = "DEXMEDETOMIDINE", text = "Dexmedetomidine", seq = 4, target = treatment_and_monitoring_links }
            GetMedicationLinks { cat = lithium_medication_name, text = "Lithium", seq = 5, useCdiAlertCategoryField = true, onlyOne = true, target = treatment_and_monitoring_links }
            GetAbstractionLinks { code = "LITHIUM", text = "Lithium", seq = 6, target = treatment_and_monitoring_links }
            for _, link in ipairs(methadone_medication_links) do
                table.insert(treatment_and_monitoring_links, link)
            end

            table.insert(treatment_and_monitoring_links, methadone_abstraction_link)

            GetMedicationLinks { cat = propofol_medication_name, text = "Propofol", seq = 10, useCdiAlertCategoryField = true, onlyOne = true, target = treatment_and_monitoring_links }
            GetAbstractionLinks { code = "PROPOFOL", text = "Propofol", seq = 11, target = treatment_and_monitoring_links }

            table.insert(treatment_and_monitoring_links, suboxone_medication_link)
            table.insert(treatment_and_monitoring_links, suboxone_abstraction_link)

            for i, doc_type in ipairs(pain_document_types) do
                GetDocumentLinks { documentType = doc_type, text = doc_type, seq = i, target = pain_team_consult_links }
            end
        end



        --------------------------------------------------------------------------------
        --- Result Finalization 
        --------------------------------------------------------------------------------
        -- Build the link heirarchy
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
            result_links = MergeLinks(existing_alert.links, result_links)
        end
        Result.links = result_links
    end
end

