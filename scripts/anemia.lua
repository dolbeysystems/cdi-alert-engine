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
    local lowHematocritValue = 34

    if Account.patient.gender == "M" then
        lowHematocritValue = 40
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
--- Get Hemoglobin and Hematocrit Links
---
--- @param pairs HemoglobinHematocritDiscreteValuePair[] Pair of Hemoglobin and Hematocrit Discrete Values to get links for
--- @param hemoglobinLinkTemplate string Link template for Hemoglobin values
--- @param hematocritLinkTemplate string Link template for Hematocrit values 
---
--- @return CdiAlertLink[] - Links for the Hemoglobin and Hematocrit values in order
--------------------------------------------------------------------------------
local function GetLinksForHemoHemaPairs(pairs, hemoglobinLinkTemplate, hematocritLinkTemplate)
    local links = MakeLinkArray()
    for i = 1, #pairs do
        local pair = pairs[i]
        local hemoglobinLink = GetLinkForDiscreteValue(pair.hemoglobin, hemoglobinLinkTemplate, i, true)
        local hematocritLink = GetLinkForDiscreteValue(pair.hematocrit, hematocritLinkTemplate, i, true)
        table.insert(links, hemoglobinLink)
        table.insert(links, hematocritLink)
    end
    return links
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
    local r310Codes = GetCodeLinks { codes={"R31", "R31.0", "R31.1", "R31.2", "R31.21", "R31.29", "R31.9" }, text="Hematuria", seq=23 }
    if #r310Codes > 0 and r310Codes ~= nil then
        r310Code = r310Codes[1]
    end
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
    i61Codes = GetCodeLinks { codes={"I61.0", "I61.1", "I61.2", "I61.3", "I61.4", "I61.5", "I61.6", "I61.8", "I61.9"}, text="Nontraumatic Intracerebral Hemorrhage", seq=37 }
    i62Codes = GetCodeLinks { codes={"I62.0", "I62.00", "I62.01", "I62.02", "I62.03", "I62.1", "I62.9"}, text="Nontraumatic Intracerebral Hemorrhage", seq=38 }
    i60Codes = GetCodeLinks {
        codes={
            "I60.0", "I60.00", "I60.01", "I60.02", "I60.03", "I60.1", "I60.10", "I60.11", "I60.12",
            "I60.2", "I60.3", "I60.30", "I60.31", "I60.32", "I60.4", "I60.5", "I60.50", "I60.51", "I60.52",
            "I60.6", "I60.7", "I60.8", "I60.9"
        },
        text="Nontraumatic Subarachnoid Hemorrhage", seq=39
    }
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
    local hemoglobinDropPresent = (#hemoglobinDropLinks > 0)
    local hematocritDropPresent = (#hematocritDropLinks > 0)

    local acuteBloodLossAlertPresent = (ExistingAlert ~= nil and ExistingAlert.subtitle == "Possible Acute Blood Loss Anemia")
    local anemiaAlertPresent = (ExistingAlert ~= nil and ExistingAlert.subtitle == "Possible Anemia")

    local anemiaTreatmentTrigger = false
    local signsOfBleedingTrigger = false
    local lowHemoglobinOrHematocritTrigger = false

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

        -- Abstractions
        AddEvidenceCode("T45.1X5A", "Adverse Effect of Antineoplastic and Immunosuppressive Drug", 1)
        GetCodeLinks { target = ClinicalEvidenceLinks, text="Alcohol Abuse", seq=2, codes = {
            "F10.1",
            "F10.10",
            "F10.11",
            "F10.12", "F10.120", "F10.121", "F10.129",
            "F10.13", "F10.130", "F10.131", "F10.132", "F10.139",
            "F10.14",
            "F10.15", "F10.150", "F10.151", "F10.159",
            "F10.18", "F10.180", "F10.181", "F10.182", "F10.188",
            "F10.19",
        }}
        GetCodeLinks { target = ClinicalEvidenceLinks, text="Alcohol Dependence", seq=3, codes = {
            "F10.2",
            "F10.20",
            "F10.21",
            "F10.22","F10.220", "F10.221", "F10.229",
            "F10.23", "F10.230", "F10.231", "F10.232", "F10.239",
            "F10.24",
            "F10.25", "F10.250", "F10.251", "F10.259",
            "F10.26",
            "F10.27",
            "F10.28", "F10.280", "F10.281", "F10.282", "F10.288",
            "F10.29"
        }}
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
        GetCodeLinks { target = ClinicalEvidenceLinks, text = "Follicular Lymphoma", seq = 14, codes = {
            "C82.0", "C82.00", "C82.01", "C82.02", "C82.03", "C82.04", "C82.05", "C82.06", "C82.07", "C82.08", "C82.09",
            "C82.1", "C82.10", "C82.11", "C82.12", "C82.13", "C82.14", "C82.15", "C82.16", "C82.17", "C82.18", "C82.19",
            "C82.2", "C82.20", "C82.21", "C82.22", "C82.23", "C82.24", "C82.25", "C82.26", "C82.27", "C82.28", "C82.29",
            "C82.3", "C82.30", "C82.31", "C82.32", "C82.33", "C82.34", "C82.35", "C82.36", "C82.37", "C82.38", "C82.39",
            "C82.4", "C82.40", "C82.41", "C82.42", "C82.43", "C82.44", "C82.45", "C82.46", "C82.47", "C82.48", "C82.49",
            "C82.5", "C82.50", "C82.51", "C82.52", "C82.53", "C82.54", "C82.55", "C82.56", "C82.57", "C82.58", "C82.59",
            "C82.6", "C82.60", "C82.61", "C82.62", "C82.63", "C82.64", "C82.65", "C82.66", "C82.67", "C82.68", "C82.69",
            "C82.8", "C82.80", "C82.81", "C82.82", "C82.83", "C82.84", "C82.85", "C82.86", "C82.87", "C82.88", "C82.89",
            "C82.9", "C82.90", "C82.91", "C82.92", "C82.93", "C82.94", "C82.95", "C82.96", "C82.97", "C82.98", "C82.99"
        }}

        GetCodeLinks { target = ClinicalEvidenceLinks, text = "Heart Failure", seq = 15, codes = {
            "I50.20", "I50.22", "I50.23", "I50.30", "I50.32", "I50.33", "I50.40", "I5.42", "I50.43", "I50.810", "I50.812", "I50.813", "I50.84", "I50.89", "I50.9"
        }}
        AddEvidenceCode("D58.0", "Hereditary Spherocytosis", 16)
        AddEvidenceCode("B20", "HIV", 17)
        GetCodeLinks { target = ClinicalEvidenceLinks, text = "Hodgkin Lymphoma", seq = 18, codes = {
            "C81.0", "C81.00", "C81.01", "C81.02", "C81.03", "C81.04", "C81.05", "C81.06", "C81.07", "C81.08", "C81.09",
            "C81.1", "C81.10", "C81.11", "C81.12", "C81.13", "C81.14", "C81.15", "C81.16", "C81.17", "C81.18", "C81.19",
            "C81.2", "C81.20", "C81.21", "C81.22", "C81.23", "C81.24", "C81.25", "C81.26", "C81.27", "C81.28", "C81.29",
            "C81.3", "C81.30", "C81.31", "C81.32", "C81.33", "C81.34", "C81.35", "C81.36", "C81.37", "C81.38", "C81.39",
            "C81.4", "C81.40", "C81.41", "C81.42", "C81.43", "C81.44", "C81.45", "C81.46", "C81.47", "C81.48", "C81.49",
            "C81.5", "C81.50", "C81.51", "C81.52", "C81.53", "C81.54", "C81.55", "C81.56", "C81.57", "C81.58", "C81.59",
            "C81.6", "C81.60", "C81.61", "C81.62", "C81.63", "C81.64", "C81.65", "C81.66", "C81.67", "C81.68", "C81.69",
            "C81.7", "C81.70", "C81.71", "C81.72", "C81.73", "C81.74", "C81.75", "C81.76", "C81.77", "C81.78", "C81.79",
            "C81.9", "C81.90", "C81.91", "C81.92", "C81.93", "C81.94", "C81.95", "C81.96", "C81.97", "C81.98", "C81.99",
        }}
        AddEvidenceCode("E61.1", "Iron Deficiency", 19)
        GetCodeLinks { target = ClinicalEvidenceLinks, text = "Leukemia of Unspecified Cell Type", seq = 20, codes = {
            "C95.0", "C95.00", "C95.01", "C95.02",
            "C95.1", "C95.10", "C95.11", "C95.12",
            "C95.9", "C95.90", "C95.91", "C95.92",
        }}
--[[
    prefixCodeValue("^C91\.", "Lymphoid Leukemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21, abs, True)
    codeValue("K22.6", "Mallory-Weiss Tear: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 22, abs, True)
    multiCodeValue(["E40", "E41", "E42", "E43", "E44.0", "E44.1", "E45"], "Malnutrition: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23, abs, True)
    prefixCodeValue("^C84\.", "Mature T/NK-Cell Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 24, abs, True)
    prefixCodeValue("^C90\.", "Multiple Myeloma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 25, abs, True)
    prefixCodeValue("^C93\.", "Monocytic Leukemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 26, abs, True)
--]]
--[[
    codeValue("D46.9", "Myelodysplastic Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 27, abs, True)
    prefixCodeValue("^C92\.", "Myeloid Leukemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 28, abs, True)
    prefixCodeValue("^C83\.", "Non-Follicular Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 29, abs, True)
    prefixCodeValue("^C94\.", "Other Leukemias: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 30, abs, True)
    prefixCodeValue("^C86\.", "Other Types of T/NK-Cell Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 31, abs, True)
--]]
--[[
    codeValue("R23.1", "Pale [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 32, abs, True)
    codeValue("K27.9", "Peptic Ulcer: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 33, abs, True)
    codeValue("F19.10", "Psychoactive Substance Abuse: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 34, abs, True)
    codeValue("Z51.0", "Radiation Therapy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 35, abs, True)
    prefixCodeValue("^M05\.", "Rheumatoid Arthritis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 36, abs, True)
--]]
--[[
    prefixCodeValue("^D86\.", "Sarcoidosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 37, abs, True)
    abstractValue("SHORTNESS_OF_BREATH", "Shortness of Breath: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 38, abs, True)
    prefixCodeValue("^D57\.", "Sickle Cell Disorder: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 39, abs, True)
    codeValue("R16.1", "Splenomegaly: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 40, abs, True)
    prefixCodeValue("^M32\.", "Systemic Lupus Erthematosus (SLE): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 41, abs, True)
    prefixCodeValue("^C85\.", "Unspecified Non-Hodgkin Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 42, abs, True)
    abstractValue("WEAKNESS", "Weakness: '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 43, abs, True)
--]]
--[[
    #Labs
    dvValue(dvImmatureReticulocyteFraction, "Immature Reticulocyte Fraction: [VALUE] (Result Date: [RESULTDATETIME])", calcImmatureReticulocyteFraction1, 3, labs, True)
    abstractValue("LOW_IMMATURE_RETICULOCYTE_FRACTION", "Immature Reticulocyte Fraction: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4, labs, True)
    dvValue(dvOccultBloodGastric, "Occult Blood: [VALUE] (Result Date: [RESULTDATETIME])", calcAny, 5, labs, True)
    dvValue(dvReticulocyteCount, "Reticulocyte Count: [VALUE] (Result Date: [RESULTDATETIME])", calcAny, 6, labs, True)
--]]
--[[
    abstractValue("LOW_RETICULOCYTE_COUNT", "Reticulocyte Count: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7, labs, True)
    abstractValue("LOW_SERUM_FERRITIN", "Serum Ferritin: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, labs, True)
    codeValue("LOW_SERUM_FOLATE", "Serum Folate '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, labs, True)
    abstractValue("LOW_SERUM_IRON", "Serum Iron: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10, labs, True)
    abstractValue("LOW_TOTAL_IRON_BINDING_CAPACITY", "Total Iron Binding Capacity: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11, labs, True)
    abstractValue("LOW_TRANSFERRIN", "Transferrin: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12, labs, True)
    abstractValue("LOW_VITAMIN_B12", "Vitamin B12 Deficiency '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13, labs, True)
--]]
--[[
    #Labs Subheading Categories
    dvValueMulti(dict(maindiscreteDic), dvMCH, "MCH: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, gt, 0, mch, True, 3)
    dvValueMulti(dict(maindiscreteDic), dvMCHC, "MCHC: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, gt, 0, mchc, True, 3)
    dvValueMulti(dict(maindiscreteDic), dvMCV, "MCV: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, gt, 0, mcv, True, 3)
    dvValueMulti(dict(maindiscreteDic), dvPlateletCount, "Platelet Count: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, gt, 0, platelets, True, 3)
    dvValueMulti(dict(maindiscreteDic), dvRBC, "RBC: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, gt, 0, rbc, True, 3)
    dvValueMulti(dict(maindiscreteDic), dvRDW, "RDW: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, gt, 0, rdw, True, 3)
--]]
--[[
    dvValueMulti(dict(maindiscreteDic), dvSerumFerritin, "Ferritin: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, gt, 0, ferritin, True, 3)
    dvValueMulti(dict(maindiscreteDic), dvFolate, "Folate: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, gt, 0, folate, True, 3)
    dvValueMulti(dict(maindiscreteDic), dvSerumIron, "Iron: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, gt, 0, iron, True, 3)
    dvValueMulti(dict(maindiscreteDic), dvTotalIronBindingCapacity, "Total Iron Binding Capacity: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, gt, 0, ironBindingCap, True, 3)
    dvValueMulti(dict(maindiscreteDic), dvTransferrin, "Transferrin: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, gt, 0, transferrin, True, 3)
    dvValueMulti(dict(maindiscreteDic), dvVitaminB12, "Vitamin B12: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, gt, 0, vitaminB12, True, 3)
    dvValueMulti(dict(maindiscreteDic), dvWBC, "WBC: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, gt, 0, wbc, True, 3)
        --]]
    end
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

