##################################################################################################################
#Evaluation Script - Heart Failure
#
#This script checks an account to see if it matches criteria to be alerted for Heart Failure
#Date - 10/23/2024
#Version - V19
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
    "I50.21": "Acute Systolic (Congestive) Heart Failure",
    "I50.22": "Chronic Systolic (Congestive) Heart Failure",
    "I50.23": "Acute on Chronic Systolic (Congestive) Heart Failure",
    "I50.31": "Acute Diastolic (Congestive) Heart Failure",
    "I50.32": "Chronic Diastolic (Congestive) Heart Failure",
    "I50.33": "Acute on Chronic Diastolic (Congestive) Heart Failure",
    "I50.41": "Acute Combined Systolic (Congestive) and Diastolic (Congestive) Heart Failure",
    "I50.42": "Chronic Combined Systolic (Congestive) and Diastolic (Congestive) Heart Failure",
    "I50.43": "Acute on Chronic Combined Systolic (Congestive) and Diastolic (Congestive) Heart Failure",
    "I50.811": "Acute Right Heart Failure",
    "I50.812": "Chronic Right Heart Failure",
    "I50.813": "Acute on Chronic Right Heart Failure",
    "I50.814": "Right Heart Failure due to Left Heart Failure",
    "I50.82": "Biventricular Heart Failure",
    "I50.83": "High Output Heart Failure",
    "I50.84": "End Stage Heart Failure"
}
autoEvidenceText = "Autoresolved Evidence - "
autoCodeText = "Autoresolved Code - "

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
dvProBNP = ["BNP(NT proBNP) (pg/mL)"]
calcProBNP1 = lambda x: x > 900
dvCentralVenousPressure = ["CVP cc"]
calcCentralVenousPressure1 = lambda x: x > 16
dvHeartRate = ["Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)", "3.5 Heart Rate (Radial) (bpm)",  "SCC Monitor Pulse (bpm)"]
calcHeartRate1 = lambda x: x > 120
dvTroponinT = ["TROPONIN, HIGH SENSITIVITY (ng/L)"]
calcTroponinT1 = lambda x: x > 59

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
def ivMedValue(medDic, med_name, link_text, sequence=0, category=None, abstract=False):
    for mv in medDic or []:
        if (
            medDic[mv]['Route'] is not None and
            medDic[mv]['Category'] == med_name and
            (re.search(r'\bIntravenous\b', medDic[mv]['Route'], re.IGNORECASE) or
            re.search(r'\bIV Push\b', medDic[mv]['Route'], re.IGNORECASE))
        ):
            if abstract == True:
                medDataConversion(medDic[mv]['StartDate'], link_text, medDic[mv]['Medication'], medDic[mv]['ExternalId'], medDic[mv]['Dosage'], medDic[mv]['Route'], category, sequence)
                return True
            elif abstract == False:
                abstraction = medDataConversion(medDic[mv]['StartDate'], link_text, medDic[mv]['Medication'], medDic[mv]['ExternalId'], medDic[mv]['Dosage'], medDic[mv]['Route'], category, sequence, abstract)
                return abstraction
    return None

def anesthesiaMedValue(medDic, med_name, link_text, sequence=0, category=None, abstract=False):
    for mv in medDic or []:
        if (
            medDic[mv]['Route'] is not None and
            medDic[mv]['Dosage'] is not None and
            medDic[mv]['Category'] == med_name and
            (re.search(r'\bhr\b', medDic[mv]['Dosage'], re.IGNORECASE) or
            re.search(r'\bhour\b', medDic[mv]['Dosage'], re.IGNORECASE) or 
            re.search(r'\bmin\b', medDic[mv]['Dosage'], re.IGNORECASE) or
            re.search(r'\bminute\b', medDic[mv]['Dosage'], re.IGNORECASE)) and
            (re.search(r'\bIntravenous\b', medDic[mv]['Route'], re.IGNORECASE) or
            re.search(r'\bIV Push\b', medDic[mv]['Route'], re.IGNORECASE))
        ):
            if abstract == True:
                medDataConversion(medDic[mv]['StartDate'], link_text, medDic[mv]['Medication'], medDic[mv]['ExternalId'], medDic[mv]['Dosage'], medDic[mv]['Route'], category, sequence)
                return True
            elif abstract == False:
                abstraction = medDataConversion(medDic[mv]['StartDate'], link_text, medDic[mv]['Medication'], medDic[mv]['ExternalId'], medDic[mv]['Dosage'], medDic[mv]['Route'], category, sequence, abstract)
                return abstraction
    return None

def medDataConversion(datetime, linkText, med, id, dosage, route, category, sequence, abstract=True):
    date_time = datetimeFromUtcToLocal(datetime)
    date_time = date_time.ToString("MM/dd/yyyy, HH:mm")
    linkText = linkText.replace("[STARTDATE]", date_time)
    linkText = linkText.replace("[MEDICATION]", med)
    linkText = linkText.replace("[DOSAGE]", dosage)
    if route is not None: linkText = linkText.replace("[ROUTE]", route)
    else: linkText = linkText.replace(", Route [ROUTE]", "")
    if abstract == True:
        abstraction = MatchedCriteriaLink(linkText, None, None, None, True, None, None, sequence)
        abstraction.MedicationId = id
        category.Links.Add(abstraction)
    elif abstract == False:
        abstraction = MatchedCriteriaLink(linkText, None, None, None, True, None, None, sequence)
        abstraction.MedicationId = id
        return abstraction
    return

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
triggerAlert = True
reason = None
dcLinks = False
absLinks = False
labsLinks = False
vitalsLinks = False
medsLinks = False
docLinksLinks = False
framinghamMajorLinks = False
framinghamMinorLinks = False
framinghamLinks = False
ASC = 0
TSC = 0
CCC = False
CCCTwo = False

#Initalize categories
dc = MatchedCriteriaLink("Document Code", None, "Document Code", None, True, None, None, 1)
framingham = MatchedCriteriaLink("Framingham Criteria:", None, "Framingham Major Criteria", None, True, None, None, 2)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 3)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 4)
vitals = MatchedCriteriaLink("Vital Signs/Intake and Output Data", None, "Vital Signs/Intake and Output Data", None, True, None, None, 5)
meds = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 6)
echoLinks = MatchedCriteriaLink("Echo", None, "Echo", None, True, None, None, 7)
ctChestLinks = MatchedCriteriaLink("CT Chest", None, "CT Chest", None, True, None, None, 7)
ekgLinks = MatchedCriteriaLink("EKG", None, "EKG", None, True, None, None, 7)
heartCathLinks = MatchedCriteriaLink("Heart Cath", None, "Heart Cath", None, True, None, None, 7)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 8)
framinghamMajor = MatchedCriteriaLink("Major:", None, "Framingham Major Criteria", None, True, None, None, 1)
framinghamMinor = MatchedCriteriaLink("Minor:", None, "Framingham Minor Criteria", None, True, None, None, 2)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Heart Failure':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        subtitle = alert.Subtitle
        reason = alert.Reason
        if outcome == 'AUTORESOLVED' or reason == 'Previously Autoresolved':
            triggerAlert = False
        break

#Check if alert was autoresolved or completed.
if (
    validated is False or
    (outcome == "AUTORESOLVED" and validated and codesExist > 1)
):
    #Get meds within last X days
    mainMedDic = {}
    unsortedMedDic = {}
    medCount = 0
    #Combine all items into one list to search against
    medSearchList = ["Beta Blocker", "Bumetanide", "Calcium Channel Blockers", "Furosemide", "Epinephrine", "Levophed", "Vasopressin", "Neosynephrine"]
    #Set datelimit for how far back to 
    medDateLimit = System.DateTime.Now.AddDays(-7)
    #Loop through all meds finding any that match in the combined list adding to a dictionary the matches
    if 'Medications' in account:    
        for med in account.Medications:
            if med.StartDate >= medDateLimit and 'Category' in med and med.Category is not None:
                if any(item == med.Category for item in medSearchList):
                    medCount += 1
                    unsortedMedDic[medCount] = med
    #Sort List by latest
    mainMedDic = sorted(unsortedMedDic.items(), key=lambda x: x[1]['StartDate'], reverse=True)
    
    #Negations
    hfCodes = multiCodeValue(["I50.1", "I50.20", "I50.30", "I50.40", "I50.810", "I50.9", "I50.21", "I50.22", "I50.23", "I50.31",
        "I50.32", "I50.33", "I50.41", "I50.42", "I50.43", "I50.811", "I50.812", "I50.813", "I50.814", "I50.82", "I50.83", "I50.84"],
        "Heart Failure Dx Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #AlertTrigger
    acuteHeartFailureAbs = abstractValue("ACUTE_HEART_FAILURE","Acute Heart Failure '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    chronicHeartFailureAbs = abstractValue("CHRONIC_HEART_FAILURE","Chronic Heart Failure '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    acuteChronicHeartFailureAbs = abstractValue("ACUTE_ON_CHRONIC_HEART_FAILURE","Acute on Chronic Heart Failure '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    i509Code = codeValue("I50.9", "Heart Failure, Unspecified Dx '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i5020Code = codeValue("I50.20", "Systolic Heart Failure Dx '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i5030Code = codeValue("I50.30", "Diastolic Heart Failure Dx '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i5040Code = codeValue("I50.40", "Systolic And Diastolic Heart Failure Dx '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i501Code = codeValue("I50.1", "Left Ventricle Heart Failure Dx '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i50810Code = codeValue("I50.810", "Right Heart Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    nyhaFuncClassificationAbs = abstractValue("NYHA_FUNCTIONAL_CLASSIFICATION","NYHA Functional Classification '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    i5021Code = codeValue("I50.21", "Acute Systolic (Congestive): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i5022Code = codeValue("I50.22", "Chronic Systolic (Congestive): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i5023Code = codeValue("I50.23", "Acute on Chronic Systolic Heart Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i5031Code = codeValue("I50.31", "Acute Diastolic (Congestive): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i5032Code = codeValue("I50.32", "Chronic Diastolic (Congestive): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i5033Code = codeValue("I50.33", "Acute on Chronic Diastolic Heart Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i5041Code = codeValue("I50.41", "Acute Combined Systolic and Diastolic (Congestive): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i5042Code = codeValue("I50.42", "Chronic Combined Systolic and Diastolic (Congestive): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i5043Code = codeValue("I50.43", "Acute on Chronic Combined Systolic and Distolic Heart Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i50811Code = codeValue("I50.811", "Acute Right Heart Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i50812Code = codeValue("I50.812", "Chronic Right Heart Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i50813Code = codeValue("I50.813", "Acute on Chronic Right Heart Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Abs
    r601Code = codeValue("R60.1", "Anasarca: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    centralVenousCongestionAbs = abstractValue("CENTRAL_VENOUS_CONGESTION", "Central Venous Congestion '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7)
    cracklesAbs = abstractValue("CRACKLES", "Crackles '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8)
    diastolicDysfunAbs = abstractValue("DIASTOLIC_DYSFUNCTION", "Diastolic Dysfunction '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9)
    moderREFAbs = abstractValue("MODERATELY_REDUCED_EJECTION_FRACTION", "Ejection Fraction: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10)
    reducEFAbs = abstractValue("REDUCED_EJECTION_FRACTION", "Ejection Fraction: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11)
    e8770Code = codeValue("E87.70", "Fluid Overloaded: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17)
    leftVentricleDilationAbs = abstractValue("LEFT_VENTRICLE_DILATION", "Left Ventricle Dilation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 25)
    leftVentricleHyperAbs = abstractValue("LEFT_VENTRICLE_HYPERTROPHY", "Left Ventricle Hypertrophy '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 26)
    pulmonaryEdemaAbs = abstractValue("PULMONARY_EDEMA", "Pulmonary Edema '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 31)
    sobLyingFlatAbs = abstractValue("SHORTNESS_OF_BREATH_LYING_FLAT", "Shortness of Breath Lying Flat '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 42)
    systolicDysfunctionAbs = abstractValue("SYSTOLIC_DYSFUNCTION","Systolic Dysfunction '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 44)
    #Labs
    proBNPDV = dvValue(dvProBNP, "Pro BNP: [VALUE] (Result Date: [RESULTDATETIME])", calcProBNP1, 1)
    #Meds
    bumetanideMed = ivMedValue(dict(mainMedDic), "Bumetanide", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 11)
    furosemideMed = ivMedValue(dict(mainMedDic), "Furosemide", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 21)
    #Major
    j810Code = codeValue("J81.0", "Acute Pulmonary Edema: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    elvatCentralVenousPressAbs = abstractValue("ELEVATED_CENTRAL_VENOUS_PRESSURE", "Central Venous Pressure: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4)
    hepatojugularRefluxAbs = abstractValue("HEPATOJUGULAR_REFLUX", "Hepatojugular Reflux '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5)
    jugularVeinDistentionAbs = abstractValue("JUGULAR_VEIN_DISTENTION", "Jugular Vein Distention '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6)
    s3HeartSoundAbs = abstractValue("S3_HEART_SOUND", "S3 Heart Sound '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9)
    #Minor
    dyspneaOnExertionAbs = abstractValue("DYSPNEA_ON_EXERTION", "Dyspnea on Exertion '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1)
    heartRateDV = dvValue(dvHeartRate, "Heart Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcHeartRate1, 2)
    hepatomegalyAbs = abstractValue("HEPATOMEGALY", "Hepatomegaly '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3)
    lowerExtremityEdemaAbs = abstractValue("LOWER_EXTREMITY_EDEMA", "Lower Extremity Edema '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4)
    nocturnalCoughAbs = abstractValue("NOCTURNAL_COUGH", "Nocturnal Cough '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5)
    pleuralEffusionAbs = abstractValue("PLEURAL_EFFUSION", "Pleural Effusion '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6)

    #Conflicting Code Checks
    if i5021Code is not None and i5022Code is not None and i5023Code is not None:
        CCC = True
    if i5031Code is not None and i5032Code is not None and i5033Code is not None:
        CCC = True
    if i5041Code is not None and i5042Code is not None and i5043Code is not None:
        CCC = True
    if i50811Code is not None and i50812Code is not None and i50813Code is not None:
        CCC = True
    if codesExist == 2 and i5021Code is not None and i5023Code is not None:
        CCCTwo = True
    if codesExist == 2 and i5022Code is not None and i5023Code is not None:
        CCCTwo = True
    if codesExist == 2 and i5031Code is not None and i5033Code is not None:
        CCCTwo = True
    if codesExist == 2 and i5032Code is not None and i5033Code is not None:
        CCCTwo = True
    #Acuity Sign Count
    if r601Code is not None: ASC += 1
    if centralVenousCongestionAbs is not None: ASC += 1
    if cracklesAbs is not None: ASC += 1
    if e8770Code is not None: ASC += 1
    if pulmonaryEdemaAbs is not None: ASC += 1
    if sobLyingFlatAbs is not None: ASC += 1
    if proBNPDV is not None: ASC += 1
    if j810Code is not None: ASC += 1
    if elvatCentralVenousPressAbs is not None: ASC += 1
    if hepatojugularRefluxAbs is not None: ASC += 1
    if jugularVeinDistentionAbs is not None: ASC += 1
    if s3HeartSoundAbs is not None: ASC += 1
    if dyspneaOnExertionAbs is not None: ASC += 1
    if heartRateDV is not None: ASC += 1
    if hepatomegalyAbs is not None: ASC += 1
    if lowerExtremityEdemaAbs is not None: ASC += 1
    if nocturnalCoughAbs is not None: ASC += 1
    if pleuralEffusionAbs is not None: ASC += 1
    if bumetanideMed is not None: meds.Links.Add(bumetanideMed); ASC += 1
    if furosemideMed is not None: meds.Links.Add(furosemideMed); ASC += 1

    #Type Sign Count
    if diastolicDysfunAbs is not None: TSC += 1
    if moderREFAbs is not None: TSC += 1
    if reducEFAbs is not None: TSC += 1
    if leftVentricleDilationAbs is not None: TSC += 1
    if systolicDysfunctionAbs is not None: TSC += 1
    if leftVentricleHyperAbs is not None: TSC += 1
        
    #Starting Main Algorithm
    #1
    if codesExist == 1:
        db.LogEvaluationScriptMessage("One specific code was on the chart, alert failed" + str(account._id), scriptName, scriptInstance, "Debug")
        if alertTriggered:
            for code in codeList:
                desc = codeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code  - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    dc.Links.Add(tempCode)
                    break
            result.Outcome = "AUTORESOLVED"
            result.Reason = "Autoresolved due to one Specified Code on the Account"
            result.Validated = True
            AlertConditions = True
        else: result.Passed = False
    #1
    elif codesExist > 1 and i5021Code is not None and i5022Code is not None and i5023Code is None:
        dc.Links.Add(i5021Code)
        dc.Links.Add(i5022Code)
        result.Subtitle = "Possible Acute on Chronic Systolic Heart Failure"
        AlertPassed = True
        if validated:
            result.Validated = False
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"
    #2
    elif codesExist > 1 and i5031Code is not None and i5032Code is not None and i5033Code is None:
        dc.Links.Add(i5031Code)
        dc.Links.Add(i5032Code)
        result.Subtitle = "Possible Acute on Chronic Diastolic Heart Failure"
        AlertPassed = True
        if validated:
            result.Validated = False
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"          
    #3
    elif codesExist > 1 and i5041Code is not None and i5042Code is not None and i5043Code is None:
        dc.Links.Add(i5041Code)
        dc.Links.Add(i5042Code)
        result.Subtitle = "Possible Acute on Chronic Combined Systolic and Diastolic Heart Failure"
        AlertPassed = True
        if validated:
            result.Validated = False
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"
    #4
    elif codesExist > 1 and i50811Code is not None and i50812Code is not None and i50813Code is None:
        dc.Links.Add(i50811Code)
        dc.Links.Add(i50812Code)
        result.Subtitle = "Possible Acute on Chronic Right Heart Failure"
        AlertPassed = True
        if validated:
            result.Validated = False
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"
    #5.1
    elif subtitle == "Conflicting Heart Failure Types" and (i5041Code is not None or i5042Code is not None or i5043Code is not None):
        if i5041Code is not None: dc.Links.Add(i5041Code)
        if i5042Code is not None: dc.Links.Add(i5042Code)
        if i5043Code is not None: dc.Links.Add(i5043Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #5
    elif (
        codesExist >= 4 or
        (codesExist == 3 and CCC == False) or
        (codesExist == 2 and CCCTwo == False) and
        i5041Code is None and
        i5042Code is None and
        i5043Code is None
    ):
        for code in codeList:
            desc = codeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, desc +": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            dc.Links.Add(tempCode)
        result.Subtitle = "Conflicting Heart Failure Types"
        if validated:
            result.Validated = False
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"
        AlertPassed = True   
    #6-15.1           
    elif codesExist > 0:
        if alertTriggered:
            for code in codeList:
                desc = codeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code  - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    dc.Links.Add(tempCode)
                    break
            result.Outcome = "AUTORESOLVED"
            result.Reason = "Autoresolved due to one Specified Code on the Account"
            result.Validated = True
            AlertConditions = True
        else: result.Passed = False
    #6
    elif triggerAlert and acuteHeartFailureAbs is not None and TSC > 0:
        dc.Links.Add(acuteHeartFailureAbs)
        result.Subtitle = "Acute Heart Failure Dx Missing Type"
        AlertPassed = True
    #7
    elif triggerAlert and chronicHeartFailureAbs is not None and TSC > 0:
        dc.Links.Add(chronicHeartFailureAbs)
        result.Subtitle = "Chronic Heart Failure Dx Missing Type"
        AlertPassed = True
    #8
    elif triggerAlert and acuteChronicHeartFailureAbs is not None and TSC > 0:
        dc.Links.Add(acuteChronicHeartFailureAbs)
        result.Subtitle = "Acute on Chronic Heart Failure Dx Missing Type"
        AlertPassed = True
    #9
    elif triggerAlert and i509Code is not None and (TSC > 0 or ASC > 0):
        dc.Links.Add(i509Code)
        result.Subtitle = "Heart Failure Dx Missing Type and Acuity"
        AlertPassed = True
    #10
    elif triggerAlert and i5020Code is not None and ASC > 0:
        dc.Links.Add(i5020Code)
        result.Subtitle = "Systolic Heart Failure Missing Acuity"
        AlertPassed = True
    #11
    elif triggerAlert and i5030Code is not None and ASC > 0:
        dc.Links.Add(i5030Code)
        result.Subtitle = "Diastolic Heart Failure Missing Acuity"
        AlertPassed = True
    #12
    elif triggerAlert and i5040Code is not None and ASC > 0:
        dc.Links.Add(i5040Code)
        result.Subtitle = "Combined Systolic and Diastolic Heart Failure with Missing Acuity"
        AlertPassed = True
    #13
    elif triggerAlert and i50810Code is not None and ASC > 0:
        dc.Links.Add(i50810Code)
        result.Subtitle = "Right Heart Failure with Missing Acuity"
        AlertPassed = True
    #14
    elif triggerAlert and i501Code is not None and (ASC > 0 or TSC > 0):
        dc.Links.Add(i501Code)
        result.Subtitle = "Left Ventricle Heart Failure Missing Type and Acuity"
        AlertPassed = True
    #15
    elif triggerAlert and hfCodes is None and (TSC >= 3 or ASC >= 3 or (TSC >= 1 and ASC >= 2) or (TSC >= 2 and ASC >= 1)) or nyhaFuncClassificationAbs is not None:
        if nyhaFuncClassificationAbs is not None: dc.Links.Add(nyhaFuncClassificationAbs)
        result.Subtitle = "Possible Heart Failure Dx"
        AlertPassed = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Abs
    codeValue("R63.5", "Abnormal Weight Gain: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, abs, True)
    if r601Code is not None: abs.Links.Add(r601Code) #2
    abstractValue("ASCITES", "Ascites '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3, abs, True)
    multiCodeValue(["I48.0", "I48.11", "I48.19", "I48.20", "I48.21", "I48.91"],
                      "Atrial Fibrillation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, abs, True)
    codeValue("I31.4", "Cardiac Tamponade: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, abs, True)
    multiCodeValue(["I25.5", "O90.3", "I42.0", "I42.1", "I42.2", "I42.3", "I42.4", "I42.5", "I42.6", "I42.7", "I42.8", "I51.81"],
                      "Cardiomyopathy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, abs, True)
    if centralVenousCongestionAbs is not None: abs.Links.Add(centralVenousCongestionAbs) #7
    if cracklesAbs is not None: abs.Links.Add(cracklesAbs) #8
    if diastolicDysfunAbs is not None: abs.Links.Add(diastolicDysfunAbs) #9
    if moderREFAbs is not None: abs.Links.Add(moderREFAbs) #10
    if reducEFAbs is not None: abs.Links.Add(reducEFAbs) #11
    abstractValue("PRESERVED_EJECTION_FRACTION_2", "Ejection Fraction: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12, abs, True)
    abstractValue("PRESERVED_EJECTION_FRACTION", "Ejection Fraction: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13, abs, True)
    codeValue("N18.6", "End-Stage Renal Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, abs, True)
    codeValue("I38", "Endocarditis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
    codeValue("R53.83", "Fatigue: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, abs, True)
    if e8770Code is not None: abs.Links.Add(e8770Code) #17
    abstractValue("HEART_PALPITATIONS", "Heart Palpitations '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 18, abs, True)
    codeValue("I31.2", "Hemopericardium: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19, abs, True)
    abstractValue("HYPERDYNAMIC_LEFT_VENTRICLE_SYSTOLIC_FUNCTION", "Hyperdynamic Left Ventricular Systolic Function '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 20, abs, True)
    abstractValue("IMPLANTABLE_CARDIAC_ASSIST_DEVICE", "Implantable Cardiac Assist Device '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 21, abs, True)
    multiCodeValue(["02HA3QZ", "02HA0QZ"], "Implantable Heart Assist Device '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 22, abs, True)
    abstractValue("IRREGULAR_ECHO_FINDING", "Irregular Echo Findings '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 23, abs, True)
    abstractValue("IRREGULAR_RADIOLOGY_REPORT_CARDIAC", "Irregular Radiology Report Cardiac '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 24, abs, True)
    if leftVentricleDilationAbs is not None: abs.Links.Add(leftVentricleDilationAbs) #25
    if leftVentricleHyperAbs is not None: abs.Links.Add(leftVentricleHyperAbs) #26
    abstractValue("NYHA_FUNCTIONAL_CLASSIFICATION", "NYHA Functional Classification '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 27, abs, True)
    codeValue("I51.2", "Papillary Muscle Rupture: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 28, abs, True)
    abstractValue("PERICARDIAL_EFFUSION", "Pericardial Effusion '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 29, abs, True)
    codeValue("I27.20", "Pulmonary Hypertension: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 30, abs, True)
    if pulmonaryEdemaAbs is not None: abs.Links.Add(pulmonaryEdemaAbs) #31
    abstractValue("RIGHT_VENTRICLE_HYPERTROPHY", "Right Ventricle Hypertrophy '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 32, abs, True)
    abstractValue("SEVERE_AORTIC_VALVE_STENOSIS", "Severe Aortic Stenosis '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 33, abs, True)
    abstractValue("SEVERE_AORTIC_VALVE_REGURGITATION", "Severe Aortic Regurgitation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 34, abs, True)
    abstractValue("SEVERE_MITRAL_VALVE_STENOSIS", "Severe Mitral Stenosis '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 35, abs, True)
    abstractValue("SEVERE_MITRAL_VALVE_REGURGITATION", "Severe Mitral Regurgitation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 36, abs, True)
    abstractValue("SEVERE_PULMONIC_VALVE_STENOSIS", "Severe Pulmonic Stenosis '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 37, abs, True)
    abstractValue("SEVERE_PULMONIC_VALVE_REGURGITATION", "Severe Pulmonic Regurgitation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 38, abs, True)
    abstractValue("SEVERE_TRICUSPID_VALVE_STENOSIS", "Severe Tricuspid Stenosis '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 39, abs, True)
    abstractValue("SEVERE_TRICUSPID_VALVE_REGURGITATION", "Severe Tricuspid Regurgitation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 40, abs, True)
    if sobLyingFlatAbs is not None: abs.Links.Add(sobLyingFlatAbs) #42
    multiCodeValue(["02HA0RJ", "02HA0RS", "02HA0RZ", "02HA3RJ", "02HA3RS", "02HA3RZ", "02HA4QZ", "02HA4RJ", "02HA4RS", "02HA4RZ"],
                      "Short-Term External Heart Assist Device '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 43, abs, True)
    if systolicDysfunctionAbs is not None: abs.Links.Add(systolicDysfunctionAbs) #44
    abstractValue("TRUNCATIONS_OF_TITIN_CARDIOMYOPATHY", "Truncations Of Titin Cardiomyopathy '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 45, abs, True)
    #Document Links
    documentLink("ECG", "ECG", 0, ekgLinks, True)
    documentLink("Electrocardiogram Adult   ECGR", "Electrocardiogram Adult   ECGR", 0, ekgLinks, True)
    documentLink("ECG Adult", "ECG Adult", 0, ekgLinks, True)
    documentLink("RestingECG", "RestingECG", 0, ekgLinks, True)
    documentLink("EKG", "EKG", 0, ekgLinks, True)
    documentLink("ECHOTE  CVSECHOTE", "ECHOTE  CVSECHOTE", 0, echoLinks, True)
    documentLink("ECHO 2D Comp Adult CVSECH2DECHO", "ECHO 2D Comp Adult CVSECH2DECHO", 0, echoLinks, True)
    documentLink("Echo Complete Adult 2D", "Echo Complete Adult 2D", 0, echoLinks, True)
    documentLink("Echo Comp W or WO Contrast", "Echo Comp W or WO Contrast", 0, echoLinks, True)
    documentLink("ECHO Stress ECHO  CVSECHSTR", "ECHO Stress ECHO  CVSECHSTR", 0, echoLinks, True)
    documentLink("Stress Echocardiogram CVS", "Stress Echocardiogram CVS", 0, echoLinks, True)
    documentLink("CVSECH2DECHO", "CVSECH2DECHO", 0, echoLinks, True)
    documentLink("CVSECHOTE", "CVSECHOTE", 0, echoLinks, True)
    documentLink("CVSECHORECHO", "CVSECHORECHO", 0, echoLinks, True)
    documentLink("CVSECH2DECHOLIMITED", "CVSECH2DECHOLIMITED", 0, echoLinks, True)
    documentLink("CVSECHOPC", "CVSECHOPC", 0, echoLinks, True)
    documentLink("CVSECHSTRAINECHO", "CVSECHSTRAINECHO", 0, echoLinks, True)
    documentLink("Heart Cath", "Heart Cath", 0, heartCathLinks, True)
    documentLink("Cath Report", "Cath Report", 0, heartCathLinks, True)
    documentLink("Cardiac Cath, PTCA, EP findings", "Cardiac Cath, PTCA, EP findings", 0, heartCathLinks, True)
    documentLink("CATHEOC", "CATHEOC", 0, heartCathLinks, True)
    documentLink("Cath Lab Procedures", "Cath Lab Procedures", 0, heartCathLinks, True)
    #Labs
    if proBNPDV is not None: labs.Links.Add(proBNPDV) #1
    dvValue(dvTroponinT, "Troponin T High Sensitivity: [VALUE] (Result Date: [RESULTDATETIME])", calcTroponinT1, 2, labs, True)
    #Meds
    medValue("Ace Inhibitor", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, meds, True)
    abstractValue("ACE_INHIBITORS", "Ace Inhibitor '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2, meds, True)
    medValue("Angiotensin II Receptor Blocker", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 3, meds, True)
    abstractValue("ANGIOTENSIN_II_RECEPTOR_BLOCKERS", "Angiotensin II Receptor Blockers '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4, meds, True)
    medValue("Angiotensin Receptor Neprilysin Inhibitor", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 5, meds, True)
    abstractValue("ANGIOTENSIN_RECEPTOR_NEPRILYSIN_INHIBITORS", "Angiotensin Receptor Neprilysin Inhibitors '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6, meds, True)
    medValue("Antianginal Medication", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 7, meds, True)
    abstractValue("ANTIANGINAL_MEDICATION", "Antianginal Medication '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, meds, True)
    ivMedValue(dict(mainMedDic), "Beta Blocker", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 9, meds, True)
    abstractValue("BETA_BLOCKER", "Beta Blocker '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10, meds, True)
    #11
    abstractValue("BUMETANIDE", "Bumetanide '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12, meds, True)
    ivMedValue(dict(mainMedDic), "Calcium Channel Blockers", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 13, meds, True)
    abstractValue("CALCIUM_CHANNEL_BLOCKER", "Calcium Channel Blocker '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 14, meds, True)
    medValue("Digitalis", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 15, meds, True)
    abstractValue("DIGOXIN", "Digoxin '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 16, meds, True)
    medValue("Diuretic", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 17, meds, True)
    abstractValue("DIURETIC", "Diuretic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 18, meds, True)
    anesthesiaMedValue(dict(mainMedDic), "Epinephrine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 19, meds, True)
    abstractValue("EPINEPHRINE", "Epinephrine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 20, meds, True)
    #21
    abstractValue("FUROSEMIDE", "Furosemide '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 22, meds, True)
    medValue("Hydralazine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 23, meds, True)
    abstractValue("HYDRALAZINE_ISOSORBIDE_AND_DINITRATE", "Hydralazine Isosorbide and Dinitrate '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 24, meds, True)
    anesthesiaMedValue(dict(mainMedDic), "Levophed", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 25, meds, True)
    abstractValue("LEVOPHED", "Levophed '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 26, meds, True)
    medValue("Milrinone", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 27, meds, True)
    abstractValue("MILRINONE", "Milrinone '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 28, meds, True)
    anesthesiaMedValue(dict(mainMedDic), "Neosynephrine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 29, meds, True)
    abstractValue("NEOSYNEPHRINE", "Neosynephrine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 30, meds, True)
    medValue("Nitroglycerin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 31, meds, True)
    abstractValue("NITROGLYCERIN", "Nitroglycerin '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 32, meds, True)
    medValue("Sodium Nitroprusside", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 33, meds, True)
    abstractValue("SODIUM_NITROPRUSSIDE", "Sodium Nitroprusside '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 34, meds, True)
    abstractValue("VASOACTIVE_MEDICATION", "Vasoactive Medication '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 35, meds, True)
    anesthesiaMedValue(dict(mainMedDic), "Vasopressin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 36, meds, True)
    abstractValue("VASOPRESSIN", "Vasopressin '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 37, meds, True)
    #Vitals
    abstractValue("ELEVATED_RIGHT_VENTRICLE_SYSTOLIC_PRESSURE", "Right Ventricle Systolic Pressure: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1, vitals, True)
    #Framingham Major Criteria
    if j810Code is not None: framinghamMajor.Links.Add(j810Code) #1
    codeValue("I51.7", "Cardiomegaly: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, framinghamMajor, True)
    dvValue(dvCentralVenousPressure, "Elevated Central Venous Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcCentralVenousPressure1, 3, framinghamMajor, True)
    if elvatCentralVenousPressAbs is not None: framinghamMajor.Links.Add(elvatCentralVenousPressAbs) #4
    if hepatojugularRefluxAbs is not None: framinghamMajor.Links.Add(hepatojugularRefluxAbs) #5
    if jugularVeinDistentionAbs is not None: framinghamMajor.Links.Add(jugularVeinDistentionAbs) #6
    abstractValue("PAROXYSMAL_NOCTURNAL_DYSPNEA", "Paroxysmal Nocturnal Dyspnea ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7, framinghamMajor, True)
    abstractValue("RALES", "Rales '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, framinghamMajor, True)
    if s3HeartSoundAbs is not None: framinghamMajor.Links.Add(s3HeartSoundAbs) #9
    #Framingham Minor Criteria
    if dyspneaOnExertionAbs is not None: framinghamMinor.Links.Add(dyspneaOnExertionAbs) #1
    if heartRateDV is not None: framinghamMinor.Links.Add(heartRateDV) #2
    if hepatomegalyAbs is not None: framinghamMinor.Links.Add(hepatomegalyAbs) #3
    if lowerExtremityEdemaAbs is not None: framinghamMinor.Links.Add(lowerExtremityEdemaAbs) #4
    if nocturnalCoughAbs is not None: framinghamMinor.Links.Add(nocturnalCoughAbs) #5
    if pleuralEffusionAbs is not None: framinghamMinor.Links.Add(pleuralEffusionAbs) #6

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    if vitals.Links: result.Links.Add(vitals); vitalsLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    if echoLinks.Links: result.Links.Add(echoLinks); docLinksLinks = True
    if ctChestLinks.Links: result.Links.Add(ctChestLinks); docLinksLinks = True
    if ekgLinks.Links: result.Links.Add(ekgLinks); docLinksLinks = True
    if heartCathLinks.Links: result.Links.Add(heartCathLinks); docLinksLinks = True
    if framinghamMajor.Links: framingham.Links.Add(framinghamMajor); framinghamMajorLinks = True
    if framinghamMinor.Links: framingham.Links.Add(framinghamMinor); framinghamMinorLinks = True
    if framingham.Links: result.Links.Add(framingham); framinghamLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Document Code- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks) + ", vitals- " + str(vitalsLinks) + ", meds- " + str(medsLinks) + ", docs- " + str(docLinksLinks) + ", major- "
        + str(framinghamMajorLinks) + ", minor- " + str(framinghamMinorLinks) + ", Fram- " + str(framinghamLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
