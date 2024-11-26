##################################################################################################################
#Evaluation Script - Abnormal Sodium Levels
#
#This script checks an account to see if it matches criteria to be alerted for Abnormal Sodium Levels
#Date - 10/22/2024
#Version - V18
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
    discreteValues = db.GetAccountField(account._id, "DiscreteValues")
#========================================
#  Discrete Value Fields and Calculations
#========================================
dvBloodGlucose = [ "GLUCOSE (mg/dL)", "GLUCOSE"]
calcBloodGlucose1 = lambda x: x > 600
dvBloodGlucosePOC = ["GLUCOSE ACCUCHECK (mg/dL)"]
calcBloodGlucosePOC1 = lambda x: x > 600
dvGlasgowComaScale = ["3.5 Neuro Glasgow Score"]
calcGlasgowComaScale1 = lambda x: x < 15
dvSerumSodium = ["SODIUM (mmol/L)"]
calcSerumSodium1 = 131
calcSerumSodium2 = 145
calcSerumSodium3 = 132
calcSerumSodium4 = 144

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
def assignedCode(code):
    workingHis = account['WorkingHistory']
    if 'WorkingHistory' in account:
        obj = workingHis[0]
        for item in obj['Diagnoses']:
            if code == item.Code:
                return True
        if obj['AdmitDiagnosis'] is not None:      
            if obj['AdmitDiagnosis']['Code'] == code:
                return True
    return False

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
reason = None
message1 = False
message2 = False
absLinks = False
labsLinks = False
treatmentLinks = False
noLabs = []

#Initalize categories
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 1)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 2)
treatment = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 3)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 4)
sodium = MatchedCriteriaLink("Serum Sodium", None, "Serum Sodium", None, True, None, None, 90)

#Link text for lacking alerts.
LinkText1 = "Possible No High Serum Sodium Levels Were Found Please Review"
LinkText2 = "Possible No Low Serum Sodium Levels Were Found Please Review"

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Abnormal Serum Sodium':
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
    #Find all discrete values for custom lookups within the last X days
    maindiscreteDic = {}
    unsortedDicsreteDic = {}
    dvCount = 0
    #Combine all items into one list to search against
    discreteSearchList = [i for j in [dvSerumSodium] for i in j]
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
    
    #Abs
    e870Code = codeValue("E87.0", "Hyperosmolality and Hypernatremia: E87.0 '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12)
    e871Code = codeValue("E87.1", "Hypoosmolality and Hyponatremia: E87.1 '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14)
    e222Code = codeValue("E22.2", "SIADH: E22.2'[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20)
    #labs Subheadings
    serumSodiumMultiDV = dvValueMulti(dict(maindiscreteDic), dvSerumSodium, "Serum Sodium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumSodium1, lt, 0, sodium, False, 10) #132
    serumSodiumMulti2DV = dvValueMulti(dict(maindiscreteDic), dvSerumSodium, "Serum Sodium: [VALUE] (Result Date: [RESULTDATETIME])",calcSerumSodium2, gt, 0, sodium, False, 10) #144
    serumSodiumMulti3DV = dvValueMulti(dict(maindiscreteDic), dvSerumSodium, "Serum Sodium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumSodium3, lt, 0, sodium, False, 10) #131
    serumSodiumMulti4DV = dvValueMulti(dict(maindiscreteDic), dvSerumSodium, "Serum Sodium: [VALUE] (Result Date: [RESULTDATETIME])",calcSerumSodium4, gt, 0, sodium, False, 10) #145
    #Treatment
    dextroseMed = medValue("Dextrose 5% in Water", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1)
    dextroseAbs = abstractValue("DEXTROSE_5_IN_WATER", "Dextrose 5% in Water '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2)
    fluidRestrAbs = abstractValue("FLUID_RESTRICTION", "Fluid Restriction '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3)
    hypertonicSalMed = medValue("Hypertonic Saline", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 4)
    hypertonicSalAbs = abstractValue("HYPERTONIC_SALINE", "Hypertonic Saline '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5)
    hypotonicSolMed = medValue("Hypotonic Solution", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 6)
    hypotonicSolAbs = abstractValue("HYPOTONIC_SOLUTION", "Hypotonic Solution '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7)

    #Main Algorithm
    if subtitle == "SIADH and Hyponatremia Both Assigned Seek Clarification" and assignedCode("E22.2") is False and assignedCode("E87.1") is False: 
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due code no longer being assigned."
        result.Validated = True
        AlertConditions = True
        
    elif assignedCode("E22.2") and assignedCode("E87.1"):
        abs.Links.Add(e871Code)
        abs.Links.Add(e222Code)
        result.Subtitle = "SIADH and Hyponatremia Both Assigned Seek Clarification"
        AlertPassed = True
    
    elif e870Code is not None and subtitle == "Possible Hypernatremia Dx":
        if e870Code is not None: updateLinkText(e870Code, autoCodeText); abs.Links.Add(e870Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True

    elif e870Code is None and len(serumSodiumMulti2DV or noLabs) > 1 and (dextroseMed is not None or dextroseAbs is not None or hypotonicSolMed is not None or hypotonicSolAbs is not None):
        if serumSodiumMulti2DV:
            for entry in serumSodiumMulti2DV:
                sodium.Links.Add(entry)
        if dextroseMed is not None: treatment.Links.Add(dextroseMed)
        if dextroseAbs is not None: treatment.Links.Add(dextroseAbs)
        if hypotonicSolMed is not None: treatment.Links.Add(hypotonicSolMed)
        if hypotonicSolAbs is not None: treatment.Links.Add(hypotonicSolAbs)
        result.Subtitle = "Possible Hypernatremia Dx"
        AlertPassed = True
    
    elif e871Code is not None and subtitle == "Possible Hyponatremia Dx":
        if e871Code is not None: updateLinkText(e871Code, autoCodeText); abs.Links.Add(e871Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
        
    elif e871Code is None and len(serumSodiumMultiDV or noLabs) > 1 and (fluidRestrAbs is not None or hypertonicSalMed is not None or hypertonicSalAbs is not None):
        if serumSodiumMultiDV:
            for entry in serumSodiumMultiDV:
                sodium.Links.Add(entry)
        if fluidRestrAbs is not None: treatment.Links.Add(fluidRestrAbs)
        if hypertonicSalMed is not None: treatment.Links.Add(hypertonicSalMed)
        if hypertonicSalAbs is not None: treatment.Links.Add(hypertonicSalAbs)
        result.Subtitle = "Possible Hyponatremia Dx"
        AlertPassed = True

    elif len(serumSodiumMulti4DV or noLabs) > 0 and e870Code is not None and subtitle == "Hypernatremia Dx Documented Possibly Lacking Supporting Evidence":
        updateLinkText(e870Code, autoEvidenceText); abs.Links.Add(e870Code)
        for entry in serumSodiumMulti4DV:
            updateLinkText(entry, autoEvidenceText); sodium.Links.Add(entry)
        if message1: labs.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, False))
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to clinical evidence now existing on the Account"
        result.Validated = True
        AlertConditions = True

    elif len(serumSodiumMulti4DV or noLabs) == 0 and e870Code is not None:
        abs.Links.Add(e870Code)
        labs.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None))
        result.Subtitle = "Hypernatremia Dx Documented Possibly Lacking Supporting Evidence"
        AlertConditions = True

    elif len(serumSodiumMulti3DV or noLabs) > 0 and e871Code is not None and subtitle == "Hyponatremia Dx Documented Possibly Lacking Supporting Evidence":
        updateLinkText(e871Code, autoEvidenceText); abs.Links.Add(e871Code)
        for entry in serumSodiumMulti3DV:
            updateLinkText(entry, autoEvidenceText); sodium.Links.Add(entry)
        if message2: labs.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None, False))
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to clinical evidence now existing on the Account"
        result.Validated = True
        AlertConditions = True

    elif (
        len(serumSodiumMulti3DV or noLabs) == 0 and
        e871Code is not None
    ):
        abs.Links.Add(e871Code)
        labs.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None))
        result.Subtitle = "Hyponatremia Dx Documented Possibly Lacking Supporting Evidence"
        AlertConditions = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Abstractions
    r4182Code = codeValue("R41.82", "Altered Level Of Consciousness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    alteredAbs = abstractValue("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level Of Consciousness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2)
    if r4182Code is not None:
        abs.Links.Add(r4182Code)
        if alteredAbs is not None: alteredAbs.Hidden = True; abs.Links.Add(alteredAbs)
    elif r4182Code is None and alteredAbs is not None:
        abs.Links.Add(alteredAbs)
    codeValue("F10.230", "Beer Potomania: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, abs, True)
    codeValue("R11.14", "Bilious Vomiting: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, abs, True)
    multiCodeValue(["I50.21", "I50.22", "I50.23", "I50.31", "I50.32", "I50.33", "I50.41",
                       "I50.42", "I50.43", "I50.811", "I50.812", "I50.813", "I50.814", "I50.82", "I50.83", "I50.84"],
                      "Congestive Heart Failure (CHF): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, abs, True)
    codeValue("R11.15", "Cyclical Vomiting: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, abs, True)
    abstractValue("DIABETES_INSIPIDUS", "Diabetes Insipidus: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7, abs, True)
    abstractValue("DIARRHEA", "Diarrhea '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, abs, True)
    codeValue("R41.0", "Disorientation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, abs, True)
    codeValue("E86.0", "Dehydration: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, abs, True)
    codeValue("R53.83", "Fatigue: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, abs, True)
    #12
    abstractValue("HYPEROSMOLAR_HYPERGLYCEMIA_SYNDROME", "Hyperosmolar Hyperglycemic Syndrome '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13, abs, True)
    #14
    codeValue("E86.1", "Hypovolemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
    multiCodeValue(["N17.0", "N17.1", "N17.2", "N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6"],
                      "Kidney Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, abs, True)
    abstractValue("MUSCLE_CRAMPS", "Muscle Cramps '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 17, abs, True)
    codeValue("R63.1", "Polydipsia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, abs, True)
    abstractValue("SEIZURE", "Seizure '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 19, abs, True)
    #20
    multiCodeValue(["E05.01", "E05.11", "E05.21", "E05.41", "E05.81", "E05.91"],
                      "Thyrotoxic Crisis Storm Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21, abs, True)
    codeValue("E86.9", "Volume Depletion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 22, abs, True)
    codeValue("R11.10", "Vomiting: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23, abs, True)
    codeValue("R11.13", "Vomiting Fecal Matter: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 24, abs, True)
    codeValue("R11.11", "Vomiting Without Nausea: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 25, abs, True)
    abstractValue("WEAKNESS", "Muscle Weakness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 26, abs, True)
    #Labs
    if not dvValue(dvBloodGlucose, "Blood Glucose: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodGlucose1, 1, labs, True):
        dvValue(dvBloodGlucosePOC, "Blood Glucose POC: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodGlucosePOC1, 2, labs, True)

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if sodium.Links: labs.Links.Add(sodium); labsLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    result.Links.Add(treatment)
    result.Links.Add(other)
    if treatment.Links: treatmentLinks = True
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: " + "Abs- " + str(absLinks) + ", labs- " + str(labsLinks) 
        + ", Treatment- " + str(treatmentLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
