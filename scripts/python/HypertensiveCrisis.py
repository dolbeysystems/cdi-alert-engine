##################################################################################################################
#Evaluation Script - Hypertensive Crisis
#
#This script checks an account to see if it matches criteria to be alerted for Hypertensive Crisis
#Date - 11/13/2024
#Version - V32
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
dvAlanineTransaminase = ["ALT", "ALT/SGPT (U/L)	16-61"]
calcAlanineTransaminase1 = lambda x: x > 61
dvAspartateTransaminase = ["AST", "AST/SGOT (U/L)"]
calcAspartateTransaminase1 = lambda x: x > 35
dvDBP = ["BP Arterial Diastolic cc (mm Hg)", "DBP 3.5 (No Calculation) (mmhg)", "DBP 3.5 (No Calculation) (mm Hg)"]
calcDBP1 = lambda x: x > 120
dvGlasgowComaScale = ["3.5 Neuro Glasgow Score"]
calcGlasgowComaScale1 = lambda x: x < 15
dvHeartRate = ["Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)", "3.5 Heart Rate (Radial) (bpm)",  "SCC Monitor Pulse (bpm)"]
dvMAP = ["Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)"]
dvSBP = ["SBP 3.5 (No Calculation) (mm Hg)"]
calcSBP1 = lambda x: x > 180
dvSerumBloodUreaNitrogen = ["BUN (mg/dL)"]
calcSerumBloodUreaNitrogen1 = lambda x: x > 23
dvSerumCreatinine = ["CREATININE (mg/dL)", "CREATININE SERUM (mg/dL)"]
calcSerumCreatinine1 = lambda x: x > 1.30
dvSerumLactate = ["Lactate Bld-sCnc (mmol/L)", "LACTIC ACID (SAH) (mmol/L)"]
calcSerumLactate1 = lambda x: x >= 4
dvTroponinT = ["TROPONIN, HIGH SENSITIVITY (ng/L)"]
calcTroponinT1 = lambda x: x > 59

dvTSAmphetamine = ["AMP/METH UR", "AMPHETAMINE URINE"]
dvTSCocaine = ["COCAINE URINE", "COCAINE UR CONF"]

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
def dvPositiveCheck(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    abstraction = None
    for dv in dvDic or []:
        if (
            dvDic[dv]['Name'] in discreteValueName and
            dvDic[dv]['Result'] is not None and
            (re.search(r'\bpositive\b', dvDic[dv]['Result'], re.IGNORECASE) is not None or
            re.search(r'\bDetected\b', dvDic[dv]['Result'], re.IGNORECASE) is not None)
        ):
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, True)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, False)
                return abstraction
    return abstraction

def linkedGreaterValues(dvDic, DV1, DV2, value, value2):
    discreteDic = {}
    discreteDic2 = {}
    discreteDic3 = {}
    discreteDic4 = {}
    s = 0
    d = 0
    x = 0
    a = 0
    matchedSBPList = []
    matchedDBPList = []
    DateList = []
    DateList2 = []

    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in DV1 and dvr is not None:
                x += 1
                discreteDic[x] = dvDic[dv]
        elif dvDic[dv]['Name'] in DV2 and dvr is not None:
                a += 1
                discreteDic2[a] = dvDic[dv]
                
    if x >= 2 and a >= 2:
        for item in discreteDic:
            if x <= 0 or a <= 0:
                break
            elif (
                discreteDic[x].ResultDate == discreteDic2[a].ResultDate and
                float(cleanNumbers(discreteDic[x].Result)) > float(value) and 
                float(cleanNumbers(discreteDic2[a].Result)) > float(value2) and
                discreteDic[x].ResultDate not in DateList and 
                discreteDic2[a].ResultDate not in DateList2
            ):
                DateList.append(discreteDic[x].ResultDate)
                d += 1
                discreteDic4[d] = discreteDic[x]
                s += 1
                discreteDic3[s] = discreteDic2[a]
                matchedDBPList.append(discreteDic[x].Result)
                matchedSBPList.append(discreteDic2[a].Result)
                x = x - 1; a = a - 1
            elif discreteDic[x].ResultDate != discreteDic2[a].ResultDate:
                for item in discreteDic2:
                    if discreteDic[x].ResultDate == discreteDic2[item].ResultDate:
                        if (    
                            float(cleanNumbers(discreteDic[x].Result)) > float(value) and 
                            float(cleanNumbers(discreteDic2[item].Result)) > float(value2) and
                            discreteDic[x].ResultDate not in DateList and 
                            discreteDic2[item].ResultDate not in DateList2
                        ):
                            DateList.append(discreteDic[x].ResultDate)
                            d += 1
                            discreteDic4[d] = discreteDic[x]
                            s += 1
                            discreteDic3[s] = discreteDic2[a]
                            matchedDBPList.append(discreteDic[x].Result)
                            matchedSBPList.append(discreteDic2[item].Result)
                            x = x - 1; a = a - 1
            else:
                x = x - 1; a = a - 1
    
    if d > 0 and s > 0:            
        bpSingleLineLookup(dict(dvDic), dict(discreteDic3), dict(discreteDic4))
    if len(matchedSBPList) == 0:
        matchedSBPList = [False]
    if len(matchedDBPList) == 0:
        matchedDBPList = [False]
    return [matchedSBPList, matchedDBPList]

def nonLinkedGreaterValues(dvDic, DV1, DV2, value, value2):
    discreteDic = {}
    discreteDic2 = {}
    discreteDic3 = {}
    s = 0
    d = 0
    x = 0
    idList = []

    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in DV1 and dvr is not None:
                x += 1
                discreteDic[x] = dvDic[dv]
        elif dvDic[dv]['Name'] in DV2 and dvr is not None:
                x += 1
                discreteDic[x] = dvDic[dv]
                
    if x > 0:
        for item in discreteDic:
            if (
                discreteDic[item]['Name'] in DV1 and
                float(cleanNumbers(discreteDic[item].Result)) > float(value) and
                discreteDic[item]._id not in idList
            ):
                d += 1
                discreteDic3[d] = discreteDic[item]
                idList.append(discreteDic[item]._id)
                for item2 in discreteDic:
                    if (
                        discreteDic[item].ResultDate == discreteDic[item2].ResultDate and 
                        discreteDic[item2]['Name'] in DV2 and
                        discreteDic[item2]._id not in idList
                    ):
                        s += 1
                        discreteDic2[s] = discreteDic[item2]
                        idList.append(discreteDic[item2]._id)
            elif (
                discreteDic[item]['Name'] in DV2 and
                float(cleanNumbers(discreteDic[item].Result)) > float(value2) and
                discreteDic[x]._id not in idList
            ):
                s += 1
                discreteDic2[s] = discreteDic[item]
                idList.append(discreteDic[item]._id)
                for item2 in discreteDic:
                    if (
                        discreteDic[item].ResultDate == discreteDic[item2].ResultDate and 
                        discreteDic[item2]['Name'] in DV1 and
                        discreteDic[item2]._id not in idList
                    ):
                        d += 1
                        discreteDic3[d] = discreteDic[item2]
                        idList.append(discreteDic[item2]._id)

    if d > 0 or s > 0:            
        bpSingleLineLookup(dict(dvDic), dict(discreteDic2), dict(discreteDic3))
    return 

def bpSingleLineLookup(dvDic, sbpDic, dbpDic):
    discreteDic1 = {}
    discreteDic2 = {}
    dbpDv = None
    hrDv = None
    mapDv = None
    matchingDate = None
    h = 0; m = 0
    matchedList = []
    dvr = None
    #Pull all values for discrete values we need
    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in dvMAP and dvr is not None:
            #Mean Arterial Blood Pressure
            m += 1
            discreteDic1[m] = dvDic[dv]
        elif dvDic[dv]['Name'] in dvHeartRate and dvr is not None:
            #Heart Rate
            h += 1
            discreteDic2[h] = dvDic[dv]
          
    for item in sbpDic:
        dbpDv = None
        hrDv = None
        mapDv = None
        matchingDate = sbpDic[item].ResultDate
        if m > 0:
            for item1 in discreteDic1:
                if discreteDic1[item1].ResultDate == matchingDate:
                    mapDv = discreteDic1[item1].Result
                    break
        if h > 0:
            for item2 in discreteDic2:
                if discreteDic2[item2].ResultDate == matchingDate:
                    hrDv = discreteDic2[item2].Result
                    break
        for item3 in dbpDic:
            if dbpDic[item3].ResultDate == matchingDate:
                dbpDv = dbpDic[item3].Result
                break
                
        if dbpDv is None:
            dbpDv = 'XX'
        if hrDv is None:
            hrDv = 'XX'
        if mapDv is None:
            mapDv = 'XX'
        matchedList.append(dataConversion(matchingDate, "[RESULTDATETIME] HR = " + str(hrDv) + ", BP = " + str(sbpDic[item].Result) + "/" + str(dbpDv) + ", MAP = " + str(mapDv), None, sbpDic[item]._id, vitals, 0, True))
    return 

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
#Standard Variable Declaration
AlertPassed = False
alertTriggered = False
AlertConditions = False
validated = False
outcome = None
subtitle = None
EODS = 0
dcLinks = False
absLinks = False
vitalsLinks = False
organLinks = False
medsLinks = False
labsLinks = False
noLabs = []

#Initalize categories
dc = MatchedCriteriaLink("Documented Code", None, "Documented Code", None, True, None, None, 1)
vitals = MatchedCriteriaLink("Vital Signs/Intake and Output Data", None, "Vital Signs/Intake and Output Data", None, True, None, None, 2)
organ = MatchedCriteriaLink("End Organ Dysfunction", None, "End Organ Dysfunction", None, True, None, None, 3)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 4)
meds = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 5)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 6)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 7)

#LinkText for lacking alerts
LinkText1 = "Possible No Blood Pressure Values Meeting Criteria, Please Review"

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Hypertensive Crisis':
        alertTriggered = True
        outcome = alert.Outcome
        validated = alert.IsValidated
        subtitle = alert.Subtitle
        break

#Check if alert was autoresolved or completed.
if validated is False:
    #Get meds within last X days
    mainMedDic = {}
    unsortedMedDic = {}
    medCount = 0
    #Combine all items into one list to search against
    medSearchList = ["Antianginal Medication", "Beta Blocker", "Calcium Channel Blockers", "Hydralazine", "Nitroglycerin", 
                     "Sodium Nitroprusside"]
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
    
    #Find all discrete values for custom lookups within the last 7 days
    maindiscreteDic = {}
    unsortedDicsreteDic = {}
    dvCount = 0
    #Combine all items into one list to search against
    discreteSearchList = [i for j in [dvDBP, dvSBP, dvTSAmphetamine, dvTSCocaine, dvMAP, dvHeartRate] for i in j]
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
    #Negations
    kidneyDiseaseCheck = multiCodeValue(["N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6", "N18.9", "N19"], "Kidney Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    heartFailureNegation = multiCodeValue(["I50.22", "I50.32", "I50.42", "I50.812"], "Heart Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    negationAspartate = multiCodeValue(["B18.2", "B19.20", "K70.10", "K70.11", "K70.30", "K70.31", "K70.40", "K70.41",
        "K72.10", "K72.11", "K73", "K74.60", "K74.69", "Z79.01", "Z86.19"], "Negation Aspartate '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    permissiveHypertensionAbs = abstractValue("PERMISSIVE_HYPERTENSION", "Permissive Hypertension: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",  True, 5)
    g40Code = codeValue("G40", "Epilepsy and Recurrent Seizures: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16)
    #Alert Trigger
    i160Code = codeValue("I16.0", "Hypertensive Urgency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i161Code = codeValue("I16.1", "Hypertensive Emergency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i169Code = codeValue("I16.9", "Unspecified Hypertensive Crisis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Abs
    acceleratedHyperAbs = abstractValue("ACCELERATED_HYPERTENSION", "Accelerated Hypertension '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1)
    malignantHyperAbs = abstractValue("MALIGNANT_HYPERTENSION", "Malignant Hypertension '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5)
    #Organ
    heartFailure = multiCodeValue(["I50.21", "I50.23", "I50.31", "I50.33", "I50.41", "I50.43", "I50.811", "I50.813"], "Acute Heart Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    n179Code = codeValue("N17.9", "Acute Kidney Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    i21Codes = prefixCodeValue("^I21\.", "Acute MI: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3)
    j810Code = codeValue("J81.0", "Acute Pulmonary Edema: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4)
    j960Codes = prefixCodeValue("^J96\.0", "Acute Respiratory Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5)
    highAlanineDV = dvValue(dvAlanineTransaminase, "Alanine Aminotransferase: [VALUE] (Result Date: [RESULTDATETIME])", calcAlanineTransaminase1, 6)
    altered = None
    altered = codeValue("R41.82", "Altered Level of Consciousness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7)
    if altered is None: altered = abstractValue("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level Of Consciousness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8)
    aorticDissection = multiCodeValue(["I71.00", "I71.010", "I71.011", "I71.012", "I71.019",
                                     "I71.02", "I71.03"], "Aortic Dissection: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9)
    highAspartateDV = dvValue(dvAspartateTransaminase, "Aspartate Aminotransferase: [VALUE] (Result Date: [RESULTDATETIME])", calcAspartateTransaminase1, 10)
    i639Code = codeValue("I63.9", "Cerebral Infarction: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11)
    r079Code = codeValue("R07.9", "Chest Pain: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12)
    r410Code = codeValue("R41.0", "Disorientation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13)  
    d65Code = codeValue("D65", "Disseminated Intravascular Coagulation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14)
    r748Code = codeValue("R74.8", "Elevated Liver Function: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15)
    encephalopathy = multiCodeValue(["G93.40", "G93.49"], "Encephalopathy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16)
    glasgowComaScoreDV = dvValue(dvGlasgowComaScale, "Glasgow Coma Score: [VALUE] (Result Date: [RESULTDATETIME])", calcGlasgowComaScale1, 17)
    e806Code = codeValue("E80.6", "Hyperbilirubinemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18)
    i674Code = codeValue("I67.4", "Hypertensive Encephalopathy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19)
    r17Code = codeValue("R17", "Jaundice: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20)
    k72Codes = multiCodeValue(["K72.00", "K72.01"], "Liver Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21)
    i61Codes = multiCodeValue(["I61.0", "I61.1", "I61.2", "I61.3", "I61.4", "I61.6", "I61.8", "I61.9"], "Nontraumatic Intracerebral Hemorrhage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 22)
    i62Codes = multiCodeValue(["I62.00", "I62.01", "I62.02", "I62.03", "I62.1", "I62.9"], "Nontraumatic Subarachnoid Hemorrhage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23)
    r569Code = codeValue("R56.9", "Seizure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 24)
    highSerumBloodUreaNitrogenDV = dvValue(dvSerumBloodUreaNitrogen, "Serum Blood Urea Nitrogen: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumBloodUreaNitrogen1, 25)
    highSerumCreatinineDV = dvValue(dvSerumCreatinine, "Serum Creatinine: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumCreatinine1, 26)
    serumLactateDV = dvValue(dvSerumLactate, "Serum Lactate: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumLactate1, 27)
    TroponinTDV = None
    TroponinTDV = dvValue(dvTroponinT, "Troponin T High Sensitivity: [VALUE] (Result Date: [RESULTDATETIME])", calcTroponinT1, 28)
    #Meds for IV
    antianginalIVMed = ivMedValue(dict(mainMedDic), "Antianginal Medication", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1)
    betaBlockerIVMed = ivMedValue(dict(mainMedDic), "Beta Blocker", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 3)
    calciumChannelIVMed = ivMedValue(dict(mainMedDic), "Calcium Channel Blockers", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 5)
    hydralazineIVMed = ivMedValue(dict(mainMedDic), "Hydralazine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 6)
    nitroglycerinIVMed = ivMedValue(dict(mainMedDic), "Nitroglycerin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 10)
    sodiumNitroprussideIVMed = ivMedValue(dict(mainMedDic), "Sodium Nitroprusside", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 12)
    #Vitals
    bpMultiDV = [[False], [False]]
    bpMultiDV = linkedGreaterValues(dict(maindiscreteDic), dvDBP, dvSBP, 120, 180)
    #Lacking BPs only
    dbpDV = dvValue(dvDBP, "Diastolic Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcDBP1, 0)
    sbpDV = dvValue(dvSBP, "Systolic Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcSBP1, 0)

    #Abstracting End organ Damage Signs
    if kidneyDiseaseCheck is None and highSerumBloodUreaNitrogenDV is not None:
        if highSerumBloodUreaNitrogenDV is not None: organ.Links.Add(highSerumBloodUreaNitrogenDV)
        EODS += 1
    elif kidneyDiseaseCheck is not None and highSerumBloodUreaNitrogenDV is not None:
        if highSerumBloodUreaNitrogenDV is not None: highSerumBloodUreaNitrogenDV.Hidden = True; organ.Links.Add(highSerumBloodUreaNitrogenDV)
    if kidneyDiseaseCheck is None and highSerumCreatinineDV is not None:
        if highSerumCreatinineDV is not None: organ.Links.Add(highSerumCreatinineDV)
        EODS += 1
    elif kidneyDiseaseCheck is not None and highSerumCreatinineDV is not None:
        if highSerumCreatinineDV is not None: highSerumCreatinineDV.Hidden = True; organ.Links.Add(highSerumCreatinineDV)
    if heartFailureNegation is None and TroponinTDV is not None:
        if TroponinTDV is not None: organ.Links.Add(TroponinTDV)
        EODS += 1
    elif heartFailureNegation is not None and TroponinTDV is not None:
        if TroponinTDV is not None: TroponinTDV.Hidden = True; organ.Links.Add(TroponinTDV)
        EODS += 1
    if negationAspartate is None and e806Code is not None: organ.Links.Add(e806Code); EODS += 1
    elif negationAspartate is not None and e806Code is not None: e806Code.Hidden = True; organ.Links.Add(e806Code)
    if negationAspartate is None and r17Code is not None: organ.Links.Add(r17Code); EODS += 1
    elif negationAspartate is not None and r17Code is not None: r17Code.Hidden = True; organ.Links.Add(r17Code)
    if negationAspartate is None and r748Code is not None: organ.Links.Add(r748Code); EODS += 1
    elif negationAspartate is None and r748Code is not None: r748Code.Hidden = True; organ.Links.Add(r748Code)
    if negationAspartate is None and highAlanineDV is not None:
        if highAlanineDV is not None: organ.Links.Add(highAlanineDV)
        EODS += 1
    elif negationAspartate is not None and highAlanineDV is not None:
        if highAlanineDV is not None: highAlanineDV.Hidden = True; organ.Links.Add(highAlanineDV)
    if negationAspartate is None and highAspartateDV is not None:
        if highAspartateDV is not None: organ.Links.Add(highAspartateDV)
        EODS += 1
    elif negationAspartate is None and highAspartateDV is not None:
        if highAspartateDV is not None: highAspartateDV.Hidden = True; organ.Links.Add(highAspartateDV)
    if n179Code is not None: organ.Links.Add(n179Code); EODS += 1
    if j810Code is not None: organ.Links.Add(j810Code); EODS += 1
    if i674Code is not None: organ.Links.Add(i674Code); EODS += 1
    if encephalopathy is not None: organ.Links.Add(encephalopathy); EODS += 1
    if aorticDissection is not None: organ.Links.Add(aorticDissection); EODS += 1
    if glasgowComaScoreDV is not None or altered is not None:
        if glasgowComaScoreDV is not None: organ.Links.Add(glasgowComaScoreDV)
        if altered is not None: organ.Links.Add(altered)
        EODS += 1
    if heartFailure is not None: organ.Links.Add(heartFailure); EODS += 1
    if r079Code is not None: organ.Links.Add(r079Code); EODS += 1
    if g40Code is None and r569Code is not None: organ.Links.Add(r569Code); EODS += 1
    if i21Codes is not None: organ.Links.Add(i21Codes); EODS += 1
    if k72Codes  is not None: organ.Links.Add(k72Codes); EODS += 1
    if d65Code is not None: organ.Links.Add(d65Code); EODS += 1
    if j960Codes is not None: organ.Links.Add(j960Codes); EODS += 1
    if serumLactateDV is not None: organ.Links.Add(serumLactateDV); EODS += 1
    if r410Code is not None: organ.Links.Add(r410Code); EODS += 1
    if i639Code is not None: organ.Links.Add(i639Code); EODS += 1
    if i61Codes is not None: organ.Links.Add(i61Codes); EODS += 1
    if i62Codes is not None: organ.Links.Add(i62Codes); EODS += 1

    #Main Algorithm
    #1
    if i160Code is not None and i161Code is not None:
        dc.Links.Add(i160Code)
        dc.Links.Add(i161Code)
        if bpMultiDV[0][0] is False and bpMultiDV[1][0] is False:
            nonLinkedGreaterValues(dict(maindiscreteDic), dvDBP, dvSBP, 120, 180)
        result.Subtitle = "Hypertensive Crisis Conflicting Dx Codes"
        AlertPassed = True
    #2.1
    elif subtitle == "Unspecified Hypertensive Crisis Dx" and (i160Code is not None or i161Code is not None):
        if i160Code is not None: updateLinkText(i160Code, autoCodeText); dc.Links.Add(i160Code)
        if i161Code is not None: updateLinkText(i161Code, autoCodeText); dc.Links.Add(i161Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #2.0
    elif i169Code is not None and (bpMultiDV[0][0] is not False or bpMultiDV[1][0] is not False) and i160Code is None and i161Code is None:
        dc.Links.Add(i169Code)
        result.Subtitle = "Unspecified Hypertensive Crisis Dx"
        AlertPassed = True
    #3.1
    elif subtitle == "Unspecified Hypertensive Crisis Dx Possibly Lacking Blood Pressure Criteria" and (sbpDV is not None or dbpDV is not None):
        if sbpDV is not None: vitals.Links.Add(sbpDV)
        if dbpDV is not None: vitals.Links.Add(dbpDV)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertPassed = True
    #3    
    elif i169Code is not None and sbpDV is None and dbpDV is None:
        dc.Links.Add(i169Code)
        dc.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, True))
        result.Subtitle = "Unspecified Hypertensive Crisis Dx Possibly Lacking Blood Pressure Criteria"
        AlertPassed = True
    #4.1
    elif subtitle == "Possible Hypertensive Emergency" and i161Code is not None:
        if i161Code is not None: updateLinkText(i161Code, autoCodeText); dc.Links.Add(i161Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertPassed = True   
    #4
    elif (
        i161Code is None and
        (acceleratedHyperAbs is not None or 
        malignantHyperAbs is not None or 
        ((bpMultiDV[0][0] is not False and len(bpMultiDV[0] or noLabs) > 3) or 
         (bpMultiDV[1][0] is not False and len(bpMultiDV[1] or noLabs) > 3))) and
        EODS > 0 and
        (antianginalIVMed is not None or betaBlockerIVMed is not None or calciumChannelIVMed is not None or
        hydralazineIVMed is not None or nitroglycerinIVMed is not None or sodiumNitroprussideIVMed is not None)
        and permissiveHypertensionAbs is None 
    ):
        if i160Code is not None: abs.Links.Add(i160Code)
        if antianginalIVMed is not None: meds.Links.Add(antianginalIVMed)
        if betaBlockerIVMed is not None: meds.Links.Add(betaBlockerIVMed)
        if calciumChannelIVMed is not None: meds.Links.Add(calciumChannelIVMed)
        if hydralazineIVMed is not None: meds.Links.Add(hydralazineIVMed)
        if nitroglycerinIVMed is not None: meds.Links.Add(nitroglycerinIVMed)
        if sodiumNitroprussideIVMed is not None: meds.Links.Add(sodiumNitroprussideIVMed)
        result.Subtitle = "Possible Hypertensive Emergency"
        AlertPassed = True
    #5.1
    elif subtitle == "Possible Hypertensive Crisis" and (i160Code is not None or i161Code is not None):
        if i160Code is not None: updateLinkText(i160Code, autoCodeText); dc.Links.Add(i160Code)
        if i161Code is not None: updateLinkText(i161Code, autoCodeText); dc.Links.Add(i161Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertPassed = True        
    #5
    elif (
        i160Code is None and 
        i161Code is None and 
        (acceleratedHyperAbs is not None or 
        malignantHyperAbs is not None or 
        ((bpMultiDV[0][0] is not False and len(bpMultiDV[0] or noLabs) > 1) or 
        (bpMultiDV[1][0] is not False and len(bpMultiDV[1] or noLabs) > 1)))
    ):
        if bpMultiDV[0][0] is False and bpMultiDV[1][0] is False:
            nonLinkedGreaterValues(dict(maindiscreteDic), dvDBP, dvSBP, 120, 180)
        result.Subtitle = "Possible Hypertensive Crisis"
        AlertPassed = True

    #6.1
    elif subtitle == "Hypertensive Emergency Dx Possibly Lacking Supporting Evidence" and (EODS > 0 and (sbpDV is not None or dbpDV is not None)):
        if sbpDV is not None: vitals.Links.Add(sbpDV)
        if dbpDV is not None: vitals.Links.Add(dbpDV)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertPassed = True
    #6
    elif i161Code is not None and (EODS == 0 or (sbpDV is None and dbpDV is None)):
        dc.Links.Add(i161Code) 
        if EODS == 0:
            dc.Links.Add(MatchedCriteriaLink("Possible No End Organ Damage Criteria found please review", None, None, None, True))
        if sbpDV is None and dbpDV is None:
            dc.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, True))
        result.Subtitle = "Hypertensive Emergency Dx Possibly Lacking Supporting Evidence"
        AlertPassed = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        AlertPassed = False
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Abs
    if acceleratedHyperAbs is not None: abs.Links.Add(acceleratedHyperAbs) #1
    codeValue("R51.9", "Headache: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, abs, True)
    abstractValue("HEART_PALPITATIONS", "Heart Palpitations '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3, abs, True)
    codeValue("R42", "Lightheadedness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, abs, True)
    if malignantHyperAbs is not None: abs.Links.Add(malignantHyperAbs) #5
    multiCodeValue(["R11.0", "R11.10", "R11.2"], "Nausea and Vomiting: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, abs, True)
    abstractValue("RESOLVING_TROPONINS", "Resolving Troponins '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7, abs, True)
    abstractValue("SHORTNESS_OF_BREATH", "Shortness of Breath '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, abs, True)
    prefixCodeValue("^F15\.", "Stimulant Abuse: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, abs, True)
    codeValue("E05.90", "Thyrotoxicosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, abs, True)
    abstractValue("ELEVATED_TROPONINS", "Troponemia '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11, abs, True)
    #Labs
    dvPositiveCheck(dict(maindiscreteDic), dvTSAmphetamine, "Drug/Tox Screen: Amphetamine Screen Urine: '[VALUE]' (Result Date: [RESULTDATETIME])", 1, labs, True)
    dvPositiveCheck(dict(maindiscreteDic), dvTSCocaine, "Drug/Tox Screen: Cocaine Screen Urine: '[VALUE]' (Result Date: [RESULTDATETIME])", 2, labs, True)
    #Meds
    medValue("Antianginal Medication", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, meds, True)
    abstractValue("ANTIANGINAL_MEDICATION", "Antianginal Medication '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2, meds, True)
    medValue("Beta Blocker", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 3, meds, True)
    abstractValue("BETA_BLOCKER", "Beta Blocker '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4, meds, True)
    medValue("Calcium Channel Blockers", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 5, meds, True)
    abstractValue("CALCIUM_CHANNEL_BLOCKER", "Calcium Channel Blockers '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6, meds, True)
    medValue("Hydralazine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 7, meds, True)
    abstractValue("HYDRALAZINE", "Hydralazine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, meds, True)
    medValue("Nitroglycerin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 9, meds, True)
    abstractValue("NITROGLYCERIN", "Nitroglycerin '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10, meds, True)
    medValue("Sodium Nitroprusside", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 11, meds, True)
    abstractValue("NITROPRUSSIDE", "Nitroprusside '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12, meds, True)
    #Vitals Subheadings
    abstractValue("HIGH_SYSTOLIC_BLOOD_PRESSURE", "SBP: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0, vitals, True)
    abstractValue("HIGH_DIASTOLIC_BLOOD_PRESSURE", "DBP: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0, vitals, True)
            
#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if labs.Links: result.Links.Add(labs); labsLinks = True
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if vitals.Links: result.Links.Add(vitals); vitalsLinks = True
    if organ.Links: result.Links.Add(organ); organLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: AlertTrigger- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", vitals- " + str(vitalsLinks) + ", meds- " + str(medsLinks) +
        ", organ- " + str(organLinks) + ", Labs- " + str(labsLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
