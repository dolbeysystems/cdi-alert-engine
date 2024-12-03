---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Anemia
---
--- This script checks an account to see if it matches the criteria for an anemia alert.
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
local dvBloodLoss = {""}
local calcBloodLoss1 = function(dv) return GetDvValueNumber(dv) > 300 end
local dvFolate = {""}
local calcFolate1 = function(dv) return GetDvValueNumber(dv) < 7.0 end
local dvHematocrit = {"HEMATOCRIT (%)", "HEMATOCRIT"}
local calcHematocrit1 = function(dv) return GetDvValueNumber(dv) < 34 end
local calcHematocrit2 = function(dv) return GetDvValueNumber(dv) < 40 end
local calcHematocrit3 = function(dv) return GetDvValueNumber(dv) < 30 end
local dvHemoglobin = {"HEMOGLOBIN", "HEMOGLOBIN (g/dL)"}
local calcHemoglobin1 = function(dv) return GetDvValueNumber(dv) < 13.5 end
local calcHemoglobin2 = function(dv) return GetDvValueNumber(dv) < 12.5 end
local calcHemoglobin3 = function(dv) return GetDvValueNumber(dv) < 10.0 end
local dvMAP = {"Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)"}
local calcMAP1 = function(dv) return GetDvValueNumber(dv) < 70 end
local dvMCH = {"MCH (pg)"}
local calcMCH1 = function(dv) return GetDvValueNumber(dv) < 25 end
local dvMCHC = {"MCHC (g/dL)"}
local calcMCHC1 = function(dv) return GetDvValueNumber(dv) < 32 end
local dvMCV = {"MCV (fL)"}
local calcMCV1 = function(dv) return GetDvValueNumber(dv) < 80 end
local dvPlateletCount = {"PLATELET COUNT (10x3/uL)"}
local dvRBC = {"RBC  (10X6/uL)"}
local calcRBC1 = function(dv) return GetDvValueNumber(dv) < 3.9 end
local dvRDW = {"RDW CV (%)"}
local calcRDW1 = function(dv) return GetDvValueNumber(dv) < 11 end
local dvRedBloodCellTransfusion = {""}
local dvReticulocyteCount = {""}
local calcReticulocyteCount1 = function(dv) return GetDvValueNumber(dv) < 0.5 end
local dvSBP = {"SBP 3.5 (No Calculation) (mm Hg)"}
local calcSBP1 = function(dv) return GetDvValueNumber(dv) < 90 end
local dvSerumFerritin = {"FERRITIN (ng/mL)"}
local calcSerumFerritin1 = function(dv) return GetDvValueNumber(dv) < 22 end
local dvSerumIron = {"IRON TOTAL (ug/dL)"}
local calcSerumIron1 = function(dv) return GetDvValueNumber(dv) < 65 end
local dvTotalIronBindingCapacity = {"IRON BINDING"}
local calcTotalIronBindingCapacity1 = function(dv) return GetDvValueNumber(dv) < 246 end
local dvTransferrin = {"TRANSFERRIN"}
local calcTransferrin1 = function(dv) return GetDvValueNumber(dv) < 200 end
local dvVitaminB12 = {"VITAMIN B12 (pg/mL)"}
local calcVitB121 = function(dv) return GetDvValueNumber(dv) < 180 end
local dvWBC = {"WBC (10x3/ul)"}
local calcWBC1 = function(dv) return GetDvValueNumber(dv) < 4.5 end
local calcAny1 = function(dv) return GetDvValueNumber(dv)  > 0 end



local existingAlert = GetExistingCdiAlert { scriptName = ScriptName }
local subtitle = existingAlert and existingAlert.subtitle or nil



if not existingAlert or not existingAlert.validated then
    --------------------------------------------------------------------------------
    --- Top-Level Link Header Variables
    --------------------------------------------------------------------------------
    local resultLinks = {}
    local documentedDxHeader = MakeHeaderLink("Documented Dx")
    local documentedDxLinks = {}
    local alertTriggerHeader = MakeHeaderLink("Alert Trigger")
    local alertTriggerLinks = {}
    local labsHeader = MakeHeaderLink("Laboratory Studies")
    local labsLinks = {}
    local vitalsHeader = MakeHeaderLink("Vital Signs/Intake and Output Data")
    local vitalsLinks = {}
    local clinicalEvidenceHeader = MakeHeaderLink("Clinical Evidence")
    local clinicalEvidenceLinks = {}
    local treatmentAndMonitoringHeader = MakeHeaderLink("Treatment and Monitoring")
    local treatmentAndMonitoringLinks = {}
    local signOfBleedingHeader = MakeHeaderLink("Sign of Bleeding")
    local signOfBleedingLinks = {}
    local otherHeader = MakeHeaderLink("Other")
    local otherLinks = {}
    local hemoglobinHeader = MakeHeaderLink("Hemoglobin")
    local hemoglobinLinks = {}
    local hematocritHeader = MakeHeaderLink("Hematocrit")
    local hematocritLinks = {}
    local bloodLossHeader = MakeHeaderLink("Blood Loss")
    local bloodLossLinks = {}



    --------------------------------------------------------------------------------
    --- Alert Variables 
    --------------------------------------------------------------------------------
    local alertCodeDictionary = {
        ["D50.8"] = "Other Iron Deficiency Anemias",
        ["D50.9"] = "Iron Deficiency Anemia Unspecified",
        ["D51.0"] = "Vitamin B12 Deficiency Anemia due to Intrinsic Factor Deficiency",
        ["D51.1"] = "Vitamin B12 Deficiency Anemia due to Selective Vitamin B12 Malabsorption With Proteinuria",
        ["D51.2"] = "Transcobalamin II Deficiency",
        ["D51.3"] = "Other Dietary Vitamin B12 Deficiency Anemia",
        ["D51.8"] = "Other Vitamin B12 Deficiency Anemias",
        ["D51.9"] = "Vitamin B12 Deficiency Anemia, Unspecified",
        ["D52.0"] = "Dietary Folate Deficiency Anemia",
        ["D52.1"] = "Drug-Induced Folate Deficiency Anemia",
        ["D52.8"] = "Other Folate Deficiency Anemias",
        ["D52.9"] = "Folate Deficiency Anemia, Unspecified",
        ["D53.0"] = "Protein Deficiency Anemia",
        ["D53.1"] = "Other Megaloblastic Anemias, not Elsewhere Classified",
        ["D53.2"] = "Scorbutic Anemia",
        ["D53.8"] = "Other Specified Nutritional Anemias",
        ["D53.9"] = "Nutritional Anemia, Unspecified",
        ["D55.0"] = "Anemia Due to Glucose-6-Phosphate Dehydrogenase [G6pd] Deficiency",
        ["D55.1"] = "Anemia Due to Other Disorders of Glutathione Metabolism",
        ["D55.21"] = "Anemia Due to Pyruvate Kinase Deficiency",
        ["D55.29"] = "Anemia Due to Other Disorders of Glycolytic Enzymes",
        ["D55.3"] = "Anemia Due to Disorders of Nucleotide Metabolism",
        ["D55.8"] = "Other Anemias Due to Enzyme Disorders",
        ["D55.9"] = "Anemia Due to Enzyme Disorder, Unspecified",
        ["D56.0"] = "Alpha Thalassemia",
        ["D56.1"] = "Beta Thalassemia",
        ["D56.2"] = "Delta-Beta Thalassemia",
        ["D56.3"] = "Thalassemia Minor",
        ["D56.4"] = "Hereditary Persistence of Fetal Hemoglobin [Hpfh]",
        ["D56.5"] = "Hemoglobin E-Beta Thalassemia",
        ["D56.8"] = "Other Thalassemias",
        ["D56.9"] = "Thalassemia, Unspecified",
        ["D58.0"] = "Hereditary Spherocytosis",
        ["D58.1"] = "Hereditary Elliptocytosis",
        ["D58.2"] = "Other Hemoglobinopathies",
        ["D58.8"] = "Other Specified Hereditary Hemolytic Anemias",
        ["D58.9"] = "Hereditary Hemolytic Anemia, Unspecified",
        ["D59.0"] = "Drug-Induced Autoimmune Hemolytic Anemia",
        ["D59.10"] = "Autoimmune Hemolytic Anemia, Unspecified",
        ["D59.11"] = "Warm Autoimmune Hemolytic Anemia",
        ["D59.12"] = "Cold Autoimmune Hemolytic Anemia",
        ["D59.13"] = "Mixed Type Autoimmune Hemolytic Anemia",
        ["D59.19"] = "Other Autoimmune Hemolytic Anemia",
        ["D59.2"] = "Drug-Induced Nonautoimmune Hemolytic Anemia",
        ["D59.30"] = "Hemolytic-Uremic Syndrome, Unspecified",
        ["D59.31"] = "Infection-Associated Hemolytic-Uremic Syndrome",
        ["D59.32"] = "Hereditary Hemolytic-Uremic Syndrome",
        ["D59.39"] = "Other Hemolytic-Uremic Syndrome",
        ["D59.4"] = "Other Nonautoimmune Hemolytic Anemias",
        ["D59.5"] = "Paroxysmal Nocturnal Hemoglobinuria [Marchiafava-Micheli]",
        ["D59.6"] = "Hemoglobinuria Due to Hemolysis From Other External Causes",
        ["D59.8"] = "Other Acquired Hemolytic Anemias",
        ["D59.9"] = "Acquired Hemolytic Anemia, Unspecified",
        ["D60.0"] = "Chronic Acquired Pure Red Cell Aplasia",
        ["D60.1"] = "Transient Acquired Pure Red Cell Aplasia",
        ["D60.8"] = "Other Acquired Pure Red Cell Aplasias",
        ["D60.9"] = "Acquired Pure Red Cell Aplasia, Unspecified",
        ["D61.01"] = "Constitutional (Pure) Red Blood Cell Aplasia",
        ["D61.09"] = "Other Constitutional Aplastic Anemia",
        ["D61.1"] = "Drug-Induced Aplastic Anemia",
        ["D61.2"] = "Aplastic Anemia Due to Other External Agents",
        ["D61.3"] = "Idiopathic Aplastic Anemia",
        ["D61.810"] = "Antineoplastic Chemotherapy Induced Pancytopenia",
        ["D61.811"] = "Other Drug-Induced Pancytopenia",
        ["D61.818"] = "Other Pancytopenia",
        ["D61.82"] = "Myelophthisis",
        ["D61.89"] = "Other Specified Aplastic Anemias and Other Bone Marrow Failure Syndromes",
        ["D61.9"] = "Aplastic Anemia, Unspecified",
        ["D62"] = "Acute Posthemorrhagic Anemia",
        ["D63.0"] = "Anemia in Neoplastic Disease",
        ["D63.1"] = "Anemia in Chronic Kidney Disease",
        ["D63.8"] = "Anemia in Other Chronic Diseases Classified Elsewhere",
        ["D64.0"] = "Hereditary Sideroblastic Anemia",
        ["D64.1"] = "Secondary Sideroblastic Anemia due to Disease",
        ["D64.2"] = "Secondary Sideroblastic Anemia due to Drugs And Toxins",
        ["D64.3"] = "Other Sideroblastic Anemias",
        ["D64.4"] = "Congenital Dyserythropoietic Anemia",
        ["D64.81"] = "Anemia due to Antineoplastic Chemotherapy",
        ["D64.89"] = "Other Specified Anemias"
    }
    local accountAlertCodes = GetAccountCodesInDictionary(Account, alertCodeDictionary)


    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- Documented Dx
    local d649CodeLink = GetCodeLink { code = "D64.9", text = "Unspecified Anemia" }
    local d500CodeLink = GetCodeLink { code = "D50.0", text = "Iron deficiency anemia secondary to blood loss (chronic)" }
    local d62CodeLink = GetCodeLink { code = "D62", text = "Acute Posthemorrhagic Anemia" }
    local bloodLossDVLink = GetDiscreteValueLink {
        discreteValueNames = dvBloodLoss,
        text = "Blood Loss: [VALUE]",
        predicate = calcBloodLoss1
    }

    -- Signs of Bleeding
    local i975CodeLink = GetCodeLink { codes = {"I97.51", "I97.52"}, text = "Accidental Puncture/Laceration of Circulatory System Organ During Procedure", seq = 1 } or {}
    local k917CodeLink = GetCodeLink { codes = {"K91.71", "K91.72"}, text = "Accidental Puncture/Laceration of Digestive System Organ During Procedure", seq = 2 } or {}
    local j957CodeLink = GetCodeLink { codes = {"J95.71", "J95.72"}, text = "Accidental Puncture/Laceration of Respiratory System Organ During Procedure", seq = 3 } or {}
    local k260CodeLink = GetCodeLink { code = "K26.0", text = "Acute Duodenal Ulcer with Hemorrhage", seq = 4 }
    local k262CodeLink = GetCodeLink { code = "K26.2", text = "Acute Duodenal Ulcer with Hemorrhage and Perforation", seq = 5 }
    local k250CodeLink = GetCodeLink { code = "K25.0", text = "Acute Gastric Ulcer with Hemorrhage", seq = 6 }
    local k252CodeLink = GetCodeLink { code = "K25.2", text = "Acute Gastric Ulcer with Hemorrhage and Perforation", seq = 7 }
    local k270CodeLink = GetCodeLink { code = "K27.0", text = "Acute Peptic Ulcer with Hemorrhage", seq = 8 }
    local k272CodeLink = GetCodeLink { code = "K27.2", text = "Acute Peptic Ulcer with Hemorrhage and Perforation", seq = 9 }
    local bleedingAbstractionLink = GetAbstractionLink { code = "BLEEDING", text = "Bleeding", seq = 10 }
    local r319CodeLink = GetCodeLink { code = "R31.9", text = "Bloody Urine", seq = 11 }
    local k264CodeLink = GetCodeLink { code = "K26.4", text = "Chronic Duodenal Ulcer with Hemorrhage", seq = 12 }
    local k266CodeLink = GetCodeLink { code = "K26.6", text = "Chronic Duodenal Ulcer with Hemorrhage and Perforation", seq = 13 }
    local k254CodeLink = GetCodeLink { code = "K25.4", text = "Chronic Gastric Ulcer with Hemorrhage", seq = 14 }
    local k256CodeLink = GetCodeLink { code = "K25.6", text = "Chronic Gastric Ulcer with Hemorrhage and Perforation", seq = 15 }
    local k276CodeLink = GetCodeLink { code = "K27.6", text = "Chronic Peptic Ulcer with Hemorrhage and Perforation", seq = 16 }
    local n99510CodeLink = GetCodeLink { code = "N99.510", text = "Cystostomy Hemorrhage", seq = 17 }
    local r040CodeLink = GetCodeLink { code = "R04.0", text = "Epistaxis", seq = 18 }
    local i8501CodeLink = GetCodeLink { code = "I85.01", text = "Esophageal Varices with Bleeding", seq = 19 }
    local eblAbstractionLink = GetAbstractionLink { code = "ESTIMATED_BLOOD_LOSS", text = "Estimated Blood Loss", seq = 20 }
    local k922CodeLink = GetCodeLink { code = "K92.2", text = "GI Hemorrhage", seq = 21 }
    local hematomaAbstractionLink = GetAbstractionLink { code = "HEMATOMA", text = "Hematoma", seq = 22 }
    local k920CodeLink = GetCodeLink { code = "K92.0", text = "Hematemesis", seq = 23 }
    local r310CodeLink = GetFirstCodePrefixLink { prefix = "R31", text = "Hematuria", seq = 24, maxPerValue = 1 }
    local r195CodeLink = GetCodeLink { code = "R19.5", text = "Heme-Positive Stool", seq = 25 }
    local k661CodeLink = GetCodeLink { code = "K66.1", text = "Hemoperitoneum", seq = 26 }
    local hemorrhageAbstractionLink = GetAbstractionLink { code = "HEMORRHAGE", text = "Hemorrhage", seq = 27 }
    local n3091CodeLink = GetCodeLink { code = "N30.91", text = "Hemorrhagic Cystitis", seq = 28 }
    local j9501CodeLink = GetCodeLink { code = "J95.01", text = "Hemorrhage from Tracheostomy Stoma", seq = 29 }
    local r042CodeLink = GetCodeLink { code = "R04.2", text = "Hemoptysis", seq = 30 }
    local i974CodeLink = GetCodeLink { codes = {"I97.410", "I97.411", "I97.418", "I97.42"}, text = "Intraoperative Hemorrhage/Hematoma of Circulatory System Organ", seq = 31 } or {}
    local k916CodeLink = GetCodeLink { codes = {"K91.61", "K91.62"}, text = "Intraoperative Hemorrhage/Hematoma of Digestive System Organ", seq = 32 } or {}
    local n99CodeLink = GetCodeLink { codes = {"N99.61", "N99.62"}, text = "Intraoperative Hemorrhage/Hematoma of Genitourinary System", seq = 33 } or {}
    local g9732CodeLink = GetCodeLink { code = "G97.32", text = "Intraoperative Hemorrhage/Hematoma of Nervous System Organ", seq = 34 }
    local g9731CodeLink = GetCodeLink { code = "G97.31", text = "Intraoperative Hemorrhage/Hematoma of Nervous System Procedure", seq = 35 }
    local j956CodeLink = GetCodeLink { codes = {"J95.61", "J95.62"}, text = "Intraoperative Hemorrhage/Hematoma of Respiratory System", seq = 36 } or {}
    local k921CodeLink = GetCodeLink { code = "K92.1", text = "Melena", seq = 37 }
    local i61CodeLink = GetFirstCodePrefixLink { prefix = "I61", text = "Nontraumatic Intracerebral Hemorrhage", seq = 38 }
    local i62CodeLink = GetFirstCodePrefixLink { prefix = "I62", text = "Nontraumatic Intracerebral Hemorrhage", seq = 39 }
    local i60CodeLink = GetFirstCodePrefixLink { prefix = "I60", text = "Nontraumatic Subarachnoid Hemorrhage", seq = 40 }
    local l7632CodeLink = GetCodeLink { code = "L76.32", text = "Postoperative Hematoma", seq = 41 }
    local k918CodeLink = GetCodeLink { codes = {"K91.840", "K91.841", "K91.870", "K91.871"}, text = "Postoperative Hemorrhage/Hematoma of Digestive System Organ", seq = 42 } or {}
    local i976CodeLink = GetCodeLink { codes = {"I97.610", "I97.611", "I97.618", "I97.620"}, text = "Postoperative Hemorrhage/Hematoma of Circulatory System Organ", seq = 43 } or {}
    local n991CodeLink = GetCodeLink { codes = {"N99.820", "N99.821", "N99.840", "N99.841"}, text = "Postoperative Hemorrhage/Hematoma of Genitourinary System", seq = 44 } or {}
    local g9752CodeLink = GetCodeLink { code = "G97.52", text = "Postoperative Hemorrhage/Hematoma of Nervous System Organ", seq = 45 }
    local g9751CodeLink = GetCodeLink { code = "G97.51", text = "Postoperative Hemorrhage/Hematoma of Nervous System Procedure", seq = 46 }
    local j958CodeLink = GetCodeLink { codes = {"J95.830", "J95.831", "J95.860", "J95.861"}, text = "Postoperative Hemorrhage/Hematoma of Respiratory System", seq = 47 } or {}
    local k625CodeLink = GetCodeLink { code = "K62.5", text = "Rectal Bleeding", seq = 48 }

    -- Labs
     GetDiscreteValuePairsAsCombinedSingleLineLink {
        discreteValueNames1 = dvHemoglobin,
        discreteValueNames2 = dvHematocrit,
        linkTemplate = "Hemoglobin/Hematocrit: ([DATE1] - [DATE2]) - [VALUE_PAIRS]",
        target = labsLinks,
    }
    local lowHemoglobin10DVLink = GetDiscreteValueLink { discreteValueNames = dvHemoglobin, text = "Hemoglobin", predicate = calcHemoglobin3 }
    local lowHematocrit30DVLink = GetDiscreteValueLink { discreteValueNames = dvHematocrit, text = "Hematocrit", predicate = calcHematocrit3 }
    --- @type CdiAlertLink?
    local lowHemoglobinDVLink
    --- @type CdiAlertLinkPair[]
    local hemoHemaConsecutDropDVLinkPairs = {}
    --- @type CdiAlertLinkPair[]
    local lowHemoglobinMultiDVLinkPairs = {}

    local gender = Account.patient and Account.patient.gender or ""
    if gender == "F" then
        --[[
        --]]
    else
        --[[
        --]]
    end


    --[[
    hemoHemaConsecutDropDV = [ [False], [False] ]
    lowHemoglobinMultiDV = [ [False], [False] ]
    dvLookUpAllLinkedValuesSingleLine(dict(maindiscreteDic), dvHemoglobin, dvHematocrit, 0, labs, "Hemoglobin/Hematocrit: (DATE1 - DATE2) - ")
    if gender == 'F':
        lowHemoglobinDV = dvValue(dvHemoglobin, "Hemoglobin: [VALUE] (Result Date: [RESULTDATETIME])", calcHemoglobin2, 0)
        lowHemoglobinMultiDV = HemoglobinHematocritValues(dict(maindiscreteDic), "Female", 12.5, 34, 10)
        hemoHemaConsecutDropDV = percentageDropDVValues(dict(maindiscreteDic), dvHemoglobin, dvHematocrit, 11, 34,
            "Hemoglobin: [VALUE] (Result Date: [RESULTDATETIME])", "Hematocrit: [VALUE] (Result Date: [RESULTDATETIME])",
            hemoglobin, hematocrit)
    if gender == 'M':
        lowHemoglobinDV = dvValue(dvHemoglobin, "Hemoglobin: [VALUE] (Result Date: [RESULTDATETIME])", calcHemoglobin1, 0)
        lowHemoglobinMultiDV = HemoglobinHematocritValues(dict(maindiscreteDic), "Male", 13.5, 40, 10)
        hemoHemaConsecutDropDV = percentageDropDVValues(dict(maindiscreteDic), dvHemoglobin, dvHematocrit, 12, 38,
            "Hemoglobin: [VALUE] (Result Date: [RESULTDATETIME])", "Hematocrit: [VALUE] (Result Date: [RESULTDATETIME])",
            hemoglobin, hematocrit)
    lowHemoglobin10DV = dvValue(dvHemoglobin, "Hemoglobin: [VALUE] (Result Date: [RESULTDATETIME])", calcHemoglobin3, 0)
    lowHematocrit30DV = dvValue(dvHematocrit, "Hematocrit: [VALUE] (Result Date: [RESULTDATETIME])", calcHematocrit3, 0)
    --]]

    -- Meds
    local anemiaMedsAbstractionLink = GetAbstractionLink { code="ANEMIA_MEDICATION", text="Anemia Medication", seq=1 }
    local anemiaMedicationLink = GetMedicationLink { cat="Anemia Supplements", text="Anemia Supplements", seq=2 }
    local cellSaverAbstractionLink = GetAbstractionLink { code="CELL_SAVER", text="Cell Saver", seq=3 }
    local hematopoeticMedicationLink = GetMedicationLink { cat="Hemopoietic Agent", text="Hematopoietic Agent", seq=4 }
    local hemtopoeticAbstractionLink = GetAbstractionLink { code="HEMATOPOIETIC_AGENT", text="Hematopoietic Agent", seq=5 }
    local rBloTransfusionCodeLink = GetCodeLink { codes = {"30233N1", "30243N1"}, text = "Red Blood Cell Transfusion", seq = 6 }
    local redBloodCellDVLink = GetDiscreteValueLink { discreteValueNames = dvRedBloodCellTransfusion, text = "Red Blood Cell Transfusion", predicate = calcAny1, seq = 7 }

    local sob =
        i975CodeLink and
        k917CodeLink and
        j957CodeLink and
        k260CodeLink and
        k262CodeLink and
        k250CodeLink and
        k252CodeLink and
        k270CodeLink and
        k272CodeLink and
        k264CodeLink and
        k266CodeLink and
        k254CodeLink and
        k256CodeLink and
        k276CodeLink and
        n99510CodeLink and
        i8501CodeLink and
        k922CodeLink and
        hematomaAbstractionLink and
        k920CodeLink and
        r310CodeLink and
        k661CodeLink and
        n3091CodeLink and
        j9501CodeLink and
        r042CodeLink and
        i974CodeLink and
        k916CodeLink and
        n99CodeLink and
        g9732CodeLink and
        g9731CodeLink and
        j956CodeLink and
        k921CodeLink and
        l7632CodeLink and
        k918CodeLink and
        i976CodeLink and
        n991CodeLink and
        g9752CodeLink and
        g9751CodeLink and
        j958CodeLink and
        k625CodeLink and
        r319CodeLink and
        r040CodeLink and
        r195CodeLink and
        i61CodeLink and
        i62CodeLink and
        i60CodeLink and
        bloodLossDVLink and
        eblAbstractionLink and
        bleedingAbstractionLink and
        hemorrhageAbstractionLink

    local AT =
        anemiaMedsAbstractionLink and
        anemiaMedicationLink and
        hematopoeticMedicationLink and
        hemtopoeticAbstractionLink and
        rBloTransfusionCodeLink and
        cellSaverAbstractionLink



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    if
        subtitle == "Anemia Dx Possibly Lacking Supporting Evidence" and
        #accountAlertCodes > 0
    then
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        local resultLinks = {}

        if Result.validated then
            -- Autoclose
        else
            -- Normal Alert
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        if existingAlert then
            resultLinks = MergeLinks(existingAlert.links, resultLinks)
        end
        Result.links = resultLinks
    end
end

