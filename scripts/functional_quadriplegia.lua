---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Functional Quadriplegia
---
--- This script checks an account to see if it matches the criteria for a Functional Quadriplegia alert.
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
local codes = require("libs.common.codes")(Account)
local discrete = require("libs.common.discrete")(Account)
local headers = require("libs.common.headers")(Account)



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local braden_risk_assessment_score_dv_names = { "3.5 Activity (Braden Scale)" }
local braden_risk_assessment_score_predicate = discrete.make_lt_predicate(2)
local braden_mobility_score_dv_names = { "3.5 Mobility" }
local braden_mobility_score_predicated = discrete.make_lt_predicate(2)


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
    local r532_code = codes.make_code_link("R53.2", "Functional Quadriplegia Dx")
    local spinal_codes = codes.make_code_one_of_link(
        { "G82.20", "G82.21", "G82.22", "G82.50", "G82.51", "G82.52", "G82.53", "G82.54" },
        "Spinal Cord Injury Dx"
    )

    -- Abs
    local assistance_adls_abs = codes.make_abstraction_link("ASSISTANCE_WITH_ADLS", "Assistance with ADLS")
    local z741_code = codes.make_code_link("Z74.1", "Assistance with Personal Care")
    local z7401_code = codes.make_code_link("Z74.01", "Bed Bound")
    local braden_risk_assessment_score_abs = codes.make_abstraction_link("BRADEN_RISK_ASSESSMENT_SCORE_FUNCTIONAL_QUADRIPLEGIA", "Braden Risk Assessment Score")
    local braden_risk_assessment_score_dv = discrete.make_discrete_value_link(braden_risk_assessment_score_dv_names, "Braden Scale Activity Score", braden_risk_assessment_score_predicate)
    local braden_risk_mobility_dv = discrete.make_discrete_value_link(braden_mobility_score_dv_names, "Braden Scale Mobility Score", braden_mobility_score_predicated)
    local complete_assistance_adls_abs = codes.make_abstraction_link("COMPLETE_ASSISTANCE_WITH_ADLS", "Complete Assistance with ADLs")
    local debilitated_abs = codes.make_abstraction_link("DEBILITATED", "Debilitated")
    local extremities_abs = codes.make_abstraction_link("MOVES_ALL_EXTREMITIES", "Extremities")
    local flaccid_limbs_abs = codes.make_abstraction_link("FLACCID_LIMBS", "Flaccid Limbs")
    local foot_drop_codes = codes.make_code_one_of_link({ "M21.371", "M21.372", "M21.379" }, "Foot Drop")
    local muscle_contracture_abs = codes.make_abstraction_link("MUSCLE_CONTRACTURE", "Muscle Contracture")
    local sacral_decubitus_codes = codes.make_code_one_of_link({ "L89.153", "L89.154" }, "Sacral Decubitus Ulcer")
    local severe_weakness_abs = codes.make_abstraction_link("SEVERE_WEAKNESS", "Severe Weakness")
    local spastic_hemiplegia = codes.mkae_code_one_of_link({ "G81.10", "G81.11", "G81.12", "G81.13", "G81.14" }, "Spastic Hemiplegia")
    local z930_code = codes.make_code_link("Z93.0", "Trach Dependent")
    local transfer_with_a_lift_abs = codes.make_abstraction_link("TRANSFER_WITH_A_LIFT", "Transfer With A Lift")
    local z9911_code = codes.make_code_link("Z99.11", "Ventilator Dependent")
    local wrist_drop_codes = codes.make_code_one_of_link({ "M21.331", "M21.332", "M21.339" }, "Wrist Drop")

    -- Illness
    local g301_code = codes.make_code_link("G30.1", "Alzheimers Disease with Late Onset")
    local g1221_code = codes.make_code_link("G12.21", "Amyotrophic Latertal Sclerosis")
    local g804_code = codes.make_code_link("G80.4", "Ataxic Cerebral Palsy")
    local g803_code = codes.make_code_link("G80.3", "Athetoid Cerebral Palsy")
    local g71031_code = codes.make_code_link("G71.031", "Autosomal Dominant Limb Girdle Muscular Dystrophy")
    local g71032_code = codes.make_code_link("G71.032", "Autosomal recessive limb girdle muscular dystrophy due to calpain-3 dysfunction")
    local g809_code = codes.make_code_link("G80.9", "Cerebral Palsy, Unspecified")
    local g7101_code = codes.make_code_link("G71.01", "Duchenne or Becker Muscular Dystrophy")
    local g7102_code = codes.make_code_link("G71.02", "Facioscapulohumeral Muscular Dystrophy")
    local guillain_barre_syndrome_abs = codes.make_abstraction_link("GUILLAIN_BARRE_SYNDROME", "Guillain-Barre Syndrome")
    local g10_code = codes.make_code_link("G10", "Huntingtons Disease")
    local g71035_code = codes.make_code_link("G71.035", "Limb Girdle Muscular Dystrophy due to Anoctamin-5 Dysfunction Muscular Dystrophy")
    local g71033_code = codes.make_code_link("G71.033", "Limb Girdle Muscular Dystrophy due to Dysferlin Dysfunction")
    local g71034_code = codes.make_code_link("G71.034", "Limb Girdle Muscular Dystrophy due to Sarcoglycan Dysfunction")
    local g71039_code = codes.make_code_link("G71.039", "Limb Girdle Muscular Dystrophy, Unspecified")
    local g35_code = codes.make_code_link("G35", "Multiple Sclerosis")
    local g7100_code = codes.make_code_link("G71.00", "Muscular Dystrophy Unspecified")
    local myasthenia_gravis_codes = codes.get_multi_code_link { codes = { "G70.00", "G70.01" }, text = "Myasthenia Gravis" }
    local g808_code = codes.make_code_link("G80.8", "Other Cerebral Palsy")
    local g20_code = codes.make_code_link("G20", "Parkinson's")
    local g20a1_code = codes.make_code_link("G20.A1", "Parkinson's Disease without Dyskinesia, without Mention of Fluctuations")
    local g20a2_code = codes.make_code_link("G20.A2", "Parkinson's Disease without Dyskinesia, with Fluctuations")
    local g20b1_code = codes.make_code_link("G20.B1", "Parkinson's Disease with Dyskinesia, without Mention of Fluctuations")
    local g20b2_code = codes.make_code_link("G20.B2", "Parkinson's Disease with Dyskinesia, with Fluctuations")
    local g20c_code = codes.make_code_link("G20.C", "Parkinsonism, Unspecified")
    local g801_code = codes.make_code_link("G80.1", "Spastic Diplegic Cerebral Palsy")
    local g802_code = codes.make_code_link("G80.2", "Spastic Hemiplegic Cerebral Palsy")
    local g800_code = codes.make_code_link("G80.0", "Spastic Quadriplegic Cerebral Palsy")
    local z8673_code = codes.make_code_link("Z86.73", "Stroke")
    local f03_c11_code = codes.make_code_link("F03.C11", "Unspecified Dementia, Severe, with Agitation")
    local f03_c4_code = codes.make_code_link("F03.C4", "Unspecified Dementia, Severe, with Anxiety")
    local f03_c1_code = codes.make_code_link("F03.C1", "Unspecified Dementia, Severe, with Behavioral Disturbance")
    local f03_c0_code = codes.make_code_link("F03.C0", "Unspecified Dementia, Severe, without Behavioral Disturbance, Psychotic Disturbance, Mood Disturbance, and Anxiety")
    local f03_c3_code = codes.make_code_link("F03.C3", "Unspecified Dementia, Severe, with Mood Disturbance")
    local f03_c18_code = codes.make_code_link("F03.C18", "Unspecified Dementia, Severe, with Other Behavioral Disturbance")
    local f03_c2_code = codes.make_code_link("F03.C2", "Unspecified Dementia, Severe, with Psychotic Disturbance")

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
    -- Main Algorithm
    if spinal_codes and extremities_abs or r532_code and subtitle == "Possible Functional Quadriplegia Dx" then
        if spinal_codes then
            spinal_codes.link_text = "Autoresolved Code - " .. spinal_codes.link_text
            documented_dx_header:add_link(spinal_codes)
        end
        if extremities_abs then
            extremities_abs.link_text = "Autoresolved Code - " .. extremities_abs.link_text
            clinical_evidence_header:add_link(extremities_abs)
        end
        if r532_code then
            r532_code.link_text = "Autoresolved Code - " .. r532_code.link_text
            documented_dx_header:add_link(r532_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code/Abstraction on the Account"
        Result.validated = true
        Result.passed = true

    elseif not spinal_codes and r532_code and not extremities_abs and (z7401_code or (ci >= 2 and codes_present >= 1)) then
        Result.subtitle = "Possible Functional Quadriplegia Dx"
        Result.passed = true

    elseif r532_code and spinal_codes then
        documented_dx_header:add_link(r532_code)
        documented_dx_header:add_link(spinal_codes)
        Result.subtitle = "Possible Conflicting Functional Quadriplegia Dx with Spinal Cord Injury Dx, Seek Clarification"
        Result.passed = true

    elseif subtitle == "Functional Quadriplegia Dx Possibly Lacking Supporting Evidence" and (z7401_code or (ci > 0 and codes_present > 0)) then
        if z7401_code then
            z7401_code.link_text = "Autoresolved Evidence - " .. z7401_code.link_text
            clinical_evidence_header:add_link(z7401_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code/Abstraction on the Account"
        Result.validated = true
        Result.passed = true

    elseif spinal_codes and r532_code and not z7401_code and ci == 0 and codes_present == 0 then
        if extremities_abs then
            clinical_evidence_header:add_link(extremities_abs)
        end
        Result.subtitle = "Functional Quadriplegia Dx Possibly Lacking Supporting Evidence"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Abstractions
            clinical_evidence_header:add_link(assistance_adls_abs)
            -- #2
            clinical_evidence_header:add_link(z7401_code)
            -- #4-6
            clinical_evidence_header:add_abstraction_link("CHAIRFAST", "Chairfast")
            -- #8-9
            clinical_evidence_header:add_code_link("3E0G76Z", "Enteral Nutrition")
            -- #11
            clinical_evidence_header:add_code_link("R15.9", "Fecal Incontinence")
            -- #13-14
            clinical_evidence_header:add_code_link("R39.81", "Functional Urinary Incontinence")
            clinical_evidence_header:add_code_link("3E0H76Z", "J Tube Nutrition")
            -- #17
            clinical_evidence_header:add_code_link("N31.9", "Neurogenic Bladder")
            clinical_evidence_header:add_code_link("R29.6", "Recurrent Falls")
            -- #20-25
            clinical_evidence_header:add_code_link("R53.1", "Weakness")
            -- #27
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

