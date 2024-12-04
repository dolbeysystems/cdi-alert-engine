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

local linkTextPossibleNoLows = "Possible No Low Hemoglobin, Low Hematocrit or Anemia Treatment"
local linkTextPossibleNoSignsOfBleeding = "Possible No Sign of Bleeding Please Review"
local linkTextPossibleNoMatchingHemoglobin = "Possible No Hemoglobin Values Meeting Criteria Please Review"
local linkTextPossibleNoAnemiaTreatment = "Possible No Anemia Treatment found"

local linkTextPossibleNoLowsPresent = false
local linkTextPossibleNoSignsOfBleedingPresent = false
local linkTextPossibleNoMatchingHemoglobinPresent = false
local linkTextPossibleNoAnemiaTreatmentPresent = false

if existingAlert and existingAlert.links then
    for _, link in ipairs(existingAlert.links) do
        if link.link_text == linkTextPossibleNoLows then
            linkTextPossibleNoLowsPresent = true
        elseif link.link_text == linkTextPossibleNoSignsOfBleeding then
            linkTextPossibleNoSignsOfBleedingPresent = true
        elseif link.link_text == linkTextPossibleNoMatchingHemoglobin then
            linkTextPossibleNoMatchingHemoglobinPresent = true
        elseif link.link_text == linkTextPossibleNoAnemiaTreatment then
            linkTextPossibleNoAnemiaTreatmentPresent = true
        end
    end
end




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
    local bloodLossDVLinks = GetDiscreteValueLinks {
        discreteValueNames = dvBloodLoss,
        text = "Blood Loss: [VALUE]",
        predicate = calcBloodLoss1,
        maxPerValue = 10
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
    local r310CodeLink = GetCodePrefixLink { prefix = "R31", text = "Hematuria", seq = 24, maxPerValue = 1 }
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
    local i61CodeLink = GetCodePrefixLink { prefix = "I61", text = "Nontraumatic Intracerebral Hemorrhage", seq = 38 }
    local i62CodeLink = GetCodePrefixLink { prefix = "I62", text = "Nontraumatic Intracerebral Hemorrhage", seq = 39 }
    local i60CodeLink = GetCodePrefixLink { prefix = "I60", text = "Nontraumatic Subarachnoid Hemorrhage", seq = 40 }
    local l7632CodeLink = GetCodeLink { code = "L76.32", text = "Postoperative Hematoma", seq = 41 }
    local k918CodeLink = GetCodeLink { codes = {"K91.840", "K91.841", "K91.870", "K91.871"}, text = "Postoperative Hemorrhage/Hematoma of Digestive System Organ", seq = 42 } or {}
    local i976CodeLink = GetCodeLink { codes = {"I97.610", "I97.611", "I97.618", "I97.620"}, text = "Postoperative Hemorrhage/Hematoma of Circulatory System Organ", seq = 43 } or {}
    local n991CodeLink = GetCodeLink { codes = {"N99.820", "N99.821", "N99.840", "N99.841"}, text = "Postoperative Hemorrhage/Hematoma of Genitourinary System", seq = 44 } or {}
    local g9752CodeLink = GetCodeLink { code = "G97.52", text = "Postoperative Hemorrhage/Hematoma of Nervous System Organ", seq = 45 }
    local g9751CodeLink = GetCodeLink { code = "G97.51", text = "Postoperative Hemorrhage/Hematoma of Nervous System Procedure", seq = 46 }
    local j958CodeLink = GetCodeLink { codes = {"J95.830", "J95.831", "J95.860", "J95.861"}, text = "Postoperative Hemorrhage/Hematoma of Respiratory System", seq = 47 } or {}
    local k625CodeLink = GetCodeLink { code = "K62.5", text = "Rectal Bleeding", seq = 48 }

    -- Labs
    local gender = Account.patient and Account.patient.gender or ""
    GetDiscreteValuePairsAsCombinedSingleLineLink {
        discreteValueNames1 = dvHemoglobin,
        discreteValueNames2 = dvHematocrit,
        linkTemplate = "Hemoglobin/Hematocrit: ([DATE1] - [DATE2]) - [VALUE_PAIRS]",
        target = labsLinks,
    }
    local lowHemoglobin10DVLink = GetDiscreteValueLink { discreteValueNames = dvHemoglobin, text = "Hemoglobin", predicate = calcHemoglobin3 }
    local lowHematocrit30DVLink = GetDiscreteValueLink { discreteValueNames = dvHematocrit, text = "Hematocrit", predicate = calcHematocrit3 }
    local lowHemoglobinDVLink = 
        GetDiscreteValueLink {
            discreteValueNames = dvHemoglobin,
            text = "Hemoglobin",
            predicate = gender == "F" and calcHemoglobin2 or calcHemoglobin1
        }

    local lowHemoglobinMultiDVLinkPairs = GetLowHemoglobinDiscreteValuePairs(gender)
    local lowHematocritMultiDVLinkPairs = GetLowHematocritDiscreteValuePairs(gender)

    local hematocritDropDVLinkPairs = GetHematocritDropPairs()
    local hemoglobinDropDVLinkPairs = GetHemoglobinDropPairs()

    -- Meds
    local anemiaMedsAbstractionLink = GetAbstractionLink { code="ANEMIA_MEDICATION", text="Anemia Medication", seq=1 }
    local anemiaMedicationLink = GetMedicationLink { cat="Anemia Supplements", text="Anemia Supplements", seq=2 }
    local cellSaverAbstractionLink = GetAbstractionLink { code="CELL_SAVER", text="Cell Saver", seq=3 }
    local hematopoeticMedicationLink = GetMedicationLink { cat="Hemopoietic Agent", text="Hematopoietic Agent", seq=4 }
    local hemtopoeticAbstractionLink = GetAbstractionLink { code="HEMATOPOIETIC_AGENT", text="Hematopoietic Agent", seq=5 }
    local rBloTransfusionCodeLink = GetCodeLink { codes = {"30233N1", "30243N1"}, text = "Red Blood Cell Transfusion", seq = 6 }
    local redBloodCellDVLink = GetDiscreteValueLink { discreteValueNames = dvRedBloodCellTransfusion, text = "Red Blood Cell Transfusion", predicate = calcAny1, seq = 7 }

    local signsOfBleeding =
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
        #bloodLossDVLinks > 0 and
        eblAbstractionLink and
        bleedingAbstractionLink and
        hemorrhageAbstractionLink

    local anemiaTreatment =
        anemiaMedsAbstractionLink and
        anemiaMedicationLink and
        hematopoeticMedicationLink and
        hemtopoeticAbstractionLink and
        rBloTransfusionCodeLink and
        cellSaverAbstractionLink



    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------
    -- Autoresolve "Anemia Dx Possibly Lacking Supporting Evidence"
    if
        subtitle == "Anemia Dx Possibly Lacking Supporting Evidence" and
        #accountAlertCodes > 0 and
        (lowHemoglobinDVLink or lowHematocrit30DVLink)
    then
        if linkTextPossibleNoLowsPresent then
            local link = MakeHeaderLink(linkTextPossibleNoLows)
            table.insert(documentedDxLinks, link)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.validated = true
        Result.passed = true

    -- Autoresolve "Acute Blood Loss Anemia Dx Possibly Lacking Clinical Evidence"
    elseif
        subtitle == "Acute Blood Loss Anemia Dx Possibly Lacking Clinical Evidence" and
        d62CodeLink and
        (
            (not linkTextPossibleNoSignsOfBleedingPresent or signsOfBleeding) and
            (not linkTextPossibleNoMatchingHemoglobinPresent or lowHemoglobinDVLink) and
            (not linkTextPossibleNoAnemiaTreatmentPresent or not anemiaTreatment)
        )
    then
        if lowHemoglobinDVLink then
            lowHemoglobinDVLink.link_text = "Autoresolved Evidence - " .. lowHemoglobinDVLink.link_text
            table.insert(documentedDxLinks, lowHemoglobinDVLink)
        end
        if linkTextPossibleNoSignsOfBleedingPresent then
            local link = MakeHeaderLink(linkTextPossibleNoSignsOfBleeding)
            table.insert(documentedDxLinks, link)
        end
        if linkTextPossibleNoMatchingHemoglobinPresent then
            local link = MakeHeaderLink(linkTextPossibleNoMatchingHemoglobin)
            table.insert(documentedDxLinks, link)
        end
        if linkTextPossibleNoAnemiaTreatmentPresent then
            local link = MakeHeaderLink(linkTextPossibleNoAnemiaTreatment)
            table.insert(documentedDxLinks, link)
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.validated = true
        Result.passed = true

    -- Autoresolve "Possible Acute Blood Loss Anemia"
    elseif
        subtitle == "Possible Acute Blood Loss Anemia" and
        d62CodeLink
    then
        table.insert(documentedDxLinks, d62CodeLink)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true

    -- Autoresolve "Possible Anemia Dx"
    elseif 
        subtitle == "Possible Anemia Dx" and
        #accountAlertCodes > 0
    then
        for _, code in ipairs(accountAlertCodes) do
            local desc = alertCodeDictionary[code]
            local tempCode = GetCodeLink { code = code, text = "Autoresolved Specified Code - " .. desc }
            if tempCode then
                table.insert(documentedDxLinks, tempCode)
                break
            end
        end
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to clinical evidence now existing on the Account"
        Result.validated = true
        Result.passed = true

    -- Alert for "Anemia Dx Possibly Lacking Supporting Evidence"
    elseif #accountAlertCodes > 0 and not lowHemoglobinDVLink and not lowHematocrit30DVLink and not anemiaTreatment then
        if not lowHemoglobinDVLink or not anemiaTreatment then
            local link = MakeHeaderLink(linkTextPossibleNoLows)
            table.insert(documentedDxLinks, link)
        end
        for _, code in ipairs(accountAlertCodes) do
            local desc = alertCodeDictionary[code]
            local tempCode = GetCodeLink { code = code, text = desc }
            if tempCode then
                table.insert(documentedDxLinks, tempCode)
            end
        end
        Result.subtitle = "Anemia Dx Possibly Lacking Supporting Evidence"
        Result.passed = true


    -- Alert for "Acute Blood Loss Anemia Dx Possibly Lacking Clinical Evidence"
    elseif d62CodeLink and (not signsOfBleeding or not lowHemoglobinDVLink or not anemiaTreatment) then
        table.insert(documentedDxLinks, d62CodeLink)

        local link2 = MakeHeaderLink(linkTextPossibleNoSignsOfBleeding)
        link2.is_validated = not (linkTextPossibleNoSignsOfBleedingPresent and signsOfBleeding)
        table.insert(documentedDxLinks, link2)

        local link3 = MakeHeaderLink(linkTextPossibleNoMatchingHemoglobin)
        link3.is_validated = not (linkTextPossibleNoMatchingHemoglobinPresent and lowHemoglobinDVLink)
        table.insert(documentedDxLinks, link3)

        local link4 = MakeHeaderLink(linkTextPossibleNoAnemiaTreatment)
        link4.is_validated = not (linkTextPossibleNoAnemiaTreatmentPresent and anemiaTreatment)
        table.insert(documentedDxLinks, link4)

        Result.subtitle = "Acute Blood Loss Anemia Dx Possibly Lacking Clinical Evidence"
        Result.passed = true

    -- Alert for "Possible Acute Blood Loss Anemia" - Drops
    elseif not d62CodeLink and (#hematocritDropDVLinkPairs > 0 or #hemoglobinDropDVLinkPairs > 0) then
        if hematocritDropDVLinkPairs then
            table.insert(hematocritLinks, hematocritDropDVLinkPairs.hematocritDropLink)
            table.insert(hematocritLinks, hematocritDropDVLinkPairs.hematocritPeakLink)
            table.insert(hematocritLinks, hematocritDropDVLinkPairs.hemoglobinDropLink)
            table.insert(hematocritLinks, hematocritDropDVLinkPairs.hemoglobinPeakLink)
        end
        if hemoglobinDropDVLinkPairs then
            table.insert(hemoglobinLinks, hemoglobinDropDVLinkPairs.hemoglobinDropLink)
            table.insert(hemoglobinLinks, hemoglobinDropDVLinkPairs.hemoglobinPeakLink)
            table.insert(hemoglobinLinks, hemoglobinDropDVLinkPairs.hematocritDropLink)
            table.insert(hemoglobinLinks, hemoglobinDropDVLinkPairs.hematocritPeakLink)
        end
        table.insert(alertTriggerLinks, MakeHeaderLink("Possible Hemoglobin levels decreased by 2 or more or possible Hematocrit levels decreased by 6 or more, along with a possible presence of Bleeding. Please review Clinical Evidence."))
        Result.subtitle = "Possible Acute Blood Loss Anemia"
        Result.passed = true

    -- Alert for "Possible Acute Blood Loss Anemia" - Low hemoglobin, sign of bleeding, and anemia treatment
    elseif not d62CodeLink and not lowHemoglobinDVLink and signsOfBleeding and anemiaTreatment then
        table.insert(hemoglobinLinks, lowHemoglobinDVLink)
        table.insert(alertTriggerLinks, MakeHeaderLink("Possible Low Hgb or Hct, possible sign of Bleeding and Anemia Treatment present."))
        Result.subtitle = "Possible Acute Blood Loss Anemia"
        Result.passed = true

    -- Alert for "Possible Acute Blood Loss Anemia" -Hgb <10 or Hct <30 and possible sign of Bleeding present
    elseif not d62CodeLink and (lowHemoglobin10DVLink or lowHematocrit30DVLink) and signsOfBleeding then
        table.insert(hemoglobinLinks, lowHemoglobin10DVLink)
        table.insert(hematocritLinks, lowHematocrit30DVLink)
        table.insert(alertTriggerLinks, MakeHeaderLink("Possible Hgb <10 or Hct <30 and possible sign of Bleeding present."))
        Result.subtitle = "Possible Acute Blood Loss Anemia"
        Result.passed = true

    -- Alert for "Possible Acute Blood Loss Anemia" - Anemia dx and sign of bleeding and anemia treatment
    elseif not d62CodeLink and (d649CodeLink or d500CodeLink) and signsOfBleeding and anemiaTreatment then
        table.insert(alertTriggerLinks, MakeHeaderLink("Anemia Dx documented, possible sign of bleeding and Anemia Treatment present."))
        table.insert(documentedDxLinks, d500CodeLink)
        table.insert(documentedDxLinks, d649CodeLink)
        Result.subtitle = "Possible Acute Blood Loss Anemia"
        Result.passed = true

    -- Alert for "Possible Acute Blood Loss Anemia" - Low pairs and anemia treatment
    elseif
        #accountAlertCodes == 0 and
        not d649CodeLink and
        (#lowHematocritMultiDVLinkPairs > 0 or #lowHemoglobinMultiDVLinkPairs > 0) and
        anemiaTreatment
    then
        Result.subtitle = "Possible Anemia Dx"
        Result.passed = true
    end



    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        if not Result.validated then
            -- Abstractions
            GetCodeLink { code = "T45.1X5A", text = "Adverse Effect of Antineoplastic and Immunosuppressive Drug", seq = 1, target = clinicalEvidenceLinks }
            GetCodePrefixLink { prefix = "F10.1", text = "Alcohol Abuse", seq = 2, target = clinicalEvidenceLinks }
            GetCodePrefixLink { prefix = "F10.2", text = "Alcohol Dependence", seq = 3, target = clinicalEvidenceLinks }
            GetCodeLink { code = "K70.31", text = "Alcoholic Liver Cirrhosis", seq = 4, target = clinicalEvidenceLinks }
            GetCodeLink { code = "Z51.11", text = "Chemotherapy", seq = 5, target = clinicalEvidenceLinks }
            GetCodeLink { codes = {"N18.1","N18.2","N18.30","N18.31","N18.32","N18.4","N18.5", "N18.9"}, text = "Chronic Kidney Disease", seq = 6, target = clinicalEvidenceLinks }
            GetCodeLink { code = "K27.4", text = "Chronic Peptic Ulcer with Hemorrhage", seq = 7, target = clinicalEvidenceLinks }
            GetAbstractionLink { code = "CURRENT_CHEMOTHERAPY", text = "Current Chemotherapy", seq = 8, target = clinicalEvidenceLinks }
            GetAbstractionLink { code = "DYSPNEA_ON_EXERTION", text = "Dyspnea on Exertion", seq = 9, target = clinicalEvidenceLinks }
            GetCodeLink { code = "N18.6", text = "End-Stage Renal Disease", seq = 10, target = clinicalEvidenceLinks }
            GetCodeLink { code = "R53.83", text = "Fatigue", seq = 11, target = clinicalEvidenceLinks }
            GetCodePrefixLink { prefix = "C82.", text = "Follicular Lymphoma", seq = 12, target = clinicalEvidenceLinks }
            GetCodeLink { codes = {"I50.20", "I50.22", "I50.23", "I50.30", "I50.32", "I50.33", "I50.40", "I5.42", "I50.43", "I50.810", "I50.812", "I50.813", "I50.84", "I50.89", "I50.9"}, text = "Heart Failure", seq = 13, target = clinicalEvidenceLinks }
            GetCodeLink { code = "D58.0", text = "Hereditary Spherocytosis", seq = 14, target = clinicalEvidenceLinks }
            GetCodeLink { code = "B20", text = "HIV", seq = 15, target = clinicalEvidenceLinks }
            GetCodePrefixLink { prefix = "C81.", text = "Hodgkin Lymphoma", seq = 16, target = clinicalEvidenceLinks }
            GetCodeLink { code = "Z51.12", text = "Immunotherapy", seq = 17, target = clinicalEvidenceLinks }
            GetCodeLink { code = "E61.1", text = "Iron Deficiency", seq = 18, target = clinicalEvidenceLinks }
            GetCodePrefixLink { prefix = "C95.", text = "Leukemia of Unspecified Cell Type", seq = 19, target = clinicalEvidenceLinks }
            GetCodePrefixLink { prefix = "C91.", text = "Lymphoid Leukemia", seq = 20, target = clinicalEvidenceLinks }
            GetCodeLink { code = "K22.6", text = "Mallory-Weiss Tear", seq = 21, target = clinicalEvidenceLinks }
            GetCodeLink { codes = {"E40", "E41", "E42", "E43", "E44.0", "E44.1", "E45"}, text = "Malnutrition", seq = 22, target = clinicalEvidenceLinks }
            GetCodePrefixLink { prefix = "C84.", text = "Mature T/NK-Cell Lymphoma", seq = 23, target = clinicalEvidenceLinks }
            GetCodePrefixLink { prefix = "C90.", text = "Multiple Myeloma", seq = 24, target = clinicalEvidenceLinks }
            GetCodePrefixLink { prefix = "C93.", text = "Monocytic Leukemia", seq = 25, target = clinicalEvidenceLinks }
            GetCodeLink { code = "D46.9", text = "Myelodysplastic Syndrome", seq = 26, target = clinicalEvidenceLinks }
            GetCodePrefixLink { prefix = "C92.", text = "Myeloid Leukemia", seq = 27, target = clinicalEvidenceLinks }
            GetCodePrefixLink { prefix = "C83.", text = "Non-Follicular Lymphoma", seq = 28, target = clinicalEvidenceLinks }
            GetCodePrefixLink { prefix = "C94.", text = "Other Leukemias", seq = 29, target = clinicalEvidenceLinks }
            GetCodePrefixLink { prefix = "C86.", text = "Other Types of T/NK-Cell Lymphoma", seq = 30, target = clinicalEvidenceLinks }
            GetCodeLink { code = "R23.1", text = "Pale", seq = 31, target = clinicalEvidenceLinks }
            GetCodeLink { code = "K27.9", text = "Peptic Ulcer", seq = 32, target = clinicalEvidenceLinks }
            GetCodeLink { code = "F19.10", text = "Psychoactive Substance Abuse", seq = 33, target = clinicalEvidenceLinks }
            GetCodeLink { code = "Z51.0", text = "Radiation Therapy", seq = 34, target = clinicalEvidenceLinks }
            GetCodePrefixLink { prefix = "M05.", text = "Rheumatoid Arthritis", seq = 35, target = clinicalEvidenceLinks }
            GetCodePrefixLink { prefix = "D86.", text = "Sarcoidosis", seq = 36, target = clinicalEvidenceLinks }
            GetAbstractionLink { code = "SHORTNESS_OF_BREATH", text = "Shortness of Breath", seq = 37, target = clinicalEvidenceLinks }
            GetCodePrefixLink { prefix = "D57.", text = "Sickle Cell Disorder", seq = 38, target = clinicalEvidenceLinks }
            GetCodeLink { code = "R16.1", text = "Splenomegaly", seq = 39, target = clinicalEvidenceLinks }
            GetCodePrefixLink { prefix = "M32.", text = "Systemic Lupus Erthematosus (SLE)", seq = 40, target = clinicalEvidenceLinks }
            GetCodePrefixLink { prefix = "C85.", text = "Unspecified Non-Hodgkin Lymphoma", seq = 41, target = clinicalEvidenceLinks }
            GetAbstractionLink { code = "WEAKNESS", text = "Weakness", seq = 42, target = clinicalEvidenceLinks }

            -- Labs
            GetDiscreteValueLink { discreteValueNames = dvMCH, text = "MCH", predicate = calcMCH1, seq = 1, target = labsLinks }
            GetDiscreteValueLink { discreteValueNames = dvMCHC, text = "MCHC", predicate = calcMCHC1, seq = 2, target = labsLinks }
            GetDiscreteValueLink { discreteValueNames = dvMCV, text = "MCV", predicate = calcMCV1, seq = 3, target = labsLinks }
            GetDiscreteValueLink { discreteValueNames = dvRBC, text = "RBC", predicate = calcRBC1, seq = 4, target = labsLinks }
            GetDiscreteValueLink { discreteValueNames = dvRDW, text = "RDW", predicate = calcRDW1, seq = 5, target = labsLinks }
            GetDiscreteValueLink { discreteValueNames = dvReticulocyteCount, text = "Reticulocyte Count", predicate = calcReticulocyteCount1, seq = 6, target = labsLinks }
            if not GetDiscreteValueLink { discreteValueNames = dvSerumFerritin, text = "Serum Ferritin", predicate = calcSerumFerritin1, seq = 7, target = labsLinks } then
                GetDiscreteValueLink { discreteValueNames = dvSerumFerritin, text = "Serum Ferritin", predicate = function(x) return true end, seq = 8, target = labsLinks }
            end
            if not GetDiscreteValueLink { discreteValueNames = dvFolate, text = "Serum Folate", predicate = calcFolate1, seq = 9, target = labsLinks } then
                GetDiscreteValueLink { discreteValueNames = dvFolate, text = "Serum Folate", predicate = function(x) return true end, seq = 10, target = labsLinks }
            end
            if not GetDiscreteValueLink { discreteValueNames = dvSerumIron, text = "Serum Iron", predicate = calcSerumIron1, seq = 11, target = labsLinks } then
                GetDiscreteValueLink { discreteValueNames = dvSerumIron, text = "Serum Iron", predicate = function(x) return true end, seq = 12, target = labsLinks }
            end
            GetDiscreteValueLink { discreteValueNames = dvTotalIronBindingCapacity, text = "Total Iron Binding Capacity", predicate = calcTotalIronBindingCapacity1, seq = 13, target = labsLinks }
            GetDiscreteValueLink { discreteValueNames = dvTransferrin, text = "Transferrin", predicate = calcTransferrin1, seq = 14, target = labsLinks }
            GetDiscreteValueLink { discreteValueNames = dvVitaminB12, text = "Vitamin B12", predicate = calcVitB121, seq = 15, target = labsLinks }
            GetDiscreteValueLink { discreteValueNames = dvWBC, text = "WBC", predicate = calcWBC1, seq = 16, target = labsLinks }

            -- Meds
            table.insert(treatmentAndMonitoringLinks, anemiaMedsAbstractionLink)
            table.insert(treatmentAndMonitoringLinks, anemiaMedicationLink)
            table.insert(treatmentAndMonitoringLinks, cellSaverAbstractionLink)
            table.insert(treatmentAndMonitoringLinks, hematopoeticMedicationLink)
            table.insert(treatmentAndMonitoringLinks, hemtopoeticAbstractionLink)
            table.insert(treatmentAndMonitoringLinks, rBloTransfusionCodeLink)
            table.insert(treatmentAndMonitoringLinks, redBloodCellDVLink)

            -- Signs of Bleeding
            table.insert(signOfBleedingLinks, i975CodeLink)
            table.insert(signOfBleedingLinks, k917CodeLink)
            table.insert(signOfBleedingLinks, j957CodeLink)
            table.insert(signOfBleedingLinks, k260CodeLink)
            table.insert(signOfBleedingLinks, k262CodeLink)
            table.insert(signOfBleedingLinks, k250CodeLink)
            table.insert(signOfBleedingLinks, k252CodeLink)
            table.insert(signOfBleedingLinks, k270CodeLink)
            table.insert(signOfBleedingLinks, k272CodeLink)
            table.insert(signOfBleedingLinks, bleedingAbstractionLink)
            table.insert(signOfBleedingLinks, r319CodeLink)
            table.insert(signOfBleedingLinks, k264CodeLink)
            table.insert(signOfBleedingLinks, k266CodeLink)
            table.insert(signOfBleedingLinks, k254CodeLink)
            table.insert(signOfBleedingLinks, k256CodeLink)
            table.insert(signOfBleedingLinks, k276CodeLink)
            table.insert(signOfBleedingLinks, n99510CodeLink)
            table.insert(signOfBleedingLinks, i8501CodeLink)
            table.insert(signOfBleedingLinks, k922CodeLink)
            table.insert(signOfBleedingLinks, hematomaAbstractionLink)
            table.insert(signOfBleedingLinks, k920CodeLink)
            table.insert(signOfBleedingLinks, r310CodeLink)
            table.insert(signOfBleedingLinks, r195CodeLink)
            table.insert(signOfBleedingLinks, k661CodeLink)
            table.insert(signOfBleedingLinks, n3091CodeLink)
            table.insert(signOfBleedingLinks, j9501CodeLink)
            table.insert(signOfBleedingLinks, hemorrhageAbstractionLink)
            table.insert(signOfBleedingLinks, r042CodeLink)
            table.insert(signOfBleedingLinks, i974CodeLink)
            table.insert(signOfBleedingLinks, k916CodeLink)
            table.insert(signOfBleedingLinks, n99CodeLink)
            table.insert(signOfBleedingLinks, g9732CodeLink)
            table.insert(signOfBleedingLinks, g9731CodeLink)
            table.insert(signOfBleedingLinks, j956CodeLink)
            table.insert(signOfBleedingLinks, k921CodeLink)
            table.insert(signOfBleedingLinks, i61CodeLink)
            table.insert(signOfBleedingLinks, i62CodeLink)
            table.insert(signOfBleedingLinks, i60CodeLink)
            table.insert(signOfBleedingLinks, l7632CodeLink)
            table.insert(signOfBleedingLinks, k918CodeLink)
            table.insert(signOfBleedingLinks, i976CodeLink)
            table.insert(signOfBleedingLinks, n991CodeLink)
            table.insert(signOfBleedingLinks, g9752CodeLink)
            table.insert(signOfBleedingLinks, g9751CodeLink)
            table.insert(signOfBleedingLinks, j958CodeLink)
            table.insert(signOfBleedingLinks, k625CodeLink)
            for _, link in ipairs(bloodLossDVLinks) do
                table.insert(signOfBleedingLinks, link)
            end

            -- Vitals
            GetAbstractionLink { code = "LOW_BLOOD_PRESSURE", text = "Blood Pressure", seq = 1, target = vitalsLinks }
            GetDiscreteValueLink { discreteValueNames = dvMAP, text = "Mean Arterial Pressure", predicate = calcMAP1, seq = 2, target = vitalsLinks }
            GetDiscreteValueLink { discreteValueNames = dvSBP, text = "Systolic Blood Pressure", predicate = calcSBP1, seq = 3, target = vitalsLinks }

            -- Hemoglobin/Hematocrit
            for _, link in ipairs(lowHematocritMultiDVLinkPairs) do
                table.insert(hematocritLinks, link.hematocritLink)
                table.insert(hemoglobinLinks, link.hemoglobinLink)
            end
            for _, link in ipairs(lowHemoglobinMultiDVLinkPairs) do
                table.insert(hemoglobinLinks, link.hemoglobinLink)
                table.insert(hematocritLinks, link.hematocritLink)
            end
        end



        ----------------------------------------
        --- Result Finalization 
        ----------------------------------------
        if #bloodLossLinks > 0 then
            bloodLossHeader.links = bloodLossLinks
            table.insert(signOfBleedingLinks, bloodLossHeader)
        end
        if #hemoglobinLinks > 0 then
            hemoglobinHeader.links = hemoglobinLinks
            table.insert(labsLinks, hemoglobinHeader)
        end
        if #hematocritLinks > 0 then
            hematocritHeader.links = hematocritLinks
            table.insert(labsLinks, hematocritHeader)
        end
        if #documentedDxLinks > 0 then
            documentedDxHeader.links = documentedDxLinks
            table.insert(resultLinks, documentedDxHeader)
        end
        if #alertTriggerLinks > 0 then
            alertTriggerHeader.links = alertTriggerLinks
            table.insert(resultLinks, alertTriggerHeader)
        end
        if #clinicalEvidenceLinks > 0 then
            clinicalEvidenceHeader.links = clinicalEvidenceLinks
            table.insert(resultLinks, clinicalEvidenceHeader)
        end
        if #labsLinks > 0 then
            labsHeader.links = labsLinks
            table.insert(resultLinks, labsHeader)
        end
        if #vitalsLinks > 0 then
            vitalsHeader.links = vitalsLinks
            table.insert(resultLinks, vitalsHeader)
        end
        if #treatmentAndMonitoringLinks > 0 then
            treatmentAndMonitoringHeader.links = treatmentAndMonitoringLinks
            table.insert(resultLinks, treatmentAndMonitoringHeader)
        end
        if #signOfBleedingLinks > 0 then
            signOfBleedingHeader.links = signOfBleedingLinks
            table.insert(resultLinks, signOfBleedingHeader)
        end
        if #otherLinks > 0 then
            otherHeader.links = otherLinks
            table.insert(resultLinks, otherHeader)
        end


        if existingAlert then
            resultLinks = MergeLinks(existingAlert.links, resultLinks)
        end
        Result.links = resultLinks
    end
end
