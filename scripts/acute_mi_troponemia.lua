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
local alerts = require("libs.common.alerts")
local links = require("libs.common.basic_links")
local codes = require("libs.common.codes")
local discrete = require("libs.common.discrete_values")



--------------------------------------------------------------------------------
--- Setup
--------------------------------------------------------------------------------
local heart_rate_dv_names = {
    "Heart Rate cc (bpm)",
    "3.5 Heart Rate (Apical) (bpm)",
    "3.5 Heart Rate (Other) (bpm)",
    "3.5 Heart Rate (Radial) (bpm)",
    "SCC Monitor Pulse (bpm)"
}
local high_heart_rate_predicate = function(dv) return discrete.get_dv_value_number(dv) > 90 end
local low_heart_rate_predicate = function(dv) return discrete.get_dv_value_number(dv) < 60 end
local hematocrit_dv_names = { "HEMATOCRIT (%)", "HEMATOCRIT" }
local female_low_hematocrit_predicate = function(dv) return discrete.get_dv_value_number(dv) < 34 end
local male_low_hematocrit_predicate = function(dv) return discrete.get_dv_value_number(dv) < 40 end
local hemogloblin_dv_names = { "HEMOGLOBIN (g/dL)", "HEMOGLOBIN" }
local male_low_hemoglobin_predicate = function(dv) return discrete.get_dv_value_number(dv) < 13.5 end
local female_low_hemoglobin_predicate = function(dv) return discrete.get_dv_value_number(dv) < 11.6 end
local map_dv_names = { "MAP Non-Invasive (Calculated) (mmHg)", "MPA Invasive (mmHg)" }
local low_map_predicate = function(dv) return discrete.get_dv_value_number(dv) < 70 end
local oxygen_dv_names = { "DELIVERY" }
local pao2_dv_names = { "BLD GAS O2 (mmHg)", "PO2 (mmHg)" }
local low_pao21_predicate = function(dv) return discrete.get_dv_value_number(dv) < 80 end
local sbp_dv_names = { "SBP 3.5 (No Calculation) (mmHg)" }
local low_sbp_predicate = function(dv) return discrete.get_dv_value_number(dv) < 90 end
local high_sbp_predicate = function(dv) return discrete.get_dv_value_number(dv) > 180 end
local spo2_dv_names = { "Pulse Oximetry(Num) (%)" }
local low_spo21_predicate = function(dv) return discrete.get_dv_value_number(dv) < 90 end
local troponin_dv_names = { "TROPONIN, HIGH SENSITIVITY (ng/L)" }
local high_troponin_predicate = function(dv) return discrete.get_dv_value_number(dv) > 59 end

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
    --- Top-Level Link Header Variables
    --------------------------------------------------------------------------------
    local result_links = {}
    local documented_dx_header = links.make_header_link("Documented Dx")
    local documented_dx_links = {}
    local laboratory_studies_header = links.make_header_link("Laboratory Studies")
    local laboratory_studies_links = {}
    local vital_signs_intake_header = links.make_header_link("Vital Signs/Intake and Output Data")
    local vital_signs_intake_links = {}
    local clinical_evidence_header = links.make_header_link("Clinical Evidence")
    local clinical_evidence_links = {}
    local oxygenation_ventillation_header = links.make_header_link("Oxygenation/Ventilation")
    local oxygenation_ventillation_links = {}
    local treatment_and_monitoring_header = links.make_header_link("Treatment and Monitoring")
    local treatment_and_monitoring_links = {}
    local ekg_header = links.make_header_link("EKG")
    local ekg_links = {}
    local echo_header = links.make_header_link("Echo")
    local echo_links = {}
    local ct_header = links.make_header_link("CT")
    local ct_links = {}
    local heart_cath_header = links.make_header_link("Heart Cath")
    local heart_cath_links = {}
    local troponin_header = links.make_header_link("Troponin")
    local troponin_links = {}



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
    local antiplatlet2_medication_link = links.get_medication_link { cat = "Antiplatelet 2" }
    local aspirin_medication_link = links.get_medication_link { cat = "Aspirin" }
    local heparin_medication_link = links.get_medication_link { cat = "Heparin" }
    local morphine_medication_link = links.get_medication_link { cat = "Morphine" }
    local nitroglycerin_medication_link = links.get_medication_link { cat = "Nitroglycerin" }

    -- Laboratory Studies
    links.GetDvValuesAsSingleLink {
        account = Account,
        dvNames = troponin_dv_names,
        linkText = "Troponin T High Sensitivity: (DATE1, DATE2) - ",
        target = troponin_links
    }
    local high_troponin_discrete_value_links = links.get_discrete_value_links { dvNames = troponin_dv_names, predicate = high_troponin_predicate, maxPerValue = 10 }



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
            table.insert(documented_dx_links, code_link)
        end
        if #account_other_codes > 0 then
            local desc = other_code_dictionary[account_other_codes[1]]
            local code_link = links.get_code_link {
                code = account_other_codes[1],
                text = "Autoresolved Specified Code - " .. desc
            }
            table.insert(documented_dx_links, code_link)
        end
        if i214_code_link then
            table.insert(documented_dx_links, i214_code_link)
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
            table.insert(documented_dx_links, code_link)
        end
        if #account_other_codes > 0 then
            local desc = other_code_dictionary[account_other_codes[1]]
            local code_link = links.get_code_link {
                code = account_other_codes[1],
                text = "Autoresolved Specified Code - " .. desc
            }
            table.insert(documented_dx_links, code_link)
        end
        if i214_code_link then
            table.insert(documented_dx_links, i214_code_link)
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
        table.insert(documented_dx_links, i21a1_code_link)
        table.insert(documented_dx_links, i2489_code_link)
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
        table.insert(documented_dx_links, i2489_code_link)
        table.insert(documented_dx_links, i219_code_link)
        Result.subtitle = "Possible Acute MI Type 2"
        Result.passed = true

    elseif trigger_alert and code_count > 0 and i2489_code_link then
        -- Alert Acute MI Type Needs Clarification
        table.insert(documented_dx_links, i2489_code_link)
        if #account_stemi_codes > 0 then
            local desc = stemicode_dictionary[account_stemi_codes[1]]
            local code_link = links.get_code_link {
                code = account_stemi_codes[1],
                text = "Autoresolved Specified Code - " .. desc
            }
            table.insert(documented_dx_links, code_link)
        end
        if #account_other_codes > 0 then
            local desc = other_code_dictionary[account_other_codes[1]]
            local code_link = links.get_code_link {
                code = account_other_codes[1],
                text = "Autoresolved Specified Code - " .. desc
            }
            table.insert(documented_dx_links, code_link)
        end
        table.insert(documented_dx_links, i214_code_link)
        Result.subtitle = "Acute MI Type Needs Clarification"
        Result.passed = true

    elseif trigger_alert and i219_code_link then
        -- Alert Acute MI Unspecified Present Confirm if Further Specification of Type Needed
        table.insert(documented_dx_links, i219_code_link)
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
        table.insert(treatment_and_monitoring_links, heparin_medication_link)
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
            links.get_code_link { code = "R94.39", text = "Abnormal Cardiovascular Function Study", target = clinical_evidence_links, seq = 1 }
            links.get_code_link { code = "D62", text = "Acute Blood Loss Anemia", target = clinical_evidence_links, seq = 2 }
            links.get_code_link { code = "I24.81", text = "Acute Coronary microvascular Dysfunction", target = clinical_evidence_links, seq = 3 }
            links.get_code_link {
                codes = { "N17.0", "N17.1", "N17.2", "K76.7", "K91.83" },
                text = "Acute Kidney Failure",
                target = clinical_evidence_links,
                seq = 4
            }
            links.get_code_link { code = "I20.9", text = "Angina", target = clinical_evidence_links, seq = 5 }
            links.get_code_link { code = "I20.81", text = "Angina Pectoris with Coronary Microvascular Dysfunction", target = clinical_evidence_links, seq = 6 }
            links.get_code_link { code = "I20.1", text = "Angina Pectoris with Documented Spasm/with Coronary Vasospasm", target = clinical_evidence_links, seq = 7 }
            links.get_abstraction_link { code = "ATRIAL_FIBRILLATION_WITH_RVR", text = "Atrial Fibrillation with RVR", target = clinical_evidence_links, seq = 8 }
            links.get_code_link { code = "I46.9", text = "Cardiac Arrest, Cause Unspecified", target = clinical_evidence_links, seq = 9 }
            links.get_code_link { code = "I46.8", text = "Cardiac Arrest Due to Other Underlying Condition", target = clinical_evidence_links, seq = 10 }
            links.get_code_link { code = "I46.2", text = "Cardiac Arrest due to Underlying Cardiac Condition", target = clinical_evidence_links, seq = 11 }
            codes.get_code_prefix_link { prefix = "I42%.", text = "Cardiomyopathy Dx", target = clinical_evidence_links, seq = 12 }
            codes.get_code_prefix_link { prefix = "I43%.", text = "Cardiomyopathy Dx", target = clinical_evidence_links, seq = 13 }
            table.insert(clinical_evidence_links, r07_code_link)
            links.get_code_link { code = "I25.85", text = "Chronic Coronary Microvascular Dysfunction", target = clinical_evidence_links, seq = 15 }
            links.get_code_link {
                codes = { "N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5" },
                text = "Chronic Kidney Failure",
                target = clinical_evidence_links,
                seq = 16
            }
            links.get_code_link { code = "I44.2", text = "Complete Heart Block", target = clinical_evidence_links, seq = 17 }
            links.get_code_link { code = "J44.1", text = "COPD Exacerbation", target = clinical_evidence_links, seq = 18 }
            links.get_code_link { code = "Z98.61", text = "Coronary Angioplasty Hx", target = clinical_evidence_links, seq = 19 }
            links.get_code_link { code = "Z95.5", text = "Coronary Angioplasty Implant and Graft Hx", target = clinical_evidence_links, seq = 20 }
            links.get_code_link { code = "I25.10", text = "Coronary Artery Disease", target = clinical_evidence_links, seq = 21 }
            links.get_code_link { code = "I25.119", text = "Coronary Artery Disease with Angina", target = clinical_evidence_links, seq = 22 }

            links.get_code_link {
                codes = {
                    "270046", "027004Z", "0270056", "027005Z", "0270066", "027006Z", "0270076", "027007Z", "02700D6", "02700DZ", "02700E6", "02700EZ",
                    "02700F6", "02700FZ", "02700G6", "02700GZ", "02700T6", "02700TZ", "02700Z6", "02700ZZ", "0271046", "027104Z", "0271056", "027105Z",
                    "0271066", "027106Z", "0271076", "027107Z", "02710D6", "02710DZ", "02710E6", "02710EZ", "02710F6", "02710FZ", "02710G6", "02710GZ",
                    "02710T6", "02710TZ", "02710Z6", "02710ZZ", "0272046", "027204Z", "0272056", "027205Z", "0272066", "027206Z", "0272076", "027207Z",
                    "02720D6", "02720DZ", "02720E6", "02720EZ", "02720F6", "02720FZ", "02720G6", "02720GZ", "02720T6", "02720TZ", "02720Z6", "02720ZZ",
                    "0273046", "027304Z", "0273056", "027305Z", "0273066", "027306Z", "0273076", "027307Z", "02730D6", "02730DZ", "02730E6", "02730EZ",
                    "02730F6", "02730FZ", "02730G6", "02730GZ", "02730T6", "02730TZ", "02730Z6", "02730ZZ"
                },
                text = "Dilation of Coronary Artery",
                target = clinical_evidence_links,
                seq = 24
            }
            links.get_abstraction_link { code = "DYSPNEA_ON_EXERTION", text = "Dyspnea On Exertion", target = clinical_evidence_links, seq = 25 }
            links.get_abstraction_link { code = "PRESERVED_EJECTION_FRACTION", text = "Ejection Fraction", target = clinical_evidence_links, seq = 26 }
            links.get_abstraction_link { code = "PRESERVED_EJECTION_FRACTION_2", text = "Ejection Fraction", target = clinical_evidence_links, seq = 27 }
            links.get_abstraction_link { code = "REDUCED_EJECTION_FRACTION", text = "Ejection Fraction", target = clinical_evidence_links, seq = 28 }
            links.get_abstraction_link { code = "MODERATELY_REDUCED_EJECTION_FRACTION", text = "Ejection Fraction", target = clinical_evidence_links, seq = 29 }
            links.get_abstraction_link { code = "ELEVATED_TROPONINS", text = "Elevated Tropinins", target = clinical_evidence_links, seq = 30 }
            links.get_code_link { code = "N18.6", text = "End-Stage Renal Disease", target = clinical_evidence_links, seq = 31 }
            codes.get_code_prefix_link { prefix = "I38%.", text = "Endocarditis Dx", target = clinical_evidence_links, seq = 32 }
            codes.get_code_prefix_link { prefix = "I39%.", text = "Endocarditis Dx", target = clinical_evidence_links, seq = 33 }
            links.get_code_link {
                codes = {
                    "I50.1", "I50.20", "I50.22", "I50.23", "I50.30", "I50.32", "I50.33", "I50.40", "I50.42", "I50.43",
                    "I50.810", "I50.812", "I50.813", "I50.84", "I50.89", "I50.9"
                },
                text = "Heart Failure",
                target = clinical_evidence_links,
                seq = 34
            }
            links.get_code_link { code = "Z95.1", text = "History of CABG", target = clinical_evidence_links, seq = 35 }
            links.get_code_link { code = "I16.1", text = "Hypertensive Emergency", target = clinical_evidence_links, seq = 36 }
            links.get_code_link { code = "I16.0", text = "Hypertensive Urgency", target = clinical_evidence_links, seq = 37 }
            links.get_code_link { code = "E86.1", text = "Hypovolemia", target = clinical_evidence_links, seq = 38 }
            links.get_code_link { code = "R09.02", text = "Hypoxemia", target = clinical_evidence_links, seq = 39 }
            links.get_code_link { code = "I47.11", text = "Inappropriate Sinus Tachycardia, So Stated", target = clinical_evidence_links, seq = 40 }
            links.get_abstraction_link { code = "IRREGULAR_ECHO_FINDING", text = "Irregular Echo Finding", target = clinical_evidence_links, seq = 41 }
            links.get_code_link { code = "R94.31", text = "Irregular Echo Finding", target = clinical_evidence_links, seq = 42 }
            table.insert(clinical_evidence_links, irregular_ekg_findings_abstraction_link)
            links.get_code_link { codes = { "44A023N7", "44A023N8" }, text = "Left Heart Cath", target = clinical_evidence_links, seq = 44 }
            codes.get_code_prefix_link { prefix = "I40%.", text = "Myocarditis Dx", target = clinical_evidence_links, seq = 45 }
            links.get_code_link { code = "I35.0", text = "Non-Rheumatic Aortic Valve Stenosis", target = clinical_evidence_links, seq = 46 }
            links.get_code_link { code = "I35.1", text = "Non-Rheumatic Aortic Valve Insufficiency", target = clinical_evidence_links, seq = 47 }
            links.get_code_link { code = "I35.2", text = "Non-Rheumatic Aortic Valve Stenosis with Insufficiency", target = clinical_evidence_links, seq = 48 }
            links.get_code_link { code = "I25.2", text = "Old MI", target = clinical_evidence_links, seq = 49 }
            links.get_code_link { code = "I20.8", text = "Other Angina Pectoris", target = clinical_evidence_links, seq = 50 }
            links.get_code_link { code = "I47.19", text = "Other Supraventricular Tachycardia", target = clinical_evidence_links, seq = 51 }
            codes.get_code_prefix_link { prefix = "I47%.", text = "Paroxysmal Tachycardia Dx", target = clinical_evidence_links, seq = 52 }
            codes.get_code_prefix_link { prefix = "I30%.", text = "Pericarditis Dx", target = clinical_evidence_links, seq = 53 }
            codes.get_code_prefix_link { prefix = "I26%.", text = "Pulmonary Embolism Dx", target = clinical_evidence_links, seq = 54 }
            links.get_code_link {
                codes = {
                    "I27.0", "I27.20", "I27.21", "I27.22", "I27.23", "I27.24", "I27.29"
                },
                text = "Pulmonary Hypertension",
                target = clinical_evidence_links,
                seq = 55
            }
            links.get_code_link {
                codes = {
                    "0270346", "027034Z", "0270356", "027035Z", "0270366", "027036Z", "02730376", "027037Z", "02703D6", "02703DZ", "02703E6", "02703EZ",
                    "02703F6", "02703FZ", "02703G6", "02703GZ", "02703T6", "02703TZ", "02703Z6", "02703ZZ", "0271346", "027134Z", "0271356", "027135Z",
                    "0271366", "027136Z", "0271376", "027137Z", "02713D6", "02713DZ", "02713E6", "02713EZ", "02713F6", "02713FZ", "02713G6", "02713GZ",
                    "02713T6", "02713TZ", "02713Z6", "02713ZZ", "0272346", "027234Z", "0272356", "027235Z", "0272366", "027236Z", "0272376", "027237Z",
                    "02723D6", "02723DZ", "02723E6", "02723EZ", "02723F6", "02723FZ", "02723G6", "02723GZ", "02723T6", "02723TZ", "02723Z6", "02723ZZ",
                    "0273346", "027334Z", "0273356", "027335Z", "0273366", "027336Z", "0273376", "027337Z", "02733D6", "02733DZ", "02733E6", "02733EZ",
                    "02733F6", "02733FZ", "02733G6", "02733GZ", "02733T6", "02733TZ", "02733Z6", "02733ZZ"
                },
                text = "Percutaneous Coronary Intervention",
                target = clinical_evidence_links,
                seq = 56
            }
            links.get_code_link { codes = { "M62.82", "T79.6XXA", "T79.6XXD", "T79.6XXS" }, text = "Rhabdomyolysis", target = clinical_evidence_links, seq = 57 }
            links.get_code_link { code = "4A023N6", text = "Right Heart Cath", target = clinical_evidence_links, seq = 58 }
            links.get_code_link { code = "I20.2", text = "Refractory Angina Pectoris", target = clinical_evidence_links, seq = 59 }
            links.get_abstraction_link { code = "RESOLVING_TROPONINS", text = "Resolving Troponins", target = clinical_evidence_links, seq = 60 }
            codes.get_code_prefix_link { prefix = "A40%.", text = "Sepsis Dx", target = clinical_evidence_links, seq = 61 }
            codes.get_code_prefix_link { prefix = "A41%.", text = "Sepsis Dx", target = clinical_evidence_links, seq = 62 }
            codes.GetCodeLink {
                codes = {
                    "A42.7", "A22.7", "B37.7", "A26.7", "A54.86", "B00.7", "A32.7", "A24.1", "A20.7", "R65.20", "R65.21",
                    "T81.44XA", "T81.44XD", "T81.44XS"
                },
                text = "Sepsis Dx",
                target = clinical_evidence_links,
                seq = 63
            }
            links.get_abstraction_link { code = "SHORTNESS_OF_BREATH", text = "Shortness of Breath", target = clinical_evidence_links, seq = 64 }
            links.get_code_link { code = "I47.10", text = "Supraventricular Tachycardia, Unspecified", target = clinical_evidence_links, seq = 65 }
            links.get_code_link { code = "I51.81", text = "Takotsubo Syndrome", target = clinical_evidence_links, seq = 66 }
            links.get_code_link { code = "I25.82", text = "Total Occlusion of Coronary Artery", target = clinical_evidence_links, seq = 67 }
            links.get_code_link { codes = { "I35.8", "I35.9" }, text = "Unspecified Non-Rheumatic Aortic Valve Disorders", target = clinical_evidence_links, seq = 68 }
            links.get_code_link { code = "I20.0", text = "Unstable Angina", target = clinical_evidence_links, seq = 69 }
            links.get_code_link { code = "I49.01", text = "Ventricular Fibrillation", target = clinical_evidence_links, seq = 70 }
            links.get_code_link { code = "I49.02", text = "Ventricular Flutter", target = clinical_evidence_links, seq = 71 }
            links.get_abstraction_link { code = "WALL_MOTION_ABNORMALITIES", text = "Wall Motion Abnormalities", target = clinical_evidence_links, seq = 72 }

            -- EKG/Echo/HeartCath/CT Document Links
            links.get_document_link { documentType = "ECG", text = "ECG", target = ekg_links }
            links.get_document_link { documentType = "Electrocardiogram Adult   ECGR", text = "Electrocardiogram Adult   ECGR", target = ekg_links }
            links.get_document_link { documentType = "ECG Adult", text = "ECG Adult", target = ekg_links }
            links.get_document_link { documentType = "RestingECG", text = "RestingECG", target = ekg_links }
            links.get_document_link { documentType = "EKG", text = "EKG", target = ekg_links }
            links.get_document_link { documentType = "ECHOTE  CVSECHOTE", text = "ECHOTE  CVSECHOTE", target = echo_links }
            links.get_document_link { documentType = "ECHO 2D Comp Adult CVSECH2DECHO", text = "ECHO 2D Comp Adult CVSECH2DECHO", target = echo_links }
            links.get_document_link { documentType = "Echo Complete Adult 2D", text = "Echo Complete Adult 2D", target = echo_links }
            links.get_document_link { documentType = "Echo Comp W or WO Contrast", text = "Echo Comp W or WO Contrast", target = echo_links }
            links.get_document_link { documentType = "ECHO Stress ECHO  CVSECHSTR", text = "ECHO Stress ECHO  CVSECHSTR", target = echo_links }
            links.get_document_link { documentType = "Stress Echocardiogram CVS", text = "Stress Echocardiogram CVS", target = echo_links }
            links.get_document_link { documentType = "CVSECH2DECHO", text = "CVSECH2DECHO", target = echo_links }
            links.get_document_link { documentType = "CVSECHOTE", text = "CVSECHOTE", target = echo_links }
            links.get_document_link { documentType = "CVSECHORECHO", text = "CVSECHORECHO", target = echo_links }
            links.get_document_link { documentType = "CVSECH2DECHOLIMITED", text = "CVSECH2DECHOLIMITED", target = echo_links }
            links.get_document_link { documentType = "CVSECHOPC", text = "CVSECHOPC", target = echo_links }
            links.get_document_link { documentType = "CVSECHSTRAINECHO", text = "CVSECHSTRAINECHO", target = echo_links }
            links.get_document_link { documentType = "Heart Cath", text = "Heart Cath", target = heart_cath_links }
            links.get_document_link { documentType = "Cath Report", text = "Cath Report", target = heart_cath_links }
            links.get_document_link { documentType = "Cardiac Cath, PTCA, EP findings", text = "Cardiac Cath, PTCA, EP findings", target = heart_cath_links }
            links.get_document_link { documentType = "CATHEOC", text = "CATHEOC", target = heart_cath_links }
            links.get_document_link { documentType = "Cath Lab Procedures", text = "Cath Lab Procedures", target = heart_cath_links }
            links.get_document_link { documentType = "CT Thorax W", text = "CT Thorax W", target = ct_links }
            links.get_document_link { documentType = "CTA Thorax Aorta", text = "CTA Thorax Aorta", target = ct_links }
            links.get_document_link { documentType = "CT Thorax WO-Abd WO-Pel WO", text = "CT Thorax WO-Abd WO-Pel WO", target = ct_links }
            links.get_document_link { documentType = "CT Thorax WO", text = "CT Thorax WO", target = ct_links }

            -- Labs
            links.get_discrete_value_link {
                discreteValueNames = hemogloblin_dv_names,
                text = "Hemoglobin",
                target = laboratory_studies_links,
                predicate =
                    (not Account.patient or Account.patient.gender == "F") and
                    female_low_hemoglobin_predicate or
                    male_low_hemoglobin_predicate
            }
            links.get_discrete_value_link {
                discreteValueNames = hematocrit_dv_names,
                text = "Hematocrit",
                target = laboratory_studies_links,
                predicate =
                    (not Account.patient or Account.patient.gender == "F") and
                    female_low_hematocrit_predicate or
                    male_low_hematocrit_predicate
            }

            -- Lab Subheadings
            for _, link in ipairs(high_troponin_discrete_value_links) do
                table.insert(troponin_links, link)
            end

            -- Medications
            links.get_medication_link { cat = "Ace Inhibitor", text = "", target = treatment_and_monitoring_links, seq = 1 }
            links.get_medication_link { cat = "Antianginal Medication", text = "", target = treatment_and_monitoring_links, seq = 2 }
            links.get_abstraction_link { code = "ANTIANGINAL_MEDICATION", text = "", target = treatment_and_monitoring_links, seq = 3 }
            links.get_medication_link { cat = "Anticoagulant", text = "", target = treatment_and_monitoring_links, seq = 4 }
            links.get_abstraction_link { code = "ANTICOAGULANT", text = "", target = treatment_and_monitoring_links, seq = 5 }
            links.get_medication_link { cat = "Antiplatelet", text = "", target = treatment_and_monitoring_links, seq = 6 }
            table.insert(treatment_and_monitoring_links, antiplatlet2_medication_link)
            links.get_abstraction_link { code = "ANTIPLATELET", text = "", target = treatment_and_monitoring_links, seq = 8 }
            table.insert(treatment_and_monitoring_links, aspirin_medication_link)
            links.get_medication_link { cat = "Beta Blocker", text = "", target = treatment_and_monitoring_links, seq = 10 }
            links.get_abstraction_link { code = "BETA_BLOCKER", text = "", target = treatment_and_monitoring_links, seq = 11 }
            links.get_medication_link { cat = "Calcium Channel Blockers", text = "", target = treatment_and_monitoring_links, seq = 12 }
            links.get_abstraction_link { code = "CALCIUM_CHANNEL_BLOCKER", text = "", target = treatment_and_monitoring_links, seq = 13 }
            table.insert(treatment_and_monitoring_links, morphine_medication_link)
            table.insert(treatment_and_monitoring_links, nitroglycerin_medication_link)
            links.get_abstraction_link { code = "NITROGLYCERIN", text = "", target = treatment_and_monitoring_links, seq = 19 }
            links.get_medication_link { cat = "Statin", text = "", target = treatment_and_monitoring_links, seq = 20 }
            links.get_abstraction_link { code = "STATIN", text = "", target = treatment_and_monitoring_links, seq = 21 }

            -- Oxygen
            links.get_discrete_value_link {
                discreteValueNames = oxygen_dv_names,
                text = "Oxygen Therapy",
                target = oxygenation_ventillation_links,
                seq = 1,
                predicate = function(dv)
                    -- Return true if dv.result contains the pattern "%bRoom Air%b"
                    return
                        dv.result:find("%bRoom Air%b") ~= nil and
                        dv.result:find("%bRA%b") == nil
                end
            }
            links.get_abstraction_link { code = "OXYGEN_THERAPY", text = "Oxygen Therapy", target = oxygenation_ventillation_links, seq = 2 }

            -- Vitals
            links.get_discrete_value_link {
                discreteValueNames = pao2_dv_names,
                text = "Arterial P02",
                target = vital_signs_intake_links,
                seq = 1,
                predicate = low_pao21_predicate
            }
            links.get_discrete_value_link {
                discreteValueNames = heart_rate_dv_names,
                text = "Heart Rate",
                target = vital_signs_intake_links,
                seq = 2,
                predicate = high_heart_rate_predicate
            }
            links.get_discrete_value_link {
                discreteValueNames = heart_rate_dv_names,
                text = "Heart Rate",
                target = vital_signs_intake_links,
                seq = 3,
                predicate = low_heart_rate_predicate
            }
            links.get_discrete_value_link {
                discreteValueNames = map_dv_names,
                text = "MAP",
                target = vital_signs_intake_links,
                seq = 4,
                predicate = low_map_predicate
            }
            links.get_discrete_value_link {
                discreteValueNames = spo2_dv_names,
                text = "Sp02",
                target = vital_signs_intake_links,
                seq = 5,
                predicate = low_spo21_predicate
            }
            links.get_discrete_value_link {
                discreteValueNames = sbp_dv_names,
                text = "SBP",
                target = vital_signs_intake_links,
                seq = 6,
                predicate = low_sbp_predicate
            }
            links.get_discrete_value_link {
                discreteValueNames = sbp_dv_names,
                text = "SBP",
                target = vital_signs_intake_links,
                seq = 7,
                predicate = high_sbp_predicate
            }
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        if #troponin_links > 0 then
            troponin_header.links = troponin_links
            table.insert(laboratory_studies_links, troponin_header)
        end
        if #documented_dx_links > 0 then
            documented_dx_header.links = documented_dx_links
            table.insert(result_links, documented_dx_header)
        end
        if #clinical_evidence_links > 0 then
            clinical_evidence_header.links = clinical_evidence_links
            table.insert(result_links, clinical_evidence_header)
        end
        if #laboratory_studies_links > 0 then
            laboratory_studies_header.links = laboratory_studies_links
            table.insert(result_links, laboratory_studies_header)
        end
        if #vital_signs_intake_links > 0 then
            vital_signs_intake_header.links = vital_signs_intake_links
            table.insert(result_links, vital_signs_intake_header)
        end
        if #treatment_and_monitoring_links > 0 then
            treatment_and_monitoring_header.links = treatment_and_monitoring_links
            table.insert(result_links, treatment_and_monitoring_header)
        end
        if #oxygenation_ventillation_links > 0 then
            oxygenation_ventillation_header.links = oxygenation_ventillation_links
            table.insert(result_links, oxygenation_ventillation_header)
        end
        if #ekg_links > 0 then
            ekg_header.links = ekg_links
            table.insert(result_links, ekg_header)
        end
        if #echo_links > 0 then
            echo_header.links = echo_links
            table.insert(result_links, echo_header)
        end
        if #ct_links > 0 then
            ct_header.links = ct_links
            table.insert(result_links, ct_header)
        end
        if #heart_cath_links > 0 then
            heart_cath_header.links = heart_cath_links
            table.insert(result_links, heart_cath_header)
        end

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end
end
