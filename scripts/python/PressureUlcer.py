##################################################################################################################
#Evaluation Script - Pressure Ulcer
#
#This script checks an account to see if it matches criteria to be alerted for Pressure Ulcer
#Date - 11/05/2024
#Version - V10
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
codeDic = {}
autoEvidenceText = "Autoresolved Evidence - "

cautionCodeDoc = [
    "Conference Note Wound/Skin/Ostomy Registered Nurse",
    "Progress Notes Burn/Wound Nursing Assistant",
    "Conference Note Burn/Wound Registered Nurse",
    "Consult Note Wound/Skin/Ostomy Registered Nurse",
    "Consult Follow-up Wound/Skin/Ostomy Registered Nurse",
    "Addendum Note Wound Registered Nurse",
    "Progress Notes Burn/Wound Registered Nurse",
    "Addendum Note Wound/Skin/Ostomy Registered Nurse",
    "Progress Notes Burn/Wound MA Student",
    "Result Encounter Note Wound Registered Nurse",
    "Addendum Note Burn/Wound Certified-MA",
    "Handoff Burn/Wound Registered Nurse",
    "Addendum Note Burn/Wound Registered Nurse",
    "Code Blue Burn/Wound Registered Nurse",
    "Addendum Note Burn/Wound Medical Assistant",
    "Wound Care Note",
    "Wound Care Progress Note",
    "Miscellaneous Wound Registered Nurse",
    "Wound/Skin/Ostomy Registered Nurse",
    "Nursing Shift Summary Wound/Skin/Ostomy Registered Nurse",
    "RN Care Note Wound Registered Nurse",
    "Progress Notes Wound Registered Nurse",
    "Progress Notes Wound/Skin/Ostomy Registered Nurse",
    "Progress Notes Burn/Wound Registered Nurse",
    "Progress Notes Burn/Wound Licensed Nurse",
    "Consult Note Wound/Skin/Ostomy Registered Nurse"
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
dvBradenRiskAssessmentScore = ["3.5 Braden Scale Total Points"]
calcBradenRiskAssessmentScore1 = lambda x: x < 12
dvPressureInjuryStage = [""]
calcPressureInjuryStage1 = lambda x: x >= 3

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
Unspec = 0
dcLinks = False
absLinks = False
docLinklinks = False

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 2)
woundCareLinks = MatchedCriteriaLink("Wound Care Note", None, "Wound Care Note", None, True, None, None, 3)
treatment = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 4)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 5)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Pressure Ulcer':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        subtitle = alert.Subtitle
        break

#Main Algorithm
if validated is False:
    #Full Spec Codes
    leftElbowSpecCodes = multiCodeValue(["L89.020", "L89.021", "L89.022", "L89.023", "L89.024", "L89.026"], "Autoresolved Code - Pressure Ulcer of Elbow Stage Specified Left: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    rightElbowSpecCodes = multiCodeValue(["L89.010", "L89.011", "L89.012", "L89.013", "L89.014", "L89.016"], "Autoresolved Code - Pressure Ulcer of Elbow Stage Specified Right: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    backRightUpperSpecCodes = multiCodeValue(["L89.110", "L89.111", "L89.112", "L89.113", "L89.114", "L89.116"], "Autoresolved Code - Pressure Ulcer Fully Specified Portions of Back Right Upper: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    backLeftUpperSpecCodes = multiCodeValue(["L89.120", "L89.121", "L89.122", "L89.123", "L89.124", "L89.126"], "Autoresolved Code - Pressure Ulcer Fully Specified Portions of Back Left Upper: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    backRightLowerSpecCodes = multiCodeValue(["L89.130", "L89.131", "L89.132", "L89.133", "L89.134", "L89.136"], "Autoresolved Code - Pressure Ulcer Fully Specified Portions of Back Right Lower: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    backLeftLowerSpecCodes = multiCodeValue(["L89.140", "L89.141", "L89.142", "L89.143", "L89.144", "L89.146"], "Autoresolved Code - Pressure Ulcer Fully Specified Portions of Back Left Lower: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    backSacralRegionSpecCodes = multiCodeValue(["L89.150", "L89.151", "L89.152", "L89.153", "L89.154", "L89.156"], "Autoresolved Code - Pressure Ulcer Fully Specified Portions of Back Sacral Region: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    backButtockHipContiguousSpecCodes = multiCodeValue(["L89.41", "L89.42", "L89.43", "L89.44", "L89.45", "L86.46"], "Autoresolved Code - Pressure Ulcer Fully Specified Contiguous Site of Back, Buttock and Hip: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    rightHipSpecCodes = multiCodeValue(["L89.210", "L89.211", "L89.212", "L89.213", "L89.214", "L89.216"], "Autoresolved Code - Pressure Ulcer Fully Specified Contiguous Site of Back, Buttock and Hip: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    leftHipSpecCodes = multiCodeValue(["L89.220", "L89.221", "L89.222", "L89.223", "L89.224", "L89.226"], "Autoresolved Code - Pressure Ulcer Fully Specified Contiguous Site of Back, Buttock and Hip: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    leftButtBackSpecCodes = multiCodeValue(["L89.320", "L89.321", "L89.322", "L89.323", "L89.324", "L89.326"], "Autoresolved Code - Pressure Ulcer Fully Specified Left Buttock Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    rightButtBackSpecCodes = multiCodeValue(["L89.310", "L89.311", "L89.312", "L89.313", "L89.314", "L89.316"], "Autoresolved Code - Pressure Ulcer Fully Specified Right Buttock Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    rightAnkleSpecCodes = multiCodeValue(["L89.510", "L89.511", "L89.512", "L89.513", "L89.514", "L89.516"], "Autoresolved Code - Pressure Ulcer Fully Specified Right Ankle Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    leftAnkleSpecCodes = multiCodeValue(["L89.520", "L89.521", "L89.522", "L89.523", "L89.524", "L89.526"], "Autoresolved Code - Pressure Ulcer Fully Specified Left Ankle Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    leftHeelSpecCodes = multiCodeValue(["L89.620", "L89.621", "L89.622", "L89.623", "L89.624", "L89.626"], "Autoresolved Code - Pressure Ulcer Fully Specified Left Heel Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    rightHeelSpecCodes = multiCodeValue(["L89.610", "L89.611", "L89.612", "L89.613"," L89.614", "L89.616"], "Autoresolved Code - Pressure Ulcer Fully Specified Right Heel Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    headSpecCodes = multiCodeValue(["L89.810", "L89.811", "L89.812", "L89.813", "L89.814", "L89.816"], "Autoresolved Code - Pressure Ulcer Fully Specified Head Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    otherSiteSpecCodes = multiCodeValue(["L89.890", "L89.891", "L89.892", "L89.893", "L89.894", "L89.896"], "Autoresolved Code - Pressure Ulcer Fully Specified Other Site Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    unspecSiteFullSpecCodes = multiCodeValue(["L89.91", "L89.92", "L89.93", "L89.94", "L89.95", "L89.96"], "Autoresolved Code - Pressure Ulcer Unspecified Site Fully Specified Stage Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    stage34PUCodes = multiCodeValue(["L89.013", "L89.014", "L89.113", "L89.114","L89.123", "L89.124","L89.133", "L89.134", "L89.023", "L89.024", "L89.143", "L89.144", "L89.153", "L89.154", "L89.203", "L89.204",
                                     "L89.213", "L89.214", "L89.223", "L89.224", "L89.313", "L89.314", "L89.323", "L89.324", "L89.43", "L89.44", "L89.513", "L89.514", "L89.523", "L89.524", "L89.613"," L89.614",
                                     "L89.623", "L89.624", "L89.813", "L89.814", "L89.893", "L89.894"],
                                    "Autoresolved Code - Fully Specified Pressure Ulcer Codes of Stage 3 or Stage 4: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Alert Trigger
    l89009Code = codeValue("L89.009", "Pressure Ulcer of Elbow present, but Side and Stage Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    elbowStageUnspecCodes = multiCodeValue(["L89.001", "L89.002", "L89.003", "L89.004", "L89.006"], "Pressure Ulcer of Elbow Stage Specified, but Unspecified Side: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89019Code = codeValue("L89.019", "Pressure Ulcer of Right Elbow, Stage Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89029Code = codeValue("L89.029", "Pressure Ulcer of Left Elbow, Stage Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    backStageUnspecCodes = multiCodeValue(["L89.100", "L89.101", "L89.102", "L89.103", "L89.104", "L89.106"], "Pressure Ulcer of Unspecified Portion of the Back, but Stage Specified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89119Code = codeValue("L89.119", "Pressure Ulcer of Right Upper Back, but Stage Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89129Code = codeValue("L89.129", "Pressure Ulcer of Left Upper Back, but Stage Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89139Code = codeValue("L89.139", "Pressure Ulcer of Right Upper Back, but Stage Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89149Code = codeValue("L89.149", "Pressure Ulcer of Left Lower Back, but Stage Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89159Code = codeValue("L89.159", "Pressure Ulcer of Sacral Region, with Stage Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    hipSideUnSpecCodes = multiCodeValue(["L89.200", "L89.201", "L89.202", "L89.203", "L89.204", "L89.206"], "Pressure Ulcer of the Hip Side Unspecified and Stage Specified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89209Code = codeValue("L89.209", "Pressure Ulcer of Unspecified Hip and Unspecified Stage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89219Code = codeValue("L89.219", "Pressure Ulcer of Sacral Region, with Stage Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89229Code = codeValue("L89.229", "Pressure Ulcer of Left Hip, but Stage is Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    buttockSideUnSpecCodes = multiCodeValue(["L89.300", "L89.301", "L89.302", "L89.303", "L89.304", "L89.306"], "Pressure Ulcer of Unspecified Buttock Side, but Stage is Present: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89309Code = codeValue("L89.309", "Pressure Ulcer of Unspecified Buttock Side and Unspecified Stage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89319Code = codeValue("L89.319", "Pressure Ulcer of Right Buttock, but Stage Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89329Code = codeValue("L89.329", "Pressure Ulcer of Left Buttock, but Stage Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    ankleUnSpecCodes = multiCodeValue(["L89.500", "L89.501", "L89.502", "L89.503", "L89.504", "L89.506"], "Pressure Ulcer of Unspecified Ankle with Stage Specified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l8940Code = codeValue("L89.40", "Pressure Ulcer of Contiguous Site of Back, Buttock and Hip with Unspecified Stage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89509Code = codeValue("L89.509", "Pressure Ulcer of Unspecified Ankle and Unspecified Stage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89519Code = codeValue("L89.519", "Pressure Ulcer of Right Ankle with Unspecified Stage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89529Code = codeValue("L89.529", "Pressure Ulcer of Left Ankle with Unspecified Stage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    heelUnSpecCodes = multiCodeValue(["L89.600", "L89.601", "L89.602", "L89.603", "L89.604", "L89.606"], "Pressure Ulcer of Unspecified Heel Side with Specified Stage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89609Code = codeValue("L89.609", "Pressure Ulcer of Unspecified Heel Side and Unspecified Stage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89619Code = codeValue("L89.619", "Pressure Ulcer of Right Heel with Unspecified Stage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89629Code = codeValue("L89.629", "Pressure Ulcer of Left Heel with Unspecified Stage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89819Code = codeValue("L89.819", "Pressure Ulcer of Head with Unspecified Stage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l89899Code = codeValue("L89.899", "Pressure Ulcer of Other Site with Unspecified Stage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    l8990Code = codeValue("L89.90", "Pressure Ulcer of Unspecified Site with Unspecified Stage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Abs
    pressureInjuryStageDV = dvValue(dvPressureInjuryStage, "Pressure Injury Stage: [VALUE] (Result Date: [RESULTDATETIME])", calcPressureInjuryStage1, 3)

    #Determine if Multiple Unspecified Codes
    if l89009Code is not None and leftElbowSpecCodes is None and rightElbowSpecCodes is None: Unspec += 1
    if elbowStageUnspecCodes is not None and leftElbowSpecCodes is None and rightElbowSpecCodes is None: Unspec += 1
    if l89019Code is not None and rightElbowSpecCodes is None: Unspec += 1
    if l89029Code is not None and leftElbowSpecCodes is None: Unspec += 1
    if (
        backStageUnspecCodes is not None and
        backRightUpperSpecCodes is None and
        backLeftUpperSpecCodes is None and
        backRightLowerSpecCodes is None and
        backLeftLowerSpecCodes is None and
        backSacralRegionSpecCodes is None and
        backButtockHipContiguousSpecCodes is None
        ): Unspec += 1
    if l89119Code is not None and backRightUpperSpecCodes is None: Unspec += 1
    if l89129Code is not None and backLeftUpperSpecCodes is None: Unspec += 1
    if l89139Code is not None and backRightLowerSpecCodes is None and backButtockHipContiguousSpecCodes is None: Unspec += 1
    if l89149Code is not None and backLeftLowerSpecCodes is None and backButtockHipContiguousSpecCodes is None: Unspec += 1
    if l89159Code is not None and backSacralRegionSpecCodes is None and backButtockHipContiguousSpecCodes is None: Unspec += 1
    if hipSideUnSpecCodes is not None and rightHipSpecCodes is None and leftHipSpecCodes is None and backButtockHipContiguousSpecCodes is None: Unspec += 1
    if l89209Code is not None and rightHipSpecCodes is None and leftHipSpecCodes is None and backButtockHipContiguousSpecCodes is None: Unspec += 1
    if l89219Code is not None and rightHipSpecCodes is None and backButtockHipContiguousSpecCodes is None: Unspec += 1
    if l89229Code is not None and leftHipSpecCodes is None and backButtockHipContiguousSpecCodes is None: Unspec += 1
    if buttockSideUnSpecCodes is not None and rightButtBackSpecCodes is None and leftButtBackSpecCodes is None and backButtockHipContiguousSpecCodes is None: Unspec += 1
    if l89309Code is not None and rightButtBackSpecCodes is None and leftButtBackSpecCodes is None and backButtockHipContiguousSpecCodes is None: Unspec += 1
    if l89319Code is not None and rightButtBackSpecCodes is None and backButtockHipContiguousSpecCodes is None: Unspec += 1
    if l89329Code is not None and leftButtBackSpecCodes is None and backButtockHipContiguousSpecCodes is None: Unspec += 1
    if l8940Code is not None and backButtockHipContiguousSpecCodes is None: Unspec += 1
    if ankleUnSpecCodes is not None and rightAnkleSpecCodes is None and leftAnkleSpecCodes is None: Unspec += 1
    if l89509Code is not None and rightAnkleSpecCodes is None and leftAnkleSpecCodes is None: Unspec += 1
    if l89519Code is not None and rightAnkleSpecCodes is None: Unspec += 1
    if l89529Code is not None and leftAnkleSpecCodes is None: Unspec += 1
    if heelUnSpecCodes is not None and rightHeelSpecCodes is None and leftHeelSpecCodes is None: Unspec += 1
    if l89609Code is not None and rightHeelSpecCodes is None and leftHeelSpecCodes is None: Unspec += 1
    if l89619Code is not None and rightHeelSpecCodes is None: Unspec += 1
    if l89629Code is not None and leftHeelSpecCodes is None: Unspec += 1
    if l89819Code is not None and headSpecCodes is None: Unspec += 1
    if l89899Code is not None and otherSiteSpecCodes is None: Unspec += 1
    if l8990Code is not None and unspecSiteFullSpecCodes is None: Unspec += 1

    #1
    if Unspec >= 2:
        if l89009Code is not None and leftElbowSpecCodes is None and rightElbowSpecCodes is None: dc.Links.Add(l89009Code)
        if elbowStageUnspecCodes is not None and leftElbowSpecCodes is None and rightElbowSpecCodes is None: dc.Links.Add(elbowStageUnspecCodes)
        if l89019Code is not None and rightElbowSpecCodes is None: dc.Links.Add(l89019Code)
        if l89029Code is not None and leftElbowSpecCodes is None: dc.Links.Add(l89029Code)
        if (
            backStageUnspecCodes is not None and
            backRightUpperSpecCodes is None and
            backLeftUpperSpecCodes is None and
            backRightLowerSpecCodes is None and
            backLeftLowerSpecCodes is None and
            backSacralRegionSpecCodes is None and
            backButtockHipContiguousSpecCodes is None
        ): 
            dc.Links.Add(backStageUnspecCodes)
        if l89119Code is not None and backRightUpperSpecCodes is None: dc.Links.Add(l89119Code)
        if l89129Code is not None and backLeftUpperSpecCodes is None: dc.Links.Add(l89129Code)
        if l89139Code is not None and backRightLowerSpecCodes is None and backButtockHipContiguousSpecCodes is None: dc.Links.Add(l89139Code)
        if l89149Code is not None and backLeftLowerSpecCodes is None and backButtockHipContiguousSpecCodes is None: dc.Links.Add(l89149Code)
        if l89159Code is not None and backSacralRegionSpecCodes is None and backButtockHipContiguousSpecCodes is None: dc.Links.Add(l89159Code)
        if hipSideUnSpecCodes is not None and rightHipSpecCodes is None and leftHipSpecCodes is None and backButtockHipContiguousSpecCodes is None: dc.Links.Add(hipSideUnSpecCodes)
        if l89209Code is not None and rightHipSpecCodes is None and leftHipSpecCodes is None and backButtockHipContiguousSpecCodes is None: dc.Links.Add(l89209Code)
        if l89219Code is not None and rightHipSpecCodes is None and backButtockHipContiguousSpecCodes is None: dc.Links.Add(l89219Code)
        if l89229Code is not None and leftHipSpecCodes is None and backButtockHipContiguousSpecCodes is None: dc.Links.Add(l89229Code)
        if buttockSideUnSpecCodes is not None and rightButtBackSpecCodes is None and leftButtBackSpecCodes is None and backButtockHipContiguousSpecCodes is None: dc.Links.Add(buttockSideUnSpecCodes)
        if l89309Code is not None and rightButtBackSpecCodes is None and leftButtBackSpecCodes is None and backButtockHipContiguousSpecCodes is None: dc.Links.Add(l89309Code)
        if l89319Code is not None and rightButtBackSpecCodes is None and backButtockHipContiguousSpecCodes is None: dc.Links.Add(l89319Code)
        if l89329Code is not None and leftButtBackSpecCodes is None and backButtockHipContiguousSpecCodes is None: dc.Links.Add(l89329Code)
        if l8940Code is not None and backButtockHipContiguousSpecCodes is None: dc.Links.Add(l8940Code)
        if ankleUnSpecCodes is not None and rightAnkleSpecCodes is None and leftAnkleSpecCodes is None: dc.Links.Add(ankleUnSpecCodes)
        if l89509Code is not None and rightAnkleSpecCodes is None and leftAnkleSpecCodes is None: dc.Links.Add(l89509Code)
        if l89519Code is not None and rightAnkleSpecCodes is None: dc.Links.Add(l89519Code)
        if l89529Code is not None and leftAnkleSpecCodes is None: dc.Links.Add(l89529Code)
        if heelUnSpecCodes is not None and rightHeelSpecCodes is None and leftHeelSpecCodes is None: dc.Links.Add(heelUnSpecCodes)
        if l89609Code is not None and rightHeelSpecCodes is None and leftHeelSpecCodes is None: dc.Links.Add(l89609Code)
        if l89619Code is not None and rightHeelSpecCodes is None: dc.Links.Add(l89619Code)
        if l89629Code is not None and leftHeelSpecCodes is None: dc.Links.Add(l89629Code)
        if l89819Code is not None and headSpecCodes is None: dc.Links.Add(l89819Code)
        if l89899Code is not None and otherSiteSpecCodes is None: dc.Links.Add(l89899Code)
        if l8990Code is not None and unspecSiteFullSpecCodes is None: dc.Links.Add(l8990Code)
        result.Subtitle = "Multiple Unspecifed Pressure Ulcer Codes Present"
        AlertPassed = True
        if validated:
            result.Validated = False
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"
    #2.1
    elif subtitle == "Pressure Ulcer of Elbow Unspecified Side with Stage Present" and (leftElbowSpecCodes is not None or rightElbowSpecCodes is not None):
        if leftElbowSpecCodes is not None: dc.Links.Add(leftElbowSpecCodes)
        if rightElbowSpecCodes is not None: dc.Links.Add(rightElbowSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #2.0
    elif l89009Code is not None and leftElbowSpecCodes is None and rightElbowSpecCodes is None:
        dc.Links.Add(l89009Code)
        result.Subtitle = "Pressure Ulcer of Elbow Unspecified Side with Stage Present"
        AlertPassed = True
    #3.1
    elif subtitle == "Pressure Ulcer of Elbow Stage Specified, but Unspecified Side Present" and (leftElbowSpecCodes is not None or rightElbowSpecCodes is not None):
        if leftElbowSpecCodes is not None: dc.Links.Add(leftElbowSpecCodes)
        if rightElbowSpecCodes is not None: dc.Links.Add(rightElbowSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #3.0
    elif elbowStageUnspecCodes is not None and leftElbowSpecCodes is None and rightElbowSpecCodes is None:
        dc.Links.Add(elbowStageUnspecCodes)
        result.Subtitle = "Pressure Ulcer of Elbow Stage Specified, but Unspecified Side Present"
        AlertPassed = True
    #4.1
    elif subtitle == "Pressure Ulcer of Right Elbow, Stage Unspecified Present" and rightElbowSpecCodes is not None:
        dc.Links.Add(rightElbowSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #4.0
    elif l89019Code is not None and rightElbowSpecCodes is None:
        dc.Links.Add(l89019Code)
        result.Subtitle = "Pressure Ulcer of Right Elbow, Stage Unspecified Present"
        AlertPassed = True
    #5.1
    elif subtitle == "Pressure Ulcer of Left Elbow, with Stage Unspecified Present" and leftElbowSpecCodes is not None:
        dc.Links.Add(leftElbowSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #5.0
    elif l89029Code is not None and leftElbowSpecCodes is None:
        dc.Links.Add(l89029Code)
        result.Subtitle = "Pressure Ulcer of Left Elbow, with Stage Unspecified Present"
        AlertPassed = True
    #6.1
    elif (
        subtitle == "Pressure Ulcer of Unspecified Portion of Back, with Stage Specified Present" and
        (backRightUpperSpecCodes is not None or
        backLeftUpperSpecCodes is not None or
        backRightLowerSpecCodes is not None or
        backLeftLowerSpecCodes is not None or
        backSacralRegionSpecCodes is not None or
        backButtockHipContiguousSpecCodes is not None)
        ):
        if backRightUpperSpecCodes is not None: dc.Links.Add(backRightUpperSpecCodes)
        if backLeftUpperSpecCodes is not None: dc.Links.Add(backLeftUpperSpecCodes)
        if backRightLowerSpecCodes is not None: dc.Links.Add(backRightLowerSpecCodes)
        if backLeftLowerSpecCodes is not None: dc.Links.Add(backLeftLowerSpecCodes)
        if backSacralRegionSpecCodes is not None: dc.Links.Add(backSacralRegionSpecCodes)
        if backButtockHipContiguousSpecCodes is not None: dc.Links.Add(backButtockHipContiguousSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #6.0
    elif (
        backStageUnspecCodes is not None and
        backRightUpperSpecCodes is None and
        backLeftUpperSpecCodes is None and
        backRightLowerSpecCodes is None and
        backLeftLowerSpecCodes is None and
        backSacralRegionSpecCodes is None and
        backButtockHipContiguousSpecCodes is None
    ):
        dc.Links.Add(backStageUnspecCodes)
        result.Subtitle = "Pressure Ulcer of Unspecified Portion of Back, with Stage Specified Present"
        AlertPassed = True
    #7.1
    elif subtitle == "Pressure Ulcer of Right Upper Back, with Stage Unspecified Present" and backRightUpperSpecCodes is not None:
        dc.Links.Add(backRightUpperSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #7.0
    elif l89119Code is not None and backRightUpperSpecCodes is None:
        dc.Links.Add(l89119Code)
        result.Subtitle = "Pressure Ulcer of Right Upper Back, with Stage Unspecified Present"
        AlertPassed = True
    #8.1
    elif subtitle == "Pressure Ulcer of Left Upper Back, with Stage Unspecified Present" and backLeftUpperSpecCodes is not None:
        dc.Links.Add(backLeftUpperSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #8.0
    elif l89129Code is not None and backLeftUpperSpecCodes is None:
        dc.Links.Add(l89129Code)
        result.Subtitle = "Pressure Ulcer of Left Upper Back, with Stage Unspecified Present"
        AlertPassed = True
    #9.1
    elif subtitle == "Pressure Ulcer of Right Lower Back, with Stage Unspecified Present" and (backRightLowerSpecCodes is not None or backButtockHipContiguousSpecCodes is not None):
        if backRightLowerSpecCodes is not None: dc.Links.Add(backRightLowerSpecCodes)
        if backButtockHipContiguousSpecCodes is not None: dc.Links.Add(backButtockHipContiguousSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #9.0
    elif l89139Code is not None and backRightLowerSpecCodes is None and backButtockHipContiguousSpecCodes is None:
        dc.Links.Add(l89139Code)
        result.Subtitle = "Pressure Ulcer of Right Lower Back, with Stage Unspecified Present"
        AlertPassed = True
    #10.1
    elif subtitle == "Pressure Ulcer of Left Lower Back, with Stage Unspecified Present" and (backLeftLowerSpecCodes is not None or backButtockHipContiguousSpecCodes is not None):
        if backLeftLowerSpecCodes is not None: dc.Links.Add(backLeftLowerSpecCodes)
        if backButtockHipContiguousSpecCodes is not None: dc.Links.Add(backButtockHipContiguousSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #10.0
    elif l89149Code is not None and backLeftLowerSpecCodes is None and backButtockHipContiguousSpecCodes is None:
        dc.Links.Add(l89149Code)
        result.Subtitle = "Pressure Ulcer of Left Lower Back, with Stage Unspecified Present"
        AlertPassed = True
    #11.1
    elif subtitle == "Pressure Ulcer of Sacral Region, but Stage Unspecified Present" and (backSacralRegionSpecCodes is not None or backButtockHipContiguousSpecCodes is not None):
        if backSacralRegionSpecCodes is not None: dc.Links.Add(backSacralRegionSpecCodes)
        if backButtockHipContiguousSpecCodes is not None: dc.Links.Add(backButtockHipContiguousSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #11.0
    elif l89159Code is not None and backSacralRegionSpecCodes is None and backButtockHipContiguousSpecCodes is None:
        dc.Links.Add(l89159Code)
        result.Subtitle = "Pressure Ulcer of Sacral Region, but Stage Unspecified Present"
        AlertPassed = True
    #12.1
    elif subtitle == "Pressure Ulcer of Unspecified Hip with Stage Present" and (rightHipSpecCodes is not None or leftHipSpecCodes is not None or backButtockHipContiguousSpecCodes is not None):
        if rightHipSpecCodes is not None: dc.Links.Add(rightHipSpecCodes)
        if leftButtBackSpecCodes  is not None: dc.Links.Add(leftButtBackSpecCodes)
        if backButtockHipContiguousSpecCodes is not None: dc.Links.Add(backButtockHipContiguousSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #12.0
    elif hipSideUnSpecCodes is not None and rightHipSpecCodes is None and leftHipSpecCodes is None and backButtockHipContiguousSpecCodes is None:
        dc.Links.Add(hipSideUnSpecCodes)
        result.Subtitle = "Pressure Ulcer of Unspecified Hip with Stage Present"
        AlertPassed = True
    #13.1
    elif subtitle == "Pressure Ulcer of Unspecified Hip and Unspecified Stage Present" and (rightHipSpecCodes is not None or leftHipSpecCodes is not None or backButtockHipContiguousSpecCodes is not None):
        if rightHipSpecCodes is not None: dc.Links.Add(rightHipSpecCodes)
        if leftHipSpecCodes  is not None: dc.Links.Add(leftHipSpecCodes)
        if backButtockHipContiguousSpecCodes is not None: dc.Links.Add(backButtockHipContiguousSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #13.0
    elif l89209Code is not None and rightHipSpecCodes is None and leftHipSpecCodes is None and backButtockHipContiguousSpecCodes is None:
        dc.Links.Add(l89209Code)
        result.Subtitle = "Pressure Ulcer of Unspecified Hip and Unspecified Stage Present"
        AlertPassed = True
    #14.1
    elif subtitle == "Pressure Ulcer of Right Hip, with Stage is Unspecified Present" and (rightHipSpecCodes is not None or backButtockHipContiguousSpecCodes is not None):
        if rightHipSpecCodes is not None: dc.Links.Add(rightHipSpecCodes)
        if backButtockHipContiguousSpecCodes is not None: dc.Links.Add(backButtockHipContiguousSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #14.0
    elif l89219Code is not None and rightHipSpecCodes is None and backButtockHipContiguousSpecCodes is None:
        dc.Links.Add(l89219Code)
        result.Subtitle = "Pressure Ulcer of Right Hip, with Stage is Unspecified Present"
        AlertPassed = True
    #15.1
    elif subtitle == "Pressure Ulcer of Left Hip, with Stage is Unspecified Present" and (leftHipSpecCodes is not None or backButtockHipContiguousSpecCodes is not None):
        if leftHipSpecCodes is not None: dc.Links.Add(leftHipSpecCodes)
        if backButtockHipContiguousSpecCodes is not None: dc.Links.Add(backButtockHipContiguousSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #15.0
    elif l89229Code is not None and leftHipSpecCodes is None and backButtockHipContiguousSpecCodes is None:
        dc.Links.Add(l89229Code)
        result.Subtitle = "Pressure Ulcer of Left Hip, with Stage is Unspecified Present"
        AlertPassed = True
    #16.1
    elif subtitle == "Pressure Ulcer of Unspecified Buttock Side Present, with Stage Present" and (rightButtBackSpecCodes is not None or leftButtBackSpecCodes is not None or backButtockHipContiguousSpecCodes is not None):
        if leftButtBackSpecCodes is not None: dc.Links.Add(leftButtBackSpecCodes)
        if rightButtBackSpecCodes is not None: dc.Links.Add(rightButtBackSpecCodes)
        if backButtockHipContiguousSpecCodes is not None: dc.Links.Add(backButtockHipContiguousSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #16.0
    elif buttockSideUnSpecCodes is not None and leftButtBackSpecCodes is None and rightButtBackSpecCodes is None and backButtockHipContiguousSpecCodes is None:
        dc.Links.Add(buttockSideUnSpecCodes)
        result.Subtitle = "Pressure Ulcer of Unspecified Buttock Side Present, with Stage Present"
        AlertPassed = True
    #17.1
    elif subtitle == "Pressure Ulcer of Unspecified Buttock Side and Unspecified Stage Present" and (rightButtBackSpecCodes is not None or leftButtBackSpecCodes is not None or backButtockHipContiguousSpecCodes is not None):
        if leftButtBackSpecCodes is not None: dc.Links.Add(leftButtBackSpecCodes)
        if rightButtBackSpecCodes is not None: dc.Links.Add(rightButtBackSpecCodes)
        if backButtockHipContiguousSpecCodes is not None: dc.Links.Add(backButtockHipContiguousSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #17.0
    elif l89309Code is not None and leftButtBackSpecCodes is None and rightButtBackSpecCodes is None and backButtockHipContiguousSpecCodes is None:
        dc.Links.Add(l89309Code)
        result.Subtitle = "Pressure Ulcer of Unspecified Buttock Side and Unspecified Stage Present"
        AlertPassed = True
    #18.1
    elif subtitle == "Pressure Ulcer of Right Buttock, with Stage Unspecified Present" and (rightButtBackSpecCodes is not None or backButtockHipContiguousSpecCodes is not None):
        if rightButtBackSpecCodes is not None: dc.Links.Add(rightButtBackSpecCodes)
        if backButtockHipContiguousSpecCodes is not None: dc.Links.Add(backButtockHipContiguousSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #18.0
    elif l89319Code is not None and rightButtBackSpecCodes is None and backButtockHipContiguousSpecCodes is None:
        dc.Links.Add(l89319Code)
        result.Subtitle = "Pressure Ulcer of Right Buttock, with Stage Unspecified Present"
        AlertPassed = True
    #19.1
    elif subtitle == "Pressure Ulcer of Left Buttock, with Stage Unspecified Present" and (leftButtBackSpecCodes is not None or backButtockHipContiguousSpecCodes is not None):
        if leftButtBackSpecCodes is not None: dc.Links.Add(leftButtBackSpecCodes)
        if backButtockHipContiguousSpecCodes is not None: dc.Links.Add(backButtockHipContiguousSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #19.0
    elif l89329Code is not None and leftButtBackSpecCodes is None and backButtockHipContiguousSpecCodes is None:
        dc.Links.Add(l89329Code)
        result.Subtitle = "Pressure Ulcer of Left Buttock, with Stage Unspecified Present"
        AlertPassed = True
    #20.1
    elif subtitle == "Pressure Ulcer of Contiguous Site of Back, Buttock and Hip with Unspecified Stage Present" and backButtockHipContiguousSpecCodes is not None:
        dc.Links.Add(backButtockHipContiguousSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #20.0
    elif l8940Code is not None and backButtockHipContiguousSpecCodes is None:
        dc.Links.Add(l8940Code)
        result.Subtitle = "Pressure Ulcer of Contiguous Site of Back, Buttock and Hip with Unspecified Stage Present"
        AlertPassed = True
    #21.1
    elif subtitle == "Pressure Ulcer of Unspecified Ankle with Stage Specified Present" and (rightAnkleSpecCodes is not None or leftAnkleSpecCodes is not None):
        if rightAnkleSpecCodes is not None: dc.Links.Add(rightAnkleSpecCodes)
        if leftAnkleSpecCodes is not None: dc.Links.Add(leftAnkleSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #21.0
    elif ankleUnSpecCodes is not None and rightAnkleSpecCodes is None and leftAnkleSpecCodes is None:
        dc.Links.Add(ankleUnSpecCodes)
        result.Subtitle = "Pressure Ulcer of Unspecified Ankle with Stage Specified Present"
        AlertPassed = True
    #22.1
    elif subtitle == "Pressure Ulcer of Unspecified Ankle and Unspecified Stage Present" and (rightAnkleSpecCodes is not None or leftAnkleSpecCodes is not None):
        if rightAnkleSpecCodes is not None: dc.Links.Add(rightAnkleSpecCodes)
        if leftAnkleSpecCodes is not None: dc.Links.Add(leftAnkleSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #22.0
    elif l89509Code is not None and rightAnkleSpecCodes is None and leftAnkleSpecCodes is None:
        dc.Links.Add(l89509Code)
        result.Subtitle = "Pressure Ulcer of Unspecified Ankle and Unspecified Stage Present"
        AlertPassed = True
    #23.1
    elif subtitle == "Pressure Ulcer of Right Ankle with Unspecified Stage Present" and rightAnkleSpecCodes is not None:
        if rightAnkleSpecCodes is not None: dc.Links.Add(rightAnkleSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #23.0
    elif l89519Code is not None and rightAnkleSpecCodes is None:
        dc.Links.Add(l89519Code)
        result.Subtitle = "Pressure Ulcer of Right Ankle with Unspecified Stage Present"
        AlertPassed = True
    #24.1
    elif subtitle == "Pressure Ulcer of Left Ankle with Unspecified Stage Present" and leftAnkleSpecCodes is not None:
        if leftAnkleSpecCodes is not None: dc.Links.Add(leftAnkleSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #24.0
    elif l89529Code is not None and leftAnkleSpecCodes is None:
        dc.Links.Add(l89529Code)
        result.Subtitle = "Pressure Ulcer of Left Ankle with Unspecified Stage Present"
        AlertPassed = True
    #25.1
    elif subtitle == "Pressure Ulcer of Unspecified Heel Side with Specified Stage Present" and (rightHeelSpecCodes is not None or leftHeelSpecCodes is not None):
        if rightHeelSpecCodes is not None: dc.Links.Add(rightHeelSpecCodes)
        if leftHeelSpecCodes is not None: dc.Links.Add(leftHeelSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #25.0
    elif heelUnSpecCodes is not None and rightHeelSpecCodes is None and leftHeelSpecCodes is None:
        dc.Links.Add(heelUnSpecCodes)
        result.Subtitle = "Pressure Ulcer of Unspecified Heel Side with Specified Stage Present"
        AlertPassed = True
    #26.1
    elif subtitle == "Pressure Ulcer of Unspecified Heel Side and Unspecified Stage Present" and (rightHeelSpecCodes is not None or leftHeelSpecCodes is not None):
        if rightHeelSpecCodes is not None: dc.Links.Add(rightHeelSpecCodes)
        if leftHeelSpecCodes is not None: dc.Links.Add(leftHeelSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #26.0
    elif l89609Code is not None and rightHeelSpecCodes is None and leftHeelSpecCodes is None:
        dc.Links.Add(l89609Code)
        result.Subtitle = "Pressure Ulcer of Unspecified Heel Side and Unspecified Stage Present"
        AlertPassed = True
    #27.1
    elif subtitle == "Pressure Ulcer of Right Heel with Unspecified Stage Present" and rightHeelSpecCodes is not None:
        if rightHeelSpecCodes is not None: dc.Links.Add(rightHeelSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #27.0
    elif l89619Code is not None and rightHeelSpecCodes is None:
        dc.Links.Add(l89619Code)
        result.Subtitle = "Pressure Ulcer of Right Heel with Unspecified Stage Present"
        AlertPassed = True
    #28.1
    elif subtitle == "Pressure Ulcer of Left Heel with Unspecified Stage Present" and leftHeelSpecCodes is not None:
        if leftHeelSpecCodes is not None: dc.Links.Add(leftHeelSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #28.0
    elif l89629Code is not None and leftHeelSpecCodes is None:
        dc.Links.Add(l89629Code)
        result.Subtitle = "Pressure Ulcer of Left Heel with Unspecified Stage Present"
        AlertPassed = True
    #29.1
    elif subtitle == "Pressure Ulcer of Head with Unspecified Stage Present" and headSpecCodes is not None:
        dc.Links.Add(headSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #29.0
    elif l89819Code is not None and headSpecCodes is None:
        dc.Links.Add(l89819Code)
        result.Subtitle = "Pressure Ulcer of Head with Unspecified Stage Present"
        AlertPassed = True
    #30.1
    elif subtitle == "Pressure Ulcer of Other Site with Unspecified Stage Present" and otherSiteSpecCodes is not None:
        dc.Links.Add(otherSiteSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #30.0
    elif l89899Code is not None and otherSiteSpecCodes is None:
        dc.Links.Add(l89899Code)
        result.Subtitle = "Pressure Ulcer of Other Site with Unspecified Stage Present"
        AlertPassed = True
    #31.1
    elif subtitle == "Pressure Ulcer of Unspecified Site and Unspecified Stage Present" and unspecSiteFullSpecCodes is not None:
        dc.Links.Add(unspecSiteFullSpecCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #31.0
    elif l8990Code is not None and unspecSiteFullSpecCodes is None:
        dc.Links.Add(l8990Code)
        result.Subtitle = "Pressure Ulcer of Unspecified Site and Unspecified Stage Present"
        AlertPassed = True
    #32.1
    elif subtitle == "Possible Pressure Ulcer" and stage34PUCodes is not None:
        dc.Links.Add(stage34PUCodes)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #32.0
    elif stage34PUCodes is None and pressureInjuryStageDV is not None:
        if pressureInjuryStageDV is not None: abs.Links.Add(pressureInjuryStageDV) #3
        result.Subtitle = "Possible Pressure Ulcer"
        AlertPassed = True
    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False
else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Documented Dx
    abstractValue("PRESSURE_ULCER_POA_STATUS", "Pressure Ulcer POA Status: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0, dc, True)
    #Abs
    dvValue(dvBradenRiskAssessmentScore, "Braden Risk Assessment Score: [VALUE] (Result Date: [RESULTDATETIME])", calcBradenRiskAssessmentScore1, 1, abs, True)
    abstractValue("BRADEN_RISK_ASSESSMENT_SCORE", "Braden Risk Assessment Score: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2, abs, True)
    #Doc Links
    documentLink("Wound Care Progress Note", "Wound Care Progress Note", 0, woundCareLinks, True)
    documentLink("Wound Care RN Initial Consult", "Wound Care RN Initial Consult", 0, woundCareLinks, True)
    documentLink("Wound Care RN Follow Up", "Wound Care RN Follow Up", 0, woundCareLinks, True)
    documentLink("Wound Care History and Physical", "Wound Care History and Physical", 0, woundCareLinks, True)
    documentLink("Wound Ostomy Team Initial Consult Note", "Wound Ostomy Team Initial Consult Note", 0, woundCareLinks, True)

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if woundCareLinks.Links: result.Links.Add(woundCareLinks); docLinklinks = True
    result.Links.Add(treatment)
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Documented Dx- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", DocLinks- " + str(docLinklinks) +"; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
