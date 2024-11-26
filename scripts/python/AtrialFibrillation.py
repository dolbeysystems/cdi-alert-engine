##################################################################################################################
#Evaluation Script - A-Fib
#
#This script checks an account to see if it matches criteria to be alerted for A-Fib
#Date - 10/24/2024
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
codeDic = {
    "I48.0": "Paroxysmal Atrial Fibrillation",
    "I48.11": "Longstanding Persistent Atrial Fibrillation",
    "I48.19": "Other Persistent Atrial Fibrillation",
    "I48.21": "Permanent Atrial Fibrillation",
    "I48.20": "Chronic Atrial Fibrillation"
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
dvHeartRate = ["Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)", "3.5 Heart Rate (Radial) (bpm)",  "SCC Monitor Pulse (bpm)"]
calcHeartRate1 = lambda x: x > 90
dvMAP = ["Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)"]
calcMAP1 = lambda x: x < 70
dvSBP = ["SBP 3.5 (No Calculation) (mm Hg)"]
calcSBP1 = lambda x: x < 90

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
documentedDxTriggerLinks = False
absLinks = False
vitalsLinks = False
medsLinks = False
docLinksLinks = False

#Initalize categories
documentedDx = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
vitals = MatchedCriteriaLink("Vital Signs/Intake and Output Data", None, "Vital Signs/Intake and Output Data", None, True, None, None, 2)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 3)
meds = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 4)
ekgLinks = MatchedCriteriaLink("EKG", None, "EKG", None, True, None, None, 5)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 6)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Atrial Fibrillation':
        alertTriggered = True
        validated = alert.IsValidated
        subtitle = alert.Subtitle
        outcome = alert.Outcome
        break

#Check if alert was autoresolved or completed.
if validated is False:
    #Alert Triggers
    i4891Code = codeValue("I48.91", "Unspecified Atrial Fibrillation Dx Present: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    artialFibAbs = abstractValue("ATRIAL_FIBRILLATION", "Atrial Fibrillation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    i480Code = codeValue("I48.0", "Paroxysmal Atrial Fibrillation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i4811Code = codeValue("I48.11", "Longstanding Persistent Atrial Fibrillation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i4819Code = codeValue("I48.19", "Other Persistent Atrial Fibrillation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i4820Code = codeValue("I48.20", "Chronic Atrial Fibrillation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i4821Code = codeValue("I48.21", "Permanent Atrial Fibrillation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")

    #Main Algorithm
    if (
        i480Code is not None and (i4819Code is not None or i4820Code is not None or i4821Code is not None)
    ):
        if i480Code is not None: documentedDx.Links.Add(i480Code)
        if i4819Code is not None: documentedDx.Links.Add(i4819Code)
        if i4820Code is not None: documentedDx.Links.Add(i4820Code)
        if i4821Code is not None: documentedDx.Links.Add(i4821Code)
        result.Subtitle = "Conflicting Atrial Fibrillation Dx"
        AlertPassed = True
        if validated:
            result.Validated = False
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"
        
    elif subtitle == "Unspecified Atrial Fibrillation Dx" and codesExist > 0:
        for code in codeList:
            desc = codeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] ([DOCUMENTTYPE], [DOCUMENTDATE])")
            if tempCode is not None:
                documentedDx.Links.Add(tempCode)
                break
        result.Validated = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        AlertConditions = True

    elif i4891Code is not None and codesExist == 0:
        documentedDx.Links.Add(i4891Code)
        result.Subtitle = "Unspecified Atrial Fibrillation Dx"
        AlertPassed = True

#    elif subtitle == "Unspecified Atrial Fibrillation Dx" and codesExist > 0:
#        for code in codeList:
#            desc = codeDic[code]
#            tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] ([DOCUMENTTYPE], [DOCUMENTDATE])")
#            if tempCode is not None:
#                documentedDx.Links.Add(tempCode)
#                break
#        result.Validated = True
#        result.Outcome = "AUTORESOLVED"
#        result.Reason = "Autoresolved due to one Specified Code on the Account"
#        AlertConditions = True
#
#    elif artialFibAbs is not None and i4891Code is None and codesExist == 0:
#        documentedDx.Links.Add(artialFibAbs)
#        result.Subtitle = "Atrial Fibrillation only present on EKG"
#        AlertPassed = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Abs
    abstractValue("ABLATION", "Ablation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1, abs, True)
    codeValue("I35.1", "Aortic Regurgitation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, abs, True)
    codeValue("I35.0", "Aortic Stenosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, abs, True)
    abstractValue("CARDIOVERSION", "Cardioversion '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4, abs, True)
    abstractValue("DYSPNEA_ON_EXERTION", "Dyspnea On Exertion: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5, abs, True)
    codeValue("R53.83", "Fatigue: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, abs, True)
    abstractValue("HEART_PALPITATIONS", "Heart Palpitations '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7, abs, True)
    abstractValue("IMPLANTABLE_CARDIAC_ASSIST_DEVICE", "Implantable Cardiac Assist Device '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, abs, True)
    abstractValue("IRREGULAR_ECHO_FINDING", "Irregular Echo Findings '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, abs, True)
    codeValue("R42", "Light Headed: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, abs, True)
    abstractValue("MAZE_PROCEDURE", "Maze Procedure '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11, abs, True)
    codeValue("I34.0", "Mitral Regurgitation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, abs, True)
    codeValue("I34.2", "Mitral Stenosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13, abs, True)
    codeValue("I35.1", "Pulmonic Regurgitation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, abs, True)
    codeValue("I37.0", "Pulmonic Stenosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
    abstractValue("SHORTNESS_OF_BREATH", "Shortness of Breath '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 16, abs, True)
    codeValue("R55", "Syncopal: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17, abs, True)
    codeValue("I36.1", "Tricuspid Regurgitation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, abs, True)
    codeValue("I36.0", "Tricuspid Stenosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19, abs, True)
    abstractValue("WATCHMAN_PROCEDURE", "Watchman Procedure '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 20, abs, True)
    #Document Links
    documentLink("ECG", "ECG", 0, ekgLinks, True)
    documentLink("Electrocardiogram Adult   ECGR", "Electrocardiogram Adult   ECGR", 0, ekgLinks, True)
    documentLink("ECG Adult", "ECG Adult", 0, ekgLinks, True)
    documentLink("RestingECG", "RestingECG", 0, ekgLinks, True)
    documentLink("EKG", "EKG", 0, ekgLinks, True)
    #Meds 
    medValue("Adenosine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, meds, True)
    abstractValue("ADENOSINE", "Adenosine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2, meds, True)
    medValue("Antiarrhythmic", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 3, meds, True)
    abstractValue("ANTIARRHYTHMIC", "Antiarrhythmic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4, meds, True)
    medValue("Anticoagulant", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 5, meds, True)
    abstractValue("ANTICOAGULANT", "Anticoagulant '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6, meds, True)
    medValue("Antiplatelet", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 7, meds, True)
    abstractValue("ANTIPLATELET", "Antiplatelet '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, meds, True)
    medValue("Beta Blocker", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 9, meds, True)
    abstractValue("BETA_BLOCKER", "Beta Blocker '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10, meds, True)
    medValue("Calcium Channel Blockers", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 11, meds, True)
    abstractValue("CALCIUM_CHANNEL_BLOCKER", "Calcium Channel Blocker '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12, meds, True)
    medValue("Digitalis", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 13, meds, True)
    abstractValue("DIGOXIN", "Digoxin '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 14, meds, True)
    codeValue("Z79.01", "Long Term Use of Z79.01 '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, meds, True)
    codeValue("Z79.02", "Long Term Use of Antithrombotics/Z79.02 '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, meds, True)
    #Vitals
    dvValue(dvHeartRate, "Heart Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcHeartRate1, 1, vitals, True)
    dvValue(dvMAP, "Mean Arterial Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcMAP1, 3, vitals, True)
    dvValue(dvSBP, "Systolic Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcSBP1, 5, vitals, True)

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if documentedDx.Links: result.Links.Add(documentedDx); documentedDxTriggerLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if vitals.Links: result.Links.Add(vitals); vitalsLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    if ekgLinks.Links: result.Links.Add(ekgLinks); docLinksLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: AlertTrigger- " + str(documentedDxTriggerLinks) + ", Abs- " + str(absLinks) + ", docs- " + str(docLinksLinks) + ", vitals- " + str(vitalsLinks) + ", meds- " + str(medsLinks)
        + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
