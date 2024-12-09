---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Cerebral Edema and Brain Compression
---
--- This script checks an account to see if it matches the criteria for a cerebral edema and brain compression alert.
---
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
---------------------------------------------------------------------------------------------------------------------
---@diagnostic disable: unused-local, empty-block, unused-function -- Remove once the script is filled out



--------------------------------------------------------------------------------
--- Requires
--------------------------------------------------------------------------------
local alerts = require("libs.common.alerts")
local links = require("libs.common.basic_links")
local codes = require("libs.common.codes")
local dates = require("libs.common.dates")
local discrete = require("libs.common.discrete_values")
local headers = require("libs.common.headers")



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local glasgow_coma_scale_dv_name = { "3.5 Neuro Glasgow Score" }
local glasgow_coma_scale_predicate = function(dv, num) return num < 15 end
local heart_rate_dv_name = {
    "Heart Rate cc (bpm)",
    "3.5 Heart Rate (Apical) (bpm)",
    "3.5 Heart Rate (Other) (bpm)",
    "3.5 Heart Rate (Radial) (bpm)",
    "SCC Monitor Pulse (bpm)"
}
local heart_rate_predicate = function(dv, num) return num < 60 end
local immature_reticulocyte_fraction_dv_name = { "" }
local immature_reticulocyte_fraction_predicate = function(dv, num) return num < 3 end
local intracranial_pressure_dv_name = { "ICP cc (mm Hg)" }
local intracranial_pressure_predicate = function(dv, num) return num > 15 end
local respiratory_rate_dv_name = { "3.5 Respiratory Rate (#VS I&O) (per Minute)" }
local respiratory_rate_predicate = function(dv, num) return num < 12 end



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
    local alert_trigger_header = headers.make_header_builder("Alert Trigger", 2)
    local laboratory_studies_header = headers.make_header_builder("Laboratory Studies", 3)
    local vital_signs_intake_header = headers.make_header_builder("Vital Signs/Intake", 4)
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 5)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 6)

    local function compile_links()
        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, alert_trigger_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, laboratory_studies_header:build(true))
        table.insert(result_links, vital_signs_intake_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))

        if existing_alert then
            result_links = links.merge_links(existing_alert.links, result_links)
        end
        Result.links = result_links
    end



    --------------------------------------------------------------------------------
    --- Alert Variables
    --------------------------------------------------------------------------------
    local edema_code_dictionary = {
        ["G93.6"] = "Cerebral Edema",
        ["S06.1X0A"] = "Traumatic Cerebral Edema Without Loss Of Consciousness",
        ["S06.1X1A"] = "Traumatic Cerebral Edema With Loss Of Consciousness Of 30 Minutes Or Less",
        ["S06.1X2A"] = "Traumatic Cerebral Edema With Loss Of Consciousness Of 31 Minutes To 59 Minutes",
        ["SO6.1X3A"] = "Traumatic Cerebral Edema With Loss Of Consciousness Of 1 Hour To 5 Hours 59 Minutes",
        ["SO6.1X4A"] = "Traumatic Cerebral Edema With Loss Of Consciousness Of 6 Hours To 24 Hours",
        ["SO6.1X5A"] =
        "Traumatic Cerebral Edema With Loss Of Consciousness Greater Than 24 Hours With Return To Pre-Existing Conscious Level",
        ["SO6.1X6A"] =
        "Traumatic Cerebral Edema With Loss Of Consciousness Greater Than 24 Hours Without Return To Pre-Existing Conscious Level With Patient Surviving",
        ["SO6.1X7A"] =
        "Traumatic Cerebral Edema With Loss Of Consciousness Of Any Duration With Death Due To Brain Injury Prior To Regaining Consciousness",
        ["S06.1X8A"] =
        "Traumatic Cerebral Edema With Loss Of Consciousness Of Any Duration With Death Due To Other Cause Prior To Regaining Consciousness",
        ["SO6.1X9A"] = "Traumatic Cerebral Edema With Loss Of Consciousness Of Unspecified Duration",
    }
    local compression_code_dictionary = {
        ["G93.5"] = "Compression Of Brain",
        ["S06.A0XA"] = "Traumatic Brain Compression Without Herniation",
        ["S06.A1XA"] = "Traumatic Brain Compression With Herniation",
    }
    local document_list = {
        "Operative Note Neurosurgery Resident Physician",
        "Operative Note Neurosurgery Physician",
        "Operative Note Neurosurgery HIM",
    }
    local account_edema_codes = codes.get_account_codes_in_dictionary(Account, compression_code_dictionary)
    local account_compression_codes = codes.get_account_codes_in_dictionary(Account, compression_code_dictionary)



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Negations
    local cervical_decompression_abs = links.get_abstraction_link { code = "CERVICAL_DECOMPRESSION", text = "Cervical Decompression" }
    local cervical_fusion_abs = links.get_abstraction_link { code = "CERVICAL_FUSION", text = "Cervical Fusion" }
    local lumbar_decompression_abs = links.get_abstraction_link { code = "LUMBAR_DECOMPRESSION", text = "Lumbar Decompression" }
    local lumbar_fusion_abs = links.get_abstraction_link { code = "LUMBAR_FUSION", text = "Lumbar Fusion" }
    local sacral_decompression_abs = links.get_abstraction_link { code = "SACRAL_DECOMPRESSION", text = "Sacral Decompression" }
    local sacral_fusion_abs = links.get_abstraction_link { code = "SACRAL_FUSION", text = "Sacral Fusion" }
    local thoracic_decompression_abs = links.get_abstraction_link { code = "THORACIC_DECOMPRESSION", text = "Thoracic Decompression" }
    local thoracic_fusion_abs = links.get_abstraction_link { code = "THORACIC_FUSION", text = "Thoracic Fusion" }

    -- Alert Trigger
    -- get latest medical document
    --- @type number | nil
    local latest_medical_document_date = nil
    --- @type string | nil
    local latest_medical_document_type = nil
    for _, document in ipairs(Account.documents) do
        if document_list[document.document_type] and latest_medical_document_date == nil or dates.date_string_to_int(document.document_date) then
            latest_medical_document_date = dates.date_string_to_int(document.document_date)
            latest_medical_document_type = document.document_type
        end
    end
    local latest_medical_document_link = links.get_document_link { documentType = latest_medical_document_type }
    local mannitol_med_doc_link =
        latest_medical_document_date and
        links.get_medication_link {
            text = "Mannitol",
            medication = "Mannitol",
            predicate = function(med)
                return dates.date_string_to_int(med.start_date) < latest_medical_document_date
            end
        } or nil
    local dexamethasone_med_doc_link =
        latest_medical_document_date and
        links.get_medication_link {
            text = "Dexamethasone",
            medication = "Dexamethasone",
            predicate = function(med)
                return dates.date_string_to_int(med.start_date) < latest_medical_document_date
            end
        } or nil

    -- Abs
    local brain_compression_abs = links.get_abstraction_link { code = "BRAIN_COMPRESSION", text = "Brain Compression" }
    local brain_herniation_abs = links.get_abstraction_link { code = "BRAIN_HERNIATION", text = "Brain Herniation" }
    local brain_pressure_abs = links.get_abstraction_link { code = "BRAIN_PRESSURE", text = "Brain Pressure" }
    local cerebral_edema_abs = links.get_abstraction_link { code = "CEREBRAL_EDEMA", text = "Cerebral Edema" }
    local cerebral_ventricle_effacement_abs = links.get_abstraction_link { code = "CEREBRAL_VENTRICLE_EFFACEMENT", text = "Cerebral Ventricle Effacement" }
    local mass_effect_abs = links.get_abstraction_link { code = "MASS_EFFECT", text = "Mass Effect" }
    local sulcal_effacement_abs = links.get_abstraction_link { code = "SULCAL_EFFACEMENT", text = "Sulcal Effacement" }

    -- Treatment
    local burr_holes_codes = links.get_code_links { codes = { "00943ZZ", "00C40ZZ" }, text = "Burr Holes" }
    local decompressive_craniectomy_code = links.get_code_link { code = "00N00ZZ", text = "Decompressive Craniectomy" }
    local hypertonic_saline_med = links.get_medication_link {
        text = "Hypertonic Saline",
        medication = "Hypertonic Saline",
        predicate = function(med)
            return med.route:find("Aerosol") ~= nil
        end
    }
    local hyperventilation_therapy_abs = links.get_abstraction_link { code = "HYPERVENTILATION_THERAPY", text = "Hyperventilation Therapy" }
    local subarchnoid_epidural_bolt_code = links.get_code_link { code = "00H032Z", text = "Subarchnoid/Epidural Bolt" }
    local ventriculostomy_codes = links.get_code_link { codes = { "009600Z", "009630Z", "009640Z" }, text = "Ventriculostomy" }

    -- Vitals
    local intra_pressure_dv = links.get_discrete_value_link { discreteValueName = "Intracranial Pressure", text = "Intracranial Pressure", predicate = intracranial_pressure_predicate }
    local intra_pressure_abs = links.get_abstraction_link { code = "ELEVATED_INTRACRANIAL_PRESSURE", text = "Intracranial Pressure" }

    local negation_check =
        cervical_decompression_abs or
        cervical_fusion_abs or
        lumbar_decompression_abs or
        lumbar_fusion_abs or
        sacral_decompression_abs or
        sacral_fusion_abs or
        thoracic_decompression_abs or
        thoracic_fusion_abs



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if #account_edema_codes > 1 then
        for _, code in ipairs(account_edema_codes) do
            documented_dx_header:add_code_link(code, "Specified Code Present")
        end
        Result.subtitle = "Cerebral Edema Conflicting Dx " .. table.concat(account_edema_codes, ", ")
        if existing_alert and existing_alert.validated then
            Result.validated = false
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
        end
        Result.passed = true
    elseif #account_compression_codes > 1 then
        for _, code in ipairs(account_compression_codes) do
            documented_dx_header:add_code_link(code, "Specified Code Present")
        end
        Result.subtitle = "Brain Compression Conflicting Dx " .. table.concat(account_compression_codes, ", ")
        if existing_alert and existing_alert.validated then
            Result.validated = false
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
        end
        Result.passed = true
    elseif brain_compression_abs and #account_compression_codes == 0 and cerebral_edema_abs and #account_edema_codes == 0 then
        documented_dx_header:add_link(brain_compression_abs)
        documented_dx_header:add_link(cerebral_edema_abs)
        Result.subtitle = "Brain Compression and Cerebral Edema Dx Possibly only present on Radiology Reports."
        Result.passed = true
    elseif cerebral_edema_abs and #account_edema_codes == 0 then
        documented_dx_header:add_link(cerebral_edema_abs)
        Result.subtitle = "Cerebral Edema Dx Possibly Only Present On Radiology Reports"
        Result.passed = true
    elseif brain_compression_abs and #account_compression_codes == 0 then
        documented_dx_header:add_link(brain_compression_abs)
        Result.subtitle = "Brain Compression Dx Possibly Only Present On Radiology Reports"
        Result.passed = true
    elseif brain_herniation_abs and #account_compression_codes == 0 then
        documented_dx_header:add_link(brain_herniation_abs)
        Result.subtitle = "Brain Herniation Dx Possibly Only Present On Radiology Reports"
        Result.passed = true
    elseif (#account_compression_codes == 0 and (
            mass_effect_abs or
            sulcal_effacement_abs or
            cerebral_ventricle_effacement_abs or
            brain_pressure_abs or
            intra_pressure_dv or
            intra_pressure_abs or
            burr_holes_codes or
            decompressive_craniectomy_code or
            hyperventilation_therapy_abs or
            subarchnoid_epidural_bolt_code or
            ventriculostomy_codes
        ))
    then
        Result.subtitle = "Possible Brain Compression Dx"
        Result.passed = true
    elseif
        #account_compression_codes == 0 and
        #account_edema_codes == 0 and (
            hypertonic_saline_med or
            (dexamethasone_med_doc_link and not negation_check) or
            (mannitol_med_doc_link and not negation_check)
        )
    then
        -- TODO: Left off here
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Normal Alert
        end



        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        compile_links()
    end
end
