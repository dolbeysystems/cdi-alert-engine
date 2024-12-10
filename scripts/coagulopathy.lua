-----------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Coagulopathy
---
--- This script checks an account to see if it matches the criteria for a coagulopathy alert.
---
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
-----------------------------------------------------------------------------------------------------------------------
---@diagnostic disable: unused-local, empty-block -- Remove once the script is filled out



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
local auto_evidence_text = "Autoresolved Evidence - "
local auto_code_text = "Autoresolved Code - "
local activated_clotting_time_dv_name = { "" }
local activated_clotting_time = function(x) return x > 120 end
local cryoprecipitate_discrete_value = { "" }
local ddimer_discrete_value = { "D-DIMER (mg/L FEU)" }
local ddimer_predicate_1 = function(x) return x >= 4 end
local ddimer_predicate_2 = lambda x: 0.48 <= x < 4
local fibrinogen_discrete_value = ["FIBRINOGEN (mg/dL)"]
local calcFibrinogen1 = lambda x: x < 200
local dvHomocysteineLevels = [""]
local calcHomocysteineLevels1 = lambda x: x > 15
local dvInr = ["INR"]
local calcInr1 = lambda x: x > 1.7
local calcInr2 = lambda x: 1.3 <= x < 1.7
local calcInr3 = 1.3
local dvPlasmaTransfusion = ["Volume (mL)-Transfuse Plasma (mL)"]
local dvPartialThromboplastinTime = ["PTT (SEC)"]
local calcPartialThromboplastinTime1 = 30.5
local dvPlateletCount = ["PLATELET COUNT (10x3/uL)"]
local calcPlateletCount1 = 150
local calcPlateletCount2 = lambda x: x < 50
local calcPlateletCount3 = lambda x: 50 <= x < 100
local dvPlateletTransfusion = [""]
local dvProteinCResistance = [""]
local calcProteinCResistance1 = lambda x: x < 2.3
local dvProthrombinTime = ["PROTIME (SEC)"]
local calcProthrombinTime1 = 13.0
local dvThrombinTime = ["THROMBIN CLOTTING TM"]
local calcThrombinTime1 = lambda x: x > 14
local calcAny1 = lambda x: x > 0



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
    local alert_code_dictionary = {
        ["D65"] = "Disseminated Intravascular Coagulation",
        ["D66"] = "Hereditary Factor VIII Deficiency",
        ["D67"] = "Hereditary Factor IX Deficiency",
        ["D68.0"] = "Von Willebrand Disease",
        ["D68.00"] = "Von Willebrand Disease, Unspecified",
        ["D68.01"] = "Von Willebrand Disease, Type 1",
        ["D68.02"] = "Von Willebrand Disease, Type 2",
        ["D68.020"] = "Von Willebrand Disease, Type 2A",
        ["D68.021"] = "Von Willebrand Disease, Type 2B",
        ["D68.022"] = "Von Willebrand Disease, Type 2M",
        ["D68.023"] = "Von Willebrand Disease, Type 2N",
        ["D68.03"] = "Von Willebrand Disease, Type 3",
        ["D68.04"] = "Acquired Von Willebrand Disease",
        ["D68.09"] = "Other Von Willebrand Disease",
        ["D68.1"] = "Hereditary Factor XI Deficiency",
        ["D68.2"] = "Hereditary Deficiency Of Other Clotting Factors",
        ["D68.311"] = "Acquired Hemophilia",
        ["D68.312"] = "Antiphospholipid Antibody With Hemorrhagic Disorder",
        ["D68.318"] = "Other Hemorrhagic Disorder Due To Intrinsic Circulating Anticoagulant, Antibodies, Or Inhibitors",
        ["D68.32"] = "Hemorrhagic Disorder Due To Extrinsic Circulating Anticoagulant",
        ["D68.4"] = "Acquired Coagulation Factor Deficiency",
        ["D68.5"] = "Primary Thrombophilia",
        ["D68.51"] = "Activated Protein C Resistance",
        ["D68.52"] = "Prothrombin Gene Mutation",
        ["D68.59"] = "Other Primary Thrombophilia",
        ["D68.6"] = "Other Thrombophilia",
        ["D68.61"] = "Antiphospholipid Syndrome",
        ["D68.62"] = "Lupus Anticoagulant Syndrome",
        ["D68.69"] = "Other Thrombophilia",
        ["D68.8"] = "Other Specified Coagulation Defects",
        ["D75.821"] = "Non-Immune Heparin-Induced Thrombocytopenia",
        ["D75.822"] = "Immune-Mediated Heparin-Induced Thrombocytopenia",
        ["D75.828"] = "Other Heparin-Induced Thrombocytopenia Syndrome",
        ["D75.829"] = "Heparin-Induced Thrombocytopenia, Unspecified",
        ["D68.9"] = "Coagulation Defect, Unspecified"
    }
    local account_alert_codes = codes.get_account_codes_in_dictionary(Account, alert_code_dictionary)



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------



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

