---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Heart Failure
---
--- This script checks an account to see if it matches the criteria for a heart failure alert.
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
local headers = require("libs.common.headers")(Account)



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local dv_pro_bnp = { "BNP(NT proBNP) (pg/mL)" }
local calc_pro_bnp1 = function(dv_, num) return num > 900 end
local dv_central_venous_pressure = { "CVP cc" }
local calc_central_venous_pressure1 = function(dv_, num) return num > 16 end
local dv_heart_rate = {
    "Heart Rate cc (bpm)",
    "3.5 Heart Rate (Apical) (bpm)",
    "3.5 Heart Rate (Other) (bpm)",
    "3.5 Heart Rate (Radial) (bpm)",
    "SCC Monitor Pulse (bpm)"
}
local calc_heart_rate1 = function(dv_, num) return num > 120 end
local dv_troponin_t = { "TROPONIN, HIGH SENSITIVITY (ng/L)" }
local calc_troponin_t1 = function(dv_, num) return num > 59 end



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }
local subtitle = existing_alert and existing_alert.subtitle or nil
local trigger_alert =
    not existing_alert or
    (existing_alert.outcome ~= "AUTORESOLVED" and existing_alert.reason ~= "Previously Autoresolved")



--------------------------------------------------------------------------------
--- Script Specific Functions
--------------------------------------------------------------------------------
---@param med Medication 
---@return boolean
local function iv_med_predicate(med)
    return
        med.route ~= nil and
        med.category ~= nil and
        (med.route:lower():find("intravenous") ~= nil or med.route:lower():find("iv push") ~= nil)
end


---@param med Medication 
---@return boolean
local function anesthesia_predicate(med)
    return
        med.route ~= nil and
        med.dosage ~= nil and
        med.category ~= nil and
        (
            med.dosage:lower():find("hr") ~= nil or
            med.dosage:lower():find("hour") ~= nil or
            med.dosage:lower():find("min") ~= nil or
            med.dosage:lower():find("minute") ~= nil
        ) and
        (med.route:lower():find("intravenous") ~= nil or med.route:lower():find("iv push") ~= nil)
end

if not existing_alert or not existing_alert.validated then
    --------------------------------------------------------------------------------
    --- Header Variables and Helper Functions
    --------------------------------------------------------------------------------
    local result_links = {}
    local documented_dx_header = headers.make_header_builder("Document Code", 1)
    local framingham_header = headers.make_header_builder("Framingham Criteria:", 2)
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 3)
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 4)
    local vitals_header = headers.make_header_builder("Vital Signs/Intake and Output Data", 5)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 6)
    local echo_links_header = headers.make_header_builder("Echo", 7)
    local ct_chest_links_header = headers.make_header_builder("CT Chest", 8)
    local ekg_links_header = headers.make_header_builder("EKG", 9)
    local heart_cath_links_header = headers.make_header_builder("Heart Cath", 10)
    local other_header = headers.make_header_builder("Other", 11)
    local framingham_major_header = headers.make_header_builder("Major:", 12)
    local framingham_minor_header = headers.make_header_builder("Minor:", 13)

    local function compile_links()
        framingham_header:add_link(framingham_major_header:build(true))
        framingham_header:add_link(framingham_minor_header:build(true))

        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, framingham_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, vitals_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))
        table.insert(result_links, echo_links_header:build(true))
        table.insert(result_links, ct_chest_links_header:build(true))
        table.insert(result_links, ekg_links_header:build(true))
        table.insert(result_links, heart_cath_links_header:build(true))
        table.insert(result_links, other_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end



    --------------------------------------------------------------------------------
    --- Alert Variables 
    --------------------------------------------------------------------------------
    local alert_code_dictionary = {
        ["I50.21"] = "Acute Systolic (Congestive) Heart Failure",
        ["I50.22"] = "Chronic Systolic (Congestive) Heart Failure",
        ["I50.23"] = "Acute on Chronic Systolic (Congestive) Heart Failure",
        ["I50.31"] = "Acute Diastolic (Congestive) Heart Failure",
        ["I50.32"] = "Chronic Diastolic (Congestive) Heart Failure",
        ["I50.33"] = "Acute on Chronic Diastolic (Congestive) Heart Failure",
        ["I50.41"] = "Acute Combined Systolic (Congestive) and Diastolic (Congestive) Heart Failure",
        ["I50.42"] = "Chronic Combined Systolic (Congestive) and Diastolic (Congestive) Heart Failure",
        ["I50.43"] = "Acute on Chronic Combined Systolic (Congestive) and Diastolic (Congestive) Heart Failure",
        ["I50.811"] = "Acute Right Heart Failure",
        ["I50.812"] = "Chronic Right Heart Failure",
        ["I50.813"] = "Acute on Chronic Right Heart Failure",
        ["I50.814"] = "Right Heart Failure due to Left Heart Failure",
        ["I50.82"] = "Biventricular Heart Failure",
        ["I50.83"] = "High Output Heart Failure",
        ["I50.84"] = "End Stage Heart Failure"
    }
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Negations
    local hf_codes = links.get_code_links {
        codes = {
            "I50.1", "I50.20", "I50.30", "I50.40", "I50.810", "I50.9", "I50.21", "I50.22", "I50.23", "I50.31",
            "I50.32", "I50.33", "I50.41", "I50.42", "I50.43", "I50.811", "I50.812", "I50.813", "I50.814", "I50.82",
            "I50.83", "I50.84"
        },
        text = "Heart Failure Dx Code"
    }

    -- Alert Trigger
    local acute_heart_failure_abs =
        links.get_abstraction_link { code = "ACUTE_HEART_FAILURE", text = "Acute Heart Failure" }
    local chronic_heart_failure_abs =
        links.get_abstraction_link { code = "CHRONIC_HEART_FAILURE", text = "Chronic Heart Failure" }
    local acute_chronic_heart_failure_abs =
        links.get_abstraction_link { code = "ACUTE_ON_CHRONIC_HEART_FAILURE", text = "Acute on Chronic Heart Failure" }
    local i509_code = links.get_code_link { code = "I50.9", text = "Heart Failure, Unspecified Dx" }
    local i5020_code = links.get_code_link { code = "I50.20", text = "Systolic Heart Failure Dx" }
    local i5030_code = links.get_code_link { code = "I50.30", text = "Diastolic Heart Failure Dx" }
    local i5040_code = links.get_code_link { code = "I50.40", text = "Systolic And Diastolic Heart Failure Dx" }
    local i501_code = links.get_code_link { code = "I50.1", text = "Left Ventricle Heart Failure Dx" }
    local i50810_code = links.get_code_link { code = "I50.810", text = "Right Heart Failure" }
    local nyha_func_classification_abs =
        links.get_abstraction_link { code = "NYHA_FUNCTIONAL_CLASSIFICATION", text = "NYHA Functional Classification" }
    local i5021_code = links.get_code_link { code = "I50.21", text = "Acute Systolic (Congestive)" }
    local i5022_code = links.get_code_link { code = "I50.22", text = "Chronic Systolic (Congestive)" }
    local i5023_code = links.get_code_link { code = "I50.23", text = "Acute on Chronic Systolic Heart Failure" }
    local i5031_code = links.get_code_link { code = "I50.31", text = "Acute Diastolic (Congestive)" }
    local i5032_code = links.get_code_link { code = "I50.32", text = "Chronic Diastolic (Congestive)" }
    local i5033_code = links.get_code_link { code = "I50.33", text = "Acute on Chronic Diastolic Heart Failure" }
    local i5041_code =
        links.get_code_link { code = "I50.41", text = "Acute Combined Systolic and Diastolic (Congestive)" }
    local i5042_code =
        links.get_code_link { code = "I50.42", text = "Chronic Combined Systolic and Diastolic (Congestive)" }
    local i5043_code =
        links.get_code_link { code = "I50.43", text = "Acute on Chronic Combined Systolic and Distolic Heart Failure" }
    local i50811_code = links.get_code_link { code = "I50.811", text = "Acute Right Heart Failure" }
    local i50812_code = links.get_code_link { code = "I50.812", text = "Chronic Right Heart Failure" }
    local i50813_code = links.get_code_link { code = "I50.813", text = "Acute on Chronic Right Heart Failure" }

    -- Clinical Evidence
    local r601_code = links.get_code_link { code = "R60.1", text = "Anasarca" }
    local central_venous_congestion_abs =
        links.get_abstraction_link { code = "CENTRAL_VENOUS_CONGESTION", text = "Central Venous Congestion" }
    local crackles_abs = links.get_abstraction_link { code = "CRACKLES", text = "Crackles" }
    local diastolic_dysfun_abs =
        links.get_abstraction_link { code = "DIASTOLIC_DYSFUNCTION", text = "Diastolic Dysfunction" }
    local moder_ref_abs = links.get_abstraction_link {
        code = "MODERATELY_REDUCED_EJECTION_FRACTION",
        text = "Moderately Reduced Ejection Fraction"
    }
    local reduc_ef_abs =
        links.get_abstraction_link { code = "REDUCED_EJECTION_FRACTION", text = "Reduced Ejection Fraction" }
    local e8770_code = links.get_code_link { code = "E87.70", text = "Fluid Overloaded" }
    local left_ventricle_dilation_abs =
        links.get_abstraction_link { code = "LEFT_VENTRICLE_DILATION", text = "Left Ventricle Dilation" }
    local left_ventricle_hyper_abs =
        links.get_abstraction_link { code = "LEFT_VENTRICLE_HYPERTROPHY", text = "Left Ventricle Hypertrophy" }
    local pulmonary_edema_abs = links.get_abstraction_link { code = "PULMONARY_EDEMA", text = "Pulmonary Edema" }
    local sob_lying_flat_abs =
        links.get_abstraction_link { code = "SHORTNESS_OF_BREATH_LYING_FLAT", text = "Shortness of Breath Lying Flat" }
    local systolic_dysfunction_abs =
        links.get_abstraction_link { code = "SYSTOLIC_DYSFUNCTION", text = "Systolic Dysfunction" }

    -- Laboratory Studies
    local pro_bnp_dv = links.get_discrete_value_link { dv = dv_pro_bnp, text = "Pro BNP", predicate = calc_pro_bnp1 }

    -- Medications
    local bumetanide_med =
        links.get_medication_link { cat = "Bumetanide", predicate = iv_med_predicate, text = "Bumetanide" }
    local furosemide_med =
        links.get_medication_link { cat = "Furosemide", predicate = iv_med_predicate, text = "Furosemide" }

    -- Major
    local j810_code = links.get_code_link { code = "J81.0", text = "Acute Pulmonary Edema" }
    local elvat_central_venous_press_abs =
        links.get_abstraction_link { code = "ELEVATED_CENTRAL_VENOUS_PRESSURE", text = "Central Venous Pressure" }
    local hepatojugular_reflux_abs =
        links.get_abstraction_link { code = "HEPATOJUGULAR_REFLUX", text = "Hepatojugular Reflux" }
    local jugular_vein_distention_abs =
        links.get_abstraction_link { code = "JUGULAR_VEIN_DISTENTION", text = "Jugular Vein Distention" }
    local s3_heart_sound_abs = links.get_abstraction_link { code = "S3_HEART_SOUND", text = "S3 Heart Sound" }

    -- Minor
    local dyspnea_on_exertion_abs =
        links.get_abstraction_link { code = "DYSPNEA_ON_EXERTION", text = "Dyspnea on Exertion" }
    local heart_rate_dv =
        links.get_discrete_value_link { dv = dv_heart_rate, text = "Heart Rate", predicate = calc_heart_rate1 }
    local hepatomegaly_abs = links.get_abstraction_link { code = "HEPATOMEGALY", text = "Hepatomegaly" }
    local lower_extremity_edema_abs =
        links.get_abstraction_link { code = "LOWER_EXTREMITY_EDEMA", text = "Lower Extremity Edema" }
    local nocturnal_cough_abs = links.get_abstraction_link { code = "NOCTURNAL_COUGH", text = "Nocturnal Cough" }
    local pleural_effusion_abs = links.get_abstraction_link { code = "PLEURAL_EFFUSION", text = "Pleural Effusion" }

    -- Conflicting Code Checks
    local ccc =
        (i5021_code and i5022_code and i5023_code) or
        (i5031_code and i5032_code and i5033_code) or
        (i5041_code and i5042_code and i5043_code) or
        (i50811_code and i50812_code and i50813_code)

    local ccc_two =
        (#account_alert_codes == 2 and i5021_code and i5023_code) or
        (#account_alert_codes == 2 and i5022_code and i5023_code) or
        (#account_alert_codes == 2 and i5031_code and i5033_code) or
        (#account_alert_codes == 2 and i5032_code and i5033_code)

    -- Acuity Sign Count
    local asc =
        r601_code and 1 or 0 +
        central_venous_congestion_abs and 1 or 0 +
        crackles_abs and 1 or 0 +
        e8770_code and 1 or 0 +
        pulmonary_edema_abs and 1 or 0 +
        sob_lying_flat_abs and 1 or 0 +
        pro_bnp_dv and 1 or 0 +
        j810_code and 1 or 0 +
        elvat_central_venous_press_abs and 1 or 0 +
        hepatojugular_reflux_abs and 1 or 0 +
        jugular_vein_distention_abs and 1 or 0 +
        s3_heart_sound_abs and 1 or 0 +
        dyspnea_on_exertion_abs and 1 or 0 +
        heart_rate_dv and 1 or 0 +
        hepatomegaly_abs and 1 or 0 +
        lower_extremity_edema_abs and 1 or 0 +
        nocturnal_cough_abs and 1 or 0 +
        pleural_effusion_abs and 1 or 0 +
        bumetanide_med and 1 or 0 +
        furosemide_med and 1 or 0

    treatment_and_monitoring_header:add_link(bumetanide_med)
    treatment_and_monitoring_header:add_link(furosemide_med)

    -- Type Sign Count
    local tsc =
        diastolic_dysfun_abs and 1 or 0 +
        moder_ref_abs and 1 or 0 +
        reduc_ef_abs and 1 or 0 +
        left_ventricle_dilation_abs and 1 or 0 +
        systolic_dysfunction_abs and 1 or 0 +
        left_ventricle_hyper_abs and 1 or 0



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if #account_alert_codes == 1 then
        -- 1.1
        if trigger_alert then
            for code, desc in pairs(alert_code_dictionary) do
                local temp_code = links.get_code_link { code = code, text = desc }
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

    elseif #account_alert_codes > 1 and i5021_code and i5022_code and not i5023_code then
        -- 1
        documented_dx_header:add_link(i5021_code)
        documented_dx_header:add_link(i5022_code)
        Result.subtitle = "Possible Acute on Chronic Systolic Heart Failure"
        Result.passed = true
        if existing_alert and existing_alert.validated then
            Result.validated = false
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
        end

    elseif #account_alert_codes > 1 and i5031_code and i5032_code and not i5033_code then
        -- 2
        documented_dx_header:add_link(i5031_code)
        documented_dx_header:add_link(i5032_code)
        Result.subtitle = "Possible Acute on Chronic Diastolic Heart Failure"
        Result.passed = true
        if existing_alert and existing_alert.validated then
            Result.validated = false
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
        end

    elseif #account_alert_codes > 1 and i5041_code and i5042_code and not i5043_code then
        -- 3
        documented_dx_header:add_link(i5041_code)
        documented_dx_header:add_link(i5042_code)
        Result.subtitle = "Possible Acute on Chronic Combined Systolic and Diastolic Heart Failure"
        Result.passed = true
        if existing_alert and existing_alert.validated then
            Result.validated = false
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
        end

    elseif #account_alert_codes > 1 and i50811_code and i50812_code and not i50813_code then
        -- 4
        documented_dx_header:add_link(i50811_code)
        documented_dx_header:add_link(i50812_code)
        Result.subtitle = "Possible Acute on Chronic Right Heart Failure"
        Result.passed = true
        if existing_alert and existing_alert.validated then
            Result.validated = false
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
        end

    elseif subtitle == "Conflicting Heart Failure Types" and (i5041_code or i5042_code or i5043_code) then
        -- 5.1
        documented_dx_header:add_link(i5041_code)
        documented_dx_header:add_link(i5042_code)
        documented_dx_header:add_link(i5043_code)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        #account_alert_codes > 4 or
        (#account_alert_codes == 3 and not ccc) or
        (#account_alert_codes == 2 and not ccc_two) and
        not i5041_code and
        not i5042_code and
        not i5043_code
    then
        -- 5
        for _, code in ipairs(account_alert_codes) do
            local desc = alert_code_dictionary[code]
            local temp_code = links.get_code_link { code = code, text = desc }
            documented_dx_header:add_link(temp_code)
        end
        Result.subtitle = "Conflicting Heart Failure Types"
        if existing_alert and existing_alert.validated then
            Result.validated = false
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
        end
        Result.passed = true

    elseif #account_alert_codes > 0 then
        -- 6-15.1
        if existing_alert then
            for _, code in ipairs(account_alert_codes) do
                local desc = alert_code_dictionary[code]
                local temp_code = links.get_code_link { code = code, text = desc }
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

    elseif trigger_alert and acute_heart_failure_abs and tsc > 0 then
        -- 6
        documented_dx_header:add_link(acute_heart_failure_abs)
        Result.subtitle = "Acute Heart Failure Dx Missing Type"
        Result.passed = true

    elseif trigger_alert and chronic_heart_failure_abs and tsc > 0 then
        -- 7
        documented_dx_header:add_link(chronic_heart_failure_abs)
        Result.subtitle = "Chronic Heart Failure Dx Missing Type"
        Result.passed = true

    elseif trigger_alert and acute_chronic_heart_failure_abs and tsc > 0 then
        -- 8
        documented_dx_header:add_link(acute_chronic_heart_failure_abs)
        Result.subtitle = "Acute on Chronic Heart Failure Dx Missing Type"
        Result.passed = true

    elseif trigger_alert and i509_code and (tsc > 0 or asc > 0) then
        -- 9
        documented_dx_header:add_link(i509_code)
        Result.subtitle = "Heart Failure Dx Missing Type and Acuity"
        Result.passed = true

    elseif trigger_alert and i5020_code and asc > 0 then
        -- 10
        documented_dx_header:add_link(i5020_code)
        Result.subtitle = "Systolic Heart Failure Missing Acuity"
        Result.passed = true

    elseif trigger_alert and i5030_code and asc > 0 then
        -- 11
        documented_dx_header:add_link(i5030_code)
        Result.subtitle = "Diastolic Heart Failure Missing Acuity"
        Result.passed = true

    elseif trigger_alert and i5040_code and asc > 0 then
        -- 12
        documented_dx_header:add_link(i5040_code)
        Result.subtitle = "Combined Systolic and Diastolic Heart Failure Missing Acuity"
        Result.passed = true

    elseif trigger_alert and i50810_code and asc > 0 then
        -- 13
        documented_dx_header:add_link(i50810_code)
        Result.subtitle = "Right Heart Failure Missing Acuity"
        Result.passed = true

    elseif trigger_alert and i501_code and (asc > 0 or tsc > 0) then
        -- 14
        documented_dx_header:add_link(i501_code)
        Result.subtitle = "Left Ventricle Heart Failure Missing Type and Acuity"
        Result.passed = true

    elseif
        trigger_alert and hf_codes and
        (tsc >= 3 or asc >= 3 or (tsc >= 1 and asc >= 2) or (tsc >= 2 and asc >= 1)) or
        nyha_func_classification_abs
    then
        -- 15
        if nyha_func_classification_abs then documented_dx_header:add_link(nyha_func_classification_abs) end
        Result.subtitle = "Possible Heart Failure Dx"
        Result.passed = true

    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Clinical Evidence
            clinical_evidence_header:add_code_link("R63.5", "Abnormal Weight Gain")
            clinical_evidence_header:add_link(r601_code)
            clinical_evidence_header:add_abstraction_link("ASCITES", "Ascites")
            clinical_evidence_header:add_code_links(
                { "I48.0", "I48.11", "I48.19", "I48.20", "I48.21", "I48.91" },
                "Atrial Fibrillation"
            )
            clinical_evidence_header:add_code_link("I31.4", "Cardiac Tamponade")
            clinical_evidence_header:add_code_links(
                {
                    "I25.5", "O90.3", "I42.0", "I42.1", "I42.2", "I42.3",
                    "I42.4", "I42.5", "I42.6", "I42.7", "I42.8", "I51.81"
                },
                "Cardiomyopathy"
            )
            clinical_evidence_header:add_link(central_venous_congestion_abs)
            clinical_evidence_header:add_link(crackles_abs)
            clinical_evidence_header:add_link(diastolic_dysfun_abs)
            clinical_evidence_header:add_link(moder_ref_abs)
            clinical_evidence_header:add_link(reduc_ef_abs)
            clinical_evidence_header:add_abstraction_link("PRESERVED_EJECTION_FRACTION_2", "Ejection Fraction")
            clinical_evidence_header:add_abstraction_link("PRESERVED_EJECTION_FRACTION", "Ejection Fraction")
            clinical_evidence_header:add_code_link("N18.6", "End-Stage Renal Disease")
            clinical_evidence_header:add_code_link("I38", "Endocarditis")
            clinical_evidence_header:add_code_link("R53.83", "Fatigue")
            clinical_evidence_header:add_link(e8770_code)
            clinical_evidence_header:add_abstraction_link("HEART_PALPITATIONS", "Heart Palpitations")
            clinical_evidence_header:add_code_link("I31.2", "Hemopericardium")
            clinical_evidence_header:add_abstraction_link(
                "HYPERDYNAMIC_LEFT_VENTRICLE_SYSTOLIC_FUNCTION",
                "Hyperdynamic Left Ventricular Systolic Function"
            )
            clinical_evidence_header:add_abstraction_link(
                "IMPLANTABLE_CARDIAC_ASSIST_DEVICE",
                "Implantable Cardiac Assist Device"
            )
            clinical_evidence_header:add_code_links({ "02HA3QZ", "02HA0QZ" }, "Implantable Heart Assist Device")
            clinical_evidence_header:add_abstraction_link("IRREGULAR_ECHO_FINDING", "Irregular Echo Findings")
            clinical_evidence_header:add_abstraction_link(
                "IRREGULAR_RADIOLOGY_REPORT_CARDIAC",
                "Irregular Radiology Report Cardiac"
            )
            clinical_evidence_header:add_link(left_ventricle_dilation_abs)
            clinical_evidence_header:add_link(left_ventricle_hyper_abs)
            clinical_evidence_header:add_abstraction_link(
                "NYHA_FUNCTIONAL_CLASSIFICATION",
                "NYHA Functional Classification"
            )
            clinical_evidence_header:add_code_link("I51.2", "Papillary Muscle Rupture")
            clinical_evidence_header:add_abstraction_link("PERICARDIAL_EFFUSION", "Pericardial Effusion")
            clinical_evidence_header:add_code_link("I27.20", "Pulmonary Hypertension")
            clinical_evidence_header:add_link(pulmonary_edema_abs)
            clinical_evidence_header:add_abstraction_link(
                "RIGHT_VENTRICLE_HYPERTROPHY",
                "Right Ventricle Hypertrophy"
            )
            clinical_evidence_header:add_abstraction_link(
                "SEVERE_AORTIC_VALVE_STENOSIS",
                "Severe Aortic Stenosis"
            )
            clinical_evidence_header:add_abstraction_link(
                "SEVERE_AORTIC_VALVE_REGURGITATION",
                "Severe Aortic Regurgitation"
            )
            clinical_evidence_header:add_abstraction_link(
                "SEVERE_MITRAL_VALVE_STENOSIS",
                "Severe Mitral Stenosis"
            )
            clinical_evidence_header:add_abstraction_link(
                "SEVERE_MITRAL_VALVE_REGURGITATION",
                "Severe Mitral Regurgitation"
            )
            clinical_evidence_header:add_abstraction_link(
                "SEVERE_PULMONIC_VALVE_STENOSIS",
                "Severe Pulmonic Stenosis"
            )
            clinical_evidence_header:add_abstraction_link(
                "SEVERE_PULMONIC_VALVE_REGURGITATION",
                "Severe Pulmonic Regurgitation"
            )
            clinical_evidence_header:add_abstraction_link(
                "SEVERE_TRICUSPID_VALVE_STENOSIS",
                "Severe Tricuspid Stenosis"
            )
            clinical_evidence_header:add_abstraction_link(
                "SEVERE_TRICUSPID_VALVE_REGURGITATION",
                "Severe Tricuspid Regurgitation"
            )
            clinical_evidence_header:add_link(sob_lying_flat_abs)
            clinical_evidence_header:add_code_links(
                {
                    "02HA0RJ", "02HA0RS", "02HA0RZ", "02HA3RJ", "02HA3RS",
                    "02HA3RZ", "02HA4QZ", "02HA4RJ", "02HA4RS", "02HA4RZ"
                },
                "Short-Term External Heart Assist Device"
            )

            -- Document Links
            ekg_links_header:add_document_link("ECG", "ECG")
            ekg_links_header:add_document_link("Electrocardiogram Adult   ECGR", "Electrocardiogram Adult   ECGR")
            ekg_links_header:add_document_link("ECG Adult", "ECG Adult")
            ekg_links_header:add_document_link("RestingECG", "RestingECG")
            ekg_links_header:add_document_link("EKG", "EKG")
            echo_links_header:add_document_link("ECHOTE  CVSECHOTE", "ECHOTE  CVSECHOTE")
            echo_links_header:add_document_link("ECHO 2D Comp Adult CVSECH2DECHO", "ECHO 2D Comp Adult CVSECH2DECHO")
            echo_links_header:add_document_link("Echo Complete Adult 2D", "Echo Complete Adult 2D")
            echo_links_header:add_document_link("Echo Comp W or WO Contrast", "Echo Comp W or WO Contrast")
            echo_links_header:add_document_link("ECHO Stress ECHO  CVSECHSTR", "ECHO Stress ECHO  CVSECHSTR")
            echo_links_header:add_document_link("Stress Echocardiogram CVS", "Stress Echocardiogram CVS")
            echo_links_header:add_document_link("CVSECH2ECHO", "CVSECH2ECHO")
            echo_links_header:add_document_link("CVSECHOTE", "CVSECHOTE")
            echo_links_header:add_document_link("CVSECHORECHO", "CVSECHORECHO")
            echo_links_header:add_document_link("CVSECH2DECHOLIMITED", "CVSECH2DECHOLIMITED")
            echo_links_header:add_document_link("CVSECHOPC", "CVSECHOPC")
            echo_links_header:add_document_link("CVSECHSTRAINECHO", "CVSECHSTRAINECHO")
            heart_cath_links_header:add_document_link("Heart Cath", "Heart Cath")
            heart_cath_links_header:add_document_link("Cath Report", "Cath Report")
            heart_cath_links_header:add_document_link(
                "Cardiac Cath, PTCA, EP findings",
                "Cardiac Cath, PTCA, EP findings"
            )
            heart_cath_links_header:add_document_link("CATHEOC", "CATHEOC")
            heart_cath_links_header:add_document_link("Cath Lab Procedures", "Cath Lab Procedures")

            -- Labs
            laboratory_studies_header:add_link(pro_bnp_dv)
            laboratory_studies_header:add_discrete_value_one_of_link(
                dv_troponin_t,
                "Troponin T High Sensitivity: [VALUE] (Result Date: [RESULTDATETIME])",
                calc_troponin_t1
            )

            -- Medication
            treatment_and_monitoring_header:add_medication_link("Ace Inhibitor", "Ace Inhibitor")
            treatment_and_monitoring_header:add_abstraction_link("ACE_INHIBITORS", "Ace Inhibitor")
            treatment_and_monitoring_header:add_medication_link(
                "Angiotensin II Receptor Blocker",
                "Angiotensin II Receptor Blocker"
            )
            treatment_and_monitoring_header:add_abstraction_link(
                "ANGIOTENSIN_II_RECEPTOR_BLOCKERS",
                "Angiotensin II Receptor Blocker"
            )
            treatment_and_monitoring_header:add_medication_link(
                "Angiotensin Receptor Neprilysin Inhibitor",
                "Angiotensin Receptor Neprilysin Inhibitor"
            )
            treatment_and_monitoring_header:add_abstraction_link(
                "ANGIOTENSIN_RECEPTOR_NEPRILYSIN_INHIBITORS",
                "Angiotensin Receptor Neprilysin Inhibitors"
            )
            treatment_and_monitoring_header:add_medication_link("Antianginal Medication", "Antianginal Medication")
            treatment_and_monitoring_header:add_abstraction_link("ANTIANGINAL_MEDICATION", "Antianginal Medication")
            treatment_and_monitoring_header:add_medication_link("Beta Blocker", "Beta Blocker", iv_med_predicate)
            treatment_and_monitoring_header:add_abstraction_link("BETA_BLOCKER", "Beta Blocker")

            -- 11
            treatment_and_monitoring_header:add_abstraction_link("BUMETANIDE", "Bumetanide")
            treatment_and_monitoring_header:add_medication_link(
                "Calcium Channel Blockers",
                "Calcium Channel Blockers",
                iv_med_predicate
            )
            treatment_and_monitoring_header:add_abstraction_link("CALCIUM_CHANNEL_BLOCKER", "Calcium Channel Blocker")
            treatment_and_monitoring_header:add_medication_link("Digitalis", "Digitalis")
            treatment_and_monitoring_header:add_abstraction_link("DIGOXIN", "Digoxin")
            treatment_and_monitoring_header:add_medication_link("Diuretic", "Diuretic")
            treatment_and_monitoring_header:add_abstraction_link("DIURETIC", "Diuretic")
            treatment_and_monitoring_header:add_medication_link("Epinephrine", "Epinephrine", anesthesia_predicate)
            treatment_and_monitoring_header:add_abstraction_link("EPINEPHRINE", "Epinephrine")

            -- 21
            treatment_and_monitoring_header:add_abstraction_link("FUROSEMIDE", "Furosemide")
            treatment_and_monitoring_header:add_medication_link("Hydralazine", "Hydralazine")
            treatment_and_monitoring_header:add_abstraction_link(
                "HYDRALAZINE_ISOSORBIDE_AND_DINITRATE",
                "Hydralazine Isosorbide and Dinitrate"
            )
            treatment_and_monitoring_header:add_medication_link("Levophed", "Levophed", anesthesia_predicate)
            treatment_and_monitoring_header:add_abstraction_link("LEVOPHED", "Levophed")
            treatment_and_monitoring_header:add_medication_link("Milrinone", "Milrinone")
            treatment_and_monitoring_header:add_abstraction_link("MILRINONE", "Milrinone")
            treatment_and_monitoring_header:add_medication_link("Neosynephrine", "Neosynephrine", anesthesia_predicate)
            treatment_and_monitoring_header:add_abstraction_link("NEOSYNEPHRINE", "Neosynephrine")
            treatment_and_monitoring_header:add_medication_link("Nitroglycerin", "Nitroglycerin")
            treatment_and_monitoring_header:add_abstraction_link("NITROGLYCERIN", "Nitroglycerin")
            treatment_and_monitoring_header:add_medication_link("Sodium Nitroprusside", "Sodium Nitroprusside")
            treatment_and_monitoring_header:add_abstraction_link("SODIUM_NITROPRUSSIDE", "Sodium Nitroprusside")
            treatment_and_monitoring_header:add_abstraction_link("VASOACTIVE_MEDICATION", "Vasoactive Medication")
            treatment_and_monitoring_header:add_medication_link("Vasopressin", "Vasopressin", anesthesia_predicate)
            treatment_and_monitoring_header:add_abstraction_link("VASOPRESSIN", "Vasopressin")

            -- Vitals
            vitals_header:add_abstraction_link(
                "ELEVATED_RIGHT_VENTRICLE_SYSTOLIC_PRESSURE",
                "Right Ventricle Systolic Pressure"
            )

            -- Frame Major Criteria
            framingham_major_header:add_link(j810_code)
            framingham_major_header:add_code_link("I51.7", "Cardiomegaly")
            framingham_major_header:add_discrete_value_one_of_link(
                dv_central_venous_pressure,
                "Elevated Central Venous Pressure",
                calc_central_venous_pressure1
            )
            framingham_major_header:add_link(elvat_central_venous_press_abs)
            framingham_major_header:add_link(hepatojugular_reflux_abs)
            framingham_major_header:add_link(jugular_vein_distention_abs)
            framingham_major_header:add_abstraction_link(
                "PAROXYSMAL_NOCTURNAL_DYSPNEA",
                "Paroxysmal Nocturnal Dyspnea"
            )
            framingham_major_header:add_abstraction_link("RALES", "Rales")
            framingham_major_header:add_link(s3_heart_sound_abs)

            -- Framingham Minor Criteria
            framingham_minor_header:add_link(dyspnea_on_exertion_abs)
            framingham_minor_header:add_link(heart_rate_dv)
            framingham_minor_header:add_link(hepatomegaly_abs)
            framingham_minor_header:add_link(lower_extremity_edema_abs)
            framingham_minor_header:add_link(nocturnal_cough_abs)
            framingham_minor_header:add_link(pleural_effusion_abs)
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

