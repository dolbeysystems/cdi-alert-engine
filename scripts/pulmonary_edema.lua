---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Pulmonary Edema
---
--- This script checks an account to see if it matches the criteria for a pulmonary edema alert.
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
local medications = require("libs.common.medications")(Account)
local discrete = require("libs.common.discrete")(Account)
local headers = require("libs.common.headers")(Account)



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local dv_arterial_blood_co2 = { "BLD GAS CO2 (mmHg)", "PaCO2 (mmHg)" }
local calc_arterial_blood_co2 = discrete.make_gt_predicate(46)
local dv_arterial_blood_ph = { "pH" }
local calc_arterial_blood_ph = discrete.make_lt_predicate(7.30)
local dv_bnp = { "BNP(NT proBNP) (pg/mL)" }
local calc_bnp = discrete.make_gt_predicate(900)
local dv_dbp = { "BP Arterial Diastolic cc (mm Hg)", "DBP 3.5 (No Calculation) (mmhg)",
    "DBP 3.5 (No Calculation) (mm Hg)" }
local calc_dbp = discrete.make_gt_predicate(110)
local dv_heart_rate = { "Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)",
    "3.5 Heart Rate (Radial) (bpm)", "SCC Monitor Pulse (bpm)" }
local calc_heart_rate = discrete.make_gt_predicate(90)
local dv_pa_o2 = { "BLD GAS O2 (mmHg)", "PO2 (mmHg)" }
local calc_pa_o2 = discrete.make_lt_predicate(80)
local dv_pro_bnp = { "" }
local calc_pro_bnp = discrete.make_gt_predicate(900)
local dv_reduced_ejection_fraction = { "" }
local calc_reduced_ejection_fraction = discrete.make_lt_predicate(41)
local dv_respiratory_rate = { "3.5 Respiratory Rate (#VS I&O) (per Minute)" }
local calc_respiratory_rate = discrete.make_gt_predicate(20)
local dv_sbp = { "SBP 3.5 (No Calculation) (mm Hg)" }
local calc_sbp = discrete.make_gt_predicate(180)
local dv_spo2 = { "Pulse Oximetry(Num) (%)" }
local calc_spo2 = discrete.make_lt_predicate(90)
local dv_troponin_t = { "TROPONIN, HIGH SENSITIVITY (ng/L)" }
local calc_troponin_t = discrete.make_gt_predicate(59)
local dv_oxygen_therapy = { "DELIVERY" }



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
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 3)
    local vital_signs_intake_header = headers.make_header_builder("Vital Signs/Intake", 4)
    local oxygenation_ventilation_header = headers.make_header_builder("Oxygenation/Ventilation", 5)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 6)
    local chest_x_ray_header = headers.make_header_builder("Chest X-Ray", 7)
    local ct_chest_header = headers.make_header_builder("CT Chest", 8)
    local contributing_dx_header = headers.make_header_builder("Contributing Dx", 9)
    local cardiogenic_indicators_header = headers.make_header_builder("Cardiogenic Indicators", 10)

    local function compile_links()
        table.insert(result_links, cardiogenic_indicators_header:build(true))
        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, vital_signs_intake_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))
        table.insert(result_links, oxygenation_ventilation_header:build(true))
        table.insert(result_links, chest_x_ray_header:build(true))
        table.insert(result_links, ct_chest_header:build(true))
        table.insert(result_links, contributing_dx_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end


    --------------------------------------------------------------------------------
    --- Alert Variables
    --------------------------------------------------------------------------------
    local ci = 0


    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Negations
    local j690_code = codes.make_code_link("J69.0", "Aspiration Pneumonia")
    local j681_code = codes.make_code_link("J68.1", "Pulmonary Edema due to Chemicals, Gases, Fumes and Vapors")
    local i501_code = codes.make_code_link("I50.1", "Pulmonary Edema with Heart Failure/Heart Failure")
    local acute_hf_codes = codes.make_code_one_of_link(
        { "I50.21", "I50.23", "I50.31", "I50.33", "I50.41", "I50.43", "I50.811", "I50.813" },
        "Acute Heart Failure"
    )
    local acute_hf_abs = codes.make_abstraction_link("ACUTE_HEART_FAILURE", "Acute Heart Failure")
    local acute_chronic_hf_abs = codes.make_abstraction_link("ACUTE_ON_CHRONIC_HEART_FAILURE", "Acute on Chronic Heart Failure")

    -- Alert Trigger
    local chronic_pulmonary_edema_abs = codes.make_abstraction_link("CHRONIC_PULMONARY_EDEMA", "Chronic Pulmonary Edema")
    local j810_code = codes.make_code_link("J81.0", "Acute Pulmonary Edema")
    local j960_code = codes.make_code_link("J96.0", "Aspiration Pneumonia")
    local pulmonary_edema_abs = codes.make_abstraction_link("PULMONARY_EDEMA", "Pulmonary Edema")

    -- Clinical Indicators
    local acute_resp_failure = codes.make_code_one_of_link({ "J96.00", "J96.01", "J96.02" }, "Acute Respiratory Failure")
    local j80_code = codes.make_code_link("J80", "Acute Respiratory Distress Syndrome")
    local r079_code = codes.make_code_link("R07.9", "Chest Pain")
    local chest_tightness_abs = codes.make_abstraction_link("CHEST_TIGHTNESS", "Chest Tightness")
    local crackles_abs = codes.make_abstraction_link("CRACKLES", "Crankles")
    local r0600_code = codes.make_code_link("R06.00", "Dyspnea")
    local e8740_code = codes.make_code_link("E87.40", "Fluid Overloaded")
    local r042_code = codes.make_code_link("R04.2", "Hemoptysis")
    local pink_frothy_sputum_abs = codes.make_abstraction_link("PINK_FROTHY_SPUTUM", "Pink Frothy Sputum")
    local r062_code = codes.make_code_link("R06.2", "Wheezing")

    -- Labs
    local r0902_code = codes.make_code_link("R09.02", "Hypoxemia")
    local pao2_dv = discrete.make_discrete_value_link(dv_pa_o2, "pa02", calc_pa_o2)

    -- Meds
    local diuretic_med = codes.make_abstraction_link("DIURETIC", "Diuretic")
    local sodium_nitro_med = medications.make_medication_link("Sodium Nitroprusside")
    local vasodilator_med = medications.make_medication_link("Vasodilator")

    -- Oxygen
    local flow_nasal_oxygen = codes.make_code_one_of_link({ "5A0935A", "5A0945A", "5A0955A" }, "Flow Nasal Oxygen")
    local a5a1945z_code = codes.make_code_link("5A1945Z", "Mechanical Ventilation 24 to 96 hours")
    local a5a1955z_code = codes.make_code_link("5A1955Z", "Mechanical Ventilation Greater than 96 hours")
    local a5a1935z_code = codes.make_code_link("5A1935Z", "Mechanical Ventilation Less than 24 hours")
    local a3e0f7sf_code = codes.make_code_link("3E0F7SF", "Nasal Cannula")
    local non_invasive_vent_abs = codes.make_abstraction_link("NON_INVASIVE_VENTILATION", "Non-Invasive Ventilation")
    local oxygen_therapy_dv = discrete.make_discrete_value_link(dv_oxygen_therapy, "Oxygen Therapy")
    local oxygen_therapy_abs = codes.make_abstraction_link("OXYGEN_THERAPY", "Oxygen Therapy")

    -- Vitals
    local elev_right_ventricle_sy_pressure_abs = codes.make_abstraction_link("ELEVATED_RIGHT_VENTRICLE_SYSTOLIC_PRESSUE", "Elevated Right Ventricle Systolic Pressure")
    local sp02_dv = discrete.make_discrete_value_link(dv_spo2, "Sp02", calc_spo2)
    local high_resp_rate_dv = discrete.make_discrete_value_link(dv_respiratory_rate, "Respiratory Rate", calc_respiratory_rate)

    -- Cardiogenic Indicators
    cardiogenic_indicators_header:add_code_link("I51.1", "Acute Heart Valve Failure Rupture of Chordae Tendineae")
    cardiogenic_indicators_header:add_code_prefix_link("I21%.", "Acute Myocardial Infarction")
    cardiogenic_indicators_header:add_code_link("I35.1", "Aortic Regurgitation")
    cardiogenic_indicators_header:add_code_link("I35.2", "Aortic Stenosis")
    cardiogenic_indicators_header:add_code_link("I31.4", "Cardiac Tamponade")
    cardiogenic_indicators_header:add_code_prefix_link("I42%.", "Cardiomyopathy")
    cardiogenic_indicators_header:add_discrete_value_one_of_link(
        dv_reduced_ejection_fraction,
        "Ejection Fraction",
        calc_reduced_ejection_fraction
    )
    cardiogenic_indicators_header:add_abstraction_link("REDUCED_EJECTION_FRACTION", "Ejection Fraction")
    cardiogenic_indicators_header:add_code_link("I38", "Endocarditis")
    cardiogenic_indicators_header:add_code_one_of_link({
        "I50.21", "I50.22", "I50.23", "I50.31", "I50.32", "I50.33", "I50.41", "I50.42", "I50.43",
        "I50.812", "I50.814", "I50.82", "I50.83", "I50.84", "I50.1", "I50.20", "I50.30", "I50.40",
        "I50.810", "I50.89", "I50.9"
    }, "Heart Failure")
    cardiogenic_indicators_header:add_code_link("I34.0", "Mitral Regurgitation")
    cardiogenic_indicators_header:add_code_link("I34.2", "Mitral Stenosis")
    cardiogenic_indicators_header:add_code_link("I51.4", "Myocarditis")
    cardiogenic_indicators_header:add_code_link("I31.39", "Pericardial Effusion")
    cardiogenic_indicators_header:add_code_link("I51.2", "Rupture of Papillary Muscle")
    cardiogenic_indicators_header:add_code_link("I49.01", "Ventricular Fibrillation")
    cardiogenic_indicators_header:add_code_link("I49.02", "Ventricular Flutter")
    cardiogenic_indicators_header:add_code_prefix_link("I47%.2", "Ventricular Tachycardia")

    -- Determining Clinical Indicators
    if acute_resp_failure then
        clinical_evidence_header:add_link(acute_resp_failure)
        ci = ci + 1
    end
    if j80_code then
        clinical_evidence_header:add_link(j80_code)
        ci = ci + 1
    end
    if r0902_code or sp02_dv or pao2_dv then
        clinical_evidence_header:add_link(r0902_code)
        vital_signs_intake_header:add_link(sp02_dv)
        laboratory_studies_header:add_link(pao2_dv)
        ci = ci + 1
    end
    if high_resp_rate_dv then
        vital_signs_intake_header:add_link(high_resp_rate_dv)
        ci = ci + 1
    end
    if r079_code then
        clinical_evidence_header:add_link(r079_code)
        ci = ci + 1
    end
    if pink_frothy_sputum_abs then
        clinical_evidence_header:add_link(pink_frothy_sputum_abs)
        ci = ci + 1
    end
    if elev_right_ventricle_sy_pressure_abs then
        clinical_evidence_header:add_link(elev_right_ventricle_sy_pressure_abs)
        ci = ci + 1
    end
    if r0600_code then
        clinical_evidence_header:add_link(r0600_code)
        ci = ci + 1
    end
    if chest_tightness_abs then
        clinical_evidence_header:add_link(chest_tightness_abs)
        ci = ci + 1
    end
    if crackles_abs then
        clinical_evidence_header:add_link(crackles_abs)
        ci = ci + 1
    end
    if e8740_code then
        clinical_evidence_header:add_link(e8740_code)
        ci = ci + 1
    end
    if r042_code then
        clinical_evidence_header:add_link(r042_code)
        ci = ci + 1
    end
    if r062_code then
        clinical_evidence_header:add_link(r062_code)
        ci = ci + 1
    end



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if chronic_pulmonary_edema_abs or j810_code or i501_code or j681_code or j960_code or acute_hf_codes then
        if existing_alert then
            if chronic_pulmonary_edema_abs then
                chronic_pulmonary_edema_abs.link_text =
                    "Autoresolved Evidence - " .. chronic_pulmonary_edema_abs.link_text
                clinical_evidence_header:add_link(chronic_pulmonary_edema_abs)
            end
            if j810_code then
                j810_code.link_text = "Autoresolved Code - " .. j810_code.link_text
                clinical_evidence_header:add_link(j810_code)
            end
            if i501_code then
                i501_code.link_text = "Autoresolved Code - " .. i501_code.link_text
                clinical_evidence_header:add_link(i501_code)
            end
            if j681_code then
                j681_code.link_text = "Autoresolved Code - " .. j681_code.link_text
                clinical_evidence_header:add_link(j681_code)
            end
            if j960_code then
                j960_code.link_text = "Autoresolved Code - " .. j960_code.link_text
                clinical_evidence_header:add_link(j960_code)
            end
            if acute_hf_codes then
                acute_hf_codes.link_text = "Autoresolved Code - " .. acute_hf_codes.link_text
                clinical_evidence_header:add_link(acute_hf_codes)
            end
            Result.outcome = "AUTORESOLVED"
            Result.reason = "Autoresolved due to one Specified Code on the Account"
            Result.validated = true
            Result.passed = true
        else
            Result.passed = false
        end

    elseif
        (subtitle == "Possible Acute Pulmonary Edema" or subtitle == "Pulmonary Edema Documented Missing Acuity") and
        pulmonary_edema_abs and
        acute_hf_codes and
        j690_code
    then
        if pulmonary_edema_abs then
            pulmonary_edema_abs.link_text = "Autoresolved Code - " .. pulmonary_edema_abs.link_text
            clinical_evidence_header:add_link(pulmonary_edema_abs)
        end
        if acute_hf_codes then
            acute_hf_codes.link_text = "Autoresolved Code - " .. acute_hf_codes.link_text
            clinical_evidence_header:add_link(acute_hf_codes)
        end
        if j690_code then
            j690_code.link_text = "Autoresolved Code - " .. j690_code.link_text
            clinical_evidence_header:add_link(j690_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to specified dx existing now."
        Result.validated = true
        Result.passed = true

    elseif
        pulmonary_edema_abs and
        ci >= 2 and
        not acute_hf_codes and
        not j690_code and
        not acute_hf_abs and
        not acute_chronic_hf_abs
    then
        clinical_evidence_header:add_link(pulmonary_edema_abs)
        Result.subtitle = "Possible Acute Pulmonary Edema"
        Result.passed = true

    elseif pulmonary_edema_abs and ci >= 2 and acute_hf_codes and j690_code then
        clinical_evidence_header:add_link(pulmonary_edema_abs)
        Result.subtitle = "Pulmonary Edema Documented Missing Acuity"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Clinical Evidence
            -- #1-4
            clinical_evidence_header:add_code_link("R23.1", "Cold Clammy Skin")
            clinical_evidence_header:add_code_link("I25.10", "Coronary Artery Disease")
            -- #7-8
            clinical_evidence_header:add_abstraction_link("DYSPNEA_ON_EXERTION", "Dyspnea on Exertion")
            clinical_evidence_header:add_abstraction_link("EJECTION_FRACTION", "Ejection Fraction")
            clinical_evidence_header:add_code_link("R53.83", "Fatigue")
            -- #12
            clinical_evidence_header:add_abstraction_link("HEART_PALPITATIONS", "Heart Palpitations")
            -- #14
            clinical_evidence_header:add_code_link("I10", "HTN")
            clinical_evidence_header:add_abstraction_link("IRREGULAR_RADIOLOGY_REPORT_LUNGS", "Irregular Radiology Report Lungs")
            clinical_evidence_header:add_abstraction_link("LOWER_EXTREMITY_EDEMA", "Lower Extremity Edema")
            -- #18
            clinical_evidence_header:add_abstraction_link("PLEURAL_EFFUSION", "Pleural Effusion")
            clinical_evidence_header:add_abstraction_link("RESTLESSNESS", "Restlessness")
            clinical_evidence_header:add_abstraction_link("SHORTNESS_OF_BREATH_LYING_FLAT", "Shortness of Breath Lying Flat")
            clinical_evidence_header:add_code_link("R61", "Sweating")
            -- #23
            contributing_dx_header:add_abstraction_link("ASPIRATION", "Aspiration")
            contributing_dx_header:add_code_one_of_link({ "I46.2", "I46.8", "I46.9" }, "Cardiac Arrest")
            contributing_dx_header:add_code_one_of_link({ "T50.901A", "T50.902A", "T50.903A", "T50.904A" }, "Drug Overdose")
            contributing_dx_header:add_code_link("N18.6", "End-Stage Renal Disease")
            contributing_dx_header:add_code_one_of_link(
                {
                    "T17.200A", "T17.290A", "T17.300A", "T17.390A", "T17.400A", "T17.420A", "T17.490A", "T17.500A",
                    "T17.590A", "T17.800A", "T17.890A"
                },
                "Foreign Body in Respiratory Tract Causing Asphyxiation"
            )
            contributing_dx_header:add_code_one_of_link(
                {
                    "T17.210A", "T17.310A", "T17.410A", "T17.510A", "T17.810A", "T17.910A"
                },
                "Gastric Contents in Respiratory Tract Causing Asphyxiation"
            )
            contributing_dx_header:add_code_one_of_link({ "I16.0", "I16.1", "I16.9" }, "Hypertensive Crisis")
            contributing_dx_header:add_abstraction_link("OPIOID_OVERDOSE", "Overdose")
            contributing_dx_header:add_code_link("J69.1", "Pneumonitis due to Inhalation of Oils and Essences")
            contributing_dx_header:add_code_link("J68.1", "Pulmonary Edema due to Chemicals, Gases, Fumes and Vapors")
            contributing_dx_header:add_code_prefix_link("I26%.", "Pulmonary Embolism")
            contributing_dx_header:add_code_link("J70.0", "Radiation Pneumonitis (Acute Pulmonary Manifestations due to Radiation)")
            contributing_dx_header:add_code_one_of_link(
                {
                    "A41.2", "A41.3", "A41.4", "A41.50", "A41.51", "A41.52", "A41.53", "A41.54", "A41.59", "A41.81",
                    "A41.89", "A41.9", "A42.7", "A22.7", "B37.7", "A26.7", "A54.86", "B00.7", "A32.7", "A24.1",
                    "A20.7", "T81.44XA", "T81.44XD"
                },
                "Sepsis Dx"
            )
            contributing_dx_header:add_code_prefix_link("T59%.4", "Toxic effect of Chlorine Gas")
            contributing_dx_header:add_code_prefix_link("T59%.5", "Toxic effect of Fluorine Gas")
            contributing_dx_header:add_code_prefix_link("T59%.2", "Toxic effect of Formaldehyde")
            contributing_dx_header:add_code_prefix_link("T59%.6", "Toxic effect of Hydrogen Sulfide")
            contributing_dx_header:add_code_prefix_link("T59%.0", "Toxic effect of Nitrogen Oxides")
            contributing_dx_header:add_code_prefix_link("T59%.8", "Toxic effect of Smoke Inhalation")
            contributing_dx_header:add_code_prefix_link("T59%.1", "Toxic effect of Sulfur Dioxide")
            contributing_dx_header:add_code_link("J95.84", "Transfusion-Related Acute Lung Injury (TRALI)")

            -- Document Links
            chest_x_ray_header:add_document_link("Chest  3 View", "Chest  3 View")
            chest_x_ray_header:add_document_link("Chest  PA and Lateral", "Chest  PA and Lateral")
            chest_x_ray_header:add_document_link("Chest  Portable", "Chest  Portable")
            chest_x_ray_header:add_document_link("Chest PA and Lateral", "Chest PA and Lateral")
            chest_x_ray_header:add_document_link("Chest  1 View", "Chest  1 View")
            ct_chest_header:add_document_link("CT Thorax W", "CT Thorax W")
            ct_chest_header:add_document_link("CTA Thorax Aorta", "CTA Thorax Aorta")
            ct_chest_header:add_document_link("CT Thorax WO-Abd WO-Pel WO", "CT Thorax WO-Abd WO-Pel WO")
            ct_chest_header:add_document_link("CT Thorax WO", "CT Thorax WO")

            -- Labs
            laboratory_studies_header:add_discrete_value_one_of_link(dv_arterial_blood_ph, "Arterial Blood PH", calc_arterial_blood_ph)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_bnp, "BNP", calc_bnp)
            -- #3-4
            laboratory_studies_header:add_discrete_value_one_of_link(dv_arterial_blood_co2, "Arterial Blood C02", calc_arterial_blood_co2)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_pro_bnp, "Pro BNP", calc_pro_bnp)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_troponin_t, "Troponin T", calc_troponin_t)

            -- Meds
            treatment_and_monitoring_header:add_medication_link("Bronchodilator", "Bronchodilator")
            treatment_and_monitoring_header:add_medication_link("Bumetanide", "Bumetanide")
            treatment_and_monitoring_header:add_medication_link("Sodium Nitroprusside", "Sodium Nitroprusside")
            treatment_and_monitoring_header:add_link(diuretic_med)
            treatment_and_monitoring_header:add_medication_link("Furosemide", "Furosemide")
            treatment_and_monitoring_header:add_link(sodium_nitro_med)
            treatment_and_monitoring_header:add_link(vasodilator_med)

            -- Oxygen
            oxygenation_ventilation_header:add_link(flow_nasal_oxygen)
            oxygenation_ventilation_header:add_link(a5a1945z_code)
            oxygenation_ventilation_header:add_link(a5a1955z_code)
            oxygenation_ventilation_header:add_link(a5a1935z_code)
            oxygenation_ventilation_header:add_link(a3e0f7sf_code)
            oxygenation_ventilation_header:add_link(non_invasive_vent_abs)
            oxygenation_ventilation_header:add_link(oxygen_therapy_dv)
            oxygenation_ventilation_header:add_link(oxygen_therapy_abs)
            oxygenation_ventilation_header:add_abstraction_link("VENTILATOR_DAYS", "Ventilator Days")

            -- Vitals
            vital_signs_intake_header:add_discrete_value_one_of_link(dv_dbp, "Diastolic Blood Pressure", calc_dbp)
            vital_signs_intake_header:add_discrete_value_one_of_link(dv_heart_rate, "Heart Rate", calc_heart_rate)
            vital_signs_intake_header:add_discrete_value_one_of_link(dv_sbp, "Systolic Blood Pressure", calc_sbp)
        end



        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        compile_links()
    end
end
