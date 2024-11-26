##################################################################################################################
#Evaluation Script - Rhabdomyolysis
#
#This script checks an account to see if it matches criteria to be alerted for Rhabdomyolysis
#Date - 11/25/2024
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

#========================================
#  Script Specific Constants
#========================================
codeDic = {
    "M62.82": "Rhabdomyolysis",
    "T79.6XXA": "Traumatic ischemia of muscle, initial encounter (Truamatic Rhabdomyolysis)",
    "T79.6XXD": "Traumatic ischemia of muscle, subsequent encounter (Truamatic Rhabdomyolysis)",
    "T79.6XXS": "Traumatic ischemia of muscle, sequela (Truamatic Rhabdomyolysis)"
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
dvAldolase = ["ALDOLASE"]
calcAldolase1 = lambda x: x > 7.7
dvCKMB = ["CKMB (ng/mL)"]
calcCKMB1 = lambda x: x > 5
dvCKMBIndex = [""]
calcCKMBindex1 = lambda x: x > 2.5
dvGlasgowComaScale = ["3.5 Neuro Glasgow Score"]
calcGlasgowComaScale1 = lambda x: x < 15
dvHeartRate = ["Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)", "3.5 Heart Rate (Radial) (bpm)",  "SCC Monitor Pulse (bpm)"]
calcHeartRate1 = lambda x: x > 90
dvKinase = ["CPK (U/L)"]
calcKinase1 = lambda x: x > 1500
calcKinase2 = lambda x: x > 308
dvMAP = ["Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)"]
calcMAP1 = lambda x: x < 70
dvSBP = ["SBP 3.5 (No Calculation) (mm Hg)"]
calcSBP1 = lambda x: x < 90
dvSerumBloodUreaNitrogen = ["BUN (mg/dL)"]
calcSerumBloodUreaNitrogen1 = lambda x: x > 23
dvSerumCreatinine = ["CREATININE (mg/dL)", "CREATININE SERUM (mg/dL)"]
calcSerumCreatinine1 = lambda x: x > 1.3
dvSerumPotassium = ["POTASSIUM (mmol/L)"]
calcSerumPotassium1 = lambda x: x > 5.1
dvTemperature = ["Temperature Degrees C 3.5 (degrees C)", "Temperature  Degrees C 3.5 (degrees C)", "TEMPERATURE (C)"]
calcTemperature1 = lambda x: x > 38.3
calcTemperature2 = lambda x: x < 36.0

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
triggerAlert = True
reason = None
dcLinks = False
absLinks = False
contriLinks = False
labsLinks = False
medsLinks = False
vitalsLinks = False

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 2)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 3)
vitals = MatchedCriteriaLink("Vital Signs", None, "Vital Signs", None, True, None, None, 4)
meds = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 5)
contri = MatchedCriteriaLink("Contributing Dx", None, "Contributing Dx", None, True, None, None, 6)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 7)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Rhabdomyolysis-Elevated CK':
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
    #Negations
    negationKidneyFailure = multiCodeValue(["N18.1", "N18.2 ", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6"], "Kidney Failure Codes: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Labs
    kinaseDV = dvValue(dvKinase, "Creatine Kinase: [VALUE] (Result Date: [RESULTDATETIME])", calcKinase1, 3)
    kinase2DV = dvValue(dvKinase, "Creatine Kinase: [VALUE] (Result Date: [RESULTDATETIME])", calcKinase2, 3)

    #Main Algorithm
    if subtitle == "Rhabdomyolysis Dx Lacking Supporting Evidence" and kinase2DV is not None:
        if kinase2DV is not None: updateLinkText(kinase2DV, autoEvidenceText); labs.Links.Add(kinase2DV)
        result.Validated = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Evidence Existing on the Account"
        AlertConditions = True
        
    elif triggerAlert and codesExist == 1 and kinase2DV is None:
        for code in codeList:
            desc = codeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            dc.Links.Add(tempCode)
        result.Subtitle = "Rhabdomyolysis Dx Lacking Supporting Evidence"
        AlertPassed = True
        
    elif codesExist > 1:
        for code in codeList:
            desc = codeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            dc.Links.Add(tempCode)
        if validated:
            result.Validated = False
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"    
        AlertPassed = True
        result.Subtitle = "Conflicting Rhabdomyolysis Dx Codes " + str1
        
    elif subtitle == "Possible Rhabdomyolysis Dx" and codesExist > 0:
        for code in codeList:
            desc = codeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] ([DOCUMENTTYPE], [DOCUMENTDATE])")
            if tempCode is not None:
                dc.Links.Add(tempCode)
                break
        result.Validated = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Dx on the Account"
        AlertConditions = True

    elif triggerAlert and codesExist == 0 and kinaseDV is not None:
        result.Subtitle = "Possible Rhabdomyolysis Dx"
        AlertPassed = True
        
    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Abs
    multiCodeValue(["N17.0", "N17.1", "N17.2", "N17.8", "N17.9"], "Acute Kidney Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, abs, True)
    multiCodeValue(["I46.2", "I46.8", "I46.9"], "Cardiac Arrest: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, abs, True)
    multiCodeValue(["F14.920", "F14.921", "F14.922", "F14.929"], "Cocaine Intoxication: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, abs, True)
    abstractValue("DARK_COLORED_URINE", "Dark Colored Urine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4, abs, True)
    codeValue("R41.0", "Disorientation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, abs, True)
    prefixCodeValue("^D65\.", "Disseminated Intravascular Coagulation (DIC): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, abs, True)
    multiCodeValue(["W06", "W07", "W08", "W09.0", "W09.1", "W09.2", "W09.8", "W10.0", "W10.1", "W10.2", "W11", "W12", "W13.0", "W13.2", "W13.3",
        "W13.4", "W13.8", "W13.9", "W14", "W15", "W17.0", "W17.2", "W17.3", "W17.4", "W17.81", "W17.82", "W17.89", "W18.00", "W18.01", "W18.02",
        "W18.09", "W18.11", "W18.12", "W18.2", "W18.30", "W18.31", "W18.39", "W19"], "Fall: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, abs, True)
    codeValue("R53.83", "Fatigue: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8, abs, True)
    abstractValue("FLUID_BOLUS", "Fluid Bolus: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, abs, True)
    codeValue("R57.1", "Hypovolemic Shock: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, abs, True)
    abstractValue("MUSCLE_CRAMPS", "Muscle Cramps '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11, abs, True)
    codeValue("M79.10", "Myalgia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, abs, True)
    codeValue("R82.1", "Myoglobinuria: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13, abs, True)
    abstractValue("LOW_URINE_OUTPUT", "Oliguria '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 14, abs, True)
    codeValue("R29.6", "Repeated Falls: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
    codeValue("R56.9", "Seizure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, abs, True)
    codeValue("E86.0", "Severe Dehydration: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17, abs, True)
    codeValue("R57.9", "Shock: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, abs, True)
    multiCodeValue(["F15.120", "F15.121", "F15.122", "F15.129"], "Stimulant Intoxication: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19, abs, True)
    codeValue("E86.9", "Volume Depleted: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20, abs, True)
    codeValue("R11.10", "Vomiting: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21, abs, True)
    abstractValue("WEAKNESS", "Weakness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 22, abs, True)
    #Contri
    prefixCodeValue("^T79\.A", "Compartement Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, contri, True)
    prefixCodeValue("^G71\.2", "Congenital Myopathy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, contri, True)
    codeValue("T88.3XXA", "Malignant Hyperthermia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, contri, True)
    codeValue("G74.04", "McArdles Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, contri, True)
    prefixCodeValue("^T07\.", "Multiple Injuries: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, contri, True)
    prefixCodeValue("^G71\.0", "Muscular Dystrophy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, contri, True)
    codeValue("G35", "Multiple Sclerosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, contri, True)
    prefixCodeValue("^G72\.", "Myopathy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8, contri, True)
    prefixCodeValue("^T31\.1", "Third Degree Burn: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, contri, True)
    prefixCodeValue("^T31\.2", "Third Degree Burn: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, contri, True)
    prefixCodeValue("^T31\.3", "Third Degree Burn: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, contri, True)
    prefixCodeValue("^T31\.4", "Third Degree Burn: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, contri, True)
    prefixCodeValue("^T31\.5", "Third Degree Burn: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, contri, True)
    prefixCodeValue("^T31\.6", "Third Degree Burn: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, contri, True)
    prefixCodeValue("^T31\.7", "Third Degree Burn: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, contri, True)
    prefixCodeValue("^T31\.8", "Third Degree Burn: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, contri, True)
    prefixCodeValue("^T31\.9", "Third Degree Burn: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, contri, True)
    prefixCodeValue("^T32\.1", "Third Degree Corrosion Burn: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, contri, True)
    prefixCodeValue("^T32\.2", "Third Degree Corrosion Burn: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, contri, True)
    prefixCodeValue("^T32\.3", "Third Degree Corrosion Burn: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, contri, True)
    prefixCodeValue("^T32\.4", "Third Degree Corrosion Burn: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, contri, True)
    prefixCodeValue("^T32\.5", "Third Degree Corrosion Burn: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, contri, True)
    prefixCodeValue("^T32\.6", "Third Degree Corrosion Burn: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, contri, True)
    prefixCodeValue("^T32\.7", "Third Degree Corrosion Burn: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, contri, True)
    prefixCodeValue("^T32\.8", "Third Degree Corrosion Burn: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, contri, True)
    prefixCodeValue("^T32\.9", "Third Degree Corrosion Burn: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, contri, True)
    #Labs
    dvValue(dvAldolase, "Aldolase: [VALUE] (Result Date: [RESULTDATETIME])", calcAldolase1, 1, labs, True)
    dvValue(dvCKMB, "CK-MB: [VALUE] (Result Date: [RESULTDATETIME])", calcCKMB1, 2, labs, True)
    dvValue(dvCKMBIndex, "CK-MB Index: [VALUE] (Result Date: [RESULTDATETIME])", calcCKMBindex1, 3, labs, True)
    if kinaseDV is not None: labs.Links.Add(kinaseDV) #4
    if negationKidneyFailure is None:
        dvValue(dvSerumBloodUreaNitrogen, "Serum Blood Urea Nitrogen: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumBloodUreaNitrogen1, 5, labs, True)
    if negationKidneyFailure is None:
        dvValue(dvSerumCreatinine, "Serum Creatinine: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumCreatinine1, 6, labs, True)
    dvValue(dvSerumPotassium, "Serum Potassium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumPotassium1, 7, labs, True)
    #Meds    
    medValue("Albumin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, meds, True)
    medValue("Fluid Bolus", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 2, meds, True)
    #Vitals
    r4182Code = codeValue("R41.82", "Altered Level Of Consciousness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    alteredAbs = abstractValue("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level Of Consciousness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2)
    if r4182Code is not None:
        vitals.Links.Add(r4182Code)
        if alteredAbs is not None: alteredAbs.Hidden = True; vitals.Links.Add(alteredAbs)
    elif r4182Code is None and alteredAbs is not None:
        vitals.Links.Add(alteredAbs)
    abstractValue("LOW_BLOOD_PRESSURE", "Blood Pressure: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3, vitals, True)
    dvValue(dvGlasgowComaScale, "Glasgow Coma Score: [VALUE] (Result Date: [RESULTDATETIME])", calcGlasgowComaScale1, 4, vitals, True)
    dvValue(dvHeartRate, "Heart Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcHeartRate1, 5, vitals, True)
    dvValue(dvMAP, "Mean Arterial Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcMAP1, 6, vitals, True)
    dvValue(dvSBP, "Systolic Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcSBP1, 7, vitals, True)
    dvValue(dvTemperature, "Temperature: [VALUE] (Result Date: [RESULTDATETIME])", calcTemperature1, 8, vitals, True)
    dvValue(dvTemperature, "Temperature: [VALUE] (Result Date: [RESULTDATETIME])", calcTemperature2, 9, vitals, True)

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if contri.Links: result.Links.Add(contri); contriLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    if vitals.Links: result.Links.Add(vitals); vitalsLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Documented Dx- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks) + ", vitals- " + str(vitalsLinks) + ", meds- " + str(medsLinks) + ", contri- "
        + str(contriLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
