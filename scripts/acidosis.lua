-----------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Acidosis
---
--- This script checks an account to see if it matches the criteria for an acidosis alert.
---
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
-----------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Requires 
--------------------------------------------------------------------------------
local alerts = require("libs.common.alerts")
local links = require("libs.common.basic_links")
local codes = require("libs.common.codes")
local dates = require("libs.common.dates")
local discrete = require("libs.common.discrete_values")



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local anion_gap_dv_name = { "" }
local anion_gap1_predicate = function(dv) return discrete.get_dv_value_number(dv) > 14 end
local arterial_blood_ph_dv_name = { "pH" }
local arterial_blood_ph2_predicate = function(dv) return discrete.get_dv_value_number(dv) < 7.32 end
local base_excess_dv_name = { "BASE EXCESS (mmol/L)" }
local base_excess1_predicate = function(dv) return discrete.get_dv_value_number(dv) < -2 end
local blood_co2_dv_name = { "CO2 (mmol/L)" }
local blood_co21_predicate = function(dv) return discrete.get_dv_value_number(dv) < 21 end
local blood_co22_predicate = function(dv) return discrete.get_dv_value_number(dv) > 32 end
local blood_glucose_dv_name = { "GLUCOSE (mg/dL)", "GLUCOSE" }
local blood_glucose1_predicate = function(dv) return discrete.get_dv_value_number(dv) > 250 end
local blood_glucose_poc_dv_name = { "GLUCOSE ACCUCHECK (mg/dL)" }
local blood_glucose_poc1_predicate = function(dv) return discrete.get_dv_value_number(dv) > 250 end
local fio2_dv_name = { "FIO2" }
local fio21_predicate = function(dv) return discrete.get_dv_value_number(dv) <= 100 end
local glasgow_coma_scale_dv_name = { "3.5 Neuro Glasgow Score" }
local glasgow_coma_scale1_predicate = function(dv) return discrete.get_dv_value_number(dv) < 15 end
local hco3_dv_name = { "HCO3 VENOUS (meq/L)" }
local hco31_predicate = function(dv) return discrete.get_dv_value_number(dv) < 22 end
local hco32_predicate = function(dv) return discrete.get_dv_value_number(dv) > 26 end
local heart_rate_dv_name = {
    "Heart Rate cc (bpm)",
    "3.5 Heart Rate (Apical) (bpm)",
    "3.5 Heart Rate (Other) (bpm)",
    "3.5 Heart Rate (Radial) (bpm)",
    "SCC Monitor Pulse (bpm)"
}
local heart_rate1_predicate = function(dv) return discrete.get_dv_value_number(dv) > 90 end
local map_dv_name = { "Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)" }
local map1_predicate = function(dv) return discrete.get_dv_value_number(dv) < 70 end
local pao2_dv_name = { "BLD GAS O2 (mmHg)" }
local pao21_predicate = function(dv) return discrete.get_dv_value_number(dv) < 60 end
local po2_dv_name = { "BLD GAS O2 (mmHg)", "PO2 (mmHg)" }
local po21_predicate = function(dv) return discrete.get_dv_value_number(dv) < 80 end
local pco2_dv_name = { "BLD GAS CO2 (mmHg)", "PaCO2 (mmHg)" }
local pco21_predicate = function(dv) return discrete.get_dv_value_number(dv) > 50 end
local pco22_predicate = function(dv) return discrete.get_dv_value_number(dv) < 30 end
local ph_dv_name = { "pH (VENOUS)", "pH VENOUS" }
local ph2_predicate = function(dv) return discrete.get_dv_value_number(dv) < 7.30 end
local respiratory_rate_dv_name = { "3.5 Respiratory Rate (#VS I&O) (per Minute)" }
local respiratory_rate1_predicate = function(dv) return discrete.get_dv_value_number(dv) > 20 end
local respiratory_rate2_predicate = function(dv) return discrete.get_dv_value_number(dv) < 12 end
local sbp_dv_name = { "SBP 3.5 (No Calculation) (mm Hg)" }
local sbp1_predicate = function(dv) return discrete.get_dv_value_number(dv) < 90 end
local serum_blood_urea_nitrogen_dv_name = { "BUN (mg/dL)" }
local serum_blood_urea_nitrogen1_predicate = function(dv) return discrete.get_dv_value_number(dv) > 23 end
local serum_bicarbonate_dv_name = { "HCO3 (meq/L)", "HCO3 (mmol/L)" }
local serum_bicarbonate1_predicate = function(dv) return discrete.get_dv_value_number(dv) > 26 end
local serum_bicarbonate3_predicate = function(dv) return discrete.get_dv_value_number(dv) < 22 end
local serum_chloride_dv_name = { "CHLORIDE (mmol/L)" }
local serum_chloride1_predicate = function(dv) return discrete.get_dv_value_number(dv) > 107 end
local serum_creatinine_dv_name = { "CREATININE (mg/dL)", "CREATININE SERUM (mg/dL)" }
local serum_creatinine1_predicate = function(dv) return discrete.get_dv_value_number(dv) > 1.3 end
local serum_lactate_dv_name = { "LACTIC ACID (mmol/L)", "LACTATE (mmol/L)" }
local serum_lactate1_predicate = function(dv) return discrete.get_dv_value_number(dv) >= 4 end
local serum_lactate2_predicate = function(dv)
    return discrete.get_dv_value_number(dv) > 2 and discrete.get_dv_value_number(dv) < 4
end
local spo2_dv_name = { "Pulse Oximetry(Num) (%)" }
local spo21_predicate = function(dv) return discrete.get_dv_value_number(dv) < 90 end
local venous_blood_co2_dv_name = { "BLD GAS CO2 VEN (mmHg)" }
local venous_blood_co2_predicate = function(dv) return discrete.get_dv_value_number(dv) > 55 end
local serum_ketone_dv_name = { "KETONES (mg/dL)" }
local serum_ketone1_predicate = function(dv) return discrete.get_dv_value_number(dv) > 0 end
local urine_ketones_dv_name = { "UR KETONES (mg/dL)", "KETONES (mg/dL)" }

local possible_acute_respiratory_acidosis_subtitle = "Possible Acute Respiratory Acidosis"
local respiratory_acidosis_lacking_evidence_subtitle = (
    "Acute Respiratory Acidosis Documented Possibly Lacking Supporting Evidence"
)
local possible_lactic_acidosis_subtitle = "Possible Lactic Acidosis"
local possible_acidosis_subtitle = "Possible Acidosis"



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

    local documented_dx_header = links.make_header_link("Documented Dx")
    local documented_dx_links = {}
    local labs_header = links.make_header_link("Laboratory Studies")
    local labs_links = {}
    local vital_signs_intake_header = links.make_header_link("Vital Signs/Intake")
    local vital_signs_intake_links = {}
    local clinical_evidence_header = links.make_header_link("Clinical Evidence")
    local clinical_evidence_links = {}
    local treatment_and_monitoring_header = links.make_header_link("Treatment and Monitoring")
    local treatment_and_monitoring_links = {}
    local abg_header = links.make_header_link("ABG")
    local abg_links = {}
    local vbg_header = links.make_header_link("VBG")
    local vbg_links = {}
    local blood_co2_header = links.make_header_link("Blood CO2")
    local blood_co2_links = {}
    local ph_header = links.make_header_link("PH")
    local ph_links = {}
    local lactate_header = links.make_header_link("Lactate")
    local lactate_links = {}
    local venous_co2_header = links.make_header_link("pCO2")
    local venous_co2_links = {}
    local vbh_co3_header = links.make_header_link("HCO3")
    local vbh_co3_links = {}
    local pao2_header = links.make_header_link("paO2")
    local pao2_links = {}
    local abg_hco3_header = links.make_header_link("HCO3")
    local abg_hco3_links = {}
    local pco2_header = links.make_header_link("PCO2")
    local pco2_links = {}
    local pa_co2_header = links.make_header_link("paCO2")
    local pa_co2_links = {}

    --- @param link CdiAlertLink?
    local function add_documented_dx_link(link)
        table.insert(documented_dx_links, link)
    end
    --- @param link CdiAlertLink?
    local function add_clinical_evidence_link(link)
        table.insert(clinical_evidence_links, link)
    end
    --- @param code string
    --- @param text string
    local function add_clinical_evidence_code(code, text)
        add_clinical_evidence_link(links.get_code_link { code = code, text = text })
    end
    --- @param prefix string
    --- @param text string
    local function add_clinical_evidence_code_prefix(prefix, text)
        add_clinical_evidence_link(codes.get_code_prefix_link { prefix = prefix, text = text })
    end
    --- @param code_set string[]
    --- @param text string
    local function add_clinical_evidence_any_code(code_set, text)
        add_clinical_evidence_link(links.get_code_link { codes = code_set, text = text })
    end
    --- @param code string
    --- @param text string
    local function add_clinical_evidence_abstraction(code, text)
        add_clinical_evidence_link(links.get_abstraction_link { code = code, text = text })
    end
    --- @param link CdiAlertLink?
    local function add_treatment_and_monitoring_link(link)
        table.insert(treatment_and_monitoring_links, link)
    end
    --- @param lnks CdiAlertLink[]
    local function add_treatment_and_monitoring_links(lnks)
        for _, lnk in ipairs(lnks) do
            table.insert(treatment_and_monitoring_links, lnk)
        end
    end
    local function compile_links()
        if #pa_co2_links > 0 then
            pa_co2_header.links = pa_co2_links
            table.insert(abg_links, pa_co2_header)
        end
        if #pco2_links > 0 then
            pco2_header.links = pco2_links
            table.insert(abg_links, pco2_header)
        end
        if #pao2_links > 0 then
            pao2_header.links = pao2_links
            table.insert(abg_links, pao2_header)
        end
        if #abg_hco3_header > 0 then
            abg_hco3_header.links = abg_hco3_links
            table.insert(abg_links, abg_hco3_header)
        end
        if #abg_links > 0 then
            abg_header.links = abg_links
            table.insert(labs_links, abg_header)
        end

        if #vbh_co3_links > 0 then
            vbh_co3_header.links = vbh_co3_links
            table.insert(vbg_links, vbh_co3_header)
        end
        if #venous_co2_links > 0 then
            venous_co2_header.links = venous_co2_links
            table.insert(vbg_links, venous_co2_header)
        end
        if #vbg_links > 0 then
            vbg_header.links = vbg_links
            table.insert(labs_links, vbg_header)
        end

        if #blood_co2_links > 0 then
            blood_co2_header.links = blood_co2_links
            table.insert(labs_links, blood_co2_header)
        end
        if #ph_links > 0 then
            ph_header.links = ph_links
            table.insert(labs_links, ph_header)
        end
        if #lactate_links > 0 then
            lactate_header.links = lactate_links
            table.insert(labs_links, lactate_header)
        end

        if #documented_dx_links > 0 then
            documented_dx_header.links = documented_dx_links
            table.insert(result_links, documented_dx_header)
        end
        if #clinical_evidence_links > 0 then
            clinical_evidence_header.links = clinical_evidence_links
            table.insert(result_links, clinical_evidence_header)
        end
        if #labs_links > 0 then
            labs_header.links = labs_links
            table.insert(result_links, labs_header)
        end
        if #vital_signs_intake_links > 0 then
            vital_signs_intake_header.links = vital_signs_intake_links
            table.insert(result_links, vital_signs_intake_header)
        end

        treatment_and_monitoring_header.links = treatment_and_monitoring_links
        table.insert(result_links, treatment_and_monitoring_header)

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end



    --------------------------------------------------------------------------------
    --- Alert Variables 
    --------------------------------------------------------------------------------
    local alert_code_dictionary = {
        ["E08.10"] = "Diabetes mellitus due to underlying condition with ketoacidosis without coma",
        ["E08.11"] = "Diabetes mellitus due to underlying condition with ketoacidosis with coma",
        ["E09.10"] = "Drug or chemical induced diabetes mellitus with ketoacidosis without coma",
        ["E09.11"] = "Drug or chemical induced diabetes mellitus with ketoacidosis with coma",
        ["E10.10"] = "Type 1 diabetes mellitus with ketoacidosis without coma",
        ["E10.11"] = "Type 1 diabetes mellitus with ketoacidosis with coma",
        ["E11.10"] = "Type 2 diabetes mellitus with ketoacidosis without coma",
        ["E11.11"] = "Type 2 diabetes mellitus with ketoacidosis with coma",
        ["E13.10"] = "Other specified diabetes mellitus with ketoacidosis without coma",
        ["E13.11"] = "Other specified diabetes mellitus with ketoacidosis with coma",
        ["E87.4"] = "Mixed disorder of acid-base balance",
        ["E87.21"] = "Acute Metabolic Acidosis",
        ["E87.22"] = "Chronic Metabolic Acidosis",
        ["P74.0"] = "Late metabolic acidosis of newborn"
    }
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)

    --------------------------------------------------------------------------------
    --- Predicate function filtering a medication list to only include medications 
    --- within 12 hours of one of these three discrete values: arterialBlood, pH, blood CO2
    --- 
    --- @param med Medication Medication being filtered
    --- 
    --- @return boolean True if the medication passes, false otherwise
    --------------------------------------------------------------------------------
    local acidosis_med_predicate = function(med)
        --- @type number[]
        local med_dv_dates = {}
        for _, date in ipairs(discrete.get_dv_dates(Account, arterial_blood_ph_dv_name)) do
            table.insert(med_dv_dates, date)
        end
        for _, date in ipairs(discrete.get_dv_dates(Account, ph_dv_name)) do
            table.insert(med_dv_dates, date)
        end
        for _, date in ipairs(discrete.get_dv_dates(Account, blood_co2_dv_name)) do
            table.insert(med_dv_dates, date)
        end

        local med_date = dates.date_string_to_int(med.start_date)

        for _, dv_date in ipairs(med_dv_dates) do
            local dv_date_after = dv_date + 12 * 60 * 60
            local dv_date_before = dv_date - 12 * 60 * 60
            if med_date >= dv_date_before and med_date <= dv_date_after then
                return true
            end
        end
        return false
    end



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    local chronic_repiratory_acidosis_abstraction_link =
        links.get_abstraction_link { code = "CHRONIC_RESPIRATORY_ACIDOSIS", text = "Chronic Respiratory Acidosis" }
    local meta_acidosis_abstraction_link =
        links.get_abstraction_link { code = "METABOLIC_ACIDOSIS", text = "Metabolic Acidosis" }
    local acute_acidosis_abstraction_link =
        links.get_abstraction_link { code = "ACUTE_ACIDOSIS", text = "Acute Acidosis" }
    local chronic_acidosis_abstraction_link =
        links.get_abstraction_link { code = "CHRONIC_ACIDOSIS", text = "Chronic Acidosis" }
    local lactic_acidosis_abstraction_link =
        links.get_abstraction_link { code = "LACTIC_ACIDOSIS", text = "Lactic Acidosis" }
    local e8720_code_link =
        links.get_code_link { code = "E87.20", text = "Acidosis Unspecified" }
    local e8729_code_link =
        links.get_code_link { code = "E87.29", text = "Other Acidosis" }

    -- Documented Dx
    local acute_respiratory_acidosis_abstraction_link =
        links.get_abstraction_link { code = "ACUTE_RESPIRATORY_ACIDOSIS", text = "Acute Respiratory Acidosis" }
    local j9602_code_link =
        links.get_code_link { code = "J96.02", text = "Acute Respiratory Failure with Hypercapnia" }

    -- Labs Subheading
    local blood_co2_dv_links = links.get_discrete_value_links {
        dvNames = blood_co2_dv_name,
        predicate = blood_co21_predicate,
        text = "Blood CO2",
    }
    local high_serum_lactate_level_dv_links = links.get_discrete_value_links {
        dvNames = serum_lactate_dv_name,
        predicate = serum_lactate1_predicate,
        text = "Serum Lactate",
    }

    -- ABG Subheading
    local low_arterial_blood_ph_multi_dv_links = links.get_discrete_value_links {
        dvNames = arterial_blood_ph_dv_name,
        predicates = arterial_blood_ph2_predicate,
        text = "PH",
    }
    local paco2_dv_links = links.get_discrete_value_links {
        dvNames = pco2_dv_name,
        predicate = pco21_predicate,
        text = "paC02",
    }
    local high_serum_bicarbonate_dv_links = links.get_discrete_value_links {
        dvNames = serum_bicarbonate_dv_name,
        predicate = serum_bicarbonate1_predicate,
        text = "HC03",
    }
    -- VBG Subheading
    local ph_dv_links = links.get_discrete_value_links {
        dvNames = ph_dv_name,
        predicate = ph2_predicate,
        text = "PH",
    }
    local venous_co2_dv_links = links.get_discrete_value_links {
        dvNames = venous_blood_co2_dv_name,
        predicate = venous_blood_co2_predicate,
        text = "pCO2",
    }

    -- Meds
    local albumin_medication_links = links.get_medication_links {
        cat = "Albumin",
        text = "Albumin",
        useCdiAlertCategoryField = true,
        predicate = acidosis_med_predicate
    }
    local fluid_bolus_medication_links = links.get_medication_links {
        cat = "Fluid Bolus",
        text = "Fluid Bolus",
        useCdiAlertCategoryField = true,
        maxPerValue = 9999,
        predicate = acidosis_med_predicate
    }
    local fluid_bolus_abstraction_link = links.get_abstraction_value_link {
        code = "FLUID_BOLUS",
        text = "Fluid Bolus"
    }
    local fluid_resuscitation_abstraction_link = links.get_abstraction_value_link {
        code = "FLUID_RESCUSITATION",
        text = "Fluid Resuscitation"
    }
    local sodium_bicarbonate_med_links = links.get_medication_links {
        cat = "Sodium Bicarbonate",
        text = "Sodium Bicarbonate",
        useCdiAlertCategoryField = true,
        maxPerValue = 9999,
        predicate = acidosis_med_predicate
    }
    local sodium_bicarbonate_abstraction_links = links.get_abstraction_value_links {
        code = "SODIUM_BICARBONATE",
        text = "Sodium Bicarbonate"
    }

    local full_specified_exist =
        #account_alert_codes >= 1 or
        chronic_repiratory_acidosis_abstraction_link ~= nil or
        lactic_acidosis_abstraction_link ~= nil or
        meta_acidosis_abstraction_link ~= nil

    local unspecified_exist =
        e8720_code_link ~= nil or
        e8729_code_link ~= nil or
        acute_acidosis_abstraction_link ~= nil or
        chronic_acidosis_abstraction_link ~= nil



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if
        subtitle == possible_acute_respiratory_acidosis_subtitle and
        (acute_respiratory_acidosis_abstraction_link or j9602_code_link)
    then
        -- Auto resolve alert if it currently triggered for acute respiratory acidosis
        for _, code in pairs(account_alert_codes) do
            local code_link = links.get_code_link {
                code = code,
                text = "Autoresolved Specified Code - " .. alert_code_dictionary[code]
            }
            if code_link then
                add_documented_dx_link(code_link)
                break
            end
        end

        if j9602_code_link then
            j9602_code_link.link_text = "Autoresolved Evidence - " .. j9602_code_link.link_text
            add_documented_dx_link(j9602_code_link)
        end
        if acute_respiratory_acidosis_abstraction_link then
            acute_respiratory_acidosis_abstraction_link.link_text =
                "Autoresolved Evidence - " .. acute_respiratory_acidosis_abstraction_link.link_text
            add_documented_dx_link(acute_respiratory_acidosis_abstraction_link)
        end

        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        subtitle == respiratory_acidosis_lacking_evidence_subtitle and
        (#venous_co2_dv_links > 0 or #ph_dv_links > 0) and
        (#low_arterial_blood_ph_multi_dv_links > 1 or #ph_dv_links > 1)
    then
        -- Auto resolve alert if triggered for Acute Respiratory Acidosis Possibly Lacking Supporting Evidence
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        (subtitle == possible_lactic_acidosis_subtitle or subtitle == possible_acidosis_subtitle) and
        (unspecified_exist or full_specified_exist)
    then
        -- Auto resolve alert if it currently triggered for Possible Lactic Acidosis or Possible Acidosis
        if #account_alert_codes > 0 then
            for _, code in pairs(account_alert_codes) do
                local code_link = links.get_code_link {
                    code = code,
                    text = "Autoresolved Specified Code - " .. alert_code_dictionary[code]
                }
                if code_link then
                    add_documented_dx_link(code_link)
                    break
                end
            end
        end
        if lactic_acidosis_abstraction_link then
            lactic_acidosis_abstraction_link.link_text =
                "Autoresolved Evidence - " .. lactic_acidosis_abstraction_link.link_text
            add_documented_dx_link(lactic_acidosis_abstraction_link)
        end
        if chronic_repiratory_acidosis_abstraction_link then
            chronic_repiratory_acidosis_abstraction_link.link_text =
                "Autoresolved Evidence - " .. chronic_repiratory_acidosis_abstraction_link.link_text
            add_documented_dx_link(chronic_repiratory_acidosis_abstraction_link)
        end
        if meta_acidosis_abstraction_link then
            meta_acidosis_abstraction_link.link_text =
                "Autoresolved Evidence - " .. meta_acidosis_abstraction_link.link_text
            add_documented_dx_link(meta_acidosis_abstraction_link)
        end
        if e8720_code_link then
            e8720_code_link.link_text =
                "Autoresolved Evidence - " .. e8720_code_link.link_text
            add_documented_dx_link(e8720_code_link)
        end
        if e8729_code_link then
            e8729_code_link.link_text =
                "Autoresolved Evidence - " .. e8729_code_link.link_text
            add_documented_dx_link(e8729_code_link)
        end
        if acute_acidosis_abstraction_link then
            acute_acidosis_abstraction_link.link_text =
                "Autoresolved Evidence - " .. acute_acidosis_abstraction_link.link_text
            add_documented_dx_link(acute_acidosis_abstraction_link)
        end
        if chronic_acidosis_abstraction_link then
            chronic_acidosis_abstraction_link.link_text =
                "Autoresolved Evidence - " .. chronic_acidosis_abstraction_link.link_text
            add_documented_dx_link(chronic_acidosis_abstraction_link)
        end

        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        not acute_respiratory_acidosis_abstraction_link and
        not j9602_code_link and
        (#venous_co2_dv_links > 0 or #paco2_dv_links > 0) and
        (#low_arterial_blood_ph_multi_dv_links > 0 or #ph_dv_links > 0)
    then
        -- Trigger alert for Possible Acute Respiratory Acidosis
        add_documented_dx_link(e8720_code_link)
        add_documented_dx_link(e8729_code_link)
        add_documented_dx_link(acute_acidosis_abstraction_link)
        add_documented_dx_link(chronic_acidosis_abstraction_link)

        Result.subtitle = possible_acute_respiratory_acidosis_subtitle
        Result.passed = true


    elseif
        acute_respiratory_acidosis_abstraction_link and
        not venous_co2_dv_links and
        not paco2_dv_links and
        #low_arterial_blood_ph_multi_dv_links == 0 and
        #ph_dv_links == 0
    then
        -- Trigger alert for Acute Respiratory Acidosis Documented Possibly Lacking Supporting Evidence
        add_documented_dx_link(acute_respiratory_acidosis_abstraction_link)
        Result.subtitle = respiratory_acidosis_lacking_evidence_subtitle
        Result.passed = true

    elseif not full_specified_exist and not unspecified_exist and #high_serum_lactate_level_dv_links > 0 then
        -- Trigger alert for Possible Lactic Acidosis
        Result.subtitle = possible_lactic_acidosis_subtitle
        Result.passed = true

    elseif
        (
            not unspecified_exist and
            not full_specified_exist and
            (#low_arterial_blood_ph_multi_dv_links >= 1 or #ph_dv_links >= 1 or #blood_co2_dv_links >= 1) or
            (
                albumin_medication_links or
                fluid_bolus_medication_links or
                fluid_bolus_abstraction_link or
                fluid_resuscitation_abstraction_link or
                sodium_bicarbonate_med_links or
                sodium_bicarbonate_abstraction_links
            )
        )
    then
        -- Trigger alert for Possible Acidosis
        add_treatment_and_monitoring_link(fluid_bolus_abstraction_link)
        add_treatment_and_monitoring_link(fluid_resuscitation_abstraction_link)
        add_treatment_and_monitoring_links(sodium_bicarbonate_abstraction_links)
        add_treatment_and_monitoring_links(sodium_bicarbonate_med_links)
        add_treatment_and_monitoring_links(albumin_medication_links)
        add_treatment_and_monitoring_links(fluid_bolus_medication_links)
        add_treatment_and_monitoring_links(sodium_bicarbonate_med_links)

        Result.subtitle = possible_acidosis_subtitle
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Clinical Evidence
            local r4182_code_link = links.get_code_links { code = "R41.82", text = "Altered Level Of Consciousness" }
            if r4182_code_link then
                table.insert(clinical_evidence_links, r4182_code_link)
                local altered_abs_link =
                    links.get_abstraction_link {
                        code = "ALTERED_LEVEL_OF_CONSCIOUSNESS",
                        text = "Altered Level Of Consciousness"
                    }
                if altered_abs_link then
                    altered_abs_link.hidden = true
                    table.insert(clinical_evidence_links, altered_abs_link)
                end
            else
                local altered_abs_link =
                    links.get_abstraction_links {
                        code = "ALTERED_LEVEL_OF_CONSCIOUSNESS",
                        text = "Altered Level Of Consciousness"
                    }
                table.insert(clinical_evidence_links, altered_abs_link)
            end
            table.insert(clinical_evidence_links, links.get_abstraction_link { code = "AZOTEMIA", text = "Azotemia" })
            table.insert(clinical_evidence_links, links.get_code_link { code = "R11.14", text = "Bilious Vomiting" })
            table.insert(clinical_evidence_links, links.get_code_link { code = "R11.15", text = "Cyclical Vomiting" })
            table.insert(clinical_evidence_links, links.get_abstraction_link { code = "DIARRHEA", text = "Diarrhea" })
            table.insert(clinical_evidence_links, links.get_code_link { code = "R41.0", text = "Disorientation" })
            table.insert(
                clinical_evidence_links,
                links.get_discrete_value_link { dvNames = fio2_dv_name, predicate = fio21_predicate, text = "Fi02" }
            )
            table.insert(
                clinical_evidence_links,
                links.get_code_link { code = "R53.83", text = "Fatigue" }
            )
            table.insert(
                clinical_evidence_links,
                links.get_abstraction_link { code = "OPIOID_OVERDOSE", text = "Opioid Overdose" }
            )
            table.insert(
                clinical_evidence_links,
                links.get_abstraction_link { code = "SHORTNESS_OF_BREATH", text = "Shortness of Breath" }
            )
            table.insert(
                clinical_evidence_links,
                links.get_code_link { code = "R11.10", text = "Vomiting" }
            )
            table.insert(
                clinical_evidence_links,
                links.get_code_link { code = "R11.13", text = "Vomiting Fecal Matter" }
            )
            table.insert(
                clinical_evidence_links,
                links.get_code_link { code = "R11.11", text = "Vomiting Without Nausea" }
            )
            table.insert(
                clinical_evidence_links,
                links.get_abstraction_link { code = "WEAKNESS", text = "Weakness" }
            )

            -- Labs
            table.insert(
                labs_links,
                links.get_discrete_value_link {
                    dvNames = anion_gap_dv_name,
                    predicate = anion_gap1_predicate,
                    text = "Anion Gap"
                }
            )

            local blood_glucose_dv_link =
                links.get_discrete_value_link {
                    dvNames = blood_glucose_dv_name,
                    predicate = blood_glucose1_predicate,
                    text = "Blood Glucose"
                }

            if blood_glucose_dv_link then
                table.insert(labs_links, blood_glucose_dv_link)
            else
                table.insert(
                    labs_links,
                    links.get_discrete_value_link {
                        dvNames = blood_glucose_poc_dv_name,
                        predicate = blood_glucose_poc1_predicate,
                        text = "Blood Glucose POC"
                    }
                )
            end

            table.insert(
                labs_links,
                links.get_abstraction_link { code = "POSITIVE_KETONES_IN_URINE", text = "Positive Ketones In Urine" }
            )
            table.insert(
                labs_links,
                links.get_discrete_value_link {
                    dvNames = serum_blood_urea_nitrogen_dv_name,
                    predicate = serum_blood_urea_nitrogen1_predicate,
                    text = "Serum Blood Urea Nitrogen"
                }
            )
            table.insert(
                labs_links,
                links.get_discrete_value_link {
                    dvNames = serum_chloride_dv_name,
                    predicate = serum_chloride1_predicate,
                    text = "Serum Chloride"
                }
            )
            table.insert(
                labs_links,
                links.get_discrete_value_link {
                    dvNames = serum_creatinine_dv_name,
                    predicate = serum_creatinine1_predicate,
                    text = "Serum Creatinine"
                }
            )
            table.insert(
                labs_links,
                links.get_discrete_value_link {
                    dvNames = serum_ketone_dv_name,
                    predicate = serum_ketone1_predicate,
                    text = "Serum Ketones"
                }
            )
            table.insert(
                labs_links,
                links.get_discrete_value_link {
                    dvNames = urine_ketones_dv_name,
                    predicate = function(dv)
                        return dv.result ~= nil and dv.result:lower():find("positive") ~= nil
                    end,
                    text = "Urine Ketones"
                }
            )

            -- Lactate, ph, and blood links
            table.insert(lactate_links, links.get_discrete_value_link { dvNames = serum_lactate_dv_name, predicate = serum_lactate2_predicate, text = "Serum Lactate" })
            for _, entry in ipairs(high_serum_lactate_level_dv_links or {}) do
                table.insert(lactate_links, entry)
            end
            for _, entry in ipairs(low_arterial_blood_ph_multi_dv_links) do
                table.insert(ph_links, entry)
            end
            for _, entry in ipairs(ph_dv_links or {}) do
                table.insert(ph_links, entry)
            end
            table.insert(blood_co2_links, links.get_discrete_value_link { dvNames = blood_co2_dv_name, predicate = blood_co22_predicate, text = "Blood CO2" })
            for _, entry in ipairs(blood_co2_dv_links or {}) do
                table.insert(blood_co2_links, entry)
            end

            -- Vitals
            table.insert(vital_signs_intake_links, links.get_discrete_value_link { dvNames = glasgow_coma_scale_dv_name, predicate = glasgow_coma_scale1_predicate, text = "Glasgow Coma Scale" })
            table.insert(vital_signs_intake_links, links.get_discrete_value_link { dvNames = heart_rate_dv_name, predicate = heart_rate1_predicate, text = "Heart Rate" })
            table.insert(vital_signs_intake_links, links.get_discrete_value_link { dvNames = map_dv_name, predicate = map1_predicate, text = "Mean Arterial Pressure" })
            table.insert(vital_signs_intake_links, links.get_discrete_value_link { dvNames = respiratory_rate_dv_name, predicate = respiratory_rate1_predicate, text = "Respiratory Rate" })
            table.insert(vital_signs_intake_links, links.get_discrete_value_link { dvNames = respiratory_rate_dv_name, predicate = respiratory_rate2_predicate, text = "Respiratory Rate" })
            table.insert(vital_signs_intake_links, links.get_discrete_value_link { dvNames = spo2_dv_name, predicate = spo21_predicate, text = "SpO2" })
            table.insert(vital_signs_intake_links, links.get_discrete_value_link { dvNames = sbp_dv_name, predicate = sbp1_predicate, text = "Systolic Blood Pressure" })

            -- ABG
            table.insert(abg_links, links.get_discrete_value_link { dvNames = base_excess_dv_name, predicate = base_excess1_predicate, text = "Base Excess" })
            table.insert(abg_links, links.get_discrete_value_link { dvNames = fio2_dv_name, predicate = fio21_predicate, text = "FiO2" })
            table.insert(abg_links, links.get_discrete_value_link { dvNames = po2_dv_name, predicate = po21_predicate, text = "pO2" })
            if paco2_dv_links and #paco2_dv_links > 0 then
                for _, entry in ipairs(paco2_dv_links or {}) do
                    table.insert(pa_co2_links, entry)
                end
            else
                table.insert(pa_co2_links, links.get_discrete_value_link { dvNames = pco2_dv_name, predicate = pco22_predicate, text = "paC02" })
            end
            if high_serum_bicarbonate_dv_links and #high_serum_bicarbonate_dv_links > 0 then
                for _, entry in ipairs(high_serum_bicarbonate_dv_links or {}) do
                    table.insert(abg_hco3_links, entry)
                end
            else
                table.insert(abg_hco3_links, links.get_discrete_value_link { dvNames = serum_bicarbonate_dv_name, predicate = serum_bicarbonate3_predicate, text = "HC03" })
            end

            -- ABG
            table.insert(
                pao2_links,
                links.get_discrete_value_links { dvNames = pao2_dv_name, predicate = pao21_predicate, text = "Pa02", maxPerValue = 10 }
            )

            -- VBG
            table.insert(
                vbh_co3_links,
                links.get_discrete_value_links { dvNames = hco3_dv_name, predicate = hco31_predicate, text = "HC03", maxPerValue = 10 }
            )
            table.insert(
                vbh_co3_links,
                links.get_discrete_value_links { dvNames = hco3_dv_name, predicate = hco32_predicate, text = "HC03", maxPerValue = 10 }
            )
            for _, entry in ipairs(venous_co2_dv_links or {}) do
                table.insert(venous_co2_links, entry)
            end
        end

        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end
