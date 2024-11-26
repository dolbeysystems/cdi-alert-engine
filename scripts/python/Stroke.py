##################################################################################################################
#Evaluation Script - Stroke
#
#This script checks an account to see if it matches criteria to be alerted for Stroke
#Date - 10/24/2024
#Version - V17
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
    "I61.0": "Nontraumatic Intracerebral Hemorrhage In Hemisphere, Subcortical",
    "I61.1": "Nontraumatic Intracerebral Hemorrhage In Hemisphere, Cortical",
    "I61.3": "Nontraumatic Intracerebral Hemorrhage In Brain Stem",
    "I61.4": "Nontraumatic Intracerebral Hemorrhage In Cerebellum",
    "I61.5": "Nontraumatic Intracerebral Hemorrhage, Intraventricular",
    "I61.6": "Nontraumatic Intracerebral Hemorrhage, Multiple Localized",
    "I63.011": "Cerebral Infarction Due To Thrombosis Of Right Vertebral Artery",
    "I63.012": "Cerebral Infarction Due To Thrombosis Of Left Vertebral Artery",
    "I63.013": "Cerebral Infarction Due To Thrombosis Of Bilateral Vertebral Arteries",
    "I63.031": "Cerebral Infarction Due To Thrombosis Of Right Carotid Artery",
    "I63.032": "Cerebral Infarction Due To Thrombosis Of Left Carotid Artery",
    "I63.033": "Cerebral Infarction Due To Thrombosis Of Bilateral Carotid Arteries",
    "I63.311": "Cerebral Infarction Due To Thrombosis Of Right Middle Cerebral Artery",
    "I63.312": "Cerebral Infarction Due To Thrombosis Of Left Middle Cerebral Artery",
    "I63.313": "Cerebral Infarction Due To Thrombosis Of Bilateral Middle Cerebral Arteries",
    "I63.321": "Cerebral Infarction Due To Thrombosis Of Right Anterior Cerebral Artery",
    "I63.322": "Cerebral Infarction Due To Thrombosis Of Left Anterior Cerebral Artery",
    "I63.323": "Cerebral Infarction Due To Thrombosis Of Bilateral Anterior Cerebral Arteries",
    "I63.331": "Cerebral Infarction Due To Thrombosis Of Right Posterior Cerebral Artery",
    "I63.332": "Cerebral Infarction Due To Thrombosis Of Left Posterior Cerebral Artery",
    "I63.333": "Cerebral Infarction Due To Thrombosis Of Bilateral Posterior Cerebral Arteries",
    "I63.341": "Cerebral Infarction Due To Thrombosis Of Right Cerebellar Artery",
    "I63.342": "Cerebral Infarction Due To Thrombosis Of Left Cerebellar Artery",
    "I63.343": "Cerebral Infarction Due To Thrombosis Of Bilateral Cerebellar Arteries",
    "I63.411": "Cerebral Infarction Due To Embolism Of Right Middle Cerebral Artery",
    "I63.412": "Cerebral Infarction Due To Embolism Of Left Middle Cerebral Artery",
    "I63.413": "Cerebral Infarction Due To Embolism Of Bilateral Middle Cerebral Arteries",
    "I63.421": "Cerebral Infarction Due To Embolism Of Right Anterior Cerebral Artery",
    "I63.422": "Cerebral Infarction Due To Embolism Of Left Anterior Cerebral Artery",
    "I63.423": "Cerebral Infarction Due To Embolism Of Bilateral Anterior Cerebral Arteries",
    "I63.431": "Cerebral Infarction Due To Embolism Of Right Posterior Cerebral Artery",
    "I63.432": "Cerebral Infarction Due To Embolism Of Left Posterior Cerebral Artery",
    "I63.433": "Cerebral Infarction Due To Embolism Of Bilateral Posterior Cerebral Arteries",
    "I63.441": "Cerebral Infarction Due To Embolism Of Right Cerebellar Artery",
    "I63.442": "Cerebral Infarction Due To Embolism Of Left Cerebellar Artery",
    "I63.443": "Cerebral Infarction Due To Embolism Of Bilateral Cerebellar Arteries",
    "I63.6": "Cerebral Infarction Due To Cerebral Venous Thrombosis, Nonpyogenic",
    "G45.9": "Transient Cerebral Ischemic Attack, Unspecified",
    "I63.00": "Cerebral infarction due to thrombosis of unspecified precerebral artery",
    "I63.019": "Cerebral infarction due to thrombosis of unspecified vertebral artery",
    "I63.02": "Cerebral infarction due to thrombosis of basilar artery",
    "I63.019": "Cerebral infarction due to thrombosis of unspecified vertebral artery",
    "I63.02": "Cerebral infarction due to thrombosis of basilar artery",
    "I63.039": "Cerebral infarction due to thrombosis of unspecified carotid artery",
    "I63.09": "Cerebral infarction due to thrombosis of other precerebral artery",
    "I63.10": "Cerebral infarction due to embolism of unspecified precerebral artery",
    "I63.111": "Cerebral infarction due to embolism of right vertebral artery",
    "I63.112": "Cerebral infarction due to embolism of left vertebral artery",
    "I63.113": "Cerebral infarction due to embolism of bilateral vertebral arteries",
    "I63.119": "Cerebral infarction due to embolism of unspecified vertebral artery",
    "I63.12": "Cerebral infarction due to embolism of basilar artery",
    "I63.131": "Cerebral infarction due to embolism of right carotid artery",
    "I63.132": "Cerebral infarction due to embolism of left carotid artery",
    "I63.133": "Cerebral infarction due to embolism of bilateral carotid arteries",
    "I63.139": "Cerebral infarction due to embolism of unspecified carotid artery",
    "I63.19": "Cerebral infarction due to embolism of other precerebral artery",
    "I63.20": "Cerebral infarction due to unspecified occlusion or stenosis of unspecified precerebral arteries",
    "I63.211": "Cerebral infarction due to unspecified occlusion or stenosis of right vertebral artery",
    "I63.212": "Cerebral infarction due to unspecified occlusion or stenosis of left vertebral artery",
    "I63.213": "Cerebral infarction due to unspecified occlusion or stenosis of bilateral vertebral arteries",
    "I63.219": "Cerebral infarction due to unspecified occlusion or stenosis of unspecified vertebral artery",
    "I63.22": "Cerebral infarction due to unspecified occlusion or stenosis of basilar artery",
    "I63.231": "Cerebral infarction due to unspecified occlusion or stenosis of right carotid arteries",
    "I63.232": "Cerebral infarction due to unspecified occlusion or stenosis of left carotid arteries",
    "I63.233": "Cerebral infarction due to unspecified occlusion or stenosis of bilateral carotid arteries",
    "I63.239": "Cerebral infarction due to unspecified occlusion or stenosis of unspecified carotid artery",
    "I63.29": "Cerebral infarction due to unspecified occlusion or stenosis of other precerebral arteries",
    "I63.30": "Cerebral infarction due to thrombosis of unspecified cerebral artery",
    "I63.319": "Cerebral infarction due to thrombosis of unspecified middle cerebral artery",
    "I63.329": "Cerebral infarction due to thrombosis of unspecified anterior cerebral artery",
    "I63.339": "Cerebral infarction due to thrombosis of unspecified posterior cerebral artery",
    "I63.349": "Cerebral infarction due to thrombosis of unspecified cerebellar artery",
    "I63.39": "Cerebral infarction due to thrombosis of other cerebral artery",
    "I63.40": "Cerebral infarction due to embolism of unspecified cerebral artery",
    "I63.419": "Cerebral infarction due to embolism of unspecified middle cerebral artery",
    "I63.429": "Cerebral infarction due to embolism of unspecified anterior cerebral artery",
    "I63.439": "Cerebral infarction due to embolism of unspecified posterior cerebral artery",
    "I63.449": "Cerebral infarction due to embolism of unspecified cerebellar artery",
    "I63.50": "Cerebral infarction due to unspecified occlusion or stenosis of unspecified cerebral artery",
    "I63.511": "Cerebral infarction due to unspecified occlusion or stenosis of right middle cerebral artery",
    "I63.512": "Cerebral infarction due to unspecified occlusion or stenosis of left middle cerebral artery",
    "I63.513": "Cerebral infarction due to unspecified occlusion or stenosis of bilateral middle cerebral arteries",
    "I63.519": "Cerebral infarction due to unspecified occlusion or stenosis of unspecified middle cerebral artery",
    "I63.521": "Cerebral infarction due to unspecified occlusion or stenosis of right anterior cerebral artery ",
    "I63.522": "Cerebral infarction due to unspecified occlusion or stenosis of left anterior cerebral artery",
    "I63.523": "Cerebral infarction due to unspecified occlusion or stenosis of bilateral anterior cerebral arteries ",
    "I63.529": "Cerebral infarction due to unspecified occlusion or stenosis of unspecified anterior cerebral artery ",
    "I63.53": "Cerebral infarction due to unspecified occlusion or stenosis of posterior cerebral artery",
    "I63.531": "Cerebral infarction due to unspecified occlusion or stenosis of right posterior cerebral artery ",
    "I63.532": "Cerebral infarction due to unspecified occlusion or stenosis of left posterior cerebral artery ",
    "I63.533": "Cerebral infarction due to unspecified occlusion or stenosis of bilateral posterior cerebral arteries ",
    "I63.539": "Cerebral infarction due to unspecified occlusion or stenosis of unspecified posterior cerebral artery",
    "I63.54": "Cerebral infarction due to unspecified occlusion or stenosis of cerebellar artery",
    "I63.541": "Cerebral infarction due to unspecified occlusion or stenosis of right cerebellar artery ",
    "I63.542": "Cerebral infarction due to unspecified occlusion or stenosis of left cerebellar artery ",
    "I63.543": "Cerebral infarction due to unspecified occlusion or stenosis of bilateral cerebellar arteries",
    "I63.549": "Cerebral infarction due to unspecified occlusion or stenosis of unspecified cerebellar artery ",
    "I63.59": "Cerebral infarction due to unspecified occlusion or stenosis of other cerebral artery",
    "I63.81": "Other cerebral infarction due to occlusion or stenosis of small artery",
    "I63.89": "Other cerebral infarction",
    "I63.9": "Cerebral infarction, unspecified"
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
accountContainer = AccountWorkflowContainer(account, False, "Category", 7)
useSeperateDiscreteCollection = False
if useSeperateDiscreteCollection == True:
    discreteValues = db.GetDiscreteValues(account._id)
else:
    discreteValues = db.GetAccountField(account._id, "DiscreteValues")

#========================================
#  Discrete Value Fields and Calculations
#========================================
dvDBP = ["BP Arterial Diastolic cc (mm Hg)", "DBP 3.5 (No Calculation) (mmhg)", "DBP 3.5 (No Calculation) (mm Hg)"]
calcDBP1 = lambda x: x > 110
dvGlasgowComaScale = ["3.5 Neuro Glasgow Score"]
calcGlasgowComaScale1 = lambda x: x <= 14
dvSBP = ["SBP 3.5 (No Calculation) (mm Hg)"]
calcSBP1 = lambda x: x > 180

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
    date_time = datetimeFromUtcToLocal(datetime)
    date_time = date_time.ToString("MM/dd/yyyy, HH:mm")
    linkText = linkText.replace("[RESULTDATETIME]", date_time)
    linkText = linkText.replace("[VALUE]", Result)
    if gender: linkText = linkText.replace("[GENDER]", gender)
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
dcLinks = False
absLinks = False
procLinks = False
vitalsLinks = False
medsLinks = False
contriLinks = False
docLinksLinks = False

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 2)
proc = MatchedCriteriaLink("Procedure", None, "Procedure", None, True, None, None, 3)
contri = MatchedCriteriaLink("Contributing Dx", None, "Contributing Dx", None, True, None, None, 4)
meds = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 5)
vitals = MatchedCriteriaLink("Vital Signs/Intake and Output Data", None, "Vital Signs/Intake and Output Data", None, True, None, None, 6)
ctBrainLinks = MatchedCriteriaLink("CT Brain", None, "CT Brain", None, True, None, None, 7)
mriBrainLinks = MatchedCriteriaLink("MRI Brain", None, "MRI Brain", None, True, None, None, 7)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 8)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Stroke':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        subtitle = alert.Subtitle
        break

#Check if alert was autoresolved or completed.
if validated is False:
    #Alert Triggers
    hemorrhagicStrokeCode = multiCodeValue(["I61.2", "I61.8", "I61.9"], "Unspecified Hemorrhagic Stroke Dx Missing Location: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    cerebralInfarctionCodes = multiCodeValue(["I63.51", "I63.511", "I63.512", "I63.513", "I63.521", "I63.522", "I63.523", "I63.531",
                                        "I63.532", "I63.533", "I63.541", "I63.542", "I63.543", "I63.50", "I63.519", "I63.529", "I63.539", "I63.549", "I63.59", "I63.81",
                                        "I63.81", "I63.89", "I63.9", "I63.00", "I63.019", "I63.039", "I63.30", "I63.319", "I63.329", "I63.339", "I63.349", "I63.39",
                                        "I63.40", "I63.419", "I63.429", "I63.439", "I63.449", "I63.49", "I63.09"],
                                        "Cerebral Infarction Codes: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    g649Code = codeValue("G64.9", "TIA: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    cerebralIschemiaAbs = abstractValue("CEREBRAL_ISCHEMIA", "Cerebral Ischemia: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    cerebralInfarctionAbs = abstractValue("CEREBRAL_INFARCTION", "Cerebral Infarction: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    #Abs
    abortedStrokeAbs = abstractValue("ABORTED_STROKE", "Aborted Stroke: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1)
    
    #Starting Main Algorithm
    if codesExist > 0:
        db.LogEvaluationScriptMessage("One specific code was on the chart, alert failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        if alertTriggered:
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
        else: result.Passed = False
        
    if cerebralInfarctionCodes is not None and (subtitle == "TIA documented Possible Cerebral Infarction seek Clarification" or subtitle == "Possible Cerebral Infarction"):
        dc.Links.Add(cerebralInfarctionCodes)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    
    elif g649Code is not None and cerebralInfarctionCodes is None and (cerebralInfarctionAbs is not None or cerebralIschemiaAbs is not None or abortedStrokeAbs is not None):
        dc.Links.Add(g649Code)
        if cerebralInfarctionAbs is not None: dc.Links.Add(cerebralInfarctionAbs)
        if cerebralIschemiaAbs is not None: dc.Links.Add(cerebralIschemiaAbs)
        result.Subtitle = "TIA documented Possible Cerebral Infarction seek Clarification"
        AlertPassed = True
    
    elif cerebralInfarctionCodes is None and (cerebralInfarctionAbs is not None or cerebralIschemiaAbs is not None):
        if cerebralInfarctionAbs is not None: dc.Links.Add(cerebralInfarctionAbs)
        if cerebralIschemiaAbs is not None: dc.Links.Add(cerebralIschemiaAbs)
        result.Subtitle = "Possible Cerebral Infarction"
        AlertPassed = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Abs
    if abortedStrokeAbs is not None: abs.Links.Add(abortedStrokeAbs) #1
    codeValue("R47.01", "Aphasia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, abs, True)
    abstractValue("ATAXIA", "Ataxia '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3, abs, True)
    multiCodeValue(["I48.0", "I48.1", "I48.11", "I48.19", "I48.20", "I48.21", "I48.91"], "Atrial Fibrillation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, abs, True)
    multiCodeValue(["Q21.10", "Q21.11", "Q21.13", "Q21.14", "Q21.15", "Q21.16", "Q21.19"], "Atrial Septal Defect: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, abs, True)
    codeValue("I65.23", "Carotid Artery Stenosis - Bilateral: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, abs, True)
    codeValue("I65.22", "Carotid Artery Stenosis - Left: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, abs, True)
    codeValue("I65.21", "Carotid Artery Stenosis - Right: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8, abs, True)
    codeValue("I65.29", "Carotid Artery Stenosis - Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, abs, True)
    codeValue("I67.1", "Cerebral Aneurysm, Nonruptured: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, abs, True)
    codeValue("I67.2", "Cerebral Atherosclerotic Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, abs, True)
    codeValue("I67.848", "Cerebrovascular Vasospasm and Vasocontriction: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, abs, True)
    codeValue("R41.0", "Confusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13, abs, True)
    codeValue("I67.0", "Dissection Of Cerebral Arteries, Nonruptured: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, abs, True)
    codeValue("R42", "Dizziness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
    codeValue("H53.2", "Double Vision: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, abs, True)
    codeValue("R47.02", "Dysphagia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17, abs, True)
    codeValue("R29.810", "Facial Droop: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, abs, True)
    abstractValue("FACIAL_NUMBNESS", "Facial Numbness: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 19, abs, True)
    codeValue("R29.810", "Facial Droop: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20, abs, True)
    abstractValue("HEADACHE", "Headache '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 21, abs, True)
    multiCodeValue(["G81.00", "G81.01", "G81.02", "G81.03", "G81.04", "G81.1", "G81.10", "G81.11", "G81.12", "G81.13", "G81.14", "G81.90", "G81.91", "G81.92", "G81.93", "G81.94"], "Hemiplegia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 22, abs, True)
    multiCodeValue(["I69.351", "I69.352", "I69.353", "I69.354", "I69.359"], "Hemiplegia/Hemiparesis following Cerebral Infarction: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23, abs, True)
    multiCodeValue(["G81.00", "G81.10", "G81.90"], "Hemiplegia/Hemiparesis Unspecified Side: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 24, abs, True)
    codeValue("Z82.3", "History of Stroke: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 25, abs, True)
    codeValue("I10", "HTN: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 26, abs, True)
    codeValue("Z86.73", "Hx Of Stroke/TIA: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 27, abs, True)
    multiCodeValue(["I16.0", "I16.1", "I16.9"], "Hypertensive Crisis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 28, abs, True)
    multiCodeValue(["G81.02", "G81.04", "G81.12", "G81.14", "G81.92", "G81.94"], "Left Hemiplegia/Hemiparesis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 29, abs, True)
    abstractValue("LEFT_INTERNAL_CAROTID_STENOSIS", "Left Internal Carotid Stenosis: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 30, abs, True)
    codeValue("I65.03", "Occlusion and Stenosis Of Bilateral Vertebral Arteries: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 31, abs, True)
    codeValue("I65.02", "Occlusion and Stenosis Left Vertebral Artery: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 32, abs, True)
    codeValue("I66.10", "Occlusion and Stenosis Of Anterior Cerebral Artery: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 33, abs, True)
    codeValue("I66.13", "Occlusion and Stenosis Of Bilateral Anterior Cerebral Artery: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 34, abs, True)
    codeValue("I66.03", "Occlusion and Stenosis Of Bilateral Middle Cerebral Artery: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 35, abs, True)
    codeValue("I66.23", "Occlusion and Stenosis Of Bilateral Posterior Cerebral Artery: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 36, abs, True)
    codeValue("I66.3", "Occlusion and Stenosis Of Cerebellar Artery: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 37, abs, True)
    codeValue("I66.12", "Occlusion and Stenosis Of Left Anterior Cerebral Artery: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 38, abs, True)
    codeValue("I66.02", "Occlusion and Stenosis Of Left Middle Cerebral Artery: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 39, abs, True)
    codeValue("I66.22", "Occlusion and Stenosis Of Left Posterior Cerebral Artery: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 40, abs, True)
    codeValue("I66.8", "Occlusion and Stenosis Of Other Cerebral Arteries: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 41, abs, True)
    codeValue("I65.8", "Occlusion and Stenosis Of Other Precerebral Arteries: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 42, abs, True)
    codeValue("I66.2", "Occlusion and Stenosis Of Posterior Cerebral Artery: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 43, abs, True)
    codeValue("I66.11", "Occlusion and Stenosis Of Right Anterior Cerebral Artery: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 44, abs, True)
    codeValue("I66.01", "Occlusion and Stenosis Of Right Middle Cerebral Artery: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 45, abs, True)
    codeValue("I66.21", "Occlusion and Stenosis Of Right Posterior Cerebral Artery: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 46, abs, True)
    codeValue("I66.19", "Occlusion and Stenosis Of Unspecified Anterior Cerebral Artery: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 47, abs, True)
    codeValue("I66.9", "Occlusion and Stenosis Of Unspecified Cerebral Artery: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 48, abs, True)
    codeValue("I66.29", "Occlusion and Stenosis Of Unspecified Posterior Cerebral Artery: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 49, abs, True)
    codeValue("I65.9", "Occlusion and Stenosis Of Unspecified Precerebral Arteries: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 50, abs, True)
    codeValue("I65.09", "Occlusion and Stenosis Of Unspecified Vertebral Artery: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 51, abs, True)
    codeValue("I65.01", "Occlusion and Stenosis Right Vertebral Artery: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 52, abs, True)
    codeValue("Q21.12", "Patent Foramen Ovale (PFO): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 53, abs, True)
    codeValue("I67.841", "Reveresible Cerebrovascular Vasospasm and Vasocontriction: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 54, abs, True)
    multiCodeValue(["G81.01", "G81.03", "G81.11", "G81.13", "G81.91", "G81.93"], "Right Hemiplegia/Hemiparesis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 55, abs, True)
    abstractValue("RIGHT_INTERNAL_CAROTID_STENOSIS", "Right Internal Carotid Stenosis: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 56, abs, True)
    codeValue("R56.9", "Seizure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 57, abs, True)
    codeValue("R47.81", "Slurred Speech: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 58, abs, True)
    codeValue("Q21.0", "Ventricular Septal Defect: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 59, abs, True)
    abstractValue("VOMITING", "Vomiting '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 60, abs, True)
    #Contributing DX
    codeValue("D68.51", "Activated Protein C Resistance: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, contri, True)
    codeValue("F10.20", "Alcohol Abuse: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, contri, True)
    codeValue("D68.61", "Antiphospholipid Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, contri, True)
    prefixCodeValue("^F14\.", "Cocaine Use: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, contri, True)
    codeValue("D68.59", "Hypercoagulable State: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, contri, True)
    codeValue("D68.62", "Lupus Anticoagulant Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, contri, True)
    multiCodeValue(["E66.01", "E66.2"], "Morbid Obesity: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, contri, True)
    prefixCodeValue("^F17\.", "Nicotine Dependence: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8, contri, True)
    codeValue("D68.69", "Other Thrombophilia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, contri, True)
    codeValue("D68.52", "Prothrombin Gene Mutation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, contri, True)
    prefixCodeValue("^F15\.", "Stimulant Use: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, contri, True)
    #Document Links
    documentLink("CT Head WO", "CT Head WO", 0, ctBrainLinks, True)
    documentLink("CT Head Stroke Alert", "CT Head Stroke Alert", 0, ctBrainLinks, True)
    documentLink("CTA Head-Neck", "CTA Head-Neck", 0, ctBrainLinks, True)
    documentLink("CTA Head", "CTA Head", 0, ctBrainLinks, True)
    documentLink("CT Head  WWO", "CT Head  WWO", 0, ctBrainLinks, True)
    documentLink("CT Head  W", "CT Head  W", 0, ctBrainLinks, True)
    documentLink("MRI Brain WWO", "MRI Brain WWO", 0, mriBrainLinks, True)
    documentLink("MRI Brain  W and W/O Contrast", "MRI Brain  W and W/O Contrast", 0, mriBrainLinks, True)
    documentLink("WO", "WO", 0, mriBrainLinks, True)
    documentLink("MRI Brain W/O Contrast", "MRI Brain W/O Contrast", 0, mriBrainLinks, True)
    documentLink("MRI Brain W/O Con", "MRI Brain W/O Con", 0, mriBrainLinks, True)
    documentLink("MRI Brain  W and W/O Con", "MRI Brain  W and W/O Con", 0, mriBrainLinks, True)
    documentLink("MRI Brain  W", "MRI Brain  W", 0, mriBrainLinks, True)
    documentLink("MRI Brain  W/ Contrast", "MRI Brain  W/ Contrast", 0, mriBrainLinks, True)
    #Meds
    medValue("Anticoagulant", "Anticoagulant: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, meds, True)
    abstractValue("ANTICOAGULANT", "Anticoagulant '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2, meds, True)
    medValue("Antiplatelet", "Antiplatelet: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 3, meds, True)
    medValue("Antiplatelet2", "Antiplatlet: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 4, meds, True)
    abstractValue("ANTIPLATELET", "Antiplatelet '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5, meds, True)
    medValue("Aspirin", "Aspirin: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 6, meds, True)
    medValue("Clot Supporting Therapy/Reversal Agents", "Clot Supporting Therapy/Reversal Agent: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 7, meds, True)
    abstractValue("CLOT_SUPPORTING_THERAPY", "Clot Supporting Therapy '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, meds, True)
    codeValue("30233M1", "Cryoprecipitate Transfusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, meds, True)
    codeValue("30233T1", "Fibrinogen Transfusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, meds, True)
    codeValue("30233K1", "Fresh Frozen Plasma Transfusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, meds, True)
    codeValue("30233R1", "Platelet Transfusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, meds, True)
    medValue("Thrombolytic", "Thrombolytic: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 13, meds, True)
    abstractValue("THROMBOLYTIC", "Thrombolytic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 14, meds, True)
    codeValue("3E03317", "TPA Peripheral Vein (IV): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, meds, True)
    #Proc
    codeValue("03CM0ZZ", "External Carotid Artery - Open Thrombectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, proc, True)
    codeValue("03CM3ZZ", "External Carotid Artery - Trans Catheter Thrombectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, proc, True)
    codeValue("03C20ZZ", "Innominate Artery - Open Thrombectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, proc, True)
    codeValue("03C23ZZ", "Innominate Artery - Trans Catheter Thrombectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, proc, True)
    codeValue("03CG0ZZ", "Intracranial - Open: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, proc, True)
    codeValue("03CG3ZZ", "Intracranial - Trans Catheter Thrombectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, proc, True)
    codeValue("03BG0ZZ", "Intracranial Artery Thrombectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, proc, True)
    codeValue("05BL0ZZ", "Intracranial Vein Thrombectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8, proc, True)
    codeValue("03CK0ZZ", "Internal Carotid Artery - Open: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, proc, True)
    codeValue("03CK3ZZ", "Internal Carotid Artery - Trans Catheter Thrombectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, proc, True)
    codeValue("03CQ0ZZ", "Left Vertebral Artery - Open Thrombectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, proc, True)
    codeValue("03CQ3ZZ", "Left Vertebral Artery - Trans Catheter Thrombectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, proc, True)
    codeValue("3E05317", "Peripheral Artery Thrombectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13, proc, True)
    codeValue("03CP0ZZ", "Right Vertebral Artery - Open Thrombectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, proc, True)
    codeValue("03CP3ZZ", "Right Vertebral Artery - Trans Catheter Thrombectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, proc, True)
    codeValue("03CH0ZZ", "Thrombectomy or Endarterectomy Common carotid artery - Open Thrombectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, proc, True)
    codeValue("03CH3ZZ", "Thrombectomy or Endarterectomy Common carotid artery - Trans Catheter Thrombectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17, proc, True)
    codeValue("03CY0ZZ", "Upper Artery - Open Thrombectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, proc, True)
    codeValue("03CY3ZZ", "Upper Artery - Trans Catheter Thrombectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19, proc, True)
    #Vitals
    r4182Code = codeValue("R41.82", "Altered Level Of Consciousness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    alteredAbs = abstractValue("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level Of Consciousness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2)
    if r4182Code is not None:
        vitals.Links.Add(r4182Code)
        if alteredAbs is not None: alteredAbs.Hidden = True; vitals.Links.Add(alteredAbs)
    elif r4182Code is None and alteredAbs is not None:
        vitals.Links.Add(alteredAbs)
    dvValue(dvDBP, "DBP: [VALUE] (Result Date: [RESULTDATETIME])", calcDBP1, 4, vitals, True)
    dvValue(dvSBP, "SBP: [VALUE] (Result Date: [RESULTDATETIME])", calcSBP1, 6, vitals, True)
    abstractValue("NIH_STROKE_SCALE_MINOR_CURRENT", "Current NIH Stroke Score: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, vitals, True)
    abstractValue("NIH_STROKE_SCALE_MODERATE_CURRENT", "Current NIH Stroke Score: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, vitals, True)
    abstractValue("NIH_STROKE_SCALE_MODERATE_TO_SEVERE_CURRENT", "Current NIH Stroke Score: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10, vitals, True)
    abstractValue("NIH_STROKE_SCALE_SEVERE_CURRENT", "Current NIH Stroke Score: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11, vitals, True)
    abstractValue("NIH_STROKE_SCALE_MINOR_INITIAL", "Initial NIH Stroke Score: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12, vitals, True)
    abstractValue("NIH_STROKE_SCALE_MODERATE_INITIAL", "Initial NIH Stroke Score: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13, vitals, True)
    abstractValue("NIH_STROKE_SCALE_MODERATE_TO_SEVERE_INITIAL", "Initial NIH Stroke Score: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 14, vitals, True)
    abstractValue("NIH_STROKE_SCALE_SEVERE_INITIAL", "Initial NIH Stroke Score: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 15, vitals, True)

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if proc.Links: result.Links.Add(proc); procLinks = True
    if vitals.Links: result.Links.Add(vitals); vitalsLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    if contri.Links: result.Links.Add(contri); contriLinks = True
    if mriBrainLinks.Links: result.Links.Add(mriBrainLinks); docLinksLinks = True
    if ctBrainLinks.Links: result.Links.Add(ctBrainLinks); docLinksLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Documentation Dx- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", vitals- " + str(vitalsLinks) + ", meds- " + str(medsLinks) + ", Proc- " + str(procLinks) + ", contri- "
        + str(contri) + ", docs- " + str(docLinksLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
