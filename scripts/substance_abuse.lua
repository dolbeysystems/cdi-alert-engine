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
require("libs.common")



--------------------------------------------------------------------------------
--- Setup
--------------------------------------------------------------------------------
local existingAlert = GetExistingCdiAlert { scriptName = ScriptName, account = Account }



if not existingAlert or not existingAlert.validated then
    ----------------------------------------
    --- Alert Variables 
    ----------------------------------------
    local alcoholCodeDic = {
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

    local opioidCodeDic = {
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

    local accountAlcoholCodes = GetAccountCodesInDictionary(Account, alcoholCodeDic)
    local accountOpioidCodes = GetAccountCodesInDictionary(Account, opioidCodeDic)

    local opioidHeaderSubtitle = "Possible Opioid Dependence"
    local alcoholHeaderSubtitle = "Possible Alcohol Withdrawal"

    --------------------------------------------------------------------------------
    --- Alert Qualification 
    --------------------------------------------------------------------------------
    --- @type CdiAlertLink?
    local autoResolvedCodeLink = nil

    local ciwaScoreDvLink = GetDiscreteValueLinks {
        discreteValueName = "alcohol CIWA Calc score 1112",
        text = "CIWA Score",
        seq = 5,
        predicate = function(dv)
            return GetDvValueNumber(dv) >= 10
        end
    }
    local ciwaScoreAbstractionLink = GetAbstractionLinks { code = "CIWA_SCORE", text = "CIWA Score", seq = 6 }
    local ciwaProtocolAbstractionLink = GetAbstractionLinks { code = "CIWA_PROTOCOL", text = "CIWA Protocol", seq = 7 }
    local methadoneMedicationLinks = GetMedicationLinks {
        cat = "Methadone",
        text = "Methadone",
        seq = 9,
        useCdiAlertCategoryField = true,
        onePerDate = true,
        predicate = function(med)
            return DateIsLessThanXDaysAgo(med.start_date, 7)
        end
    }
    local methadoneAbstractionLink = GetAbstractionLinks { code = "METHADONE", text = "Methadone", seq = 8 }
    local suboxoneMedicationLink = GetMedicationLinks {
        cat = "Suboxone",
        text = "Suboxone",
        seq = 11,
        useCdiAlertCategoryField = true,
        onlyOne = true,
        predicate = function(med)
            return DateIsLessThanXDaysAgo(med.start_date, 7)
        end
    }
    local suboxoneAbstractionLink = GetAbstractionLinks { code = "SUBOXONE", text = "Suboxone", seq = 12 }
    local methadoneClinicAbstractionLink = GetAbstractionLinks { code = "METHADONE_CLINIC", text = "Methadone Clinic", seq = 13 }

    -- Auto resolve alert if it currently triggered for alcohol but now has alcohol codes
    if existingAlert and not existingAlert.validated and existingAlert.subtitle == alcoholHeaderSubtitle and #accountAlcoholCodes > 0 then
        local code = accountAlcoholCodes[1]
        local codeDesc = alcoholCodeDic[code]
        autoResolvedCodeLink = GetCodeLinks { code = code, text = "Autoresolved Specified Code - " .. codeDesc, seq = 1 }
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    -- Auto resolve alert if it currently triggered for opioids but now has opioid codes
    elseif existingAlert and not existingAlert.validated and existingAlert.subtitle == opioidHeaderSubtitle and #accountOpioidCodes > 0 then
        local code = accountOpioidCodes[1]
        local codeDesc = opioidCodeDic[code]
        autoResolvedCodeLink = GetCodeLinks { code = code, text = "Autoresolved Specified Code - " .. codeDesc, seq = 1 }
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    -- Trigger alert if it has no alcohol code, but has a ciwa score dv of 10 or greater, or a ciwa score abstraction, or a ciwa protcol abstraction
    elseif #accountAlcoholCodes == 0 and (ciwaScoreDvLink or ciwaScoreAbstractionLink or ciwaProtocolAbstractionLink) then
        Result.subtitle = alcoholHeaderSubtitle
        Result.passed = true

    -- Trigger alert if it has no opioid code, but has a methadone medication, or a methadone abstraction, or a suboxone medication, or a suboxone abstraction, or a methadone clinic abstraction
    elseif #accountOpioidCodes == 0 and (#methadoneMedicationLinks > 0 or methadoneAbstractionLink or suboxoneMedicationLink or suboxoneAbstractionLink or methadoneClinicAbstractionLink) then
        Result.subtitle = opioidHeaderSubtitle
        Result.passed = true

    -- Do nothing
    else
        Result.passed = false
    end



    --------------------------------------------------------------------------------
    --- Link Composition and Alert Finalization
    --------------------------------------------------------------------------------
    if Result.passed then
        local resultLinks = {}

        if existingAlert then
            local documentedDxHeader = MakeHeaderLink("Documented Dx")
            documentedDxHeader.links = { autoResolvedCodeLink }
            resultLinks = { documentedDxHeader }
        else
            local clinicalEvidenceHeader = MakeHeaderLink("Clinical Evidence")
            local clinicalEvidenceLinks = {}
            local treatmentAndMonitoringHeader = MakeHeaderLink("Treatment and Monitoring")
            local treatmentAndMonitoringLinks = {}
            local painTeamConsultHeader = MakeHeaderLink("Pain Team Consult")
            local painTeamConsultLinks = {}

            ----------------------------------------
            -- Clinical Evidence Links (Abstractions and Codes)
            ----------------------------------------
            GetCodeLinks {
                codes = {
                    "F10.20", "F10.21", "F10.220", "F10.221", "F10.229", "F10.24", "F10.250", "F10.251",
                    "F10.259", "F10.26", "F10.27", "F10.280", "F10.281", "F10.282", "F10.288", "F10.29"
                },
                text = "Alcohol Dependence",
                sequence = 1,
                target = clinicalEvidenceLinks,
            }
            local r4182CodeLink = GetCodeLinks { code = "R41.82", text = "Altered Level of Consciousness", seq = 2, target = clinicalEvidenceLinks }
            local alteredAbs = GetAbstractionLinks { code = "ALTERED_LEVEL_OF_CONSCIOUSNESS", text = "Altered Level of Consciousness", seq = 3, target = clinicalEvidenceLinks }
            if r4182CodeLink then
                alteredAbs.hidden = true
            end
            GetCodeLinks { code = "R44.8", text = "Auditory Hallucinations", seq = 4, target = clinicalEvidenceLinks }
            if ciwaScoreDvLink then
                table.insert(clinicalEvidenceLinks, ciwaScoreDvLink)
            end
            if ciwaScoreAbstractionLink then
                table.insert(clinicalEvidenceLinks, ciwaScoreAbstractionLink)
            end
            if ciwaProtocolAbstractionLink then
                table.insert(clinicalEvidenceLinks, ciwaProtocolAbstractionLink)
            end
            GetAbstractionLinks { code = "COMBATIVE", text = "Combative", seq = 8, target = clinicalEvidenceLinks }
            GetAbstractionLinks { code = "DELIRIUM", text = "Delirium", seq = 9, target = clinicalEvidenceLinks }
            GetCodeLinks { code = "R44.3", text = "Hallucinations", seq = 10, target = clinicalEvidenceLinks }
            GetCodeLinks { code = "R51.9", text = "Headache", seq = 11, target = clinicalEvidenceLinks }
            GetCodeLinks { code = "R45.4", text = "Irritability and Anger", seq = 12, target = clinicalEvidenceLinks }
            if methadoneClinicAbstractionLink then
                table.insert(clinicalEvidenceLinks, methadoneClinicAbstractionLink)
            end
            GetCodeLinks { code = "R11.0", text = "Nausea", seq = 14, target = clinicalEvidenceLinks }
            GetCodeLinks { code = "R45.0", text = "Nervousness", seq = 15, target = clinicalEvidenceLinks }
            GetAbstractionLinks { code = "ONE_TO_ONE_SUPERVISION", text = "One to One Supervision", seq = 16, target = clinicalEvidenceLinks }
            GetCodeLinks { code = "R11.12", text = "Projectile Vomiting", seq = 17, target = clinicalEvidenceLinks }
            GetCodeLinks { code = "R45.1", text = "Restlessness and Agitation", seq = 18, target = clinicalEvidenceLinks }
            GetCodeLinks { code = "R61", text = "Sweating", seq = 19, target = clinicalEvidenceLinks }
            GetCodeLinks { code = "R25.1", text = "Tremor", seq = 20, target = clinicalEvidenceLinks }
            GetCodeLinks { code = "R44.1", text = "Visual Hallucinations", seq = 21, target = clinicalEvidenceLinks }
            GetCodeLinks { code = "R11.10", text = "Vomiting", seq = 22, target = clinicalEvidenceLinks }

            ----------------------------------------
            -- Treatment and Monitoring Links (Medications and Abstractions)
            ----------------------------------------
            GetMedicationLinks { cat = "Benzodiazepine", text = "Suboxone", seq = 1, useCdiAlertCategoryField = true, onlyOne = true, target = treatmentAndMonitoringLinks }
            GetAbstractionLinks { code = "BENZODIAZEPINE", text = "Benzodiazepine", seq = 2, target = treatmentAndMonitoringLinks }
            GetMedicationLinks { cat = "Dexmedetomidine", text = "Dexmedetomidine", seq = 3, useCdiAlertCategoryField = true, onlyOne = true, target = treatmentAndMonitoringLinks }
            GetAbstractionLinks { code = "DEXMEDETOMIDINE", text = "Dexmedetomidine", seq = 4, target = treatmentAndMonitoringLinks }
            GetMedicationLinks { cat = "Lithium", text = "Lithium", seq = 5, useCdiAlertCategoryField = true, onlyOne = true, target = treatmentAndMonitoringLinks }
            GetAbstractionLinks { code = "LITHIUM", text = "Lithium", seq = 6, target = treatmentAndMonitoringLinks }
            if methadoneMedicationLinks and #methadoneMedicationLinks > 0 then
                for _, link in ipairs(methadoneMedicationLinks) do
                    table.insert(treatmentAndMonitoringLinks, link)
                end
            end
            if methadoneAbstractionLink then
                table.insert(treatmentAndMonitoringLinks, methadoneAbstractionLink)
            end
            GetMedicationLinks { cat = "Propofol", text = "Propofol", seq = 10, useCdiAlertCategoryField = true, onlyOne = true, target = treatmentAndMonitoringLinks }
            GetAbstractionLinks { code = "PROPOFOL", text = "Propofol", seq = 11, target = treatmentAndMonitoringLinks }
            if suboxoneMedicationLink then
                table.insert(treatmentAndMonitoringLinks, suboxoneMedicationLink)
            end
            if suboxoneAbstractionLink then
                table.insert(treatmentAndMonitoringLinks, suboxoneAbstractionLink)
            end

            ----------------------------------------
            -- Pain Team Consultation Links (Document links)
            ----------------------------------------
            GetDocumentLinks { documentType = "Pain Team Consultation Note", text = "Pain Team Consultation Note", seq = 1, target = painTeamConsultLinks }
            GetDocumentLinks { documentType = "zzPain Team Consultation Note", text = "zzPain Team Consultation Note", seq = 2, target = painTeamConsultLinks }
            GetDocumentLinks { documentType = "Pain Team Progress Note", text = "Pain Team Progress Note", seq = 3, target = painTeamConsultLinks }

            clinicalEvidenceHeader.links = clinicalEvidenceLinks
            treatmentAndMonitoringHeader.links = treatmentAndMonitoringLinks
            painTeamConsultHeader.links = painTeamConsultLinks

            resultLinks = { clinicalEvidenceHeader, treatmentAndMonitoringHeader, painTeamConsultHeader }
        end

        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        if existingAlert then
            resultLinks = MergeLinks(existingAlert.links, resultLinks)
        end
        Result.links = resultLinks
        Result.passed = true
    end
end

