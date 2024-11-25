---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Acute MI Troponemia
---
--- This script checks an account to see if it matches the criteria for an acute MI troponemia alert.
---
--- Date: 4/10/2024
--- Version: 1.0
--- Site: (Default)
---------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Requires 
--------------------------------------------------------------------------------
require("libs.common")
require("libs.standard_cdi")



--------------------------------------------------------------------------------
--- Setup
--------------------------------------------------------------------------------
local alertCodeDictionary = {
    ["I21.01"] = "ST Elevation (STEMI) Myocardial Infarction Involving Left Main Coronary Artery",
    ["I21.02"] = "ST Elevation (STEMI) Myocardial Infarction Involving Left Anterior Descending Coronary Artery",
    ["I21.09"] = "ST Elevation (STEMI) Myocardial Infarction Involving Other Coronary Artery Of Anterior Wall",
    ["I21.11"] = "ST Elevation (STEMI) Myocardial Infarction Involving Right Coronary Artery",
    ["I21.19"] = "ST Elevation (STEMI) Myocardial Infarction Involving Other Coronary Artery Of Inferior Wall",
    ["I21.21"] = "ST Elevation (STEMI) Myocardial Infarction Involving Left Circumflex Coronary Artery",
    ["I21.29"] = "ST Elevation (STEMI) Myocardial Infarction Involving Other Sites",
    ["I21.A1"] = "Myocardial Infarction Type 2",
    ["I21.A9"] = "Other Myocardial Infarction Type",
    ["I21.B"] = "Myocardial Infarction with Coronary Microvascular Dysfunction",
    ["I5A"] = "Non-Ischemic Myocardial Injury (Non-Traumatic)"
}
local accountAlertCodes = GetAccountCodesInDictionary(Account, alertCodeDictionary)

local oxygenHeader = MakeHeaderLink("Oxygenation/Ventilation")
local ekgHeader = MakeHeaderLink("EKG")
local echoHeader = MakeHeaderLink("Echo")
local heartCathHeader = MakeHeaderLink("Heart Cath")
local ctHeader = MakeHeaderLink("CT")
local troponinHeader = MakeHeaderLink("Troponin")

local oxygenLinks = MakeLinkArray()
local ekgLinks = MakeLinkArray()
local echoLinks = MakeLinkArray()
local heartCathLinks = MakeLinkArray()
local ctLinks = MakeLinkArray()
local troponinLinks = MakeLinkArray()

local i214Code = MakeNilLink()
local i219Code = MakeNilLink()
local elevatedTroponinIDV = MakeNilLink()
local troponinTDV = MakeNilLink()
local troponinTAbs = MakeNilLink()
local irregularEKGFindingsAbs = MakeNilLink()
local r07Codes = MakeNilLink()
local i2489Code = MakeNilLink()
local antiplatlet2Med = MakeNilLink()
local aspirinMed = MakeNilLink()
local heparinMed = MakeNilLink()
local morphineMed = MakeNilLink()
local nitroglycerinMed = MakeNilLink()



--------------------------------------------------------------------------------
--- Alert Qualification 
--------------------------------------------------------------------------------
if not ExistingAlert or not ExistingAlert.validated then
    -- Documentation Includes
    i214Code = GetCodeLinks { code="I21.4", text="Non-ST Elevation (NSTEMI) Myocardial Infarction: " }
    i219Code = GetCodeLinks { code="I21.9", text="Acute MI Dx: " }
    elevatedTroponinIDV = GetDiscreteValueLinks {
        discreteValue="Elevated Troponin I",
        text="Troponin I",
        predicate = function(dv)
            return CheckDvResultNumber(dv, function(v) return v.result > 0.04 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end
    }
    if Account.patient.gender == "M" then
        troponinTDV = GetDiscreteValueLinks {
            discreteValue="hs Troponin (ng/L)",
            text="Troponin T High Sensitivity Male",
            predicate = function(dv)
                return CheckDvResultNumber(dv, function(v) return v.result > 22 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
            end
        }
        troponinTAbs = GetAbstractionValueLinks { code="ELEVATED_TROPONIN_T_HIGH_SENSITIVITY_MALE", text="Troponin T High Sensitivity Male" }
    elseif Account.patient.gender =="F" then
        troponinTDV = GetDiscreteValueLinks {
            discreteValue="hs Troponin (ng/L)",
            text="Troponin T High Sensitivity Female",
            predicate = function(dv)
                return CheckDvResultNumber(dv, function(v) return v.result > 14 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
            end
        }
        troponinTAbs = GetAbstractionValueLinks { code="ELEVATED_TROPONIN_T_HIGH_SENSITIVITY_FEMALE", text="Troponin T High Sensitivity Female" }
    end
    irregularEKGFindingsAbs = GetAbstractionValueLinks { code="IRREGULAR_EKG_FINDINGS_MI", text="Irregular EKG Finding" }
    r07Codes = GetCodeLinks { codes={"R07.89", "R07.9"}, text="Chest Pain" }

    -- Abs
    i2489Code = GetCodeLinks { code="I24.89", text="Demand Ischemia", seq=19 }

    -- Meds
    antiplatlet2Med = GetMedicationLinks { cat="Antiplatlet2", text="Antiplatlet2", seq=7 }
    aspirinMed = GetMedicationLinks { cat="Aspirin", text="Aspirin", seq=9 }
    heparinMed = GetMedicationLinks { cat="Heparin", text="Heparin", seq=14 }
    morphineMed = GetMedicationLinks { cat="Morphine", text="Morphine", seq=16 }
    nitroglycerinMed = GetMedicationLinks { cat="Nitroglycerin", text="Nitroglycerin", seq=17 }

    -- Starting Main Algorithm
    if #accountAlertCodes > 0 then
        if ExistingAlert then
            Result.outcome = "AUTORESOLVED"
            Result.reason = "Autoresolved due to one specified code on the account"
            Result.validated = true

            for codeIndex = 1, #accountAlertCodes do
                local code = accountAlertCodes[codeIndex]
                local description = alertCodeDictionary[code]
                GetCodeLinks { target=DocumentationIncludesLinks, code=code, text="Autoresolved Specified Code - " .. description }
            end
            AlertAutoResolved = true
        else
            Result.passed = false
        end
    elseif #accountAlertCodes == 0 and i214Code then
        if i214Code then
            table.insert(DocumentationIncludesLinks, i214Code)
        end
        Result.subtitle = "NSTEMI Present Confirm if Further Specification of Type Needed"
        AlertMatched = true
    elseif #accountAlertCodes == 0 and i219Code then
        if i219Code then
            table.insert(DocumentationIncludesLinks, i219Code)
        end
        Result.subtitle = "Acute MI Unspecified Present Confirm if Further Specification of Type Needed"
        AlertMatched = true
    elseif #accountAlertCodes == 0 and (troponinTDV or troponinTAbs) and i2489Code then
        if i2489Code then
            table.insert(DocumentationIncludesLinks, i2489Code)
        end
        if troponinTDV then
            for _, entry in ipairs(troponinTDV) do
                --- @cast troponinLinks CdiAlertLink[]
                table.insert(troponinLinks, entry)
            end
        end
        Result.subtitle = "Possible Acute MI Type 2"
        AlertMatched = true
    elseif #accountAlertCodes == 0 and (troponinTDV or troponinTAbs) and irregularEKGFindingsAbs then
        if irregularEKGFindingsAbs then
            table.insert(DocumentationIncludesLinks, irregularEKGFindingsAbs)
        end
        if troponinTDV then
            for _, entry in ipairs(troponinTDV) do
                --- @cast troponinLinks CdiAlertLink[]
                table.insert(troponinLinks, entry)
            end
        end
        if troponinTAbs then
            table.insert(DocumentationIncludesLinks, troponinTAbs)
        end
        Result.subtitle = "Possible Acute MI or Injury"
        AlertMatched = true
    elseif (r07Codes or (troponinTDV or troponinTAbs)) and heparinMed and (morphineMed or nitroglycerinMed) and aspirinMed and antiplatlet2Med then
        if heparinMed then
            table.insert(DocumentationIncludesLinks, heparinMed)
        end
        if morphineMed then
            table.insert(DocumentationIncludesLinks, morphineMed)
        end
        if nitroglycerinMed then
            table.insert(DocumentationIncludesLinks, nitroglycerinMed)
        end
        if r07Codes then
            table.insert(DocumentationIncludesLinks, r07Codes)
        end
        if aspirinMed then
            table.insert(DocumentationIncludesLinks, aspirinMed)
        end
        if antiplatlet2Med then
            table.insert(DocumentationIncludesLinks, antiplatlet2Med)
        end
        if troponinTDV then
            for _, entry in ipairs(troponinTDV) do
                --- @cast troponinLinks CdiAlertLink[]
                table.insert(troponinLinks, entry)
            end
        end
        if troponinTAbs then
            table.insert(DocumentationIncludesLinks, troponinTAbs)
        end
        Result.subtitle = "Possible Acute MI or Injury"
        AlertMatched = true
    elseif #accountAlertCodes == 0 and (troponinTDV or troponinTAbs) then
        if troponinTDV then
            for _, entry in ipairs(troponinTDV) do
                --- @cast troponinLinks CdiAlertLink[]
                table.insert(troponinLinks, entry)
            end
        end
        if troponinTAbs then
            table.insert(DocumentationIncludesLinks, troponinTAbs)
        end
        Result.subtitle = "Elevated Troponins Present"
        AlertMatched = true
    elseif (troponinTDV or elevatedTroponinIDV or troponinTAbs) then
        if troponinTDV then
            for _, entry in ipairs(troponinTDV) do
                --- @cast troponinLinks CdiAlertLink[]
                table.insert(troponinLinks, entry)
            end
        end
        if troponinTAbs then
            table.insert(DocumentationIncludesLinks, troponinTAbs)
        end
        if elevatedTroponinIDV then
            table.insert(DocumentationIncludesLinks, elevatedTroponinIDV)
        end
        AddDocumentationAbs("ELEVATED_TROPONIN_I", "Troponin I: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 0)
        Result.subtitle = "Elevated Troponins Present"
        AlertMatched = true
    else
        Result.passed = false
    end
end



--------------------------------------------------------------------------------
--- Additional Link Creation
--------------------------------------------------------------------------------
if AlertMatched then
    -- Clinical Evidence Links
    AddEvidenceCode("R94.39", "Abnormal Cardiovascular Function Study", 1)
    AddEvidenceCode("D62", "Acute Blood Loss Anemia", 2)
    AddEvidenceCode("I24.81", "Acute Coronary microvascular Dysfunction", 3)
    GetCodeLinks { target = ClinicalEvidenceLinks, codes = { "N17.0", "N17.1", "N17.2", "K76.7", "K91.83" }, text = "Acute Kidney Failure", seq = 4 }
    AddEvidenceCode("I48.92", "Aflutter", 5)
    AddEvidenceCode("I20.81", "Angina", 6)
    AddEvidenceCode("I20.1", "Angina Pectoris with Coronary Microvascular Dysfunction", 7)
    AddEvidenceCode("I20.1", "Angina Pectoris with Documented Spasm/with Coronary Vasospasm", 8)
    AddEvidenceCode("I48.91", "Atrial Fibrillation", 9)
    AddEvidenceAbs("ATRIAL_FIBRILLATION_WITH_RVR", "Atrial Fibrillation with RVR", 10)
    AddEvidenceCode("I48.4", "Atrial Flutter", 11)
    AddEvidenceCode("I46.9", "Cardiac Arrest", 12)
    GetCodeLinks {
        target = ClinicalEvidenceLinks,
        codes = { "270046", "027004Z", "0270056", "027005Z", "0270066", "027006Z", "0270076", "027007Z", "02700D6", "02700DZ", "02700E6", "02700EZ",
                  "02700F6", "02700FZ", "02700G6", "02700GZ", "02700T6", "02700TZ", "02700Z6", "02700ZZ", "0271046", "027104Z", "0271056", "027105Z",
                  "0271066", "027106Z", "0271076", "027107Z", "02710D6", "02710DZ", "02710E6", "02710EZ", "02710F6", "02710FZ", "02710G6", "02710GZ",
                  "02710T6", "02710TZ", "02710Z6", "02710ZZ", "0272046", "027204Z", "0272056", "027205Z", "0272066", "027206Z", "0272076", "027207Z",
                  "02720D6", "02720DZ", "02720E6", "02720EZ", "02720F6", "02720FZ", "02720G6", "02720GZ", "02720T6", "02720TZ", "02720Z6", "02720ZZ",
                  "0273046", "027304Z", "0273056", "027305Z", "0273066", "027306Z", "0273076", "027307Z", "02730D6", "02730DZ", "02730E6", "02730EZ",
                  "02730F6", "02730FZ", "02730G6", "02730GZ", "02730T6", "02730TZ", "02730Z6", "02730ZZ" },
        text = "Dilation of Coronary Artery",
        seq = 13
    }
    AddEvidenceCode("I46.8", "Cardiac Arrest Due to Other Underlying Condition", 14)
    AddEvidenceCode("I46.2", "Cardiac Arrest due to Underlying Cardiac Condition", 15)
    GetCodeLinks {
        target = ClinicalEvidenceLinks,
        codes = {
            "I42", "I42.0", "I42.1", "I42.2", "I42.3", "I42.4", "I42.5", "I42.6", "I42.7", "I42.8", "I42.9",
            "I43"
        },
        text = "Cardiomyopathy",
        seq = 16
    }
    AddEvidenceCode("I25.85", "Chronic Coronary Microvascular Dysfunction", 18)
    GetCodeLinks {
        target = ClinicalEvidenceLinks,
        codes = { "N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5" },
        text = "Chronic Kidney Failure",
        seq = 19
    }
    AddEvidenceCode("I44.2", "Complete Heart Block", 20)
    AddEvidenceCode("J44.1", "COPD Exacerbation", 21)
    AddEvidenceCode("Z98.61", "Coronary Angioplasty Hx", 22)
    AddEvidenceCode("Z95.5", "Coronary Angioplasty Implant and Graft Hx", 23)
    AddEvidenceCode("I25.10", "Coronary Artery Disease", 24)
    AddEvidenceCode("I25.119", "Coronary Artery Disease with Angina", 25)
    AddEvidenceAbs("DYSPNEA_ON_EXERTION", "Dyspnea On Exertion", 26)
    AddEvidenceAbs("EJECTION_FRACTION", "Ejection Fraction", 30)
    AddEvidenceCode("N18.6", "End-Stage Renal Disease", 31)
    AddEvidenceCode("I38", "Endocarditis", 32)
    AddEvidenceCode("I39", "Endocarditis", 33)
    GetCodeLinks {
        target = ClinicalEvidenceLinks,
        codes = {
            "I50.1", "I50.20", "I50.22", "I50.23", "I50.30", "I50.32", "I50.33", "I50.40", "I50.42", "I50.43",
            "I50.810", "I50.812", "I50.813", "I50.84", "I50.89", "I50.9"
        },
        text = "Heart Failure",
        seq = 34
    }
    AddEvidenceCode("Z95.1", "History of CABG", 35)
    GetCodeLinks {
        target = ClinicalEvidenceLinks,
        codes = { "I16.0", "I16.1", "I16.9" },
        text = "Hypertensive Crisis",
        seq = 36
    }
    AddEvidenceCode("I16.1", "Hypertensive Emergency", 37)
    AddEvidenceCode("I16.0", "Hypertensive Urgency", 38)
    AddEvidenceCode("E86.1", "Hypovolemia", 39)
    AddEvidenceCode("R09.02", "Hypoxemia", 40)
    AddEvidenceCode("I4711", "Inappropriate Sinus Tachycardia", 41)
    AddEvidenceAbs("IRREGULAR_ECHO_FINDING", "Irregular Echo Finding", 42)
    GetCodeLinks {
        target = ClinicalEvidenceLinks,
        codes = { "4A023N7", "4A023N8" },
        text = "Left Heart Cath",
        seq = 43
    }
    GetCodeLinks {
        target = ClinicalEvidenceLinks,
        codes = { "I40", "I40.0", "I40.1", "I40.8", "I40.9" },
        text = "Myocarditis Dx",
        seq = 44
    }
    AddEvidenceCode("I35.0", "Non-Rheumatic Aortic Valve Stenosis", 45)
    AddEvidenceCode("I35.1", "Non-Rheumatic Aortic Valve Insufficiency", 46)
    AddEvidenceCode("I35.2", "Non-Rheumatic Aortic Valve Stenosis with Insufficiency", 47)
    AddEvidenceCode("I25.2", "Old MI", 48)
    AddEvidenceCode("I20.8", "Other Angina Pectoris", 49)
    AddEvidenceCode("I4719", "Other Supraventricular Tachycardia", 50)
    GetCodeLinks {
        target = ClinicalEvidenceLinks,
        codes = { "I47.0", "I47.1", "I47.10", "I47.11", "I47.19", "I47.2", "I47.20", "I47.21", "I47.29", "I47.9"},
        text = "Paroxysmal Tachycardia Dx",
        seq = 51
    }
    GetCodeLinks {
        target = ClinicalEvidenceLinks,
        codes = { "I30", "I30.0", "I30.1", "I30.8", "I30.9" },
        text = "Pericarditis Dx",
        seq = 52
    }
    GetCodeLinks {
        target = ClinicalEvidenceLinks,
        codes = { "I26", "I26.0", "I26.01", "I26.02", "I26.09", "I26.9", "I26.90", "I26.92", "I26.93", "I26.94", "I26.99" },
        text = "Pulmonary Embolism Dx",
        seq = 53
    }
    GetCodeLinks {
        target = ClinicalEvidenceLinks,
        codes = { "I27.0", "I27.20", "I27.21", "I27.22", "I27.23", "I27.24", "I27.29" },
        text = "Pulmonary Hypertension Dx",
        seq = 54
    }
    GetCodeLinks {
        target = ClinicalEvidenceLinks,
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
        seq = 55
    }
    GetCodeLinks {
        target = ClinicalEvidenceLinks,
        codes = { "M62.82", "T79.6XXA", "T79.6XXD", "T79.6XXS" },
        text = "Rhabdomyolysis",
        seq = 56
    }
    AddEvidenceCode("4A023N6", "Right Heart Cath", 57)
    AddEvidenceCode("I20.2", "Refractory Angina Pectoris", 58)
    GetCodeLinks {
        target = ClinicalEvidenceLinks,
        codes = { "A40", "A40.0", "A40.1", "A40.3", "A40.8", "A40.9" },
        text = "Sepsis Dx",
        seq = 59
    }
    GetCodeLinks {
        target = ClinicalEvidenceLinks,
        codes = { "A41", "A41.0", "A41.1", "A41.2", "A41.3", "A41.8", "A41.9" },
        text = "Sepsis Dx",
        seq = 60
    }
    GetCodeLinks {
        target = ClinicalEvidenceLinks,
        codes = {
            "A42.7", "A22.7", "B37.7", "A26.7", "A54.86", "B00.7", "A32.7", "A24.1", "A20.7", "R65.20", "R65.21", "T81.44XA", "T81.44XD", "T81.44XS"
        },
        text = "Sepsis Dx",
        seq = 61
    }
    AddEvidenceAbs("SHORTNESS_OF_BREATH", "Shortness of Breath", 62)
    AddEvidenceCode("I47.10", "Supraventricular Tachycardia, Unspecified", 63)
    AddEvidenceCode("I51.81", "Takotsubo Syndrome", 64)
    AddEvidenceCode("I25.82", "Total Occlusion of Coronary Artery", 65)
    AddEvidenceCode("I48.3", "Typical Aflutter", 66)
    GetCodeLinks {
        target = ClinicalEvidenceLinks,
        codes = { "I35.8", "I35.9" },
        text = "Unspecified Non-Rheumatic Aortic Valve Disorders",
        seq = 67
    }
    AddEvidenceCode("I20.0", "Unstable Angina", 68)
    AddEvidenceCode("I49.01", "Ventricular Fibrillation", 69)
    AddEvidenceCode("I49.02", "Ventricular Flutter", 70)
    AddEvidenceAbs("WALL_MOTION_ABNORMALITIES", "Wall Motion Abnormalities", 71)

    -- EKG Links
    GetDocumentLinks { target = ekgLinks, documentType="EKG", text = "EKG", seq = 0 }
    GetDocumentLinks { target = ekgLinks, documentType="Telemetry Strips", text = "Telemetry Strips", seq = 0 }

    GetDocumentLinks { target = echoLinks, documentType="CA Master Echo Complete w/ Contrast", text="CA Master Echo Complete w/ Contrast", seq = 0 }
    GetDocumentLinks { target = echoLinks, documentType="PCA MASTER ECHO COMPLETE", text="PCA MASTER ECHO COMPLETE", seq = 0 }
    GetDocumentLinks { target = echoLinks, documentType="MCA MASTER ECHO COMPLETE", text="MCA MASTER ECHO COMPLETE", seq = 0 }

    GetDocumentLinks { target = echoLinks, documentType="SCA MASTER ECHO COMPLETE", text="SCA MASTER ECHO COMPLETE", seq = 0 }
    GetDocumentLinks { target = echoLinks, documentType="QCA MASTER ECHO COMPLETE", text="QCA MASTER ECHO COMPLETE", seq = 0 }
    GetDocumentLinks { target = echoLinks, documentType="FCA MASTER ECHO COMPLETE", text="FCA MASTER ECHO COMPLETE", seq = 0 }
    GetDocumentLinks { target = echoLinks, documentType="FCA MASTER TEE ECHO+", text="FCA MASTER TEE ECHO+", seq = 0 }
    GetDocumentLinks { target = echoLinks, documentType="DCA MASTER ECHO COMPLETE", text="DCA MASTER ECHO COMPLETE", seq = 0 }
    GetDocumentLinks { target = echoLinks, documentType="SCA MASTER ECHO COMP W CONTRAST", text="SCA MASTER ECHO COMP W CONTRAST", seq = 0 }

    GetDocumentLinks { target = echoLinks, documentType="ECHOCARDIOGRAM REPORT", text="ECHOCARDIOGRAM REPORT", seq = 0 }
    GetDocumentLinks { target = echoLinks, documentType="FCA MASTER ECHO COMP W CONTRAST", text="FCA MASTER ECHO COMP W CONTRAST", seq = 0 }
    GetDocumentLinks { target = echoLinks, documentType="MCA MASTER TEE ECHO+", text="MCA MASTER TEE ECHO+", seq = 0 }
    GetDocumentLinks { target = echoLinks, documentType="SCA MASTER TEE ECHO+", text="SCA MASTER TEE ECHO+", seq = 0 }
    GetDocumentLinks { target = echoLinks, documentType="Z.ITSREPE_X", text="Z.ITSREPE_X", seq = 0 }
    GetDocumentLinks { target = echoLinks, documentType="CA Master TEE Echo+", text="CA Master TEE Echo+", seq = 0 }
    GetDocumentLinks { target = echoLinks, documentType="CA Master Echo Complete", text="CA Master Echo Complete", seq = 0 }
    GetDocumentLinks { target = echoLinks, documentType="Echo Report", text="Echo Report", seq = 0 }
    GetDocumentLinks { target = echoLinks, documentType="CA Transesophageal Echo", text="CA Transesophageal Echo", seq = 0 }
    GetDocumentLinks { target = echoLinks, documentType="Echo", text="Echo", seq = 0 }
    GetDocumentLinks { target = echoLinks, documentType="Echocardiogram Transthoracic", text="Echocardiogram Transthoracic", seq = 0 }
    GetDocumentLinks { target = echoLinks, documentType="Echocardiogram Transesophageal", text="Echocardiogram Transesophageal", seq = 0 }
    GetDocumentLinks { target = echoLinks, documentType="CA Transesophageal Echo w/ Contrast", text="CA Transesophageal Echo w/ Contrast", seq = 0 }
    GetDocumentLinks { target = echoLinks, documentType="Echocardiogram Report", text="Echocardiogram Report", seq = 0 }

    GetDocumentLinks { target = heartCathLinks, documentType="Cath Report", text="Cath Report", seq = 0 }
    GetDocumentLinks { target = ctLinks, documentType="CT Angio Chest", text="CT Angio Chest", seq = 0 }
    GetDocumentLinks { target = ctLinks, documentType="CT Angio Coronary Artery Str/Mph/Fnt Cnt", text="CT Angio Coronary Artery Str/Mph/Fnt Cnt", seq = 0 }
    GetDocumentLinks { target = ctLinks, documentType="CT Angio Heart + Coronary ART/Graft w/Contrast", text="CT Angio Heart + Coronary ART/Graft w/Contrast", seq = 0 }
    GetDocumentLinks { target = ctLinks, documentType="CT Angio Coronary Trip RO Study", text="CT Angio Coronary Trip RO Study", seq = 0 }
    GetDocumentLinks { target = ctLinks, documentType="CA Cath Lab Case", text="CA Cath Lab Case", seq = 0 }

    -- Lab Links
    AddLabsDv("eGFR Non-AA (mL/min/1.73 m2)", "eGFR Non-AA (mL/min/1.73 m2)", 1, function(dv) return dv.result <= 60 end)
    if Account.patient.gender == "F" then
        AddLabsDv("Hemoglobin (g/dL)", "Hemoglobin (g/dL)", 2, function(dv)
            return CheckDvResultNumber(dv, function(v) return v < 12 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end)
        AddLabsDv("Hematocrit (%)", "Hematocrit (%)", 3, function(dv)
            return CheckDvResultNumber(dv, function (v) return v < 35 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end)
    elseif Account.patient.gender == "M" then
        AddLabsDv("Hemoglobin (g/dL)", "Hemoglobin (g/dL)", 2, function(dv)
            return CheckDvResultNumber(dv, function(v) return v < 13.5 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end)
        AddLabsDv("Hematocrit (%)", "Hematocrit (%)", 3, function(dv)
            return CheckDvResultNumber(dv, function (v) return v < 40 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end)
    end

    AddLabsAbs("HEMOGLOBIN", "Hemoglobin", 4)
    AddLabsAbs("HEMATOCRIT", "Hematocrit", 5)
    AddLabsDv("PaO2 (mmHg)", "PaO2 (mmHg)", 6, function(dv)
        return CheckDvResultNumber(dv, function(v) return v < 80 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)
    AddLabsDv("Serum Creatinine (mg/dL)", "Serum Creatinine (mg/dL)", 7, function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 1.2 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)

    -- Meds Links
    AddTreatmentMed("Ace Inhibitor", "Ace Inhibitor", 1)
    AddTreatmentMed("Antianginal Medication", "Antianginal Medication", 2)
    AddTreatmentAbs("ANTIANGINAL_MEDICATION", "Antianginal Medication", 3)
    AddTreatmentMed("Anticoagulant", "Anticoagulant", 4)
    AddTreatmentAbs("ANTICOAGULANT", "Anticoagulant", 5)
    AddTreatmentMed("Antiplatelet", "Antiplatelet", 6)
    AddTreatmentAbs("ANTIPLATELET", "Antiplatelet", 8)
    AddTreatmentMed("Beta Blocker", "Beta Blocker", 10)
    AddTreatmentAbs("BETA_BLOCKER", "Beta Blocker", 11)
    AddTreatmentMed("Calcium Channel Blocker", "Calcium Channel Blocker", 12)
    AddTreatmentAbs("CALCIUM_CHANNEL_BLOCKER", "Calcium Channel Blocker", 13)
    AddTreatmentMed("Hydralazine", "Hydralazine", 15)
    AddTreatmentAbs("NITROGLYCERIN", "Nitroglycerin", 18)
    AddTreatmentMed("Statin", "Statin", 19)
    AddTreatmentAbs("STATIN", "Statin", 20)

    -- Oxygen Links
    GetAbstractionValueLinks { target = oxygenLinks, code="OXYGEN_THERAPY", text="Oxygen Therapy", seq=1 }

    -- Vitals Links
    GetDiscreteValueLinks {
        target = VitalsLinks,
        discreteValue = "Diastolic Blood Pressure",
        text = "Diastolic Blood Pressure",
        predicate = function(dv)
            return CheckDvResultNumber(dv, function(v) return v.result > 120 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        seq = 1
    }
    AddVitalsAbs("HIGH_DIASTOLIC_BLOOD_PRESSURE", "Diastolic Blood Pressure", 2)
    GetDiscreteValueLinks {
        target = VitalsLinks,
        discreteValue = "Heart Rate",
        text = "Heart Rate",
        predicate = function(dv)
            return CheckDvResultNumber(dv, function(v) return v.result > 90 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        seq = 3
    }
    AddVitalsAbs("HIGH_HEART_RATE", "Heart Rate", 4)
    GetDiscreteValueLinks {
        target = VitalsLinks,
        discreteValue = "Heart Rate",
        text = "Heart Rate",
        predicate = function(dv)
            return CheckDvResultNumber(dv, function(v) return v.result < 60 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        seq = 5
    }
    AddVitalsAbs("LOW_HEART_RATE", "Heart Rate", 6)
    GetDiscreteValueLinks {
        target = VitalsLinks,
        discreteValue = "Mean Arterial Pressure",
        text = "Mean Arterial Pressure",
        predicate = function(dv)
            return CheckDvResultNumber(dv, function(v) return v.result < 65 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        seq = 7
    }
    AddVitalsAbs("LOW_MEAN_ARTERIAL_BLOOD_PRESSURE", "Mean Arterial Pressure", 8)
    GetDiscreteValueLinks {
        target = VitalsLinks,
        discreteValue = "Pulse Oximetry",
        text = "Pulse Oximetry",
        predicate = function(dv)
            return CheckDvResultNumber(dv, function(v) return v.result < 90 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        seq = 9
    }
    AddVitalsAbs("LOW_PULSE_OXIMETRY", "Pulse Oximetry", 10)
    GetDiscreteValueLinks {
        target = VitalsLinks,
        discreteValue = "Systolic Blood Pressure",
        text = "Systolic Blood Pressure",
        predicate = function(dv)
            return CheckDvResultNumber(dv, function(v) return v.result < 90 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        seq = 11
    }
    AddVitalsAbs("LOW_SYSTOLIC_BLOOD_PRESSURE", "Systolic Blood Pressure", 12)
    GetDiscreteValueLinks {
        target = VitalsLinks,
        discreteValue = "Systolic Blood Pressure",
        text = "Systolic Blood Pressure",
        predicate = function(dv)
            return CheckDvResultNumber(dv, function(v) return v.result > 180 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end,
        seq = 13
    }
    AddVitalsAbs("HIGH_SYSTOLIC_BLOOD_PRESSURE", "Systolic Blood Pressure", 14)
end



--------------------------------------------------------------------------------
--- Result Finalization 
--------------------------------------------------------------------------------
if AlertMatched or AlertAutoResolved then
    if ekgLinks then
        ekgHeader.links = ekgLinks
    end
    if echoLinks then
        echoHeader.links = echoLinks
    end
    if heartCathLinks then
        heartCathHeader.links = heartCathLinks
    end
    if ctLinks then
        ctHeader.links = ctLinks
    end
    if oxygenLinks then
        oxygenHeader.links = oxygenLinks
    end
    if troponinLinks then
        troponinHeader.links = troponinLinks
    end

    local resultLinks = GetFinalTopLinks({ oxygenHeader, ekgHeader, echoHeader, heartCathHeader, ctHeader, troponinHeader })

    resultLinks = MergeLinksWithExisting(ExistingAlert, resultLinks)
    Result.links = resultLinks
    Result.passed = true
end

