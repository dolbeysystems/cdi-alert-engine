---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Stroke
---
--- This script checks an account to see if it matches the criteria for a stroke alert.
---
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
---------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Requires
--------------------------------------------------------------------------------
local alerts = require "libs.common.alerts" (Account)
local links = require "libs.common.basic_links" (Account)
local codes = require "libs.common.codes" (Account)
local headers = require "libs.common.headers" (Account)



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
    local procedure_header = headers.make_header_builder("Procedure", 3)
    local contributing_dx_header = headers.make_header_builder("Contributing Dx", 4)
    local treatment_and_monitoring_header = headers.make_header_builder("Treatment and Monitoring", 5)
    local vital_signs_header = headers.make_header_builder("Vital Signs/Intake and Output Data", 6)
    local ct_brain_header = headers.make_header_builder("CT Brain", 7)
    local mri_brain_header = headers.make_header_builder("MRI Brain", 8)
    local other_header = headers.make_header_builder("Other", 9)

    local function compile_links()
        table.insert(result_links, documented_dx_header:build(true))
        table.insert(result_links, clinical_evidence_header:build(true))
        table.insert(result_links, procedure_header:build(true))
        table.insert(result_links, contributing_dx_header:build(true))
        table.insert(result_links, treatment_and_monitoring_header:build(true))
        table.insert(result_links, vital_signs_header:build(true))
        table.insert(result_links, ct_brain_header:build(true))
        table.insert(result_links, mri_brain_header:build(true))
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
        ["I61.0"] = "Nontraumatic Intracerebral Hemorrhage In Hemisphere, Subcortical",
        ["I61.1"] = "Nontraumatic Intracerebral Hemorrhage In Hemisphere, Cortical",
        ["I61.3"] = "Nontraumatic Intracerebral Hemorrhage In Brain Stem",
        ["I61.4"] = "Nontraumatic Intracerebral Hemorrhage In Cerebellum",
        ["I61.5"] = "Nontraumatic Intracerebral Hemorrhage, Intraventricular",
        ["I61.6"] = "Nontraumatic Intracerebral Hemorrhage, Multiple Localized",
        ["I63.011"] = "Cerebral Infarction Due To Thrombosis Of Right Vertebral Artery",
        ["I63.012"] = "Cerebral Infarction Due To Thrombosis Of Left Vertebral Artery",
        ["I63.013"] = "Cerebral Infarction Due To Thrombosis Of Bilateral Vertebral Arteries",
        ["I63.031"] = "Cerebral Infarction Due To Thrombosis Of Right Carotid Artery",
        ["I63.032"] = "Cerebral Infarction Due To Thrombosis Of Left Carotid Artery",
        ["I63.033"] = "Cerebral Infarction Due To Thrombosis Of Bilateral Carotid Arteries",
        ["I63.311"] = "Cerebral Infarction Due To Thrombosis Of Right Middle Cerebral Artery",
        ["I63.312"] = "Cerebral Infarction Due To Thrombosis Of Left Middle Cerebral Artery",
        ["I63.313"] = "Cerebral Infarction Due To Thrombosis Of Bilateral Middle Cerebral Arteries",
        ["I63.321"] = "Cerebral Infarction Due To Thrombosis Of Right Anterior Cerebral Artery",
        ["I63.322"] = "Cerebral Infarction Due To Thrombosis Of Left Anterior Cerebral Artery",
        ["I63.323"] = "Cerebral Infarction Due To Thrombosis Of Bilateral Anterior Cerebral Arteries",
        ["I63.331"] = "Cerebral Infarction Due To Thrombosis Of Right Posterior Cerebral Artery",
        ["I63.332"] = "Cerebral Infarction Due To Thrombosis Of Left Posterior Cerebral Artery",
        ["I63.333"] = "Cerebral Infarction Due To Thrombosis Of Bilateral Posterior Cerebral Arteries",
        ["I63.341"] = "Cerebral Infarction Due To Thrombosis Of Right Cerebellar Artery",
        ["I63.342"] = "Cerebral Infarction Due To Thrombosis Of Left Cerebellar Artery",
        ["I63.343"] = "Cerebral Infarction Due To Thrombosis Of Bilateral Cerebellar Arteries",
        ["I63.411"] = "Cerebral Infarction Due To Embolism Of Right Middle Cerebral Artery",
        ["I63.412"] = "Cerebral Infarction Due To Embolism Of Left Middle Cerebral Artery",
        ["I63.413"] = "Cerebral Infarction Due To Embolism Of Bilateral Middle Cerebral Arteries",
        ["I63.421"] = "Cerebral Infarction Due To Embolism Of Right Anterior Cerebral Artery",
        ["I63.422"] = "Cerebral Infarction Due To Embolism Of Left Anterior Cerebral Artery",
        ["I63.423"] = "Cerebral Infarction Due To Embolism Of Bilateral Anterior Cerebral Arteries",
        ["I63.431"] = "Cerebral Infarction Due To Embolism Of Right Posterior Cerebral Artery",
        ["I63.432"] = "Cerebral Infarction Due To Embolism Of Left Posterior Cerebral Artery",
        ["I63.433"] = "Cerebral Infarction Due To Embolism Of Bilateral Posterior Cerebral Arteries",
        ["I63.441"] = "Cerebral Infarction Due To Embolism Of Right Cerebellar Artery",
        ["I63.442"] = "Cerebral Infarction Due To Embolism Of Left Cerebellar Artery",
        ["I63.443"] = "Cerebral Infarction Due To Embolism Of Bilateral Cerebellar Arteries",
        ["I63.6"] = "Cerebral Infarction Due To Cerebral Venous Thrombosis, Nonpyogenic",
        ["G45.9"] = "Transient Cerebral Ischemic Attack, Unspecified",
        ["I63.00"] = "Cerebral infarction due to thrombosis of unspecified precerebral artery",
        ["I63.019"] = "Cerebral infarction due to thrombosis of unspecified vertebral artery",
        ["I63.02"] = "Cerebral infarction due to thrombosis of basilar artery",
        ["I63.039"] = "Cerebral infarction due to thrombosis of unspecified carotid artery",
        ["I63.09"] = "Cerebral infarction due to thrombosis of other precerebral artery",
        ["I63.10"] = "Cerebral infarction due to embolism of unspecified precerebral artery",
        ["I63.111"] = "Cerebral infarction due to embolism of right vertebral artery",
        ["I63.112"] = "Cerebral infarction due to embolism of left vertebral artery",
        ["I63.113"] = "Cerebral infarction due to embolism of bilateral vertebral arteries",
        ["I63.119"] = "Cerebral infarction due to embolism of unspecified vertebral artery",
        ["I63.12"] = "Cerebral infarction due to embolism of basilar artery",
        ["I63.131"] = "Cerebral infarction due to embolism of right carotid artery",
        ["I63.132"] = "Cerebral infarction due to embolism of left carotid artery",
        ["I63.133"] = "Cerebral infarction due to embolism of bilateral carotid arteries",
        ["I63.139"] = "Cerebral infarction due to embolism of unspecified carotid artery",
        ["I63.19"] = "Cerebral infarction due to embolism of other precerebral artery",
        ["I63.20"] = "Cerebral infarction due to unspecified occlusion or stenosis of unspecified precerebral arteries",
        ["I63.211"] = "Cerebral infarction due to unspecified occlusion or stenosis of right vertebral artery",
        ["I63.212"] = "Cerebral infarction due to unspecified occlusion or stenosis of left vertebral artery",
        ["I63.213"] = "Cerebral infarction due to unspecified occlusion or stenosis of bilateral vertebral arteries",
        ["I63.219"] = "Cerebral infarction due to unspecified occlusion or stenosis of unspecified vertebral artery",
        ["I63.22"] = "Cerebral infarction due to unspecified occlusion or stenosis of basilar artery",
        ["I63.231"] = "Cerebral infarction due to unspecified occlusion or stenosis of right carotid arteries",
        ["I63.232"] = "Cerebral infarction due to unspecified occlusion or stenosis of left carotid arteries",
        ["I63.233"] = "Cerebral infarction due to unspecified occlusion or stenosis of bilateral carotid arteries",
        ["I63.239"] = "Cerebral infarction due to unspecified occlusion or stenosis of unspecified carotid artery",
        ["I63.29"] = "Cerebral infarction due to unspecified occlusion or stenosis of other precerebral arteries",
        ["I63.30"] = "Cerebral infarction due to thrombosis of unspecified cerebral artery",
        ["I63.319"] = "Cerebral infarction due to thrombosis of unspecified middle cerebral artery",
        ["I63.329"] = "Cerebral infarction due to thrombosis of unspecified anterior cerebral artery",
        ["I63.339"] = "Cerebral infarction due to thrombosis of unspecified posterior cerebral artery",
        ["I63.349"] = "Cerebral infarction due to thrombosis of unspecified cerebellar artery",
        ["I63.39"] = "Cerebral infarction due to thrombosis of other cerebral artery",
        ["I63.40"] = "Cerebral infarction due to embolism of unspecified cerebral artery",
        ["I63.419"] = "Cerebral infarction due to embolism of unspecified middle cerebral artery",
        ["I63.429"] = "Cerebral infarction due to embolism of unspecified anterior cerebral artery",
        ["I63.439"] = "Cerebral infarction due to embolism of unspecified posterior cerebral artery",
        ["I63.449"] = "Cerebral infarction due to embolism of unspecified cerebellar artery",
        ["I63.50"] = "Cerebral infarction due to unspecified occlusion or stenosis of unspecified cerebral artery",
        ["I63.511"] = "Cerebral infarction due to unspecified occlusion or stenosis of right middle cerebral artery",
        ["I63.512"] = "Cerebral infarction due to unspecified occlusion or stenosis of left middle cerebral artery",
        ["I63.513"] = "Cerebral infarction due to unspecified occlusion or stenosis of bilateral middle cerebral arteries",
        ["I63.519"] = "Cerebral infarction due to unspecified occlusion or stenosis of unspecified middle cerebral artery",
        ["I63.521"] = "Cerebral infarction due to unspecified occlusion or stenosis of right anterior cerebral artery ",
        ["I63.522"] = "Cerebral infarction due to unspecified occlusion or stenosis of left anterior cerebral artery",
        ["I63.523"] = "Cerebral infarction due to unspecified occlusion or stenosis of bilateral anterior cerebral arteries ",
        ["I63.529"] = "Cerebral infarction due to unspecified occlusion or stenosis of unspecified anterior cerebral artery ",
        ["I63.53"] = "Cerebral infarction due to unspecified occlusion or stenosis of posterior cerebral artery",
        ["I63.531"] = "Cerebral infarction due to unspecified occlusion or stenosis of right posterior cerebral artery ",
        ["I63.532"] = "Cerebral infarction due to unspecified occlusion or stenosis of left posterior cerebral artery ",
        ["I63.533"] = "Cerebral infarction due to unspecified occlusion or stenosis of bilateral posterior cerebral arteries ",
        ["I63.539"] = "Cerebral infarction due to unspecified occlusion or stenosis of unspecified posterior cerebral artery",
        ["I63.54"] = "Cerebral infarction due to unspecified occlusion or stenosis of cerebellar artery",
        ["I63.541"] = "Cerebral infarction due to unspecified occlusion or stenosis of right cerebellar artery ",
        ["I63.542"] = "Cerebral infarction due to unspecified occlusion or stenosis of left cerebellar artery ",
        ["I63.543"] = "Cerebral infarction due to unspecified occlusion or stenosis of bilateral cerebellar arteries",
        ["I63.549"] = "Cerebral infarction due to unspecified occlusion or stenosis of unspecified cerebellar artery ",
        ["I63.59"] = "Cerebral infarction due to unspecified occlusion or stenosis of other cerebral artery",
        ["I63.81"] = "Other cerebral infarction due to occlusion or stenosis of small artery",
        ["I63.89"] = "Other cerebral infarction",
        ["I63.9"] = "Cerebral infarction, unspecified"
    }
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)

    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    local cerebral_infarction_codes = links.get_code_links {
        codes = {
            "I63.51", "I63.511", "I63.512", "I63.513", "I63.521", "I63.522", "I63.523", "I63.531", "I63.532",
            "I63.533", "I63.541", "I63.542", "I63.543", "I63.50", "I63.519", "I63.529", "I63.539", "I63.549",
            "I63.59", "I63.81", "I63.81", "I63.89", "I63.9", "I63.00", "I63.019", "I63.039", "I63.30", "I63.319",
            "I63.329", "I63.339", "I63.349", "I63.39", "I63.40", "I63.419", "I63.429", "I63.439", "I63.449", "I63.49",
            "I63.09"
        },
        text = "Cerebral Infarction Codes"
    }
    local g649_code = links.get_code_link { code = "G64.9", text = "TIA" }
    local cerebral_ischemia_abs = links.get_abstraction_link { code = "CEREBRAL_ISCHEMIA", text = "Cerebral Ischemia" }
    local cerebral_infarction_abs =
        links.get_abstraction_link { code = "CEREBRAL_INFARCTION", text = "Cerebral Infarction" }
    local aborted_stroke_abs = links.get_abstraction_link { code = "ABORTED_STROKE", text = "Aborted Stroke" }

    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------

    if #account_alert_codes > 0 then
        if existing_alert then
            for _, code in ipairs(account_alert_codes) do
                local desc = alert_code_dictionary[code]
                local temp_code = links.get_code_link {
                    code = code,
                    text = "Autoresolved Specified Code - " .. desc .. ""
                }
                if temp_code then
                    documented_dx_header:add_link(temp_code)
                    break
                end
            end
            Result.outcome = "AUTORESOLVED"
            Result.reason = "Autoresolved due to one Specified Code on the Account"
            Result.validated = true
        else
            Result.passed = false
        end
    elseif #cerebral_infarction_codes > 0
        and (
            subtitle == "TIA documented Possible Cerebral Infarction seek Clarification"
            or subtitle == "Possible Cerebral Infarction"
        ) then
        documented_dx_header:add_links(cerebral_infarction_codes)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
    elseif
        g649_code ~= nil and
        #cerebral_infarction_codes == 0 and
        (cerebral_infarction_abs ~= nil or cerebral_ischemia_abs ~= nil or aborted_stroke_abs ~= nil)
    then
        documented_dx_header:add_link(g649_code)
        documented_dx_header:add_link(cerebral_infarction_abs)
        documented_dx_header:add_link(cerebral_ischemia_abs)
        Result.subtitle = "TIA documented Possible Cerebral Infarction seek Clarification"
        Result.passed = true
    elseif #cerebral_infarction_codes == 0 and (cerebral_infarction_abs ~= nil or cerebral_ischemia_abs ~= nil) then
        documented_dx_header:add_link(cerebral_infarction_abs)
        documented_dx_header:add_link(cerebral_ischemia_abs)
        Result.subtitle = "Possible Cerebral Infarction"
        Result.passed = true
    end

    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            clinical_evidence_header:add_link(aborted_stroke_abs)
            clinical_evidence_header:add_link(aborted_stroke_abs)
            clinical_evidence_header:add_code_link("R47.01", "Aphasia")
            clinical_evidence_header:add_abstraction_link("ATAXIA", "Ataxia")
            clinical_evidence_header:add_code_one_of_link(
                { "I48.0", "I48.1", "I48.11", "I48.19", "I48.20", "I48.21", "I48.91" },
                "Atrial Fibrillation"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "Q21.10", "Q21.11", "Q21.13", "Q21.14", "Q21.15", "Q21.16", "Q21.19" },
                "Atrial Septal Defect"
            )
            clinical_evidence_header:add_code_link("I65.23", "Carotid Artery Stenosis - Bilateral")
            clinical_evidence_header:add_code_link("I65.22", "Carotid Artery Stenosis - Left")
            clinical_evidence_header:add_code_link("I65.21", "Carotid Artery Stenosis - Right")
            clinical_evidence_header:add_code_link("I65.29", "Carotid Artery Stenosis - Unspecified")
            clinical_evidence_header:add_code_link("I67.1", "Cerebral Aneurysm, Nonruptured")
            clinical_evidence_header:add_code_link("I67.2", "Cerebral Atherosclerotic Disease")
            clinical_evidence_header:add_code_link("I67.848", "Cerebrovascular Vasospasm and Vasocontriction")
            clinical_evidence_header:add_code_link("R41.0", "Confusion")
            clinical_evidence_header:add_code_link("I67.0", "Dissection Of Cerebral Arteries, Nonruptured")
            clinical_evidence_header:add_code_link("R42", "Dizziness")
            clinical_evidence_header:add_code_link("H53.2", "Double Vision")
            clinical_evidence_header:add_code_link("R47.02", "Dysphagia")
            clinical_evidence_header:add_code_link("R29.810", "Facial Droop")
            clinical_evidence_header:add_abstraction_link("FACIAL_NUMBNESS", "Facial Numbness")
            clinical_evidence_header:add_code_link("R29.810", "Facial Droop")
            clinical_evidence_header:add_abstraction_link("HEADACHE", "Headache")
            clinical_evidence_header:add_code_one_of_link(
                {
                    "G81.00", "G81.01", "G81.02", "G81.03", "G81.04", "G81.1", "G81.10", "G81.11", "G81.12", "G81.13",
                    "G81.14", "G81.90", "G81.91", "G81.92", "G81.93", "G81.94"
                },
                "Hemiplegia"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "I69.351", "I69.352", "I69.353", "I69.354", "I69.359" },
                "Hemiplegia/Hemiparesis following Cerebral Infarction"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "G81.00", "G81.10", "G81.90" },
                "Hemiplegia/Hemiparesis Unspecified Side"
            )
            clinical_evidence_header:add_code_link("Z82.3", "History of Stroke")
            clinical_evidence_header:add_code_link("I10", "HTN")
            clinical_evidence_header:add_code_link("Z86.73", "Hx Of Stroke/TIA")
            clinical_evidence_header:add_code_one_of_link({ "I16.0", "I16.1", "I16.9" }, "Hypertensive Crisis")
            clinical_evidence_header:add_code_one_of_link(
                { "G81.02", "G81.04", "G81.12", "G81.14", "G81.92", "G81.94" },
                "Left Hemiplegia/Hemiparesis"
            )
            clinical_evidence_header:add_abstraction_link(
                "LEFT_INTERNAL_CAROTID_STENOSIS",
                "Left Internal Carotid Stenosis"
            )
            clinical_evidence_header:add_code_link("I65.03", "Occlusion and Stenosis Of Bilateral Vertebral Arteries")
            clinical_evidence_header:add_code_link("I65.02", "Occlusion and Stenosis Left Vertebral Artery")
            clinical_evidence_header:add_code_link("I66.10", "Occlusion and Stenosis Of Anterior Cerebral Artery")
            clinical_evidence_header:add_code_link(
                "I66.13",
                "Occlusion and Stenosis Of Bilateral Anterior Cerebral Artery"
            )
            clinical_evidence_header:add_code_link(
                "I66.03",
                "Occlusion and Stenosis Of Bilateral Middle Cerebral Artery"
            )
            clinical_evidence_header:add_code_link(
                "I66.23",
                "Occlusion and Stenosis Of Bilateral Posterior Cerebral Artery"
            )
            clinical_evidence_header:add_code_link("I66.3", "Occlusion and Stenosis Of Cerebellar Artery")
            clinical_evidence_header:add_code_link("I66.12", "Occlusion and Stenosis Of Left Anterior Cerebral Artery")
            clinical_evidence_header:add_code_link("I66.02", "Occlusion and Stenosis Of Left Middle Cerebral Artery")
            clinical_evidence_header:add_code_link(
                "I66.22",
                "Occlusion and Stenosis Of Left Posterior Cerebral Artery"
            )
            clinical_evidence_header:add_code_link("I66.8", "Occlusion and Stenosis Of Other Cerebral Arteries")
            clinical_evidence_header:add_code_link("I65.8", "Occlusion and Stenosis Of Other Precerebral Arteries")
            clinical_evidence_header:add_code_link("I66.2", "Occlusion and Stenosis Of Posterior Cerebral Artery")
            clinical_evidence_header:add_code_link(
                "I66.11",
                "Occlusion and Stenosis Of Right Anterior Cerebral Artery"
            )
            clinical_evidence_header:add_code_link("I66.01", "Occlusion and Stenosis Of Right Middle Cerebral Artery")
            clinical_evidence_header:add_code_link(
                "I66.21",
                "Occlusion and Stenosis Of Right Posterior Cerebral Artery"
            )
            clinical_evidence_header:add_code_link(
                "I66.19",
                "Occlusion and Stenosis Of Unspecified Anterior Cerebral Artery"
            )
            clinical_evidence_header:add_code_link("I66.9", "Occlusion and Stenosis Of Unspecified Cerebral Artery")
            clinical_evidence_header:add_code_link(
                "I66.29",
                "Occlusion and Stenosis Of Unspecified Posterior Cerebral Artery"
            )
            clinical_evidence_header:add_code_link(
                "I65.9",
                "Occlusion and Stenosis Of Unspecified Precerebral Arteries"
            )
            clinical_evidence_header:add_code_link("I65.09", "Occlusion and Stenosis Of Unspecified Vertebral Artery")
            clinical_evidence_header:add_code_link("I65.01", "Occlusion and Stenosis Right Vertebral Artery")
            clinical_evidence_header:add_code_link("Q21.12", "Patent Foramen Ovale (PFO)")
            clinical_evidence_header:add_code_link(
                "I67.841",
                "Reveresible Cerebrovascular Vasospasm and Vasocontriction"
            )
            clinical_evidence_header:add_code_one_of_link(
                { "G81.01", "G81.03", "G81.11", "G81.13", "G81.91", "G81.93" },
                "Right Hemiplegia/Hemiparesis"
            )
            clinical_evidence_header:add_abstraction_link(
                "RIGHT_INTERNAL_CAROTID_STENOSIS",
                "Right Internal Carotid Stenosis"
            )
            clinical_evidence_header:add_code_link("R56.9", "Seizure")
            clinical_evidence_header:add_code_link("R47.81", "Slurred Speech")
            clinical_evidence_header:add_code_link("Q21.0", "Ventricular Septal Defect")
            clinical_evidence_header:add_abstraction_link("VOMITING", "Vomiting")
            contributing_dx_header:add_code_link("D68.51", "Activated Protein C Resistance")
            contributing_dx_header:add_code_link("F10.20", "Alcohol Abuse")
            contributing_dx_header:add_code_link("D68.61", "Antiphospholipid Syndrome")
            contributing_dx_header:add_code_prefix_link("F14.", "Cocaine Use")
            contributing_dx_header:add_code_link("D68.59", "Hypercoagulable State")
            contributing_dx_header:add_code_link("D68.62", "Lupus Anticoagulant Syndrome")
            contributing_dx_header:add_code_one_of_link({ "E66.01", "E66.2" }, "Morbid Obesity")
            contributing_dx_header:add_code_prefix_link("F17.", "Nicotine Dependence")
            contributing_dx_header:add_code_link("D68.69", "Other Thrombophilia")
            contributing_dx_header:add_code_link("D68.52", "Prothrombin Gene Mutation")
            contributing_dx_header:add_code_prefix_link("F15.", "Stimulant Use")

            -- #Document Links
            ct_brain_header:add_document_link("CT Head WO", "CT Head WO")
            ct_brain_header:add_document_link("CT Head Stroke Alert", "CT Head Stroke Alert")
            ct_brain_header:add_document_link("CTA Head-Neck", "CTA Head-Neck")
            ct_brain_header:add_document_link("CTA Head", "CTA Head")
            ct_brain_header:add_document_link("CT Head  WWO", "CT Head  WWO")
            ct_brain_header:add_document_link("CT Head  W", "CT Head  W")
            mri_brain_header:add_document_link("MRI Brain WWO", "MRI Brain WWO")
            mri_brain_header:add_document_link("MRI Brain  W and W/O Contrast", "MRI Brain  W and W/O Contrast")
            mri_brain_header:add_document_link("WO", "WO")
            mri_brain_header:add_document_link("MRI Brain W/O Contrast", "MRI Brain W/O Contrast")
            mri_brain_header:add_document_link("MRI Brain W/O Con", "MRI Brain W/O Con")
            mri_brain_header:add_document_link("MRI Brain  W and W/O Con", "MRI Brain  W and W/O Con")
            mri_brain_header:add_document_link("MRI Brain  W", "MRI Brain  W")
            mri_brain_header:add_document_link("MRI Brain  W/ Contrast", "MRI Brain  W/ Contrast")

            -- #Meds
            treatment_and_monitoring_header:add_medication_link("Anticoagulant", "Anticoagulant")
            treatment_and_monitoring_header:add_abstraction_link("ANTICOAGULANT", "Anticoagulant")
            treatment_and_monitoring_header:add_medication_link("Antiplatelet", "Antiplatelet")
            treatment_and_monitoring_header:add_medication_link("Antiplatelet2", "Antiplatlet")
            treatment_and_monitoring_header:add_abstraction_link("ANTIPLATELET", "Antiplatelet")
            treatment_and_monitoring_header:add_medication_link("Aspirin", "Aspirin")
            treatment_and_monitoring_header:add_medication_link(
                "Clot Supporting Therapy/Reversal Agents",
                "Clot Supporting Therapy/Reversal Agent"
            )
            treatment_and_monitoring_header:add_abstraction_link("CLOT_SUPPORTING_THERAPY", "Clot Supporting Therapy")
            treatment_and_monitoring_header:add_code_link("30233M1", "Cryoprecipitate Transfusion")
            treatment_and_monitoring_header:add_code_link("30233T1", "Fibrinogen Transfusion")
            treatment_and_monitoring_header:add_code_link("30233K1", "Fresh Frozen Plasma Transfusion")
            treatment_and_monitoring_header:add_code_link("30233R1", "Platelet Transfusion")
            treatment_and_monitoring_header:add_medication_link("Thrombolytic", "Thrombolytic")
            treatment_and_monitoring_header:add_abstraction_link("THROMBOLYTIC", "Thrombolytic")
            treatment_and_monitoring_header:add_code_link("3E03317", "TPA Peripheral Vein (IV)")

            -- #Proc
            procedure_header:add_code_link("03CM0ZZ", "External Carotid Artery - Open Thrombectomy")
            procedure_header:add_code_link("03CM3ZZ", "External Carotid Artery - Trans Catheter Thrombectomy")
            procedure_header:add_code_link("03C20ZZ", "Innominate Artery - Open Thrombectomy")
            procedure_header:add_code_link("03C23ZZ", "Innominate Artery - Trans Catheter Thrombectomy")
            procedure_header:add_code_link("03CG0ZZ", "Intracranial - Open")
            procedure_header:add_code_link("03CG3ZZ", "Intracranial - Trans Catheter Thrombectomy")
            procedure_header:add_code_link("03BG0ZZ", "Intracranial Artery Thrombectomy")
            procedure_header:add_code_link("05BL0ZZ", "Intracranial Vein Thrombectomy")
            procedure_header:add_code_link("03CK0ZZ", "Internal Carotid Artery - Open")
            procedure_header:add_code_link("03CK3ZZ", "Internal Carotid Artery - Trans Catheter Thrombectomy")
            procedure_header:add_code_link("03CQ0ZZ", "Left Vertebral Artery - Open Thrombectomy")
            procedure_header:add_code_link("03CQ3ZZ", "Left Vertebral Artery - Trans Catheter Thrombectomy")
            procedure_header:add_code_link("3E05317", "Peripheral Artery Thrombectomy")
            procedure_header:add_code_link("03CP0ZZ", "Right Vertebral Artery - Open Thrombectomy")
            procedure_header:add_code_link("03CP3ZZ", "Right Vertebral Artery - Trans Catheter Thrombectomy")
            procedure_header:add_code_link("03CH0ZZ",
                "Thrombectomy or Endarterectomy Common carotid artery - Open Thrombectomy")
            procedure_header:add_code_link(
                "03CH3ZZ",
                "Thrombectomy or Endarterectomy Common carotid artery - Trans Catheter Thrombectomy"
            )
            procedure_header:add_code_link("03CY0ZZ", "Upper Artery - Open Thrombectomy")
            procedure_header:add_code_link("03CY3ZZ", "Upper Artery - Trans Catheter Thrombectomy")

            local r4182_code = links.get_code_link { code = "R41.82", text = "Altered Level Of Consciousness" }
            local altered_level_of_consciousness =
                links.get_abstraction_link {
                    code = "ALTERED_LEVEL_OF_CONSCIOUSNESS",
                    text = "Altered Level Of Consciousness"
                }
            if r4182_code ~= nil then
                vital_signs_header:add_link(r4182_code)
                if altered_level_of_consciousness ~= nil then
                    altered_level_of_consciousness.hidden = true
                end
                vital_signs_header:add_link(altered_level_of_consciousness)
            else
                vital_signs_header:add_link(altered_level_of_consciousness)
            end

            vital_signs_header:add_discrete_value_one_of_link(
                {
                    "BP Arterial Diastolic cc (mm Hg)",
                    "DBP 3.5 (No Calculation) (mmhg)",
                    "DBP 3.5 (No Calculation) (mm Hg)"
                },
                "DBP",
                function(dv_, number)
                    return number > 110
                end
            )
            vital_signs_header:add_discrete_value_link(
                "SBP 3.5 (No Calculation) (mm Hg)",
                "SBP",
                function(dv_, number)
                    return number > 180
                end
            )
            vital_signs_header:add_abstraction_link("NIH_STROKE_SCALE_MINOR_CURRENT", "Current NIH Stroke Score")
            vital_signs_header:add_abstraction_link("NIH_STROKE_SCALE_MODERATE_CURRENT", "Current NIH Stroke Score")
            vital_signs_header:add_abstraction_link(
                "NIH_STROKE_SCALE_MODERATE_TO_SEVERE_CURRENT",
                "Current NIH Stroke Score"
            )
            vital_signs_header:add_abstraction_link("NIH_STROKE_SCALE_SEVERE_CURRENT", "Current NIH Stroke Score")
            vital_signs_header:add_abstraction_link("NIH_STROKE_SCALE_MINOR_INITIAL", "Initial NIH Stroke Score")
            vital_signs_header:add_abstraction_link("NIH_STROKE_SCALE_MODERATE_INITIAL", "Initial NIH Stroke Score")
            vital_signs_header:add_abstraction_link(
                "NIH_STROKE_SCALE_MODERATE_TO_SEVERE_INITIAL",
                "Initial NIH Stroke Score"
            )
            vital_signs_header:add_abstraction_link("NIH_STROKE_SCALE_SEVERE_INITIAL", "Initial NIH Stroke Score")

            ----------------------------------------
            --- Result Finalization
            ----------------------------------------
            compile_links()
        end
    end
end
