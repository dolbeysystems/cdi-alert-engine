##################################################################################################################
#Evaluation Script - Anemia
#
#This script checks an account to see if it matches criteria to be alerted for Anemia
#Date - 11/24/2024
#Version - V22
#Site - Sarasota County Health District
#
##################################################################################################################

#========================================
#  Imports
#========================================
import sys
import time
import datetime
import clr
import math
clr.AddReference("fusion-cac-script-engine")
import re
from fusion_cac_script_engine.Lib.Scripting import *
from fusion_cac_script_engine.Models import *
import System
import System.Collections.Generic
clr.AddReference('System.Core')
from System import *
from System.Data import *
from System.Configuration import *
from System.Collections.Generic import *
clr.ImportExtensions(System.Linq)
from operator import le, ge, gt, lt
from datetime import datetime

#========================================
#  Script Specific Constants
#========================================
codeDic = {
    "D50.8": "Other Iron Deficiency Anemias",
    "D50.9": "Iron Deficiency Anemia Unspecified",
    "D51.0": "Vitamin B12 Deficiency Anemia due to Intrinsic Factor Deficiency",
    "D51.1": "Vitamin B12 Deficiency Anemia due to Selective Vitamin B12 Malabsorption With Proteinuria",
    "D51.2": "Transcobalamin II Deficiency",
    "D51.3": "Other Dietary Vitamin B12 Deficiency Anemia",
    "D51.8": "Other Vitamin B12 Deficiency Anemias",
    "D51.9": "Vitamin B12 Deficiency Anemia, Unspecified",
    "D52.0": "Dietary Folate Deficiency Anemia",
    "D52.1": "Drug-Induced Folate Deficiency Anemia",
    "D52.8": "Other Folate Deficiency Anemias",
    "D52.9": "Folate Deficiency Anemia, Unspecified",
    "D53.0": "Protein Deficiency Anemia",
    "D53.1": "Other Megaloblastic Anemias, not Elsewhere Classified",
    "D53.2": "Scorbutic Anemia",
    "D53.8": "Other Specified Nutritional Anemias",
    "D53.9": "Nutritional Anemia, Unspecified",
    "D55.0": "Anemia Due to Glucose-6-Phosphate Dehydrogenase [G6pd] Deficiency",
    "D55.1": "Anemia Due to Other Disorders of Glutathione Metabolism",
    "D55.21": "Anemia Due to Pyruvate Kinase Deficiency",
    "D55.29": "Anemia Due to Other Disorders of Glycolytic Enzymes",
    "D55.3": "Anemia Due to Disorders of Nucleotide Metabolism",
    "D55.8": "Other Anemias Due to Enzyme Disorders",
    "D55.9": "Anemia Due to Enzyme Disorder, Unspecified",
    "D56.0": "Alpha Thalassemia",
    "D56.1": "Beta Thalassemia",
    "D56.2": "Delta-Beta Thalassemia",
    "D56.3": "Thalassemia Minor",
    "D56.4": "Hereditary Persistence of Fetal Hemoglobin [Hpfh]",
    "D56.5": "Hemoglobin E-Beta Thalassemia",
    "D56.8": "Other Thalassemias",
    "D56.9": "Thalassemia, Unspecified",
    "D58.0": "Hereditary Spherocytosis",
    "D58.1": "Hereditary Elliptocytosis",
    "D58.2": "Other Hemoglobinopathies",
    "D58.8": "Other Specified Hereditary Hemolytic Anemias",
    "D58.9": "Hereditary Hemolytic Anemia, Unspecified",
    "D59.0": "Drug-Induced Autoimmune Hemolytic Anemia",
    "D59.10": "Autoimmune Hemolytic Anemia, Unspecified",
    "D59.11": "Warm Autoimmune Hemolytic Anemia",
    "D59.12": "Cold Autoimmune Hemolytic Anemia",
    "D59.13": "Mixed Type Autoimmune Hemolytic Anemia",
    "D59.19": "Other Autoimmune Hemolytic Anemia",
    "D59.2": "Drug-Induced Nonautoimmune Hemolytic Anemia",
    "D59.30": "Hemolytic-Uremic Syndrome, Unspecified",
    "D59.31": "Infection-Associated Hemolytic-Uremic Syndrome",
    "D59.32": "Hereditary Hemolytic-Uremic Syndrome",
    "D59.39": "Other Hemolytic-Uremic Syndrome",
    "D59.4": "Other Nonautoimmune Hemolytic Anemias",
    "D59.5": "Paroxysmal Nocturnal Hemoglobinuria [Marchiafava-Micheli]",
    "D59.6": "Hemoglobinuria Due to Hemolysis From Other External Causes",
    "D59.8": "Other Acquired Hemolytic Anemias",
    "D59.9": "Acquired Hemolytic Anemia, Unspecified",
    "D60.0": "Chronic Acquired Pure Red Cell Aplasia",
    "D60.1": "Transient Acquired Pure Red Cell Aplasia",
    "D60.8": "Other Acquired Pure Red Cell Aplasias",
    "D60.9": "Acquired Pure Red Cell Aplasia, Unspecified",
    "D61.01": "Constitutional (Pure) Red Blood Cell Aplasia",
    "D61.09": "Other Constitutional Aplastic Anemia",
    "D61.1": "Drug-Induced Aplastic Anemia",
    "D61.2": "Aplastic Anemia Due to Other External Agents",
    "D61.3": "Idiopathic Aplastic Anemia",
    "D61.810": "Antineoplastic Chemotherapy Induced Pancytopenia",
    "D61.811": "Other Drug-Induced Pancytopenia",
    "D61.818": "Other Pancytopenia",
    "D61.82": "Myelophthisis",
    "D61.89": "Other Specified Aplastic Anemias and Other Bone Marrow Failure Syndromes",
    "D61.9": "Aplastic Anemia, Unspecified",
    "D62": "Acute Posthemorrhagic Anemia",
    "D63.0": "Anemia in Neoplastic Disease",
    "D63.1": "Anemia in Chronic Kidney Disease",
    "D63.8": "Anemia in Other Chronic Diseases Classified Elsewhere",
    "D64.0": "Hereditary Sideroblastic Anemia",
    "D64.1": "Secondary Sideroblastic Anemia due to Disease",
    "D64.2": "Secondary Sideroblastic Anemia due to Drugs And Toxins",
    "D64.3": "Other Sideroblastic Anemias",
    "D64.4": "Congenital Dyserythropoietic Anemia",
    "D64.81": "Anemia due to Antineoplastic Chemotherapy",
    "D64.89": "Other Specified Anemias"
}

autoEvidenceText = "Autoresolved Evidence - "

#========================================
#  Globals
#========================================
db = CACDataRepository()
admitDate = account.AdmitDateTime.Date
birthDate = account.Patient.BirthDate.Date
gender = account.Patient.Gender
#Update true = External DV collection False = On Acct Record
accountContainer = AccountWorkflowContainer(account, True, "Category", 7)
useSeperateDiscreteCollection = True
if useSeperateDiscreteCollection == True:
    discreteValues = db.GetDiscreteValues(account._id)
else:
    discreteValues = db.GetAccountField(account._id, "DiscreteValues")

#========================================
#  Discrete Value Fields and Calculations
#========================================
dvBloodLoss = [""]
calcBloodLoss1 = 300
dvFolate = [""]
calcFolate1 = lambda x: x < 7.0
dvHematocrit = ["HEMATOCRIT (%)", "HEMATOCRIT"]
calcHematocrit1 = lambda x: x < 34
calcHematocrit2 = lambda x: x < 40
calcHematocrit3 = lambda x: x < 30
dvHemoglobin = ["HEMOGLOBIN", "HEMOGLOBIN (g/dL)"]
calcHemoglobin1 = lambda x: x < 13.5
calcHemoglobin2 = lambda x: x < 12.5
calcHemoglobin3 = lambda x: x < 10.0
dvMAP = ["Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)"]
calcMAP1 = lambda x: x < 70
dvMCH = ["MCH (pg)"]
calcMCH1 = lambda x: x < 25
dvMCHC = ["MCHC (g/dL)"]
calcMCHC1 = lambda x: x < 32
dvMCV = ["MCV (fL)"]
calcMCV1 = lambda x: x < 80
dvPlateletCount = ["PLATELET COUNT (10x3/uL)"]
dvRBC = ["RBC  (10X6/uL)"]
calcRBC1 = lambda x: x < 3.9
dvRDW = ["RDW CV (%)"]
calcRDW1 = lambda x: x < 11
dvRedBloodCellTransfusion = [""]
dvReticulocyteCount = [""]
calcReticulocyteCount1 = lambda x: x < 0.5
dvSBP = ["SBP 3.5 (No Calculation) (mm Hg)"]
calcSBP1 = lambda x: x < 90
dvSerumFerritin = ["FERRITIN (ng/mL)"]
calcSerumFerritin1 = lambda x: x < 22
dvSerumIron = ["IRON TOTAL (ug/dL)"]
calcSerumIron1 = lambda x: x < 65
dvTotalIronBindingCapacity = ["IRON BINDING"]
calcTotalIronBindingCapacity1 = lambda x: x < 246
dvTransferrin = ["TRANSFERRIN"]
calcTransferrin1 = lambda x: x < 200
dvVitaminB12 = ["VITAMIN B12 (pg/mL)"]
calcVitB121 = lambda x: x < 180
dvWBC = ["WBC (10x3/ul)"]
calcWBC1 = lambda x: x < 4.5

calcAny1 = lambda x: x > 0

#========================================
#  Functions
#========================================
def datetimeFromUtcToLocal(utc_datetime):
    if utc_datetime:
        convertedDate = DateTime.SpecifyKind(utc_datetime, DateTimeKind.Utc)
        return  convertedDate.ToLocalTime()
    else:
        return None

def cleanNumbers(result):
    result1 = re.sub("[\\<\\>]", "", str(result))
    if result1.count('.') <= 1 and result1.replace(".", "").isnumeric():
        return result1
    else:
        return None

def dataConversion(datetime, linkText, Result, id, category, sequence, abstract=True, gender=None):
    if datetime is not None:
        date_time = datetimeFromUtcToLocal(datetime)
        date_time = date_time.ToString("MM/dd/yyyy, HH:mm")
        linkText = linkText.replace("[RESULTDATETIME]", date_time)
    else: 
        linkText = linkText.replace("(Result Date: [RESULTDATETIME])", "")
    if Result is not None:
        linkText = linkText.replace("[VALUE]", Result)
    else: linkText = linkText.replace("[VALUE]", "")
    if gender: linkText = linkText.replace("[GENDER]", gender)
    else: linkText = linkText.replace("[GENDER]", "")
    if abstract == True:
        category.Links.Add(MatchedCriteriaLink(linkText, None, None, id, True, None, None, sequence))
    elif abstract == False:
        abstraction = MatchedCriteriaLink(linkText, None, None, id, True, None, None, sequence)
        return abstraction
    return

def CodeCount(codes):
    # Get list of codes on the acct based on CodeDic
    result = set()
    for document in account.Documents or []:
        for codeReference in document.CodeReferences or []:
            if codeReference.Code in codes:
                matching_code = codeReference.Code
                result.add(matching_code)
    return list(result)

def abstractValue(abstraction_name, link_text, calculation, sequence=0, category=None, abstract=False):
    # Find abstraction and if abstract is true abstract it to the provided category
    abstraction = accountContainer.GetFirstLinkMatchingAbstractionValue(abstraction_name, link_text, lambda x: calculation)
    if abstraction is not None:
        abstraction.Sequence = sequence
        if abstract:
            category.Links.Add(abstraction)
            return True
        else:
            return abstraction
    if abstract:
        return False
    return abstraction

def dvValue(dv_name, link_text, calculation, sequence=0, category=None, abstract=False):
    # Find Discrete Value and if abstract is true abstract it to the provided category
    for dv in dv_name:
        abstraction = accountContainer.GetFirstLinkMatchingDiscreteValue(dv, link_text, calculation)
        if abstraction is not None:
            break
    if abstraction is not None:
        abstraction.Sequence = sequence
        if abstract:
            category.Links.Add(abstraction)
            return True
        else:
            return abstraction
    if abstract:
        return False
    return abstraction

def dvValueMulti(dvDic, DV1, linkText, value, sign, sequence=0, category=None, abstract=False, needed=2):
    # Find Discrete Value and if abstract is true abstract it to the provided category
    matchedList = []
    x = 0
    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in DV1 and dvr is not None and sign(float(dvr), float(value)):
            matchedList.append(dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract))
            x += 1
            if needed <= x:
                break
    if abstract and x > 0:
        return True
    elif abstract is False and len(matchedList) > 0 and needed > 0:
        return matchedList
    else:
        return None

def compareValuesMulti(dvDic, DV1, value, value1, linkText, sign, sign1, sequence=0, category=None, abstract=False, needed=2):
    matchedList = []
    x = 0
    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in DV1 and dvr is not None and sign(float(value), float(dvr)) and sign1(float(dvr), float(value1)):
            matchedList.append(dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract))
            x += 1
            if needed <= x:
                break
    if abstract and x > 0:
        return True
    elif abstract is False and len(matchedList) > 0 and needed > 0:
        return matchedList
    else:
        return None

def codeValue(code_name, link_text, sequence=0, category=None, abstract=False):
    # Find code and if abstract is true abstract it to the provided category
    abstraction = accountContainer.GetFirstCodeLink(code_name, link_text)
    if abstraction is not None:
        abstraction.Sequence = sequence
        if abstract:
            category.Links.Add(abstraction)
            return True
        else:
            return abstraction
    if abstract:
        return False
    return abstraction

def multiCodeValue(code_list, link_text, sequence=0, category=None, abstract=False):
    # Go through Code List and find first code and if abstract is true abstract it to the provided category
    abstraction = None
    for code in code_list:
        abstraction = accountContainer.GetFirstCodeLink(code, link_text)
        if abstraction is not None:
            abstraction.Sequence = sequence
            if abstract:
                category.Links.Add(abstraction)
                return True
            else:
                return abstraction
    if abstract and abstraction is None:
        return False
    return abstraction

def prefixCodeValue(prefix, link_text, sequence=0, category=None, abstract=False):
    # Use prefix to find first code match based on regex search and if abstract is true abstract it to the provided category
    abstraction = None
    validCodes = [codes for codes in accountContainer.CodeKeys if re.match(prefix, codes) is not None]
    for code in validCodes:
        abstraction = accountContainer.GetFirstCodeLink(code, link_text)
        if abstraction is not None:
            abstraction.Sequence = sequence
            if abstract:
                category.Links.Add(abstraction)
                return True
            else:
                return abstraction
    if abstract and abstraction is None:
        return False
    return abstraction

def medValue(med_name, link_text, sequence=0, category=None, abstract=False):
    # Find Medication Value and if abstract is true abstract it to the provided category
    abstraction = accountContainer.GetFirstMedicationLink(med_name, link_text)
    if abstraction is not None:
        abstraction.Sequence = sequence
        if abstract:
            category.Links.Add(abstraction)
            return True
        else:
            return abstraction
    if abstract:
        return False
    return abstraction

def updateLinkText(value, replacement_text):
    # Update the link text with the provided text
    value.LinkText = replacement_text + value.LinkText
    return value

def documentLink(DocumentType, LinkText, sequence, category, abstract):
    # Finds a document link and adds it as link so that its a quick reference for the cdi user.
    abstraction = None
    abstraction = accountContainer.GetFirstDocumentLink(DocumentType, LinkText)
    if abstraction is not None:
        abstraction.Sequence = sequence
        if abstract:
            category.Links.Add(abstraction)
            return True
        else:
            return abstraction
    return None

#========================================
#  Script Specific Functions
#========================================
def HemoglobinHematocritValues(dvDic, gender, value, value1, Needed):
    linkText1 = "Hemoglobin: [VALUE] (Result Date: [RESULTDATETIME])"
    linkText2 = "Hematocrit: [VALUE] (Result Date: [RESULTDATETIME])"
    discreteDic = {}
    discreteDic1 = {}
    x = 0
    a = 0
    z = 0
    hemoglobinList = []
    hematocritList = []
    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in dvHemoglobin and dvr is not None:
            x += 1
            discreteDic[x] = dvDic[dv]
        elif dvDic[dv]['Name'] in dvHematocrit and dvr is not None:
            a += 1
            discreteDic1[a] = dvDic[dv]

    if x > 0:
        for item in discreteDic:
            if z == Needed:
                break
            if x > 0 and float(cleanNumbers(discreteDic[x].Result)) < float(value):
                hemoglobinList.append(dataConversion(discreteDic[x].ResultDate, linkText1, discreteDic[x].Result, discreteDic[x].UniqueId or discreteDic[x]._id, hemoglobin, 0, False, gender))
                if a > 0 and discreteDic[x].ResultDate == discreteDic1[a].ResultDate:
                    hematocritList.append(dataConversion(discreteDic1[a].ResultDate, linkText2, discreteDic1[a].Result, discreteDic1[a].UniqueId or discreteDic1[a]._id, hematocrit, 0, False, gender))
                else:
                    for item in discreteDic1:
                        if discreteDic[x].ResultDate == discreteDic1[item].ResultDate:
                            hematocritList.append(dataConversion(discreteDic1[item].ResultDate, linkText2, discreteDic1[item].Result, discreteDic1[item].UniqueId or discreteDic1[item]._id, hematocrit, 0, False, gender))
                            break
                z += 1; a = a - 1; x = x - 1
            elif a > 0 and float(cleanNumbers(discreteDic1[a].Result)) < float(value1):
                hematocritList.append(dataConversion(discreteDic1[a].ResultDate, linkText2, discreteDic1[a].Result, discreteDic1[a].UniqueId or discreteDic1[a]._id, hematocrit, 0, False, gender))
                if x > 0 and discreteDic[x].ResultDate == discreteDic1[a].ResultDate:
                    hemoglobinList.append(dataConversion(discreteDic[x].ResultDate, linkText1, discreteDic[x].Result, discreteDic[x].UniqueId or discreteDic[x]._id, hemoglobin, 0, False, gender))
                else:
                    for item in discreteDic:
                        if discreteDic1[a].ResultDate == discreteDic[item].ResultDate:
                            hemoglobinList.append(dataConversion(discreteDic[item].ResultDate, linkText1, discreteDic[item].Result, discreteDic[item].UniqueId or discreteDic[item]._id, hematocrit, 0, False, gender))
                            break
                z += 1; a = a - 1; x = x - 1
            else:
                a = a - 1
                x = x - 1

    if len(hemoglobinList) > 0 or len(hematocritList) > 0:
        if len(hemoglobinList) == 0:
            hemoglobinList = [False]
        if len(hematocritList) == 0:
            hematocritList = [False]
        return [hemoglobinList, hematocritList]
    elif len(hemoglobinList) == 0 and len(hematocritList) == 0:
        if len(hemoglobinList) == 0:
            hemoglobinList = [False]
        if len(hematocritList) == 0:
            hematocritList = [False]

    return [hemoglobinList, hematocritList]

def percentageDropDVValues(dvDic, DV1, DV2, value1, value2, linkText1, linkText2, category1, category2):
    discreteDic = {}
    discreteDic2 = {}
    x = 0
    a = 0
    hemoglobinList = []
    hematocritList = []
    trigger = False
    trigger1 = False
    
    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in DV1 and dvr is not None:
            x += 1
            discreteDic[x] = dvDic[dv]
        if dvDic[dv]['Name'] in DV2 and dvr is not None:
            a += 1
            discreteDic2[a] = dvDic[dv]
            
    largeHemoglobinDic = sorted(discreteDic.items(), key=lambda x: x[1]['Result'], reverse=True)
    largeHematocritDic = sorted(discreteDic2.items(), key=lambda x: x[1]['Result'], reverse=True)
    if len(largeHemoglobinDic ) > 0:
        hemoLarge = list(largeHemoglobinDic)[0]
    if len(largeHematocritDic ) > 0:
        hemaLarge = list(largeHematocritDic)[0]

    if x >= 2:
        for item in discreteDic:
            if x <= 0:
                break
            if (
                discreteDic[x].ResultDate > hemoLarge[1]['ResultDate'] and
                float(cleanNumbers(hemoLarge[1]['Result'])) - float(cleanNumbers(discreteDic[x].Result)) >= 2 and
                float(cleanNumbers(discreteDic[x].Result)) < value1
            ):
                hemoglobinList.append(dataConversion(hemoLarge[1]['ResultDate'], linkText1, hemoLarge[1]['Result'], hemoLarge[1]['UniqueId'] or hemoLarge[1]['_id'], category1, 1, False))
                hemoglobinList.append(dataConversion(discreteDic[x].ResultDate, linkText1, discreteDic[x].Result, discreteDic[x].UniqueId or discreteDic[x]._id, category1, 1, False))
                trigger = True
                break
            x = x - 1
        if trigger:
            for item in discreteDic2:
                if hemoLarge[1]['ResultDate'] == discreteDic2[item].ResultDate:
                    hematocritList.append(dataConversion(discreteDic2[item].ResultDate, linkText2, discreteDic2[item].Result, discreteDic2[item].UniqueId or discreteDic2[item]._id, category2, 1, False))
                elif discreteDic[x].ResultDate == discreteDic2[item].ResultDate:
                    hematocritList.append(dataConversion(discreteDic2[item].ResultDate, linkText2, discreteDic2[item].Result, discreteDic2[item].UniqueId or discreteDic2[item]._id, category2, 1, False))
    if a >= 2:
        for item in discreteDic2:
            if a <= 0:
                break
            if (
                discreteDic2[a].ResultDate > hemaLarge[1]['ResultDate'] and
                float(cleanNumbers(hemaLarge[1]['Result'])) - float(cleanNumbers(discreteDic2[a].Result)) >= 6 and
                float(cleanNumbers(discreteDic2[a].Result)) < value2
            ):
                hematocritList.append(dataConversion(hemaLarge[1]['ResultDate'], linkText2, hemaLarge[1]['Result'], hemaLarge[1]['UniqueId'] or hemaLarge[1]['_id'], category2, 1, False))
                hematocritList.append(dataConversion(discreteDic2[a].ResultDate, linkText2, discreteDic2[a].Result, discreteDic2[a].UniqueId or discreteDic2[a]._id, category2, 1, False))
                trigger1 = True
                break
            a = a - 1
        if trigger1:
            for item in discreteDic:
                if discreteDic[item].ResultDate == hemaLarge[1]['ResultDate']:
                    hemoglobinList.append(dataConversion(discreteDic[item].ResultDate, linkText1, discreteDic[item].Result, discreteDic[item].UniqueId or discreteDic[item]._id, category1, 1, False))
                elif discreteDic[item].ResultDate == discreteDic2[a].ResultDate:
                    hemoglobinList.append(dataConversion(discreteDic[item].ResultDate, linkText1, discreteDic[item].Result, discreteDic[item].UniqueId or discreteDic[item]._id, category1, 1, False))

    if len(hemoglobinList) > 0 or len(hematocritList) > 0:
        if len(hemoglobinList) == 0:
            hemoglobinList = [False]
        if len(hematocritList) == 0:
            hematocritList = [False]
        return [hemoglobinList, hematocritList]
    elif len(hemoglobinList) == 0 and len(hematocritList) == 0:
        if len(hemoglobinList) == 0:
            hemoglobinList = [False]
        if len(hematocritList) == 0:
            hematocritList = [False]

    return [hemoglobinList, hematocritList]

def dvLookUpAllLinkedValuesSingleLine(dvDic, DV1, DV2, sequence, category, linkText):
    date1 = None
    date2 = None
    id = None
    FirstLoop = True
    dateList = []
    for dv in dvDic or []:
        dvr1 = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in DV1 and dvr1 is not None and dvDic[dv]['ResultDate'] not in dateList:
            for dv2 in dvDic or []:
                dvr2 = cleanNumbers(dvDic[dv2]['Result'])
                if dvDic[dv2]['Name'] in DV2 and dvr2 is not None and dvDic[dv]['ResultDate'] == dvDic[dv2]['ResultDate']:
                    if FirstLoop:
                        FirstLoop = False
                        linkText = linkText + dvr1 + "/" + dvr2
                    else:
                        linkText = linkText + ", " + dvr1 + "/" + dvr2
                    if date1 is None:
                        date1 = dvDic[dv]['ResultDate']
                    date2 = dvDic[dv]['ResultDate']
                    if id is None:
                        id = dvDic[dv]['UniqueId'] or dvDic[dv]['_id']
                    dateList.append(dvDic[dv]['ResultDate'])
                    break
        elif dvDic[dv]['Name'] in DV2 and dvr1 is not None and dvDic[dv]['ResultDate'] not in dateList:
            for dv2 in dvDic or []:
                dvr2 = cleanNumbers(dvDic[dv2]['Result'])
                if dvDic[dv2]['Name'] in DV1 and dvr2 is not None and dvDic[dv]['ResultDate'] == dvDic[dv2]['ResultDate']:
                    if FirstLoop:
                        FirstLoop = False
                        linkText = linkText + dvr1 + "/" + dvr2
                    else:
                        linkText = linkText + ", " + dvr1 + "/" + dvr2
                    if date1 is None:
                        date1 = dvDic[dv]['ResultDate']
                    date2 = dvDic[dv]['ResultDate']
                    if id is None:
                        id = dvDic[dv]['UniqueId'] or dvDic[dv]['_id']
                    dateList.append(dvDic[dv]['ResultDate'])
                    break
            
    if date1 is not None and date2 is not None:
        date1 = datetimeFromUtcToLocal(date1)
        date1 = date1.ToString("MM/dd/yyyy")
        date2 = datetimeFromUtcToLocal(date2)
        date2 = date2.ToString("MM/dd/yyyy") 
        linkText = linkText.replace("DATE1", date1)
        linkText = linkText.replace("DATE2", date2)
        category.Links.Add(MatchedCriteriaLink(linkText, None, None, id, True, None, None, sequence))
            
#========================================
#  Algorithm
#========================================
db.LogEvaluationScriptMessage("Script starting " + str(account._id), scriptName, scriptInstance, "Debug")
#Determine if if and how many fully spec codes are on the acct
codes = []
codes = codeDic.keys()
codeList = CodeCount(codes)
codesExist = len(codeList)
str1 = ', '.join([str(elem) for elem in codeList])

#Variable Declaration and Algorithm Start
#Standard Variable Declaration
AlertPassed = False
alertTriggered = False
AlertConditions = False
validated = False
outcome = None
subtitle = None
dcLinks = False
absLinks = False
labsLinks = False
vitalsLinks = False
medsLinks = False
hemoglobinLinks = False
hematocritLinks = False
soBleedingLinks = False
SOB = False
AT = False
noLabs = []
message1 = False
message2 = False
message3 = False
message4 = False

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
alertTrigger = MatchedCriteriaLink("Alert Trigger", None, "Alert Trigger", None, True, None, None, 2)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 3)
vitals = MatchedCriteriaLink("Vital Signs/Intake and Output Data", None, "Vital Signs/Intake and Output Data", None, True, None, None, 4)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 5)
meds = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 6)
soBleeding = MatchedCriteriaLink("Sign of Bleeding", None, "Sign of Bleeding", None, True, None, None, 7)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 8)
hemoglobin = MatchedCriteriaLink("Hemoglobin", None, "Hemoglobin", None, True, None, None, 1)
hematocrit = MatchedCriteriaLink("Hematocrit", None, "Hematocrit", None, True, None, None, 2)
bloodLoss = MatchedCriteriaLink("Blood Loss", None, "Blood Loss", None, True, None, None, 3)

#Link Text for special messages for lacking
LinkText1 = "Possible No Low Hemoglobin, Low Hematocrit or Anemia Treatment"
LinkText2 = "Possible No Sign of Bleeding Please Review"
LinkText3 = "Possible No Hemoglobin Values Meeting Criteria Please Review"
LinkText4 = "Possible No Anemia Treatment found"

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Anemia':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        subtitle = alert.Subtitle
        for alertLink in alert.Links:
            if alertLink.LinkText == "Documented Dx":
                for links in alertLink.Links:
                    if links.LinkText == LinkText1:
                        message1 = True
                    if links.LinkText == LinkText2:
                        message2 = True
                    if links.LinkText == LinkText3:
                        message3 = True
                    if links.LinkText == LinkText4:
                        message4 = True  
        break

#Check if alert was autoresolved or completed.
if validated is False:
    #Find all discrete values for custom lookups within the last X days
    maindiscreteDic = {}
    unsortedDicsreteDic = {}
    dvCount = 0
    #Combine all items into one list to search against
    discreteSearchList = [i for j in [dvHemoglobin, dvHematocrit, dvBloodLoss] for i in j]
    #Set datelimit for how far back to 
    dvDateLimit = System.DateTime.Now.AddDays(-7)
    #Loop through all dvs finding any that match in the combined list adding to a dictionary the matches
    for dv in discreteValues or []:
        if dv.ResultDate >= dvDateLimit:
            if any(item == dv.Name for item in discreteSearchList):
                dvCount += 1
                unsortedDicsreteDic[dvCount] = dv
    #Sort List by latest
    maindiscreteDic = sorted(unsortedDicsreteDic.items(), key=lambda x: x[1]['ResultDate'], reverse=True)
                           
    #Documented Dx
    d649Code = codeValue("D64.9", "Unspecified Anemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 0)
    d500Code = codeValue("D50.0", "Iron deficiency anemia secondary to blood loss (chronic): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 0)
    d62Code = codeValue("D62", "Acute Posthemorrhagic Anemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 0)
    bloodLossDV = dvValueMulti(dict(maindiscreteDic), dvBloodLoss, "Blood Loss: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodLoss1, gt, 0, bloodLoss, False, 10)
    #Signs of Bleeding
    i975Codes = multiCodeValue(["I97.51", "I97.52"], "Accidental Puncture/Laceration of Circulatory System Organ During Procedure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    k917Codes = multiCodeValue(["K91.71", "K91.72"], "Accidental Puncture/Laceration of Digestive System Organ During Procedure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    j957Codes = multiCodeValue(["J95.71", "J95.72"], "Accidental Puncture/Laceration of Respiratory System Organ During Procedure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3)
    k260Code = codeValue("K26.0", "Acute Duodenal Ulcer with Hemorrhage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4)
    k262Code = codeValue("K26.2", "Acute Duodenal Ulcer with Hemorrhage and Perforation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5)
    k250Code = codeValue("K25.0", "Acute Gastric Ulcer with Hemorrhage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6)
    k252Code = codeValue("K25.2", "Acute Gastric Ulcer with Hemorrhage and Perforation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7)
    k270Code = codeValue("K27.0", "Acute Peptic Ulcer with Hemorrhage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8)
    k272Code = codeValue("K27.2", "Acute Peptic Ulcer with Hemorrhage and Perforation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9)
    bleedingAbs = abstractValue("BLEEDING", "Bleeding '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10)
    r319Code = codeValue("R31.9", "Bloody Urine: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11)
    k264Code = codeValue("K26.4", "Chronic Duodenal Ulcer with Hemorrhage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12)
    k266Code = codeValue("K26.6", "Chronic Duodenal Ulcer with Hemorrhage and Perforation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13)
    k254Code = codeValue("K25.4", "Chronic Gastric Ulcer with Hemorrhage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14)
    k256Code = codeValue("K25.6", "Chronic Gastric Ulcer with Hemorrhage and Perforation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15)
    k276Code = codeValue("K27.6", "Chronic Peptic Ulcer with Hemorrhage and Perforation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16)
    n99510Code = codeValue("N99.510", "Cystostomy Hemorrhage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17)
    r040Code = codeValue("R04.0", "Epistaxis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18)
    i8501Code = codeValue("I85.01", "Esophageal Varices with Bleeding: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19)
    eblAbs = abstractValue("ESTIMATED_BLOOD_LOSS", "Estimated Blood Loss '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 20)
    k922Code = codeValue("K92.2", "GI Hemorrhage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21)
    hematomaAbs = abstractValue("HEMATOMA", "Hematoma '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 22)
    k920Code = codeValue("K92.0", "Hematemesis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23)
    r310Code = prefixCodeValue("^R31\.", "Hematuria: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 24)
    r195Code = codeValue("R19.5", "Heme-Positive Stool: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 25)
    k661Code = codeValue("K66.1", "Hemoperitoneum: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 26)
    hemorrhageAbs = abstractValue("HEMORRHAGE", "Hemorrhage '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 27)
    n3091Code = codeValue("N30.91", "Hemorrhagic Cystitis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 28)
    j9501Code = codeValue("J95.01", "Hemorrhage from Tracheostomy Stoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 29)
    r042Code = codeValue("R04.2", "Hemoptysis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 30)
    i974Codes = multiCodeValue(["I97.410", "I97.411", "I97.418", "I97.42"], "Intraoperative Hemorrhage/Hematoma of Circulatory System Organ: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 31)
    k916Codes = multiCodeValue(["K91.61", "K91.62"], "Intraoperative Hemorrhage/Hematoma of Digestive System Organ: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 32)
    n99Codes = multiCodeValue(["N99.61", "N99.62"], "Intraoperative Hemorrhage/Hematoma of Genitourinary System: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 33)
    g9732Code = codeValue("G97.32", "Intraoperative Hemorrhage/Hematoma of Nervous System Organ: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 34)
    g9731Code = codeValue("G97.31", "Intraoperative Hemorrhage/Hematoma of Nervous System Procedure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 35)
    j956Codes = multiCodeValue(["J95.61", "J95.62"], "Intraoperative Hemorrhage/Hematoma of Respiratory System: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 36)
    k921Code = codeValue("K92.1", "Melena: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 37)
    i61Codes = prefixCodeValue("^I61\.", "Nontraumatic Intracerebral Hemorrhage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 38)
    i62Codes = prefixCodeValue("^I62\.", "Nontraumatic Intracerebral Hemorrhage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 39)
    i60Codes = prefixCodeValue("^I60\.", "Nontraumatic Subarachnoid Hemorrhage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 40)
    l7632Code = codeValue("L76.32", "Postoperative Hematoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 41)
    k918Codes = multiCodeValue(["K91.840", "K91.841", "K91.870", "K91.871"], "Postoperative Hemorrhage/Hematoma of Digestive System Organ: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 42)
    i976Codes = multiCodeValue(["I97.610", "I97.611", "I97.618", "I97.620"], "Postoperative Hemorrhage/Hematoma of Circulatory System Organ: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 43)
    n991Codes = multiCodeValue(["N99.820", "N99.821", "N99.840", "N99.841"], "Postoperative Hemorrhage/Hematoma of Genitourinary System: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 44)
    g9752Code = codeValue("G97.52", "Postoperative Hemorrhage/Hematoma of Nervous System Organ: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 45)
    g9751Code = codeValue("G97.51", "Postoperative Hemorrhage/Hematoma of Nervous System Procedure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 46)
    j958Codes = multiCodeValue(["J95.830", "J95.831", "J95.860", "J95.861"], "Postoperative Hemorrhage/Hematoma of Respiratory System: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 47)
    k625Code = codeValue("K62.5", "Rectal Bleeding: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 48)
    #Labs
    hemoHemaConsecutDropDV = [[False], [False]]
    lowHemoglobinMultiDV = [[False], [False]]
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
    #Meds
    anemiaMedsAbs = abstractValue("ANEMIA_MEDICATION", "Anemia Medication '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1)
    anemiaMeds = medValue("Anemia Supplement", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 2)
    cellSaverAbs = abstractValue("CELL_SAVER", "Cell Saver '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3)
    hematopoeticMed = medValue("Hemopoietic Agent", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 4)
    hemtopoeticAbs = abstractValue("HEMATOPOIETIC_AGENT", "Hematopoietic Agent '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5)
    rBloTransfusionCodes = multiCodeValue(["30233N1", "30243N1"], "Red Blood Cell Transfusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6)
    redBloodCellDV = dvValue(dvRedBloodCellTransfusion, "Red Blood Cell Transfusion: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, 7)
    
    #Signs of Bleeding
    if (
        i975Codes is not None or
        k917Codes is not None or
        j957Codes is not None or
        k260Code is not None or
        k262Code is not None or
        k250Code is not None or
        k252Code is not None or
        k270Code is not None or
        k272Code is not None or
        k264Code is not None or
        k266Code is not None or
        k254Code is not None or
        k256Code is not None or
        k276Code is not None or
        n99510Code is not None or
        i8501Code is not None or
        k922Code is not None or
        hematomaAbs is not None or
        k920Code is not None or
        r310Code is not None or
        k661Code is not None or
        n3091Code is not None or
        j9501Code is not None or
        r042Code is not None or
        i974Codes is not None or
        k916Codes is not None or
        n99Codes is not None or
        g9732Code is not None or
        g9731Code is not None or
        j956Codes is not None or
        k921Code is not None or
        l7632Code is not None or
        k918Codes is not None or
        i976Codes is not None or
        n991Codes is not None or
        g9752Code is not None or
        g9751Code is not None or
        j958Codes is not None or
        k625Code is not None or
        r319Code is not None or
        r040Code is not None or
        r195Code is not None or
        i61Codes is not None or
        i62Codes is not None or
        i60Codes is not None or 
        len(bloodLossDV or noLabs) > 0 or
        eblAbs is not None or
        bleedingAbs is not None or
        hemorrhageAbs is not None
    ):
        SOB = True

    #Anemia Treatment
    if (
        anemiaMedsAbs is not None or
        anemiaMeds is not None or
        hematopoeticMed is not None or
        hemtopoeticAbs is not None or
        rBloTransfusionCodes is not None or
        cellSaverAbs is not None
    ):
        AT = True
        
    #Algorithm
    #1.1
    if codesExist > 0 and (lowHemoglobinDV is not None or AT or lowHematocrit30DV is not None) and subtitle == "Anemia Dx Possibly Lacking Supporting Evidence":
        AlertConditions = True
        if message1: dc.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, False))
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to clinical evidence now existing on the Account"
        result.Validated = True
    #1
    elif codesExist > 0 and lowHemoglobinDV is None and lowHematocrit30DV is None and AT is False:
        if lowHemoglobinDV is None or AT is False: dc.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None))
        for code in codeList:
            desc = codeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            dc.Links.Add(tempCode)
        result.Subtitle = "Anemia Dx Possibly Lacking Supporting Evidence"
        AlertPassed = True
    #2.1    
    elif(
        d62Code is not None and
        ((message2 is False or (message2 is True and SOB)) and
        (message3 is False or (message3 is True and lowHemoglobinDV is not None)) and
        (message4 is False or (message4 is True and AT))) and
        subtitle == "Acute Blood Loss Anemia Dx Possibly Lacking Clinical Evidence"
    ):
        if lowHemoglobinDV is not None: updateLinkText(lowHemoglobinDV, autoEvidenceText); dc.Links.Add(lowHemoglobinDV)
        if message2: dc.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None, False))
        if message3: dc.Links.Add(MatchedCriteriaLink(LinkText3, None, None, None, False))
        if message4: dc.Links.Add(MatchedCriteriaLink(LinkText4, None, None, None, False))
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to clinical evidence now existing on the Account"
        result.Validated = True
        AlertPassed = True
    #2
    elif d62Code is not None and (SOB is False or lowHemoglobinDV is None or AT is False):
        dc.Links.Add(d62Code)
        if SOB is False: dc.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None))
        elif SOB and message2: dc.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None, False))
        if lowHemoglobinDV is None: dc.Links.Add(MatchedCriteriaLink(LinkText3, None, None, None))
        elif lowHemoglobinDV is not None and message3: dc.Links.Add(MatchedCriteriaLink(LinkText3, None, None, None, False))
        if AT is False: dc.Links.Add(MatchedCriteriaLink(LinkText4, None, None, None))
        elif AT and message4: dc.Links.Add(MatchedCriteriaLink(LinkText4, None, None, None, False))
        result.Subtitle = "Acute Blood Loss Anemia Dx Possibly Lacking Clinical Evidence"
        AlertPassed = True
    #3.1/4.1/5.1/6.1
    elif d62Code is not None and subtitle == "Possible Acute Blood Loss Anemia":
        dc.Links.Add(d62Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #3
    elif d62Code is None and (hemoHemaConsecutDropDV[0][0] is not False or hemoHemaConsecutDropDV[1][0] is not False) and SOB:
        if hemoHemaConsecutDropDV[0][0] is not False:
            for entry in hemoHemaConsecutDropDV[0]:
                hemoglobin.Links.Add(entry)
        if hemoHemaConsecutDropDV[1][0] is not False:
            for entry in hemoHemaConsecutDropDV[1]:
                hematocrit.Links.Add(entry)
        alertTrigger.Links.Add(MatchedCriteriaLink("Possible Hemoglobin levels decreased by 2 or more or possible Hematocrit levels decreased by 6 or more, along with a possible presence of Bleeding. Please review Clinical Evidence.", None, None, None, True))
        db.LogEvaluationScriptMessage("Possible Acute Blood Loss Anemia Number 4 Triggered. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Subtitle = "Possible Acute Blood Loss Anemia"
        AlertPassed = True
    #4
    elif d62Code is None and lowHemoglobinDV is not None and SOB and AT:
        if lowHemoglobinDV is not None: hemoglobin.Links.Add(lowHemoglobinDV)
        alertTrigger.Links.Add(MatchedCriteriaLink("Possible Low Hgb or Hct, possible sign of Bleeding and Anemia Treatment present.", None, None, None, True))
        db.LogEvaluationScriptMessage("Possible Acute Blood Loss Anemia Number 2 Triggered. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Subtitle = "Possible Acute Blood Loss Anemia"
        AlertPassed = True
    #5   
    elif d62Code is None and (lowHemoglobin10DV is not None or lowHematocrit30DV is not None) and SOB:
        if lowHemoglobin10DV is not None: hemoglobin.Links.Add(lowHemoglobin10DV)
        if lowHematocrit30DV is not None: hematocrit.Links.Add(lowHematocrit30DV)
        alertTrigger.Links.Add(MatchedCriteriaLink("Possible Hgb <10 or Hct <30 and possible sign of Bleeding present.", None, None, None, True))
        db.LogEvaluationScriptMessage("Possible Acute Blood Loss Anemia Number 3 Triggered. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Subtitle = "Possible Acute Blood Loss Anemia"
        AlertPassed = True
    #6
    elif (
        d62Code is None and 
        (d649Code is not None or d500Code is not None) and
        SOB and AT
    ):
        alertTrigger.Links.Add(MatchedCriteriaLink("Anemia Dx documented, possible sign of bleeding and Anemia Treatment present.", None, None, None, True))
        if d500Code is not None: dc.Links.Add(d500Code)
        if d649Code is not None: dc.Links.Add(d649Code)
        db.LogEvaluationScriptMessage("Possible Acute Blood Loss Anemia Number 1 Triggered. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Subtitle = "Possible Acute Blood Loss Anemia"
        AlertPassed = True
    #7.1
    elif subtitle == "Possible Anemia Dx" and codesExist > 0:
        for code in codeList:
            desc = codeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            if tempCode is not None:
                dc.Links.Add(tempCode)
                break
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to clinical evidence now existing on the Account"
        result.Validated = True
        AlertConditions = True
    #7
    elif (
        codesExist == 0 and
        d649Code is None and 
        (((lowHemoglobinMultiDV[0][0] is not False and len(lowHemoglobinMultiDV[0] or noLabs) > 1 ) or 
            (lowHemoglobinMultiDV[1][0] is not False and len(lowHemoglobinMultiDV[1] or noLabs) > 1 )) or
        (((lowHemoglobinMultiDV[0][0] is not False and len(lowHemoglobinMultiDV[0] or noLabs) == 1) or 
            (lowHemoglobinMultiDV[1][0] is not False and len(lowHemoglobinMultiDV[1] or noLabs) == 1)) and AT))
    ):
        result.Subtitle = "Possible Anemia Dx"
        AlertPassed = True  

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#Alert Passed Abstractions
if AlertPassed:
    #Abstractions
    codeValue("T45.1X5A", "Adverse Effect of Antineoplastic and Immunosuppressive Drug: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, abs, True)
    prefixCodeValue("^F10\.1", "Alcohol Abuse: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, abs, True)
    prefixCodeValue("^F10\.2", "Alcohol Dependence: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, abs, True)
    codeValue("K70.31", "Alcoholic Liver Cirrhosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, abs, True)
    codeValue("Z51.11", "Chemotherapy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, abs, True)
    multiCodeValue(["N18.1","N18.2","N18.30","N18.31","N18.32","N18.4","N18.5", "N18.9"], "Chronic Kidney Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, abs, True)
    codeValue("K27.4", "Chronic Peptic Ulcer with Hemorrhage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, abs, True)
    abstractValue("CURRENT_CHEMOTHERAPY", "Current Chemotherapy '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, abs, True)
    abstractValue("DYSPNEA_ON_EXERTION", "Dyspnea on Exertion '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, abs, True)
    codeValue("N18.6", "End-Stage Renal Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, abs, True)
    codeValue("R53.83", "Fatigue: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, abs, True)
    prefixCodeValue("^C82\.", "Follicular Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, abs, True)
    multiCodeValue(["I50.20", "I50.22", "I50.23", "I50.30", "I50.32", "I50.33", "I50.40", "I5.42", "I50.43", "I50.810", "I50.812", "I50.813", "I50.84", "I50.89", "I50.9"], "Heart Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13, abs, True)
    codeValue("D58.0", "Hereditary Spherocytosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, abs, True)
    codeValue("B20", "HIV: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
    prefixCodeValue("^C81\.", "Hodgkin Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, abs, True)
    codeValue("Z51.12", "Immunotherapy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17, abs, True)
    codeValue("E61.1", "Iron Deficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, abs, True)
    prefixCodeValue("^C95\.", "Leukemia of Unspecified Cell Type: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19, abs, True)
    prefixCodeValue("^C91\.", "Lymphoid Leukemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20, abs, True)
    codeValue("K22.6", "Mallory-Weiss Tear: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21, abs, True)
    multiCodeValue(["E40", "E41", "E42", "E43", "E44.0", "E44.1", "E45"], "Malnutrition: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 22, abs, True)
    prefixCodeValue("^C84\.", "Mature T/NK-Cell Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23, abs, True)
    prefixCodeValue("^C90\.", "Multiple Myeloma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 24, abs, True)
    prefixCodeValue("^C93\.", "Monocytic Leukemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 25, abs, True)
    codeValue("D46.9", "Myelodysplastic Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 26, abs, True)
    prefixCodeValue("^C92\.", "Myeloid Leukemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 27, abs, True)
    prefixCodeValue("^C83\.", "Non-Follicular Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 28, abs, True)
    prefixCodeValue("^C94\.", "Other Leukemias: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 29, abs, True)
    prefixCodeValue("^C86\.", "Other Types of T/NK-Cell Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 30, abs, True)
    codeValue("R23.1", "Pale [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 31, abs, True)
    codeValue("K27.9", "Peptic Ulcer: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 32, abs, True)
    codeValue("F19.10", "Psychoactive Substance Abuse: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 33, abs, True)
    codeValue("Z51.0", "Radiation Therapy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 34, abs, True)
    prefixCodeValue("^M05\.", "Rheumatoid Arthritis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 35, abs, True)
    prefixCodeValue("^D86\.", "Sarcoidosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 36, abs, True)
    abstractValue("SHORTNESS_OF_BREATH", "Shortness of Breath: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 37, abs, True)
    prefixCodeValue("^D57\.", "Sickle Cell Disorder: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 38, abs, True)
    codeValue("R16.1", "Splenomegaly: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 39, abs, True)
    prefixCodeValue("^M32\.", "Systemic Lupus Erthematosus (SLE): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 40, abs, True)
    prefixCodeValue("^C85\.", "Unspecified Non-Hodgkin Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 41, abs, True)
    abstractValue("WEAKNESS", "Weakness: '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 42, abs, True)
    #Labs
    dvValue(dvMCH, "MCH: [VALUE] (Result Date: [RESULTDATETIME])", calcMCH1, 1, labs, True)
    dvValue(dvMCHC, "MCHC: [VALUE] (Result Date: [RESULTDATETIME])", calcMCHC1, 2, labs, True)
    dvValue(dvMCV, "MCV: [VALUE] (Result Date: [RESULTDATETIME])", calcMCV1, 3, labs, True)
    dvValue(dvRBC, "RBC: [VALUE] (Result Date: [RESULTDATETIME])", calcRBC1, 4, labs, True)
    dvValue(dvRDW, "RDW: [VALUE] (Result Date: [RESULTDATETIME])", calcRDW1, 5, labs, True)
    dvValue(dvReticulocyteCount, "Reticulocyte Count: [VALUE] (Result Date: [RESULTDATETIME])", calcReticulocyteCount1, 6, labs, True)
    if not dvValue(dvSerumFerritin, "Serum Ferritin: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumFerritin1, 7, labs, True):
        dvValue(dvSerumFerritin, "Serum Ferritin: [VALUE] (Result Date: [RESULTDATETIME])", lambda x: True, 8, labs, True)
    if not dvValue(dvFolate, "Serum Folate: [VALUE] (Result Date: [RESULTDATETIME])", calcFolate1, 9, labs, True):
        dvValue(dvFolate, "Serum Folate: [VALUE] (Result Date: [RESULTDATETIME])", lambda x: True, 10, labs, True)
    if not dvValue(dvSerumIron, "Serum Iron: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumIron1, 11, labs, True):
        dvValue(dvSerumIron, "Serum Iron: [VALUE] (Result Date: [RESULTDATETIME])", lambda x: True, 12, labs, True)
    dvValue(dvTotalIronBindingCapacity, "Total Iron Binding Capacity: [VALUE] (Result Date: [RESULTDATETIME])", calcTotalIronBindingCapacity1, 13, labs, True)
    dvValue(dvTransferrin, "Transferrin: [VALUE] (Result Date: [RESULTDATETIME])", calcTransferrin1, 14, labs, True)
    dvValue(dvVitaminB12, "Vitamin B12: [VALUE] (Result Date: [RESULTDATETIME])", calcVitB121, 15, labs, True)
    dvValue(dvWBC, "WBC: [VALUE] (Result Date: [RESULTDATETIME])", calcWBC1, 16, labs, True)
    #Meds
    if anemiaMedsAbs is not None: meds.Links.Add(anemiaMedsAbs) #1
    if anemiaMeds is not None: meds.Links.Add(anemiaMeds) #2
    if cellSaverAbs is not None: meds.Links.Add(cellSaverAbs) #3
    if hematopoeticMed is not None: meds.Links.Add(hematopoeticMed) #4
    if hemtopoeticAbs is not None: meds.Links.Add(hemtopoeticAbs) #5
    if rBloTransfusionCodes is not None: meds.Links.Add(rBloTransfusionCodes) #6
    if redBloodCellDV is not None: meds.Links.Add(redBloodCellDV) #7
    #Signs of Bleeding
    if i975Codes is not None: soBleeding.Links.Add(i975Codes) #1
    if k917Codes is not None: soBleeding.Links.Add(k917Codes) #2
    if j957Codes is not None: soBleeding.Links.Add(j957Codes) #3
    if k260Code is not None: soBleeding.Links.Add(k260Code) #4
    if k262Code is not None: soBleeding.Links.Add(k262Code) #5
    if k250Code is not None: soBleeding.Links.Add(k250Code) #6
    if k252Code is not None: soBleeding.Links.Add(k252Code) #7
    if k270Code is not None: soBleeding.Links.Add(k270Code) #8
    if k272Code is not None: soBleeding.Links.Add(k272Code) #9
    if bleedingAbs is not None: soBleeding.Links.Add(bleedingAbs) #10
    if r319Code is not None: soBleeding.Links.Add(r319Code) #11
    if k264Code is not None: soBleeding.Links.Add(k264Code) #12
    if k266Code is not None: soBleeding.Links.Add(k266Code) #13
    if k254Code is not None: soBleeding.Links.Add(k254Code) #14
    if k256Code is not None: soBleeding.Links.Add(k256Code) #15
    if k276Code is not None: soBleeding.Links.Add(k276Code) #16
    if n99510Code is not None: soBleeding.Links.Add(n99510Code) #17
    if r040Code is not None: soBleeding.Links.Add(r040Code) #18
    if i8501Code is not None: soBleeding.Links.Add(i8501Code) #19
    if eblAbs is not None: soBleeding.Links.Add(eblAbs) #20
    if k922Code is not None: soBleeding.Links.Add(k922Code) #21
    if hematomaAbs is not None: soBleeding.Links.Add(hematomaAbs) #22
    if k920Code is not None: soBleeding.Links.Add(k920Code) #23
    if r310Code is not None: soBleeding.Links.Add(r310Code) #24
    if r195Code is not None: soBleeding.Links.Add(r195Code) #25
    if k661Code is not None: soBleeding.Links.Add(k661Code) #26
    if n3091Code is not None: soBleeding.Links.Add(n3091Code) #27
    if j9501Code is not None: soBleeding.Links.Add(j9501Code) #28
    if hemorrhageAbs is not None: soBleeding.Links.Add(hemorrhageAbs) #29
    if r042Code is not None: soBleeding.Links.Add(r042Code) #30
    if i974Codes is not None: soBleeding.Links.Add(i974Codes) #31
    if k916Codes is not None: soBleeding.Links.Add(k916Codes) #32
    if n99Codes is not None: soBleeding.Links.Add(n99Codes) #33
    if g9732Code is not None: soBleeding.Links.Add(g9732Code) #34
    if g9731Code is not None: soBleeding.Links.Add(g9731Code) #35
    if j956Codes is not None: soBleeding.Links.Add(j956Codes) #36
    if k921Code is not None: soBleeding.Links.Add(k921Code) #37
    if i61Codes is not None: soBleeding.Links.Add(i61Codes) #38
    if i62Codes is not None: soBleeding.Links.Add(i62Codes) #39
    if i60Codes is not None: soBleeding.Links.Add(i60Codes) #40
    if l7632Code is not None: soBleeding.Links.Add(l7632Code) #41
    if k918Codes is not None: soBleeding.Links.Add(k918Codes) #42
    if i976Codes is not None: soBleeding.Links.Add(i976Codes) #43
    if n991Codes is not None: soBleeding.Links.Add(n991Codes) #44
    if g9752Code is not None: soBleeding.Links.Add(g9752Code) #45
    if g9751Code is not None: soBleeding.Links.Add(g9751Code) #46
    if j958Codes is not None: soBleeding.Links.Add(j958Codes) #47
    if k625Code is not None: soBleeding.Links.Add(k625Code) #48
    if bloodLossDV is not None:             
        for entry in bloodLossDV:
            bloodLoss.Links.Add(entry)
        if bloodLoss.Links: soBleeding.Links.Add(bloodLoss)
    #Vitals
    abstractValue("LOW_BLOOD_PRESSURE", "Blood Pressure: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1, vitals, True)
    dvValue(dvMAP, "Mean Arterial Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcMAP1, 2, vitals, True)
    dvValue(dvSBP, "Systolic Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcSBP1, 3, vitals, True)
    #Hemoglobin/Hematocrit
    if lowHemoglobinMultiDV[0][0] is not False:
        for entry in lowHemoglobinMultiDV[0]:
            hemoglobin.Links.Add(entry)
    if lowHemoglobinMultiDV[1][0] is not False:
        for entry in lowHemoglobinMultiDV[1]:
            hematocrit.Links.Add(entry)
 
#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if hemoglobin.Links: labs.Links.Add(hemoglobin); hemoglobinLinks = True
    if hematocrit.Links: labs.Links.Add(hematocrit); hematocritLinks = True
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if alertTrigger.Links: result.Links.Add(alertTrigger)
    if abs.Links: result.Links.Add(abs); absLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    if vitals.Links: result.Links.Add(vitals); vitalsLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    if soBleeding.Links: result.Links.Add(soBleeding); soBleedingLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Documented Dx- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks) + ", vitals- "
        + str(vitalsLinks) + ", meds- " + str(medsLinks) + ", Hemoglobin- " + str(hemoglobinLinks) + ", hematocrit- " + str(hematocritLinks) +
        ", sign of bleeding- " + str(soBleedingLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
