---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Encephalopathy (INCOMPLETE)
---
--- This script checks an account to see if it matches the criteria for a encephalopathy alert.
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
local dates = require("libs.common.dates")
local discrete = require("libs.common.discrete_values")(Account)
local headers = require("libs.common.headers")(Account)
local cdi_alert_link = require "cdi.link"



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local dv_alkaline_phos = { "ALKALINE PHOS", "ALK PHOS TOTAL (U/L)" }
local calc_alkaline_phos1 = function(dv_, num) return num > 149 end
local dv_arterial_blood_ph = { "pH" }
local calc_arterial_blood_ph1 = function(dv_, num) return num < 7.30 end
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
local num_glasgow_coma_scale1 = 14
local num_glasgow_coma_scale2 = 12
local dv_pa_o2 = { "BLD GAS O2 (mmHg)", "PO2 (mmHg)" }
local calc_pa_o21 = function(dv_, num) return num < 80 end
local dv_p_co2 = { "BLD GAS CO2 (mmHg)", "PaCO2 (mmHg)" }
local calc_p_co21 = function(dv_, num) return num > 46 end
local dv_sbp = { "SBP 3.5 (No Calculation) (mm Hg)" }
local calc_sbp1 = function(dv_, num) return num > 180 end
local dv_serum_ammonia = { "" }
local calc_serum_ammonia1 = function(dv_, num) return num > 71 end
local dv_serum_blood_urea_nitrogen = { "BUN (mg/dL)" }
local calc_serum_blood_urea_nitrogen1 = function(dv_, num) return num > 20 end
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
local dv_methadone_screen = { "METHADONE URINE", "METHADONE UR" }
local dv_opiate_screen = { "OPIATES URINE", "OPIATES UR" }
local dv_oxycodone_screen = { "OXYCODONE UR", "OXYCODONE URINE" }

local dv_glasgow_eye_opening = { "3.5 Neuro Glasgow Eyes (Adult)" }
local dv_glasgow_verbal = { "3.5 Neuro Glasgow Verbal (Adult)" }
local dv_glasgow_motor = { "3.5 Neuro Glasgow Motor" }
local dv_oxygen_therapy = { "O2 Device" }
local dv_ua_bacteria = { "UA Bacteria (/HPF)" }



--------------------------------------------------------------------------------
--- Script Functions
--------------------------------------------------------------------------------
--- @param value number
--- @param consecutive boolean
--- @return CdiAlertLink[]
local function glasgow_linked_values(value, consecutive)
    local score_dvs = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_glasgow_coma_scale,
        predicate = function(dv_, num) return num ~= nil end
    }
    local eye_dvs = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_glasgow_eye_opening,
        predicate = function(dv, num_) return dv.result ~= nil end
    }
    local verbal_dvs = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_glasgow_verbal,
        predicate = function(dv, num_) return dv.result ~= nil end
    }
    local motor_dvs = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_glasgow_motor,
        predicate = function(dv, num_) return dv.result ~= nil end
    }
    local oxygen_dvs = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_oxygen_therapy,
        predicate = function(dv, num_) return string.find(dv.result, "vent") ~= nil or string.find(dv.result, "Vent") ~= nil end
    }

    local matched_list = {}
    local a = #score_dvs
    local b = #eye_dvs
    local c = #verbal_dvs
    local d = #motor_dvs
    local w = a - 1
    local x = b - 1
    local y = c - 1
    local z = d - 1

    local clean_numbers = function(num) return tonumber(string.gsub(num, "[<>]", "")) end
    local twelve_hour_check = function(date_string, oxygen_dvs_)
        local date_int = dates.date_string_to_int(date_string)
        for _, dv in ipairs(oxygen_dvs_) do
            local dv_date_int = dates.date_string_to_int(dv.result_date)
            local start_date = dv_date_int - (12 * 3600)
            local end_date = dv_date_int - (12 * 3600)
            if start_date <= date_int and date_int <= end_date then
                return false
            end
        end
        return true
    end
    local function get_start_link()
        if
            a > 0 and b > 0 and c > 0 and d > 0 and
            eye_dvs[b].result ~= 'Oriented' and
            clean_numbers(score_dvs[a].result) <= value and
            dates.date_string_to_int(score_dvs[a].result_date) == dates.date_string_to_int(eye_dvs[b].result_date) and
            dates.date_string_to_int(score_dvs[a].result_date) == dates.date_string_to_int(verbal_dvs[c].result_date) and
            dates.date_string_to_int(score_dvs[a].result_date) == dates.date_string_to_int(motor_dvs[d].result_date) and
            twelve_hour_check(score_dvs[a].result_date, oxygen_dvs)
        then
            local matching_date = score_dvs[a].result_date
            local link = cdi_alert_link()
            link.discrete_value_id = score_dvs[a].unique_id
            link.link_text =
                matching_date ..
                " Total GCS = " .. score_dvs[a].result ..
                " (Eye Opening: " .. eye_dvs[b].result ..
                ", Verbal Response: " .. verbal_dvs[c].result ..
                ", Motor Response: " .. motor_dvs[d].result .. ")"
            return link
        end
        return nil
    end

    local function get_last_link()
        if
            w > 0 and x > 0 and y > 0 and z > 0 and
            eye_dvs[x].result ~= 'Oriented' and
            clean_numbers(score_dvs[w].result) <= value and
            dates.date_string_to_int(score_dvs[w].result_date) == dates.date_string_to_int(eye_dvs[x].result_date) and
            dates.date_string_to_int(score_dvs[w].result_date) == dates.date_string_to_int(verbal_dvs[y].result_date) and
            dates.date_string_to_int(score_dvs[w].result_date) == dates.date_string_to_int(motor_dvs[z].result_date) and
            twelve_hour_check(score_dvs[w].result_date, oxygen_dvs)
        then
            local matching_date = score_dvs[w].result_date
            local link = cdi_alert_link()
            link.discrete_value_id = score_dvs[w].unique_id
            link.link_text =
                matching_date ..
                " Total GCS = " .. score_dvs[w].result ..
                " (Eye Opening: " .. eye_dvs[x].result ..
                ", Verbal Response: " .. verbal_dvs[y].result ..
                ", Motor Response: " .. motor_dvs[z].result .. ")"
            return link
        end
        return nil
    end

    if consecutive then
        if a >= 1 then
            for _ in 1, #score_dvs do
                local start_link = get_start_link()
                local last_link = get_last_link()

                if start_link ~= nil and last_link ~= nil then
                    table.insert(matched_list, start_link)
                    table.insert(matched_list, last_link)
                    return matched_list
                else
                    a = a - 1; b = b - 1; c = c - 1; d = d - 1;
                    w = w - 1; x = x - 1; y = y - 1; z = z - 1;
                end
            end
        else
            for _ in 1, #score_dvs do
                local start_link = get_start_link()

                if start_link ~= nil then
                    table.insert(matched_list, start_link)
                    return matched_list
                else
                    a = a - 1; b = b - 1; c = c - 1; d = d - 1;
                end
            end
        end
    else
        for _ in 1, #score_dvs do
            local start_link = get_start_link()

            if start_link ~= nil then
                table.insert(matched_list, start_link)
                return matched_list
            else
                a = a - 1; b = b - 1; c = c - 1; d = d - 1;
            end
        end
    end
    return matched_list
end



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
    local negation_vars = {}
    negation_vars.g931_code = codes.get_code_prefix_link {
        prefix = "G93%.1",
        text = "Anoxic Brain Damage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])"
    }
    negation_vars.dementia1 = codes.get_code_prefix_link { prefix = "F01%.", text = "Dementia" }
    negation_vars.dementia2 = codes.get_code_prefix_link { prefix = "F02%.", text = "Dementia" }
    negation_vars.dementia3 = codes.get_code_prefix_link { prefix = "F03%.", text = "Dementia" }
    negation_vars.alzheimers_neg = codes.get_code_prefix_link { prefix = "G30%.", text = "Alzheimers Disease" }
    negation_vars.vent_discrete_value_names = links.get_discrete_value_link {
        discreteValueNames = dv_oxygen_therapy,
        text = "Ventilator Mentioned In Oxygen Therapy",
        predicate = function(dv, num_)
            return string.find(dv.result, "Vent") ~= nil or string.find(dv.result, "Ventilator") ~= nil
        end
    }

    -- Documented Dx
    local documented_dx_vars = {}
    documented_dx_vars.g9340_code = links.get_code_link { code = "G93.40", text = "Unspecified Encephalopathy" }
    documented_dx_vars.g928_code = links.get_code_link { code = "G92.8", text = "Encephalopathy" }
    documented_dx_vars.g9341_code = links.get_code_link { code = "G93.41", text = "Encephalopathy" }
    documented_dx_vars.k7682_code = links.get_code_link { code = "K76.82", text = "Liver Disease or Failure" }
    documented_dx_vars.severe_alzheimers_abs = links.get_abstraction_link {
        code = "SEVERE_ALZHEIMERS_DISEASE",
        text = "Severe Alzheimers Disease"
    }
    documented_dx_vars.severe_dementia_abs = links.get_abstraction_link { code = "SEVERE_DEMENTIA", text = "Severe Dementia" }
    documented_dx_vars.liver_neg1 = codes.get_code_prefix_link { prefix = "K70%.", text = "Liver Disease or Failure DX Code" }
    documented_dx_vars.liver_neg2 = codes.get_code_prefix_link { prefix = "K71%.", text = "Liver Disease or Failure DX Code" }
    documented_dx_vars.liver_neg3 = codes.get_code_prefix_link { prefix = "K72%.", text = "Liver Disease or Failure DX Code" }
    documented_dx_vars.liver_neg4 = codes.get_code_prefix_link { prefix = "K73%.", text = "Liver Disease or Failure DX Code" }
    documented_dx_vars.liver_neg5 = codes.get_code_prefix_link { prefix = "K74%.", text = "Liver Disease or Failure DX Code" }
    documented_dx_vars.liver_neg6 = codes.get_code_prefix_link { prefix = "K75%.", text = "Liver Disease or Failure DX Code" }
    documented_dx_vars.liver_neg7 = links.get_code_links {
        codes = { "K76.1", "K76.2", "K76.3", "K76.4", "K76.5", "K76.6", "K76.7", "K76.81", "K76.9" },
        text = "Liver Disease or Failure DX Code"
    }
    documented_dx_vars.liver_neg8 = codes.get_code_prefix_link { prefix = "K77%.", text = "Liver Disease or Failure DX Code" }

    documented_dx_vars.r9402_code = links.get_code_link { code = "R94.02", text = "Abnormal Brain Scan" }
    documented_dx_vars.acute_subacute_hepatic_fail_code = links.get_code_links {
        codes = { "K72.00", "K72.01" },
        text = "Acute and Subacute Hepatic Failure"
    }
    documented_dx_vars.acute_kidney_failure_abs = links.get_abstraction_link {
        code = "ACUTE_KIDNEY_FAILURE",
        text = "Acute Kidney Failure"
    }
    documented_dx_vars.f101_codes = codes.get_code_prefix_link { prefix = "F10%.1", text = "Alcohol Abuse" }
    documented_dx_vars.f102_codes = codes.get_code_prefix_link { prefix = "F10%.2", text = "Alcohol Dependence" }
    documented_dx_vars.alcohol_intoxication_code = links.get_code_links {
        codes = { "F10.120", "F10.121", "F10.129" },
        text = "Alcohol Intoxication"
    }
    documented_dx_vars.alcohol_withdrawal_abs = links.get_abstraction_link {
        code = "ALCOHOL_WITHDRAWAL",
        text = "Alcohol Withdrawal"
    }
    documented_dx_vars.alcohol_heptac_fail_code = links.get_code_links {
        codes = { "K70.40", "K70.41" },
        text = "Alcoholic Hepatic Failure"
    }
    documented_dx_vars.r4182_code = links.get_code_link { code = "R41.82", text = "Altered Mental Status" }
    documented_dx_vars.cerebral_edema_abs = links.get_abstraction_link { code = "CEREBRAL_EDEMA", text = "Cerebral Edema" }
    documented_dx_vars.i63_codes = codes.get_code_prefix_link { prefix = "I63%.", text = "Cerebral Infarction" }
    documented_dx_vars.cerebral_ischemia_abs = links.get_abstraction_link {
        code = "CEREBRAL_ISCHEMIA",
        text = "Cerebral Ischemia"
    }
    documented_dx_vars.ch_baseline_mental_status_abs = links.get_abstraction_link {
        code = "CHANGE_IN_BASELINE_MENTAL_STATUS",
        text = "Change in Baseline Mental Status"
    }
    documented_dx_vars.chronic_hepatic_failure_code = links.get_code_links {
        codes = { "K72.10", "K72.11" },
        text = "Chronic Hepatic Failure"
    }
    documented_dx_vars.coma_abs = links.get_abstraction_link { code = "COMA", text = "Coma" }
    documented_dx_vars.s07_codes = codes.get_code_prefix_link { prefix = "S07%.", text = "Crushing Head Injury" }
    documented_dx_vars.r410_code = links.get_code_link { code = "R41.0", text = "Disorientation" }
    documented_dx_vars.heavy_metal_poisioning_abs = links.get_abstraction_link {
        code = "HEAVY_METAL_POISIONING",
        text = "Heavy Metal Poisioning"
    }
    documented_dx_vars.hepatic_failure_code = links.get_code_links {
        codes = { "K72.90", "K72.91" },
        text = "Hepatic Failure"
    }
    documented_dx_vars.i160_code = codes.get_code_prefix_link { prefix = "I16%.0", text = "Hypertensive Crisis Code" }
    documented_dx_vars.infection_abs = links.get_abstraction_link { code = "INFECTION", text = "Infection" }
    documented_dx_vars.influenza_a_abs = links.get_abstraction_link { code = "INFLUENZA_A", text = "Influenza A" }
    documented_dx_vars.s06_codes = codes.get_code_prefix_link { prefix = "S06%.", text = "Intracranial Injury" }
    documented_dx_vars.g0481_code = links.get_code_link { code = "G04.81", text = "Liver" }
    documented_dx_vars.k7460_code = links.get_code_link { code = "K74.60", text = "Liver Cirrhosis" }
    documented_dx_vars.e8841_code = links.get_code_link { code = "E88.41", text = "MELAS Syndrome" }
    documented_dx_vars.e8840_code = links.get_code_link { code = "E88.40", text = "Mitochondrial Metabolism Disorder" }
    documented_dx_vars.e035_code = links.get_code_link { code = "E03.5", text = "Myxedema Coma" }
    documented_dx_vars.obtunded_abs = links.get_abstraction_link { code = "OBTUNDED", text = "Obtunded" }
    documented_dx_vars.opiodid_overdose_abs = links.get_abstraction_link {
        code = "OPIOID_OVERDOSE",
        text = "Opioid Overdose"
    }
    documented_dx_vars.opioid_withdrawal_abs = links.get_abstraction_link {
        code = "OPIOID_WITHDRAWAL",
        text = "Opioid Withdrawal"
    }

    documented_dx_vars.t36_codes = codes.get_code_prefix_link { prefix = "T36%.", text = "Poisoning" }
    documented_dx_vars.t37_codes = codes.get_code_prefix_link { prefix = "T37%.", text = "Poisoning" }
    documented_dx_vars.t38_codes = codes.get_code_prefix_link { prefix = "T38%.", text = "Poisoning" }
    documented_dx_vars.t39_codes = codes.get_code_prefix_link { prefix = "T39%.", text = "Poisoning" }
    documented_dx_vars.t40_codes = codes.get_code_prefix_link { prefix = "T40%.", text = "Poisoning" }
    documented_dx_vars.t41_codes = codes.get_code_prefix_link { prefix = "T41%.", text = "Poisoning" }
    documented_dx_vars.t42_codes = codes.get_code_prefix_link { prefix = "T42%.", text = "Poisoning" }
    documented_dx_vars.t43_codes = codes.get_code_prefix_link { prefix = "T43%.", text = "Poisoning" }
    documented_dx_vars.t44_codes = codes.get_code_prefix_link { prefix = "T44%.", text = "Poisoning" }
    documented_dx_vars.t45_codes = codes.get_code_prefix_link { prefix = "T45%.", text = "Poisoning" }
    documented_dx_vars.t46_codes = codes.get_code_prefix_link { prefix = "T46%.", text = "Poisoning" }
    documented_dx_vars.t47_codes = codes.get_code_prefix_link { prefix = "T47%.", text = "Poisoning" }
    documented_dx_vars.t48_codes = codes.get_code_prefix_link { prefix = "T48%.", text = "Poisoning" }
    documented_dx_vars.t49_codes = codes.get_code_prefix_link { prefix = "T49%.", text = "Poisoning" }
    documented_dx_vars.t50_codes = codes.get_code_prefix_link { prefix = "T50%.", text = "Poisoning" }
    documented_dx_vars.f29_code = links.get_code_link { code = "F29", text = "Postconcussional Syndrome" }

    documented_dx_vars.psychosis_abs = links.get_abstraction_link { code = "PSYCHOSIS", text = "Psychosis" }
    documented_dx_vars.sepsis_code = links.get_code_links {
        codes = {
            "A41.2", "A41.3", "A41.4", "A41.50", "A41.51", "A41.52", "A41.53", "A41.54", "A41.59",
            "A41.81", "A41.89", "A41.9", "A42.7", "A22.7", "B37.7", "A26.7", "A54.86", "B00.7", "A32.7", "A24.1",
            "A20.7", "T81.44XA", "T81.44XD"
        },
        text = "Sepsis"
    }
    documented_dx_vars.severe_malnutrition = links.get_code_links {
        codes = { "E40", "E41", "E42", "E43" },
        text = "Severe Malnutrition"
    }
    documented_dx_vars.stimulant_intoxication = links.get_code_links {
        codes = { "F15.120", "F15.121", "F15.129" },
        text = "Stimulant Intoxication"
    }
    documented_dx_vars.f1510_code = links.get_code_link { code = "F15.10", text = "Stimulant Abuse" }
    documented_dx_vars.r401_code = links.get_code_link { code = "R40.1", text = "Stupor" }
    documented_dx_vars.t51_codes = codes.get_code_prefix_link { prefix = "T51%.", text = "Toxic Effects of Alcohol" }
    documented_dx_vars.t58_codes = codes.get_code_prefix_link { prefix = "T58%.", text = "Toxic Effects of Carbon Monoxide" }
    documented_dx_vars.t57_codes = codes.get_code_prefix_link { prefix = "T57%.", text = "Toxic Effects of Inorganic Substance" }
    documented_dx_vars.t56_codes = codes.get_code_prefix_link { prefix = "T56%.", text = "Toxic Effects of Metals" }
    documented_dx_vars.k712_code = links.get_code_link { code = "K71.2", text = "Toxic Liver Disease with Acute Hepatitis" }
    documented_dx_vars.toxic_liver_disease_code = links.get_code_links {
        codes = { "K71.10", "K71.11" },
        text = "Toxic Liver Disease with Hepatic Necrosis"
    }
    documented_dx_vars.type_i_diabetic_keto = links.get_code_links {
        codes = { "E10.10", "E10.11" },
        text = "Type I Diabetic Ketoacidosis"
    }
    documented_dx_vars.type_ii_diabetic_keto = links.get_code_links {
        codes = { "E11.10", "E11.11" },
        text = "Type II Diabetic Ketoacidosis"
    }
    documented_dx_vars.e1100_code = links.get_code_link {
        code = "E11.00",
        text = "Type II Diabetes with Hyperosmolarity without NKHHC"
    }
    documented_dx_vars.e1101_code = links.get_code_link {
        code = "E11.01",
        text = "Type II Diabetes with Hyperosmolarity with Coma"
    }

    -- Labs
    local lab_vars = {}
    lab_vars.cblood_discrete_value_names = links.get_discrete_value_link {
        discreteValueNames = dv_c_blood,
        text = "Blood Culture Result",
        predicate = function(dv, num_)
            return string.find(dv.result, "positive") ~= nil or string.find(dv.result, "detected") ~= nil
        end
    }
    lab_vars.ethanol_discrete_value_names = links.get_discrete_value_link {
        discreteValueNames = dv_ethanol_level,
        text = "Ethanol Level",
        predicate = calc_ethanol_level1
    }
    lab_vars.e162_code = links.get_code_link { code = "E16.2", text = "Hypoglycemia" }
    lab_vars.r0902_code = links.get_code_link { code = "R09.02", text = "Hypoxemia" }
    lab_vars.positive_cerebrospinal_fluid_culture_abs = links.get_abstraction_link {
        code = "POSITIVE_CEREBROSPINAL_FLUID_CULTURE",
        text = "Positive Cerebrospinal Fluid Culture"
    }
    lab_vars.uremia_abs = links.get_abstraction_link { code = "UREMIA", text = "Uremia" }
    lab_vars.ua_bacteria_discrete_value_names = links.get_discrete_value_link {
        discreteValueNames = dv_ua_bacteria,
        text = "UA Bacteria",
        predicate = function(dv, num_)
            return string.find(dv.result, "positive") ~= nil or string.find(dv.result, "present") ~= nil
        end
    }
    lab_vars.urine_discrete_value_names = links.get_discrete_value_link {
        discreteValueNames = dv_c_urine,
        text = "Urine Culture Result",
        predicate = function(dv, num_)
            return string.find(dv.result, "positive") ~= nil or string.find(dv.result, "detected") ~= nil
        end
    }

    -- Lab Sub Categories
    local lab_sub_vars = {}
    lab_sub_vars.high_blood_glucose_dvs = links.get_discrete_value_links {
        discreteValueNames = dv_blood_glucose,
        text = "Blood Glucose",
        predicate = calc_blood_glucose1
    }
    lab_sub_vars.high_blood_glucose_poc_dvs = links.get_discrete_value_links {
        discreteValueNames = dv_blood_glucose_poc,
        text = "Blood Glucose",
        predicate = calc_blood_glucose_poc1
    }
    lab_sub_vars.low_blood_glucose_dvs = links.get_discrete_value_links {
        discreteValueNames = dv_blood_glucose,
        text = "Blood Glucose",
        predicate = calc_blood_glucose2
    }
    lab_sub_vars.low_blood_glucose_poc_dvs = links.get_discrete_value_links {
        discreteValueNames = dv_blood_glucose_poc,
        text = "Blood Glucose",
        predicate = calc_blood_glucose_poc2
    }
    lab_sub_vars.serum_ammonia_dvs = links.get_discrete_value_links {
        discreteValueNames = dv_serum_ammonia,
        text = "Serum Ammonia",
        predicate = calc_serum_ammonia1
    }
    lab_sub_vars.high_serum_blood_urea_nitrogen_dvs = links.get_discrete_value_links {
        discreteValueNames = dv_serum_blood_urea_nitrogen,
        text = "Serum Blood Urea Nitrogen",
        predicate = calc_serum_blood_urea_nitrogen1
    }
    lab_sub_vars.serum_calcium1_dvs = links.get_discrete_value_links {
        discreteValueNames = dv_serum_calcium,
        text = "Serum Calcium",
        predicate = calc_serum_calcium1
    }
    lab_sub_vars.serum_calcium2_dvs = links.get_discrete_value_links {
        discreteValueNames = dv_serum_calcium,
        text = "Serum Calcium",
        predicate = calc_serum_calcium2
    }
    lab_sub_vars.serum_creatinine1_dvs = links.get_discrete_value_links {
        discreteValueNames = dv_serum_creatinine,
        text = "Serum Creatinine",
        predicate = calc_serum_creatinine1
    }
    lab_sub_vars.serum_sodium1_dvs = links.get_discrete_value_links {
        discreteValueNames = dv_serum_sodium,
        text = "Serum Sodium",
        predicate = calc_serum_sodium1
    }
    lab_sub_vars.serum_sodium2_dvs = links.get_discrete_value_links {
        discreteValueNames = dv_serum_sodium,
        text = "Serum Sodium",
        predicate = calc_serum_sodium2
    }

    -- ABG Sub Categories
    local abg_vars = {}
    abg_vars.pao2_dvs = links.get_discrete_value_links {
        discreteValueNames = dv_pa_o2,
        text = "p02",
        predicate = calc_pa_o21
    }
    abg_vars.low_arterial_blood_ph_dvs = links.get_discrete_value_links {
        discreteValueNames = dv_arterial_blood_ph,
        text = "PH",
        predicate = calc_arterial_blood_ph1
    }
    abg_vars.pco2_dvs = links.get_discrete_value_links {
        discreteValueNames = dv_p_co2,
        text = "paC02",
        predicate = calc_p_co21
    }

    -- Medications
    local medication_vars = {}
    medication_vars.antibiotic_med = links.get_medication_link { cat = "Antibiotic", text = "Antibiotic" }
    medication_vars.antibiotic_abs = links.get_abstraction_link { code = "ANTIBIOTIC", text = "Antibiotic" }
    medication_vars.antibiotic2_med = links.get_medication_link { cat = "Antibiotic2", text = "Antibiotic" }
    medication_vars.antibiotic2_abs = links.get_abstraction_link { code = "ANTIBIOTIC_2", text = "Antibiotic" }
    medication_vars.anticonvulsant_med = links.get_medication_link { cat = "Anticonvulsant", text = "Anticonvulsant" }
    medication_vars.anticonvulsant_abs = links.get_abstraction_link { code = "ANTICONVULSANT", text = "Anticonvulsant" }
    medication_vars.antifungal_med = links.get_medication_link { cat = "Antifungal", text = "Antifungal" }
    medication_vars.antifungal_abs = links.get_abstraction_link { code = "ANTIFUNGAL", text = "Antifungal" }
    medication_vars.antiviral_med = links.get_medication_link { cat = "Antiviral", text = "Antiviral" }
    medication_vars.antiviral_abs = links.get_abstraction_link { code = "ANTIVIRAL", text = "Antiviral" }
    medication_vars.dextrose_med = links.get_medication_link { cat = "Dextrose 50%", text = "Dextrose 50%" }
    medication_vars.encephalopathy_medication_abs = links.get_abstraction_link {
        code = "ENCEPHALOPATHY_MEDICATION",
        text = "Encephalopathy Medication"
    }

    -- Vitals
    local vital_vars = {}
    vital_vars.diastolic_hypertensive_crisis_discrete_value_names = links.get_discrete_value_link {
        discreteValueNames = dv_dbp,
        text = "Diastolic Blood Pressure",
        predicate = calc_dbp1
    }
    vital_vars.systolic_hypertensive_crisis_discrete_value_names = links.get_discrete_value_link {
        discreteValueNames = dv_sbp,
        text = "Systolic Blood Pressure",
        predicate = calc_sbp1
    }
    vital_vars.low_pulse_oximetry_discrete_value_names = links.get_discrete_value_link {
        discreteValueNames = dv_sp_o2,
        text = "Sp02",
        predicate = calc_sp_o21
    }
    vital_vars.high_temp_discrete_value_names = links.get_discrete_value_link {
        discreteValueNames = dv_temperature,
        text = "Temperature",
        predicate = calc_temperature1
    }
    vital_vars.temp2_discrete_value_names = links.get_discrete_value_link {
        discreteValueNames = dv_temperature,
        text = "Temperature",
        predicate = calc_temperature2
    }

    -- Drugs
    local drug_vars = {}
    drug_vars.amphetamine_drug = links.get_discrete_value_link {
        discreteValueNames = dv_amphetamine_screen,
        text = "Amphetamine Screen Urine",
        predicate = function(dv, num_)
            return string.find(dv.result, "positive") ~= nil or string.find(dv.result, "detected") ~= nil
        end
    }
    drug_vars.barbiturate_drug = links.get_discrete_value_link {
        discreteValueNames = dv_barbiturate_screen,
        text = "Barbiturate Screen Urine",
        predicate = function(dv, num_)
            return string.find(dv.result, "positive") ~= nil or string.find(dv.result, "detected") ~= nil
        end
    }
    drug_vars.benzodiazepine_drug = links.get_discrete_value_link {
        discreteValueNames = dv_benzodiazepine_screen,
        text = "Benzodiazepine Screen Urine",
        predicate = function(dv, num_)
            return string.find(dv.result, "positive") ~= nil or string.find(dv.result, "detected") ~= nil
        end
    }
    drug_vars.buprenorphine_drug = links.get_discrete_value_link {
        discreteValueNames = dv_buprenorphine_screen,
        text = "Buprenorphine Screen Urine",
        predicate = function(dv, num_)
            return string.find(dv.result, "positive") ~= nil or string.find(dv.result, "detected") ~= nil
        end
    }
    drug_vars.cannabinoid_drug = links.get_discrete_value_link {
        discreteValueNames = dv_cannabinoid_screen,
        text = "Cannabinoid Screen Urine",
        predicate = function(dv, num_)
            return string.find(dv.result, "positive") ~= nil or string.find(dv.result, "detected") ~= nil
        end
    }
    drug_vars.cocaine_drug = links.get_discrete_value_link {
        discreteValueNames = dv_cocaine_screen,
        text = "Cocaine Screen Urine",
        predicate = function(dv, num_)
            return string.find(dv.result, "positive") ~= nil or string.find(dv.result, "detected") ~= nil
        end
    }
    drug_vars.methadone_drug = links.get_discrete_value_link {
        discreteValueNames = dv_methadone_screen,
        text = "Methadone Screen Urine",
        predicate = function(dv, num_)
            return string.find(dv.result, "positive") ~= nil or string.find(dv.result, "detected") ~= nil
        end
    }
    drug_vars.opiate_drug = links.get_discrete_value_link {
        discreteValueNames = dv_opiate_screen,
        text = "Opiate Screen Urine",
        predicate = function(dv, num_)
            return string.find(dv.result, "positive") ~= nil or string.find(dv.result, "detected") ~= nil
        end
    }
    drug_vars.oxycodone_drug = links.get_discrete_value_link {
        discreteValueNames = dv_oxycodone_screen,
        text = "Oxycodone Screen Urine",
        predicate = function(dv, num_)
            return string.find(dv.result, "positive") ~= nil or string.find(dv.result, "detected") ~= nil
        end
    }

    -- Neurologic Change Indicators Count
    local nci = 0
    if documented_dx_vars.psychosis_abs then
        clinical_evidence_header:add_link(documented_dx_vars.psychosis_abs)
        nci = nci + 1
    end
    if documented_dx_vars.r410_code then
        clinical_evidence_header:add_link(documented_dx_vars.r410_code)
        nci = nci + 1
    end
    if documented_dx_vars.r4182_code then
        clinical_evidence_header:add_link(documented_dx_vars.r4182_code)
        nci = nci + 1
    end
    if documented_dx_vars.obtunded_abs then
        clinical_evidence_header:add_link(documented_dx_vars.obtunded_abs)
        nci = nci + 1
    end
    if documented_dx_vars.r401_code then
        clinical_evidence_header:add_link(documented_dx_vars.r401_code)
        nci = nci + 1
    end
    if documented_dx_vars.coma_abs then
        clinical_evidence_header:add_link(documented_dx_vars.coma_abs)
        nci = nci + 1
    end
    if documented_dx_vars.ch_baseline_mental_status_abs then
        clinical_evidence_header:add_link(documented_dx_vars.ch_baseline_mental_status_abs)
        nci = nci + 1
    end

    -- Abstracting glasgow based on NCI score
    local glasgow_coma_score_links =
        glasgow_linked_values(
            (
                negation_vars.dementia1 or
                negation_vars.dementia2 or
                negation_vars.dementia3 or
                negation_vars.alzheimers_neg and
                negation_vars.ch_baseline_mental_status_abs == nil
            ) and num_glasgow_coma_scale2 or num_glasgow_coma_scale1,
            nci == 0
        )

    -- Clinical Indicators Count
    local ci = 0
    if lab_sub_vars.serum_ammonia_dvs then
        ci = ci + 1
    end
    if vital_vars.high_temp_discrete_value_names or vital_vars.temp2_discrete_value_names then
        vital_signs_intake_header:add_link(vital_vars.high_temp_discrete_value_names)
        ci = ci + 1
    end
    if abg_vars.low_arterial_blood_ph_dvs then
        ci = ci + 1
    end
    if lab_vars.positive_cerebrospinal_fluid_culture_abs then
        laboratory_studies_header:add_link(lab_vars.positive_cerebrospinal_fluid_culture_abs)
        ci = ci + 1
    end
    if lab_sub_vars.serum_sodium1_dvs or lab_sub_vars.serum_sodium2_dvs then
        ci = ci + 1
    end
    if lab_vars.uremia_abs then
        laboratory_studies_header:add_link(lab_vars.uremia_abs)
        ci = ci + 1
    end
    if vital_vars.diastolic_hypertensive_crisis_discrete_value_names or vital_vars.systolic_hypertensive_crisis_discrete_value_names then
        vital_signs_intake_header:add_link(vital_vars.diastolic_hypertensive_crisis_discrete_value_names)
        vital_signs_intake_header:add_link(vital_vars.systolic_hypertensive_crisis_discrete_value_names)
        ci = ci + 1
    end
    if lab_sub_vars.serum_calcium1_dvs or lab_sub_vars.serum_calcium2_dvs then
        ci = ci + 1
    end
    if documented_dx_vars.cerebral_edema_abs then
        clinical_evidence_header:add_link(documented_dx_vars.cerebral_edema_abs)
        ci = ci + 1
    end
    if documented_dx_vars.cerebral_ischemia_abs then
        clinical_evidence_header:add_link(documented_dx_vars.cerebral_ischemia_abs)
        ci = ci + 1
    end
    if abg_vars.pao2_dvs or lab_vars.r0902_code then
        vital_signs_intake_header:add_link(lab_vars.r0902_code)
        ci = ci + 1
    end
    if vital_vars.low_pulse_oximetry_discrete_value_names then
        vital_signs_intake_header:add_link(vital_vars.low_pulse_oximetry_discrete_value_names)
        ci = ci + 1
    end
    if lab_sub_vars.high_blood_glucose_dvs or lab_sub_vars.high_blood_glucose_poc_dvs or lab_vars.e162_code or lab_sub_vars.low_blood_glucose_dvs or lab_sub_vars.low_blood_glucose_poc_dvs then
        laboratory_studies_header:add_link(lab_vars.e162_code)
        ci = ci + 1
    end
    if documented_dx_vars.opioid_withdrawal_abs then
        clinical_evidence_header:add_link(documented_dx_vars.opioid_withdrawal_abs)
        ci = ci + 1
    end
    if documented_dx_vars.sepsis_code then
        clinical_evidence_header:add_link(documented_dx_vars.sepsis_code)
        ci = ci + 1
    end
    if documented_dx_vars.alcohol_withdrawal_abs then
        clinical_evidence_header:add_link(documented_dx_vars.alcohol_withdrawal_abs)
        ci = ci + 1
    end
    if
        documented_dx_vars.acute_subacute_hepatic_fail_code or
        documented_dx_vars.alcohol_heptac_fail_code or
        documented_dx_vars.chronic_hepatic_failure_code or
        documented_dx_vars.hepatic_failure_code or
        documented_dx_vars.k712_code or
        documented_dx_vars.toxic_liver_disease_code
    then

        clinical_evidence_header:add_link(documented_dx_vars.acute_subacute_hepatic_fail_code)
        clinical_evidence_header:add_link(documented_dx_vars.alcohol_heptac_fail_code)
        clinical_evidence_header:add_link(documented_dx_vars.chronic_hepatic_failure_code)
        clinical_evidence_header:add_link(documented_dx_vars.hepatic_failure_code)
        clinical_evidence_header:add_link(documented_dx_vars.k712_code)
        clinical_evidence_header:add_link(documented_dx_vars.toxic_liver_disease_code)
        ci = ci + 1
    end
    if lab_sub_vars.high_serum_blood_urea_nitrogen_dvs then
        ci = ci + 1
    end
    if documented_dx_vars.opiodid_overdose_abs then
        clinical_evidence_header:add_link(documented_dx_vars.opiodid_overdose_abs)
        ci = ci + 1
    end
    if documented_dx_vars.stimulant_intoxication then
        clinical_evidence_header:add_link(documented_dx_vars.stimulant_intoxication)
        ci = ci + 1
    end
    if documented_dx_vars.f1510_code then
        clinical_evidence_header:add_link(documented_dx_vars.f1510_code)
        ci = ci + 1
    end
    if documented_dx_vars.heavy_metal_poisioning_abs then
        clinical_evidence_header:add_link(documented_dx_vars.heavy_metal_poisioning_abs)
        ci = ci + 1
    end
    if documented_dx_vars.infection_abs then
        clinical_evidence_header:add_link(documented_dx_vars.infection_abs)
        ci = ci + 1
    end
    if documented_dx_vars.acute_kidney_failure_abs then
        clinical_evidence_header:add_link(documented_dx_vars.acute_kidney_failure_abs)
        ci = ci + 1
    end
    if medication_vars.encephalopathy_medication_abs then
        treatment_and_monitoring_header:add_link(medication_vars.encephalopathy_medication_abs)
        ci = ci + 1
    end
    if medication_vars.antiviral_med or medication_vars.antiviral_abs then
        treatment_and_monitoring_header:add_link(medication_vars.antiviral_med)
        treatment_and_monitoring_header:add_link(medication_vars.antiviral_abs)
        ci = ci + 1
    end
    if medication_vars.antifungal_med or medication_vars.antifungal_abs then
        treatment_and_monitoring_header:add_link(medication_vars.antifungal_med)
        treatment_and_monitoring_header:add_link(medication_vars.antifungal_abs)
        ci = ci + 1
    end
    if medication_vars.antibiotic_med or medication_vars.antibiotic_abs or medication_vars.antibiotic2_med or medication_vars.antibiotic2_abs then
        treatment_and_monitoring_header:add_link(medication_vars.antibiotic_med)
        treatment_and_monitoring_header:add_link(medication_vars.antibiotic_abs)
        treatment_and_monitoring_header:add_link(medication_vars.antibiotic2_med)
        treatment_and_monitoring_header:add_link(medication_vars.antibiotic2_abs)
        ci = ci + 1
    end
    if medication_vars.anticonvulsant_med or medication_vars.anticonvulsant_abs then
        treatment_and_monitoring_header:add_link(medication_vars.anticonvulsant_med)
        treatment_and_monitoring_header:add_link(medication_vars.anticonvulsant_abs)
        ci = ci + 1
    end
    if medication_vars.dextrose_med then
        treatment_and_monitoring_header:add_link(medication_vars.dextrose_med)
        ci = ci + 1
    end
    if documented_dx_vars.g0481_code then
        clinical_evidence_header:add_link(documented_dx_vars.g0481_code)
        ci = ci + 1
    end
    if documented_dx_vars.i160_code then
        clinical_evidence_header:add_link(documented_dx_vars.i160_code)
        ci = ci + 1
    end
    if documented_dx_vars.type_i_diabetic_keto then
        clinical_evidence_header:add_link(documented_dx_vars.type_i_diabetic_keto)
        ci = ci + 1
    end
    if documented_dx_vars.type_ii_diabetic_keto then
        clinical_evidence_header:add_link(documented_dx_vars.type_ii_diabetic_keto)
        ci = ci + 1
    end
    if documented_dx_vars.e1100_code then
        clinical_evidence_header:add_link(documented_dx_vars.e1100_code)
        ci = ci + 1
    end
    if documented_dx_vars.e1101_code then
        clinical_evidence_header:add_link(documented_dx_vars.e1101_code)
        ci = ci + 1
    end
    if documented_dx_vars.f101_codes then
        clinical_evidence_header:add_link(documented_dx_vars.f101_codes)
        ci = ci + 1
    end
    if documented_dx_vars.f102_codes then
        clinical_evidence_header:add_link(documented_dx_vars.f102_codes)
        ci = ci + 1
    end
    if documented_dx_vars.s07_codes then
        clinical_evidence_header:add_link(documented_dx_vars.s07_codes)
        ci = ci + 1
    end
    if documented_dx_vars.influenza_a_abs then
        clinical_evidence_header:add_link(documented_dx_vars.influenza_a_abs)
        ci = ci + 1
    end
    if documented_dx_vars.e8841_code then
        clinical_evidence_header:add_link(documented_dx_vars.e8841_code)
        ci = ci + 1
    end
    if documented_dx_vars.e8840_code then
        clinical_evidence_header:add_link(documented_dx_vars.e8840_code)
        ci = ci + 1
    end
    if documented_dx_vars.e035_code then
        clinical_evidence_header:add_link(documented_dx_vars.e035_code)
        ci = ci + 1
    end
    if documented_dx_vars.f29_code then
        clinical_evidence_header:add_link(documented_dx_vars.f29_code)
        ci = ci + 1
    end
    if documented_dx_vars.severe_malnutrition then
        clinical_evidence_header:add_link(documented_dx_vars.severe_malnutrition)
        ci = ci + 1
    end
    if documented_dx_vars.s06_codes then
        clinical_evidence_header:add_link(documented_dx_vars.s06_codes)
        ci = ci + 1
    end
    if lab_vars.cblood_dv then
        ci = ci + 1
    end
    if lab_vars.ua_bacteria_dv then
        ci = ci + 1
    end
    if lab_vars.urine_dv then
        ci = ci + 1
    end
    if lab_sub_vars.serum_creatinine1_dvs then
        ci = ci + 1
    end
    if abg_vars.pco2_dvs then
        ci = ci + 1
    end
    if
        documented_dx_vars.t36_codes or
        documented_dx_vars.t37_codes or
        documented_dx_vars.t38_codes or
        documented_dx_vars.t39_codes or
        documented_dx_vars.t40_codes or
        documented_dx_vars.t41_codes or
        documented_dx_vars.t42_codes or
        documented_dx_vars.t43_codes or
        documented_dx_vars.t44_codes or
        documented_dx_vars.t45_codes or
        documented_dx_vars.t46_codes or
        documented_dx_vars.t47_codes or
        documented_dx_vars.t48_codes or
        documented_dx_vars.t49_codes or
        documented_dx_vars.t50_codes
    then
        clinical_evidence_header:add_link(documented_dx_vars.t36_codes)
        clinical_evidence_header:add_link(documented_dx_vars.t37_codes)
        clinical_evidence_header:add_link(documented_dx_vars.t38_codes)
        clinical_evidence_header:add_link(documented_dx_vars.t39_codes)
        clinical_evidence_header:add_link(documented_dx_vars.t40_codes)
        clinical_evidence_header:add_link(documented_dx_vars.t41_codes)
        clinical_evidence_header:add_link(documented_dx_vars.t42_codes)
        clinical_evidence_header:add_link(documented_dx_vars.t43_codes)
        clinical_evidence_header:add_link(documented_dx_vars.t44_codes)
        clinical_evidence_header:add_link(documented_dx_vars.t45_codes)
        clinical_evidence_header:add_link(documented_dx_vars.t46_codes)
        clinical_evidence_header:add_link(documented_dx_vars.t47_codes)
        clinical_evidence_header:add_link(documented_dx_vars.t48_codes)
        clinical_evidence_header:add_link(documented_dx_vars.t49_codes)
        clinical_evidence_header:add_link(documented_dx_vars.t50_codes)
        ci = ci + 1
    end
    if documented_dx_vars.t51_codes then
        clinical_evidence_header:add_link(documented_dx_vars.t51_codes)
        ci = ci + 1
    end
    if documented_dx_vars.t58_codes then
        clinical_evidence_header:add_link(documented_dx_vars.t58_codes)
        ci = ci + 1
    end
    if documented_dx_vars.t57_codes then
        clinical_evidence_header:add_link(documented_dx_vars.t57_codes)
        ci = ci + 1
    end
    if documented_dx_vars.t56_codes then
        clinical_evidence_header:add_link(documented_dx_vars.t56_codes)
        ci = ci + 1
    end
    if drug_vars.amphetamine_drug then
        treatment_and_monitoring_header:add_link(drug_vars.amphetamine_drug)
        ci = ci + 1
    end
    if drug_vars.barbiturate_drug then
        treatment_and_monitoring_header:add_link(drug_vars.barbiturate_drug)
        ci = ci + 1
    end
    if drug_vars.benzodiazepine_drug then
        treatment_and_monitoring_header:add_link(drug_vars.benzodiazepine_drug)
        ci = ci + 1
    end
    if drug_vars.buprenorphine_drug then
        treatment_and_monitoring_header:add_link(drug_vars.buprenorphine_drug)
        ci = ci + 1
    end
    if drug_vars.cannabinoid_drug then
        treatment_and_monitoring_header:add_link(drug_vars.cannabinoid_drug)
        ci = ci + 1
    end
    if drug_vars.cocaine_drug then
        treatment_and_monitoring_header:add_link(drug_vars.cocaine_drug)
        ci = ci + 1
    end
    if drug_vars.methadone_drug then
        treatment_and_monitoring_header:add_link(drug_vars.methadone_drug)
        ci = ci + 1
    end
    if drug_vars.opiate_drug then
        treatment_and_monitoring_header:add_link(drug_vars.opiate_drug)
        ci = ci + 1
    end
    if drug_vars.oxycodone_drug then
        treatment_and_monitoring_header:add_link(drug_vars.oxycodone_drug)
        ci = ci + 1
    end
    if lab_vars.ethanol_dv then
        laboratory_studies_header:add_link(lab_vars.ethanol_dv)
        ci = ci + 1
    end
    if documented_dx_vars.i63_codes then
        clinical_evidence_header:add_link(documented_dx_vars.i63_codes)
        ci = ci + 1
    end



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if
        existing_alert and
        subtitle == "Encephalopathy Dx Documented Possibly Lacking Supporting Evidence" and
        #account_alert_codes == 1 and
        (nci > 0 or #glasgow_coma_score_links > 0)
    then
        if documented_dx_vars.r4182_code then
            documented_dx_vars.r4182_code.link_text = "Autoclosed Due To - " .. documented_dx_vars.r4182_code.link_text
            documented_dx_header:add_link(documented_dx_vars.r4182_code)
        end
        if #glasgow_coma_score_links > 0 then
            documented_dx_header:add_text_link("AutoClosed due to most recent Glasgow Coma Score")
            documented_dx_header:add_text_link("No Documented Signs of Alerted Mental Status")
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Glascow Coma Score or NCI Existing on the Account"
        Result.validated = true
        Result.passed = true

    elseif existing_alert and #account_alert_codes == 1 and documented_dx_vars.r4182_code == nil and #glasgow_coma_score_links == 0 and nci == 0 then
        for _, code in ipairs(account_alert_codes) do
            local desc = alert_code_dictionary[code]
            local temp_code = links.get_code_link { code = code, text = desc }
            if temp_code then
                documented_dx_header:add_link(temp_code)
                break
            end
        end
        if #glasgow_coma_score_links == 0 then
            documented_dx_header:add_text_link("No Documented Signs of Alerted Mental Status")
        end
        Result.subtitle = "Encephalopathy Dx Documented Possibly Lacking Supporting Evidence"
        Result.passed = true

    elseif
        subtitle == "Hepatic Encephalopathy Documented, but No Evidence of Liver Failure Found" and
        (
            documented_dx_vars.liver_neg1 or
            documented_dx_vars.liver_neg2 or
            documented_dx_vars.liver_neg3 or
            documented_dx_vars.liver_neg4 or
            documented_dx_vars.liver_neg5 or
            documented_dx_vars.liver_neg6 or
            documented_dx_vars.liver_neg7
        ) and
        documented_dx_vars.k7682_code
    then
        documented_dx_header:add_link(documented_dx_vars.liver_neg1)
        documented_dx_header:add_link(documented_dx_vars.liver_neg2)
        documented_dx_header:add_link(documented_dx_vars.liver_neg3)
        documented_dx_header:add_link(documented_dx_vars.liver_neg4)
        documented_dx_header:add_link(documented_dx_vars.liver_neg5)
        documented_dx_header:add_link(documented_dx_vars.liver_neg6)
        documented_dx_header:add_link(documented_dx_vars.liver_neg7)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Liver Disease/Failure DX Code Existing On Account."
        Result.validated = true
        Result.passed = true

    elseif
        existing_alert and
        documented_dx_vars.k7682_code and
        (
            not documented_dx_vars.liver_neg1 and
            not documented_dx_vars.liver_neg2 and
            not documented_dx_vars.liver_neg3 and
            not documented_dx_vars.liver_neg4 and
            not documented_dx_vars.liver_neg5 and
            not documented_dx_vars.liver_neg6 and
            not documented_dx_vars.liver_neg7
        )
    then
        documented_dx_header:add_link(documented_dx_vars.k7682_code)
        Result.subtitle = "Hepatic Encephalopathy Documented, but No Evidence of Liver Failure Found"
        Result.passed = true

    elseif #account_alert_codes > 1 and not (documented_dx_vars.g928_code and documented_dx_vars.g9341_code) or #account_alert_codes > 2 then
        for _, code in ipairs(account_alert_codes) do
            local desc = alert_code_dictionary[code]
            local temp_code = links.get_code_link { code = code, text = desc }
            if temp_code then
                documented_dx_header:add_link(temp_code)
            end
        end
        if existing_alert and existing_alert.validated then
            Result.validated = false
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
        end
        Result.subtitle = "Encephalopathy Conflicting Dx " .. table.concat(account_alert_codes, ", ")
        Result.passed = true

    elseif #account_alert_codes == 1 or documented_dx_vars.severe_alzheimers_abs or documented_dx_vars.severe_dementia_abs then
        if existing_alert then
            for _, code in ipairs(account_alert_codes) do
                local desc = alert_code_dictionary[code]
                local temp_code = links.get_code_link { code = code, text = "Autoresolved Specified Code - " .. desc }
                if temp_code then
                    documented_dx_header:add_link(temp_code)
                    break
                end
            end
            documented_dx_header:add_link(documented_dx_vars.severe_alzheimers_abs)
            documented_dx_header:add_link(documented_dx_vars.severe_dementia_abs)
            Result.outcome = "AUTORESOLVED"
            Result.reason = "Autoresolved due to one Specified Code on the Account"
            Result.validated = true
            Result.passed = true
        else
            Result.passed = false
        end

    elseif existing_alert and documented_dx_vars.g9340_code then
        documented_dx_header:add_link(documented_dx_vars.g9340_code)
        Result.subtitle = "Unspecified Encephalopathy Dx"
        Result.passed = true

    elseif existing_alert and #glasgow_coma_score_links > 2 or (#glasgow_coma_score_links == 1 and nci > 0) and ci > 0 then
        Result.subtitle = "Possible Encephalopathy Dx"
        Result.passed = true

    elseif
        #glasgow_coma_score_links > 0 or
        (nci >= 1 and not (documented_dx_vars.dementia1 or documented_dx_vars.dementia2 or documented_dx_vars.dementia3 or documented_dx_vars.alzheimers_neg)) or
        (documented_dx_vars.ch_baseline_mental_status_abs and (documented_dx_vars.dementia1 or documented_dx_vars.dementia2 or documented_dx_vars.dementia3 or documented_dx_vars.alzheimers_neg))
    then
        if documented_dx_vars.ch_baseline_mental_status_abs and (documented_dx_vars.dementia1 or documented_dx_vars.dementia2 or documented_dx_vars.dementia3 or documented_dx_vars.alzheimers_neg) then
            documented_dx_header:add_link(documented_dx_vars.ch_baseline_mental_status_abs)
            documented_dx_header:add_link(documented_dx_vars.dementia1)
            documented_dx_header:add_link(documented_dx_vars.dementia2)
            documented_dx_header:add_link(documented_dx_vars.dementia3)
            documented_dx_header:add_link(documented_dx_vars.alzheimers_neg)
        end
        Result.subtitle = "Altered Mental Status"
        Result.passed = true
    end


    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Clinical Indicators
            -- 1
            clinical_evidence_header:add_code_link("R94.01", "Abnormal Electroencephalogram (EEG)")
            clinical_evidence_header:add_abstraction_link("ACE_CONSULT", "ACE Consult")
            -- 4-5
            clinical_evidence_header:add_abstraction_link("AGITATION", "Agitation")
            -- 7-12
            local altered_abs = clinical_evidence_header:add_abstraction_link("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level Of Consciousness")
            if documented_dx_vars.r4182_code then
                if altered_abs then
                    altered_abs.hidden = true
                    clinical_evidence_header:add_link(altered_abs)
                end
            elseif altered_abs then
                clinical_evidence_header:add_link(altered_abs)
            end
            clinical_evidence_header:add_code_link("R47.01", "Aphasia")
            clinical_evidence_header:add_code_link("R18.8", "Ascities")
            clinical_evidence_header:add_abstraction_link("ATAXIA", "Ataxia")
            -- 17-22
            clinical_evidence_header:add_abstraction_link("COMBATIVE", "Combativeness")
            -- 24-25
            clinical_evidence_header:add_code_link("E86.0", "Dehydration")
            clinical_evidence_header:add_code_link("F07.81", "Fatigue")
            clinical_evidence_header:add_code_link("R44.3", "Hallucinations")
            -- 29-30
            clinical_evidence_header:add_code_link("E87.0", "Hypernatremia")
            -- 32-35
            clinical_evidence_header:add_code_link("R17", "Jaundice")
            clinical_evidence_header:add_code_link("R53.83", "Lethargy")
            -- 38-43
            clinical_evidence_header:add_abstraction_link("ONE_TO_ONE_SUPERVISION", "One to one supervision")
            -- 45-61
            clinical_evidence_header:add_abstraction_link("POSSIBLE_ENCEPHALOPATHY", "Possible Encephalopathy")
            -- 63-64
            clinical_evidence_header:add_abstraction_link("RESTLESSNESS", "Restlessness")
            clinical_evidence_header:add_code_link("R10.811", "Right Upper Quadrant Tenderness")
            clinical_evidence_header:add_abstraction_link("SEIZURE", "Seizure")
            -- 68-69
            clinical_evidence_header:add_code_link("R47.81", "Slurred Speech")
            clinical_evidence_header:add_code_link("R40.0", "Somnolence")
            -- 72-74
            clinical_evidence_header:add_abstraction_link("SUNDOWNING", "Sundowning")
            -- 76-85
            clinical_evidence_header:add_code_link("S09.90", "Unspecified Injury of Head")

            -- Document Links
            ct_head_brain_header:add_document_link("CT Head WO", "CT Head WO")
            ct_head_brain_header:add_document_link("CT Head Stroke Alert", "CT Head Stroke Alert")
            ct_head_brain_header:add_document_link("CTA Head-Neck", "CTA Head-Neck")
            ct_head_brain_header:add_document_link("CTA Head", "CTA Head")
            ct_head_brain_header:add_document_link("CT Head  WWO", "CT Head  WWO")
            ct_head_brain_header:add_document_link("CT Head  W", "CT Head  W")
            mri_brain_header:add_document_link("MRI Brain WWO", "MRI Brain WWO")
            mri_brain_header:add_document_link("MRI Brain  W and W/O Contrast", "MRI Brain  W and W/O Contrast")
            mri_brain_header:add_document_link("WO", "WO")
            mri_brain_header:add_document_link("MRI Brain W/O Contrast", "MRI Brain W/O Contrast")
            mri_brain_header:add_document_link("MRI Brain W/O Con", "MRI Brain W/O Con")
            mri_brain_header:add_document_link("MRI Brain  W and W/O Con", "MRI Brain  W and W/O Con")
            mri_brain_header:add_document_link("MRI Brain  W", "MRI Brain  W")
            mri_brain_header:add_document_link("MRI Brain  W/ Contrast", "MRI Brain  W/ Contrast")
            eeg_header:add_document_link("EEG Report", "EEG Report")
            eeg_header:add_document_link("EEG", "EEG")

            -- Labs
            laboratory_studies_header:add_discrete_value_one_of_link(dv_alkaline_phos, "Alkaline Phos", calc_alkaline_phos1)
            laboratory_studies_header:add_discrete_value_one_of_link(dv_bilirubin_total, "Bilirubin Total", calc_bilirubin_total1)
            laboratory_studies_header:add_link(lab_vars.cblood_dv)

            -- Meds
            treatment_and_monitoring_header:add_medication_link("Anti-Hypoglycemic Agent", "Anti-Hypoglycemic Agent")
            -- 2-11
            treatment_and_monitoring_header:add_medication_link("Benzodiazepine", "Benzodiazepine")
            treatment_and_monitoring_header:add_abstraction_link("BENZODIAZEPINE", "Benzodiazepine")
            -- 14-15
            treatment_and_monitoring_header:add_medication_link("Haloperidol", "Haloperidol")
            treatment_and_monitoring_header:add_abstraction_link("HALOPERIDOL", "Haloperidol")
            treatment_and_monitoring_header:add_medication_link("Lactulose", "Lactulose")
            treatment_and_monitoring_header:add_abstraction_link("LACTULOSE", "Lactulose")

            -- Vitals
            vital_signs_intake_header:add_code_one_of_link({ "F10.220", "F10.221", "F10.229" }, "Acute Alcohol Intoxication")
            -- 2-5
            vital_signs_intake_header:add_link(vital_vars.temp2_discrete_value_names)

            -- Glasgow
            if #glasgow_coma_score_links > 0 then
                for _, entry in ipairs(glasgow_coma_score_links) do
                    glasgow_header:add_link(entry)
                end
            else
                glasgow_header:add_abstraction_link("LOW_GLASGOW_COMA_SCORE", "Glasgow Coma Score")
            end
            if lab_sub_vars.high_blood_glucose_dvs then
                for _, entry in ipairs(lab_sub_vars.high_blood_glucose_dvs) do
                    glucose_header:add_link(entry)
                end
            end
            if lab_sub_vars.high_blood_glucose_poc_dvs then
                for _, entry in ipairs(lab_sub_vars.high_blood_glucose_poc_dvs) do
                    glucose_header:add_link(entry)
                end
            end
            if lab_sub_vars.low_blood_glucose_dvs then
                for _, entry in ipairs(lab_sub_vars.low_blood_glucose_dvs) do
                    glucose_header:add_link(entry)
                end
            end
            if lab_sub_vars.low_blood_glucose_poc_dvs then
                for _, entry in ipairs(lab_sub_vars.low_blood_glucose_poc_dvs) do
                    glucose_header:add_link(entry)
                end
            end
            if lab_sub_vars.serum_ammonia_dvs then
                for _, entry in ipairs(lab_sub_vars.serum_ammonia_dvs) do
                    ammonia_header:add_link(entry)
                end
            end
            if lab_sub_vars.high_serum_blood_urea_nitrogen_dvs then
                for _, entry in ipairs(lab_sub_vars.high_serum_blood_urea_nitrogen_dvs) do
                    bun_header:add_link(entry)
                end
            end
            if lab_sub_vars.serum_calcium1_dvs then
                for _, entry in ipairs(lab_sub_vars.serum_calcium1_dvs) do
                    calcium_header:add_link(entry)
                end
            end
            if lab_sub_vars.serum_calcium2_dvs then
                for _, entry in ipairs(lab_sub_vars.serum_calcium2_dvs) do
                    calcium_header:add_link(entry)
                end
            end
            if lab_sub_vars.serum_creatinine1_dvs then
                for _, entry in ipairs(lab_sub_vars.serum_creatinine1_dvs) do
                    creatinine_header:add_link(entry)
                end
            end
            if lab_sub_vars.serum_sodium1_dvs then
                for _, entry in ipairs(lab_sub_vars.serum_sodium1_dvs) do
                    sodium_header:add_link(entry)
                end
            end
            if lab_sub_vars.serum_sodium2_dvs then
                for _, entry in ipairs(lab_sub_vars.serum_sodium2_dvs) do
                    sodium_header:add_link(entry)
                end
            end
            if lab_sub_vars.low_arterial_blood_ph_dvs then
                for _, entry in ipairs(lab_sub_vars.low_arterial_blood_ph_dvs) do
                    ph_header:add_link(entry)
                end
            end
            if lab_sub_vars.pao2_dvs then
                for _, entry in ipairs(lab_sub_vars.pao2_dvs) do
                    pao2_header:add_link(entry)
                end
            end
            if lab_sub_vars.pco2_dvs then
                for _, entry in ipairs(lab_sub_vars.pco2_dvs) do
                    pco2_header:add_link(entry)
                end
            end
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

