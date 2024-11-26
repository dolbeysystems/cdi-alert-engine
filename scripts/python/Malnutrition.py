##################################################################################################################
#Evaluation Script - Malnutrition
#
#This script checks an account to see if it matches criteria to be alerted for Nalnutrition
#Date - 11/24/2024
#Version - V21
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

#========================================
#  Script Specific Constants
#========================================
codeDic = {
    "E40": "Kwashiorkor",
    "E41": "Nutritional Marasmus",
    "E42": "Marasmic Kwashiorkor",
    "E43": "Unspecified Severe Protein-Calorie Malnutrition",
    "E44.0": "Moderate Protein-Calorie Malnutrition",
    "E44.1": "Mild Protein-Calorie Malnutrition",
    "E45": "Retarded Development Following Protein-Calorie Malnutrition"
}
autoEvidenceText = "Autoresolved Evidence - "
autoCodeText = "Autoresolved Code - "

cautionCodeDoc = [
    "Dietitian Progress Notes", 
    "Nutrition MNT Follow-Up ADIME Note", 
    "Clinical Nutrition", 
    "Nutrition A-D-I-M-E Note", 
    "Nutrition ADIME Initial Note", 
    "Nutrition ADIME Follow Up Note"
]

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
dvBMI = ["3.5 BMI Calculation (kg/m2)"]
calcBMI1 = lambda x : 0 < x < 18.5
calcBMI2 = lambda x : x > 18.5
dvLymphocyteCount = [""]
calcLymphocyteCount1 = lambda x: x < 1
dvSerumCalcium = ["CALCIUM (mg/dL)"]
calcSerumCalcium1 = lambda x: x < 8.3
calcSerumCalcium2 = lambda x: x > 10.2
dvSerumChloride = ["CHLORIDE (mmol/L)"]
calcSerumChloride1 = lambda x: x < 98
calcSerumChloride2 = lambda x: x > 110
dvSerumMagnesium = ["MAGNESIUM (mg/dL)"]
calcSerumMagnesium1 = lambda x: x < 1.6
calcSerumMagnesium2 = lambda x: x > 2.5
dvSerumPhosphate = ["PHOSPHATE (mg/dL)"]
calcSerumPhosphate1 = lambda x: x < 2.7
calcSerumPhosphate2 = lambda x: x > 4.5
dvSerumPotassium = ["POTASSIUM (mmol/L)"]
calcSerumPotassium1 = lambda x: x < 3.4
calcSerumPotassium2 = lambda x: x > 5.1
dvSerumSodium = ["SODIUM (mmol/L)"]
calcSerumSodium1 = lambda x: x < 131
calcSerumSodium2 = lambda x: x > 145
dvTotalCholesterol = ["CHOLESTEROL (mg/dL)", "CHOLESTEROL"]
calcTotalCholesterol1 = lambda x: x < 200
dvTransferrin = ["TRANSFERRIN"]
calcTransferrin1 = lambda x: x < 215

dvWeightkg = ["Weight lbs 3.5 (kg)"]
dvWeightLbs = ["Weight lbs 3.5 (lb)"]
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
#  Script Specific
#========================================
def cautionCode(code_name, link_text, document, sequence):
    # Caution coding is used here to find where a code is only mentioned on one of the above listed caution code documents.
    # This function for conflicting purposes will abstract both caution coded codes and an indicator if its only on caution code docs.
    match = {}
    abstractionList = accountContainer.GetCodeLinks(code_name, link_text)
    nonMatch = {}
    x = 0
    y = 0
    for doc in abstractionList:
        for item in document:
            if any(re.search(pattern, doc.LinkText, re.IGNORECASE) for pattern in document):
                x += 1
                match[x] = doc
            else:
                y += 1
                nonMatch[y] = doc

    # First if checks if the code is only located on a caution code document and send the abstraction back and indicates with a false
    #       that its caution coding only.
    if y == 0 and x > 0:
        abstraction = MatchedCriteriaLink(match[x].LinkText, match[x].DocumentId, match[x].Code, None, True, None, None, sequence)
        return [abstraction, False]
    #Else is there to catch the first code Abstraction not on a caution code document and send the abstraction back and indicate with a True
    #       that the code is found on both legitament documentation not just on caution coded documentation.
    else:
        for item in abstractionList:
            abstraction = MatchedCriteriaLink(nonMatch[y].LinkText, nonMatch[y].DocumentId, nonMatch[y].Code, None, True, None, None, sequence)
            return [abstraction, True]
    #If no match at all is found None is returned
    return [None, None]

#========================================
#  Algorithm
#========================================
db.LogEvaluationScriptMessage("Script starting " + str(account._id), scriptName, scriptInstance, "Debug")
#Calaculate Age
age = math.floor((admitDate - birthDate).TotalDays/ 365.2425)

#Determine if if and how many fully spec codes are on the acct
codes = []
codes = codeDic.keys()
codeList = CodeCount(codes)
codesExist = len(codeList)
str1 = ', '.join([str(elem) for elem in codeList])

#Standard Variable Declaration
AlertPassed = False
alertTriggered = False
AlertConditions = False
validated = False
outcome = None
subtitle = None
CI = 0
CMS40 = False
CMS41 = False
CMS441 = False
CMS42 = False
CMS43 = False
CMS440 = False
MS441 = False
CMS45 = False
CMS46 = False
triggerAlert = True
reason = None
dcLinks = False
absLinks = False
labsLinks = False
riskLinks = False
docLinksLinks = False
treatmentLinks = False

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 2)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 3)
risk = MatchedCriteriaLink("Risk Factor(s)", None, "Risk Factor(s)", None, True, None, None, 4)
nutritionNoteLinks = MatchedCriteriaLink("Nutrition Note", None, "Nutrition Note", None, True, None, None, 5)
treatment = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 6)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 7)

#Caution coding autoresolve declarations
autoCC = False
e40Triggered = False
e41Triggered = False
e42Triggered = False
e43Triggered = False
e440Triggered = False
e441Triggered = False
e45Triggered = False
e46Triggered = False

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Malnutrition':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        reason = alert.Reason
        if outcome == 'AUTORESOLVED' or reason == 'Previously Autoresolved':
            triggerAlert = False
        subtitle = alert.Subtitle
        if alert.Subtitle == "Possible Malnutrition" or alert.Subtitle == "Possible Low BMI":
            for alertLink in alert.Links:
                if alertLink.LinkText == 'Documented Dx':
                    for links in alertLink.Links:
                        if re.match(r'\bCaution Code - Kwashiorkor\b', links.LinkText, re.IGNORECASE):
                            e40Triggered = True
                        if re.match(r'\bCaution Code - Nutritional\b', links.LinkText, re.IGNORECASE):
                            e41Triggered = True
                        if re.match(r'\bCaution Code - Marasmic\b', links.LinkText, re.IGNORECASE):
                            e42Triggered = True
                        if re.match(r'\bCaution Code - Severe Protein-Calorie Malnutrition\b', links.LinkText, re.IGNORECASE):
                            e43Triggered = True
                        if re.match(r'\bCaution Code - Moderate\b', links.LinkText, re.IGNORECASE):
                            e440Triggered = True
                        if re.match(r'\bCaution Code - Mild\b', links.LinkText, re.IGNORECASE):
                            e441Triggered = True
                        if re.match(r'\bCaution Code - Retarded\b', links.LinkText, re.IGNORECASE):
                            e45Triggered = True
                        if re.match(r'\bCaution Code - Unspecified Protein-Calorie Malnutrition\b', links.LinkText, re.IGNORECASE):
                            e46Triggered = True
        break

#Check if alert was autoresolved or completed.
if (
    validated is False or
    (outcome == "AUTORESOLVED" and validated and codesExist > 1)
):
    #Alert Trigger
    e46Code = codeValue("E46", "Unspecified Protein-Calorie Malnutrition: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    r636Code = codeValue("R63.6", "Underweight: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    t730xxxaCode = codeValue("T73.0XXA", "Starvation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    malnutritionCodes = multiCodeValue(["E40", "E41", "E42", "E43", "E44.0", "E44.1", "E45"], "Malnutrition: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Abs
    r634Code = codeValue("R63.4", "Abnormal Weight Loss: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    r627Code = codeValue("R62.7", "Adult Failure to Thrive: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    lowBMIAbs = abstractValue("LOW_BMI", "BMI: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4)
    lowBMIDV = dvValue(dvBMI, "BMI: [VALUE] (Result Date: [RESULTDATETIME])", calcBMI1, 5)
    r64Code = codeValue("R64", "Cachexia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6)
    r601Code = codeValue("R60.1", "Generalized Edema: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18)
    gripStrengthAbs = abstractValue("GRIP_STRENGTH_REDUCED", "Reduceded Grip Strength '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 19)
    lossofMuscleMassMildAbs = abstractValue("LOSS_OF_MUSCLE_MASS_MILD", "Loss of Muscle Mass Mild '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 21)
    lossofMuscleMassModAbs = abstractValue("LOSS_OF_MUSCLE_MASS_MODERATE", "Loss of Muscle Mass Moderate '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 22)
    lossofMuscleMassSevereAbs = abstractValue("LOSS_OF_MUSCLE_MASS_SEVERE", "Loss of Muscle Mass Severe '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 23)
    lossofSubcutaneousFatMildAbs = abstractValue("LOSS_OF_SUBCUTANEOUS_FAT_MILD", "Loss of Subcutaneous Fat Mild '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 24)
    lossofSubcutaneousFatModAbs = abstractValue("LOSS_OF_SUBCUTANEOUS_FAT_MODERATE", "Loss of Subcutaneous Fat Moderate '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 25)
    lossofSubcutaneousFatSevereAbs = abstractValue("LOSS_OF_SUBCUTANEOUS_FAT_SEVERE", "Loss of Subcutaneous Fat Severe '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 26)
    modFluidAccumulationAbs = abstractValue("MODERATE_FLUID_ACCUMULATION", "Moderate Fluid Accumulation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 30)
    nonHealingWoundAbs = abstractValue("NON_HEALING_WOUND", "Non Healing Wound '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 33)
    reducedEnergyIntakeAbs = abstractValue("REDUCED_ENERGY_INTAKE", "Reduced Energy Intake '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 36)
    reducedEnergyIntakeSevereAbs = abstractValue("REDUCED_ENERGY_INTAKE_SEVERE", "Reduced Energy Intake Severe '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 37)
    reducedEnergyIntakeModAbs = abstractValue("REDUCED_ENERGY_INTAKE_MODERATE", "Reduced Energy Intake Moderate '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 38)
    severeFluidAccumulationAbs = abstractValue("SEVERE_FLUID_ACCUMULATION", "Severe Fluid Accumulation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 39)
    unintentionalWeightLossMildAbs = abstractValue("UNINTENTIONAL_WEIGHT_LOSS_MILD", "Unintentional Weight Loss Mild '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 43)
    unintentionalWeightLossSevereAbs = abstractValue("UNINTENTIONAL_WEIGHT_LOSS_SEVERE", "Unintentional Weight Loss Severe '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 44)
    unintentionalWeightLossAbs = abstractValue("UNINTENTIONAL_WEIGHT_LOSS", "Unintentional Weight Loss '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 45)
    #Doc Links
    documentLink("Dietitian Progress Notes", "Dietitian Progress Notes", 0, nutritionNoteLinks, True)
    documentLink("Nutrition MNT Follow-Up ADIME Note", "Nutrition MNT Follow-Up ADIME Note", 0, nutritionNoteLinks, True)
    documentLink("Clinical Nutrition", "Clinical Nutrition", 0, nutritionNoteLinks, True)
    documentLink("Nutrition A-D-I-M-E Note", "Nutrition A-D-I-M-E Note", 0, nutritionNoteLinks, True)
    documentLink("Nutrition ADIME Initial Note", "Nutrition ADIME Initial Note", 0, nutritionNoteLinks, True)
    documentLink("Nutrition ADIME Follow Up Note", "Nutrition ADIME Follow Up Note", 0, nutritionNoteLinks, True)
    #Caution Code
    e40CC = cautionCode("E40", "Caution Code - Kwashiorkor (MCC): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", cautionCodeDoc, 0)
    e41CC = cautionCode("E41", "Caution Code - Nutritional Marasmus (MCC): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", cautionCodeDoc, 0)
    e42CC = cautionCode("E42", "Caution Code - Marasmic Kwashiorkor (MCC): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", cautionCodeDoc, 0)
    e43CC = cautionCode("E43", "Caution Code - Severe Protein-Calorie Malnutrition (MCC): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", cautionCodeDoc, 0)
    e440CC = cautionCode("E44.0", "Caution Code - Moderate Protein-Calorie Malnutrition (CC): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", cautionCodeDoc, 0)
    e441CC = cautionCode("E44.1", "Caution Code - Mild Protein-Calorie Malnutrition (CC): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", cautionCodeDoc, 0)
    e45CC = cautionCode("E45", "Caution Code - Retarded Development Following Protein-Calorie Malnutrition (CC): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", cautionCodeDoc, 0)
    e46CC = cautionCode("E46", "Caution Code - Unspecified Protein-Calorie Malnutrition: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", cautionCodeDoc, 0)

    #Clinical Indicator count and abstraction.
    if lossofSubcutaneousFatMildAbs is not None or lossofSubcutaneousFatModAbs is not None or lossofSubcutaneousFatSevereAbs is not None:
        if lossofSubcutaneousFatMildAbs is not None: abs.Links.Add(lossofSubcutaneousFatMildAbs)
        if lossofSubcutaneousFatModAbs is not None: abs.Links.Add(lossofSubcutaneousFatModAbs)
        if lossofSubcutaneousFatSevereAbs is not None: abs.Links.Add(lossofSubcutaneousFatSevereAbs)
        CI += 1
    if lossofMuscleMassMildAbs is not None or lossofMuscleMassModAbs is not None or lossofMuscleMassSevereAbs is not None:
        if lossofMuscleMassMildAbs is not None: abs.Links.Add(lossofMuscleMassMildAbs)
        if lossofMuscleMassModAbs is not None: abs.Links.Add(lossofMuscleMassModAbs)
        if lossofMuscleMassSevereAbs is not None: abs.Links.Add(lossofMuscleMassSevereAbs)
        CI += 1
    if unintentionalWeightLossMildAbs is not None or unintentionalWeightLossAbs is not None or unintentionalWeightLossSevereAbs is not None:
        if unintentionalWeightLossMildAbs is not None: abs.Links.Add(unintentionalWeightLossMildAbs)
        if unintentionalWeightLossAbs is not None: abs.Links.Add(unintentionalWeightLossAbs)
        if unintentionalWeightLossSevereAbs is not None: abs.Links.Add(unintentionalWeightLossSevereAbs)
        CI += 1
    if reducedEnergyIntakeAbs is not None or reducedEnergyIntakeModAbs is not None or reducedEnergyIntakeSevereAbs is not None:
        if unintentionalWeightLossMildAbs is not None: abs.Links.Add(unintentionalWeightLossMildAbs)
        if reducedEnergyIntakeModAbs is not None: abs.Links.Add(reducedEnergyIntakeModAbs)
        if reducedEnergyIntakeSevereAbs is not None: abs.Links.Add(reducedEnergyIntakeSevereAbs)
        CI += 1
    if r634Code is not None: abs.Links.Add(r634Code); CI += 1
    if gripStrengthAbs is not None: abs.Links.Add(gripStrengthAbs); CI += 1
    if nonHealingWoundAbs is not None: abs.Links.Add(nonHealingWoundAbs); CI += 1
    if r627Code is not None: abs.Links.Add(r627Code); CI += 1
    if r64Code is not None: abs.Links.Add(r64Code); CI += 1
    if r601Code is not None: abs.Links.Add(r601Code); CI += 1
    if severeFluidAccumulationAbs is not None: abs.Links.Add(severeFluidAccumulationAbs); CI += 1
    if modFluidAccumulationAbs is not None: abs.Links.Add(modFluidAccumulationAbs); CI += 1   
    
    #Determine Conflicting Malnutrition Severity
    if e40CC[0] is not None and e40CC[1] and (e41CC[1] is False or e42CC[1] is False or e43CC[1] is False or e440CC[1] is False or e441CC[1] is False or e45CC[1] is False):
        CMS40 = True
    if e41CC[0] is not None and e41CC[1]  and (e40CC[1] is False or e42CC[1] is False or e43CC[1] is False or e440CC[1] is False or e441CC[1] is False or e45CC[1] is False):
        CMS41 = True
    if e42CC[0] is not None and e42CC[1] and (e40CC[1] is False or e41CC[1] is False or e43CC[1] is False or e440CC[1] is False or e441CC[1] is False or e45CC[1] is False):
        CMS42 = True
    if e43CC[0] is not None and e43CC[1] and (e40CC[1] is False or e41CC[1] is False or e42CC[1] is False or e440CC[1] is False or e441CC[1] is False or e45CC[1] is False):
        CMS43 = True
    if e440CC[0] is not None and e440CC[1] and (e40CC[1] is False or e41CC[1] is False or e42CC[1] is False or e43CC[1] is False or e441CC[1] is False or e45CC[1] is False):
        CMS440 = True
    if e441CC[0] is not None and e441CC[1] and (e40CC[1] is False or e41CC[1] is False or e42CC[1] is False or e43CC[1] is False or e440CC[1] is False or e45CC[1] is False):
        CMS441 = True
    if e45CC[0] is not None and e45CC[1] and (e40CC[1] is False or e41CC[1] is False or e42CC[1] is False or e43CC[1] is False or e440CC[1] is False or e441CC[1] is False):
        CMS45 = True

    #Check if Caution Coding is no longer present and if so autoresolve the alert.
    if e40CC[1] and e40Triggered:
        autoCC = True
    if e41CC[1] and e41Triggered:
        autoCC = True
    if e42CC[1] and e42Triggered:
        autoCC = True
    if e43CC[1] and e43Triggered:
        autoCC = True
    if e440CC[1] and e440Triggered:
        autoCC = True
    if e441CC[1] and e441Triggered:
        autoCC = True
    if e45CC[1] and e45Triggered:
        autoCC = True
    if e46CC[1] and e46Triggered:
        autoCC = True
    if e40CC[1] is False and e40Triggered:
        autoCC = False
    if e41CC[1] is False and e41Triggered:
        autoCC = False
    if e42CC[1] is False and e42Triggered:
        autoCC = False
    if e43CC[1] is False and e43Triggered:
        autoCC = False
    if e440CC[1] is False and e440Triggered:
        autoCC = False
    if e441CC[1] is False and e441Triggered:
        autoCC = False
    if e45CC[1] is False and e45Triggered:
        autoCC = False
    if e46CC[1] is False and e46Triggered:
        autoCC = False

    db.LogEvaluationScriptMessage("AutoCC " + str(autoCC) + ", e40CC[1] " + str(e40CC[1]) + ", e40CC[1] " + str(e40CC[1]) + ", e41CC[1] " + str(e41CC[1]) +
        ", e42CC[1] " + str(e42CC[1]) + ", e43CC[1] " + str(e43CC[1]) + ", e440CC[1] " + str(e440CC[1]) + ", e441CC[1] " + str(e441CC[1]) + 
        ", e45CC[1] " + str(e45CC[1]) + ", e46CC[1] " + str(e45CC[1]) + ", e40Triggered " + str(e40Triggered) + ", e41Triggered " + str(e41Triggered) + 
        ", e42Triggered " + str(e42Triggered) + ", e43Triggered " + str(e43Triggered) + ", e440Triggered " + str(e440Triggered) + ", e441Triggered " + str(e441Triggered) + 
        ", e45Triggered " + str(e45Triggered) + ", e46Triggered " + str(e46Triggered) + " " + str(account._id), scriptName, scriptInstance, "Debug")
    
    #Main Algorithm
    #1
    if (CMS40 or CMS41 or CMS42 or CMS43 or CMS440 or CMS441 or CMS45):
        if e40CC[0] is not None and CMS40: dc.Links.Add(e40CC[0])
        if e41CC[0] is not None and CMS41: dc.Links.Add(e41CC[0])
        if e42CC[0] is not None and CMS42: dc.Links.Add(e42CC[0])
        if e43CC[0] is not None and CMS43: dc.Links.Add(e43CC[0])
        if e440CC[0] is not None and CMS440: dc.Links.Add(e440CC[0])
        if e441CC[0] is not None and CMS441: dc.Links.Add(e441CC[0])
        if e45CC[0] is not None and CMS45: dc.Links.Add(e45CC[0])
        if e40CC[1] is False: dc.Links.Add(e40CC[0])
        if e41CC[1] is False: dc.Links.Add(e41CC[0])
        if e42CC[1] is False: dc.Links.Add(e42CC[0])
        if e43CC[1] is False: dc.Links.Add(e43CC[0])
        if e440CC[1] is False: dc.Links.Add(e440CC[0])
        if e441CC[1] is False: dc.Links.Add(e441CC[0])
        if e45CC[1] is False: dc.Links.Add(e45CC[0])
        result.Subtitle = "Conflicting Malnutrition Severity (Provider/RDN)"
        AlertPassed = True 
    #2  
    elif codesExist > 1:
        for code in codeList:
            desc = codeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, desc + ": [CODE] '[PHRASE]' '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            dc.Links.Add(tempCode)
        result.Subtitle = "Conflicting Malnutrition Dx " + str1
        if validated:
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"
            result.Validated = False
        AlertPassed = True
    #3.1
    elif subtitle == "Malnutrition Missing Acuity" and codesExist == 1:
        for code in codeList:
            desc = codeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            if tempCode is not None:
                dc.Links.Add(tempCode)
                break
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #3
    elif triggerAlert and codesExist == 0 and e46Code is not None:
        if e46Code is not None: dc.Links.Add(e46Code)
        result.Subtitle = "Malnutrition Missing Acuity"
        AlertPassed = True
    #4.1
    elif (
        subtitle == "Possible Malnutrition" and
        autoCC == True and 
        (codesExist > 0 or e46Code is not None)
    ):
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #4
    elif (
        triggerAlert and
        (e40CC[0] is not None and e40CC[1] is False) or
        (e41CC[0] is not None and e41CC[1] is False) or
        (e42CC[0] is not None and e42CC[1] is False) or
        (e43CC[0] is not None and e43CC[1] is False) or
        (e440CC[0] is not None and e440CC[1] is False) or
        (e441CC[0] is not None and e441CC[1] is False) or
        (e45CC[0] is not None and e45CC[1] is False) or
        (e46CC[0] is not None and e46CC[1] is False)
    ):
        if e40CC[0] is not None and e40CC[1] is False: dc.Links.Add(e40CC[0])
        if e41CC[0] is not None and e41CC[1] is False: dc.Links.Add(e41CC[0])
        if e42CC[0] is not None and e42CC[1] is False: dc.Links.Add(e42CC[0])
        if e43CC[0] is not None and e43CC[1] is False: dc.Links.Add(e43CC[0])
        if e440CC[0] is not None and e440CC[1] is False: dc.Links.Add(e440CC[0])
        if e441CC[0] is not None and e441CC[1] is False: dc.Links.Add(e441CC[0])
        if e45CC[0] is not None and e45CC[1] is False: dc.Links.Add(e45CC[0])
        if e46CC[0] is not None and e46CC[1] is False: dc.Links.Add(e46CC[0])
        result.Subtitle = "Possible Malnutrition"
        AlertPassed = True
    #5.1
    elif (
        subtitle == "Possible Low BMI" and
        ((r627Code is not None or r634Code is not None or r64Code is not None or r636Code is not None or t730xxxaCode is not None or e46Code is not None) or
        (malnutritionCodes is not None and autoCC))
    ):
        if r627Code is not None: updateLinkText(r627Code, "Autoresolved Specified Code - "); dc.Links.Add(r627Code)
        if r634Code is not None: updateLinkText(r634Code, "Autoresolved Specified Code - "); dc.Links.Add(r634Code)
        if r64Code is not None: updateLinkText(r64Code, "Autoresolved Specified Code - "); dc.Links.Add(r64Code)
        if r636Code is not None: updateLinkText(r636Code, "Autoresolved Specified Code - "); dc.Links.Add(r636Code)
        if t730xxxaCode is not None: updateLinkText(t730xxxaCode, "Autoresolved Specified Code - "); dc.Links.Add(t730xxxaCode)
        if malnutritionCodes is not None: updateLinkText(malnutritionCodes, "Autoresolved Specified Code - "); dc.Links.Add(malnutritionCodes)
        if e46Code is not None: updateLinkText(e46Code, "Autoresolved Specified Code - "); dc.Links.Add(e46Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one or more Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #5
    elif triggerAlert and (lowBMIDV is not None or lowBMIAbs is not None) and r627Code is None and e46Code is None and r634Code is None and r64Code is None and r636Code is None and t730xxxaCode is None and malnutritionCodes is None:
        result.Subtitle = "Possible Low BMI"
        AlertPassed = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Negations
    transferrinNegation = multiCodeValue(["K72.0", "K72.00", "K72.01", "K72.1", "K72.10", "K72.11", "K72.9", "K72.90",
                                      "K72.91", "K74.4", "K74.5", "K74.6", "K74.60", "D59.13", "D59.19", "D59.2",
                                      "D59.3", "D59.30", "D59.31", "D59.32", "D59.39", "D59.4", "D59.5", "D59.6",
                                      "D59.8", "D59.9"],
                                    "Transferrin Negation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    lymphocyteCountNegation = multiCodeValue(["D60.0", "D60.1", "D60.8", "D60.9", "D61", "D61.0", "D61.01", "D61.09",
                                          "D61.1", "D61.2", "D61.3", "D61.8", "D61.81", "D61.810", "D61.811",
                                          "D61.818", "D61.82", "D61.89", "D61.9"],
                                        "Lymphocyte Count Negation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Abstractions
    #1-2
    prefixCodeValue("^E54\.", "Ascorbic Acid Deficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, abs, True)
    #4
    if lowBMIDV is not None: abs.Links.Add(lowBMIDV) #5
    else: dvValue(dvBMI, "BMI: [VALUE] (Result Date: [RESULTDATETIME])", calcBMI2, 5)
    if lowBMIAbs is not None: abs.Links.Add(lowBMIAbs) #6
    abstractValue("DECREASED_FUNCTIONAL_CAPACITY", "Decreased Functional Capacity '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7, abs, True)
    prefixCodeValue("^E53\.", "Deficiency of other B group Vitamins: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8, abs, True)
    prefixCodeValue("^E61\.", "Deficiency of other Nutrient Elements: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, abs, True)
    abstractValue("DIARRHEA", "Diarrhea '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10, abs, True)
    codeValue("E58", "Dietary Calcium Deficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, abs, True)
    codeValue("E59", "Dietary Selenium Deficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, abs, True)
    codeValue("E60", "Dietary Zinc Deficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13, abs, True)
    multiCodeValue(["R13.10", "R13.11", "R13.12", "R13.13", "R13.14", "R13.19"], "Dysphagia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, abs, True)
    codeValue("R53.83", "Fatigue: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
    abstractValue("FEELING_COLD", "Feeling Cold '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 16, abs, True)
    abstractValue("FRAIL", "Frail '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 17, abs, True)
    #18-19
    abstractValue("HEIGHT", "Height: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 20, abs, True)
    #21-26
    abstractValue("LOW_FOOD_INTAKE", "Low Food Intake '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 27, abs, True)
    abstractValue("MALNOURISHED_SIGN", "Malnourished Sign '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 28, abs, True)
    abstractValue("MALNUTRITION_RISK_FACTORS", "Malnutrition Risk Factors '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 29, abs, True)
    #30
    abstractValue("MODERATE_MALNUTRITION", "Moderate Malnutrition '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 31, abs, True)
    prefixCodeValue("^E52\.", "Niacin Deficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 32, abs, True)
    #33
    prefixCodeValue("^E63\.", "Other Nutritional Deficiencies: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 34, abs, True)
    prefixCodeValue("^E56\.", "Other Vitamin Deficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 35, abs, True)
    #36-39
    abstractValue("SEVERE_MALNUTRTION", "Severe Malnutrition '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 40, abs, True)
    codeValue("T73.0XXA", "Starvation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 41, abs, True)
    prefixCodeValue("^E51\.", "Thiamine Deficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 42, abs, True)
    #43-45
    prefixCodeValue("^E50\.", "Vitamin A Deficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 46, abs, True)
    prefixCodeValue("^E55\.", "Vitamin D Deficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 47, abs, True)
    codeValue("R11.10", "Vomiting: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 48, abs, True)
    abstractValue("WEAKNESS", "Weakness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 49, abs, True)
    abstractValue("WEIGHT", "Weight '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 50, abs, True)
    #Labs
    if lymphocyteCountNegation is None:
        dvValue(dvLymphocyteCount, "Lymphocyte Count: [VALUE] (Result Date: [RESULTDATETIME])", calcLymphocyteCount1, 1, labs, True)
    dvValue(dvSerumCalcium, "Serum Calcium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumCalcium1, 2, labs, True)
    dvValue(dvSerumCalcium, "Serum Calcium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumCalcium2, 3, labs, True)
    dvValue(dvSerumChloride, "Serum Chloride: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumChloride1, 4, labs, True)
    dvValue(dvSerumChloride, "Serum Chloride: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumChloride2, 4, labs, True)
    dvValue(dvSerumMagnesium, "Serum Magnesium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumMagnesium1, 5, labs, True)
    dvValue(dvSerumMagnesium, "Serum Magnesium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumMagnesium2, 5, labs, True)
    dvValue(dvSerumPhosphate, "Serum Phosphate: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumPhosphate1, 6, labs, True)
    dvValue(dvSerumPhosphate, "Serum Phosphate: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumPhosphate2, 6, labs, True)
    dvValue(dvSerumPotassium, "Serum Potassium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumPotassium1, 7, labs, True)
    dvValue(dvSerumPotassium, "Serum Potassium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumPotassium2, 7, labs, True)
    dvValue(dvSerumSodium, "Serum Sodium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumSodium1, 8, labs, True)
    dvValue(dvSerumSodium, "Serum Sodium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumSodium2, 8, labs, True)
    dvValue(dvTotalCholesterol, "Total Cholesterol: [VALUE] (Result Date: [RESULTDATETIME])", calcTotalCholesterol1, 9, labs, True)
    if transferrinNegation is None:
        dvValue(dvTransferrin, "Transferrin: [VALUE] (Result Date: [RESULTDATETIME])", calcTransferrin1, 10, labs, True)
    #Treatment
    abstractValue("DIET", "Diet '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1, treatment, True)
    codeValue("3E0G76Z", "Enteral Nutrition: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, treatment, True)
    codeValue("3E0H76Z", "J Tube Nutrition: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, treatment, True)
    abstractValue("NUTRITIONAL_SUPPLEMENT", "Nutritional Supplement: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4, treatment, True)
    abstractValue("PARENTERAL_NUTRITION", "Parenteral Nutrition '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5, treatment, True)
    #Risk Factors
    codeValue("B20", "AIDS/HIV: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, risk, True)
    prefixCodeValue("^F10\.1", "Alcohol Abuse: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, risk, True)
    prefixCodeValue("^F10\.2", "Alcohol Dependence: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, risk, True)
    prefixCodeValue("^K70\.", "Alcoholic Liver Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, risk, True)
    codeValue("R63.0", "Anorexia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, risk, True)
    abstractValue("CANCER", "Cancer '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5, risk, True)
    codeValue("K90.0", "Celiac Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, risk, True)
    prefixCodeValue("^Z51\.1", "Chemotherapy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, risk, True)
    prefixCodeValue("^Z79\.63", "Chemotherapy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8, risk, True)
    codeValue("3E04305", "Chemotherapy Administration: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, risk, True)
    codeValue("N52.9", "Colitis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, risk, True)
    prefixCodeValue("^K50\.", "Crohns Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, risk, True)
    prefixCodeValue("^E84\.", "Cystic Fibrosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, risk, True)
    prefixCodeValue("^K57\.", "Diverticulitis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13, risk, True)
    multiCodeValue(["F50.00", "F50.01", "F50.02", "F50.2", "F50.82", "F50.9"], "Eating Disorder: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, risk, True)
    codeValue("I50.84", "End Stage Heart Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, risk, True)
    codeValue("N18.6", "End-Stage Renal Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, risk, True)
    codeValue("K56.7", "Ileus: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17, risk, True)
    multiCodeValue(["K90.89", "K90.9"], "Intestinal Malabsorption: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, risk, True)
    prefixCodeValue("^K56\.6", "Intestinal Obstructions: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19, risk, True)
    abstractValue("MENTAL_HEALTH_DISORDER", "Mental Health Disorder '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 20, risk, True)
    prefixCodeValue("^Z79\.62", "On Immunosuppressants: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21, risk, True)
    abstractValue("POOR_DENTITION", "Poor Dentition '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 22, risk, True)
    prefixCodeValue("^F01\.C", "Severe Dementia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23, risk, True)
    prefixCodeValue("^F02\.C", "Severe Dementia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 24, risk, True)
    prefixCodeValue("^F03\.C", "Severe Dementia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 25, risk, True)
    prefixCodeValue("^K90\.82", "Short Bowel Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 26, risk, True)
    abstractValue("SOCIAL_FACTOR", "Social Factor '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 27, risk, True)
    prefixCodeValue("^K51\.", "Ulcerative Colitis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 28, risk, True)
   
#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    result.Links.Add(treatment)
    if treatment.Links: treatmentLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    if risk.Links: result.Links.Add(risk); riskLinks = True
    if nutritionNoteLinks.Links: result.Links.Add(nutritionNoteLinks); docLinksLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Documented Dx- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks) + ", risk- " +
        str(riskLinks) + ", docs- " + str(docLinksLinks) + ", treatment- " + str(treatmentLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
