---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Functional Quadriplegia
---
--- This script checks an account to see if it matches the criteria for a Functional Quadriplegia alert.
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
local dv_braden_risk_assessment_score = { "3.5 Activity (Braden Scale)" }
local calc_braden_risk_assessment_score1 = function(_dv, num) return num < 2 end
local dv_braden_mobility_score = { "3.5 Mobility" }
local calc_braden_mobility_score1 = function(_dv, num) return num < 2 end


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
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 5)
    local illness_header = headers.make_header_builder("Supporting Illness Dx", 3)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 6)

    local function compile_links()
        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, illness_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Alert Trigger
    local r532_code = links.get_code_link { code = "R53.2", text = "Functional Quadriplegia Dx" }
    local spinal_codes = links.get_code_link {
        codes = { "G82.20", "G82.21", "G82.22", "G82.50", "G82.51", "G82.52", "G82.53", "G82.54" },
        text = "Spinal Cord Injury Dx"
    }
    -- Abs
    local assistance_adls_abs = links.get_abstraction_link {
        code = "ASSISTANCE_WITH_ADLS",
        text = "Assistance with ADLS"
    }
    local z741_code = links.get_code_link { code = "Z74.1", text = "Assistance with Personal Care" }
    local z7401_code = links.get_code_link { code = "Z74.01", text = "Bed Bound" }
    local braden_risk_assessment_score_abs = links.get_abstraction_link {
        code = "BRADEN_RISK_ASSESSMENT_SCORE_FUNCTIONAL_QUADRIPLEGIA",
        text = "Braden Risk Assessment Score"
    }
    local braden_risk_assessment_score_dv = links.get_discrete_value_link {
        discreteValueNames = dv_braden_risk_assessment_score,
        text = "Braden Scale Activity Score"
    }
    local braden_risk_mobility_dv = links.get_discrete_value_link {
        discreteValueNames = dv_braden_mobility_score,
        text = "Braden Scale Mobility Score"
    }
    local complete_assistance_adls_abs = links.get_abstraction_link {
        code = "COMPLETE_ASSISTANCE_WITH_ADLS",
        text = "Complete Assistance with ADLs"
    }
    local debilitated_abs = links.get_abstraction_link {
        code = "DEBILITATED",
        text = "Debilitated"
    }
    local extremities_abs = links.get_abstraction_link {
        code = "MOVES_ALL_EXTREMITIES",
        text = "Extremities"
    }
    local flaccid_limbs_abs = links.get_abstraction_link {
        code = "FLACCID_LIMBS",
        text = "Flaccid Limbs"
    }
    local foot_drop_codes = links.get_code_link {
        codes = { "M21.371", "M21.372", "M21.379" },
        text = "Foot Drop"
    }
    local muscle_contracture_abs = links.get_abstraction_link {
        code = "MUSCLE_CONTRACTURE",
        text = "Muscle Contracture"
    }
    local sacral_decubitus_codes = links.get_code_link {
        codes = { "L89.153", "L89.154" },
        text = "Sacral Decubitus Ulcer"
    }
    local severe_weakness_abs = links.get_abstraction_link {
        code = "SEVERE_WEAKNESS",
        text = "Severe Weakness"
    }
    local spastic_hemiplegia = links.get_code_link {
        codes = { "G81.10", "G81.11", "G81.12", "G81.13", "G81.14" },
        text = "Spastic Hemiplegia"
    }
    local z930_code = links.get_code_link { code = "Z93.0", text = "Trach Dependent" }
    local transfer_with_a_lift_abs = links.get_abstraction_link {
        code = "TRANSFER_WITH_A_LIFT",
        text = "Transfer With A Lift"
    }
    local z9911_code = links.get_code_link { code = "Z99.11", text = "Ventilator Dependent" }
    local wrist_drop_codes = links.get_code_link {
        codes = { "M21.331", "M21.332", "M21.339" },
        text = "Wrist Drop"
    }

    -- Illness
    local g301_code = links.get_code_link { code = "G30.1", text = "Alzheimers Disease with Late Onset" }
    local g1221_code = links.get_code_link { code = "G12.21", text = "Amyotrophic Latertal Sclerosis" }
    local g804_code = links.get_code_link { code = "G80.4", text = "Ataxic Cerebral Palsy" }
    local g803_code = links.get_code_link { code = "G80.3", text = "Athetoid Cerebral Palsy" }
    local g71031_code = links.get_code_link {
        code = "G71.031",
        text = "Autosomal Dominant Limb Girdle Muscular Dystrophy"
    }
    local g71032_code = links.get_code_link {
        code = "G71.032",
        text = "Autosomal recessive limb girdle muscular dystrophy due to calpain-3 dysfunction"
    }
    local g809_code = links.get_code_link { code = "G80.9", text = "Cerebral Palsy, Unspecified" }
    local g7101_code = links.get_code_link { code = "G71.01", text = "Duchenne or Becker Muscular Dystrophy" }
    local g7102_code = links.get_code_link { code = "G71.02", text = "Facioscapulohumeral Muscular Dystrophy" }
    local guillain_barre_syndrome_abs = links.get_abstraction_link {
        code = "GUILLAIN_BARRE_SYNDROME",
        text = "Guillain-Barre Syndrome"
    }
    local g10_code = links.get_code_link { code = "G10", text = "Huntingtons Disease" }
    local g71035_code = links.get_code_link {
        code = "G71.035",
        text = "Limb Girdle Muscular Dystrophy due to Anoctamin-5 Dysfunction Muscular Dystrophy"
    }
    local g71033_code = links.get_code_link {
        code = "G71.033",
        text = "Limb Girdle Muscular Dystrophy due to Dysferlin Dysfunction"
    }
    local g71034_code = links.get_code_link {
        code = "G71.034",
        text = "Limb Girdle Muscular Dystrophy due to Sarcoglycan Dysfunction"
    }
    local g71039_code = links.get_code_link {
        code = "G71.039",
        text = "Limb Girdle Muscular Dystrophy, Unspecified"
    }
    local g35_code = links.get_code_link { code = "G35", text = "Multiple Sclerosis" }
    local g7100_code = links.get_code_link { code = "G71.00", text = "Muscular Dystrophy Unspecified" }
    local myasthenia_gravis_codes = codes.get_multi_code_link {
        codes = { "G70.00", "G70.01" },
        text = "Myasthenia Gravis"
    }
    local g808_code = links.get_code_link { code = "G80.8", text = "Other Cerebral Palsy" }
    local g20_code = links.get_code_link { code = "G20", text = "Parkinson's" }
    local g20a1_code = links.get_code_link {
        code = "G20.A1",
        text = "Parkinson's Disease without Dyskinesia, without Mention of Fluctuations"
    }
    local g20a2_code = links.get_code_link {
        code = "G20.A2",
        text = "Parkinson's Disease without Dyskinesia, with Fluctuations"
    }
    local g20b1_code = links.get_code_link {
        code = "G20.B1",
        text = "Parkinson's Disease with Dyskinesia, without Mention of Fluctuations"
    }
    local g20b2_code = links.get_code_link {
        code = "G20.B2",
        text = "Parkinson's Disease with Dyskinesia, with Fluctuations"
    }
    local g20c_code = links.get_code_link { code = "G20.C", text = "Parkinsonism, Unspecified" }
    local g801_code = links.get_code_link { code = "G80.1", text = "Spastic Diplegic Cerebral Palsy" }
    local g802_code = links.get_code_link { code = "G80.2", text = "Spastic Hemiplegic Cerebral Palsy" }
    local g800_code = links.get_code_link { code = "G80.0", text = "Spastic Quadriplegic Cerebral Palsy" }
    local z8673_code = links.get_code_link { code = "Z86.73", text = "Stroke" }
    local f03_c11_code = links.get_code_link {
        code = "F03.C11",
        text = "Unspecified Dementia, Severe, with Agitation"
    }
    local f03_c4_code = links.get_code_link {
        code = "F03.C4",
        text = "Unspecified Dementia, Severe, with Anxiety"
    }
    local f03_c1_code = links.get_code_link {
        code = "F03.C1",
        text = "Unspecified Dementia, Severe, with Behavioral Disturbance"
    }
    local f03_c0_code = links.get_code_link {
        code = "F03.C0",
        text = "Unspecified Dementia, Severe, without Behavioral Disturbance, Psychotic Disturbance, Mood Disturbance, and Anxiety"
    }
    local f03_c3_code = links.get_code_link {
        code = "F03.C3",
        text = "Unspecified Dementia, Severe, with Mood Disturbance"
    }
    local f03_c18_code = links.get_code_link {
        code = "F03.C18",
        text = "Unspecified Dementia, Severe, with Other Behavioral Disturbance"
    }
    local f03_c2_code = links.get_code_link {
        code = "F03.C2",
        text = "Unspecified Dementia, Severe, with Psychotic Disturbance"
    }

    -- Abstracting Clinical Indicators
    clinical_evidence_header:add_link(assistance_adls_abs)
    clinical_evidence_header:add_link(z741_code)
    clinical_evidence_header:add_link(muscle_contracture_abs)
    clinical_evidence_header:add_link(spastic_hemiplegia)
    clinical_evidence_header:add_link(transfer_with_a_lift_abs)
    clinical_evidence_header:add_link(flaccid_limbs_abs)
    clinical_evidence_header:add_link(debilitated_abs)
    if braden_risk_assessment_score_dv then
        clinical_evidence_header:add_link(braden_risk_assessment_score_dv)
        clinical_evidence_header:add_link(braden_risk_assessment_score_abs)
    end
    clinical_evidence_header:add_link(braden_risk_mobility_dv)
    clinical_evidence_header:add_link(complete_assistance_adls_abs)
    clinical_evidence_header:add_link(severe_weakness_abs)
    clinical_evidence_header:add_link(foot_drop_codes)
    clinical_evidence_header:add_link(sacral_decubitus_codes)
    clinical_evidence_header:add_link(z930_code)
    clinical_evidence_header:add_link(z9911_code)
    clinical_evidence_header:add_link(wrist_drop_codes)
    local ci = #clinical_evidence_header.links

    -- Abstracting Disease Codes
    illness_header:add_link(g800_code)
    illness_header:add_link(g801_code)
    illness_header:add_link(g802_code)
    illness_header:add_link(g803_code)
    illness_header:add_link(g804_code)
    illness_header:add_link(g808_code)
    illness_header:add_link(g809_code)
    illness_header:add_link(g35_code)
    illness_header:add_link(g20_code)
    illness_header:add_link(g20a1_code)
    illness_header:add_link(g20a2_code)
    illness_header:add_link(g20b1_code)
    illness_header:add_link(g20b2_code)
    illness_header:add_link(g20c_code)
    illness_header:add_link(g1221_code)
    illness_header:add_link(g7100_code)
    illness_header:add_link(g7101_code)
    illness_header:add_link(g7102_code)
    illness_header:add_link(g71031_code)
    illness_header:add_link(g71032_code)
    illness_header:add_link(g71033_code)
    illness_header:add_link(g71034_code)
    illness_header:add_link(g71035_code)
    illness_header:add_link(g71039_code)
    illness_header:add_link(f03_c0_code)
    illness_header:add_link(f03_c1_code)
    illness_header:add_link(f03_c11_code)
    illness_header:add_link(f03_c18_code)
    illness_header:add_link(f03_c2_code)
    illness_header:add_link(f03_c3_code)
    illness_header:add_link(f03_c4_code)
    illness_header:add_link(g301_code)
    illness_header:add_link(g10_code)
    illness_header:add_link(z8673_code)
    illness_header:add_link(guillain_barre_syndrome_abs)
    illness_header:add_link(myasthenia_gravis_codes)

    local codes_present = #illness_header.links



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    --[[
    #Main Algorithm
    if spinalCodes is not None and extremitiesAbs is not None or r532Code is not None and subtitle == "Possible Functional Quadriplegia Dx":
        if spinalCodes is not None: updateLinkText(spinalCodes, autoCodeText); dc.Links.Add(spinalCodes)
        if extremitiesAbs is not None: updateLinkText(extremitiesAbs, autoCodeText); abs.Links.Add(extremitiesAbs)
        if r532Code is not None: updateLinkText(r532Code, autoCodeText); dc.Links.Add(r532Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code/Abstraction on the Account"
        result.Validated = True
        AlertPassed = True
    --]]
    -- Main Algorithm
    if spinal_codes and extremities_abs or r532_code and subtitle == "Possible Functional Quadriplegia Dx" then
        if spinal_codes then
            spinal_codes.link_text = "Autoresolved Code - " .. spinal_codes.link_text
            links.add_to_document(spinal_codes)
        end
        if extremities_abs then
            extremities_abs.link_text = "Autoresolved Code - " .. extremities_abs.link_text
            links.add_to_abstraction(extremities_abs)
        end
        if r532_code then
            r532_code.link_text = "Autoresolved Code - " .. r532_code.link_text
            links.add_to_document(r532_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code/Abstraction on the Account"
        Result.validated = true
        Result.passed = true

    --[[
    elif spinalCodes is None and r532Code is None and extremitiesAbs is None and (z7401Code is not None or (CI >= 2 and codePresent >= 1)):
        result.Subtitle = "Possible Functional Quadriplegia Dx"
        AlertPassed = True

    --]]
    --[[
    elif r532Code is not None and spinalCodes is not None:
        dc.Links.Add(r532Code)
        dc.Links.Add(spinalCodes)
        result.Subtitle = "Possible Conflicting Functional Quadriplegia Dx with Spinal Cord Injury Dx, Seek Clarification"
        AlertPassed = True

    --]]
    --[[
    elif subtitle == "Functional Quadriplegia Dx Possibly Lacking Supporting Evidence" and (z7401Code is not None or (CI > 0 and codePresent > 0)):
        if z7401Code is not None: updateLinkText(z7401Code, autoEvidenceText); abs.Links.Add(z7401Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code/Abstraction on the Account"
        result.Validated = True
        AlertPassed = True

    --]]
    --[[
    elif spinalCodes is None and r532Code is not None and z7401Code is None and CI == 0 and codePresent == 0:
        if extremitiesAbs is not None: abs.Links.Add(extremitiesAbs)
        result.Subtitle = "Functional Quadriplegia Dx Possibly Lacking Supporting Evidence"
        AlertPassed = True

    --]]
    --[[
    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False
    --]]
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            --[[
            #Abstractions
            if assistanceADLSAbs is not None: abs.Links.Add(assistanceADLSAbs) #1
            #2 
            if z7401Code is not None: abs.Links.Add(z7401Code) #3
            #4-6
            abstractValue("CHAIRFAST", "Chairfast '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7)
            #8-9
            codeValue("3E0G76Z", "Enteral Nutrition: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, abs, True)
            #11
            codeValue("R15.9", "Fecal Incontinence: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, abs, True)
            #13-14
            codeValue("R39.81", "Functional Urinary Incontinence: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
            codeValue("3E0H76Z", "J Tube Nutrition: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, abs, True)
            #17
            codeValue("N31.9", "Neurogenic Bladder: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, abs, True)
            codeValue("R29.6", "Recurrent Falls: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19, abs, True)
            #20-25
            codeValue("R53.1", "Weakness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 26, abs, True)
            #27
            --]]
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

