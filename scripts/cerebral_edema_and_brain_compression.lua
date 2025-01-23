-----------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Cerebral Edema and Brain Compression
---
--- This script checks an account to see if it matches the criteria for a cerebral edema and brain compression alert.
---
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
-----------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Requires
--------------------------------------------------------------------------------
local alerts = require("libs.common.alerts")(Account)
local links = require("libs.common.basic_links")(Account)
local codes = require("libs.common.codes")(Account)
local discrete = require("libs.common.discrete")(Account)
local medications = require("libs.common.medications")(Account)
local dates = require("libs.common.dates")
local headers = require("libs.common.headers")(Account)
local documents = require("libs.common.documents")(Account)



--------------------------------------------------------------------------------
--- Site Constants
--------------------------------------------------------------------------------
local glasgow_coma_scale_dv_name = { "3.5 Neuro Glasgow Score" }
local glasgow_coma_scale_predicate = discrete.make_lt_predicate(15)
local heart_rate_dv_name = {
    "Heart Rate cc (bpm)",
    "3.5 Heart Rate (Apical) (bpm)",
    "3.5 Heart Rate (Other) (bpm)",
    "3.5 Heart Rate (Radial) (bpm)",
    "SCC Monitor Pulse (bpm)"
}
local heart_rate_predicate = discrete.make_lt_predicate(60)
local intracranial_pressure_dv_name = { "ICP cc (mm Hg)" }
local intracranial_pressure_predicate = discrete.make_gt_predicate(15)
local respiratory_rate_dv_name = { "3.5 Respiratory Rate (#VS I&O) (per Minute)" }
local respiratory_rate_predicate = discrete.make_lt_predicate(12)



--------------------------------------------------------------------------------
--- Existing Alert
--------------------------------------------------------------------------------
local existing_alert = alerts.get_existing_cdi_alert { scriptName = Result.script_name }



if not existing_alert or not existing_alert.validated then
    --------------------------------------------------------------------------------
    --- Header Variables and Helper Functions
    --------------------------------------------------------------------------------
    local result_links = {}
    local documented_dx_header = headers.make_header_builder("Documented Code", 1)
    local vital_signs_intake_header = headers.make_header_builder("Vital Signs/Intake", 4)
    local clinical_evidence_header = headers.make_header_builder("Clinical Evidence", 5)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 6)
    local ct_head_brain_header = headers.make_header_builder("CT Head/Brain", 7)
    local mri_brain_header = headers.make_header_builder("MRI Brain", 8)

    local function compile_links()
        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, vital_signs_intake_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))
        table.insert(result_links, ct_head_brain_header:build(true))
        table.insert(result_links, mri_brain_header:build(true))

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
        ["SO6.1X5A"] = "Traumatic Cerebral Edema With Loss Of Consciousness Greater Than 24 Hours With Return To Pre-Existing Conscious Level",
        ["SO6.1X6A"] = "Traumatic Cerebral Edema With Loss Of Consciousness Greater Than 24 Hours Without Return To Pre-Existing Conscious Level With Patient Surviving",
        ["SO6.1X7A"] = "Traumatic Cerebral Edema With Loss Of Consciousness Of Any Duration With Death Due To Brain Injury Prior To Regaining Consciousness",
        ["S06.1X8A"] = "Traumatic Cerebral Edema With Loss Of Consciousness Of Any Duration With Death Due To Other Cause Prior To Regaining Consciousness",
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
    local account_edema_codes = codes.get_account_codes_in_dictionary(Account, edema_code_dictionary)
    local account_compression_codes = codes.get_account_codes_in_dictionary(Account, compression_code_dictionary)



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Negations
    local cervical_decompression_abs =
        codes.make_abstraction_link("CERVICAL_DECOMPRESSION", "Cervical Decompression")
    local cervical_fusion_abs =
        codes.make_abstraction_link("CERVICAL_FUSION", "Cervical Fusion")
    local lumbar_decompression_abs =
        codes.make_abstraction_link("LUMBAR_DECOMPRESSION", "Lumbar Decompression")
    local lumbar_fusion_abs =
        codes.make_abstraction_link("LUMBAR_FUSION", "Lumbar Fusion")
    local sacral_decompression_abs =
        codes.make_abstraction_link("SACRAL_DECOMPRESSION", "Sacral Decompression")
    local sacral_fusion_abs =
        codes.make_abstraction_link("SACRAL_FUSION", "Sacral Fusion")
    local thoracic_decompression_abs =
        codes.make_abstraction_link("THORACIC_DECOMPRESSION", "Thoracic Decompression")
    local thoracic_fusion_abs =
        codes.make_abstraction_link("THORACIC_FUSION", "Thoracic Fusion")

    -- Alert Trigger
    -- get latest medical document
    --- @type number | nil
    local latest_medical_document_date = nil
    --- @type string | nil
    local latest_medical_document_type = nil
    for _, document in ipairs(Account.documents) do
        if
            document_list[document.document_type] and
            latest_medical_document_date == nil or
            dates.date_string_to_int(document.document_date)
        then
            latest_medical_document_date = dates.date_string_to_int(document.document_date)
            latest_medical_document_type = document.document_type
        end
    end
    local latest_medical_document_link =
        latest_medical_document_type and
        documents.make_document_link(latest_medical_document_type) or nil
    local mannitol_med_doc_link =
        latest_medical_document_date and
        medications.make_medication_link("Mannitol", "Mannitol", nil, function(med)
            return dates.date_string_to_int(med.start_date) < latest_medical_document_date
        end
        ) or nil
    local dexamethasone_med_doc_link =
        latest_medical_document_date and
        medications.make_medication_link(
            "Dexamethasone",
            "Dexamethasone",
            nil,
            function(med)
                return dates.date_string_to_int(med.start_date) < latest_medical_document_date
            end
        ) or nil

    -- Abs
    local brain_compression_abs = codes.make_abstraction_link("BRAIN_COMPRESSION", "Brain Compression")
    local brain_herniation_abs = codes.make_abstraction_link("BRAIN_HERNIATION", "Brain Herniation")
    local brain_pressure_abs = codes.make_abstraction_link("BRAIN_PRESSURE", "Brain Pressure")
    local cerebral_edema_abs = codes.make_abstraction_link("CEREBRAL_EDEMA", "Cerebral Edema")
    local cerebral_ventricle_effacement_abs =
        codes.make_abstraction_link("CEREBRAL_VENTRICLE_EFFACEMENT", "Cerebral Ventricle Effacement")
    local mass_effect_abs = codes.make_abstraction_link("MASS_EFFECT", "Mass Effect")
    local sulcal_effacement_abs = codes.make_abstraction_link("SULCAL_EFFACEMENT", "Sulcal Effacement")

    -- Treatment
    local burr_holes_codes = codes.make_code_links({ "00943ZZ", "00C40ZZ" }, "Burr Holes")
    local decompressive_craniectomy_code = codes.make_code_link("00N00ZZ", "Decompressive Craniectomy")
    local hypertonic_saline_med = medications.make_medication_link(
        "Hypertonic Saline",
        "Hypertonic Saline",
        nil,
        function(med)
            return med.route:find("Aerosol") ~= nil
        end
    )
    local hyperventilation_therapy_abs =
        codes.make_abstraction_link("HYPERVENTILATION_THERAPY", "Hyperventilation Therapy")
    local subarchnoid_epidural_bolt_code = codes.make_code_link("00H032Z", "Subarchnoid/Epidural Bolt")
    local ventriculostomy_codes = codes.make_code_links({ "009600Z", "009630Z", "009640Z" }, "Ventriculostomy")

    -- Vitals
    local intra_pressure_dv =
        discrete.make_discrete_value_link(intracranial_pressure_dv_name, "Intracranial Pressure", intracranial_pressure_predicate)
    local intra_pressure_abs =
        codes.make_abstraction_link("ELEVATED_INTRACRANIAL_PRESSURE", "Intracranial Pressure")

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
    elseif
        brain_compression_abs and
        #account_compression_codes == 0 and
        cerebral_edema_abs and
        #account_edema_codes == 0
    then
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
        if mannitol_med_doc_link and latest_medical_document_type then
            documented_dx_header:add_link(mannitol_med_doc_link)
            documented_dx_header:add_link(latest_medical_document_link)
        end
        if dexamethasone_med_doc_link and latest_medical_document_type then
            documented_dx_header:add_link(dexamethasone_med_doc_link)
            documented_dx_header:add_link(latest_medical_document_link)
        end
        Result.subtitle = "Possible Cerebral Edema Dx"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Clinical Evidence
            local r4182_code = codes.make_code_link("R41.82", "Altered Level Of Consciousness")
            local altered_abs = codes.make_abstraction_link("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level Of Consciousness")
            if r4182_code then
                clinical_evidence_header:add_link(r4182_code)
                if altered_abs then
                    altered_abs.hidden = true
                end
            end
            clinical_evidence_header:add_link(altered_abs)
            clinical_evidence_header:add_link(brain_compression_abs)

            clinical_evidence_header:add_code_one_of_link(
                {
                    "I60.31", "I60.32", "I60.4", "I60.5", "I60.50", "I60.51", "I60.52", "I60.6", "I60.7", "I60.8",
                    "I60.9", "I61.0", "I61.1", "I61.2", "I61.3", "I61.4", "I61.5", "I61.6", "I61.8", "I61.9", "I62",
                    "I62.0", "I62.00", "I62.01", "I62.02", "I62.03", "I62.1", "I62.9", "I60.0", "I60.00", "I60.01",
                    "I60.02", "I60.1", "I60.10", "I60.11", "I60.12", "I60.2", "I60.3", "I60.30",
                },
                "Brain Hemorrhage"
            )
            clinical_evidence_header:add_link(brain_herniation_abs)
            clinical_evidence_header:add_link(brain_pressure_abs)
            clinical_evidence_header:add_code_link("G93.0", "Cerebral Cysts")
            clinical_evidence_header:add_link(cerebral_edema_abs)
            clinical_evidence_header:add_code_link("I67.82", "Cerebral Ischemia")
            clinical_evidence_header:add_link(cerebral_ventricle_effacement_abs)
            clinical_evidence_header:add_code_link("G31.9", "Cerebral Volume loss")
            clinical_evidence_header:add_code_link("Z98.2", "Cerebrospinal Fluid Drainage Device")
            clinical_evidence_header:add_abstraction_link("COMA", "Coma");
            clinical_evidence_header:add_code_link("R41.0", "Disorientation")
            clinical_evidence_header:add_code_link("R29.810", "Facial Droop")
            clinical_evidence_header:add_abstraction_link("FACIAL_NUMBNESS", "Facial Numbness")
            clinical_evidence_header:add_code_link("R51.9", "Headache")
            clinical_evidence_header:add_code_one_of_link(
                {
                    "G81.00", "G81.01", "G81.02", "G81.03", "G81.04", "G81.1", "G81.10", "G81.11", "G81.12",
                    "G81.13", "G81.14", "G81.90", "G81.91", "G81.92", "G81.93", "G81.94"
                },
                "Hemiplegia"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "G81.00", "G81.10", "G81.90" },
                "Hemiplegia/Hemiparesis of Unspecified Site"
            )
            clinical_evidence_header:add_code_one_of_link({ "G91.1", "G91.3", "G91.9" }, "Hydrocephalus")
            clinical_evidence_header:add_code_link("G04.90", "Encephalitis")
            clinical_evidence_header:add_code_prefix_link("S06%.", "Intracranial Injury")
            clinical_evidence_header:add_abstraction_link("IRREGULAR_RADIOLOGY_FINDINGS_BRAIN", "Radiology Findings")
            clinical_evidence_header:add_code_one_of_link({ "5A1935Z", "5A1945Z", "5A1955Z" }, "Intubation")
            clinical_evidence_header:add_link(mass_effect_abs)
            clinical_evidence_header:add_abstraction_link("MIDLINE_SHIFT", "Midline Shift")
            clinical_evidence_header:add_abstraction_link("MUSCLE_CRAMPS", "Muscle Cramps")
            clinical_evidence_header:add_code_one_of_link(
                {
                    "I63.0", "I63.00", "I63.01", "I63.011", "I63.012", "I63.013", "I63.019", "I63.02", "I63.03",
                    "I63.031", "I63.032", "I63.033", "I63.039", "I63.09", "I63.1", "I63.10", "I63.11", "I63.111",
                    "I63.112", "I63.113", "I63.119", "I63.12", "I63.13", "I63.131", "I63.132", "I63.133", "I63.139",
                    "I63.19", "I63.2", "I63.20", "I63.21", "I63.211", "I63.212", "I63.213", "I63.219", "I63.22",
                    "I63.23", "I63.231", "I63.232", "I63.233", "I63.239", "I63.29", "I63.3", "I63.30", "I63.31",
                    "I63.311", "I63.312", "I63.313", "I63.319", "I63.32", "I63.321", "I63.322", "I63.323", "I63.329",
                    "I63.33", "I63.331", "I63.332", "I63.333", "I63.339", "I63.34", "I63.341", "I63.342", "I63.343",
                    "I63.349", "I63.39", "I63.4", "I63.40", "I63.41", "I63.411", "I63.412", "I63.413", "I63.419",
                    "I63.432", "I63.433", "I63.439", "I63.44", "I63.441", "I63.442", "I63.443", "I63.449", "I63.49",
                    "I63.5", "I63.50", "I63.51", "I63.511", "I63.512", "I63.513", "I63.519", "I63.52", "I63.521",
                    "I63.522", "I63.523", "I63.529", "I63.53", "I63.531", "I63.532", "I63.533", "I63.539", "I63.54",
                    "I63.541", "I63.542", "I63.543", "I63.549", "I63.59", "I63.6", "I63.8", "I63.81", "I63.89", "I63.9"
                },
                "Cerebral Infarction"
            )
            clinical_evidence_header:add_abstraction_link("OBTUNED", "Obtuned")
            clinical_evidence_header:add_abstraction_link("SEIZURE", "Seizure")
            clinical_evidence_header:add_link(sulcal_effacement_abs)
            clinical_evidence_header:add_code_link("S09.8XXA", "Traumatic Brain Injury - Closed Head Injury")
            clinical_evidence_header:add_code_link("S09.90XA", "Traumatic Brain Injury - Open Head Injury")
            clinical_evidence_header:add_code_link("R11.10", "Vomiting")

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

            -- Treatment Links
            treatment_and_monitoring_header:add_medication_link("Acetazolamide", "")
            treatment_and_monitoring_header:add_abstraction_link("ACETAZOLAMIDE", "Acetazolamide")
            treatment_and_monitoring_header:add_medication_link("Anticonvulsant", "")
            treatment_and_monitoring_header:add_abstraction_link("ANTICONVULSANT", "Anticonvulsant")
            treatment_and_monitoring_header:add_medication_link("Benzodiazepine", "")
            treatment_and_monitoring_header:add_abstraction_link("BENZODIAZEPINE", "Benzodiazepine")
            treatment_and_monitoring_header:add_link(burr_holes_codes)
            treatment_and_monitoring_header:add_medication_link("Beta Blocker", "")
            treatment_and_monitoring_header:add_medication_link("Bumetanide", "")
            treatment_and_monitoring_header:add_medication_link("Calcium Channel Blockers", "")
            treatment_and_monitoring_header:add_abstraction_link("CALCIUM_CHANNEL_BLOCKER", "Calcium Channel Blocker")
            treatment_and_monitoring_header:add_link(decompressive_craniectomy_code)
            treatment_and_monitoring_header:add_medication_link("Dexamethasone", "")
            treatment_and_monitoring_header:add_medication_link("Diuretic", "")
            treatment_and_monitoring_header:add_abstraction_link("DIURETIC", "Diuretic")
            treatment_and_monitoring_header:add_medication_link("Furosemide", "")
            treatment_and_monitoring_header:add_medication_link("Hydralazine", "")
            treatment_and_monitoring_header:add_link(hypertonic_saline_med)
            treatment_and_monitoring_header:add_abstraction_link("HYPERTONIC_SALINE", "Hypertonic Saline")
            treatment_and_monitoring_header:add_link(hyperventilation_therapy_abs)
            treatment_and_monitoring_header:add_medication_link("Lithium", "")
            treatment_and_monitoring_header:add_medication_link("Mannitol", "")
            treatment_and_monitoring_header:add_medication_link("Methylprednisolone", "")
            treatment_and_monitoring_header:add_medication_link("Sodium Nitroprusside", "")
            treatment_and_monitoring_header:add_medication_link("Steroid", "")
            treatment_and_monitoring_header:add_abstraction_link("STEROIDS", "Steroid")
            treatment_and_monitoring_header:add_link(subarchnoid_epidural_bolt_code)
            treatment_and_monitoring_header:add_link(ventriculostomy_codes)

            -- Vitals Links
            vital_signs_intake_header:add_discrete_value_one_of_link(
                glasgow_coma_scale_dv_name,
                "Glasgow Coma Score",
                glasgow_coma_scale_predicate
            )
            vital_signs_intake_header:add_discrete_value_one_of_link(
                heart_rate_dv_name,
                "Heart Rate",
                heart_rate_predicate
            )
            vital_signs_intake_header:add_link(intra_pressure_dv)
            vital_signs_intake_header:add_link(intra_pressure_abs)
            vital_signs_intake_header:add_discrete_value_one_of_link(
                respiratory_rate_dv_name,
                "Respiratory Rate",
                respiratory_rate_predicate
            )
        end



        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        compile_links()
    end
end
