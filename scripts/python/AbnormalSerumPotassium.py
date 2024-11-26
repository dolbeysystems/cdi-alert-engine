##################################################################################################################
#Evaluation Script - Abnormal Serum Potassium Levels
#
#This script checks an account to see if it matches criteria to be alerted for Abnormal Serum Potassium Levels
#Date - 10/22/2024
#Version - V16
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
    discreteV7alues = db.GetAccountField(account._id, "DiscreteValues")

#========================================
#  Discrete Value Fields and Calculations
#========================================
dvSerumPotassium = ["POTASSIUM (mmol/L)"]
calcSerumPotassium1 = 3.1
calcSerumPotassium2 = 5.1
calcSerumPotassium3 = 5.4
calcSerumPotassium4 = 3.4

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
    
def insulinValue(medDic, med_name, link_text, sequence=0, category=None, abstract=False):
    for mv in medDic or []:
        mvr = cleanNumbers(medDic[mv]['Dosage'])
        if (
            medDic[mv]['Route'] is not None and
            med_name == medDic[mv]['Category'] and
            (re.search(r'\bIntravenous\b', medDic[mv]['Route'], re.IGNORECASE) or
            re.search(r'\bIV Push\b', medDic[mv]['Route'], re.IGNORECASE)) and
            mvr is not None and 
            float(mvr) == float(10)
        ):
            if abstract == True:
                medDataConversion(medDic[mv]['StartDate'], link_text, medDic[mv]['Medication'], medDic[mv]['ExternalId'], medDic[mv]['Dosage'], medDic[mv]['Route'], category, sequence)
                return True
            elif abstract == False:
                abstraction = medDataConversion(medDic[mv]['StartDate'], link_text, medDic[mv]['Medication'], medDic[mv]['ExternalId'], medDic[mv]['Dosage'], medDic[mv]['Route'], category, sequence, abstract)
                return abstraction
    return None
    
#========================================
#  Algorithm
#========================================
db.LogEvaluationScriptMessage("Script starting " + str(account._id), scriptName, scriptInstance, "Debug")
#Standard Variable Declaration
AlertPassed = False
AlertConditions = False
alertTriggered = False
validated = False
outcome = None
subtitle = None
reason = None
message1 = False
message2 = False
dcTriggerLinks = False
absLinks = False
labsLinks = False
treatmentLinks = False
noLabs = []

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 2)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 3)
treatment = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 4)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 5)
potassium = MatchedCriteriaLink("Serum Potassium", None, "Serum Potassium", None, True, None, None, 90)

#Lacking Messages
LinkText1 = "Possible No High Serum Potassium Levels Were Found Please Review"
LinkText2 = "Possible No Low Serum Potassium Levels Were Found Please Review"

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Abnormal Serum Potassium':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        reason = alert.Reason
        if outcome == 'AUTORESOLVED' or reason == 'Previously Autoresolved':
            triggerAlert = False
        subtitle = alert.Subtitle
        for alertLink in alert.Links:
            if alertLink.LinkText == 'Laboratory Studies':
                for links in alertLink.Links:
                    if links.LinkText == LinkText1:
                        message1 = True
                    if links.LinkText == LinkText2:
                        message2 = True
        break

#Check if alert was autoresolved or completed.
if validated is False:
    #Get treatment within last X days
    mainMedDic = {}
    unsortedMedDic = {}
    medCount = 0
    #Combine all items into one list to search against
    medSearchList = ["Insulin"]
    #Set datelimit for how far back to 
    medDateLimit = System.DateTime.Now.AddDays(-7)
    #Loop through all treatment finding any that match in the combined list adding to a dictionary the matches
    if 'Medications' in account:    
        for med in account.Medications:
            if med.StartDate >= medDateLimit and 'Category' in med and med.Category is not None:
                if any(item == med.Category for item in medSearchList):
                    medCount += 1
                    unsortedMedDic[medCount] = med
    #Sort List by latest
    mainMedDic = sorted(unsortedMedDic.items(), key=lambda x: x[1]['StartDate'], reverse=True)
        
    #Find all discrete values for custom lookups within the last X days
    maindiscreteDic = {}
    unsortedDicsreteDic = {}
    dvCount = 0
    #Combine all items into one list to search against
    discreteSearchList = [i for j in [dvSerumPotassium] for i in j]
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
    
    #AlertTrigger
    e875Code = codeValue("E87.5", "Hyperkalemia Fully Specified Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    e876Code = codeValue("E87.6", "Hypokalemia Fully Specified Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Labs
    serumPotassiumMultiDV = dvValueMulti(dict(maindiscreteDic), dvSerumPotassium, "Serum Potassium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumPotassium2, gt, 0, potassium, False, 10)
    serumPotassiumMulti2DV = dvValueMulti(dict(maindiscreteDic), dvSerumPotassium, "Serum Potassium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumPotassium1, lt, 0, potassium, False, 10)
    serumPotassiumMulti3DV = dvValueMulti(dict(maindiscreteDic), dvSerumPotassium, "Serum Potassium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumPotassium3, gt, 0, potassium, False, 10)
    serumPotassiumMulti4DV = dvValueMulti(dict(maindiscreteDic), dvSerumPotassium, "Serum Potassium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumPotassium4, le, 0, potassium, False, 10)
    #Meds
    dextroseMed = medValue("Dextrose 5% In Water", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1)
    hemodialysisCodes = multiCodeValue(["5A1D70Z", "5A1D80Z", "5A1D90Z"], "Hemodialysis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    insulinMed = insulinValue(dict(mainMedDic), "Insulin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 3)
    kayexalateMed = medValue("Kayexalate", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 4)
    potassiumReplacementMed = medValue("Potassium Replacement", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 5)
    potChlorideAbs = abstractValue("POTASSIUM_CHLORIDE", "Potassium Chlroide '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6)
    potPhoshateAbs = abstractValue("POTASSIUM_PHOSPHATE", "Potassium Phosphate '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7)
    potBicarbonateAbs = abstractValue("POTASSIUM_BICARBONATE", "Potassium Bicarbonate '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8)

    #Main Algorithm
    if e875Code is not None and subtitle == "Possible Hyperkalemia Dx":
        if e875Code is not None: updateLinkText(e875Code, autoCodeText); dc.Links.Add(e875Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True

    elif (
        e875Code is None and
        len(serumPotassiumMulti3DV or noLabs) > 1 and
        (kayexalateMed is not None or (insulinMed is not None and dextroseMed is not None) or hemodialysisCodes is not None)
    ):
        if serumPotassiumMulti3DV:
            for entry in serumPotassiumMulti3DV:
                potassium.Links.Add(entry)
        if serumPotassiumMultiDV and len(serumPotassiumMulti3DV or noLabs) < 2:
            for entry in serumPotassiumMultiDV:
                potassium.Links.Add(entry)
        result.Subtitle = "Possible Hyperkalemia Dx"
        AlertPassed = True
        
    elif e876Code is not None and subtitle == "Possible Hypokalemia Dx":
        if e876Code is not None: updateLinkText(e876Code, autoCodeText); dc.Links.Add(e876Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
        
    elif (
        e876Code is None and
        len(serumPotassiumMulti2DV or noLabs) > 1 and
        (potassiumReplacementMed is not None or potChlorideAbs is not None or
        potPhoshateAbs is not None or potBicarbonateAbs is not None)
    ):
        if serumPotassiumMulti2DV:
            for entry in serumPotassiumMulti2DV:
                potassium.Links.Add(entry)
        if len(serumPotassiumMulti2DV or noLabs) < 2 and serumPotassiumMulti4DV is not None:
            for entry in serumPotassiumMulti4DV:
                potassium.Links.Add(entry)
        result.Subtitle = "Possible Hypokalemia Dx"
        AlertPassed = True
        
    elif len(serumPotassiumMultiDV or noLabs) >= 1 and e875Code is not None and subtitle == "Hyperkalemia Dx Documented Possibly Lacking Supporting Evidence":
        #This alert trigger autoresolves the alert the proceeds it if the criteria is met.
        AlertConditions = True
        updateLinkText(e875Code, autoEvidenceText); dc.Links.Add(e875Code)
        for entry in serumPotassiumMultiDV:
            updateLinkText(entry, autoEvidenceText); potassium.Links.Add(entry)
        if message1: labs.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, False))
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to clinical evidence now existing on the Account"
        result.Validated = True

    elif len(serumPotassiumMultiDV or noLabs) == 0 and e875Code is not None:
        result.Subtitle = "Hyperkalemia Dx Documented Possibly Lacking Supporting Evidence"
        dc.Links.Add(e875Code)
        labs.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, True))
        AlertConditions = True

    elif len(serumPotassiumMulti4DV or noLabs) >= 1 and e876Code is not None and subtitle == "Hypokalemia Dx Documented Possibly Lacking Supporting Evidence":
        updateLinkText(e876Code, autoEvidenceText); dc.Links.Add(e876Code)
        for entry in serumPotassiumMulti4DV:
            updateLinkText(entry, autoEvidenceText); potassium.Links.Add(entry)
        if message2: labs.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None, False))
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to clinical evidence now existing on the Account"
        result.Validated = True
        AlertConditions = True

    elif (
        len(serumPotassiumMulti4DV or noLabs) == 0 and
        e876Code is not None and
        potassiumReplacementMed is None and
        potChlorideAbs is None and
        potPhoshateAbs is None and
        potBicarbonateAbs is None
    ):
        result.Subtitle = "Hypokalemia Dx Documented Possibly Lacking Supporting Evidence"
        dc.Links.Add(e876Code)
        labs.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None, True))
        AlertConditions = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False
else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Abstractions
    codeValue("E27.1", "Addisons Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, abs, True)
    prefixCodeValue("^E24\.", "Cushing Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, abs, True)
    abstractValue("DIARRHEA", "Diarrhea '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3, abs, True)
    abstractValue("HYPERKALEMIA_EKG_CHANGES", "EKG Changes '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5, abs, True)
    abstractValue("HYPOKALEMIA_EKG_CHANGES", "EKG Changes '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6, abs, True)
    codeValue("R53.83", "Fatigue: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, abs, True)
    abstractValue("HEART_PALPITATIONS", "Heart Palpitations '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, abs, True)
    multiCodeValue(["N17.0", "N17.1", "N17.2", "N18.30", "N18.31", "N18.32", "N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6"],
                   "Kidney Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, abs, True)
    abstractValue("MUSCLE_CRAMPS", "Muscle Cramps '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10, abs, True)
    abstractValue("WEAKNESS", "Muscle Weakness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11, abs, True)
    abstractValue("VOMITING", "Vomiting '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12, abs, True)
    #Treatments
    if dextroseMed is not None: treatment.Links.Add(dextroseMed) #1
    if hemodialysisCodes is not None: abs.Links.Add(hemodialysisCodes) #2
    if insulinMed is not None: treatment.Links.Add(insulinMed) #3
    if kayexalateMed is not None: treatment.Links.Add(kayexalateMed) #4
    if potassiumReplacementMed is not None: treatment.Links.Add(potassiumReplacementMed) #5
    if potChlorideAbs is not None: treatment.Links.Add(potChlorideAbs) #6
    if potPhoshateAbs is not None: treatment.Links.Add(potPhoshateAbs) #7
    if potBicarbonateAbs is not None: treatment.Links.Add(potBicarbonateAbs) #8

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if potassium.Links: labs.Links.Add(potassium); labsLinks = True
    if dc.Links: result.Links.Add(dc); dcTriggerLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    result.Links.Add(treatment)
    if treatment.Links: treatmentLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Document Code- " + str(dcTriggerLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks) + ", treatment- "
        + str(treatmentLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
