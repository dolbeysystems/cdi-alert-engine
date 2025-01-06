---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Hypertensive Crisis
---
--- This script checks an account to see if it matches the criteria for a hypertensive crisis alert.
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
local dates = require("libs.common.dates")
local discrete = require("libs.common.discrete_values")(Account)
local headers = require("libs.common.headers")(Account)
local lists = require("libs.common.lists")
local cdi_alert_link = require "cdi.link"



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local dv_alanine_transaminase = { "ALT", "ALT/SGPT (U/L)	16-61" }
local calc_alanine_transaminase1 = function(dv_, num) return num > 61 end
local dv_aspartate_transaminase = { "AST", "AST/SGOT (U/L)" }
local calc_aspartate_transaminase1 = function(dv_, num) return num > 35 end
local dv_dbp = { "BP Arterial Diastolic cc (mm Hg)", "DBP 3.5 (No Calculation) (mmhg)", "DBP 3.5 (No Calculation) (mm Hg)" }
local calc_dbp1 = function(dv_, num) return num > 120 end
local dv_glasgow_coma_scale = { "3.5 Neuro Glasgow Score" }
local calc_glasgow_coma_scale1 = function(dv_, num) return num < 15 end
local dv_heart_rate = { "Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)", "3.5 Heart Rate (Radial) (bpm)", "SCC Monitor Pulse (bpm)" }
local dv_map = { "Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)" }
local dv_sbp = { "SBP 3.5 (No Calculation) (mm Hg)" }
local calc_sbp1 = function(dv_, num) return num > 180 end
local dv_serum_blood_urea_nitrogen = { "BUN (mg/dL)" }
local calc_serum_blood_urea_nitrogen1 = function(dv_, num) return num > 23 end
local dv_serum_creatinine = { "CREATININE (mg/dL)", "CREATININE SERUM (mg/dL)" }
local calc_serum_creatinine1 = function(dv_, num) return num > 1.30 end
local dv_serum_lactate = { "Lactate Bld-sCnc (mmol/L)", "LACTIC ACID (SAH) (mmol/L)" }
local calc_serum_lactate1 = function(dv_, num) return num >= 4 end
local dv_troponin_t = { "TROPONIN, HIGH SENSITIVITY (ng/L)" }
local calc_troponin_t1 = function(dv_, num) return num > 59 end
local dv_ts_amphetamine = { "AMP/METH UR", "AMPHETAMINE URINE" }
local dv_ts_cocaine = { "COCAINE URINE", "COCAINE UR CONF" }



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = ScriptName }
local subtitle = existing_alert and existing_alert.subtitle or nil



--------------------------------------------------------------------------------
--- Header Variables and Helper Functions
--------------------------------------------------------------------------------
local result_links = {}
local documented_dx_header = headers.make_header_builder("Documented Code", 1)
local vital_signs_intake_header = headers.make_header_builder("Vital Signs/Intake", 2)
local organ_dysfunction_header = headers.make_header_builder("End Organ Dysfunction", 3)
local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 4)
local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 5)
local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 6)

local function compile_links()
    table.insert(result_links, laboratory_studies_header:build(true))
    table.insert(result_links, documented_dx_header:build(true))
    table.insert(result_links, clinical_evidence_header:build(true))
    table.insert(result_links, vital_signs_intake_header:build(true))
    table.insert(result_links, organ_dysfunction_header:build(true))
    table.insert(result_links, treatment_and_monitoring_header:build(true))

    if existing_alert then
        result_links = links.merge_links(existing_alert.links, result_links)
    end
    Result.links = result_links
end



--------------------------------------------------------------------------------
--- Script Specific Functions
--------------------------------------------------------------------------------
--- @param sbp_dic DiscreteValue[]
--- @param dbp_dic DiscreteValue[]
local function bp_single_line_lookup(sbp_dic, dbp_dic)
    local map_discrete_values = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_map,
        predicate = function(dv_, num) return num ~= nil end,
    }
    local heart_rate_discrete_values = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_heart_rate,
        predicate = function(dv_, num) return num ~= nil end,
    }
    local dbp_dv = nil
    local hr_dv = nil
    local map_dv = nil
    local matching_date = nil
    local h = #heart_rate_discrete_values
    local m = #map_discrete_values

    for _, item in ipairs(sbp_dic) do
        dbp_dv = nil
        hr_dv = nil
        map_dv = nil
        matching_date = dates.date_string_to_int(item.result_date)
        if m > 0 then
            for _, item1 in map_discrete_values do
                if dates.date_string_to_int(item1.result_date) == matching_date then
                    map_dv = item1.result
                    break
                end
            end
        end
        if h > 0 then
            for _, item2 in heart_rate_discrete_values do
                if dates.date_string_to_int(item2.result_date) == matching_date then
                    hr_dv = item2.result
                    break
                end
            end
        end
        for _, item3 in ipairs(dbp_dic) do
            if dates.date_string_to_int(item3.result_date) == matching_date then
                dbp_dv = item3.result
                break
            end
        end

        if not dbp_dv then dbp_dv = "XX" end
        if not hr_dv then hr_dv = "XX" end
        if not map_dv then map_dv = "XX" end

        local link = cdi_alert_link()
        link.discrete_value_id = item.unique_id
        link.link_text =
            item.result_date .. " HR = " .. hr_dv .. ", BP = " .. item.result .. "/" .. dbp_dv .. ", MAP = " .. map_dv
        vital_signs_intake_header:add_link(link)
    end
end

local function linked_greater_values()
    local value = 80
    local value2 = 120

    local dbp_discrete_values = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_dbp,
        predicate = function(dv_, num) return num ~= nil end,
    }
    local sbp_discrete_values = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_sbp,
        predicate = function(dv_, num) return num ~= nil end,
    }
    local discrete_dic3 = {}
    local discrete_dic4 = {}
    local matched_dbp_list = {}
    local matched_sbp_list = {}

    local s = 0
    local d = 0
    local x = #dbp_discrete_values
    local a = #sbp_discrete_values
    local date_list = {}
    local date_list2 = {}

    if x >= 2 and a >= 2 then
        for _ in ipairs(dbp_discrete_values) do
            local x_item = dbp_discrete_values[x]
            local a_item = sbp_discrete_values[a]

            local x_date = dates.date_string_to_int(x_item.result_date)
            local a_date = dates.date_string_to_int(a_item.result_date)

            if s <= 0 or a <= 0 then
                break
            elseif
                x_date == a_date and
                x_item.result > value and
                a_item.result > value2 and
                not date_list[x_date] and
                not date_list2[a_date]
            then
                date_list[x_date] = true
                d = d + 1
                discrete_dic4[d] = x_item
                s = s + 1
                discrete_dic3[s] = a_item
                table.insert(matched_dbp_list, x_item.result)
                table.insert(matched_sbp_list, a_item.result)
                x = x - 1
                a = a - 1
            elseif x_date ~= a_date then
                for _, item2 in ipairs(sbp_discrete_values) do
                    if x_item.result_date == item2.result_date then
                        if
                            tonumber(x_item.result) > value and
                            tonumber(item2.result) > value2 and
                            not date_list[x_date] and
                            not date_list2[a_date]
                        then
                            date_list[x_date] = true
                            d = d + 1
                            discrete_dic4[d] = x_item
                            s = s + 1
                            discrete_dic3[s] = item2
                            table.insert(matched_dbp_list, x_item.result)
                            table.insert(matched_sbp_list, item2.result)
                            x = x - 1
                            a = a - 1
                        end
                    end
                end
            else
                x = x - 1
                a = a - 1
            end
        end
    end

    if d > 0 and s > 0 then
        bp_single_line_lookup(discrete_dic3, discrete_dic4)
    end
    if #matched_sbp_list == 0 then
        matched_sbp_list = { false }
    end
    if #matched_dbp_list == 0 then
        matched_dbp_list = { false }
    end
    return { matched_sbp_list, matched_dbp_list }
end

local function non_linked_greater_values()
    local value = 80
    local value2 = 120

    local dbp_discrete_values = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_dbp,
        predicate = function(dv_, num) return num ~= nil end,
    }
    local sbp_discrete_values = discrete.get_ordered_discrete_values {
        discreteValueNames = dv_sbp,
        predicate = function(dv_, num) return num ~= nil end,
    }
    local combined_discrete_values = {}

    for _, item in ipairs(dbp_discrete_values) do
        table.insert(combined_discrete_values, item)
    end
    for _, item in ipairs(sbp_discrete_values) do
        table.insert(combined_discrete_values, item)
    end
    table.sort(combined_discrete_values, function(a, b)
        return dates.date_string_to_int(a.result_date) < dates.date_string_to_int(b.result_date)
    end)

    local discrete_dic2 = {}
    local discrete_dic3 = {}
    local s = 0
    local d = 0
    local x = #combined_discrete_values
    local id_list = {}

    if x > 0 then
        for _, item in ipairs(combined_discrete_values) do
            if lists.includes(dv_dbp, item.name) and tonumber(item.result) > value and not id_list[item.unique_id] then
                d = d + 1
                discrete_dic3[d] = item
                id_list[item.unique_id] = true
                for _, item2 in ipairs(combined_discrete_values) do
                    if
                        dates.date_string_to_int(item.result_date) == dates.date_string_to_int(item2.result_date) and
                        lists.includes(dv_sbp, item2.name) and
                        not id_list[item2.unique_id]
                    then
                        s = s + 1
                        discrete_dic2[s] = item2
                        id_list[item2.unique_id] = true
                    end
                end
            elseif lists.includes(dv_sbp, item.name) and tonumber(item.result) > value2 and not id_list[item.unique_id] then
                s = s + 1
                discrete_dic2[s] = item
                id_list[item.unique_id] = true
                for _, item2 in ipairs(combined_discrete_values) do
                    if
                        dates.date_string_to_int(item.result_date) == dates.date_string_to_int(item2.result_date) and
                        lists.includes(dv_dbp, item2.name) and
                        tonumber(item2.result) > value and
                        not id_list[item2.unique_id]
                    then
                        d = d + 1
                        discrete_dic3[d] = item2
                        id_list[item2.unique_id] = true
                    end
                end
            end
        end
    end
    if d > 0 or s > 0 then
        bp_single_line_lookup(discrete_dic2, discrete_dic3)
    end
end



if not existing_alert or not existing_alert.validated then
    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Negations
    local kidney_disease_check = links.get_code_link {
        codes = {
            "N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6", "N18.9", "N19"
        },
        text = "Kidney Disease"
    }
    local heart_failure_negation = links.get_code_link {
        codes = { "I50.22", "I50.32", "I50.42", "I50.812" },
        text = "Heart Failure"
    }
    local negation_aspartate = links.get_code_link {
        codes = {
            "B18.2", "B19.20", "K70.10", "K70.11", "K70.30", "K70.31", "K70.40", "K70.41",
            "K72.10", "K72.11", "K73", "K74.60", "K74.69", "Z79.01", "Z86.19"
        },
        text = "Negation Aspartate"
    }
    local permissive_hypertension_abs = links.get_abstraction_link {
        code = "PERMISSIVE_HYPERTENSION",
        text = "Permissive Hypertension"
    }
    local g40_code = links.get_code_link { codes = { "G40" }, text = "Epilepsy and Recurrent Seizures" }

    -- Alert Trigger
    local i160_code = links.get_code_link { code = "I16.0", text = "Hypertensive Urgency" }
    local i161_code = links.get_code_link { code = "I16.1", text = "Hypertensive Emergency" }
    local i169_code = links.get_code_link { code = "I16.9", text = "Unspecified Hypertensive Crisis" }

    -- Abs
    local accelerated_hyper_abs = links.get_abstraction_link {
        code = "ACCELERATED_HYPERTENSION",
        text = "Accelerated Hypertension"
    }
    local malignant_hyper_abs = links.get_abstraction_link {
        code = "MALIGNANT_HYPERTENSION",
        text = "Malignant Hypertension"
    }

    -- Organ
    local heart_failure = links.get_code_link {
        codes = {
            "I50.21", "I50.23", "I50.31", "I50.33", "I50.41", "I50.43", "I50.811", "I50.813"
        },
        text = "Acute Heart Failure"
    }
    local n179_code = links.get_code_link { code = "N17.9", text = "Acute Kidney Failure" }
    local i21_codes = links.get_code_link { code = "^I21%.", text = "Acute MI" }
    local j810_code = links.get_code_link { code = "J81.0", text = "Acute Pulmonary Edema" }
    local j960_codes = links.get_code_link { code = "^J96%.0", text = "Acute Respiratory Failure" }
    local high_alanine_dv = links.get_discrete_value_link {
        discreteValueNames = dv_alanine_transaminase,
        text = "Alanine Aminotransferase",
        predicate = calc_alanine_transaminase1
    }
    local altered = links.get_code_link { code = "R41.82", text = "Altered Level of Consciousness" }
    if not altered then
        altered = links.get_abstraction_link {
            code = "ALTERED_LEVEL_OF_CONSCIOUSNESS",
            text = "Altered Level Of Consciousness"
        }
    end
    local aortic_dissection = links.get_code_link {
        codes = {
            "I71.00", "I71.010", "I71.011", "I71.012", "I71.019",
            "I71.02", "I71.03"
        },
        text = "Aortic Dissection"
    }
    local high_aspartate_dv = links.get_discrete_value_link {
        discreteValueNames = dv_aspartate_transaminase,
        text = "Aspartate Aminotransferase",
        predicate = calc_aspartate_transaminase1
    }
    local i639_code = links.get_code_link { code = "I63.9", text = "Cerebral Infarction" }
    local r079_code = links.get_code_link { code = "R07.9", text = "Chest Pain" }
    local r410_code = links.get_code_link { code = "R41.0", text = "Disorientation" }
    local d65_code = links.get_code_link { code = "D65", text = "Disseminated Intravascular Coagulation" }
    local r748_code = links.get_code_link { code = "R74.8", text = "Elevated Liver Function" }
    local encephalopathy = links.get_code_link { codes = { "G93.40", "G93.49" }, text = "Encephalopathy" }
    local glasgow_coma_score_dv = links.get_discrete_value_link {
        discreteValueNames = dv_glasgow_coma_scale,
        text = "Glasgow Coma Score",
        predicate = calc_glasgow_coma_scale1
    }
    local e806_code = links.get_code_link { code = "E80.6", text = "Hyperbilirubinemia" }
    local i674_code = links.get_code_link { code = "I67.4", text = "Hypertensive Encephalopathy" }
    local r17_code = links.get_code_link { code = "R17", text = "Jaundice" }
    local k72_codes = links.get_code_link { codes = { "K72.00", "K72.01" }, text = "Liver Failure" }
    local i61_codes = links.get_code_link {
        codes = {
            "I61.0", "I61.1", "I61.2", "I61.3", "I61.4", "I61.6", "I61.8", "I61.9"
        },
        text = "Nontraumatic Intracerebral Hemorrhage"
    }
    local i62_codes = links.get_code_link {
        codes = {
            "I62.00", "I62.01", "I62.02", "I62.03", "I62.1", "I62.9"
        },
        text = "Nontraumatic Subarachnoid Hemorrhage"
    }
    local r569_code = links.get_code_link { code = "R56.9", text = "Seizure" }
    local high_serum_blood_urea_nitrogen_dv = links.get_discrete_value_link {
        discreteValueNames = dv_serum_blood_urea_nitrogen,
        text = "Serum Blood Urea Nitrogen",
        predicate = calc_serum_blood_urea_nitrogen1
    }
    local high_serum_creatinine_dv = links.get_discrete_value_link {
        discreteValueNames = dv_serum_creatinine,
        text = "Serum Creatinine",
        predicate = calc_serum_creatinine1
    }
    local serum_lactate_dv = links.get_discrete_value_link {
        discreteValueNames = dv_serum_lactate,
        text = "Serum Lactate",
        predicate = calc_serum_lactate1
    }
    local troponin_t_dv = links.get_discrete_value_link {
        discreteValueNames = dv_troponin_t,
        text = "Troponin T High Sensitivity",
        predicate = calc_troponin_t1
    }

    -- Meds for IV
    local antianginal_iv_med = links.get_medication_link {
        cat = "Antianginal Medication",
        text = "Antianginal Medication"
    }
    local beta_blocker_iv_med = links.get_medication_link {
        cat = "Beta Blocker",
        text = "Beta Blocker"
    }
    local calcium_channel_iv_med = links.get_medication_link {
        cat = "Calcium Channel Blockers",
        text = "Calcium Channel Blockers"
    }
    local hydralazine_iv_med = links.get_medication_link { cat = "Hydralazine", text = "Hydralazine" }
    local nitroglycerin_iv_med = links.get_medication_link { cat = "Nitroglycerin", text = "Nitroglycerin" }
    local sodium_nitroprusside_iv_med = links.get_medication_link {
        cat = "Sodium Nitroprusside",
        text = "Sodium Nitroprusside"
    }

    -- Vitals
    local bp_multi_dv = linked_greater_values()

    -- Lacking BPs only
    local dbp_dv = links.get_discrete_value_link {
        discreteValueNames = dv_dbp,
        text = "Diastolic Blood Pressure",
        predicate = calc_dbp1
    }
    local sbp_dv = links.get_discrete_value_link {
        discreteValueNames = dv_sbp,
        text = "Systolic Blood Pressure",
        predicate = calc_sbp1
    }

    -- Abstracting End organ Damage Signs
    local eods = 0
    if not kidney_disease_check and high_serum_blood_urea_nitrogen_dv then
        organ_dysfunction_header:add_link(high_serum_blood_urea_nitrogen_dv)
        eods = eods + 1
    elseif kidney_disease_check and high_serum_blood_urea_nitrogen_dv then
        high_serum_blood_urea_nitrogen_dv.hidden = true
        organ_dysfunction_header:add_link(high_serum_blood_urea_nitrogen_dv)
    end
    if not kidney_disease_check and high_serum_creatinine_dv then
        organ_dysfunction_header:add_link(high_serum_creatinine_dv)
        eods = eods + 1
    elseif kidney_disease_check and high_serum_creatinine_dv then
        high_serum_creatinine_dv.hidden = true
        organ_dysfunction_header:add_link(high_serum_creatinine_dv)
    end
    if not heart_failure_negation and troponin_t_dv then
        organ_dysfunction_header:add_link(troponin_t_dv)
        eods = eods + 1
    elseif heart_failure_negation and troponin_t_dv then
        troponin_t_dv.hidden = true
        organ_dysfunction_header:add_link(troponin_t_dv)
        eods = eods + 1
    end
    if not negation_aspartate and e806_code then
        organ_dysfunction_header:add_link(e806_code)
        eods = eods + 1
    elseif negation_aspartate and e806_code then
        e806_code.hidden = true
        organ_dysfunction_header:add_link(e806_code)
    end
    if not negation_aspartate and r17_code then
        organ_dysfunction_header:add_link(r17_code)
        eods = eods + 1
    elseif negation_aspartate and r17_code then
        r17_code.hidden = true
        organ_dysfunction_header:add_link(r17_code)
    end
    if not negation_aspartate and r748_code then
        organ_dysfunction_header:add_link(r748_code)
        eods = eods + 1
    elseif negation_aspartate and r748_code then
        r748_code.hidden = true
        organ_dysfunction_header:add_link(r748_code)
    end
    if not negation_aspartate and high_alanine_dv then
        organ_dysfunction_header:add_link(high_alanine_dv)
        eods = eods + 1
    elseif negation_aspartate and high_alanine_dv then
        high_alanine_dv.hidden = true
        organ_dysfunction_header:add_link(high_alanine_dv)
    end
    if not negation_aspartate and high_aspartate_dv then
        organ_dysfunction_header:add_link(high_aspartate_dv)
        eods = eods + 1
    elseif negation_aspartate and high_aspartate_dv then
        high_aspartate_dv.hidden = true
        organ_dysfunction_header:add_link(high_aspartate_dv)
    end
    if n179_code then
        organ_dysfunction_header:add_link(n179_code)
        eods = eods + 1
    end
    if j810_code then
        organ_dysfunction_header:add_link(j810_code)
        eods = eods + 1
    end
    if i674_code then
        organ_dysfunction_header:add_link(i674_code)
        eods = eods + 1
    end
    if encephalopathy then
        organ_dysfunction_header:add_link(encephalopathy)
        eods = eods + 1
    end
    if aortic_dissection then
        organ_dysfunction_header:add_link(aortic_dissection)
        eods = eods + 1
    end
    if glasgow_coma_score_dv or altered then
        if glasgow_coma_score_dv then
            organ_dysfunction_header:add_link(glasgow_coma_score_dv)
        end
        if altered then
            organ_dysfunction_header:add_link(altered)
        end
        eods = eods + 1
    end
    if heart_failure then
        organ_dysfunction_header:add_link(heart_failure)
        eods = eods + 1
    end
    if r079_code then
        organ_dysfunction_header:add_link(r079_code)
        eods = eods + 1
    end
    if not g40_code and r569_code then
        organ_dysfunction_header:add_link(r569_code)
        eods = eods + 1
    end
    if i21_codes then
        organ_dysfunction_header:add_link(i21_codes)
        eods = eods + 1
    end
    if k72_codes then
        organ_dysfunction_header:add_link(k72_codes)
        eods = eods + 1
    end
    if d65_code then
        organ_dysfunction_header:add_link(d65_code)
        eods = eods + 1
    end
    if j960_codes then
        organ_dysfunction_header:add_link(j960_codes)
        eods = eods + 1
    end
    if serum_lactate_dv then
        organ_dysfunction_header:add_link(serum_lactate_dv)
        eods = eods + 1
    end
    if r410_code then
        organ_dysfunction_header:add_link(r410_code)
        eods = eods + 1
    end
    if i639_code then
        organ_dysfunction_header:add_link(i639_code)
        eods = eods + 1
    end
    if i61_codes then
        organ_dysfunction_header:add_link(i61_codes)
        eods = eods + 1
    end
    if i62_codes then
        organ_dysfunction_header:add_link(i62_codes)
        eods = eods + 1
    end


    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if i160_code and i161_code then
        -- 1
        documented_dx_header:add_link(i160_code)
        documented_dx_header:add_link(i161_code)
        if not bp_multi_dv[1][1] and not bp_multi_dv[2][1] then
            non_linked_greater_values()
        end
        Result.subtitle = "Hypertensive Crisis Conflicting Dx Codes"
        Result.passed = true

    elseif subtitle == "Unspecified Hypertensive Crisis Dx" and (i160_code or i161_code) then
        -- 2.1
        if i160_code then
            i160_code.link_text = "Autoresolved Code - " .. i160_code.link_text
            documented_dx_header:add_link(i160_code)
        end
        if i161_code then
            i161_code.link_text = "Autoresolved Code - " .. i161_code.link_text
            documented_dx_header:add_link(i161_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif i169_code and (bp_multi_dv[1][1] or bp_multi_dv[2][1]) and not i160_code and not i161_code then
        -- 2.0
        documented_dx_header:add_link(i169_code)
        Result.subtitle = "Unspecified Hypertensive Crisis Dx"
        Result.passed = true

    elseif subtitle == "Unspecified Hypertensive Crisis Dx Possibly Lacking Blood Pressure Criteria" and (sbp_dv or dbp_dv) then
        -- 3.1
        vital_signs_intake_header:add_link(sbp_dv)
        vital_signs_intake_header:add_link(dbp_dv)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif i169_code and not sbp_dv and not dbp_dv then
        -- 3
        documented_dx_header:add_link(i169_code)
        documented_dx_header:add_text_link("Possible No Blood Pressure Values Meeting Criteria, Please Review")
        Result.subtitle = "Unspecified Hypertensive Crisis Dx Possibly Lacking Blood Pressure Criteria"
        Result.passed = true

    elseif subtitle == "Possible Hypertensive Emergency" and i161_code then
        -- 4.1
        if i161_code then
            i161_code.link_text = "Autoresolved Code - " .. i161_code.link_text
            documented_dx_header:add_link(i161_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        i161_code and
        (
            accelerated_hyper_abs or
            malignant_hyper_abs or
            (
                bp_multi_dv[1][1] and #bp_multi_dv[1] > 3
            ) or
            (
                bp_multi_dv[2][1] and #bp_multi_dv[2] > 3
            )
        ) and
        eods > 0 and
        (
            antianginal_iv_med or
            beta_blocker_iv_med or
            calcium_channel_iv_med or
            hydralazine_iv_med or
            nitroglycerin_iv_med or
            sodium_nitroprusside_iv_med
        ) and
        not permissive_hypertension_abs
    then
        -- 4
        clinical_evidence_header:add_link(i160_code)
        treatment_and_monitoring_header:add_link(antianginal_iv_med)
        treatment_and_monitoring_header:add_link(beta_blocker_iv_med)
        treatment_and_monitoring_header:add_link(calcium_channel_iv_med)
        treatment_and_monitoring_header:add_link(hydralazine_iv_med)
        treatment_and_monitoring_header:add_link(nitroglycerin_iv_med)
        treatment_and_monitoring_header:add_link(sodium_nitroprusside_iv_med)
        Result.subtitle = "Possible Hypertensive Emergency"
        Result.passed = true


    elseif subtitle == "Possible Hypertensive Crisis" and (i160_code or i161_code) then
        -- 5.1
        if i160_code then
            i160_code.link_text = "Autoresolved Code - " .. i160_code.link_text
            documented_dx_header:add_link(i160_code)
        end
        if i161_code then
            i161_code.link_text = "Autoresolved Code - " .. i161_code.link_text
            documented_dx_header:add_link(i161_code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        not i160_code and
        not i161_code and
        (
            accelerated_hyper_abs or
            malignant_hyper_abs or
            (bp_multi_dv[1][1] and #bp_multi_dv[1] > 1) or
            (bp_multi_dv[2][1] and #bp_multi_dv[2] > 1)
        )
    then
        -- 5
        if not bp_multi_dv[1][1] and not bp_multi_dv[2][1] then
            non_linked_greater_values()
        end
        Result.subtitle = "Possible Hypertensive Crisis"
        Result.passed = true

    elseif subtitle == "Hypertensive Emergency Dx Possibly Lacking Supporting Evidence" and (eods > 0 and (sbp_dv or dbp_dv)) then
        -- 6.1
        vital_signs_intake_header:add_link(sbp_dv)
        vital_signs_intake_header:add_link(dbp_dv)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif i161_code and (eods == 0 or (not sbp_dv and not dbp_dv)) then
        -- 6
        documented_dx_header:add_link(i161_code)
        if eods == 0 then
            documented_dx_header:add_text_link("Possible No End Organ Damage Criteria found please review")
        end
        if not sbp_dv and not dbp_dv then
            documented_dx_header:add_text_link("Possible No Blood Pressure Values Meeting Criteria, Please Review")
        end
        Result.subtitle = "Hypertensive Emergency Dx Possibly Lacking Supporting Evidence"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Clinical Evidence
            clinical_evidence_header:add_link(accelerated_hyper_abs)
            clinical_evidence_header:add_code_link("R51.9", "Headache")
            clinical_evidence_header:add_abstraction_link("HEART_PALPITATIONS", "Heart Palpitations")
            clinical_evidence_header:add_code_link("R42", "Lightheadedness")
            clinical_evidence_header:add_link(malignant_hyper_abs)
            clinical_evidence_header:add_code_links({ "R11.0", "R11.10", "R11.2" }, "Nausea and Vomiting")
            clinical_evidence_header:add_abstraction_link("RESOLVING_TROPONINS", "Resolving Troponins")
            clinical_evidence_header:add_abstraction_link("SHORTNESS_OF_BREATH", "Shortness of Breath")
            clinical_evidence_header:add_code_prefix_link("F15%.", "Stimulant Abuse")
            clinical_evidence_header:add_code_link("E05.90", "Thyrotoxicosis")
            clinical_evidence_header:add_abstraction_link("ELEVATED_TROPONINS", "Troponemia")

            -- Labs
            laboratory_studies_header:add_discrete_value_one_of_link(dv_ts_amphetamine, "Drug/Tox Screen: Amphetamine Screen Urine")
            laboratory_studies_header:add_discrete_value_one_of_link(dv_ts_cocaine, "Drug/Tox Screen: Cocaine Screen Urine")

            -- Meds
            treatment_and_monitoring_header:add_medication_link("Antianginal Medication", "Antianginal Medication")
            treatment_and_monitoring_header:add_abstraction_link("ANTIANGINAL_MEDICATION", "Antianginal Medication")
            treatment_and_monitoring_header:add_medication_link("Beta Blocker", "Beta Blocker")
            treatment_and_monitoring_header:add_abstraction_link("BETA_BLOCKER", "Beta Blocker")
            treatment_and_monitoring_header:add_medication_link("Calcium Channel Blockers", "Calcium Channel Blockers")
            treatment_and_monitoring_header:add_abstraction_link("CALCIUM_CHANNEL_BLOCKER", "Calcium Channel Blockers")
            treatment_and_monitoring_header:add_medication_link("Hydralazine", "Hydralazine")
            treatment_and_monitoring_header:add_abstraction_link("HYDRALAZINE", "Hydralazine")
            treatment_and_monitoring_header:add_medication_link("Nitroglycerin", "Nitroglycerin")
            treatment_and_monitoring_header:add_abstraction_link("NITROGLYCERIN", "Nitroglycerin")
            treatment_and_monitoring_header:add_medication_link("Sodium Nitroprusside", "Sodium Nitroprusside")
            treatment_and_monitoring_header:add_abstraction_link("NITROPRUSSIDE", "Sodium Nitroprusside")

            -- Vitals Subheadings
            vital_signs_intake_header:add_abstraction_link_with_value("HIGH_SYSTOLIC_BLOOD_PRESSURE", "SBP")
            vital_signs_intake_header:add_abstraction_link_with_value("HIGH_DIASTOLIC_BLOOD_PRESSURE", "DBP")
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

