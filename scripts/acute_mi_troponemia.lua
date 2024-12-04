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
require("libs.common")



--------------------------------------------------------------------------------
--- Setup
--------------------------------------------------------------------------------
local heartRateDvNames = {
    "Heart Rate cc (bpm)",
    "3.5 Heart Rate (Apical) (bpm)",
    "3.5 Heart Rate (Other) (bpm)",
    "3.5 Heart Rate (Radial) (bpm)",
    "SCC Monitor Pulse (bpm)"
}
local highHeartRatePredicate = function(dv) return GetDvValueNumber(dv) > 90 end
local lowHeartRatePredicate = function(dv) return GetDvValueNumber(dv) < 60 end
local hematocritDvNames = { "HEMATOCRIT (%)", "HEMATOCRIT" }
local femaleLowHematocritPredicate = function(dv) return GetDvValueNumber(dv) < 34 end
local maleLowHematocritPredicate = function(dv) return GetDvValueNumber(dv) < 40 end
local hemogloblinDvNames = { "HEMOGLOBIN (g/dL)", "HEMOGLOBIN" }
local maleLowHemoglobinPredicate = function(dv) return GetDvValueNumber(dv) < 13.5 end
local femaleLowHemoglobinPredicate = function(dv) return GetDvValueNumber(dv) < 11.6 end
local mapDvNames = { "MAP Non-Invasive (Calculated) (mmHg)", "MPA Invasive (mmHg)" }
local lowMapPredicate = function(dv) return GetDvValueNumber(dv) < 70 end
local oxygenDvNames = { "DELIVERY" }
local paO2DvNames = { "BLD GAS O2 (mmHg)", "PO2 (mmHg)" }
local lowPaO21Predicate = function(dv) return GetDvValueNumber(dv) < 80 end
local sbpDvNames = { "SBP 3.5 (No Calculation) (mmHg)" }
local lowSbpPredicate = function(dv) return GetDvValueNumber(dv) < 90 end
local highSbpPredicate = function(dv) return GetDvValueNumber(dv) > 180 end
local spO2DvNames = { "Pulse Oximetry(Num) (%)" }
local lowSpO21Predicate = function(dv) return GetDvValueNumber(dv) < 90 end
local dvTroponinNames = { "TROPONIN, HIGH SENSITIVITY (ng/L)" }
local highTroponinPredicate = function(dv) return GetDvValueNumber(dv) > 59 end

local existingAlert = GetExistingCdiAlert { scriptName = ScriptName }



--------------------------------------------------------------------------------
--- Additional Pre-conditions
--------------------------------------------------------------------------------
local stemicodeDictionary = {
    ["I21.01"] = "ST Elevation (STEMI) Myocardial Infarction Involving Left Main Coronary Artery",
    ["I21.02"] = "ST Elevation (STEMI) Myocardial Infarction Involving Left Anterior Descending Coronary Artery",
    ["I21.09"] = "ST Elevation (STEMI) Myocardial Infarction Involving Other Coronary Artery Of Anterior Wall",
    ["I21.11"] = "ST Elevation (STEMI) Myocardial Infarction Involving Right Coronary Artery",
    ["I21.19"] = "ST Elevation (STEMI) Myocardial Infarction Involving Other Coronary Artery Of Inferior Wall",
    ["I21.21"] = "ST Elevation (STEMI) Myocardial Infarction Involving Left Circumflex Coronary Artery",
    ["I21.29"] = "ST Elevation (STEMI) Myocardial Infarction Involving Other Sites",
    ["I21.3"] = "ST Elevation (STEMI) Myocardial Infarction of Unspecified Site"
}
local othercodeDictionary = {
    ["I21.A1"] = "Myocardial Infarction Type 2",
    ["I21.A9"] = "Other Myocardial Infarction Type",
    ["I21.B"] = "Myocardial Infarction with Coronary Microvascular Dysfunction",
    ["I5A"] = "Non-Ischemic Myocardial Injury (Non-Traumatic)",
}
local accountStemiCodes = GetAccountCodesInDictionary(stemicodeDictionary, Account)
local accountOtherCodes = GetAccountCodesInDictionary(othercodeDictionary, Account)

local i214Code = GetCodeLinks { code = "I21.4", text = "Non-ST Elevation (NSTEMI) Myocardial Infarction" }
local codeCount = 0
if #accountStemiCodes > 0 then
    codeCount = codeCount + 1
end
if #accountOtherCodes > 0 then
    codeCount = codeCount + 1
end
if i214Code then
    codeCount = codeCount + 1
end
local triggerAlert = not existingAlert or (existingAlert.outcome ~= "AUTORESOLVED" and existingAlert.reason ~= "Previously Autoresolved")



if
    (not existingAlert or not existingAlert.validated) or
    (not existingAlert and existingAlert.outcome == "AUTORESOLVED" and existingAlert.validated and codeCount > 0)
then
    --------------------------------------------------------------------------------
    --- Top-Level Link Header Variables
    --------------------------------------------------------------------------------
    local resultLinks = {}
    local documentedDxHeader = MakeHeaderLink("Documented Dx")
    local documentedDxLinks= {}
    local laboratoryStudiesHeader = MakeHeaderLink("Laboratory Studies")
    local laboratoryStudiesLinks = {}
    local vitalSignsIntakeHeader = MakeHeaderLink("Vital Signs/Intake and Output Data")
    local vitalSignsIntakeLinks = {}
    local clinicalEvidenceHeader = MakeHeaderLink("Clinical Evidence")
    local clinicalEvidenceLinks = {}
    local oxygenationVentilationHeader = MakeHeaderLink("Oxygenation/Ventilation")
    local oxygenationVentilationLinks = {}
    local treatmentAndMonitoringHeader = MakeHeaderLink("Treatment and Monitoring")
    local treatmentAndMonitoringLinks = {}
    local ekgHeader = MakeHeaderLink("EKG")
    local ekgLinks = {}
    local echoHeader = MakeHeaderLink("Echo")
    local echoLinks = {}
    local ctHeader = MakeHeaderLink("CT")
    local ctLinks = {}
    local heartCathHeader = MakeHeaderLink("Heart Cath")
    local heartCathLinks = {}
    local troponinHeader = MakeHeaderLink("Troponin")
    local troponinLinks = {}



    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Documented Dx
    local i219CodeLink = GetCodeLink { code = "I21.9", text = "Acute Myocardial Infarction Unspecified" }
    local r778CodeLink = GetCodeLink { code = "R77.8", text = "Other Specified Abnormalities of Plasma Proteins" }
    local i21A1CodeLink = GetCodeLink { code = "I21.A1", text = "Myocardial Infarction Type 2" }
    -- Clinical Evidence (Abstractions)
    local r07CodeLink = GetCodeLink { codes = { "R07.89", "R07.9" }, text = "Chest Pain" } or {}
    local i2489CodeLink = GetCodeLink { code = "I24.89", text = "Demand Ischemia" }
    local irregularEKGFindingsAbstractionLink = GetAbstractionLink { code = "IRREGULAR_EKG_FINDINGS_MI", text = "Irregular EKG Finding" }
    -- Medications
    local antiplatlet2MedicationLink = GetMedicationLink { cat = "Antiplatelet 2" }
    local aspirinMedicationLink = GetMedicationLink { cat = "Aspirin" }
    local heparinMedicationLink = GetMedicationLink { cat = "Heparin" }
    local morphineMedicationLink = GetMedicationLink { cat = "Morphine" }
    local nitroglycerinMedicationLink = GetMedicationLink { cat = "Nitroglycerin" }
    -- Laboratory Studies
    GetDvValuesAsSingleLink {
        account = Account,
        dvNames = dvTroponinNames,
        linkText = "Troponin T High Sensitivity: (DATE1, DATE2) - ",
        target = troponinLinks
    }
    local highTroponinDiscreteValueLinks = GetDiscreteValueLinks { dvNames = dvTroponinNames, predicate = highTroponinPredicate, maxPerValue = 10 }



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    -- Autresolve
    if codeCount == 1 and not i2489CodeLink and Result.passed then
        if #accountStemiCodes > 0 then
            local desc = stemicodeDictionary[accountStemiCodes[1]]
            local codeLink = GetCodeLink {
                code = accountStemiCodes[1],
                text = "Autoresolved Specified Code - " .. desc
            }
            table.insert(documentedDxLinks, codeLink)
        end
        if #accountOtherCodes > 0 then
            local desc = othercodeDictionary[accountOtherCodes[1]]
            local codeLink = GetCodeLink {
                code = accountOtherCodes[1],
                text = "Autoresolved Specified Code - " .. desc
            }
            table.insert(documentedDxLinks, codeLink)
        end
        if i214Code then
            table.insert(documentedDxLinks, i214Code)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    -- Alert Acute MI Conflicting Dx
    elseif codeCount > 1 then
        if #accountStemiCodes > 0 then
            local desc = stemicodeDictionary[accountStemiCodes[1]]
            local codeLink = GetCodeLink {
                code = accountStemiCodes[1],
                text = "Autoresolved Specified Code - " .. desc
            }
            table.insert(documentedDxLinks, codeLink)
        end
        if #accountOtherCodes > 0 then
            local desc = othercodeDictionary[accountOtherCodes[1]]
            local codeLink = GetCodeLink {
                code = accountOtherCodes[1],
                text = "Autoresolved Specified Code - " .. desc
            }
            table.insert(documentedDxLinks, codeLink)
        end
        if i214Code then
            table.insert(documentedDxLinks, i214Code)
        end
        if existingAlert and existingAlert.validated then
            Result.validated = false
            Result.outcome = ""
            Result.reason = "Previously Autoresolved"
        end
        Result.subtitle = "Acute MI Conflicting Dx"
        Result.passed = true

    -- Alert Acute MI Type 2 and Demand Ischemia Documented Seek Clarification
    elseif triggerAlert and i21A1CodeLink and i2489CodeLink then
        table.insert(documentedDxLinks, i21A1CodeLink)
        table.insert(documentedDxLinks, i2489CodeLink)
        Result.subtitle = "Acute MI Type 2 and Demand Ischemia Documented Seek Clarification"
        Result.passed = true

    -- Alert Possible Acute MI Type 2
    elseif
        triggerAlert and
        codeCount == 0 and
        (
            (#highTroponinDiscreteValueLinks > 0) or
            i219CodeLink
        ) and
        i2489CodeLink
    then
        table.insert(documentedDxLinks, i2489CodeLink)
        table.insert(documentedDxLinks, i219CodeLink)
        Result.subtitle = "Possible Acute MI Type 2"
        Result.passed = true

    -- Alert Acute MI Type Needs Clarification
    elseif triggerAlert and codeCount > 0 and i2489CodeLink then
        table.insert(documentedDxLinks, i2489CodeLink)
        if #accountStemiCodes > 0 then
            local desc = stemicodeDictionary[accountStemiCodes[1]]
            local codeLink = GetCodeLink {
                code = accountStemiCodes[1],
                text = "Autoresolved Specified Code - " .. desc
            }
            table.insert(documentedDxLinks, codeLink)
        end
        if #accountOtherCodes > 0 then
            local desc = othercodeDictionary[accountOtherCodes[1]]
            local codeLink = GetCodeLink {
                code = accountOtherCodes[1],
                text = "Autoresolved Specified Code - " .. desc
            }
            table.insert(documentedDxLinks, codeLink)
        end
        table.insert(documentedDxLinks, i214Code)
        Result.subtitle = "Acute MI Type Needs Clarification"
        Result.passed = true

    -- Alert Acute MI Unspecified Present Confirm if Further Specification of Type Needed
    elseif triggerAlert and i219CodeLink then
        table.insert(documentedDxLinks, i219CodeLink)
        Result.subtitle = "Acute MI Unspecified Present Confirm if Further Specification of Type Needed"
        Result.passed = true

    -- Alert Possible Acute MI
    elseif triggerAlert and #highTroponinDiscreteValueLinks > 0 and irregularEKGFindingsAbstractionLink then
        Result.subtitle = "Possible Acute MI"
        Result.passed = true

    -- Alert Possible Acute MI
    elseif
        triggerAlert and
        (r07CodeLink or #highTroponinDiscreteValueLinks > 0) and
        heparinMedicationLink and
        (morphineMedicationLink or nitroglycerinMedicationLink) and
        aspirinMedicationLink and
        antiplatlet2MedicationLink
    then
        table.insert(treatmentAndMonitoringLinks, heparinMedicationLink)
        Result.subtitle = "Possible Acute MI"
        Result.passed = true

    -- Alert Elevanted Tropins Present
    elseif triggerAlert and #highTroponinDiscreteValueLinks > 0 then
        Result.subtitle = "Elevanted Tropins Present"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Clinical Evidence
            GetCodeLink { code = "R94.39", text = "Abnormal Cardiovascular Function Study", target = clinicalEvidenceLinks, seq = 1 }
            GetCodeLink { code = "D62", text = "Acute Blood Loss Anemia", target = clinicalEvidenceLinks, seq = 2 }
            GetCodeLink { code = "I24.81", text = "Acute Coronary microvascular Dysfunction", target = clinicalEvidenceLinks, seq = 3 }
            GetCodeLink {
                codes = { "N17.0", "N17.1", "N17.2", "K76.7", "K91.83" },
                text = "Acute Kidney Failure",
                target = clinicalEvidenceLinks,
                seq = 4
            }
            GetCodeLink { code = "I20.9", text = "Angina", target = clinicalEvidenceLinks, seq = 5 }
            GetCodeLink { code = "I20.81", text = "Angina Pectoris with Coronary Microvascular Dysfunction", target = clinicalEvidenceLinks, seq = 6 }
            GetCodeLink { code = "I20.1", text = "Angina Pectoris with Documented Spasm/with Coronary Vasospasm", target = clinicalEvidenceLinks, seq = 7 }
            GetAbstractionLink { code = "ATRIAL_FIBRILLATION_WITH_RVR", text = "Atrial Fibrillation with RVR", target = clinicalEvidenceLinks, seq = 8 }
            GetCodeLink { code = "I46.9", text = "Cardiac Arrest, Cause Unspecified", target = clinicalEvidenceLinks, seq = 9 }
            GetCodeLink { code = "I46.8", text = "Cardiac Arrest Due to Other Underlying Condition", target = clinicalEvidenceLinks, seq = 10 }
            GetCodeLink { code = "I46.2", text = "Cardiac Arrest due to Underlying Cardiac Condition", target = clinicalEvidenceLinks, seq = 11 }
            GetCodePrefixLink { prefix = "I42%.", text = "Cardiomyopathy Dx", target = clinicalEvidenceLinks, seq = 12 }
            GetCodePrefixLink { prefix = "I43%.", text = "Cardiomyopathy Dx", target = clinicalEvidenceLinks, seq = 13 }
            table.insert(clinicalEvidenceLinks, r07CodeLink)
            GetCodeLink { code = "I25.85", text = "Chronic Coronary Microvascular Dysfunction", target = clinicalEvidenceLinks, seq = 15 }
            GetCodeLink {
                codes = { "N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5" },
                text = "Chronic Kidney Failure",
                target = clinicalEvidenceLinks,
                seq = 16
            }
            GetCodeLink { code = "I44.2", text = "Complete Heart Block", target = clinicalEvidenceLinks, seq = 17 }
            GetCodeLink { code = "J44.1", text = "COPD Exacerbation", target = clinicalEvidenceLinks, seq = 18 }
            GetCodeLink { code = "Z98.61", text = "Coronary Angioplasty Hx", target = clinicalEvidenceLinks, seq = 19 }
            GetCodeLink { code = "Z95.5", text = "Coronary Angioplasty Implant and Graft Hx", target = clinicalEvidenceLinks, seq = 20 }
            GetCodeLink { code = "I25.10", text = "Coronary Artery Disease", target = clinicalEvidenceLinks, seq = 21 }
            GetCodeLink { code = "I25.119", text = "Coronary Artery Disease with Angina", target = clinicalEvidenceLinks, seq = 22 }

            GetCodeLink {
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
                target = clinicalEvidenceLinks,
                seq = 24
            }
            GetAbstractionLink { code = "DYSPNEA_ON_EXERTION", text = "Dyspnea On Exertion", target = clinicalEvidenceLinks, seq = 25 }
            GetAbstractionLink { code = "PRESERVED_EJECTION_FRACTION", text = "Ejection Fraction", target = clinicalEvidenceLinks, seq = 26 }
            GetAbstractionLink { code = "PRESERVED_EJECTION_FRACTION_2", text = "Ejection Fraction", target = clinicalEvidenceLinks, seq = 27 }
            GetAbstractionLink { code = "REDUCED_EJECTION_FRACTION", text = "Ejection Fraction", target = clinicalEvidenceLinks, seq = 28 }
            GetAbstractionLink { code = "MODERATELY_REDUCED_EJECTION_FRACTION", text = "Ejection Fraction", target = clinicalEvidenceLinks, seq = 29 }
            GetAbstractionLink { code = "ELEVATED_TROPONINS", text = "Elevated Tropinins", target = clinicalEvidenceLinks, seq = 30 }
            GetCodeLink { code = "N18.6", text = "End-Stage Renal Disease", target = clinicalEvidenceLinks, seq = 31 }
            GetCodePrefixLink { prefix = "I38%.", text = "Endocarditis Dx", target = clinicalEvidenceLinks, seq = 32 }
            GetCodePrefixLink { prefix = "I39%.", text = "Endocarditis Dx", target = clinicalEvidenceLinks, seq = 33 }
            GetCodeLink {
                codes = {
                    "I50.1", "I50.20", "I50.22", "I50.23", "I50.30", "I50.32", "I50.33", "I50.40", "I50.42", "I50.43",
                    "I50.810", "I50.812", "I50.813", "I50.84", "I50.89", "I50.9"
                },
                text = "Heart Failure",
                target = clinicalEvidenceLinks,
                seq = 34
            }
            GetCodeLink { code = "Z95.1", text = "History of CABG", target = clinicalEvidenceLinks, seq = 35 }
            GetCodeLink { code = "I16.1", text = "Hypertensive Emergency", target = clinicalEvidenceLinks, seq = 36 }
            GetCodeLink { code = "I16.0", text = "Hypertensive Urgency", target = clinicalEvidenceLinks, seq = 37 }
            GetCodeLink { code = "E86.1", text = "Hypovolemia", target = clinicalEvidenceLinks, seq = 38 }
            GetCodeLink { code = "R09.02", text = "Hypoxemia", target = clinicalEvidenceLinks, seq = 39 }
            GetCodeLink { code = "I47.11", text = "Inappropriate Sinus Tachycardia, So Stated", target = clinicalEvidenceLinks, seq = 40 }
            GetAbstractionLink { code = "IRREGULAR_ECHO_FINDING", text = "Irregular Echo Finding", target = clinicalEvidenceLinks, seq = 41 }
            GetCodeLink { code = "R94.31", text = "Irregular Echo Finding", target = clinicalEvidenceLinks, seq = 42 }
            table.insert(clinicalEvidenceLinks, irregularEKGFindingsAbstractionLink)
            GetCodeLink { codes = { "44A023N7", "44A023N8" }, text = "Left Heart Cath", target = clinicalEvidenceLinks, seq = 44 }
            GetCodePrefixLink { prefix = "I40%.", text = "Myocarditis Dx", target = clinicalEvidenceLinks, seq = 45 }
            GetCodeLink { code = "I35.0", text = "Non-Rheumatic Aortic Valve Stenosis", target = clinicalEvidenceLinks, seq = 46 }
            GetCodeLink { code = "I35.1", text = "Non-Rheumatic Aortic Valve Insufficiency", target = clinicalEvidenceLinks, seq = 47 }
            GetCodeLink { code = "I35.2", text = "Non-Rheumatic Aortic Valve Stenosis with Insufficiency", target = clinicalEvidenceLinks, seq = 48 }
            GetCodeLink { code = "I25.2", text = "Old MI", target = clinicalEvidenceLinks, seq = 49 }
            GetCodeLink { code = "I20.8", text = "Other Angina Pectoris", target = clinicalEvidenceLinks, seq = 50 }
            GetCodeLink { code = "I47.19", text = "Other Supraventricular Tachycardia", target = clinicalEvidenceLinks, seq = 51 }
            GetCodePrefixLink { prefix = "I47%.", text = "Paroxysmal Tachycardia Dx", target = clinicalEvidenceLinks, seq = 52 }
            GetCodePrefixLink { prefix = "I30%.", text = "Pericarditis Dx", target = clinicalEvidenceLinks, seq = 53 }
            GetCodePrefixLink { prefix = "I26%.", text = "Pulmonary Embolism Dx", target = clinicalEvidenceLinks, seq = 54 }
            GetCodeLink {
                codes = {
                    "I27.0", "I27.20", "I27.21", "I27.22", "I27.23", "I27.24", "I27.29"
                },
                text = "Pulmonary Hypertension",
                target = clinicalEvidenceLinks,
                seq = 55
            }
            GetCodeLink {
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
                target = clinicalEvidenceLinks,
                seq = 56
            }
            GetCodeLink { codes = { "M62.82", "T79.6XXA", "T79.6XXD", "T79.6XXS" }, text = "Rhabdomyolysis", target = clinicalEvidenceLinks, seq = 57 }
            GetCodeLink { code = "4A023N6", text = "Right Heart Cath", target = clinicalEvidenceLinks, seq = 58 }
            GetCodeLink { code = "I20.2", text = "Refractory Angina Pectoris", target = clinicalEvidenceLinks, seq = 59 }
            GetAbstractionLink { code = "RESOLVING_TROPONINS", text = "Resolving Troponins", target = clinicalEvidenceLinks, seq = 60 }
            GetCodePrefixLink { prefix = "A40%.", text = "Sepsis Dx", target = clinicalEvidenceLinks, seq = 61 }
            GetCodePrefixLink { prefix = "A41%.", text = "Sepsis Dx", target = clinicalEvidenceLinks, seq = 62 }
            GetCodeLink {
                codes = {
                    "A42.7", "A22.7", "B37.7", "A26.7", "A54.86", "B00.7", "A32.7", "A24.1", "A20.7", "R65.20", "R65.21", 
                    "T81.44XA", "T81.44XD", "T81.44XS"
                },
                text = "Sepsis Dx",
                target = clinicalEvidenceLinks,
                seq = 63
            }
            GetAbstractionLink { code = "SHORTNESS_OF_BREATH", text = "Shortness of Breath", target = clinicalEvidenceLinks, seq = 64 }
            GetCodeLink { code = "I47.10", text = "Supraventricular Tachycardia, Unspecified", target = clinicalEvidenceLinks, seq = 65 }
            GetCodeLink { code = "I51.81", text = "Takotsubo Syndrome", target = clinicalEvidenceLinks, seq = 66 }
            GetCodeLink { code = "I25.82", text = "Total Occlusion of Coronary Artery", target = clinicalEvidenceLinks, seq = 67 }
            GetCodeLink { codes = { "I35.8", "I35.9" }, text = "Unspecified Non-Rheumatic Aortic Valve Disorders", target = clinicalEvidenceLinks, seq = 68 }
            GetCodeLink { code = "I20.0", text = "Unstable Angina", target = clinicalEvidenceLinks, seq = 69 }
            GetCodeLink { code = "I49.01", text = "Ventricular Fibrillation", target = clinicalEvidenceLinks, seq = 70 }
            GetCodeLink { code = "I49.02", text = "Ventricular Flutter", target = clinicalEvidenceLinks, seq = 71 }
            GetAbstractionLink { code = "WALL_MOTION_ABNORMALITIES", text = "Wall Motion Abnormalities", target = clinicalEvidenceLinks, seq = 72 }

            -- EKG/Echo/HeartCath/CT Document Links
            GetDocumentLink { documentType = "ECG", text = "ECG", target = ekgLinks }
            GetDocumentLink { documentType = "Electrocardiogram Adult   ECGR", text = "Electrocardiogram Adult   ECGR", target = ekgLinks }
            GetDocumentLink { documentType = "ECG Adult", text = "ECG Adult", target = ekgLinks }
            GetDocumentLink { documentType = "RestingECG", text = "RestingECG", target = ekgLinks }
            GetDocumentLink { documentType = "EKG", text = "EKG", target = ekgLinks }
            GetDocumentLink { documentType = "ECHOTE  CVSECHOTE", text = "ECHOTE  CVSECHOTE", target = echoLinks }
            GetDocumentLink { documentType = "ECHO 2D Comp Adult CVSECH2DECHO", text = "ECHO 2D Comp Adult CVSECH2DECHO", target = echoLinks }
            GetDocumentLink { documentType = "Echo Complete Adult 2D", text = "Echo Complete Adult 2D", target = echoLinks }
            GetDocumentLink { documentType = "Echo Comp W or WO Contrast", text = "Echo Comp W or WO Contrast", target = echoLinks }
            GetDocumentLink { documentType = "ECHO Stress ECHO  CVSECHSTR", text = "ECHO Stress ECHO  CVSECHSTR", target = echoLinks }
            GetDocumentLink { documentType = "Stress Echocardiogram CVS", text = "Stress Echocardiogram CVS", target = echoLinks }
            GetDocumentLink { documentType = "CVSECH2DECHO", text = "CVSECH2DECHO", target = echoLinks }
            GetDocumentLink { documentType = "CVSECHOTE", text = "CVSECHOTE", target = echoLinks }
            GetDocumentLink { documentType = "CVSECHORECHO", text = "CVSECHORECHO", target = echoLinks }
            GetDocumentLink { documentType = "CVSECH2DECHOLIMITED", text = "CVSECH2DECHOLIMITED", target = echoLinks }
            GetDocumentLink { documentType = "CVSECHOPC", text = "CVSECHOPC", target = echoLinks }
            GetDocumentLink { documentType = "CVSECHSTRAINECHO", text = "CVSECHSTRAINECHO", target = echoLinks }
            GetDocumentLink { documentType = "Heart Cath", text = "Heart Cath", target = heartCathLinks }
            GetDocumentLink { documentType = "Cath Report", text = "Cath Report", target = heartCathLinks }
            GetDocumentLink { documentType = "Cardiac Cath, PTCA, EP findings", text = "Cardiac Cath, PTCA, EP findings", target = heartCathLinks }
            GetDocumentLink { documentType = "CATHEOC", text = "CATHEOC", target = heartCathLinks }
            GetDocumentLink { documentType = "Cath Lab Procedures", text = "Cath Lab Procedures", target = heartCathLinks }
            GetDocumentLink { documentType = "CT Thorax W", text = "CT Thorax W", target = ctLinks }
            GetDocumentLink { documentType = "CTA Thorax Aorta", text = "CTA Thorax Aorta", target = ctLinks }
            GetDocumentLink { documentType = "CT Thorax WO-Abd WO-Pel WO", text = "CT Thorax WO-Abd WO-Pel WO", target = ctLinks }
            GetDocumentLink { documentType = "CT Thorax WO", text = "CT Thorax WO", target = ctLinks }
            
            -- Labs
            GetDiscreteValueLink {
                discreteValueNames = hemogloblinDvNames,
                text = "Hemoglobin",
                target = laboratoryStudiesLinks,
                predicate =
                    (not Account.patient or Account.patient.gender == "F") and
                    femaleLowHemoglobinPredicate or
                    maleLowHemoglobinPredicate
            }
            GetDiscreteValueLink {
                discreteValueNames = hematocritDvNames,
                text = "Hematocrit",
                target = laboratoryStudiesLinks,
                predicate =
                    (not Account.patient or Account.patient.gender == "F") and
                    femaleLowHematocritPredicate or
                    maleLowHematocritPredicate
            }

            -- Lab Subheadings
            for _, link in ipairs(highTroponinDiscreteValueLinks) do
                table.insert(troponinLinks, link)
            end

            -- Medications
            GetMedicationLink { cat = "Ace Inhibitor", text = "", target = treatmentAndMonitoringLinks, seq = 1 }
            GetMedicationLink { cat = "Antianginal Medication", text = "", target = treatmentAndMonitoringLinks, seq = 2 }
            GetAbstractionLink { code = "ANTIANGINAL_MEDICATION", text = "", target = treatmentAndMonitoringLinks, seq = 3 }
            GetMedicationLink { cat = "Anticoagulant", text = "", target = treatmentAndMonitoringLinks, seq = 4 }
            GetAbstractionLink { code = "ANTICOAGULANT", text = "", target = treatmentAndMonitoringLinks, seq = 5 }
            GetMedicationLink { cat = "Antiplatelet", text = "", target = treatmentAndMonitoringLinks, seq = 6 }
            table.insert(treatmentAndMonitoringLinks, antiplatlet2MedicationLink)
            GetAbstractionLink { code = "ANTIPLATELET", text = "", target = treatmentAndMonitoringLinks, seq = 8 }
            table.insert(treatmentAndMonitoringLinks, aspirinMedicationLink)
            GetMedicationLink { cat = "Beta Blocker", text = "", target = treatmentAndMonitoringLinks, seq = 10 }
            GetAbstractionLink { code = "BETA_BLOCKER", text = "", target = treatmentAndMonitoringLinks, seq = 11 }
            GetMedicationLink { cat = "Calcium Channel Blockers", text = "", target = treatmentAndMonitoringLinks, seq = 12 }
            GetAbstractionLink { code = "CALCIUM_CHANNEL_BLOCKER", text = "", target = treatmentAndMonitoringLinks, seq = 13 }
            table.insert(treatmentAndMonitoringLinks, morphineMedicationLink)
            table.insert(treatmentAndMonitoringLinks, nitroglycerinMedicationLink)
            GetAbstractionLink { code = "NITROGLYCERIN", text = "", target = treatmentAndMonitoringLinks, seq = 19 }
            GetMedicationLink { cat = "Statin", text = "", target = treatmentAndMonitoringLinks, seq = 20 }
            GetAbstractionLink { code = "STATIN", text = "", target = treatmentAndMonitoringLinks, seq = 21 }

            -- Oxygen
            GetDiscreteValueLink {
                discreteValueNames = oxygenDvNames,
                text = "Oxygen Therapy",
                target = oxygenationVentilationLinks,
                seq = 1,
                predicate = function(dv)
                    -- Return true if dv.result contains the pattern "%bRoom Air%b"
                    return
                        dv.result:find("%bRoom Air%b") ~= nil and
                        dv.result:find("%bRA%b") == nil
                end
            }
            GetAbstractionLink { code = "OXYGEN_THERAPY", text = "Oxygen Therapy", target = oxygenationVentilationLinks, seq = 2 }

            -- Vitals
            GetDiscreteValueLink {
                discreteValueNames = paO2DvNames,
                text = "Arterial P02",
                target = vitalSignsIntakeLinks,
                seq = 1,
                predicate = lowPaO21Predicate
            }
            GetDiscreteValueLink {
                discreteValueNames = heartRateDvNames,
                text = "Heart Rate",
                target = vitalSignsIntakeLinks,
                seq = 2,
                predicate = highHeartRatePredicate
            }
            GetDiscreteValueLink {
                discreteValueNames = heartRateDvNames,
                text = "Heart Rate",
                target = vitalSignsIntakeLinks,
                seq = 3,
                predicate = lowHeartRatePredicate
            }
            GetDiscreteValueLink {
                discreteValueNames = mapDvNames,
                text = "MAP",
                target = vitalSignsIntakeLinks,
                seq = 4,
                predicate = lowMapPredicate
            }
            GetDiscreteValueLink {
                discreteValueNames = spO2DvNames,
                text = "Sp02",
                target = vitalSignsIntakeLinks,
                seq = 5,
                predicate = lowSpO21Predicate
            }
            GetDiscreteValueLink {
                discreteValueNames = sbpDvNames,
                text = "SBP",
                target = vitalSignsIntakeLinks,
                seq = 6,
                predicate = lowSbpPredicate
            }
            GetDiscreteValueLink {
                discreteValueNames = sbpDvNames,
                text = "SBP",
                target = vitalSignsIntakeLinks,
                seq = 7,
                predicate = highSbpPredicate
            }
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        if #troponinLinks > 0 then
            troponinHeader.links = troponinLinks
            table.insert(laboratoryStudiesLinks, troponinHeader)
        end
        if #documentedDxLinks > 0 then
            documentedDxHeader.links = documentedDxLinks
            table.insert(resultLinks, documentedDxHeader)
        end
        if #clinicalEvidenceLinks > 0 then
            clinicalEvidenceHeader.links = clinicalEvidenceLinks
            table.insert(resultLinks, clinicalEvidenceHeader)
        end
        if #laboratoryStudiesLinks > 0 then
            laboratoryStudiesHeader.links = laboratoryStudiesLinks
            table.insert(resultLinks, laboratoryStudiesHeader)
        end
        if #vitalSignsIntakeLinks > 0 then
            vitalSignsIntakeHeader.links = vitalSignsIntakeLinks
            table.insert(resultLinks, vitalSignsIntakeHeader)
        end
        if #treatmentAndMonitoringLinks > 0 then
            treatmentAndMonitoringHeader.links = treatmentAndMonitoringLinks
            table.insert(resultLinks, treatmentAndMonitoringHeader)
        end
        if #oxygenationVentilationLinks > 0 then
            oxygenationVentilationHeader.links = oxygenationVentilationLinks
            table.insert(resultLinks, oxygenationVentilationHeader)
        end
        if #ekgLinks > 0 then
            ekgHeader.links = ekgLinks
            table.insert(resultLinks, ekgHeader)
        end
        if #echoLinks > 0 then
            echoHeader.links = echoLinks
            table.insert(resultLinks, echoHeader)
        end
        if #ctLinks > 0 then
            ctHeader.links = ctLinks
            table.insert(resultLinks, ctHeader)
        end
        if #heartCathLinks > 0 then
            heartCathHeader.links = heartCathLinks
            table.insert(resultLinks, heartCathHeader)
        end

        if existingAlert then
            resultLinks = MergeLinks(existingAlert.links, resultLinks)
        end
        Result.links = resultLinks
    end
end
