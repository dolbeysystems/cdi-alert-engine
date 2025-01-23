---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Pulmonary Embolism
---
--- This script checks an account to see if it matches the criteria for a pulmonary embolism alert.
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
local dv_bnp = { "BNP(NT proBNP) (pg/mL)" }
local calc_bnp = discrete.make_gt_predicate(900)
local dv_d_dimer = { "D-DIMER (mg/L FEU)" }
local calc_d_dimer = discrete.make_gt_predicate(0.48)
local dv_heart_rate = {
    "Heart Rate cc (bpm)",
    "3.5 Heart Rate (Apical) (bpm)",
    "3.5 Heart Rate (Other) (bpm)",
    "3.5 Heart Rate (Radial) (bpm)",
    "SCC Monitor Pulse (bpm)"
}
local calc_heart_rate = discrete.make_gt_predicate(90)
local dv_oxygen_therapy = { "DELIVERY" }
local dv_pa_o2 = { "BLD GAS O2 (mmHg)", "PO2 (mmHg)" }
local calc_pa_o2 = discrete.make_lt_predicate(80)
local dv_pro_bnp = { "" }
local calc_pro_bnp = discrete.make_gt_predicate(900)
local dv_pulmonary_pressure = { "" }
local calc_pulmonary_pressure = discrete.make_gt_predicate(30)
local dv_respiratory_rate = { "3.5 Respiratory Rate (#VS I&O) (per Minute)" }
local calc_respiratory_rate = discrete.make_gt_predicate(20)



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = Result.script_name }
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
    local ct_chest_header = headers.make_header_builder("CT Chest", 7)

    local function compile_links()
        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, vital_signs_intake_header:build(true))
        table.insert(result_links, oxygenation_ventilation_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))
        table.insert(result_links, chest_x_ray_header:build(true))
        table.insert(result_links, ct_chest_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end



    --------------------------------------------------------------------------------
    --- Alert Variables
    --------------------------------------------------------------------------------
    local alert_code_dictionary = {
        ["I26.0"] = "Pulmonary embolism with Acute Cor Pulmonale",
        ["I26.01"] = "Septic pulmonary embolism with acute cor pulmonale",
        ["I26.02"] = "Saddle embolus of pulmonary artery with acute cor pulmonale",
        ["I26.09"] = "Other pulmonary embolism with acute cor pulmonale"
    }
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Alert Trigger
    local i2694_code = codes.make_code_link("I26.94", "Assigned Multiple Subsegmental Pulmonary Embolism without Acute Cor Pulmonale")
    local i2699_code = codes.make_code_link("I26.99", "Assigned Pulmonary Embolism without Acute Cor Pulmonale")
    local i2692_code = codes.make_code_link("I26.92", "Assigned Saddle Embolus without Acute Cor Pulmonale")
    local i2690_code = codes.make_code_link("I26.90", "Assigned Septic Pulmonary Embolism without Acute Cor Pulmonale")
    local i2693_code = codes.make_code_link("I26.93", "Assigned Single Subsegmental Pulmonary Embolism without Acute Cor Pulmonale")
    local right_ventricle_hypertropy_abs = codes.make_abstraction_link("RIGHT_VENTRICULAR_HYPERTROPHY", "Right Ventricular Hypertrophy")
    local pul_embo_abs = codes.make_abstraction_link("PULMONARY_EMBOLISM", "Pulmonary Embolism")
    local i50810_code = codes.make_code_link("I50.810", "Right Heart Failure")
    local heart_strain_abs = codes.make_abstraction_link("RIGHT_HEART_STRAIN", "Right Heart Strain")
    local clot_burden_abs = codes.make_abstraction_link("CLOT_BURDEN", "Clot Burden")



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    local trigger_alert =
        existing_alert and
        existing_alert.outcome ~= "AUTORESOLVED" and
        existing_alert.reason ~= "Previously Autoresolved"

    if #account_alert_codes == 1 then
        if existing_alert then
            for _, code in ipairs(account_alert_codes) do
                local desc = alert_code_dictionary[code]
                local temp_code = codes.make_code_link(code, "Autoresolved Specified Code - " .. desc)
                if temp_code then
                    documented_dx_header:add_link(temp_code)
                    break
                end
            end
            Result.outcome = "AUTORESOLVED"
            Result.reason = "Autoresolved due to one Specified Code on the Account"
            Result.validated = true
            Result.passed = true
        else
            Result.passed = false
        end
    elseif #account_alert_codes >= 2 then
        for _, code in ipairs(account_alert_codes) do
            local desc = alert_code_dictionary[code]
            local temp_code = codes.make_code_link(code, desc)
            documented_dx_header:add_link(temp_code)
        end
        if existing_alert and existing_alert.validated then
            Result.validated = false
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
        end
        Result.passed = true
        Result.subtitle = "Possible Conflicting Pulmonary Embolism Dx Codes"
    elseif
        trigger_alert and
        #account_alert_codes == 0 and
        (i2694_code or i2699_code or i2692_code or i2690_code or i2693_code) and
        (right_ventricle_hypertropy_abs or heart_strain_abs or i50810_code or clot_burden_abs)
    then
        documented_dx_header:add_link(heart_strain_abs)
        documented_dx_header:add_link(i50810_code)
        documented_dx_header:add_link(right_ventricle_hypertropy_abs)
        documented_dx_header:add_link(i2694_code)
        documented_dx_header:add_link(i2699_code)
        documented_dx_header:add_link(i2692_code)
        documented_dx_header:add_link(i2693_code)
        documented_dx_header:add_link(i2690_code)
        documented_dx_header:add_link(clot_burden_abs)
        Result.subtitle = "Pulmonary Embolism Possible Acute Cor Pulmonale"
        Result.passed = true
    elseif
        subtitle == "Pulmonary Embolism found only on Radiology Report" and
        (
            #account_alert_codes == 0 or
            i2699_code or
            i2690_code or
            i2692_code or
            i2693_code or
            i2694_code
        )
    then
        if #account_alert_codes > 0 then
            for _, code in ipairs(account_alert_codes) do
                local desc = alert_code_dictionary[code]
                local temp_code = codes.make_code_link(code, "Autoresolved Specified Code - " .. desc)
                if temp_code then
                    documented_dx_header:add_link(temp_code)
                    break
                end
            end
        end
        if i2699_code then
            links.update_link_text(i2699_code, "Autoresolved Code")
            documented_dx_header:add_link(i2699_code)
        end
        if i2690_code then
            links.update_link_text(i2690_code, "Autoresolved Code")
            documented_dx_header:add_link(i2690_code)
        end
        if i2692_code then
            links.update_link_text(i2692_code, "Autoresolved Code")
            documented_dx_header:add_link(i2692_code)
        end
        if i2693_code then
            links.update_link_text(i2693_code, "Autoresolved Code")
            documented_dx_header:add_link(i2693_code)
        end
        if i2694_code then
            links.update_link_text(i2694_code, "Autoresolved Code")
            documented_dx_header:add_link(i2694_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true
    elseif
        trigger_alert and
        not i2694_code and
        not i2699_code and
        not i2692_code and
        not i2690_code and
        not i2693_code and
        #account_alert_codes == 0 and
        pul_embo_abs
    then
        documented_dx_header:add_link(pul_embo_abs)
        Result.subtitle = "Pulmonary Embolism found only on Radiology Report"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Clinical Evidence
            clinical_evidence_header:add_code_link("D68.51", "Activated Protein C Resistance \"Factor V Liden\"")
            clinical_evidence_header:add_code_link("R18.8", "Ascities")
            clinical_evidence_header:add_code_link("D68.61", "Antiphospholipid Syndrome")
            clinical_evidence_header:add_code_link("R07.9", "Chest Pain")
            clinical_evidence_header:add_code_link("R05.9", "Cough")
            clinical_evidence_header:add_abstraction_link("CYANOSIS", "Cyanosis")
            clinical_evidence_header:add_code_link("R06.00", "Dyspnea")
            clinical_evidence_header:add_abstraction_link("DYSPNEA_ON_EXERTION", "Dyspnea on Exertion")
            clinical_evidence_header:add_code_one_of_link(
                {
                    "02FP3Z0", "02FQ3Z0", "02FR3Z0", "02FS3Z0", "02FT3Z0", "03F23Z0", "03F33Z0", "03F43Z0",
                    "03F53Z0", "03F63Z0", "03F73Z0", "03F83Z0", "03F93Z0", "03FA3Z0", "03FB3Z0", "03FC3Z0",
                    "03FY3Z0", "04FC3Z0", "04FD3Z0", "04FE3Z0", "04FF3Z0", "04FH3Z0", "04FJ3Z0", "04FK3Z0",
                    "04FL3Z0", "04FM3Z0", "04FN3Z0", "04FP3Z0", "04FQ3Z0", "04FR3Z0", "04FS3Z0", "04FT3Z0",
                    "04FU3Z0", "04FY3Z0", "05F33Z0", "05F43Z0", "05F53Z0", "05F63Z0", "05F73Z0", "05F83Z0",
                    "05F93Z0", "05FA3Z0", "05FB3Z0", "05FC3Z0", "05FD3Z0", "05FF3Z0", "05FY3Z0", "06FC3Z0",
                    "06FD3Z0", "06FF3Z0", "06FG3Z0", "06FH3Z0", "06FJ3Z0", "06FM3Z0", "06FN3Z0", "06FP3Z0",
                    "06FQ3Z0", "06FY3Z0"
                },
                "EKOS Therapy"
            )
            clinical_evidence_header:add_code_link("R04.2", "Hemoptysis")
            clinical_evidence_header:add_abstraction_link("HEPATOMEGALY", "Hepatomegaly")
            clinical_evidence_header:add_abstraction_link("JUGULAR_VEIN_DISTENTION", "Jugular Vein Distension")
            clinical_evidence_header:add_abstraction_link("LOWER_EXTERMITY_EDEMA", "Lower Extermity Edema")
            clinical_evidence_header:add_code_link("D68.62", "Lupus Anticoagulant Antiphospholipid Syndrome")
            clinical_evidence_header:add_code_link("D68.59", "Other Primary Thrombophilia")
            clinical_evidence_header:add_code_link("D68.69", "Other Thrombophilia")
            clinical_evidence_header:add_code_link("R07.81", "Pleuritic Chest Pain")
            clinical_evidence_header:add_abstraction_link(
                "PULMONARY_EMBOLISM_PRESENT_ON_ADMISSION",
                "Pulmonary Embolism Present on Admission Document"
            )
            clinical_evidence_header:add_abstraction_link(
                "SHORTNESS_OF_BREATH_PULMONARY_EMBOLISM",
                "Shortness of Breath"
            )

            -- Document Links
            ct_chest_header:add_document_link("CT Thorax W", "CT Thorax W")
            ct_chest_header:add_document_link("CTA Thorax Aorta", "CTA Thorax Aorta")
            ct_chest_header:add_document_link("CT Thorax WO-Abd WO-Pel WO", "CT Thorax WO-Abd WO-Pel WO")
            ct_chest_header:add_document_link("CT Thorax WO", "CT Thorax WO")
            chest_x_ray_header:add_document_link("Chest  3 View", "Chest  3 View")
            chest_x_ray_header:add_document_link("Chest  PA and Lateral", "Chest  PA and Lateral")
            chest_x_ray_header:add_document_link("Chest  Portable", "Chest  Portable")
            chest_x_ray_header:add_document_link("Chest PA and Lateral", "Chest PA and Lateral")
            chest_x_ray_header:add_document_link("Chest  1 View", "Chest  1 View")

            -- Labs
            laboratory_studies_header:add_discrete_value_one_of_link(dv_pa_o2, "Arterial Blood Oxygen", calc_pa_o2)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_bnp, "BNP", calc_bnp)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_d_dimer, "D Dimer", calc_d_dimer)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_pro_bnp, "Pro BNP", calc_pro_bnp)
            laboratory_studies_header:add_abstraction_link("PULMONARY_EDEMA", "Pulmonary Edema")

            -- Medications
            treatment_and_monitoring_header:add_medication_link("Anticoagulant", "Anticoagulant")
            treatment_and_monitoring_header:add_abstraction_link("ANTICOAGULANT", "Anticoagulant")
            treatment_and_monitoring_header:add_medication_link("Antiplatelet", "Antiplatelet")
            treatment_and_monitoring_header:add_abstraction_link("ANTIPLATELET", "Antiplatelet")
            treatment_and_monitoring_header:add_medication_link("Antiplatelet2", "Antiplatelet2")
            treatment_and_monitoring_header:add_abstraction_link("ANTIPLATELET_2", "Antiplatelet")
            treatment_and_monitoring_header:add_medication_link("Aspirin", "Aspirin")
            treatment_and_monitoring_header:add_abstraction_link("ASPIRIN", "Aspirin")
            treatment_and_monitoring_header:add_medication_link("Bronchodilator", "Bronchodilator")
            treatment_and_monitoring_header:add_abstraction_link("BRONCHODILATOR", "Bronchodilator")
            treatment_and_monitoring_header:add_medication_link("Bumetanide", "Bumetanide")
            treatment_and_monitoring_header:add_abstraction_link("BUMETANIDE", "Bumetanide")
            treatment_and_monitoring_header:add_medication_link("Diuretic", "Diuretic")
            treatment_and_monitoring_header:add_abstraction_link("DIURETIC", "Diuretic")
            treatment_and_monitoring_header:add_medication_link("Furosemide", "Furosemide")
            treatment_and_monitoring_header:add_abstraction_link("FUROSEMIDE", "Furosemide")
            treatment_and_monitoring_header:add_medication_link("Thrombolytic", "Thrombolytic")
            treatment_and_monitoring_header:add_abstraction_link("THROMBOLYTIC", "Thrombolytic")
            treatment_and_monitoring_header:add_medication_link("Vasodilator", "Vasodilator")
            treatment_and_monitoring_header:add_abstraction_link("VASODILATOR", "Vasodilator")

            -- Oxygen
            oxygenation_ventilation_header:add_code_one_of_link(
                { "5A0935A", "5A0945A", "5A0955A", "5A1935Z", "5A1945Z", "5A1955Z" },
                "Flow Nasal Oxygen"
            )
            oxygenation_ventilation_header:add_code_one_of_link(
                { "5A1935Z", "5A1945Z", "5A1955Z" },
                "Invasive Mechanical Ventilation"
            )
            oxygenation_ventilation_header:add_abstraction_link("NON_INVASIVE_VENTILATION", "Non-Invasive Ventilation")
            oxygenation_ventilation_header:add_discrete_value_one_of_link(
                dv_oxygen_therapy,
                "Oxygen Therapy",
                function(dv, num_)
                    return dv.result:find("Room Air") ~= nil or dv.result:find("RA") ~= nil
                end
            )
            oxygenation_ventilation_header:add_abstraction_link("OXYGEN_THERAPY", "Oxygen Therapy")

            -- Vitals
            vital_signs_intake_header:add_abstraction_link("ELEVATED_RIGHT_VENTRICLE_SYSTOLIC_PRESSURE",
                "Elevated Right Ventricle Systolic Pressure")
            vital_signs_intake_header:add_discrete_value_one_of_link(dv_heart_rate, "Heart Rate", calc_heart_rate)
            vital_signs_intake_header:add_code_link("R09.02", "Hypoxemia")
            vital_signs_intake_header:add_discrete_value_one_of_link(
                dv_pulmonary_pressure,
                "Pulmonary Systolic Pressure",
                calc_pulmonary_pressure
            )
            vital_signs_intake_header:add_abstraction_link(
                "ELEVATED_RIGHT_VENTRICLE_SYSTOLIC_PRESSUE",
                "Right Ventricle Systolic Pressure"
            )
            vital_signs_intake_header:add_discrete_value_one_of_link(
                dv_respiratory_rate,
                "Respiratory Rate",
                calc_respiratory_rate
            )
        end



        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        compile_links()
    end
end
