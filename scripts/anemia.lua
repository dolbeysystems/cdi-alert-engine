---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Anemia 
---
--- This script checks an account to see if it matches the criteria for an anemia alert.
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
--[[
#========================================
#  Discrete Value Fields and Calculations
#========================================
dvFolate = ["Folate Lvl (ng/mL)"]
dvHematocrit = ["Hct (%)"]
calcHematocrit1 = lambda x: x < 35
calcHematocrit2 = lambda x: x < 38
calcHematocrit3 = 35
calcHematocrit4 = 38
dvHemoglobin = ["Hgb (g/dL)"]
calcHemoglobin1 = lambda x: x < 13.5
calcHemoglobin2 = lambda x: x < 12
dvImmatureReticulocyteFraction = [""]
calcImmatureReticulocyteFraction1 = lambda x: x < 3
dvMAP = ["Mean Arterial Pressure"]
calcMAP1 = lambda x: x < 60
dvMCH = ["MCH (pg)"]
dvMCHC = ["MCHC (g/dL)"]
dvMCV = ["MCV (fL)"]
dvOccultBloodGastric = ["Occult Blood Gastric"]
dvPlateletCount = ["Platelets (10x3/uL)"]
dvRBC = ["RBC (10x6/uL)"]
dvRDW = ["RDW (%)"]
dvReticulocyteCount = [""]
calcReticulocyteCount1 = lambda x: x < 0.5
dvSBP = ["Systolic Blood Pressure"]
dvSBP2 = ["Systolic Blood Pressure (mmHg)"]
calcSBP1 = lambda x: x < 90
dvSerumFerritin = ["Ferritin Lvl (ng/mL)"]
dvSerumIron = ["Iron Lvl (mcg/dL)"]
dvTotalIronBindingCapacity = ["TIBC (mcg/dL)"]
dvTransferrin = ["Transferrin (mg/dL)"]
dvVitaminB12 = ["Vitamin B12 Lvl (pg/ml)"]
dvWBC = ["WBC (10x3/uL)"]

calcAny = lambda x: x > 0
calcAny1 = 0
--]]


--[[
hemoglobinLabs = MatchedCriteriaLink("Hemoglobin", None, "Hemoglobin", None, True, None, None, 87)
hematocritLabs = MatchedCriteriaLink("Hematocrit", None, "Hematocrit", None, True, None, None, 88)
hemoglobin = MatchedCriteriaLink("Hemoglobin", None, "Hemoglobin", None, True, None, None, 89)
hematocrit = MatchedCriteriaLink("Hematocrit", None, "Hematocrit", None, True, None, None, 90)
mch = MatchedCriteriaLink("MCH", None, "MCH", None, True, None, None, 91)
mchc = MatchedCriteriaLink("MCHC", None, "MCHC", None, True, None, None, 92)
mcv = MatchedCriteriaLink("MCV", None, "MCV", None, True, None, None, 93)
platelets = MatchedCriteriaLink("Platelets", None, "Platelets", None, True, None, None, 94)
rbc = MatchedCriteriaLink("RBC", None, "RBC", None, True, None, None, 95)
rdw = MatchedCriteriaLink("RDW", None, "RDW", None, True, None, None, 96)
ferritin = MatchedCriteriaLink("Ferritin", None, "Ferritin", None, True, None, None, 97)
folate = MatchedCriteriaLink("Folate", None, "Folate", None, True, None, None, 98)
iron = MatchedCriteriaLink("Iron", None, "Iron", None, True, None, None, 99)
ironBindingCap = MatchedCriteriaLink("Iron Binding Capacity", None, "Iron Binding Capacity", None, True, None, None, 100)
transferrin = MatchedCriteriaLink("Transferrin", None, "Transferrin", None, True, None, None, 101)
vitaminB12 = MatchedCriteriaLink("Vitamin B12", None, "Vitamin B12", None, True, None, None, 102)
wbc = MatchedCriteriaLink("WBC", None, "WBC", None, True, None, None, 103)
--]]

local hemoglobinLabsHeader = MakeHeaderLink("Hemoglobin")
local hematocritLabsHeader = MakeHeaderLink("Hematocrit")
local hemoglobinHeader = MakeHeaderLink("Hemoglobin")
local hematocritHeader = MakeHeaderLink("Hematocrit")
local mchHeader = MakeHeaderLink("MCH")
local mchcHeader = MakeHeaderLink("MCHC")
local mcvHeader = MakeHeaderLink("MCV")
local plateletsHeader = MakeHeaderLink("Platelets")
local rbcHeader = MakeHeaderLink("RBC")
local rdwHeader = MakeHeaderLink("RDW")
local ferritinHeader = MakeHeaderLink("Ferritin")
local folateHeader = MakeHeaderLink("Folate")
local ironHeader = MakeHeaderLink("Iron")
local ironBindingCapHeader = MakeHeaderLink("Iron Binding Capacity")
local transferrinHeader = MakeHeaderLink("Transferrin")
local vitaminB12Header = MakeHeaderLink("Vitamin B12")
local wbcHeader = MakeHeaderLink("WBC")


local hemoglobinLabsLinks = MakeNilLinkArray()
local hematocritLabsLinks = MakeNilLinkArray()
local hemoglobinLinks = MakeNilLinkArray()
local hematocritLinks = MakeNilLinkArray()
local mchLinks = MakeNilLinkArray()
local mchcLinks = MakeNilLinkArray()
local mcvLinks = MakeNilLinkArray()
local plateletsLinks = MakeNilLinkArray()
local rbcLinks = MakeNilLinkArray()
local rdwLinks = MakeNilLinkArray()
local ferritinLinks = MakeNilLinkArray()
local folateLinks = MakeNilLinkArray()
local ironLinks = MakeNilLinkArray()
local ironBindingCapLinks = MakeNilLinkArray()
local transferrinLinks = MakeNilLinkArray()
local vitaminB12Links = MakeNilLinkArray()
local wbcLinks = MakeNilLinkArray()

local d649Code = MakeNilLink()
local d500Code = MakeNilLink()
local eblAbs = MakeNilLink()
local d62Code = MakeNilLink()
local lowHemoglobinDV = MakeNilLink()
local highHemoglobinDV = MakeNilLink()
local lowHematocritDV = MakeNilLink()
local hemoHemaConsecutDropDV = { false, false }
local procedureHemoDV = { false, false }
local anemiaMedsAbs = MakeNilLink()
local anemiaMeds = MakeNilLink()
local fluidBolusMeds = MakeNilLink()
local hematopoeticMed = MakeNilLink()
local hemtopoeticAbs = MakeNilLink()
local isotonicIVSolMed = MakeNilLink()
local a30233N1Code = MakeNilLink()
local sodiumChlorideMed = MakeNilLink()
local i975Codes = MakeNilLinkArray()
local k917Codes = MakeNilLinkArray()
local j957Codes = MakeNilLinkArray()
local k260Code = MakeNilLink()
local k262Code = MakeNilLink()
local k250Code = MakeNilLink()
local k252Code = MakeNilLink()
local k270Code = MakeNilLink()
local k272Code = MakeNilLink()
local r319Code = MakeNilLink()
local k264Code = MakeNilLink()
local k266Code = MakeNilLink()
local k254Code = MakeNilLink()
local k256Code = MakeNilLink()
local k276Code = MakeNilLink()
local n99510Code = MakeNilLink()
local r040Code = MakeNilLink()
local i8501Code = MakeNilLink()
local giBleedCodes = MakeNilLinkArray()
local k922Code = MakeNilLink()
local hematomaAbs = MakeNilLink()
local k920Code = MakeNilLink()
local r310Code = MakeNilLink()
local r195Code = MakeNilLink()
local k661Code = MakeNilLink()
local n3091Code = MakeNilLink()
local j9501Code = MakeNilLink()
local r042Code = MakeNilLink()
local i974Codes = MakeNilLinkArray()
local k916Codes = MakeNilLinkArray()
local n99Codes = MakeNilLinkArray()
local g9732Code = MakeNilLink()
local g9731Code = MakeNilLink()
local j956Codes = MakeNilLinkArray()
local k921Code = MakeNilLink()
local n920Code = MakeNilLink()
local i61Codes = MakeNilLinkArray()
local i62Codes = MakeNilLinkArray()
local i60Codes = MakeNilLinkArray()
local l7632Code = MakeNilLink()
local k918Codes = MakeNilLinkArray()
local i976Codes = MakeNilLinkArray()
local n991Codes = MakeNilLinkArray()
local g9752Code = MakeNilLink()
local g9751Code = MakeNilLink()
local j958Codes = MakeNilLinkArray()
local k625Code = MakeNilLink()

local SOB = false
local AT = false
local noLabs = {}






--------------------------------------------------------------------------------
--- Alert Qualification 
--------------------------------------------------------------------------------
if not ExistingAlert or not ExistingAlert.validated then
end



--------------------------------------------------------------------------------
--- Additional Link Creation
--------------------------------------------------------------------------------
if AlertMatched then
end



--------------------------------------------------------------------------------
--- Result Finalization 
--------------------------------------------------------------------------------
if AlertMatched or AlertAutoResolved then
    if hemoglobinLabsLinks and #hemoglobinLabsLinks > 0 then
        hemoglobinLabsHeader.links = hemoglobinLabsLinks
        table.insert(Result.links, hemoglobinLabsHeader)
    end
    if hematocritLabsLinks and #hematocritLabsLinks > 0 then
        hematocritLabsHeader.links = hematocritLabsLinks
        table.insert(Result.links, hematocritLabsHeader)
    end
    if hemoglobinLinks and #hemoglobinLinks > 0 then
        hemoglobinHeader.links = hemoglobinLinks
        table.insert(Result.links, hemoglobinHeader)
    end
    if hematocritLinks and #hematocritLinks > 0 then
        hematocritHeader.links = hematocritLinks
        table.insert(Result.links, hematocritHeader)
    end
    if mchLinks and #mchLinks > 0 then
        mchHeader.links = mchLinks
        table.insert(Result.links, mchHeader)
    end
    if mchcLinks and #mchcLinks > 0 then
        mchcHeader.links = mchcLinks
        table.insert(Result.links, mchcHeader)
    end
    if mcvLinks and #mcvLinks > 0 then
        mcvHeader.links = mcvLinks
        table.insert(Result.links, mcvHeader)
    end
    if plateletsLinks and #plateletsLinks > 0 then
        plateletsHeader.links = plateletsLinks
        table.insert(Result.links, plateletsHeader)
    end
    if rbcLinks and #rbcLinks > 0 then
        rbcHeader.links = rbcLinks
        table.insert(Result.links, rbcHeader)
    end
    if rdwLinks and #rdwLinks > 0 then
        rdwHeader.links = rdwLinks
        table.insert(Result.links, rdwHeader)
    end
    if ferritinLinks and #ferritinLinks > 0 then
        ferritinHeader.links = ferritinLinks
        table.insert(Result.links, ferritinHeader)
    end
    if folateLinks and #folateLinks > 0 then
        folateHeader.links = folateLinks
        table.insert(Result.links, folateHeader)
    end
    if ironLinks and #ironLinks > 0 then
        ironHeader.links = ironLinks
        table.insert(Result.links, ironHeader)
    end
    if ironBindingCapLinks and #ironBindingCapLinks > 0 then
        ironBindingCapHeader.links = ironBindingCapLinks
        table.insert(Result.links, ironBindingCapHeader)
    end
    if transferrinLinks and #transferrinLinks > 0 then
        transferrinHeader.links = transferrinLinks
        table.insert(Result.links, transferrinHeader)
    end
    if vitaminB12Links and #vitaminB12Links > 0 then
        vitaminB12Header.links = vitaminB12Links
        table.insert(Result.links, vitaminB12Header)
    end
    if wbcLinks and #wbcLinks > 0 then
        wbcHeader.links = wbcLinks
        table.insert(Result.links, wbcHeader)
    end

    local resultLinks = GetFinalTopLinks({
        hemoglobinLabsHeader,
        hematocritLabsHeader,
        hemoglobinHeader,
        hematocritHeader,
        mchHeader,
        mchcHeader,
        mcvHeader,
        plateletsHeader,
        rbcHeader,
        rdwHeader,
        ferritinHeader,
        folateHeader,
        ironHeader,
        ironBindingCapHeader,
        transferrinHeader,
        vitaminB12Header,
        wbcHeader
    })

    resultLinks = MergeLinksWithExisting(ExistingAlert, resultLinks)
    Result.links = resultLinks
    Result.passed = true
end

