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
--- Lua type definitions
--------------------------------------------------------------------------------
--- @class HemoglobinHematocritDiscreteValuePair
--- @field hemoglobin DiscreteValue
--- @field hematocrit DiscreteValue
---
--- @class HemoglobinHematocritPeakDropLinks
--- @field hemoglobinPeakLink CdiAlertLink
--- @field hemoglobinDropLink CdiAlertLink
--- @field hematocritPeakLink CdiAlertLink
--- @field hematocritDropLink CdiAlertLink



--------------------------------------------------------------------------------
--- Requires 
--------------------------------------------------------------------------------
require("libs.common")
require("libs.standard_cdi")



--------------------------------------------------------------------------------
--- Functions 
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--- Get Low Hemoglobin Discrete Value Pairs
---
--- @return HemoglobinHematocritDiscreteValuePair[]
--------------------------------------------------------------------------------
local function GetLowHemoglobinValuePairs()
    local lowHemoglobinValue = 12

    if Account.patient.gender == "M" then
        lowHemoglobinValue = 13.5
    end

    --- @type HemoglobinHematocritDiscreteValuePair[]
    local lowHemoglobinPairs = {}

    local lowHemoglobinValues = GetOrderedDiscreteValues({
        discreteValueName = "Hemoglobin",
        predicate = function(dv)
            return GetDvValueNumber(dv) <= lowHemoglobinValue
        end,
        daysBack = 31
    })
    for i = 1, #lowHemoglobinValues do
        local dvHemoglobin = lowHemoglobinValues[i]
        local dvDate = dvHemoglobin.result_date
        local dvHematocrit = GetDiscreteValueNearestToDate({
            discreteValueName = "Hematocrit",
            --- @cast dvDate string
            date = dvDate
        })
        if dvHematocrit then
            table.insert(lowHemoglobinPairs, { hemoglobin = dvHemoglobin, hematocrit = dvHematocrit })
        end
    end

    return lowHemoglobinPairs
end

--------------------------------------------------------------------------------
--- Get Low Hemoglobin Discrete Value Pairs
---
--- @return HemoglobinHematocritDiscreteValuePair[]
--------------------------------------------------------------------------------
local function GetLowHematocritDiscreteValuePairs()
    local lowHematocritValue = 35

    if Account.patient.gender == "M" then
        lowHematocritValue = 38
    end

    --- @type HemoglobinHematocritDiscreteValuePair[]
    local lowHematocritPairs = {}

    local lowHematomocritValues = GetOrderedDiscreteValues({
        discreteValueName = "Hematocrit",
        predicate = function(dv)
            return GetDvValueNumber(dv) <= lowHematocritValue
        end,
        daysBack = 31
    })
    for i = 1, #lowHematomocritValues do
        local dvHematocrit = lowHematomocritValues[i]
        local dvDate = dvHematocrit.result_date
        local dvHemoglobin = GetDiscreteValueNearestToDate({
            discreteValueName = "Hemoglobin",
            --- @cast dvDate string
            date = dvDate
        })
        if dvHemoglobin then
            table.insert(lowHematocritPairs, { hemoglobin = dvHemoglobin, hematocrit = dvHematocrit })
        end
    end
    return lowHematocritPairs
end

--------------------------------------------------------------------------------
--- Get Hemoglobin and Hematocrit Links denoting a significant drop in hemoglobin 
---
--- @return HemoglobinHematocritPeakDropLinks? - Peak and Drop links for Hemoglobin and Hematocrit if present
--------------------------------------------------------------------------------
local function GetHemoglobinDropPairs()
    local hemoglobinPeakLink = nil
    local hemoglobinDropLink = nil
    local hematocritPeakLink = nil
    local hematocritDropLink = nil

    local highestHemoglobinInPastWeek = GetHighestDiscreteValue({
        discreteValueName = "Hemoglobin",
        daysBack = 7
    })
    local lowestHemoglobinInPastWeekAfterHighest = GetLowestDiscreteValue({
        discreteValueName = "Hemoglobin",
        daysBack = 7,
        predicate = function(dv)
            return highestHemoglobinInPastWeek ~= nil and dv.result_date > highestHemoglobinInPastWeek.result_date
        end
    })
    local hemoglobinDelta = 0

    if highestHemoglobinInPastWeek and lowestHemoglobinInPastWeekAfterHighest then
        hemoglobinDelta = GetDvValueNumber(highestHemoglobinInPastWeek) - GetDvValueNumber(lowestHemoglobinInPastWeekAfterHighest)
        if hemoglobinDelta >= 2 then
            hemoglobinPeakLink = GetLinkForDiscreteValue(highestHemoglobinInPastWeek, "Peak Hemoglobin", 1, true)
            hemoglobinDropLink = GetLinkForDiscreteValue(lowestHemoglobinInPastWeekAfterHighest, "Dropped Hemoglobin", 2, true)
            local hemoglobinPeakHemocrit = GetDiscreteValueNearestToDate({
                discreteValueName = "Hematocrit",
                date = highestHemoglobinInPastWeek.result_date
            })
            local hemoglobinDropHemocrit = GetDiscreteValueNearestToDate({
                discreteValueName = "Hematocrit",
                date = lowestHemoglobinInPastWeekAfterHighest.result_date
            })
            if hemoglobinPeakHemocrit then
                hematocritPeakLink = GetLinkForDiscreteValue(hemoglobinPeakHemocrit, "Hematocrit at Hemoglobin Peak", 3, true)
            end
            if hemoglobinDropHemocrit then
                hematocritDropLink = GetLinkForDiscreteValue(hemoglobinDropHemocrit, "Hematocrit at Hemoglobin Drop", 4, true)
            end
        end
    end

    if hemoglobinPeakLink and hemoglobinDropLink and hematocritPeakLink and hematocritDropLink then
        return {
            hemoglobinPeakLink = hemoglobinPeakLink,
            hemoglobinDropLink = hemoglobinDropLink,
            hematocritPeakLink = hematocritPeakLink,
            hematocritDropLink = hematocritDropLink
        }
    else
        return nil
    end
end

--------------------------------------------------------------------------------
--- Get Hemoglobin and Hematocrit Links denoting a significant drop in hematocrit
---
--- @return HemoglobinHematocritPeakDropLinks? - Peak and Drop links for Hemoglobin and Hematocrit if present
--------------------------------------------------------------------------------
local function GetHematocritDropPairs()
    local hemoglobinPeakLink = nil
    local hemoglobinDropLink = nil
    local hematocritPeakLink = nil
    local hematocritDropLink = nil

    -- If we didn't find the hemoglobin drop, look for a hematocrit drop
    local highestHematocritInPastWeek = GetHighestDiscreteValue({
        discreteValueName = "Hematocrit",
        daysBack = 7
    })
    local lowestHematocritInPastWeekAfterHighest = GetLowestDiscreteValue({
        discreteValueName = "Hematocrit",
        daysBack = 7,
        predicate = function(dv)
            return highestHematocritInPastWeek ~= nil and dv.result_date > highestHematocritInPastWeek.result_date
        end
    })
    local hematocritDelta = 0

    if highestHematocritInPastWeek and lowestHematocritInPastWeekAfterHighest then
        hematocritDelta = GetDvValueNumber(highestHematocritInPastWeek) - GetDvValueNumber(lowestHematocritInPastWeekAfterHighest)
        if hematocritDelta >= 6 then
            hematocritPeakLink = GetLinkForDiscreteValue(highestHematocritInPastWeek, "Peak Hematocrit", 5, true)
            hematocritDropLink = GetLinkForDiscreteValue(lowestHematocritInPastWeekAfterHighest, "Dropped Hematocrit", 6, true)
            local hemocritPeakHemoglobin = GetDiscreteValueNearestToDate({
                discreteValueName = "Hemoglobin",
                date = highestHematocritInPastWeek.result_date
            })
            local hemocritDropHemoglobin = GetDiscreteValueNearestToDate({
                discreteValueName = "Hemoglobin",
                date = lowestHematocritInPastWeekAfterHighest.result_date
            })
            if hemocritPeakHemoglobin then
                hemoglobinPeakLink = GetLinkForDiscreteValue(hemocritPeakHemoglobin, "Hemoglobin at Hematocrit Peak", 7, true)
            end
            if hemocritDropHemoglobin then
                hemoglobinDropLink = GetLinkForDiscreteValue(hemocritDropHemoglobin, "Hemoglobin at Hematocrit Drop", 8, true)
            end
        end
    end

    if hemoglobinPeakLink and hemoglobinDropLink and hematocritPeakLink and hematocritDropLink then
        return {
            hemoglobinPeakLink = hemoglobinPeakLink,
            hemoglobinDropLink = hemoglobinDropLink,
            hematocritPeakLink = hematocritPeakLink,
            hematocritDropLink = hematocritDropLink
        }
    else
        return nil
    end
end



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


local hemoglobinLabsHeader = MakeHeaderLink("Hemoglobin")
local hematocritLabsHeader = MakeHeaderLink("Hematocrit")
local soBleedingHeader = MakeHeaderLink("Sign of Bleeding")
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

local hemoglobinLabsLinks = MakeLinkArray()
local hematocritLabsLinks = MakeLinkArray()
local soBleedingLinks = MakeLinkArray()
local hemoglobinLinks = MakeLinkArray()
local hematocritLinks = MakeLinkArray()
local mchLinks = MakeLinkArray()
local mchcLinks = MakeLinkArray()
local mcvLinks = MakeLinkArray()
local plateletsLinks = MakeLinkArray()
local rbcLinks = MakeLinkArray()
local rdwLinks = MakeLinkArray()
local ferritinLinks = MakeLinkArray()
local folateLinks = MakeLinkArray()
local ironLinks = MakeLinkArray()
local ironBindingCapLinks = MakeLinkArray()
local transferrinLinks = MakeLinkArray()
local vitaminB12Links = MakeLinkArray()
local wbcLinks = MakeLinkArray()

local d649Code = MakeNilLink()
local d500Code = MakeNilLink()
local eblAbs = MakeNilLink()
local d62Code = MakeNilLink()
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
local lowHemoglobinAbs = MakeNilLink()
-- @type HemoglobinHematocritPeakDropLinks?
local hemoglobinDropLinks = nil
-- @type HemoglobinHematocritPeakDropLinks?
local hematocritDropLinks = nil
-- @type HemoglobinHematocritDiscreteValuePair[]?
local lowHemoglobinPairs = {}
-- @type HemoglobinHematocritDiscreteValuePair[]?
local lowHematocritPairs = {}


local anySignsOfBleeding = false
local anyAnemiaTreatment = false


local anemiaTreatmentTrigger = false
local signsOfBleedingTrigger = false
local lowHemoglobinOrHematocritTrigger = false


--------------------------------------------------------------------------------
--- Alert Qualification 
--------------------------------------------------------------------------------
if not ExistingAlert or not ExistingAlert.validated then
    -- Alert Trigger
    d649Code = GetCodeLinks { code="D64.9", text="Anemia, Unspecified" }
    d500Code = GetCodeLinks { code="D50.0", text="Iron Deficiency Anemia" }
    eblAbs = GetAbstractionValueLinks { code="EVIDENCE_OF_BLEEDING", text="Evidence of Bleeding" }
    d62Code = GetCodeLinks { code="D62", text="Acute Posthemorrhagic Anemia" }

    -- Labs
    lowHemoglobinPairs = GetLowHemoglobinValuePairs()
    lowHematocritPairs = GetLowHematocritDiscreteValuePairs()
    hemoglobinDropLinks = GetHemoglobinDropPairs()
    hematocritDropLinks = GetHematocritDropPairs()

    if Account.patient.gender == "F" then
        lowHemoglobinAbs = GetAbstractionLinks { code="LOW_HEMOGLOBIN", text="Hemoglobin Female", seq=2 }
    elseif Account.patient.gender == "M" then
        lowHemoglobinAbs = GetAbstractionLinks { code="LOW_HEMOGLOBIN", text="Hemoglobin Male", seq=2 }
    end

    -- Meds
    anemiaMedsAbs = GetAbstractionLinks { code="ANEMIA_MEDICATION", text="Anemia Medication", seq=1 }
    anemiaMeds = GetMedicationLinks { cat="Anemia Supplements", text="Anemia Supplements", seq=2 }
    fluidBolusMeds = GetMedicationLinks { cat="Fluid Bolus", text="Fluid Bolus", seq=3 }
    hematopoeticMed = GetMedicationLinks { cat="Hemopoietic Agent", text="Hematopoietic Agent", seq=4 }
    hemtopoeticAbs = GetAbstractionLinks { code="HEMATOPOIETIC_AGENT", text="Hematopoietic Agent", seq=5 }
    isotonicIVSolMed = GetMedicationLinks { cat="Isotonic IV Solution", text="Isotonic IV Solution", seq=6 }
    a30233N1Code = GetCodeLinks { code="30233N1", text="Red Blood Cell Transfusion", seq=7 }
    sodiumChlorideMed = GetMedicationLinks { cat="Sodium Chloride", text="Sodium Chloride", seq=8 }

    -- Signs of Bleeding
    i975Codes = GetCodeLinks { codes={"I97.51", "I97.52"}, text="Accidental Puncture/Laceration of Circulatory System Organ During Procedure", seq=1 }
    k917Codes = GetCodeLinks { codes={"K91.71", "K91.72"}, text="Accidental Puncture/Laceration of Digestive System Organ During Procedure", seq=2 }
    j957Codes = GetCodeLinks { codes={"J95.71", "J95.72"}, text="Accidental Puncture/Laceration of Respiratory System Organ During Procedure", seq=3 }
    k260Code = GetCodeLinks { code="K26.0", text="Acute Duodenal Ulcer with Hemorrhage", seq=4 }
    k262Code = GetCodeLinks { code="K26.2", text="Acute Duodenal Ulcer with Hemorrhage and Perforation", seq=5 }
    k250Code = GetCodeLinks { code="K25.0", text="Acute Gastric Ulcer with Hemorrhage", seq=6 }
    k252Code = GetCodeLinks { code="K25.2", text="Acute Gastric Ulcer with Hemorrhage and Perforation", seq=7 }
    k270Code = GetCodeLinks { code="K27.0", text="Acute Peptic Ulcer with Hemorrhage", seq=8 }
    k272Code = GetCodeLinks { code="K27.2", text="Acute Peptic Ulcer with Hemorrhage and Perforation", seq=9 }
    r319Code = GetCodeLinks { code="R31.9", text="Bloody Urine", seq=10 }
    k264Code = GetCodeLinks { code="K26.4", text="Chronic Duodenal Ulcer with Hemorrhage", seq=11 }
    k266Code = GetCodeLinks { code="K26.6", text="Chronic Duodenal Ulcer with Hemorrhage and Perforation", seq=12 }
    k254Code = GetCodeLinks { code="K25.4", text="Chronic Gastric Ulcer with Hemorrhage", seq=13 }
    k256Code = GetCodeLinks { code="K25.6", text="Chronic Gastric Ulcer with Hemorrhage and Perforation", seq=14 }
    k276Code = GetCodeLinks { code="K27.6", text="Chronic Peptic Ulcer with Hemorrhage and Perforation", seq=15 }
    n99510Code = GetCodeLinks { code="N99.510", text="Cystostomy Hemorrhage", seq=16 }
    r040Code = GetCodeLinks { code="R04.0", text="Epistaxis", seq=17 }
    i8501Code = GetCodeLinks { code="I85.01", text="Esophageal Varices with Bleeding", seq=18 }
    giBleedCodes = GetCodeLinks {
        codes = {
            "K25.0", "K25.2", "K25.4", "K25.6", "K26.0", "K26.2", "K26.4", "K26.6", "K27.0", "K27.2", "K27.4", "K27.6", "K28.0",
            "K28.2", "K28.4", "K28.6", "K29.01", "K29.21", "K29.31", "K29.41", "K29.51", "K29.61", "K29.71", "K29.81", "K29.91", "K31.811", "K31.82",
            "K55.21", "K57.01", "K57.11", "K57.13", "K57.21", "K57.31", "K57.33", "K57.41", "K57.51", "K57.53", "K57.81", "K57.91", "K57.93", "K62.5",
            "K92.0", "K92.2"
        },
        text = "GI Bleed",
        seq = 19
    }
    k922Code = GetCodeLinks { code="K92.2", text="GI Hemorrhage", seq=20 }
    hematomaAbs = GetAbstractionLinks { code="HEMATOMA", text="Hematoma", seq=21 }
    k920Code = GetCodeLinks { code="K92.0", text="Hematemesis", seq=22 }
    r310Code = GetFirstCodePrefixLink { prefix = "R31.", text="Hematuria", seq=23 }
    r195Code = GetCodeLinks { code="R19.5", text="Heme-Positive Stool", seq=24 }
    k661Code = GetCodeLinks { code="K66.1", text="Hemoperitoneum", seq=25 }
    n3091Code = GetCodeLinks { code="N30.91", text="Hemorrhagic Cystitis", seq=26 }
    j9501Code = GetCodeLinks { code="J95.01", text="Hemorrhage from Tracheostomy Stoma", seq=27 }
    r042Code = GetCodeLinks { code="R04.2", text="Hemoptysis", seq=28 }
    i974Codes = GetCodeLinks { codes={"I97.410", "I97.411", "I97.418", "I97.42"}, text="Intraoperative Hemorrhage/Hematoma of Circulatory System Organ", seq=29 }
    k916Codes = GetCodeLinks { codes={"K91.61", "K91.62"}, text="Intraoperative Hemorrhage/Hematoma of Digestive System Organ", seq=30 }
    n99Codes = GetCodeLinks { codes={"N99.61", "N99.62"}, text="Intraoperative Hemorrhage/Hematoma of Genitourinary System", seq=31 }
    g9732Code = GetCodeLinks { code="G97.32", text="Intraoperative Hemorrhage/Hematoma of Nervous System Organ", seq=32 }
    g9731Code = GetCodeLinks { code="G97.31", text="Intraoperative Hemorrhage/Hematoma of Nervous System Procedure", seq=33 }
    j956Codes = GetCodeLinks { codes={"J95.61", "J95.62"}, text="Intraoperative Hemorrhage/Hematoma of Respiratory System", seq=34 }
    k921Code = GetCodeLinks { code="K92.1", text="Melena", seq=35 }
    n920Code = GetCodeLinks { code="N92.0", text="Menorrhagia", seq=36 }
    i61Codes = GetAllCodePrefixLinks { prefix="I61.", text="Nontraumatic Intracerebral Hemorrhage", seq=37 }
    i62Codes = GetAllCodePrefixLinks { prefix="I62.", text="Nontraumatic Intracerebral Hemorrhage", seq=38 }
    i60Codes = GetAllCodePrefixLinks { prefix="I60.", text="Nontraumatic Subarachnoid Hemorrhage", seq=39 }
    l7632Code = GetCodeLinks { code="L76.32", text="Postoperative Hematoma", seq=40 }
    k918Codes = GetCodeLinks { codes={"K91.840", "K91.841", "K91.870", "K91.871"}, text="Postoperative Hemorrhage/Hematoma of Digestive System Organ", seq=41 }
    i976Codes = GetCodeLinks { codes={"I97.610", "I97.611", "I97.618", "I97.620"}, text="Postoperative Hemorrhage/Hematoma of Circulatory System Organ", seq=42 }
    n991Codes = GetCodeLinks { codes={"N99.820", "N99.821", "N99.840", "N99.841"}, text="Postoperative Hemorrhage/Hematoma of Genitourinary System", seq=43 }
    g9752Code = GetCodeLinks { code="G97.52", text="Postoperative Hemorrhage/Hematoma of Nervous System Organ", seq=44 }
    g9751Code = GetCodeLinks { code="G97.51", text="Postoperative Hemorrhage/Hematoma of Nervous System Procedure", seq=45 }
    j958Codes = GetCodeLinks { codes={"J95.830", "J95.831", "J95.860", "J95.861"}, text="Postoperative Hemorrhage/Hematoma of Respiratory System", seq=46 }
    k625Code = GetCodeLinks { code="K62.5", text="Rectal Bleeding", seq=47 }

    anySignsOfBleeding =
        (i975Codes ~= nil and #i975Codes > 0) or
        (k917Codes ~= nil and #k917Codes > 0) or
        (j957Codes ~= nil and #j957Codes > 0) or
        k260Code ~= nil or
        k262Code ~= nil or
        k250Code ~= nil or
        k252Code ~= nil or
        k270Code ~= nil or
        k272Code ~= nil or
        k264Code ~= nil or
        k266Code ~= nil or
        k254Code ~= nil or
        k256Code ~= nil or
        k276Code ~= nil or
        n99510Code ~= nil or
        i8501Code ~= nil or
        k922Code ~= nil or
        hematomaAbs ~= nil or
        k920Code ~= nil or
        r310Code ~= nil or
        k661Code ~= nil or
        n3091Code ~= nil or
        j9501Code ~= nil or
        r042Code ~= nil or
        (i974Codes ~= nil and #i974Codes > 0) or
        (k916Codes ~= nil and #k916Codes > 0) or
        (n99Codes ~= nil and #n99Codes > 0) or
        g9732Code ~= nil or
        g9731Code ~= nil or
        (j956Codes ~= nil and #j956Codes > 0) or
        k921Code ~= nil or
        n920Code ~= nil or
        l7632Code ~= nil or
        (k918Codes ~= nil and #k918Codes > 0) or
        (i976Codes ~= nil and #i976Codes > 0) or
        (n991Codes ~= nil and #n991Codes > 0) or
        g9752Code ~= nil or
        g9751Code ~= nil or
        (j958Codes ~= nil and #j958Codes > 0) or
        k625Code ~= nil or
        r319Code ~= nil or
        r040Code ~= nil or
        (giBleedCodes ~= nil and #giBleedCodes > 0) or
        r195Code ~= nil or
        (i61Codes ~= nil and #i61Codes > 0) or
        (i62Codes ~= nil and #i62Codes > 0) or
        (i60Codes ~= nil and #i60Codes > 0) or
        (eblAbs ~= nil)

    anyAnemiaTreatment =
        anemiaMedsAbs ~= nil or
        anemiaMeds ~= nil or
        fluidBolusMeds ~= nil or
        hematopoeticMed ~= nil or
        hemtopoeticAbs ~= nil or
        isotonicIVSolMed ~= nil or
        a30233N1Code ~= nil or
        sodiumChlorideMed ~= nil

    local anyAlertCodePresent = (#accountAlertCodes > 0)
    local acuteBloodLossAnemiaCodePresent = (d62Code ~= nil)
    local unspecifiedOrSecondaryToBloodLossAnemiaCodePresent = (d649Code ~= nil or d500Code ~= nil)
    local lowHemoglobinAbsPresent = (lowHemoglobinAbs ~= nil)
    local lowHemoglobinDvCount = (#lowHemoglobinPairs)
    local lowHemoglobinDvAbsCount = lowHemoglobinDvCount + (lowHemoglobinAbsPresent and 1 or 0)
    local lowHematocritDvCount = (#lowHematocritPairs)
    local hemoglobinDropPresent = (hemoglobinDropLinks and #hemoglobinDropLinks > 0)
    local hematocritDropPresent = (hematocritDropLinks and #hematocritDropLinks > 0)

    local acuteBloodLossAlertPresent = (ExistingAlert ~= nil and ExistingAlert.subtitle == "Possible Acute Blood Loss Anemia")
    local anemiaAlertPresent = (ExistingAlert ~= nil and ExistingAlert.subtitle == "Possible Anemia")

    if acuteBloodLossAlertPresent and acuteBloodLossAnemiaCodePresent then
        -- Autoresolve Possible Acute Blood Loss
        table.insert(DocumentationIncludesLinks, d62Code)
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        AutoResolved = true

    elseif not acuteBloodLossAnemiaCodePresent and unspecifiedOrSecondaryToBloodLossAnemiaCodePresent and anySignsOfBleeding and anyAnemiaTreatment then
        -- Possible acute blood loss by d649Code or d500Code (#2)
        if d500Code ~= nil then
            table.insert(DocumentationIncludesLinks, d500Code)
        end
        if d649Code ~= nil then
            table.insert(DocumentationIncludesLinks, d649Code)
        end
        anemiaTreatmentTrigger = true
        signsOfBleedingTrigger = true
        Result.subtitle = "Possible Acute Blood Loss Anemia"
        AlertMatched = true

    elseif not acuteBloodLossAnemiaCodePresent and (lowHemoglobinDvCount >= 1 or lowHematocritDvCount >= 1 or lowHemoglobinAbsPresent) and anySignsOfBleeding and anyAnemiaTreatment then
        -- Possible acute blood loss by lowHemoHemaPairs or lowHemoglobinAbs (#3)
        anemiaTreatmentTrigger = true
        signsOfBleedingTrigger = true
        lowHemoglobinOrHematocritTrigger = true
        Result.subtitle = "Possible Acute Blood Loss Anemia"
        AlertMatched = true

    elseif not acuteBloodLossAnemiaCodePresent and (hemoglobinDropPresent or hematocritDropPresent) and anySignsOfBleeding then
        -- Possible acute blood loss by hemoHemaPeakDropLinks (#4)
        signsOfBleedingTrigger = true
        if hemoglobinDropLinks ~= nil then
            table.insert(hemoglobinLinks, hemoglobinDropLinks.hemoglobinPeakLink)
            table.insert(hemoglobinLinks, hemoglobinDropLinks.hemoglobinDropLink)
            table.insert(hemoglobinLinks, hemoglobinDropLinks.hematocritPeakLink)
            table.insert(hemoglobinLinks, hemoglobinDropLinks.hematocritDropLink)
            hemoglobinHeader.links = hemoglobinLinks
            table.insert(DocumentationIncludesLinks, hemoglobinHeader)
        elseif hematocritDropLinks ~= nil then
            table.insert(hematocritLinks, hematocritDropLinks.hematocritPeakLink)
            table.insert(hematocritLinks, hematocritDropLinks.hematocritDropLink)
            table.insert(hematocritLinks, hematocritDropLinks.hemoglobinPeakLink)
            table.insert(hematocritLinks, hematocritDropLinks.hemoglobinDropLink)
            hematocritHeader.links = hematocritLinks
            table.insert(DocumentationIncludesLinks, hematocritHeader)
        end
        Result.subtitle = "Possible Acute Blood Loss Anemia"
        AlertMatched = true

    elseif anemiaAlertPresent and anyAlertCodePresent then
        -- Autoresolve Possible Anemia
        for _, code in ipairs(accountAlertCodes) do
            local desc = alertCodeDictionary[code]
            local codeLink = GetCodeLinks { code=code, text="Autoresolved Specified Code - " + desc }
            if codeLink ~= nil then
                table.insert(DocumentationIncludesLinks, codeLink)
                break
            end
        end
        AutoResolved = true
        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true

    elseif not acuteBloodLossAnemiaCodePresent and (lowHemoglobinDvAbsCount >= 3 or lowHematocritDvCount >= 3) and anyAnemiaTreatment then
        -- Possible Anemia (#6)
        lowHemoglobinOrHematocritTrigger = true
        Result.subtitle = "Possible Anemia Dx"
        AlertMatched = true

    else
        -- No alert / autoresolve action to be taken
        AlertMatched = false
    end
end



--------------------------------------------------------------------------------
--- Additional Link Creation
--------------------------------------------------------------------------------
if AlertMatched then
    -- Abstractions
    AddEvidenceCode("T45.1X5A", "Adverse Effect of Antineoplastic and Immunosuppressive Drug", 1)
    GetFirstCodePrefixLink{ target = ClinicalEvidenceLinks, prefix="F10.1", text="Alcohol Abuse", seq=2 }
    GetFirstCodePrefixLink { target = ClinicalEvidenceLinks, prefix="F10.2", text="Alcohol Dependence", seq=3 }
    AddEvidenceCode("K70.31", "Alcoholic Liver Cirrhosis", 4)
    AddEvidenceCode("T45.7X1A", "Anticoagulant-Induced Bleeding", 5)
    AddEvidenceCode("Z51.11", "Chemotherapy", 6)
    AddEvidenceCode("3E04305", "Chemotherapy Administration", 7)

    GetCodeLinks { target = ClinicalEvidenceLinks, text = "Chronic Kidney Disease", seq = 8, codes = {
        "N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.9"
    }}
    AddEvidenceCode("K27.4", "Chronic Peptic Ulcer with Hemorrhage", 9)
    AddEvidenceAbs("CURRENT_CHEMOTHERAPY", "Current Chemotherapy", 10)
    AddEvidenceAbs("DYSPNEA_ON_EXERTION", "Dyspnea on Exertion", 11)
    AddEvidenceCode("N18.6", "End-Stage Renal Disease", 12)
    AddEvidenceCode("R53.83", "Fatigue", 13)
    GetFirstCodePrefixLink { prefix="C82.", target=ClinicalEvidenceLinks, text="Follicular Lymphoma", seq=14 }

    GetCodeLinks { target = ClinicalEvidenceLinks, text = "Heart Failure", seq = 15, codes = {
        "I50.20", "I50.22", "I50.23", "I50.30", "I50.32", "I50.33", "I50.40", "I5.42", "I50.43", "I50.810", "I50.812", "I50.813", "I50.84", "I50.89", "I50.9"
    }}
    AddEvidenceCode("D58.0", "Hereditary Spherocytosis", 16)
    AddEvidenceCode("B20", "HIV", 17)
    GetFirstCodePrefixLink { prefix="C81.", target=ClinicalEvidenceLinks, text="Hodgkin Lymphoma", seq=18 }
    AddEvidenceCode("E61.1", "Iron Deficiency", 19)
    GetFirstCodePrefixLink { prefix="C95.", target=ClinicalEvidenceLinks, text="Leukemia of Unspecified Cell Type", seq=20 }
    GetFirstCodePrefixLink { prefix="C91.", target=ClinicalEvidenceLinks, text="Lymphoid Leukemia", seq=21 }
    AddEvidenceCode("K22.6", "Mallory-Weiss Tear", 22)
    GetCodeLinks { target = ClinicalEvidenceLinks, text = "Malnutrition", seq = 23, codes = {
        "E40", "E41", "E42", "E43", "E44.0", "E44.1", "E45"
    }}
    GetFirstCodePrefixLink { prefix="C84.", target=ClinicalEvidenceLinks, text="Mature T/NK-Cell Lymphoma", seq=24 }
    GetFirstCodePrefixLink { prefix="C90.", target=ClinicalEvidenceLinks, text="Multiple Myeloma", seq=25 }
    GetFirstCodePrefixLink { prefix="C93.", target=ClinicalEvidenceLinks, text="Monocytic Leukemia", seq=26 }
    AddEvidenceCode("D46.9", "Myelodysplastic Syndrome", 27)
    GetFirstCodePrefixLink { prefix="C92.", target=ClinicalEvidenceLinks, text="Myeloid Leukemia", seq=28 }
    GetFirstCodePrefixLink { prefix="C83.", target=ClinicalEvidenceLinks, text="Non-Follicular Lymphoma", seq=29 }
    GetFirstCodePrefixLink { prefix="C94.", target=ClinicalEvidenceLinks, text="Other Leukemias", seq=30 }
    GetFirstCodePrefixLink { prefix="C86.", target=ClinicalEvidenceLinks, text="Other Types of T/NK-Cell Lymphoma", seq=31 }
    AddEvidenceCode("R23.1", "Pale", 32)
    AddEvidenceCode("K27.9", "Peptic Ulcer", 33)
    AddEvidenceCode("F19.10", "Psychoactive Substance Abuse", 34)
    AddEvidenceCode("Z51.0", "Radiation Therapy", 35)
    GetFirstCodePrefixLink { prefix="M05.", target=ClinicalEvidenceLinks, text="Rheumatoid Arthritis", seq=36 }
    GetFirstCodePrefixLink { prefix="D86.", target=ClinicalEvidenceLinks, text="Sarcoidosis", seq=37 }
    AddEvidenceAbs("SHORTNESS_OF_BREATH", "Shortness of Breath", 38)
    GetFirstCodePrefixLink { prefix="D57.", target=ClinicalEvidenceLinks, text="Sickle Cell Disorder", seq=39 }
    AddEvidenceCode("R16.1", "Splenomegaly", 40)
    GetFirstCodePrefixLink { prefix="M32.", target=ClinicalEvidenceLinks, text="Systemic Lupus Erythematosus (SLE)", seq=41 }
    GetFirstCodePrefixLink { prefix="C85.", target=ClinicalEvidenceLinks, text="Unspecified Non-Hodgkin Lymphoma", seq=42 }
    AddEvidenceAbs("WEAKNESS", "Weakness", 43)

    -- Labs
    AddLabsDv("Immature Reticulocyte Fraction", "Immature Reticulocyte Fraction", 3, function(dv)
        return CheckDvResultNumber(dv, function(v) return v < 3 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)
    AddLabsAbs("LOW_IMMATURE_RETICULOCYTE_FRACTION", "Immature Reticulocyte Fraction", 4)
    AddLabsDv("Occult Blood Gastric", "Occult Blood", 5, function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 0 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)
    AddLabsDv("Reticulocyte Count", "Reticulocyte Count", 6, function(dv)
        return CheckDvResultNumber(dv, function(v) return v < 0.5 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)
    AddLabsAbs("LOW_RETICULOCYTE_COUNT", "Reticulocyte Count", 7)
    AddLabsAbs("LOW_SERUM_FERRITIN", "Serum Ferritin", 8)
    AddLabsAbs("LOW_SERUM_FOLATE", "Serum Folate", 9)
    AddLabsAbs("LOW_SERUM_IRON", "Serum Iron", 10)
    AddLabsAbs("LOW_TOTAL_IRON_BINDING_CAPACITY", "Total Iron Binding Capacity", 11)
    AddLabsAbs("LOW_TRANSFERRIN", "Transferrin", 12)
    AddLabsAbs("LOW_VITAMIN_B12", "Vitamin B12 Deficiency", 13)

    -- Labs Subheading Categories
    GetDiscreteValueLinks { target=mchLinks, text="MCH", discreteValueName="MCH (pg)", maxPerValue=3, predicate=function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 0 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end }
    GetDiscreteValueLinks { target=mchcLinks, text="MCHC", discreteValueName="MCHC (g/dL)", maxPerValue=3, predicate=function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 0 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end }
    GetDiscreteValueLinks { target=mcvLinks, text="MCV", discreteValueName="MCV (fL)", maxPerValue=3, predicate=function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 0 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end }
    GetDiscreteValueLinks { target=plateletsLinks, text="Platelet Count", discreteValueName="Platelets (10x3/uL)", maxPerValue=3, predicate=function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 0 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end }
    GetDiscreteValueLinks { target=rbcLinks, text="RBC", discreteValueName="RBC (10x6/uL)", maxPerValue=3, predicate=function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 0 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end }
    GetDiscreteValueLinks { target=rdwLinks, text="RDW", discreteValueName="RDW (%)", maxPerValue=3, predicate=function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 0 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end }
    GetDiscreteValueLinks { target=ferritinLinks, text="Ferritin", discreteValueName="Ferritin Lvl (ng/mL)", maxPerValue=3, predicate=function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 0 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end }
    GetDiscreteValueLinks { target=folateLinks, text="Folate", discreteValueName="Folate Lvl (ng/mL)", maxPerValue=3, predicate=function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 0 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end }
    GetDiscreteValueLinks { target=ironLinks, text="Iron", discreteValueName="Iron Lvl (mcg/dL)", maxPerValue=3, predicate=function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 0 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end }
    GetDiscreteValueLinks { target=ironBindingCapLinks, text="Total Iron Binding Capacity", discreteValueName="TIBC (mcg/dL)", maxPerValue=3, predicate=function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 0 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end }
    GetDiscreteValueLinks { target=transferrinLinks, text="Transferrin", discreteValueName="Transferrin (mg/dL)", maxPerValue=3, predicate=function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 0 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end }
    GetDiscreteValueLinks { target=vitaminB12Links, text="Vitamin B12", discreteValueName="Vitamin B12 Lvl (pg/mL)", maxPerValue=3, predicate=function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 0 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end }
    GetDiscreteValueLinks { target=wbcLinks, text="WBC", discreteValueName="WBC (10x3/uL)", maxPerValue=3, predicate=function(dv)
        return CheckDvResultNumber(dv, function(v) return v > 0 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end }

    -- Hemoglobin/Hematocrit Links
    if lowHemoglobinOrHematocritTrigger then
        for _, pair in ipairs(lowHemoglobinPairs) do
            local hemoglobinLink = GetLinkForDiscreteValue(pair.hemoglobin, "Hemoglobin (g/dL)", 0, true)
            local hematocritLink = GetLinkForDiscreteValue(pair.hematocrit, "Hematocrit (%)", 0, true)
            table.insert(hemoglobinLinks, hemoglobinLink)
            table.insert(hematocritLinks, hematocritLink)
        end
        hemoglobinHeader.links = hemoglobinLinks
        hematocritHeader.links = hematocritLinks

        if #hemoglobinLinks > 0 then
            table.insert(DocumentationIncludesLinks, hemoglobinLabsHeader)
        end
        if #hematocritLinks > 0 then
            table.insert(DocumentationIncludesLinks, hematocritLabsHeader)
        end
    else
        for _, pair in ipairs(lowHemoglobinPairs) do
            local hemoglobinLink = GetLinkForDiscreteValue(pair.hemoglobin, "Hemoglobin (g/dL)", 0, true)
            local hematocritLink = GetLinkForDiscreteValue(pair.hematocrit, "Hematocrit (%)", 0, true)
            table.insert(hemoglobinLabsLinks, hemoglobinLink)
            table.insert(hematocritLabsLinks, hematocritLink)
        end
    end

    if Account.patient.gender == "F" then
        GetAbstractionLinks {
            target = hematocritLabsLinks,
            code = "LOW_HEMATOCRIT",
            text = "Hematocrit Female",
            seq = 1
        }
        if lowHemoglobinAbs ~= nil then
            table.insert(hemoglobinLabsLinks, lowHemoglobinAbs)
        end
    elseif Account.patient.gender == "M" then
        GetAbstractionLinks {
            target = hematocritLabsLinks,
            code = "LOW_HEMATOCRIT",
            text = "Hematocrit Male",
            seq = 1
        }
        if lowHemoglobinAbs ~= nil then
            table.insert(hemoglobinLabsLinks, lowHemoglobinAbs)
        end
    end

    hemoglobinLabsHeader.links = hemoglobinLabsLinks
    hematocritLabsHeader.links = hematocritLabsLinks

    -- Meds
    if not anemiaTreatmentTrigger then
        if anemiaMedsAbs ~= nil then
            table.insert(TreatmentLinks, anemiaMedsAbs)
        end
        if anemiaMeds ~= nil then
            table.insert(TreatmentLinks, anemiaMeds)
        end
        if fluidBolusMeds ~= nil then
            table.insert(TreatmentLinks, fluidBolusMeds)
        end
        if hematopoeticMed ~= nil then
            table.insert(TreatmentLinks, hematopoeticMed)
        end
        if hemtopoeticAbs ~= nil then
            table.insert(TreatmentLinks, hemtopoeticAbs)
        end
        if isotonicIVSolMed ~= nil then
            table.insert(TreatmentLinks, isotonicIVSolMed)
        end
        if a30233N1Code ~= nil then
            table.insert(TreatmentLinks, a30233N1Code)
        end
        if sodiumChlorideMed ~= nil then
            table.insert(TreatmentLinks, sodiumChlorideMed)
        end
    else
        if anemiaMedsAbs ~= nil then
            table.insert(DocumentationIncludesLinks, anemiaMedsAbs)
        end
        if anemiaMeds ~= nil then
            table.insert(DocumentationIncludesLinks, anemiaMeds)
        end
        if fluidBolusMeds ~= nil then
            table.insert(DocumentationIncludesLinks, fluidBolusMeds)
        end
        if hematopoeticMed ~= nil then
            table.insert(DocumentationIncludesLinks, hematopoeticMed)
        end
        if hemtopoeticAbs ~= nil then
            table.insert(DocumentationIncludesLinks, hemtopoeticAbs)
        end
        if isotonicIVSolMed ~= nil then
            table.insert(DocumentationIncludesLinks, isotonicIVSolMed)
        end
        if a30233N1Code ~= nil then
            table.insert(DocumentationIncludesLinks, a30233N1Code)
        end
        if sodiumChlorideMed ~= nil then
            table.insert(DocumentationIncludesLinks, sodiumChlorideMed)
        end
    end
    -- Signs of Bleeding
    if signsOfBleedingTrigger then
        if i975Codes ~= nil then
            for _, code in ipairs(i975Codes) do
                table.insert(soBleedingLinks, code)
            end
        end
        if k917Codes ~= nil then
            for _, code in ipairs(k917Codes) do
                table.insert(soBleedingLinks, code)
            end
        end
        if j957Codes ~= nil then
            for _, code in ipairs(j957Codes) do
                table.insert(soBleedingLinks, code)
            end
        end
        if k260Code ~= nil then
            table.insert(soBleedingLinks, k260Code)
        end
        if k262Code ~= nil then
            table.insert(soBleedingLinks, k262Code)
        end
        if k250Code ~= nil then
            table.insert(soBleedingLinks, k250Code)
        end
        if k252Code ~= nil then
            table.insert(soBleedingLinks, k252Code)
        end
        if k270Code ~= nil then
            table.insert(soBleedingLinks, k270Code)
        end
        if k272Code ~= nil then
            table.insert(soBleedingLinks, k272Code)
        end
        if r319Code ~= nil then
            table.insert(soBleedingLinks, r319Code)
        end
        if k264Code ~= nil then
            table.insert(soBleedingLinks, k264Code)
        end
        if k266Code ~= nil then
            table.insert(soBleedingLinks, k266Code)
        end
        if k254Code ~= nil then
            table.insert(soBleedingLinks, k254Code)
        end
        if k256Code ~= nil then
            table.insert(soBleedingLinks, k256Code)
        end
        if k276Code ~= nil then
            table.insert(soBleedingLinks, k276Code)
        end
        if n99510Code ~= nil then
            table.insert(soBleedingLinks, n99510Code)
        end
        if r040Code ~= nil then
            table.insert(soBleedingLinks, r040Code)
        end
        if i8501Code ~= nil then
            table.insert(soBleedingLinks, i8501Code)
        end
        if giBleedCodes ~= nil then
            for _, code in ipairs(giBleedCodes) do
                table.insert(soBleedingLinks, code)
            end
        end
        if k922Code ~= nil then
            table.insert(soBleedingLinks, k922Code)
        end
        if hematomaAbs ~= nil then
            table.insert(soBleedingLinks, hematomaAbs)
        end
        if k920Code ~= nil then
            table.insert(soBleedingLinks, k920Code)
        end
        if r310Code ~= nil then
            table.insert(soBleedingLinks, r310Code)
        end
        if r195Code ~= nil then
            table.insert(soBleedingLinks, r195Code)
        end
        if k661Code ~= nil then
            table.insert(soBleedingLinks, k661Code)
        end
        if n3091Code ~= nil then
            table.insert(soBleedingLinks, n3091Code)
        end
        if j9501Code ~= nil then
            table.insert(soBleedingLinks, j9501Code)
        end
        if r042Code ~= nil then
            table.insert(soBleedingLinks, r042Code)
        end
        if i974Codes ~= nil then
            for _, code in ipairs(i974Codes) do
                table.insert(soBleedingLinks, code)
            end
        end
        if k916Codes ~= nil then
            for _, code in ipairs(k916Codes) do
                table.insert(soBleedingLinks, code)
            end
        end
        if n99Codes ~= nil then
            for _, code in ipairs(n99Codes) do
                table.insert(soBleedingLinks, code)
            end
        end
        if g9732Code ~= nil then
            table.insert(soBleedingLinks, g9732Code)
        end
        if g9731Code ~= nil then
            table.insert(soBleedingLinks, g9731Code)
        end
        if j956Codes ~= nil then
            for _, code in ipairs(j956Codes) do
                table.insert(soBleedingLinks, code)
            end
        end
        if k921Code ~= nil then
            table.insert(soBleedingLinks, k921Code)
        end
        if n920Code ~= nil then
            table.insert(soBleedingLinks, n920Code)
        end
        if i61Codes ~= nil then
            for _, code in ipairs(i61Codes) do
                table.insert(soBleedingLinks, code)
            end
        end
        if i62Codes ~= nil then
            for _, code in ipairs(i62Codes) do
                table.insert(soBleedingLinks, code)
            end
        end
        if i60Codes ~= nil then
            for _, code in ipairs(i60Codes) do
                table.insert(soBleedingLinks, code)
            end
        end
        if l7632Code ~= nil then
            table.insert(soBleedingLinks, l7632Code)
        end
        if k918Codes ~= nil then
            for _, code in ipairs(k918Codes) do
                table.insert(soBleedingLinks, code)
            end
        end
        if i976Codes ~= nil then
            for _, code in ipairs(i976Codes) do
                table.insert(soBleedingLinks, code)
            end
        end
        if n991Codes ~= nil then
            for _, code in ipairs(n991Codes) do
                table.insert(soBleedingLinks, code)
            end
        end
        if g9752Code ~= nil then
            table.insert(soBleedingLinks, g9752Code)
        end
        if g9751Code ~= nil then
            table.insert(soBleedingLinks, g9751Code)
        end
        if j958Codes ~= nil then
            for _, code in ipairs(j958Codes) do
                table.insert(soBleedingLinks, code)
            end
        end
        if k625Code ~= nil then
            table.insert(soBleedingLinks, k625Code)
        end
        if eblAbs ~= nil then
            table.insert(soBleedingLinks, eblAbs)
        end
    end
    soBleedingHeader.links = soBleedingLinks
    if #soBleedingLinks > 0 then
        table.insert(DocumentationIncludesLinks, soBleedingHeader)
    end

    -- Vitals
    AddVitalsAbs("LOW_BLOOD_PRESSURE", "Blood Pressure", 1)
    AddVitalsDv("Mean Arterial Pressure", "Mean Arterial Pressure", 2, function(dv)
        return CheckDvResultNumber(dv, function(v) return v < 60 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
    end)
    AddVitalsAbs("LOW_MEAN_ARTERIAL_BLOOD_PRESSURE", "Mean Arterial Pressure", 3)
    if not GetDiscreteValueLinks {
        target = VitalsLinks,
        discreteValueName = "Systolic Blood Pressure",
        text = "Systolic Blood Pressure",
        predicate = function(dv)
            return CheckDvResultNumber(dv, function(v) return v < 90 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
        end
    } then
        GetDiscreteValueLinks {
            target = VitalsLinks,
            discreteValueName = "Systolic Blood Pressure (mmHg)",
            text = "Systolic Blood Pressure",
            predicate = function(dv)
                return CheckDvResultNumber(dv, function(v) return v < 90 end) and DateIsLessThanXDaysAgo(dv.result_date, 365)
            end
        }
    end
    AddVitalsAbs("LOW_SYSTOLIC_BLOOD_PRESSURE", "Systolic Pressure", 4)
end



--------------------------------------------------------------------------------
--- Result Finalization 
--------------------------------------------------------------------------------
if AlertMatched or AlertAutoResolved then
    if hemoglobinLabsLinks and #hemoglobinLabsLinks > 0 then
        hemoglobinLabsHeader.links = hemoglobinLabsLinks
        table.insert(LabsLinks, hemoglobinLabsHeader)
    end
    if hematocritLabsLinks and #hematocritLabsLinks > 0 then
        hematocritLabsHeader.links = hematocritLabsLinks
        table.insert(LabsLinks, hematocritLabsHeader)
    end
    if mchLinks and #mchLinks > 0 then
        mchHeader.links = mchLinks
        table.insert(LabsLinks, mchHeader)
    end
    if mchcLinks and #mchcLinks > 0 then
        mchcHeader.links = mchcLinks
        table.insert(LabsLinks, mchcHeader)
    end
    if mcvLinks and #mcvLinks > 0 then
        mcvHeader.links = mcvLinks
        table.insert(LabsLinks, mcvHeader)
    end
    if plateletsLinks and #plateletsLinks > 0 then
        plateletsHeader.links = plateletsLinks
        table.insert(LabsLinks, plateletsHeader)
    end
    if rbcLinks and #rbcLinks > 0 then
        rbcHeader.links = rbcLinks
        table.insert(LabsLinks, rbcHeader)
    end
    if rdwLinks and #rdwLinks > 0 then
        rdwHeader.links = rdwLinks
        table.insert(LabsLinks, rdwHeader)
    end
    if ferritinLinks and #ferritinLinks > 0 then
        ferritinHeader.links = ferritinLinks
        table.insert(LabsLinks, ferritinHeader)
    end
    if folateLinks and #folateLinks > 0 then
        folateHeader.links = folateLinks
        table.insert(LabsLinks, folateHeader)
    end
    if ironLinks and #ironLinks > 0 then
        ironHeader.links = ironLinks
        table.insert(LabsLinks, ironHeader)
    end
    if ironBindingCapLinks and #ironBindingCapLinks > 0 then
        ironBindingCapHeader.links = ironBindingCapLinks
        table.insert(LabsLinks, ironBindingCapHeader)
    end
    if transferrinLinks and #transferrinLinks > 0 then
        transferrinHeader.links = transferrinLinks
        table.insert(LabsLinks, transferrinHeader)
    end
    if vitaminB12Links and #vitaminB12Links > 0 then
        vitaminB12Header.links = vitaminB12Links
        table.insert(LabsLinks, vitaminB12Header)
    end
    if wbcLinks and #wbcLinks > 0 then
        LabsLinks= wbcLinks
        table.insert(Result.links, wbcHeader)
    end

    local resultLinks = GetFinalTopLinks({
        hemoglobinLabsHeader,
        hematocritLabsHeader,
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

