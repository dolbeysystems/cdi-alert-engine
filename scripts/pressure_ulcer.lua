---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Pressure Ulcer
---
--- This script checks an account to see if it matches the criteria for a pressure ulcer alert.
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
local dv_braden_risk_assessment_score = { "3.5 Braden Scale Total Points" }
local calc_braden_risk_assessment_score1 = function(dv_, num) return num < 12 end
local dv_pressure_injury_stage = { "" }
local calc_pressure_injury_stage1 = function(dv_, num) return num >= 3 end



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
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 2)
    local wound_care_header = headers.make_header_builder("Wound Care Note", 3)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 4)

    local function compile_links()
        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, wound_care_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end


    --------------------------------------------------------------------------------
    --- Alert Variables 
    --------------------------------------------------------------------------------
    local caution_code_doc = {
        "Conference Note Wound/Skin/Ostomy Registered Nurse",
        "Progress Notes Burn/Wound Nursing Assistant",
        "Conference Note Burn/Wound Registered Nurse",
        "Consult Note Wound/Skin/Ostomy Registered Nurse",
        "Consult Follow-up Wound/Skin/Ostomy Registered Nurse",
        "Addendum Note Wound Registered Nurse",
        "Progress Notes Burn/Wound Registered Nurse",
        "Addendum Note Wound/Skin/Ostomy Registered Nurse",
        "Progress Notes Burn/Wound MA Student",
        "Result Encounter Note Wound Registered Nurse",
        "Addendum Note Burn/Wound Certified-MA",
        "Handoff Burn/Wound Registered Nurse",
        "Addendum Note Burn/Wound Registered Nurse",
        "Code Blue Burn/Wound Registered Nurse",
        "Addendum Note Burn/Wound Medical Assistant",
        "Wound Care Note",
        "Wound Care Progress Note",
        "Miscellaneous Wound Registered Nurse",
        "Wound/Skin/Ostomy Registered Nurse",
        "Nursing Shift Summary Wound/Skin/Ostomy Registered Nurse",
        "RN Care Note Wound Registered Nurse",
        "Progress Notes Wound Registered Nurse",
        "Progress Notes Wound/Skin/Ostomy Registered Nurse",
        "Progress Notes Burn/Wound Registered Nurse",
        "Progress Notes Burn/Wound Licensed Nurse",
        "Consult Note Wound/Skin/Ostomy Registered Nurse"
    }
    local unspec = 0



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Full Spec Codes
    local left_elbow_spec_codes = links.get_code_links {
        codes = { "L89.020", "L89.021", "L89.022", "L89.023", "L89.024", "L89.026" },
        text = "Autoresolved Code - Pressure Ulcer of Elbow Stage Specified Left"
    }
    local right_elbow_spec_codes = links.get_code_links {
        codes = { "L89.010", "L89.011", "L89.012", "L89.013", "L89.014", "L89.016" },
        text = "Autoresolved Code - Pressure Ulcer of Elbow Stage Specified Right"
    }
    local back_right_upper_spec_codes = links.get_code_links {
        codes = { "L89.110", "L89.111", "L89.112", "L89.113", "L89.114", "L89.116" },
        text = "Autoresolved Code - Pressure Ulcer Fully Specified Portions of Back Right Upper"
    }
    local back_left_upper_spec_codes = links.get_code_links {
        codes = { "L89.120", "L89.121", "L89.122", "L89.123", "L89.124", "L89.126" },
        text = "Autoresolved Code - Pressure Ulcer Fully Specified Portions of Back Left Upper"
    }
    local back_right_lower_spec_codes = links.get_code_links {
        codes = { "L89.130", "L89.131", "L89.132", "L89.133", "L89.134", "L89.136" },
        text = "Autoresolved Code - Pressure Ulcer Fully Specified Portions of Back Right Lower"
    }
    local back_left_lower_spec_codes = links.get_code_links {
        codes = { "L89.140", "L89.141", "L89.142", "L89.143", "L89.144", "L89.146" },
        text = "Autoresolved Code - Pressure Ulcer Fully Specified Portions of Back Left Lower"
    }
    local back_sacral_region_spec_codes = links.get_code_links {
        codes = { "L89.150", "L89.151", "L89.152", "L89.153", "L89.154", "L89.156" },
        text = "Autoresolved Code - Pressure Ulcer Fully Specified Portions of Back Sacral Region"
    }
    local back_buttock_hip_contiguous_spec_codes = links.get_code_links {
        codes = { "L89.41", "L89.42", "L89.43", "L89.44", "L89.45", "L86.46" },
        text = "Autoresolved Code - Pressure Ulcer Fully Specified Contiguous Site of Back, Buttock and Hip"
    }
    local right_hip_spec_codes = links.get_code_links {
        codes = { "L89.210", "L89.211", "L89.212", "L89.213", "L89.214", "L89.216" },
        text = "Autoresolved Code - Pressure Ulcer Fully Specified Contiguous Site of Back, Buttock and Hip"
    }
    local left_hip_spec_codes = links.get_code_links {
        codes = { "L89.220", "L89.221", "L89.222", "L89.223", "L89.224", "L89.226" },
        text = "Autoresolved Code - Pressure Ulcer Fully Specified Contiguous Site of Back, Buttock and Hip"
    }
    local left_butt_back_spec_codes = links.get_code_links {
        codes = { "L89.320", "L89.321", "L89.322", "L89.323", "L89.324", "L89.326" },
        text = "Autoresolved Code - Pressure Ulcer Fully Specified Left Buttock Code"
    }
    local right_butt_back_spec_codes = links.get_code_links {
        codes = { "L89.310", "L89.311", "L89.312", "L89.313", "L89.314", "L89.316" },
        text = "Autoresolved Code - Pressure Ulcer Fully Specified Right Buttock Code"
    }
    local right_ankle_spec_codes = links.get_code_links {
        codes = { "L89.510", "L89.511", "L89.512", "L89.513", "L89.514", "L89.516" },
        text = "Autoresolved Code - Pressure Ulcer Fully Specified Right Ankle Code"
    }
    local left_ankle_spec_codes = links.get_code_links {
        codes = { "L89.520", "L89.521", "L89.522", "L89.523", "L89.524", "L89.526" },
        text = "Autoresolved Code - Pressure Ulcer Fully Specified Left Ankle Code"
    }
    local left_heel_spec_codes = links.get_code_links {
        codes = { "L89.620", "L89.621", "L89.622", "L89.623", "L89.624", "L89.626" },
        text = "Autoresolved Code - Pressure Ulcer Fully Specified Left Heel Code"
    }
    local right_heel_spec_codes = links.get_code_links {
        codes = { "L89.610", "L89.611", "L89.612", "L89.613", "L89.614", "L89.616" },
        text = "Autoresolved Code - Pressure Ulcer Fully Specified Right Heel Code"
    }
    local head_spec_codes = links.get_code_links {
        codes = { "L89.810", "L89.811", "L89.812", "L89.813", "L89.814", "L89.816" },
        text = "Autoresolved Code - Pressure Ulcer Fully Specified Head Code"
    }
    local other_site_spec_codes = links.get_code_links {
        codes = { "L89.890", "L89.891", "L89.892", "L89.893", "L89.894", "L89.896" },
        text = "Autoresolved Code - Pressure Ulcer Fully Specified Other Site Code"
    }
    local unspec_site_full_spec_codes = links.get_code_links {
        codes = { "L89.91", "L89.92", "L89.93", "L89.94", "L89.95", "L89.96" },
        text = "Autoresolved Code - Pressure Ulcer Unspecified Site Fully Specified Stage Code"
    }
    local stage_34_pu_codes = links.get_code_links {
        codes = {
            "L89.013", "L89.014", "L89.113", "L89.114", "L89.123", "L89.124", "L89.133", "L89.134", "L89.023", "L89.024",
            "L89.143", "L89.144", "L89.153", "L89.154", "L89.203", "L89.204", "L89.213", "L89.214", "L89.223", "L89.224",
            "L89.313", "L89.314", "L89.323", "L89.324", "L89.43", "L89.44", "L89.513", "L89.514", "L89.523", "L89.524",
            "L89.613", "L89.614", "L89.623", "L89.624", "L89.813", "L89.814", "L89.893", "L89.894"
        },
        text = "Autoresolved Code - Fully Specified Pressure Ulcer Codes of Stage 3 or Stage 4"
    }

    -- Alert Trigger
    local l89009_code = links.get_code_link {
        code = "L89.009",
        text = "Pressure Ulcer of Elbow present, but Side and Stage Unspecified"
    }
    local elbow_stage_unspec_codes = links.get_code_links {
        codes = { "L89.001", "L89.002", "L89.003", "L89.004", "L89.006" },
        text = "Pressure Ulcer of Elbow Stage Specified, but Unspecified Side"
    }
    local l89019_code = links.get_code_link {
        code = "L89.019",
        text = "Pressure Ulcer of Right Elbow, Stage Unspecified"
    }
    local l89029_code = links.get_code_link {
        code = "L89.029",
        text = "Pressure Ulcer of Left Elbow, Stage Unspecified"
    }
    local back_stage_unspec_codes = links.get_code_links {
        codes = { "L89.100", "L89.101", "L89.102", "L89.103", "L89.104", "L89.106" },
        text = "Pressure Ulcer of Unspecified Portion of the Back, but Stage Specified"
    }
    local l89119_code = links.get_code_link {
        code = "L89.119",
        text = "Pressure Ulcer of Right Upper Back, but Stage Unspecified"
    }
    local l89129_code = links.get_code_link {
        code = "L89.129",
        text = "Pressure Ulcer of Left Upper Back, but Stage Unspecified"
    }
    local l89139_code = links.get_code_link {
        code = "L89.139",
        text = "Pressure Ulcer of Right Upper Back, but Stage Unspecified"
    }
    local l89149_code = links.get_code_link {
        code = "L89.149",
        text = "Pressure Ulcer of Left Lower Back, but Stage Unspecified"
    }
    local l89159_code = links.get_code_link {
        code = "L89.159",
        text = "Pressure Ulcer of Sacral Region, with Stage Unspecified"
    }
    local hip_side_unspec_codes = links.get_code_links {
        codes = { "L89.200", "L89.201", "L89.202", "L89.203", "L89.204", "L89.206" },
        text = "Pressure Ulcer of the Hip Side Unspecified and Stage Specified"
    }
    local l89209_code = links.get_code_link {
        code = "L89.209",
        text = "Pressure Ulcer of Unspecified Hip and Unspecified Stage"
    }
    local l89219_code = links.get_code_link {
        code = "L89.219",
        text = "Pressure Ulcer of Sacral Region, with Stage Unspecified"
    }
    local l89229_code = links.get_code_link {
        code = "L89.229",
        text = "Pressure Ulcer of Left Hip, but Stage is Unspecified"
    }
    local buttock_side_unspec_codes = links.get_code_links {
        codes = { "L89.300", "L89.301", "L89.302", "L89.303", "L89.304", "L89.306" },
        text = "Pressure Ulcer of Unspectified Buttock Side, but Stage is Present"
    }
    local l89309_code = links.get_code_link {
        code = "L89.309",
        text = "Pressure Ulcer of Unspecified Buttock Side and Unspecified Stage"
    }
    local l89319_code = links.get_code_link {
        code = "L89.319",
        text = "Pressure Ulcer of Right Buttock, but Stage Unspecified"
    }
    local l89329_code = links.get_code_link {
        code = "L89.329",
        text = "Pressure Ulcer of Left Buttock, but Stage Unspecified"
    }
    local ankle_unspec_codes = links.get_code_links {
        codes = { "L89.500", "L89.501", "L89.502", "L89.503", "L89.504", "L89.506" },
        text = "Pressure Ulcer of Unspecified Ankle with Stage Specified"
    }
    local l8940_code = links.get_code_link {
        code = "L89.40",
        text = "Pressure Ulcer of Contiguous Site of Back, Buttock and Hip with Unspecified Stage"
    }
    local l89509_code = links.get_code_link {
        code = "L89.509",
        text = "Pressure Ulcer of Unspecified Ankle and Unspecified Stage"
    }
    local l89519_code = links.get_code_link {
        code = "L89.519",
        text = "Pressure Ulcer of Right Ankle with Unspecified Stage"
    }
    local l89529_code = links.get_code_link {
        code = "L89.529",
        text = "Pressure Ulcer of Left Ankle with Unspecified Stage"
    }
    local heel_unspec_codes = links.get_code_links {
        codes = { "L89.600", "L89.601", "L89.602", "L89.603", "L89.604", "L89.606" },
        text = "Pressure Ulcer of Unspectified Heel Side with Specified Stage"
    }
    local l89609_code = links.get_code_link {
        code = "L89.609",
        text = "Pressure Ulcer of Unspecified Heel Side and Unspecified Stage"
    }
    local l89619_code = links.get_code_link {
        code = "L89.619",
        text = "Pressure Ulcer of Right Heel with Unspecified Stage"
    }
    local l89629_code = links.get_code_link {
        code = "L89.629",
        text = "Pressure Ulcer of Left Heel with Unspecified Stage"
    }
    local l89819_code = links.get_code_link {
        code = "L89.819",
        text = "Pressure Ulcer of Head with Unspecified Stage"
    }
    local l89899_code = links.get_code_link {
        code = "L89.899",
        text = "Pressure Ulcer of Other Site with Unspecified Stage"
    }
    local l8990_code = links.get_code_link {
        code = "L89.90",
        text = "Pressure Ulcer of Unspecified Site with Unspecified Stage"
    }

    -- Clinical Evidence
    local pressure_injury_stage_dv = links.get_discrete_value_link {
        discreteValueNames = dv_pressure_injury_stage,
        text = "Pressure Injury Stage",
        predicate = calc_pressure_injury_stage1
    }

    -- Determine if Multiple Unspecified Codes
    if l89009_code and not left_elbow_spec_codes and not right_elbow_spec_codes then unspec = unspec + 1 end
    if elbow_stage_unspec_codes and not left_elbow_spec_codes and not right_elbow_spec_codes then unspec = unspec + 1 end
    if l89019_code and not right_elbow_spec_codes then unspec = unspec + 1 end
    if l89029_code and not left_elbow_spec_codes then unspec = unspec + 1 end
    if l89119_code and not back_right_upper_spec_codes then unspec = unspec + 1 end
    if l89129_code and not back_left_upper_spec_codes then unspec = unspec + 1 end
    if l89139_code and not back_right_lower_spec_codes and not back_buttock_hip_contiguous_spec_codes then unspec = unspec + 1 end
    if l89149_code and not back_left_lower_spec_codes and not back_buttock_hip_contiguous_spec_codes then unspec = unspec + 1 end
    if l89159_code and not back_sacral_region_spec_codes and not back_buttock_hip_contiguous_spec_codes then unspec = unspec + 1 end
    if hip_side_unspec_codes and not right_hip_spec_codes and not left_hip_spec_codes and not back_buttock_hip_contiguous_spec_codes then
        unspec = unspec + 1
    end
    if l89209_code and not right_hip_spec_codes and not left_hip_spec_codes and not back_buttock_hip_contiguous_spec_codes then
        unspec = unspec + 1
    end
    if l89219_code and not right_hip_spec_codes and not back_buttock_hip_contiguous_spec_codes then unspec = unspec + 1 end
    if l89229_code and not left_hip_spec_codes and not back_buttock_hip_contiguous_spec_codes then unspec = unspec + 1 end
    if
        buttock_side_unspec_codes and
        not right_butt_back_spec_codes and
        not left_butt_back_spec_codes and
        not back_buttock_hip_contiguous_spec_codes
    then
        unspec = unspec + 1
    end
    if
        l89309_code and
        not right_butt_back_spec_codes and
        not left_butt_back_spec_codes and
        not back_buttock_hip_contiguous_spec_codes
    then
        unspec = unspec + 1
    end
    if l89319_code and not right_butt_back_spec_codes and not back_buttock_hip_contiguous_spec_codes then unspec = unspec + 1 end
    if l89329_code and not left_butt_back_spec_codes and not back_buttock_hip_contiguous_spec_codes then unspec = unspec + 1 end
    if l8940_code and not back_buttock_hip_contiguous_spec_codes then unspec = unspec + 1 end
    if ankle_unspec_codes and not right_ankle_spec_codes and not left_ankle_spec_codes then unspec = unspec + 1 end
    if l89509_code and not right_ankle_spec_codes and not left_ankle_spec_codes then unspec = unspec + 1 end
    if l89519_code and not right_ankle_spec_codes then unspec = unspec + 1 end
    if l89529_code and not left_ankle_spec_codes then unspec = unspec + 1 end
    if heel_unspec_codes and not right_heel_spec_codes and not left_heel_spec_codes then unspec = unspec + 1 end
    if l89609_code and not right_heel_spec_codes and not left_heel_spec_codes then unspec = unspec + 1 end
    if l89619_code and not right_heel_spec_codes then unspec = unspec + 1 end
    if l89629_code and not left_heel_spec_codes then unspec = unspec + 1 end
    if l89819_code and not head_spec_codes then unspec = unspec + 1 end
    if l89899_code and not other_site_spec_codes then unspec = unspec + 1 end
    if l8990_code and not unspec_site_full_spec_codes then unspec = unspec + 1 end



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if unspec >= 2 then
        -- 1
        if l89009_code and not left_elbow_spec_codes and not right_elbow_spec_codes then
            documented_dx_header:add_link(l89009_code)
        end
        if elbow_stage_unspec_codes and not left_elbow_spec_codes and not right_elbow_spec_codes then
            documented_dx_header:add_link(elbow_stage_unspec_codes)
        end
        if l89019_code and not right_elbow_spec_codes then
            documented_dx_header:add_link(l89019_code)
        end
        if l89029_code and not left_elbow_spec_codes then
            documented_dx_header:add_link(l89029_code)
        end
        if
            back_stage_unspec_codes and
            not back_right_upper_spec_codes and
            not back_left_upper_spec_codes and
            not back_right_lower_spec_codes and
            not back_left_lower_spec_codes and
            not back_sacral_region_spec_codes and
            not back_buttock_hip_contiguous_spec_codes
        then
            documented_dx_header:add_link(back_stage_unspec_codes)
        end
        if l89119_code and not back_right_upper_spec_codes then documented_dx_header:add_link(l89119_code) end
        if l89129_code and not back_left_upper_spec_codes then documented_dx_header:add_link(l89129_code) end
        if l89139_code and not back_right_lower_spec_codes and not back_buttock_hip_contiguous_spec_codes then
            documented_dx_header:add_link(l89139_code)
        end
        if l89149_code and not back_left_lower_spec_codes and not back_buttock_hip_contiguous_spec_codes then
            documented_dx_header:add_link(l89149_code)
        end
        if l89159_code and not back_sacral_region_spec_codes and not back_buttock_hip_contiguous_spec_codes then
            documented_dx_header:add_link(l89159_code)
        end
        if hip_side_unspec_codes and not right_hip_spec_codes and not left_hip_spec_codes and not back_buttock_hip_contiguous_spec_codes then
            documented_dx_header:add_link(hip_side_unspec_codes)
        end
        if l89209_code and not right_hip_spec_codes and not left_hip_spec_codes and not back_buttock_hip_contiguous_spec_codes then
            documented_dx_header:add_link(l89209_code)
        end
        if l89219_code and not right_hip_spec_codes and not back_buttock_hip_contiguous_spec_codes then
            documented_dx_header:add_link(l89219_code)
        end
        if l89229_code and not left_hip_spec_codes and not back_buttock_hip_contiguous_spec_codes then
            documented_dx_header:add_link(l89229_code)
        end
        if
            buttock_side_unspec_codes and
            not right_butt_back_spec_codes and
            not left_butt_back_spec_codes and
            not back_buttock_hip_contiguous_spec_codes
        then
            documented_dx_header:add_link(buttock_side_unspec_codes)
        end
        if
            l89309_code and
            not right_butt_back_spec_codes and
            not left_butt_back_spec_codes and
            not back_buttock_hip_contiguous_spec_codes
        then
            documented_dx_header:add_link(l89309_code)
        end
        if l89319_code and not right_butt_back_spec_codes and not back_buttock_hip_contiguous_spec_codes then
            documented_dx_header:add_link(l89319_code)
        end
        if l89329_code and not left_butt_back_spec_codes and not back_buttock_hip_contiguous_spec_codes then
            documented_dx_header:add_link(l89329_code)
        end
        if l8940_code and not back_buttock_hip_contiguous_spec_codes then documented_dx_header:add_link(l8940_code) end
        if ankle_unspec_codes and not right_ankle_spec_codes and not left_ankle_spec_codes then
            documented_dx_header:add_link(ankle_unspec_codes)
        end
        if l89509_code and not right_ankle_spec_codes and not left_ankle_spec_codes then
            documented_dx_header:add_link(l89509_code)
        end
        if l89519_code and not right_ankle_spec_codes then documented_dx_header:add_link(l89519_code) end
        if l89529_code and not left_ankle_spec_codes then documented_dx_header:add_link(l89529_code) end
        if heel_unspec_codes and not right_heel_spec_codes and not left_heel_spec_codes then
            documented_dx_header:add_link(heel_unspec_codes)
        end
        if l89609_code and not right_heel_spec_codes and not left_heel_spec_codes then
            documented_dx_header:add_link(l89609_code)
        end
        if l89619_code and not right_heel_spec_codes then documented_dx_header:add_link(l89619_code) end
        if l89629_code and not left_heel_spec_codes then documented_dx_header:add_link(l89629_code) end
        if l89819_code and not head_spec_codes then documented_dx_header:add_link(l89819_code) end
        if l89899_code and not other_site_spec_codes then documented_dx_header:add_link(l89899_code) end
        if l8990_code and not unspec_site_full_spec_codes then documented_dx_header:add_link(l8990_code) end
        Result.subtitle = "Multiple Unspecifed Pressure Ulcer Codes Present"
        Result.passed = true
        if existing_alert and existing_alert.validated then
            Result.validated = false
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
        end

    elseif subtitle == "Pressure Ulcer of Elbow Unspecified Side with Stage Present" and (left_elbow_spec_codes or right_elbow_spec_codes) then
        -- 2.1
        if left_elbow_spec_codes then documented_dx_header:add_link(left_elbow_spec_codes) end
        if right_elbow_spec_codes then documented_dx_header:add_link(right_elbow_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89009_code and not left_elbow_spec_codes and not right_elbow_spec_codes then
        -- 2.0
        documented_dx_header:add_link(l89009_code)
        Result.subtitle = "Pressure Ulcer of Elbow Unspecified Side with Stage Present"
        Result.passed = true

    elseif
        subtitle == "Pressure Ulcer of Elbow Stage Specified, but Unspecified Side Present" and
        (left_elbow_spec_codes or right_elbow_spec_codes)
    then
        -- 3.1
        if left_elbow_spec_codes then documented_dx_header:add_link(left_elbow_spec_codes) end
        if right_elbow_spec_codes then documented_dx_header:add_link(right_elbow_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif elbow_stage_unspec_codes and not left_elbow_spec_codes and not right_elbow_spec_codes then
        -- 3.0
        documented_dx_header:add_link(elbow_stage_unspec_codes)
        Result.subtitle = "Pressure Ulcer of Elbow Stage Specified, but Unspecified Side Present"
        Result.passed = true

    elseif subtitle == "Pressure Ulcer of Right Elbow, Stage Unspecified Present" and right_elbow_spec_codes then
        -- 4.1
        documented_dx_header:add_link(right_elbow_spec_codes)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89019_code and not right_elbow_spec_codes then
        -- 4.0
        documented_dx_header:add_link(l89019_code)
        Result.subtitle = "Pressure Ulcer of Right Elbow, Stage Unspecified Present"
        Result.passed = true

    elseif subtitle == "Pressure Ulcer of Left Elbow, with Stage Unspecified Present" and left_elbow_spec_codes then
        -- 5.1
        documented_dx_header:add_link(left_elbow_spec_codes)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89029_code and not left_elbow_spec_codes then
        -- 5.0
        documented_dx_header:add_link(l89029_code)
        Result.subtitle = "Pressure Ulcer of Left Elbow, with Stage Unspecified Present"
        Result.passed = true

    elseif
        subtitle == "Pressure Ulcer of Unspecified Portion of Back, with Stage Specified Present" and
        (
            back_right_upper_spec_codes or
            back_left_upper_spec_codes or
            back_right_lower_spec_codes or
            back_left_lower_spec_codes or
            back_sacral_region_spec_codes or
            back_buttock_hip_contiguous_spec_codes
        )
    then
        -- 6.1
        if back_right_upper_spec_codes then documented_dx_header:add_link(back_right_upper_spec_codes) end
        if back_left_upper_spec_codes then documented_dx_header:add_link(back_left_upper_spec_codes) end
        if back_right_lower_spec_codes then documented_dx_header:add_link(back_right_lower_spec_codes) end
        if back_left_lower_spec_codes then documented_dx_header:add_link(back_left_lower_spec_codes) end
        if back_sacral_region_spec_codes then documented_dx_header:add_link(back_sacral_region_spec_codes) end
        if back_buttock_hip_contiguous_spec_codes then documented_dx_header:add_link(back_buttock_hip_contiguous_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif
        back_stage_unspec_codes and
        not back_right_upper_spec_codes and
        not back_left_upper_spec_codes and
        not back_right_lower_spec_codes and
        not back_left_lower_spec_codes and
        not back_sacral_region_spec_codes and
        not back_buttock_hip_contiguous_spec_codes
    then
        -- 6.0
        documented_dx_header:add_link(back_stage_unspec_codes)
        Result.subtitle = "Pressure Ulcer of Unspecified Portion of Back, with Stage Specified Present"
        Result.passed = true

    elseif subtitle == "Pressure Ulcer of Right Upper Back, with Stage Unspecified Present" and back_right_upper_spec_codes then
        -- 7.1
        documented_dx_header:add_link(back_right_upper_spec_codes)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89119_code and not back_right_upper_spec_codes then
        -- 7.0
        documented_dx_header:add_link(l89119_code)
        Result.subtitle = "Pressure Ulcer of Right Upper Back, with Stage Unspecified Present"
        Result.passed = true

    elseif subtitle == "Pressure Ulcer of Left Upper Back, with Stage Unspecified Present" and back_left_upper_spec_codes then
        -- 8.1
        documented_dx_header:add_link(back_left_upper_spec_codes)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89129_code and not back_left_upper_spec_codes then
        -- 8.0
        documented_dx_header:add_link(l89129_code)
        Result.subtitle = "Pressure Ulcer of Left Upper Back, with Stage Unspecified Present"
        Result.passed = true

    elseif
        subtitle == "Pressure Ulcer of Right Lower Back, with Stage Unspecified Present" and
        (back_right_lower_spec_codes or back_buttock_hip_contiguous_spec_codes)
    then
        -- 9.1
        if back_right_lower_spec_codes then documented_dx_header:add_link(back_right_lower_spec_codes) end
        if back_buttock_hip_contiguous_spec_codes then documented_dx_header:add_link(back_buttock_hip_contiguous_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89139_code and not back_right_lower_spec_codes and not back_buttock_hip_contiguous_spec_codes then
        -- 9.0
        documented_dx_header:add_link(l89139_code)
        Result.subtitle = "Pressure Ulcer of Right Lower Back, with Stage Unspecified Present"
        Result.passed = true

    elseif
        subtitle == "Pressure Ulcer of Left Lower Back, with Stage Unspecified Present" and
        (back_left_lower_spec_codes or back_buttock_hip_contiguous_spec_codes)
    then
        -- 10.1
        if back_left_lower_spec_codes then documented_dx_header:add_link(back_left_lower_spec_codes) end
        if back_buttock_hip_contiguous_spec_codes then documented_dx_header:add_link(back_buttock_hip_contiguous_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89149_code and not back_left_lower_spec_codes and not back_buttock_hip_contiguous_spec_codes then
        -- 10.0
        documented_dx_header:add_link(l89149_code)
        Result.subtitle = "Pressure Ulcer of Left Lower Back, with Stage Unspecified Present"
        Result.passed = true

    elseif
        subtitle == "Pressure Ulcer of Sacral Region, but Stage Unspecified Present" and
        (back_sacral_region_spec_codes or back_buttock_hip_contiguous_spec_codes)
    then
        -- 11.1
        if back_sacral_region_spec_codes then documented_dx_header:add_link(back_sacral_region_spec_codes) end
        if back_buttock_hip_contiguous_spec_codes then documented_dx_header:add_link(back_buttock_hip_contiguous_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89159_code and not back_sacral_region_spec_codes and not back_buttock_hip_contiguous_spec_codes then
        -- 11.0
        documented_dx_header:add_link(l89159_code)
        Result.subtitle = "Pressure Ulcer of Sacral Region, but Stage Unspecified Present"
        Result.passed = true

    elseif
        subtitle == "Pressure Ulcer of Unspecified Hip with Stage Present" and
        (right_hip_spec_codes or left_hip_spec_codes or back_buttock_hip_contiguous_spec_codes)
    then
        -- 12.1
        if right_hip_spec_codes then documented_dx_header:add_link(right_hip_spec_codes) end
        if left_hip_spec_codes then documented_dx_header:add_link(left_hip_spec_codes) end
        if back_buttock_hip_contiguous_spec_codes then documented_dx_header:add_link(back_buttock_hip_contiguous_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif hip_side_unspec_codes and not right_hip_spec_codes and not left_hip_spec_codes and not back_buttock_hip_contiguous_spec_codes then
        -- 12.0
        documented_dx_header:add_link(hip_side_unspec_codes)
        Result.subtitle = "Pressure Ulcer of Unspecified Hip with Stage Present"
        Result.passed = true

    elseif
        subtitle == "Pressure Ulcer of Unspecified Hip and Unspecified Stage Present" and
        (right_hip_spec_codes or left_hip_spec_codes or back_buttock_hip_contiguous_spec_codes)
    then
        -- 13.1
        if right_hip_spec_codes then documented_dx_header:add_link(right_hip_spec_codes) end
        if left_hip_spec_codes then documented_dx_header:add_link(left_hip_spec_codes) end
        if back_buttock_hip_contiguous_spec_codes then documented_dx_header:add_link(back_buttock_hip_contiguous_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89209_code and not right_hip_spec_codes and not left_hip_spec_codes and not back_buttock_hip_contiguous_spec_codes then
        -- 13.0
        documented_dx_header:add_link(l89209_code)
        Result.subtitle = "Pressure Ulcer of Unspecified Hip and Unspecified Stage Present"
        Result.passed = true

    elseif
        subtitle == "Pressure Ulcer of Right Hip, with Stage is Unspecified Present" and
        (right_hip_spec_codes or back_buttock_hip_contiguous_spec_codes)
    then
        -- 14.1
        if right_hip_spec_codes then documented_dx_header:add_link(right_hip_spec_codes) end
        if back_buttock_hip_contiguous_spec_codes then documented_dx_header:add_link(back_buttock_hip_contiguous_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89219_code and not right_hip_spec_codes and not back_buttock_hip_contiguous_spec_codes then
        -- 14.0
        documented_dx_header:add_link(l89219_code)
        Result.subtitle = "Pressure Ulcer of Right Hip, with Stage is Unspecified Present"
        Result.passed = true

    elseif
        subtitle == "Pressure Ulcer of Left Hip, with Stage is Unspecified Present" and
        (left_hip_spec_codes or back_buttock_hip_contiguous_spec_codes)
    then
        -- 15.1
        if left_hip_spec_codes then documented_dx_header:add_link(left_hip_spec_codes) end
        if back_buttock_hip_contiguous_spec_codes then documented_dx_header:add_link(back_buttock_hip_contiguous_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89229_code and not left_hip_spec_codes and not back_buttock_hip_contiguous_spec_codes then
        -- 15.0
        documented_dx_header:add_link(l89229_code)
        Result.subtitle = "Pressure Ulcer of Left Hip, with Stage is Unspecified Present"
        Result.passed = true

    elseif
        subtitle == "Pressure Ulcer of Unspecified Buttock Side Present, with Stage Present" and
        (right_butt_back_spec_codes or left_butt_back_spec_codes or back_buttock_hip_contiguous_spec_codes)
    then
        -- 16.1
        if left_butt_back_spec_codes then documented_dx_header:add_link(left_butt_back_spec_codes) end
        if right_butt_back_spec_codes then documented_dx_header:add_link(right_butt_back_spec_codes) end
        if back_buttock_hip_contiguous_spec_codes then documented_dx_header:add_link(back_buttock_hip_contiguous_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif buttock_side_unspec_codes and not left_butt_back_spec_codes and not right_butt_back_spec_codes and not back_buttock_hip_contiguous_spec_codes then
        -- 16.0
        documented_dx_header:add_link(buttock_side_unspec_codes)
        Result.subtitle = "Pressure Ulcer of Unspecified Buttock Side Present, with Stage Present"
        Result.passed = true

    elseif
        subtitle == "Pressure Ulcer of Unspecified Buttock Side and Unspecified Stage Present" and
        (right_butt_back_spec_codes or left_butt_back_spec_codes or back_buttock_hip_contiguous_spec_codes)
    then
        -- 17.1
        if left_butt_back_spec_codes then documented_dx_header:add_link(left_butt_back_spec_codes) end
        if right_butt_back_spec_codes then documented_dx_header:add_link(right_butt_back_spec_codes) end
        if back_buttock_hip_contiguous_spec_codes then documented_dx_header:add_link(back_buttock_hip_contiguous_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89309_code and not left_butt_back_spec_codes and not right_butt_back_spec_codes and not back_buttock_hip_contiguous_spec_codes then
        -- 17.0
        documented_dx_header:add_link(l89309_code)
        Result.subtitle = "Pressure Ulcer of Unspecified Buttock Side and Unspecified Stage Present"
        Result.passed = true

    elseif
        subtitle == "Pressure Ulcer of Right Buttock, with Stage Unspecified Present" and
        (right_butt_back_spec_codes or back_buttock_hip_contiguous_spec_codes)
    then
        -- 18.1
        if right_butt_back_spec_codes then documented_dx_header:add_link(right_butt_back_spec_codes) end
        if back_buttock_hip_contiguous_spec_codes then documented_dx_header:add_link(back_buttock_hip_contiguous_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89319_code and not right_butt_back_spec_codes and not back_buttock_hip_contiguous_spec_codes then
        -- 18.0
        documented_dx_header:add_link(l89319_code)
        Result.subtitle = "Pressure Ulcer of Right Buttock, with Stage Unspecified Present"
        Result.passed = true

    elseif
        subtitle == "Pressure Ulcer of Left Buttock, with Stage Unspecified Present" and
        (left_butt_back_spec_codes or back_buttock_hip_contiguous_spec_codes)
    then
        -- 19.1
        if left_butt_back_spec_codes then documented_dx_header:add_link(left_butt_back_spec_codes) end
        if back_buttock_hip_contiguous_spec_codes then documented_dx_header:add_link(back_buttock_hip_contiguous_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89329_code and not left_butt_back_spec_codes and not back_buttock_hip_contiguous_spec_codes then
        -- 19.0
        documented_dx_header:add_link(l89329_code)
        Result.subtitle = "Pressure Ulcer of Left Buttock, with Stage Unspecified Present"
        Result.passed = true

    elseif
        subtitle == "Pressure Ulcer of Contiguous Site of Back, Buttock and Hip with Unspecified Stage Present" and
        back_buttock_hip_contiguous_spec_codes
    then
        -- 20.1
        documented_dx_header:add_link(back_buttock_hip_contiguous_spec_codes)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l8940_code and not back_buttock_hip_contiguous_spec_codes then
        -- 20.0
        documented_dx_header:add_link(l8940_code)
        Result.subtitle = "Pressure Ulcer of Contiguous Site of Back, Buttock and Hip with Unspecified Stage Present"
        Result.passed = true

    elseif
        subtitle == "Pressure Ulcer of Unspecified Ankle with Stage Specified Present" and
        (right_ankle_spec_codes or left_ankle_spec_codes)
    then
        -- 21.1
        if right_ankle_spec_codes then documented_dx_header:add_link(right_ankle_spec_codes) end
        if left_ankle_spec_codes then documented_dx_header:add_link(left_ankle_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif ankle_unspec_codes and not right_ankle_spec_codes and not left_ankle_spec_codes then
        -- 21.0
        documented_dx_header:add_link(ankle_unspec_codes)
        Result.subtitle = "Pressure Ulcer of Unspecified Ankle with Stage Specified Present"
        Result.passed = true

    elseif
        subtitle == "Pressure Ulcer of Unspecified Ankle and Unspecified Stage Present" and
        (right_ankle_spec_codes or left_ankle_spec_codes)
    then
        -- 22.1
        if right_ankle_spec_codes then documented_dx_header:add_link(right_ankle_spec_codes) end
        if left_ankle_spec_codes then documented_dx_header:add_link(left_ankle_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89509_code and not right_ankle_spec_codes and not left_ankle_spec_codes then
        -- 22.0
        documented_dx_header:add_link(l89509_code)
        Result.subtitle = "Pressure Ulcer of Unspecified Ankle and Unspecified Stage Present"
        Result.passed = true

    elseif
        subtitle == "Pressure Ulcer of Right Ankle with Unspecified Stage Present" and
        right_ankle_spec_codes
    then
        -- 23.1
        if right_ankle_spec_codes then documented_dx_header:add_link(right_ankle_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89519_code and not right_ankle_spec_codes then
        -- 23.0
        documented_dx_header:add_link(l89519_code)
        Result.subtitle = "Pressure Ulcer of Right Ankle with Unspecified Stage Present"
        Result.passed = true

    elseif
        subtitle == "Pressure Ulcer of Left Ankle with Unspecified Stage Present" and
        left_ankle_spec_codes
    then
        -- 24.1
        if left_ankle_spec_codes then documented_dx_header:add_link(left_ankle_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89529_code and not left_ankle_spec_codes then
        -- 24.0
        documented_dx_header:add_link(l89529_code)
        Result.subtitle = "Pressure Ulcer of Left Ankle with Unspecified Stage Present"
        Result.passed = true

    elseif subtitle == "Pressure Ulcer of Unspecified Heel Side with Specified Stage Present" and (right_heel_spec_codes or left_heel_spec_codes) then
        -- 25.1
        if right_heel_spec_codes then documented_dx_header:add_link(right_heel_spec_codes) end
        if left_heel_spec_codes then documented_dx_header:add_link(left_heel_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif heel_unspec_codes and not right_heel_spec_codes and not left_heel_spec_codes then
        -- 25.0
        documented_dx_header:add_link(heel_unspec_codes)
        Result.subtitle = "Pressure Ulcer of Unspectified Heel Side with Specified Stage Present"
        Result.passed = true

    elseif subtitle == "Pressure Ulcer of Unspecified Heel Side and Unspecified Stage Present" and (right_heel_spec_codes or left_heel_spec_codes) then
        -- 26.1
        if right_heel_spec_codes then documented_dx_header:add_link(right_heel_spec_codes) end
        if left_heel_spec_codes then documented_dx_header:add_link(left_heel_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89609_code and not right_heel_spec_codes and not left_heel_spec_codes then
        -- 26.0
        documented_dx_header:add_link(l89609_code)
        Result.subtitle = "Pressure Ulcer of Unspecified Heel Side and Unspecified Stage Present"
        Result.passed = true

    elseif subtitle == "Pressure Ulcer of Right Heel with Unspecified Stage Present" and right_heel_spec_codes then
        -- 27.1
        if right_heel_spec_codes then documented_dx_header:add_link(right_heel_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89619_code and not right_heel_spec_codes then
        -- 27.0
        documented_dx_header:add_link(l89619_code)
        Result.subtitle = "Pressure Ulcer of Right Heel with Unspecified Stage Present"
        Result.passed = true

    elseif subtitle == "Pressure Ulcer of Left Heel with Unspecified Stage Present" and left_heel_spec_codes then
        -- 28.1
        if left_heel_spec_codes then documented_dx_header:add_link(left_heel_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89629_code and not left_heel_spec_codes then
        -- 28.0
        documented_dx_header:add_link(l89629_code)
        Result.subtitle = "Pressure Ulcer of Left Heel with Unspecified Stage Present"
        Result.passed = true

    elseif subtitle == "Pressure Ulcer of Head with Unspecified Stage Present" and head_spec_codes then
        -- 29.1
        if head_spec_codes then documented_dx_header:add_link(head_spec_codes) end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89819_code and not head_spec_codes then
        -- 29.0
        documented_dx_header:add_link(l89819_code)
        Result.subtitle = "Pressure Ulcer of Head with Unspecified Stage Present"
        Result.passed = true

    elseif subtitle == "Pressure Ulcer of Other Site with Unspecified Stage Present" and other_site_spec_codes then
        -- 30.1
        documented_dx_header:add_link(other_site_spec_codes)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l89899_code and not other_site_spec_codes then
        -- 30.0
        documented_dx_header:add_link(l89899_code)
        Result.subtitle = "Pressure Ulcer of Other Site with Unspecified Stage Present"
        Result.passed = true

    elseif subtitle == "Pressure Ulcer of Unspecified Site and Unspecified Stage Present" and unspec_site_full_spec_codes then
        -- 31.1
        documented_dx_header:add_link(unspec_site_full_spec_codes)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif l8990_code and not unspec_site_full_spec_codes then
        -- 31.0
        documented_dx_header:add_link(l8990_code)
        Result.subtitle = "Pressure Ulcer of Unspecified Site and Unspecified Stage Present"
        Result.passed = true

    elseif subtitle == "Possible Pressure Ulcer" and stage_34_pu_codes then
        -- 32.1
        documented_dx_header:add_link(stage_34_pu_codes)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    elseif not stage_34_pu_codes and pressure_injury_stage_dv then
        -- 32.0
        if pressure_injury_stage_dv then clinical_evidence_header:add_link(pressure_injury_stage_dv) end
        Result.subtitle = "Possible Pressure Ulcer"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Documented Dx
            documented_dx_header:add_abstraction_link_with_value("PRESSURE_ULCER_POA_STATUS", "Pressure Ulcer POA Status")

            -- Clinical Evidence
            clinical_evidence_header:add_discrete_value_one_of_link(
                dv_braden_risk_assessment_score,
                "Braden Risk Assessment Score",
                calc_braden_risk_assessment_score1
            )
            clinical_evidence_header:add_abstraction_link(
                "BRADEN_RISK_ASSESSMENT_SCORE",
                "Braden Risk Assessment Score"
            )

            -- Document Links
            wound_care_header:add_document_link("Wound Care Progress Note", "Wound Care Progress Note")
            wound_care_header:add_document_link("Wound Care RN Initial Consult", "Wound Care RN Initial Consult")
            wound_care_header:add_document_link("Wound Care RN Follow Up", "Wound Care RN Follow Up")
            wound_care_header:add_document_link("Wound Care History and Physical", "Wound Care History and Physical")
            wound_care_header:add_document_link("Wound Ostomy Team Initial Consult Note", "Wound Ostomy Team Initial Consult Note")
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        compile_links()
    end
end

