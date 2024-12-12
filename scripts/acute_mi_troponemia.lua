---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Acute MI with Troponemia
---
--- This script checks an account to see if it matches the criteria for an Acute MI with Troponemia alert.
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
local discrete = require("libs.common.discrete_values")(Account)



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
--- @diagnostic disable: unused-local
local heart_rate_dv_names = {
    "Heart Rate cc (bpm)",
    "3.5 Heart Rate (Apical) (bpm)",
    "3.5 Heart Rate (Other) (bpm)",
    "3.5 Heart Rate (Radial) (bpm)",
    "SCC Monitor Pulse (bpm)"
}
local high_heart_rate_predicate = function(dv, num) return num > 90 end
local low_heart_rate_predicate = function(dv, num) return num < 60 end
local hematocrit_dv_names = { "HEMATOCRIT (%)", "HEMATOCRIT" }
local female_low_hematocrit_predicate = function(dv, num) return num < 34 end
local male_low_hematocrit_predicate = function(dv, num) return num < 40 end
local hemogloblin_dv_names = { "HEMOGLOBIN (g/dL)", "HEMOGLOBIN" }
local male_low_hemoglobin_predicate = function(dv, num) return num < 13.5 end
local female_low_hemoglobin_predicate = function(dv, num) return num < 11.6 end
local map_dv_names = { "MAP Non-Invasive (Calculated) (mmHg)", "MPA Invasive (mmHg)" }
local low_map_predicate = function(dv, num) return num < 70 end
local oxygen_dv_names = { "DELIVERY" }
local pao2_dv_names = { "BLD GAS O2 (mmHg)", "PO2 (mmHg)" }
local low_pao21_predicate = function(dv, num) return num < 80 end
local sbp_dv_names = { "SBP 3.5 (No Calculation) (mmHg)" }
local low_sbp_predicate = function(dv, num) return num < 90 end
local high_sbp_predicate = function(dv, num) return num > 180 end
local spo2_dv_names = { "Pulse Oximetry(Num) (%)" }
local low_spo21_predicate = function(dv, num) return num < 90 end
local troponin_dv_names = { "TROPONIN, HIGH SENSITIVITY (ng/L)" }
local high_troponin_predicate = function(dv, num) return num > 59 end
--- @diagnostic enable: unused-local



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }



--------------------------------------------------------------------------------
--- Additional Pre-conditions
--------------------------------------------------------------------------------
local stemicode_dictionary = {
    ["I21.01"] = "ST Elevation (STEMI) Myocardial Infarction Involving Left Main Coronary Artery",
    ["I21.02"] = "ST Elevation (STEMI) Myocardial Infarction Involving Left Anterior Descending Coronary Artery",
    ["I21.09"] = "ST Elevation (STEMI) Myocardial Infarction Involving Other Coronary Artery Of Anterior Wall",
    ["I21.11"] = "ST Elevation (STEMI) Myocardial Infarction Involving Right Coronary Artery",
    ["I21.19"] = "ST Elevation (STEMI) Myocardial Infarction Involving Other Coronary Artery Of Inferior Wall",
    ["I21.21"] = "ST Elevation (STEMI) Myocardial Infarction Involving Left Circumflex Coronary Artery",
    ["I21.29"] = "ST Elevation (STEMI) Myocardial Infarction Involving Other Sites",
    ["I21.3"] = "ST Elevation (STEMI) Myocardial Infarction of Unspecified Site"
}
local other_code_dictionary = {
    ["I21.A1"] = "Myocardial Infarction Type 2",
    ["I21.A9"] = "Other Myocardial Infarction Type",
    ["I21.B"] = "Myocardial Infarction with Coronary Microvascular Dysfunction",
    ["I5A"] = "Non-Ischemic Myocardial Injury (Non-Traumatic)",
}
local account_stemi_codes = codes.get_account_codes_in_dictionary(stemicode_dictionary, Account)
local account_other_codes = codes.get_account_codes_in_dictionary(other_code_dictionary, Account)

local i214_code_link = links.get_code_links { code = "I21.4", text = "Non-ST Elevation (NSTEMI) Myocardial Infarction" }
local code_count = 0
if #account_stemi_codes > 0 then
    code_count = code_count + 1
end
if #account_other_codes > 0 then
    code_count = code_count + 1
end
if i214_code_link then
    code_count = code_count + 1
end
local trigger_alert = not existing_alert or (existing_alert.outcome ~= "AUTORESOLVED" and existing_alert.reason ~= "Previously Autoresolved")



if
    (not existing_alert or not existing_alert.validated) or
    (not existing_alert and existing_alert.outcome == "AUTORESOLVED" and existing_alert.validated and code_count > 0)
then
    --------------------------------------------------------------------------------
    --- Header Variables and Helper Functions
    --------------------------------------------------------------------------------
    local result_links = {}
    local documented_dx_header = headers.make_header_builder("Documented Dx", 1)
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 2)
    local vital_signs_intake_header = headers.make_header_builder("Vital Signs/Intake", 3)
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 4)
    local oxygenation_ventillation_header = headers.make_header_builder("Oxygenation/Ventilation", 5)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 5)
    local ekg_header = headers.make_header_builder("EKG", 6)
    local echo_header = headers.make_header_builder("Echo", 7)
    local ct_header = headers.make_header_builder("CT", 8)
    local heart_cath_header = headers.make_header_builder("Heart Cath", 9)
    local troponin_header = headers.make_header_builder("Troponin", 10)

    local function compile_links()
        laboratory_studies_header:add_link(troponin_header:build(true))

        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, vital_signs_intake_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))
        table.insert(result_links, oxygenation_ventillation_header:build(true))
        table.insert(result_links, ekg_header:build(true))
        table.insert(result_links, echo_header:build(true))
        table.insert(result_links, ct_header:build(true))
        table.insert(result_links, heart_cath_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Documented Dx
    local i219_code_link = links.get_code_link { code = "I21.9", text = "Acute Myocardial Infarction Unspecified" }
    local i21a1_code_link = links.get_code_link { code = "I21.A1", text = "Myocardial Infarction Type 2" }

    -- Clinical Evidence (Abstractions)
    local r07_code_link = links.get_code_link { codes = { "R07.89", "R07.9" }, text = "Chest Pain" } or {}
    local i2489_code_link = links.get_code_link { code = "I24.89", text = "Demand Ischemia" }
    local irregular_ekg_findings_abstraction_link = links.get_abstraction_link { code = "IRREGULAR_EKG_FINDINGS_MI", text = "Irregular EKG Finding" }

    -- Medications
    local antiplatlet2_medication_link = links.get_medication_link { cat = "Antiplatelet 2", text = "" }
    local aspirin_medication_link = links.get_medication_link { cat = "Aspirin", text = "" }
    local heparin_medication_link = links.get_medication_link { cat = "Heparin", text = "" }
    local morphine_medication_link = links.get_medication_link { cat = "Morphine", text = "" }
    local nitroglycerin_medication_link = links.get_medication_link { cat = "Nitroglycerin", text = "" }

    -- Laboratory Studies
    troponin_header:add_link(
        discrete.GetDvValuesAsSingleLink {
            account = Account,
            dvNames = troponin_dv_names,
            linkText = "Troponin T High Sensitivity: (DATE1, DATE2) - ",
        }
    )
    local high_troponin_discrete_value_links = links.get_discrete_value_links {
        dvNames = troponin_dv_names,
        text = "Elevated Troponin",
        predicate = high_troponin_predicate,
        maxPerValue = 10
    }



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if code_count == 1 and not i2489_code_link and Result.passed then
        -- Autresolve
        if #account_stemi_codes > 0 then
            local desc = stemicode_dictionary[account_stemi_codes[1]]
            local code_link = links.get_code_link {
                code = account_stemi_codes[1],
                text = "Autoresolved Specified Code - " .. desc
            }
            documented_dx_header:add_link(code_link)
        end
        if #account_other_codes > 0 then
            local desc = other_code_dictionary[account_other_codes[1]]
            local code_link = links.get_code_link {
                code = account_other_codes[1],
                text = "Autoresolved Specified Code - " .. desc
            }
            documented_dx_header:add_link(code_link)
        end
        if i214_code_link then
            documented_dx_header:add_link(i214_code_link)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif code_count > 1 then
        -- Alert Acute MI Conflicting Dx
        if #account_stemi_codes > 0 then
            local desc = stemicode_dictionary[account_stemi_codes[1]]
            local code_link = links.get_code_link {
                code = account_stemi_codes[1],
                text = "Autoresolved Specified Code - " .. desc
            }
            documented_dx_header:add_link(code_link)
        end
        if #account_other_codes > 0 then
            local desc = other_code_dictionary[account_other_codes[1]]
            local code_link = links.get_code_link {
                code = account_other_codes[1],
                text = "Autoresolved Specified Code - " .. desc
            }
            documented_dx_header:add_link(code_link)
        end
        if i214_code_link then
            documented_dx_header:add_link(i214_code_link)
        end
        if existing_alert and existing_alert.validated then
            Result.validated = false
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
        end
        Result.subtitle = "Acute MI Conflicting Dx"
        Result.passed = true

    elseif trigger_alert and i21a1_code_link and i2489_code_link then
        -- Alert Acute MI Type 2 and Demand Ischemia Documented Seek Clarification
        documented_dx_header:add_link(i21a1_code_link)
        documented_dx_header:add_link(i2489_code_link)
        Result.subtitle = "Acute MI Type 2 and Demand Ischemia Documented Seek Clarification"
        Result.passed = true

    elseif
        trigger_alert and
        code_count == 0 and
        (
            (#high_troponin_discrete_value_links > 0) or
            i219_code_link
        ) and
        i2489_code_link
    then
        -- Alert Possible Acute MI Type 2
        documented_dx_header:add_link(i2489_code_link)
        documented_dx_header:add_link(i219_code_link)
        Result.subtitle = "Possible Acute MI Type 2"
        Result.passed = true

    elseif trigger_alert and code_count > 0 and i2489_code_link then
        -- Alert Acute MI Type Needs Clarification
        documented_dx_header:add_link(i2489_code_link)
        if #account_stemi_codes > 0 then
            local desc = stemicode_dictionary[account_stemi_codes[1]]
            local code_link = links.get_code_link {
                code = account_stemi_codes[1],
                text = "Autoresolved Specified Code - " .. desc
            }
            documented_dx_header:add_link(code_link)
        end
        if #account_other_codes > 0 then
            local desc = other_code_dictionary[account_other_codes[1]]
            local code_link = links.get_code_link {
                code = account_other_codes[1],
                text = "Autoresolved Specified Code - " .. desc
            }
            documented_dx_header:add_link(code_link)
        end
        documented_dx_header:add_link(i214_code_link)
        Result.subtitle = "Acute MI Type Needs Clarification"
        Result.passed = true

    elseif trigger_alert and i219_code_link then
        -- Alert Acute MI Unspecified Present Confirm if Further Specification of Type Needed
        documented_dx_header:add_link(i219_code_link)
        Result.subtitle = "Acute MI Unspecified Present Confirm if Further Specification of Type Needed"
        Result.passed = true

    elseif trigger_alert and #high_troponin_discrete_value_links > 0 and irregular_ekg_findings_abstraction_link then
        -- Alert Possible Acute MI
        Result.subtitle = "Possible Acute MI"
        Result.passed = true

    elseif
        trigger_alert and
        (r07_code_link or #high_troponin_discrete_value_links > 0) and
        heparin_medication_link and
        (morphine_medication_link or nitroglycerin_medication_link) and
        aspirin_medication_link and
        antiplatlet2_medication_link
    then
        -- Alert Possible Acute MI
        treatment_and_monitoring_header:add_link(heparin_medication_link)
        Result.subtitle = "Possible Acute MI"
        Result.passed = true

    elseif trigger_alert and #high_troponin_discrete_value_links > 0 then
        -- Alert Elevanted Tropins Present
        Result.subtitle = "Elevanted Tropins Present"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Clinical Evidence
            clinical_evidence_header:add_code_link("R94.39", "Abnormal Cardiovascular Function Study")
            clinical_evidence_header:add_code_link("D62", "Acute Blood Loss Anemia")
            clinical_evidence_header:add_code_link("I24.81", "Acute Coronary microvascular Dysfunction")
            clinical_evidence_header:add_code_links({ "N17.0", "N17.1", "N17.2", "K76.7", "K91.83" }, "Acute Kidney Failure")
            clinical_evidence_header:add_code_link("I20.9", "Angina")
            clinical_evidence_header:add_code_link("I20.81", "Angina Pectoris with Coronary Microvascular Dysfunction")
            clinical_evidence_header:add_code_link("I20.1", "Angina Pectoris with Documented Spasm/with Coronary Vasospasm")
            clinical_evidence_header:add_abstraction_link("ATRIAL_FIBRILLATION_WITH_RVR", "Atrial Fibrillation with RVR")
            clinical_evidence_header:add_code_link("I46.9", "Cardiac Arrest, Cause Unspecified")
            clinical_evidence_header:add_code_link("I46.8", "Cardiac Arrest Due to Other Underlying Condition")
            clinical_evidence_header:add_code_link("I46.2", "Cardiac Arrest due to Underlying Cardiac Condition")
            clinical_evidence_header:add_code_prefix_link("I42%.", "Cardiomyopathy Dx")
            clinical_evidence_header:add_code_prefix_link("I43%.", "Cardiomyopathy Dx")
            clinical_evidence_header:add_link(r07_code_link)
            clinical_evidence_header:add_code_link("I25.85", "Chronic Coronary Microvascular Dysfunction")
            clinical_evidence_header:add_code_links(
                { "N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5" },
                "Chronic Kidney Failure"
            )
            clinical_evidence_header:add_code_link("I44.2", "Complete Heart Block")
            clinical_evidence_header:add_code_link("J44.1", "COPD Exacerbation")
            clinical_evidence_header:add_code_link("Z98.61", "Coronary Angioplasty Hx")
            clinical_evidence_header:add_code_link("Z95.5", "Coronary Angioplasty Implant and Graft Hx")
            clinical_evidence_header:add_code_link("I25.10", "Coronary Artery Disease")
            clinical_evidence_header:add_code_link("I25.119", "Coronary Artery Disease with Angina")
            clinical_evidence_header:add_code_links(
                {
                    "270046", "027004Z", "0270056", "027005Z", "0270066", "027006Z", "0270076", "027007Z",
                    "02700D6", "02700DZ", "02700E6", "02700EZ", "02700F6", "02700FZ", "02700G6", "02700GZ",
                    "02700T6", "02700TZ", "02700Z6", "02700ZZ", "0271046", "027104Z", "0271056", "027105Z",
                    "0271066", "027106Z", "0271076", "027107Z", "02710D6", "02710DZ", "02710E6", "02710EZ",
                    "02710F6", "02710FZ", "02710G6", "02710GZ", "02710T6", "02710TZ", "02710Z6", "02710ZZ",
                    "0272046", "027204Z", "0272056", "027205Z", "0272066", "027206Z", "0272076", "027207Z",
                    "02720D6", "02720DZ", "02720E6", "02720EZ", "02720F6", "02720FZ", "02720G6", "02720GZ",
                    "02720T6", "02720TZ", "02720Z6", "02720ZZ", "0273046", "027304Z", "0273056", "027305Z",
                    "0273066", "027306Z", "0273076", "027307Z", "02730D6", "02730DZ", "02730E6", "02730EZ",
                    "02730F6", "02730FZ", "02730G6", "02730GZ", "02730T6", "02730TZ", "02730Z6", "02730ZZ"
                },
                "Dilation of Coronary Artery"
            )
            clinical_evidence_header:add_abstraction_link("DYSPNEA_ON_EXERTION", "Dyspnea On Exertion")
            clinical_evidence_header:add_abstraction_link("PRESERVED_EJECTION_FRACTION", "Ejection Fraction")
            clinical_evidence_header:add_abstraction_link("PRESERVED_EJECTION_FRACTION_2", "Ejection Fraction")
            clinical_evidence_header:add_abstraction_link("REDUCED_EJECTION_FRACTION", "Ejection Fraction")
            clinical_evidence_header:add_abstraction_link("MODERATELY_REDUCED_EJECTION_FRACTION", "Ejection Fraction")
            clinical_evidence_header:add_abstraction_link("ELEVATED_TROPONINS", "Elevated Tropinins")
            clinical_evidence_header:add_code_link("N18.6", "End-Stage Renal Disease")
            clinical_evidence_header:add_code_prefix_link("I38%.", "Endocarditis Dx")
            clinical_evidence_header:add_code_prefix_link("I39%.", "Endocarditis Dx")
            clinical_evidence_header:add_code_links(
                {
                    "I50.1", "I50.20", "I50.22", "I50.23", "I50.30", "I50.32", "I50.33", "I50.40", "I50.42", "I50.43",
                    "I50.810", "I50.812", "I50.813", "I50.84", "I50.89", "I50.9"
                },
                "Heart Failure"
            )
            clinical_evidence_header:add_code_link("Z95.1", "History of CABG")
            clinical_evidence_header:add_code_link("I16.1", "Hypertensive Emergency")
            clinical_evidence_header:add_code_link("I16.0", "Hypertensive Urgency")
            clinical_evidence_header:add_code_link("E86.1", "Hypovolemia")
            clinical_evidence_header:add_code_link("R09.02", "Hypoxemia")
            clinical_evidence_header:add_code_link("I47.11", "Inappropriate Sinus Tachycardia, So Stated")
            clinical_evidence_header:add_abstraction_link("IRREGULAR_ECHO_FINDING", "Irregular Echo Finding")
            clinical_evidence_header:add_code_link("R94.31", "Irregular Echo Finding")
            clinical_evidence_header:add_link(irregular_ekg_findings_abstraction_link)
            clinical_evidence_header:add_code_link("44A023N7", "Left Heart Cath")
            clinical_evidence_header:add_code_prefix_link("I40%.", "Myocarditis Dx")
            clinical_evidence_header:add_code_link("I35.0", "Non-Rheumatic Aortic Valve Stenosis")
            clinical_evidence_header:add_code_link("I35.1", "Non-Rheumatic Aortic Valve Insufficiency")
            clinical_evidence_header:add_code_link("I35.2", "Non-Rheumatic Aortic Valve Stenosis with Insufficiency")
            clinical_evidence_header:add_code_link("I25.2", "Old MI")
            clinical_evidence_header:add_code_link("I20.8", "Other Angina Pectoris")
            clinical_evidence_header:add_code_link("I47.19", "Other Supraventricular Tachycardia")
            clinical_evidence_header:add_code_prefix_link("I47%.", "Paroxysmal Tachycardia Dx")
            clinical_evidence_header:add_code_prefix_link("I30%.", "Pericarditis Dx")
            clinical_evidence_header:add_code_prefix_link("I26%.", "Pulmonary Embolism Dx")
            clinical_evidence_header:add_code_links(
                { "I27.0", "I27.20", "I27.21", "I27.22", "I27.23", "I27.24", "I27.29" },
                "Pulmonary Hypertension"
            )
            clinical_evidence_header:add_code_links(
                {
                    "0270346", "027034Z", "0270356", "027035Z", "0270366", "027036Z", "02730376", "027037Z",
                    "02703D6", "02703DZ", "02703E6", "02703EZ", "02703F6", "02703FZ", "02703G6", "02703GZ",
                    "02703T6", "02703TZ", "02703Z6", "02703ZZ", "0271346", "027134Z", "0271356", "027135Z",
                    "0271366", "027136Z", "0271376", "027137Z", "02713D6", "02713DZ", "02713E6", "02713EZ",
                    "02713F6", "02713FZ", "02713G6", "02713GZ", "02713T6", "02713TZ", "02713Z6", "02713ZZ",
                    "0272346", "027234Z", "0272356", "027235Z", "0272366", "027236Z", "0272376", "027237Z",
                    "02723D6", "02723DZ", "02723E6", "02723EZ", "02723F6", "02723FZ", "02723G6", "02723GZ",
                    "02723T6", "02723TZ", "02723Z6", "02723ZZ", "0273346", "027334Z", "0273356", "027335Z",
                    "0273366", "027336Z", "0273376", "027337Z", "02733D6", "02733DZ", "02733E6", "02733EZ",
                    "02733F6", "02733FZ", "02733G6", "02733GZ", "02733T6", "02733TZ", "02733Z6", "02733ZZ"
                },
                "Percutaneous Coronary Intervention"
            )
            clinical_evidence_header:add_code_links({ "M62.82", "T79.6XXA", "T79.6XXD", "T79.6XXS" }, "Rhabdomyolysis")
            clinical_evidence_header:add_code_link("4A023N6", "Right Heart Cath")
            clinical_evidence_header:add_code_link("I20.2", "Refractory Angina Pectoris")
            clinical_evidence_header:add_abstraction_link("RESOLVING_TROPONINS", "Resolving Troponins")
            clinical_evidence_header:add_code_prefix_link("A40%.", "Sepsis Dx")
            clinical_evidence_header:add_code_prefix_link("A41%.", "Sepsis Dx")
            clinical_evidence_header:add_code_links(
                {
                    "A42.7", "A22.7", "B37.7", "A26.7", "A54.86", "B00.7", "A32.7", "A24.1", "A20.7", "R65.20",
                    "R65.21", "T81.44XA", "T81.44XD", "T81.44XS"
                },
                "Sepsis Dx"
            )
            clinical_evidence_header:add_abstraction_link("SHORTNESS_OF_BREATH", "Shortness of Breath")
            clinical_evidence_header:add_code_link("I47.10", "Supraventricular Tachycardia, Unspecified")
            clinical_evidence_header:add_code_link("I51.81", "Takotsubo Syndrome")
            clinical_evidence_header:add_code_link("I25.82", "Total Occlusion of Coronary Artery")
            clinical_evidence_header:add_code_links({ "I35.8", "I35.9" }, "Unspecified Non-Rheumatic Aortic Valve Disorders")
            clinical_evidence_header:add_code_link("I20.0", "Unstable Angina")
            clinical_evidence_header:add_code_link("I49.01", "Ventricular Fibrillation")
            clinical_evidence_header:add_code_link("I49.02", "Ventricular Flutter")
            clinical_evidence_header:add_abstraction_link("WALL_MOTION_ABNORMALITIES", "Wall Motion Abnormalities")

            -- EKG/Echo/HeartCath/CT Document Links
            ekg_header:add_document_link("ECG", "ECG")
            ekg_header:add_document_link("Electrocardiogram Adult   ECGR", "Electrocardiogram Adult   ECGR")
            ekg_header:add_document_link("ECG Adult", "ECG Adult")
            ekg_header:add_document_link("RestingECG", "RestingECG")
            ekg_header:add_document_link("EKG", "EKG")

            echo_header:add_document_link("ECHO  CVSECHOTE", "ECHO  CVSECHOTE")
            echo_header:add_document_link("ECHO 2D Comp Adult CVSECH2DECHO", "ECHO 2D Comp Adult CVSECH2DECHO")
            echo_header:add_document_link("Echo Complete Adult 2D", "Echo Complete Adult 2D")
            echo_header:add_document_link("Echo Comp W or WO Contrast", "Echo Comp W or WO Contrast")
            echo_header:add_document_link("ECHO Stress ECHO  CVSECHSTR", "ECHO Stress ECHO  CVSECHSTR")
            echo_header:add_document_link("Stress Echocardiogram CVS", "Stress Echocardiogram CVS")
            echo_header:add_document_link("CVSECH2DECHO", "CVSECH2DECHO")
            echo_header:add_document_link("CVSECHOTE", "CVSECHOTE")
            echo_header:add_document_link("CVSECHORECHO", "CVSECHORECHO")
            echo_header:add_document_link("CVSECH2DECHOLIMITED", "CVSECH2DECHOLIMITED")
            echo_header:add_document_link("CVSECHOPC", "CVSECHOPC")
            echo_header:add_document_link("CVSECHSTRAINECHO", "CVSECHSTRAINECHO")

            heart_cath_header:add_document_link("Heart Cath", "Heart Cath")
            heart_cath_header:add_document_link("Cath Report", "Cath Report")
            heart_cath_header:add_document_link("Cardiac Cath, PTCA, EP findings", "Cardiac Cath, PTCA, EP findings")
            heart_cath_header:add_document_link("CATHEOC", "CATHEOC")
            heart_cath_header:add_document_link("Cath Lab Procedures", "Cath Lab Procedures")

            ct_header:add_document_link("CT Thorax W", "CT Thorax W")
            ct_header:add_document_link("CTA Thorax Aorta", "CTA Thorax Aorta")
            ct_header:add_document_link("CT Thorax WO-Abd WO-Pel WO", "CT Thorax WO-Abd WO-Pel WO")
            ct_header:add_document_link("CT Thorax WO", "CT Thorax WO")

            -- Labs
            laboratory_studies_header:add_discrete_value_one_of_link(
                hemogloblin_dv_names,
                "Hemoglobin",
                (not Account.patient or Account.patient.gender == "F") and
                female_low_hemoglobin_predicate or
                male_low_hemoglobin_predicate
            )
            laboratory_studies_header:add_discrete_value_one_of_link(
                hematocrit_dv_names,
                "Hematocrit",
                (not Account.patient or Account.patient.gender == "F") and
                female_low_hematocrit_predicate or
                male_low_hematocrit_predicate
            )

            -- Lab Subheadings
            troponin_header:add_links(high_troponin_discrete_value_links)

            -- Medications
            treatment_and_monitoring_header:add_medication_link("Ace Inhibitor", "ACE Inhibitor", nil)
            treatment_and_monitoring_header:add_medication_link("Antianginal Medication", "Antianginal Medication", nil)
            treatment_and_monitoring_header:add_abstraction_link("ANTIANGINAL_MEDICATION", "Antianginal Medication")
            treatment_and_monitoring_header:add_medication_link("Anticoagulant", "Anticoagulant", nil)
            treatment_and_monitoring_header:add_abstraction_link("ANTICOAGULANT", "Anticoagulant")
            treatment_and_monitoring_header:add_medication_link("Antiplatelet", "Antiplatelet", nil)
            treatment_and_monitoring_header:add_link(antiplatlet2_medication_link)
            treatment_and_monitoring_header:add_abstraction_link("ANTIPLATELET", "Antiplatelet")
            treatment_and_monitoring_header:add_link(aspirin_medication_link)
            treatment_and_monitoring_header:add_medication_link("Beta Blocker", "Beta Blocker", nil)
            treatment_and_monitoring_header:add_abstraction_link("BETA_BLOCKER", "Beta Blocker")
            treatment_and_monitoring_header:add_medication_link("Calcium Channel Blockers", "Calcium Channel Blockers", nil)
            treatment_and_monitoring_header:add_abstraction_link("CALCIUM_CHANNEL_BLOCKER", "Calcium Channel Blockers")
            treatment_and_monitoring_header:add_link(morphine_medication_link)
            treatment_and_monitoring_header:add_link(nitroglycerin_medication_link)
            treatment_and_monitoring_header:add_abstraction_link("NITROGLYCERIN", "Nitroglycerin")
            treatment_and_monitoring_header:add_medication_link("Statin", "Statin", nil)
            treatment_and_monitoring_header:add_abstraction_link("STATIN", "Statin")

            -- Oxygen
            oxygenation_ventillation_header:add_discrete_value_one_of_link(
                oxygen_dv_names,
                "Oxygen Therapy",
                ---@diagnostic disable-next-line: unused-local
                function(dv, num)
                    return dv.result:find("%bRoom Air%b") ~= nil and dv.result:find("%bRA%b") == nil
                end
            )
            oxygenation_ventillation_header:add_abstraction_link("OXYGEN_THERAPY", "Oxygen Therapy")

            -- Vitals
            vital_signs_intake_header:add_discrete_value_one_of_link(pao2_dv_names, "Arterial P02", low_pao21_predicate)
            vital_signs_intake_header:add_discrete_value_one_of_link(heart_rate_dv_names, "Heart Rate", high_heart_rate_predicate)
            vital_signs_intake_header:add_discrete_value_one_of_link(heart_rate_dv_names, "Heart Rate", low_heart_rate_predicate)
            vital_signs_intake_header:add_discrete_value_one_of_link(map_dv_names, "MAP", low_map_predicate)
            vital_signs_intake_header:add_discrete_value_one_of_link(spo2_dv_names, "Sp02", low_spo21_predicate)
            vital_signs_intake_header:add_discrete_value_one_of_link(sbp_dv_names, "SBP", low_sbp_predicate)
            vital_signs_intake_header:add_discrete_value_one_of_link(sbp_dv_names, "SBP", high_sbp_predicate)
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end
