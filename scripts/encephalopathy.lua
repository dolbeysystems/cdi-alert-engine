---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Encephalopathy
---
--- This script checks an account to see if it matches the criteria for a encephalopathy alert.
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
local dv_alkaline_phos = { "ALKALINE PHOS", "ALK PHOS TOTAL (U/L)" }
local calc_alkaline_phos1 = function(dv_, num) return num > 149 end
local dv_arterial_blood_ph = { "pH" }
local calc_arterial_blood_ph1 = 7.30
local dv_bilirubin_total = { "TOTAL BILIRUBIN (mg/dL)" }
local calc_bilirubin_total1 = function(dv_, num) return num > 1.2 end
local dv_blood_glucose = { "GLUCOSE (mg/dL)", "GLUCOSE" }
local calc_blood_glucose1 = function(dv_, num) return num > 200 end
local calc_blood_glucose2 = function(dv_, num) return num < 50 end
local dv_blood_glucose_poc = { "GLUCOSE ACCUCHECK (mg/dL)" }
local calc_blood_glucose_poc1 = function(dv_, num) return num > 200 end
local calc_blood_glucose_poc2 = function(dv_, num) return num < 50 end
local dv_dbp = {
    "BP Arterial Diastolic cc (mm Hg)",
    "DBP 3.5 (No Calculation) (mmhg)",
    "DBP 3.5 (No Calculation) (mm Hg)"
}
local calc_dbp1 = function(dv_, num) return num > 110 end
local dv_ethanol_level = { "ALCOHOL,ETHYL UR" }
local calc_ethanol_level1 = function(dv_, num) return num > 0.2 end
local dv_glasgow_coma_scale = { "3.5 Neuro Glasgow Score" }
local calc_glasgow_coma_scale1 = function(dv_, num) return num > 14 end
local calc_glasgow_coma_scale2 = function(dv_, num) return num < 12 end
local dv_pa_o2 = { "BLD GAS O2 (mmHg)", "PO2 (mmHg)" }
local calc_pa_o21 = function(dv_, num) return num < 80 end
local dv_p_co2 = { "BLD GAS CO2 (mmHg)", "PaCO2 (mmHg)" }
local calc_p_co21 = function(dv_, num) return num > 46 end
local dv_sbp = { "SBP 3.5 (No Calculation) (mm Hg)" }
local calc_sbp1 = function(dv_, num) return num > 180 end
local dv_serum_ammonia = { "" }
local calc_serum_ammonia1 = function(dv_, num) return num > 71 end
local dv_serum_blood_urea_nitrogen = { "BUN (mg/dL)" }
local calc_serum_blood_urea_nitrogen1 = 20
local dv_serum_calcium = { "CALCIUM (mg/dL)" }
local calc_serum_calcium1 = function(dv_, num) return num > 10.2 end
local calc_serum_calcium2 = function(dv_, num) return num < 8.3 end
local dv_serum_creatinine = { "CREATININE (mg/dL)", "CREATININE SERUM (mg/dL)" }
local calc_serum_creatinine1 = function(dv_, num) return num > 1.2 end
local dv_serum_sodium = { "SODIUM (mmol/L)" }
local calc_serum_sodium1 = function(dv_, num) return num > 148 end
local calc_serum_sodium2 = function(dv_, num) return num < 135 end
local dv_sp_o2 = { "Pulse Oximetry(Num) (%)" }
local calc_sp_o21 = function(dv_, num) return num < 90 end
local dv_temperature = {
    "Temperature Degrees C 3.5 (degrees C)",
    "Temperature  Degrees C 3.5 (degrees C)",
    "TEMPERATURE (C)"
}
local calc_temperature1 = function(dv_, num) return num > 38.3 end
local calc_temperature2 = function(dv_, num) return num < 36.0 end

local dv_amphetamine_screen = { "AMP/METH UR", "AMPHETAMINE URINE" }
local dv_barbiturate_screen = { "BARBITURATES URINE", "BARBS UR" }
local dv_benzodiazepine_screen = { "BENZO URINE", "BENZO UR" }
local dv_buprenorphine_screen = { "" }
local dv_c_blood = { "" }
local dv_c_urine = { "BACTERIA (/HPF)" }
local dv_cannabinoid_screen = { "CANNABINOIDS UR", "Cannabinoids (THC) UR" }
local dv_cocaine_screen = { "COCAINE URINE", "COCAINE UR CONF" }
local dv_fentanyl_screen = { "FENTANYL URINE", "FENTANYL UR" }
local dv_methadone_screen = { "METHADONE URINE", "METHADONE UR" }
local dv_opiate_screen = { "OPIATES URINE", "OPIATES UR" }
local dv_oxycodone_screen = { "OXYCODONE UR", "OXYCODONE URINE" }

local dv_glasgow_eye_opening = { "3.5 Neuro Glasgow Eyes (Adult)" }
local dv_glasgow_verbal = { "3.5 Neuro Glasgow Verbal (Adult)" }
local dv_glasgow_motor = { "3.5 Neuro Glasgow Motor" }
local dv_oxygen_therapy = { "O2 Device" }
local dv_ua_bacteria = { "UA Bacteria (/HPF)" }



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
    local glasgow_header = headers.make_header_builder("Glasgow Coma Score", 2)
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 3)
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 4)
    local vital_signs_intake_header = headers.make_header_builder("Vital Signs/Intake", 5)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 6)
    local mri_brain_header = headers.make_header_builder("MRI Brain", 7)
    local ct_head_brain_header = headers.make_header_builder("CT Head/Brain", 8)
    local eeg_header = headers.make_header_builder("EEG", 9)

    local glucose_header = headers.make_header_builder("Glucose", 90)
    local ammonia_header = headers.make_header_builder("Serum Ammonia", 91)
    local bun_header = headers.make_header_builder("BUN", 92)
    local creatinine_header = headers.make_header_builder("Creatinine", 93)
    local calcium_header = headers.make_header_builder("Serum Calcium", 94)
    local sodium_header = headers.make_header_builder("Serum Sodium", 95)
    local abg_header = headers.make_header_builder("ABG", 88)
    local drug_header = headers.make_header_builder("Drug Screen", 89)

    local ph_header = headers.make_header_builder("PH", 89)
    local pao2_header = headers.make_header_builder("Pa02", 96)
    local pco2_header = headers.make_header_builder("PC02", 97)

    local function compile_links()
        abg_header:add_link(pao2_header:build(true))
        abg_header:add_link(pco2_header:build(true))
        abg_header:add_link(ph_header:build(true))

        laboratory_studies_header:add_link(glucose_header:build(true))
        laboratory_studies_header:add_link(ammonia_header:build(true))
        laboratory_studies_header:add_link(bun_header:build(true))
        laboratory_studies_header:add_link(creatinine_header:build(true))
        laboratory_studies_header:add_link(calcium_header:build(true))
        laboratory_studies_header:add_link(sodium_header:build(true))
        laboratory_studies_header:add_link(abg_header:build(true))
        laboratory_studies_header:add_link(drug_header:build(true))

        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, vital_signs_intake_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))
        table.insert(result_links, mri_brain_header:build(true))
        table.insert(result_links, ct_head_brain_header:build(true))
        table.insert(result_links, eeg_header:build(true))
        table.insert(result_links, glasgow_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end



    --------------------------------------------------------------------------------
    --- Alert Variables 
    --------------------------------------------------------------------------------
    local alert_code_dictionary = {
        ["E51.2"] = "Wernicke's Encephalopathy",
        ["G31.2"] = "Alcoholic Encephalopathy",
        ["G92.8"] = "Other Toxic Encephalopathy",
        ["G93.41"] = "Metabolic Encephalopathy",
        ["I67.4"] = "Hypertensive Encephalopathy",
        ["G92.9"] = "Unspecified toxic encephalopathy",
        ["G32.89"] = "Degenerative Encephalopathy in Diseases Classified Elsewhere",
        ["J11.81"] = "Influenzal Encephalopathy",
        ["F07.81"] = "Postconcussional Encephalopathy",
        ["G93.49"] = "Other Encephalopathy",
        ["K76.82"] = "Hepatic Encephalopathy",
        ["G04.30"] = "Acute necrotizing hemorrhagic encephalopathy",
        ["G04.31"] = "Postinfectious acute necrotizing hemorrhagic encephalopathy",
        ["G04.32"] = "Postimmunization acute necrotizing hemorrhagic encephalopathy",
        ["G04.39"] = "Other acute necrotizing hemorrhagic encephalopathy"
    }
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Negations
    local g931_code = codes.get_code_prefix_link {
        prefix = "G93%.1",
        text = "Anoxic Brain Damage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])"
    }
    local dementia1 = codes.get_code_prefix_link { prefix = "F01%.", text = "Dementia" }
    local dementia2 = codes.get_code_prefix_link { prefix = "F02%.", text = "Dementia" }
    local dementia3 = codes.get_code_prefix_link { prefix = "F03%.", text = "Dementia" }
    local alzheimers_neg = codes.get_code_prefix_link { prefix = "G30%.", text = "Alzheimers Disease" }
    local vent_discrete_value_names = links.get_discrete_value_link {
        discreteValueNames = dv_oxygen_therapy,
        text = "Ventilator Mentioned In Oxygen Therapy",
        predicate = function(dv, num_)
            return string.find(dv.result, "Vent") ~= nil or string.find(dv.result, "Ventilator") ~= nil
        end
    }

    -- Documented Dx
    local g9340_code = links.get_code_link { code = "G93.40", text = "Unspecified Encephalopathy" }
    local g928_code = links.get_code_link { code = "G92.8", text = "Encephalopathy" }
    local g9341_code = links.get_code_link { code = "G93.41", text = "Encephalopathy" }
    local k7682_code = links.get_code_link { code = "K76.82", text = "Liver Disease or Failure" }
    local severe_alzheimers_abs = links.get_abstraction_link {
        code = "SEVERE_ALZHEIMERS_DISEASE",
        text = "Severe Alzheimers Disease"
    }
    local severe_dementia_abs = links.get_abstraction_link { code = "SEVERE_DEMENTIA", text = "Severe Dementia" }
    local liver_neg1 = codes.get_code_prefix_link { prefix = "K70%.", text = "Liver Disease or Failure DX Code" }
    local liver_neg2 = codes.get_code_prefix_link { prefix = "K71%.", text = "Liver Disease or Failure DX Code" }
    local liver_neg3 = codes.get_code_prefix_link { prefix = "K72%.", text = "Liver Disease or Failure DX Code" }
    local liver_neg4 = codes.get_code_prefix_link { prefix = "K73%.", text = "Liver Disease or Failure DX Code" }
    local liver_neg5 = codes.get_code_prefix_link { prefix = "K74%.", text = "Liver Disease or Failure DX Code" }
    local liver_neg6 = codes.get_code_prefix_link { prefix = "K75%.", text = "Liver Disease or Failure DX Code" }
    local liver_neg7 = links.get_code_links {
        codes = { "K76.1", "K76.2", "K76.3", "K76.4", "K76.5", "K76.6", "K76.7", "K76.81", "K76.9" },
        text = "Liver Disease or Failure DX Code"
    }
    local liver_neg8 = codes.get_code_prefix_link { prefix = "K77%.", text = "Liver Disease or Failure DX Code" }

    local r9402_code = links.get_code_link { code = "R94.02", text = "Abnormal Brain Scan" }
    local acute_subacute_hepatic_fail_code = links.get_code_links {
        codes = { "K72.00", "K72.01" },
        text = "Acute and Subacute Hepatic Failure"
    }
    local acute_kidney_failure_abs = links.get_abstraction_link {
        code = "ACUTE_KIDNEY_FAILURE",
        text = "Acute Kidney Failure"
    }
    local f101_codes = codes.get_code_prefix_link { prefix = "F10%.1", text = "Alcohol Abuse" }
    local f102_codes = codes.get_code_prefix_link { prefix = "F10%.2", text = "Alcohol Dependence" }
    local alcohol_intoxication_code = links.get_code_links {
        codes = { "F10.120", "F10.121", "F10.129" },
        text = "Alcohol Intoxication"
    }
    local alcohol_withdrawal_abs = links.get_abstraction_link {
        code = "ALCOHOL_WITHDRAWAL",
        text = "Alcohol Withdrawal"
    }
    local alcohol_heptac_fail_code = links.get_code_links {
        codes = { "K70.40", "K70.41" },
        text = "Alcoholic Hepatic Failure"
    }
    local r4182_code = links.get_code_link { code = "R41.82", text = "Altered Mental Status" }
    local cerebral_edema_abs = links.get_abstraction_link { code = "CEREBRAL_EDEMA", text = "Cerebral Edema" }
    local i63_codes = codes.get_code_prefix_link { prefix = "I63%.", text = "Cerebral Infarction" }
    local cerebral_ischemia_abs = links.get_abstraction_link {
        code = "CEREBRAL_ISCHEMIA",
        text = "Cerebral Ischemia"
    }
    local ch_baseline_mental_status_abs = links.get_abstraction_link {
        code = "CHANGE_IN_BASELINE_MENTAL_STATUS",
        text = "Change in Baseline Mental Status"
    }
    local chronic_hepatic_failure_code = links.get_code_links {
        codes = { "K72.10", "K72.11" },
        text = "Chronic Hepatic Failure"
    }
    local coma_abs = links.get_abstraction_link { code = "COMA", text = "Coma" }
    local s07_codes = codes.get_code_prefix_link { prefix = "S07%.", text = "Crushing Head Injury" }
    local r410_code = links.get_code_link { code = "R41.0", text = "Disorientation" }
    local heavy_metal_poisioning_abs = links.get_abstraction_link {
        code = "HEAVY_METAL_POISIONING",
        text = "Heavy Metal Poisioning"
    }
    local hepatic_failure_code = links.get_code_links {
        codes = { "K72.90", "K72.91" },
        text = "Hepatic Failure"
    }
    local i160_code = codes.get_code_prefix_link { prefix = "I16%.0", text = "Hypertensive Crisis Code" }
    local infection_abs = links.get_abstraction_link { code = "INFECTION", text = "Infection" }
    local influenza_a_abs = links.get_abstraction_link { code = "INFLUENZA_A", text = "Influenza A" }
    local s06_codes = codes.get_code_prefix_link { prefix = "S06%.", text = "Intracranial Injury" }
    local g0481_code = links.get_code_link { code = "G04.81", text = "Liver" }
    local k7460_code = links.get_code_link { code = "K74.60", text = "Liver Cirrhosis" }
    local e8841_code = links.get_code_link { code = "E88.41", text = "MELAS Syndrome" }
    local e8840_code = links.get_code_link { code = "E88.40", text = "Mitochondrial Metabolism Disorder" }
    local e035_code = links.get_code_link { code = "E03.5", text = "Myxedema Coma" }
    local obtunded_abs = links.get_abstraction_link { code = "OBTUNDED", text = "Obtunded" }
    local opiodid_overdose_abs = links.get_abstraction_link {
        code = "OPIOID_OVERDOSE",
        text = "Opioid Overdose"
    }
    local opioid_withdrawal_abs = links.get_abstraction_link {
        code = "OPIOID_WITHDRAWAL",
        text = "Opioid Withdrawal"
    }

    local t36_codes = codes.get_code_prefix_link { prefix = "T36%.", text = "Poisoning" }
    local t37_codes = codes.get_code_prefix_link { prefix = "T37%.", text = "Poisoning" }
    local t38_codes = codes.get_code_prefix_link { prefix = "T38%.", text = "Poisoning" }
    local t39_codes = codes.get_code_prefix_link { prefix = "T39%.", text = "Poisoning" }
    local t40_codes = codes.get_code_prefix_link { prefix = "T40%.", text = "Poisoning" }
    local t41_codes = codes.get_code_prefix_link { prefix = "T41%.", text = "Poisoning" }
    local t42_codes = codes.get_code_prefix_link { prefix = "T42%.", text = "Poisoning" }
    local t43_codes = codes.get_code_prefix_link { prefix = "T43%.", text = "Poisoning" }
    local t44_codes = codes.get_code_prefix_link { prefix = "T44%.", text = "Poisoning" }
    local t45_codes = codes.get_code_prefix_link { prefix = "T45%.", text = "Poisoning" }
    local t46_codes = codes.get_code_prefix_link { prefix = "T46%.", text = "Poisoning" }
    local t47_codes = codes.get_code_prefix_link { prefix = "T47%.", text = "Poisoning" }
    local t48_codes = codes.get_code_prefix_link { prefix = "T48%.", text = "Poisoning" }
    local t49_codes = codes.get_code_prefix_link { prefix = "T49%.", text = "Poisoning" }
    local t50_codes = codes.get_code_prefix_link { prefix = "T50%.", text = "Poisoning" }
    local f29_code = links.get_code_link { code = "F29", text = "Postconcussional Syndrome" }

    local psychosis_abs = links.get_abstraction_link { code = "PSYCHOSIS", text = "Psychosis" }
    local sepsis_code = links.get_code_links {
        codes = {
            "A41.2", "A41.3", "A41.4", "A41.50", "A41.51", "A41.52", "A41.53", "A41.54", "A41.59",
            "A41.81", "A41.89", "A41.9", "A42.7", "A22.7", "B37.7", "A26.7", "A54.86", "B00.7", "A32.7", "A24.1",
            "A20.7", "T81.44XA", "T81.44XD"
        },
        text = "Sepsis"
    }
    local severe_malnutrition = links.get_code_links {
        codes = { "E40", "E41", "E42", "E43" },
        text = "Severe Malnutrition"
    }
    local stimulant_intoxication = links.get_code_links {
        codes = { "F15.120", "F15.121", "F15.129" },
        text = "Stimulant Intoxication"
    }
    local f1510_code = links.get_code_link { code = "F15.10", text = "Stimulant Abuse" }
    local r401_code = links.get_code_link { code = "R40.1", text = "Stupor" }
    local t51_codes = codes.get_code_prefix_link { prefix = "T51%.", text = "Toxic Effects of Alcohol" }
    local t58_codes = codes.get_code_prefix_link { prefix = "T58%.", text = "Toxic Effects of Carbon Monoxide" }
    local t57_codes = codes.get_code_prefix_link { prefix = "T57%.", text = "Toxic Effects of Inorganic Substance" }
    local t56_codes = codes.get_code_prefix_link { prefix = "T56%.", text = "Toxic Effects of Metals" }
    local k712_code = links.get_code_link { code = "K71.2", text = "Toxic Liver Disease with Acute Hepatitis" }
    local toxic_liver_disease_code = links.get_code_links {
        codes = { "K71.10", "K71.11" },
        text = "Toxic Liver Disease with Hepatic Necrosis"
    }
    local type_i_diabetic_keto = links.get_code_links {
        codes = { "E10.10", "E10.11" },
        text = "Type I Diabetic Ketoacidosis"
    }
    local type_ii_diabetic_keto = links.get_code_links {
        codes = { "E11.10", "E11.11" },
        text = "Type II Diabetic Ketoacidosis"
    }
    local e1100_code = links.get_code_link {
        code = "E11.00",
        text = "Type II Diabetes with Hyperosmolarity without NKHHC"
    }
    local e1101_code = links.get_code_link {
        code = "E11.01",
        text = "Type II Diabetes with Hyperosmolarity with Coma"
    }

    -- Labs
    local cblood_discrete_value_names = links.get_discrete_value_link {
        discreteValueNames = dv_c_blood,
        text = "Blood Culture Result: '[VALUE]' (Result Date: [RESULTDATETIME])",
        predicate = function(dv, num_)
            return string.find(dv.result, "positive") ~= nil or string.find(dv.result, "detected") ~= nil
        end
    }
    local ethanol_discrete_value_names = links.get_discrete_value_link {
        discreteValueNames = dv_ethanol_level,
        text = "Ethanol Level: [VALUE] (Result Date: [RESULTDATETIME])",
        predicate = calc_ethanol_level1
    }
    local e162_code = links.get_code_link { code = "E16.2", text = "Hypoglycemia" }
    local r0902_code = links.get_code_link { code = "R09.02", text = "Hypoxemia" }
    local positive_cerebrospinal_fluid_culture_abs = links.get_abstraction_link {
        code = "POSITIVE_CEREBROSPINAL_FLUID_CULTURE",
        text = "Positive Cerebrospinal Fluid Culture"
    }
    local uremia_abs = links.get_abstraction_link { code = "UREMIA", text = "Uremia" }
    local ua_bacteria_discrete_value_names = links.get_discrete_value_link {
        discreteValueNames = dv_ua_bacteria,
        text = "UA Bacteria: [VALUE] (Result Date: [RESULTDATETIME])",
        predicate = function(dv, num_)
            return string.find(dv.result, "positive") ~= nil or string.find(dv.result, "present") ~= nil
        end
    }
    local urine_discrete_value_names = links.get_discrete_value_link {
        discreteValueNames = dv_c_urine,
        text = "Urine Culture Result: '[VALUE]' (Result Date: [RESULTDATETIME])",
        predicate = function(dv, num_)
            return string.find(dv.result, "positive") ~= nil or string.find(dv.result, "detected") ~= nil
        end
    }
    --[[
    #Lab Sub Categories
    highBloodGlucosediscreteValueNames = dvValueMulti(dict(maindiscreteDic), dvBloodGlucose, "Blood Glucose: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodGlucose1, gt, 0, glucose, False, 10)
    highBloodGlucosePOCdiscreteValueNames = dvValueMulti(dict(maindiscreteDic), dvBloodGlucosePOC, "Blood Glucose: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodGlucosePOC1, gt, 0, glucose, False, 10)
    lowBloodGlucosediscreteValueNames = dvValueMulti(dict(maindiscreteDic), dvBloodGlucose, "Blood Glucose: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodGlucose2, lt, 0, glucose, False, 10)
    lowBloodGlucosePOCdiscreteValueNames = dvValueMulti(dict(maindiscreteDic), dvBloodGlucosePOC, "Blood Glucose: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodGlucosePOC2, lt, 0, glucose, False, 10)
    serumAmmoniadiscreteValueNames = dvValueMulti(dict(maindiscreteDic), dvSerumAmmonia, "Serum Ammonia: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumAmmonia1, gt, 0, ammonia, False, 10)
    highSerumBloodUreaNitrogendiscreteValueNames = dvValueMulti(dict(maindiscreteDic), dvSerumBloodUreaNitrogen, "Serum Blood Urea Nitrogen: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumBloodUreaNitrogen1, gt, 0, bun, False, 10)
    serumCalcium1discreteValueNames = dvValueMulti(dict(maindiscreteDic), dvSerumCalcium, "Serum Calcium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumCalcium1, gt, 0, calcium, False, 10)
    serumCalcium2discreteValueNames = dvValueMulti(dict(maindiscreteDic), dvSerumCalcium, "Serum Calcium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumCalcium2, lt, 0, calcium, False, 10)
    serumCreatinine1discreteValueNames = dvValueMulti(dict(maindiscreteDic), dvSerumCreatinine, "Serum Creatinine: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumCreatinine1, gt, 0, creatinine, False, 10)
    serumSodium1discreteValueNames = dvValueMulti(dict(maindiscreteDic), dvSerumSodium, "Serum Sodium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumSodium1, gt, 0, sodium, False, 10)
    serumSodium2discreteValueNames = dvValueMulti(dict(maindiscreteDic), dvSerumSodium, "Serum Sodium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumSodium2, lt, 0, sodium, False, 10)

    --]]
    -- Lab Sub Categories
    local high_blood_glucose_dvs = links.get_discrete_value_links {
        discreteValueNames = dv_blood_glucose,
        text = "Blood Glucose: [VALUE] (Result Date: [RESULTDATETIME])",
        predicate = calc_blood_glucose1
    }
    --[[
    #ABG Sub Categories
    pao2discreteValueNames = dvValueMulti(dict(maindiscreteDic), dvPaO2, "p02: [VALUE] (Result Date: [RESULTDATETIME])", calcPAO21, lt, 0, p02, False, 10)
    lowArterialBloodPHdiscreteValueNames = dvValueMulti(dict(maindiscreteDic), dvArterialBloodPH, "PH: [VALUE] (Result Date: [RESULTDATETIME])", calcArterialBloodPH1, lt, 0, ph, False, 10)
    pco2discreteValueNames = dvValueMulti(dict(maindiscreteDic), dvPC02, "paC02: [VALUE] (Result Date: [RESULTDATETIME])", calcPC021, gt, 0, pco2, False, 10)

    --]]
    --[[
    #Meds
    antibioticMed = antiboticMedValue(dict(mainMedDic), "Antibiotic", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 2)
    antibioticAbs = abstractValue("ANTIBIOTIC", "Antibiotic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3)
    antibiotic2Med = antiboticMedValue(dict(mainMedDic), "Antibiotic2", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 4)
    antibiotic2Abs = abstractValue("ANTIBIOTIC_2", "Antibiotic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5)
    anticonvulsantMed = medValue("Anticonvulsant", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 6)
    anticonvulsantAbs = abstractValue("ANTICONVULSANT", "Anticonvulsant '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7)
    antifungalMed = medValue("Antifungal", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 8)
    antifungalAbs = abstractValue("ANTIFUNGAL", "Antifungal '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9)
    antiviralMed = medValue("Antiviral", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 10)
    antiviralAbs = abstractValue("ANTIVIRAL", "Antiviral '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11)
    dextroseMed = medValue("Dextrose 50%", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 14)
    encephalopathyMedicationAbs = abstractValue("ENCEPHALOPATHY_MEDICATION", "Encephalopathy Medication '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 15)

    --]]
    --[[
    #Vitals
    diastolicHyperTensiveCrisisdiscreteValueNames = dvValue(dvDBP, "Diastolic Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcDBP1, 2)
    systolicHyperTensiveCrisisdiscreteValueNames = dvValue(dvSBP, "Systolic Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcSBP1, 3)
    lowPulseOximetrydiscreteValueNames = dvValue(dvSPO2, "Sp02: [VALUE] (Result Date: [RESULTDATETIME])", calcSPO21, 4)
    highTempdiscreteValueNames = dvValue(dvTemperature, "Temperature: [VALUE] (Result Date: [RESULTDATETIME])", calcTemperature1, 5)
    temp2discreteValueNames = dvValue(dvTemperature, "Temperature: [VALUE] (Result Date: [RESULTDATETIME])", calcTemperature2, 6)

    --]]
    --[[
    #Drug
    amphetamineDrug = dvPositiveCheck(dict(maindiscreteDic), dvAmphetamineScreen, "Amphetamine Screen Urine: '[VALUE]' (Result Date: [RESULTDATETIME])", 1)
    barbiturateDrug = dvPositiveCheck(dict(maindiscreteDic), dvBarbiturateScreen, "Barbiturate Screen Urine: '[VALUE]' (Result Date: [RESULTDATETIME])", 2)
    benzodiazepineDrug = dvPositiveCheck(dict(maindiscreteDic), dvBenzodiazepineScreen, "Benzodiazepine Screen Urine: '[VALUE]' (Result Date: [RESULTDATETIME])", 3)
    buprenorphineDrug = dvPositiveCheck(dict(maindiscreteDic), dvBuprenorphineScreen, "Buprenorphine Screen Urine: '[VALUE]' (Result Date: [RESULTDATETIME])", 4)
    cannabinoidDrug = dvPositiveCheck(dict(maindiscreteDic), dvCannabinoidScreen, "Cannabinoid Screen Urine: '[VALUE]' (Result Date: [RESULTDATETIME])", 5)
    cocaineDrug = dvPositiveCheck(dict(maindiscreteDic), dvCocaineScreen, "Cocaine Screen Urine: '[VALUE]' (Result Date: [RESULTDATETIME])", 6)
    methadoneDrug = dvPositiveCheck(dict(maindiscreteDic), dvMethadoneScreen, "Methadone Screen Urine: '[VALUE]' (Result Date: [RESULTDATETIME])", 7)
    opiateDrug = dvPositiveCheck(dict(maindiscreteDic), dvOpiateScreen, "Opiate Screen Urine: '[VALUE]' (Result Date: [RESULTDATETIME])", 8)
    oxycodoneDrug = dvPositiveCheck(dict(maindiscreteDic), dvOxycodoneScreen, "Oxycodone Screen Urine: '[VALUE]' (Result Date: [RESULTDATETIME])", 9)

    --]]
    --[[
    #Neurologic Change Indicators Count
    if psychosisAbs is not None: abs.Links.Add(psychosisAbs); NCI += 1
    if r410Code is not None: abs.Links.Add(r410Code); NCI += 1
    if r4182Code is not None: abs.Links.Add(r4182Code); NCI += 1
    if obtundedAbs is not None: abs.Links.Add(obtundedAbs); NCI += 1
    if r401Code is not None: abs.Links.Add(r401Code); NCI += 1
    if comaAbs is not None: abs.Links.Add(comaAbs); NCI += 1
    if chBaselineMenStatusAbs is not None: abs.Links.Add(chBaselineMenStatusAbs); NCI += 1
    db.LogEvaluationScriptMessage("NCI Score " + str(NCI) + " " + str(account._id), scriptName, scriptInstance, "Debug")

    --]]
    --[[
    #Abstracting Glasgow based on NCI score
    glasgowComaScorediscreteValueNames = []
    if (Dementia1 is not None or Dementia2 is not None or Dementia3 is not None or alzheimersNeg is not None) and chBaselineMenStatusAbs is None:
        if NCI > 0:
            glasgowComaScorediscreteValueNames = GlasgowLinkedValues(dict(maindiscreteDic), dvGlasgowComaScale, dvGlasgowEyeOpening, dvGlasgowVerbal, dvGlasgowMotor, dvOxygenTherapy, calcGlasgowComaScale2, False)
        elif NCI == 0:
            glasgowComaScorediscreteValueNames = GlasgowLinkedValues(dict(maindiscreteDic), dvGlasgowComaScale, dvGlasgowEyeOpening, dvGlasgowVerbal, dvGlasgowMotor, dvOxygenTherapy, calcGlasgowComaScale2, True)

    else:
        if NCI > 0:
            glasgowComaScorediscreteValueNames = GlasgowLinkedValues(dict(maindiscreteDic), dvGlasgowComaScale, dvGlasgowEyeOpening, dvGlasgowVerbal, dvGlasgowMotor, dvOxygenTherapy, calcGlasgowComaScale1, False)
        elif NCI == 0:
            glasgowComaScorediscreteValueNames = GlasgowLinkedValues(dict(maindiscreteDic), dvGlasgowComaScale, dvGlasgowEyeOpening, dvGlasgowVerbal, dvGlasgowMotor, dvOxygenTherapy, calcGlasgowComaScale1, True)

    --]]
    --[[
    #Clinical Indicators Count
    if serumAmmoniaDV is not None: CI += 1
    if highTempDV is not None or temp2DV is not None:
        if highTempDV is not None: vitals.Links.Add(highTempDV)
        CI += 1
    if lowArterialBloodPHDV is not None: CI += 1
    if positiveCerebrospinalFluidCultureAbs is not None: labs.Links.Add(positiveCerebrospinalFluidCultureAbs); CI += 1
    if serumSodium1DV is not None or serumSodium2DV is not None:
        CI += 1
    if uremiaAbs is not None: labs.Links.Add(uremiaAbs); CI += 1
    if (
        diastolicHyperTensiveCrisisDV is not None or
        systolicHyperTensiveCrisisDV is not None
    ):
        if diastolicHyperTensiveCrisisDV is not None: vitals.Links.Add(diastolicHyperTensiveCrisisDV)
        if systolicHyperTensiveCrisisDV is not None: vitals.Links.Add(systolicHyperTensiveCrisisDV)
        CI += 1
    if serumCalcium1DV is not None or serumCalcium2DV is not None:
        CI += 1
    if cerebralEdemaAbs is not None: abs.Links.Add(cerebralEdemaAbs); CI += 1
    if cerebralIschemiaAbs is not None: abs.Links.Add(cerebralIschemiaAbs); CI += 1
    if pao2DV is not None or r0902Code is not None:
        if r0902Code is not None: vitals.Links.Add(r0902Code)
        CI += 1
    if lowPulseOximetryDV is not None: vitals.Links.Add(lowPulseOximetryDV); CI += 1
    if (
        (highBloodGlucoseDV is not None or
        highBloodGlucosePOCDV is not None or
        e162Code is not None) or
        (lowBloodGlucoseDV is not None or
        lowBloodGlucosePOCDV is not None)
    ):
        if e162Code is not None: labs.Links.Add(e162Code)
        CI += 1
    if opioidWithdrawalAbs is not None: abs.Links.Add(opioidWithdrawalAbs); CI += 1
    if sepsisCode is not None: abs.Links.Add(sepsisCode); CI += 1
    if alcoholWithdrawalAbs is not None: abs.Links.Add(alcoholWithdrawalAbs); CI += 1
    if (
        acuteSubacuteHepaticFailCode is not None or
        AlcoholHeptacFailCode is not None or
        chronicHepaticFailureCode is not None or
        hepaticFailureCode is not None or
        k712Code is not None or
        toxicLiverDiseaseCode is not None
    ):
        if acuteSubacuteHepaticFailCode is not None: abs.Links.Add(acuteSubacuteHepaticFailCode)
        if AlcoholHeptacFailCode is not None: abs.Links.Add(AlcoholHeptacFailCode)
        if chronicHepaticFailureCode is not None: abs.Links.Add(chronicHepaticFailureCode)
        if hepaticFailureCode is not None: abs.Links.Add(hepaticFailureCode)
        if k712Code is not None: abs.Links.Add(k712Code)
        if toxicLiverDiseaseCode is not None: abs.Links.Add(toxicLiverDiseaseCode)
        CI += 1
    if highSerumBloodUreaNitrogenDV is not None: CI += 1
    if opiodidOverdoseAbs is not None: abs.Links.Add(opiodidOverdoseAbs); CI += 1
    if stimulantIntoxication is not None: abs.Links.Add(stimulantIntoxication); CI += 1
    if f1510Code is not None: abs.Links.Add(f1510Code); CI += 1
    if heavyMetalPoisioningAbs is not None: abs.Links.Add(heavyMetalPoisioningAbs); CI += 1
    if infectionAbs is not None: abs.Links.Add(infectionAbs); CI += 1
    if acuteKidneyFailureAbs is not None: abs.Links.Add(acuteKidneyFailureAbs); CI += 1
    if encephalopathyMedicationAbs is not None: meds.Links.Add(encephalopathyMedicationAbs); CI += 1
    if antiviralAbs is not None or antiviralMed is not None:
        if antiviralMed is not None: meds.Links.Add(antiviralMed)
        if antiviralAbs is not None: meds.Links.Add(antiviralAbs)
        CI += 1
    if antifungalAbs is not None or antifungalMed is not None:
        if antifungalMed is not None: meds.Links.Add(antifungalMed)
        if antifungalAbs is not None: meds.Links.Add(antifungalAbs)
        CI += 1
    if antibioticAbs is not None or antibioticMed is not None or antibiotic2Abs is not None or antibiotic2Med is not None:
        if antibioticMed is not None: meds.Links.Add(antibioticMed)
        if antibioticAbs is not None: meds.Links.Add(antibioticAbs)
        if antibiotic2Med is not None: meds.Links.Add(antibiotic2Med)
        if antibiotic2Abs is not None: meds.Links.Add(antibiotic2Abs)
        CI += 1
    if anticonvulsantMed is not None or anticonvulsantAbs is not None:
        if anticonvulsantMed is not None: meds.Links.Add(anticonvulsantMed)
        if anticonvulsantAbs is not None: meds.Links.Add(anticonvulsantAbs)
        CI += 1
    if dextroseMed is not None: meds.Links.Add(dextroseMed); CI += 1
    if g0481Code is not None: abs.Links.Add(g0481Code); CI += 1
    if i160Code is not None: abs.Links.Add(i160Code); CI += 1
    if typeIDiabeticKeto is not None: abs.Links.Add(typeIDiabeticKeto); CI += 1
    if typeIIDiabeticKeto is not None: abs.Links.Add(typeIIDiabeticKeto); CI += 1
    if e1100Code is not None: abs.Links.Add(e1100Code); CI += 1
    if e1101Code is not None: abs.Links.Add(e1101Code); CI += 1
    if f101Codes is not None: abs.Links.Add(f101Codes); CI += 1
    if f102Codes is not None: abs.Links.Add(f102Codes); CI += 1
    if s07Codes is not None: abs.Links.Add(s07Codes); CI += 1
    if influenzaAAbs is not None: abs.Links.Add(influenzaAAbs); CI += 1
    if e8841Code is not None: abs.Links.Add(e8841Code); CI += 1
    if e8840Code is not None: abs.Links.Add(e8840Code); CI += 1
    if e035Code is not None: abs.Links.Add(e035Code); CI += 1
    if f29Code is not None: abs.Links.Add(f29Code); CI += 1
    if severeMalnutrition is not None: abs.Links.Add(severeMalnutrition); CI += 1
    if s06Codes is not None: abs.Links.Add(s06Codes); CI += 1
    if cbloodDV is not None: CI += 1
    if uaBacteriaDV is not None: CI += 1
    if urineDV is not None: CI += 1
    if serumCreatinine1DV is not None: CI += 1
    if pco2DV is not None: CI += 1
    if (
        t36Codes is not None or 
        t37Codes is not None or 
        t38Codes is not None or 
        t39Codes is not None or 
        t40Codes is not None or 
        t41Codes is not None or 
        t42Codes is not None or 
        t43Codes is not None or 
        t44Codes is not None or 
        t45Codes is not None or 
        t46Codes is not None or 
        t47Codes is not None or 
        t48Codes is not None or 
        t49Codes is not None or 
        t50Codes is not None
    ):
        CI += 1
        if t36Codes is not None: abs.Links.Add(t36Codes)
        if t37Codes is not None: abs.Links.Add(t37Codes)
        if t38Codes is not None: abs.Links.Add(t38Codes)
        if t39Codes is not None: abs.Links.Add(t39Codes)
        if t40Codes is not None: abs.Links.Add(t40Codes)
        if t41Codes is not None: abs.Links.Add(t41Codes)
        if t42Codes is not None: abs.Links.Add(t42Codes)
        if t43Codes is not None: abs.Links.Add(t43Codes)
        if t44Codes is not None: abs.Links.Add(t44Codes)
        if t45Codes is not None: abs.Links.Add(t45Codes)
        if t46Codes is not None: abs.Links.Add(t46Codes)
        if t47Codes is not None: abs.Links.Add(t47Codes)
        if t48Codes is not None: abs.Links.Add(t48Codes)
        if t49Codes is not None: abs.Links.Add(t49Codes)
        if t50Codes is not None: abs.Links.Add(t50Codes)
    if t51Codes is not None: CI += 1; abs.Links.Add(t51Codes)
    if t58Codes is not None: CI += 1; abs.Links.Add(t58Codes)
    if t57Codes is not None: CI += 1; abs.Links.Add(t57Codes)
    if t56Codes is not None: CI += 1; abs.Links.Add(t56Codes)
    if amphetamineDrug is not None: drug.Links.Add(amphetamineDrug); CI += 1
    if barbiturateDrug is not None: drug.Links.Add(barbiturateDrug); CI += 1
    if benzodiazepineDrug is not None: drug.Links.Add(benzodiazepineDrug); CI += 1
    if buprenorphineDrug is not None: drug.Links.Add(buprenorphineDrug); CI += 1
    if cannabinoidDrug is not None: drug.Links.Add(cannabinoidDrug); CI += 1
    if cocaineDrug is not None: drug.Links.Add(cocaineDrug); CI += 1
    if methadoneDrug is not None: drug.Links.Add(methadoneDrug); CI += 1
    if opiateDrug is not None: drug.Links.Add(opiateDrug); CI += 1
    if oxycodoneDrug is not None: drug.Links.Add(oxycodoneDrug); CI += 1
    if ethanolDV is not None: labs.Links.Add(ethanolDV); CI += 1
    if i63Codes is not None: abs.Links.Add(i63Codes); CI += 1
    --]]



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    --[[
    if triggerAlert and subtitle == "Encephalopathy Dx Documented Possibly Lacking Supporting Evidence" and codesExist == 1 and (NCI > 0 or glasgowComaScoreDV):
        if glasgowComaScoreDV:
            dc.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, False))
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Glascow Coma Score or NCI Existing on the Account"
        result.Validated = True
        AlertConditions = True

    elif triggerAlert and codesExist == 1 and r4182Code is None and glasgowComaScoreDV is None and NCI == 0:
        for code in codeList:
            desc = codeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            if tempCode is not None:
                dc.Links.Add(tempCode)
                break
        if not glasgowComaScoreDV: dc.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, True))
        result.Subtitle = "Encephalopathy Dx Documented Possibly Lacking Supporting Evidence"
        AlertPassed = True
    
    elif (
        subtitle == "Hepatic Encephalopathy Documented, but No Evidence of Liver Failure Found" and
        (liverNeg1 is not None or liverNeg2 is not None or liverNeg3 is not None or
        liverNeg4 is not None or liverNeg5 is not None or liverNeg6 is not None or
        liverNeg7 is not None) and
        k7682Code is not None
    ):
        if liverNeg1 is not None: dc.Links.Add(liverNeg1)
        if liverNeg2 is not None: dc.Links.Add(liverNeg2)
        if liverNeg3 is not None: dc.Links.Add(liverNeg3)
        if liverNeg4 is not None: dc.Links.Add(liverNeg4)
        if liverNeg5 is not None: dc.Links.Add(liverNeg5)
        if liverNeg6 is not None: dc.Links.Add(liverNeg6)
        if liverNeg7 is not None: dc.Links.Add(liverNeg7)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Liver Disease/Failure DX Code Existing On Account."
        result.Validated = True
        AlertConditions = True

    elif (
        triggerAlert and
        k7682Code is not None and
        (liverNeg1 is None and liverNeg2 is None and liverNeg3 is None and
         liverNeg4 is None and liverNeg5 is None and liverNeg6 is None and
         liverNeg7 is None)
    ):
        dc.Links.Add(k7682Code)
        result.Subtitle = "Hepatic Encephalopathy Documented, but No Evidence of Liver Failure Found"
        AlertPassed = True    
                
    elif codesExist > 1 and not (g928Code is not None and g9341Code is not None) or codesExist > 2:
        for code in codeList:
            desc = codeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            dc.Links.Add(tempCode)
        if validated:
            result.Validated = False
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"
        result.Subtitle = "Encephalopathy Conflicting Dx " + str1
        AlertPassed = True
        
    elif codesExist == 1 or severeAlzheimersAbs is not None or severeDementiaAbs is not None:
        db.LogEvaluationScriptMessage("One specific code was on the chart, alert failed. " + str(alertTriggered) + " " + str(account._id), scriptName, scriptInstance, "Debug")
        if alertTriggered:
            for code in codeList:
                desc = codeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    dc.Links.Add(tempCode)
                    break
            if severeAlzheimersAbs is not None: dc.Links.Add(severeAlzheimersAbs)
            if severeDementiaAbs is not None: dc.Links.Add(severeDementiaAbs)
            result.Outcome = "AUTORESOLVED"
            result.Reason = "Autoresolved due to one Specified Code on the Account"
            result.Validated = True
            AlertConditions = True
            db.LogEvaluationScriptMessage("Alert Autoclosed due to one specific code" + str(account._id), scriptName, scriptInstance, "Debug")
        else: result.Passed = False

    elif triggerAlert and g9340Code is not None:
        dc.Links.Add(g9340Code)
        result.Subtitle = "Unspecified Encephalopathy Dx"
        AlertPassed = True

    elif triggerAlert and (len(glasgowComaScoreDV) > 2 or (len(glasgowComaScoreDV) == 1 and NCI > 0)) and CI > 0:
        result.Subtitle = "Possible Encephalopathy Dx"
        AlertPassed = True

    elif (
        len(glasgowComaScoreDV) > 0 or
        (NCI >= 1 and Dementia1 is None and Dementia2 is None and Dementia3 is None and alzheimersNeg is None) or
        (chBaselineMenStatusAbs is not None and (Dementia1 is not None or Dementia2 is not None or Dementia3 is not None or alzheimersNeg is not None))
    ):
        if (chBaselineMenStatusAbs is not None and (Dementia1 is not None or Dementia2 is not None or Dementia3 is not None or alzheimersNeg is not None)):
            if chBaselineMenStatusAbs is not None: dc.Links.Add(chBaselineMenStatusAbs)
            if Dementia1 is not None: dc.Links.Add(Dementia1)
            if Dementia2 is not None: dc.Links.Add(Dementia2)
            if Dementia3 is not None: dc.Links.Add(Dementia3)
            if alzheimersNeg is not None: dc.Links.Add(alzheimersNeg)
        result.Subtitle = "Altered Mental Status"
        AlertPassed = True
        
    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

    --]]


    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            --[[
            #Abs
            #1
            codeValue("R94.01", "Abnormal Electroencephalogram (EEG): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, abs, True)
            abstractValue("ACE_CONSULT", "ACE Consult '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3, abs, True)
            #4-5
            abstractValue("AGITATION", "Agitation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6, abs, True)
            #7-12
            alteredAbs = abstractValue("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level Of Consciousness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13)
            if r4182Code is not None:
                if alteredAbs is not None: alteredAbs.Hidden = True; abs.Links.Add(alteredAbs)
            elif r4182Code is None and alteredAbs is not None:
                abs.Links.Add(alteredAbs)
            codeValue("R47.01", "Aphasia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, abs, True)
            codeValue("R18.8", "Ascities: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
            abstractValue("ATAXIA", "Ataxia '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 16, abs, True)
            #17-22
            abstractValue("COMBATIVE", "Combativeness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 23, abs, True)
            #24-25
            codeValue("E86.0", "Dehydration: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 26, abs, True)
            codeValue("F07.81", "Fatigue: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 27, abs, True)
            codeValue("R44.3", "Hallucinations: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 28, abs, True)
            #29-30
            codeValue("E87.0", "Hypernatremia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 31, abs, True)
            #32-35
            codeValue("R17", "Jaundice: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 36, abs, True)
            codeValue("R53.83", "Lethargy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 37, abs, True)
            #38-43
            abstractValue("ONE_TO_ONE_SUPERVISION", "One to one supervision: '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 44, abs, True)
            #45-61
            abstractValue("POSSIBLE_ENCEPHALOPATHY", "Possible Encephalopathy '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 62, abs, True)
            #63-64
            abstractValue("RESTLESSNESS", "Restlessness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 65, abs, True)
            codeValue("R10.811", "Right Upper Quadrant Tenderness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 66, abs, True)
            abstractValue("SEIZURE", "Seizure '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 67, abs, True)
            #68-69
            codeValue("R47.81", "Slurred Speech: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 70, abs, True)
            codeValue("R40.0", "Somnolence: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 71, abs, True)
            #72-74
            abstractValue("SUNDOWNING", "Sundowning '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 75, abs, True)
            #76-85
            codeValue("S09.90", "Unspecified Injury of Head: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 86, abs, True)
            #Document Links
            documentLink("CT Head WO", "CT Head WO", 0, ctHeadBrainLinks, True)
            documentLink("CT Head Stroke Alert", "CT Head Stroke Alert", 0, ctHeadBrainLinks, True)
            documentLink("CTA Head-Neck", "CTA Head-Neck", 0, ctHeadBrainLinks, True)
            documentLink("CTA Head", "CTA Head", 0, ctHeadBrainLinks, True)
            documentLink("CT Head  WWO", "CT Head  WWO", 0, ctHeadBrainLinks, True)
            documentLink("CT Head  W", "CT Head  W", 0, ctHeadBrainLinks, True)
            documentLink("MRI Brain WWO", "MRI Brain WWO", 0, mriBrainLinks, True)
            documentLink("MRI Brain  W and W/O Contrast", "MRI Brain  W and W/O Contrast", 0, mriBrainLinks, True)
            documentLink("WO", "WO", 0, mriBrainLinks, True)
            documentLink("MRI Brain W/O Contrast", "MRI Brain W/O Contrast", 0, mriBrainLinks, True)
            documentLink("MRI Brain W/O Con", "MRI Brain W/O Con", 0, mriBrainLinks, True)
            documentLink("MRI Brain  W and W/O Con", "MRI Brain  W and W/O Con", 0, mriBrainLinks, True)
            documentLink("MRI Brain  W", "MRI Brain  W", 0, mriBrainLinks, True)
            documentLink("MRI Brain  W/ Contrast", "MRI Brain  W/ Contrast", 0, mriBrainLinks, True)
            documentLink("EEG Report", "EEG Report", 0, eegLinks, True)
            documentLink("EEG", "EEG", 0, eegLinks, True)
            #Labs
            dvValue(dvAlkalinePhos, "Alkaline Phos: [VALUE] (Result Date: [RESULTDATETIME])", calcAlkalinePhos1, 1, labs, True)
            dvValue(dvBilirubinTotal, "Bilirubin Total: [VALUE] (Result Date: [RESULTDATETIME])", calcBilirubinTotal1, 2, labs, True)
            if cbloodDV is not None: labs.Links.Add(cbloodDV) #3
            #4-8
            if uaBacteriaDV is not None: labs.Links.Add(uaBacteriaDV) #9
            if urineDV is not None: labs.Links.Add(urineDV) #10
            #Meds
            medValue("Anti-Hypoglycemic Agent", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, meds, True)
            #2-11
            medValue("Benzodiazepine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 12, meds, True)
            abstractValue("BENZODIAZEPINE", "Benzodiazepine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13, meds, True)
            #14-15
            medValue("Haloperidol", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 16, meds, True)
            abstractValue("HALOPERIDOL", "Haloperidol '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 17, meds, True)
            medValue("Lactulose", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 18, meds, True)
            abstractValue("LACTULOSE", "Lactulose '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 19, meds, True)
            #Vitals
            multiCodeValue(["F10.220", "F10.221", "F10.229"], "Acute Alcohol Intoxication: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, vitals, True)
            #2-5
            if temp2DV is not None: vitals.Links.Add(temp2DV) #6

            #Glasgow
            if len(glasgowComaScoreDV) > 0:
                for entry in glasgowComaScoreDV:
                    glasgow.Links.Add(entry)
            if glasgowComaScoreDV is None:
                abstractValue("LOW_GLASGOW_COMA_SCORE", "Glasgow Coma Score: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0, glasgow, True)
            #Sub category links
            if highBloodGlucoseDV is not None:
                for entry in highBloodGlucoseDV:
                    glucose.Links.Add(entry)
            if highBloodGlucosePOCDV is not None:
                for entry in highBloodGlucosePOCDV:
                    glucose.Links.Add(entry)
            if lowBloodGlucoseDV is not None:
                for entry in lowBloodGlucoseDV:
                    glucose.Links.Add(entry)
            if lowBloodGlucosePOCDV is not None:
                for entry in lowBloodGlucosePOCDV:
                    glucose.Links.Add(entry)
            if serumAmmoniaDV is not None:
                for entry in serumAmmoniaDV:
                    ammonia.Links.Add(entry)
            if highSerumBloodUreaNitrogenDV is not None:
                for entry in highSerumBloodUreaNitrogenDV:
                    bun.Links.Add(entry)
            if serumCalcium1DV is not None:
                for entry in serumCalcium1DV:
                    calcium.Links.Add(entry)
            if serumCalcium2DV is not None:
                for entry in serumCalcium2DV:
                    calcium.Links.Add(entry)
            if serumCreatinine1DV is not None:
                for entry in serumCreatinine1DV:
                    creatinine.Links.Add(entry)
            if serumSodium1DV is not None:
                for entry in serumSodium1DV:
                    sodium.Links.Add(entry)
            if serumSodium2DV is not None:
                for entry in serumSodium2DV:
                    sodium.Links.Add(entry)
            if lowArterialBloodPHDV is not None:
                for entry in lowArterialBloodPHDV:
                    ph.Links.Add(entry)
            if pao2DV is not None:
                for entry in pao2DV:
                    p02.Links.Add(entry)
            if pco2DV is not None:
                for entry in pco2DV:
                    pco2.Links.Add(entry)
            --]]
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

