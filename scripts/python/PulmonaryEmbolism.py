##################################################################################################################
#Evaluation Script - Pulmonary Embolism
#
#This script checks an account to see if it matches criteria to be alerted for Pulmonary Embolism
#Date - 10/22/2024
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
   "I26.0": "Pulmonary embolism with Acute Cor Pulmonale",
   "I26.01": "Septic pulmonary embolism with acute cor pulmonale",
   "I26.02": "Saddle embolus of pulmonary artery with acute cor pulmonale",
   "I26.09": "Other pulmonary embolism with acute cor pulmonale"
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
dvBNP = ["BNP(NT proBNP) (pg/mL)"]
calcBNP1 = lambda x: x > 900
dvDDimer = ["D-DIMER (mg/L FEU)"]
calcDDimer1 = lambda x: x > 0.48
dvHeartRate = ["Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)", "3.5 Heart Rate (Radial) (bpm)",  "SCC Monitor Pulse (bpm)"]
calcHeartRate1 = lambda x: x > 90
dvOxygenTherapy = ["DELIVERY"]
dvPaO2 = ["BLD GAS O2 (mmHg)", "PO2 (mmHg)"]
calcPAO21 = lambda x: x < 80
dvProBNP = [""]
calcProBNP1 = lambda x: x > 900
dvPulmonaryPressure = [""]
calcPulmonaryPressure1 = lambda x: x > 30
dvRespiratoryRate = ["3.5 Respiratory Rate (#VS I&O) (per Minute)"]
calcRespiratoryRate1 = lambda x: x > 20

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
def dvOxygenCheck(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    abstraction = None
    for dv in dvDic or []:
        if (
            dvDic[dv]['Name'] in discreteValueName and
            dvDic[dv]['Result'] is not None and
            not re.search(r'\bRoom Air\b', dvDic[dv]['Result'], re.IGNORECASE) and
            not re.search(r'\bRA\b', dvDic[dv]['Result'], re.IGNORECASE)
        ):
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return abstraction
    return abstraction

#========================================
#  Algorithm
#========================================
db.LogEvaluationScriptMessage("Script starting " + str(account._id), scriptName, scriptInstance, "Debug")
#Determine if if and how many fully spec codes are on the acct
age = math.floor((admitDate - birthDate).TotalDays/ 365.2425)
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
SSCP = 0
dcLinks = False
absLinks = False
labsLinks = False
vitalsLinks = False
medsLinks = False
oxygenLinks = False
docLinksLinks = False

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 2)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 3)
vitals = MatchedCriteriaLink("Vital Signs/Intake and Output Data", None, "Vital Signs/Intake and Output Data", None, True, None, None, 4)
oxygen = MatchedCriteriaLink("Oxygenation/Ventilation", None, "Oxygenation/Ventilation", None, True, None, None, 5)
meds = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 6)
chestXRayLinks = MatchedCriteriaLink("Chest X-Ray", None, "Chest X-Ray", None, True, None, None, 7)
ctChestLinks = MatchedCriteriaLink("CT Chest", None, "CT Chest", None, True, None, None, 7)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 8)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Pulmonary Embolism':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        subtitle = alert.Subtitle
        if outcome == 'AUTORESOLVED' or reason == 'Previously Autoresolved':
            triggerAlert = False
        break

#Check if alert was autoresolved or completed.
if (
    validated is False or
    (outcome == "AUTORESOLVED" and validated and codesExist > 1)
):
    #Alert Trigger
    i2694Code = codeValue("I26.94", "Assigned Multiple Subsegmental Pulmonary Embolism without Acute Cor Pulmonale: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i2699Code = codeValue("I26.99", "Assigned Pulmonary Embolism without Acute Cor Pulmonale: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i2692Code = codeValue("I26.92", "Assigned Saddle Embolus without Acute Cor Pulmonale: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i2690Code = codeValue("I26.90", "Assigned Septic Pulmonary Embolism without Acute Cor Pulmonale: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i2693Code = codeValue("I26.93", "Assigned Single Subsegmental Pulmonary Embolism without Acute Cor Pulmonale: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    rightVentricleHypertropyAbs = abstractValue("RIGHT_VENTRICLE_HYPERTROPY", "Right Ventricular Hypertrophy '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    pulEmboAbs = abstractValue("PULMONARY_EMBOLISM", "Pulmonary Embolism '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    i50810Code = codeValue("I50.810", "Right Heart Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    heartStrainAbs = abstractValue("RIGHT_HEART_STRAIN", "Right Heart Strain '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    clotBurdenAbs = abstractValue("CLOT_BURDEN", "Clot Burden '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    
    #Main Algorithm
    if codesExist == 1:
        db.LogEvaluationScriptMessage("One specific code was on the chart, alert failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        if alertTriggered:
            for code in codeList:
                desc = codeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] '[PHRASE]' '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    dc.Links.Add(tempCode)
                    break
            result.Outcome = "AUTORESOLVED"
            result.Reason = "Autoresolved due to one Specified Code on the Account"
            result.Validated = True
            AlertConditions = True
        else: result.Passed = False
        
    elif codesExist >= 2:
        for code in codeList:
            desc = codeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            dc.Links.Add(tempCode)
        if validated:
            result.Validated = False
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"    
        AlertPassed = True
        result.Subtitle = "Possible Conflicting Pulmonary Embolism Dx Codes " + str1
        
    elif (
        triggerAlert and
        codesExist == 0 and
        (i2694Code is not None or i2699Code is not None or i2692Code is not None or i2690Code is not None or i2693Code is not None) and
        (rightVentricleHypertropyAbs is not None or heartStrainAbs is not None or i50810Code is not None or clotBurdenAbs is not None)
    ):
        if heartStrainAbs is not None: dc.Links.Add(heartStrainAbs)
        if i50810Code is not None: dc.Links.Add(i50810Code)
        if rightVentricleHypertropyAbs is not None: dc.Links.Add(rightVentricleHypertropyAbs)
        if i2694Code is not None: dc.Links.Add(i2694Code)
        if i2699Code is not None: dc.Links.Add(i2699Code)
        if i2692Code is not None: dc.Links.Add(i2692Code)
        if i2693Code is not None: dc.Links.Add(i2693Code)
        if i2690Code is not None: dc.Links.Add(i2690Code)
        if clotBurdenAbs is not None: dc.Links.Add(clotBurdenAbs)
        result.Subtitle = "Pulmonary Embolism Possible Acute Cor Pulmonale"
        AlertPassed = True
        
    elif (
        subtitle == "Pulmonary Embolism found only on Radiology Report" and 
        (codesExist > 0 or 
        i2699Code is not None or 
        i2690Code is not None or 
        i2692Code is not None or 
        i2693Code is not None or 
        i2694Code is not None)
    ):
        if codesExist > 0:
            for code in codeList:
                desc = codeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] '[PHRASE]' '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    dc.Links.Add(tempCode)
                    break
        if i2699Code is not None: updateLinkText(i2699Code, autoCodeText); dc.Links.Add(i2699Code)
        if i2690Code is not None: updateLinkText(i2690Code, autoCodeText); dc.Links.Add(i2690Code)
        if i2692Code is not None: updateLinkText(i2692Code, autoCodeText); dc.Links.Add(i2692Code)
        if i2693Code is not None: updateLinkText(i2693Code, autoCodeText); dc.Links.Add(i2693Code)
        if i2694Code is not None: updateLinkText(i2694Code, autoCodeText); dc.Links.Add(i2694Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
        
    elif (
        triggerAlert and
        i2694Code is None and i2699Code is None and i2692Code is None and i2690Code is None and i2693Code is None and
        codesExist == 0 and
        pulEmboAbs is not None
    ):
        if pulEmboAbs is not None: dc.Links.Add(pulEmboAbs)
        result.Subtitle = "Pulmonary Embolism found only on Radiology Report"
        AlertPassed = True
        
    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Find all discrete values for custom lookups within the last X days
    maindiscreteDic = {}
    unsortedDicsreteDic = {}
    dvCount = 0
    #Combine all items into one list to search against
    discreteSearchList = [i for j in [dvOxygenTherapy] for i in j]
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
    codeValue("D68.51", "Activated Protein C Resistance \"Factor V Liden\": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, abs, True)
    codeValue("R18.8", "Ascities: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, abs, True)
    codeValue("D68.61", "Antiphospholipid Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, abs, True)
    codeValue("R07.9", "Chest Pain: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, abs, True)
    codeValue("R05.9", "Cough: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, abs, True)
    abstractValue("CYANOSIS", "Cyanosis '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6, abs, True)
    codeValue("R06.00", "Dyspnea: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, abs, True)
    abstractValue("DYSPNEA_ON_EXERTION", "Dyspnea on Exertion '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, abs, True)
    multiCodeValue(["02FP3Z0", "02FQ3Z0", "02FR3Z0", "02FS3Z0", "02FT3Z0", "03F23Z0", "03F33Z0", "03F43Z0",
                      "03F53Z0", "03F63Z0", "03F73Z0", "03F83Z0", "03F93Z0", "03FA3Z0", "03FB3Z0", "03FC3Z0",
                      "03FY3Z0", "04FC3Z0", "04FD3Z0", "04FE3Z0", "04FF3Z0", "04FH3Z0", "04FJ3Z0", "04FK3Z0",
                      "04FL3Z0", "04FM3Z0", "04FN3Z0", "04FP3Z0", "04FQ3Z0", "04FR3Z0", "04FS3Z0", "04FT3Z0",
                      "04FU3Z0", "04FY3Z0", "05F33Z0", "05F43Z0", "05F53Z0", "05F63Z0", "05F73Z0", "05F83Z0",
                      "05F93Z0", "05FA3Z0", "05FB3Z0", "05FC3Z0", "05FD3Z0", "05FF3Z0", "05FY3Z0", "06FC3Z0",
                      "06FD3Z0", "06FF3Z0", "06FG3Z0", "06FH3Z0", "06FJ3Z0", "06FM3Z0", "06FN3Z0", "06FP3Z0",
                      "06FQ3Z0", "06FY3Z0"], "EKOS Therapy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, abs, True)
    codeValue("R04.2", "Hemoptysis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, abs, True)
    abstractValue("HEPATOMEGALY", "Hepatomegaly '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11, abs, True)
    abstractValue("JUGULAR_VEIN_DISTENTION", "Jugular Vein Distension '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12, abs, True)
    abstractValue("LOWER_EXTERMITY_EDEMA", "Lower Extermity Edema '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13, abs, True)
    codeValue("D68.62", "Lupus Anticoagulant Antiphospholipid Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, abs, True)
    codeValue("D68.59", "Other Primary Thrombophilia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
    codeValue("D68.69", "Other Thrombophilia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, abs, True)
    codeValue("R07.81", "Pleuritic Chest Pain: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17, abs, True)
    abstractValue("PULMONARY_EMBOLISM_PRESENT_ON_ADMISSION", "Pulmonary Embolism Present on Admission Document '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 18, abs, True)
    abstractValue("SHORTNESS_OF_BREATH_PULMONARY_EMBOLISM", "Shortness of Breath: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 19, abs, True)
    #Document Links
    documentLink("CT Thorax W", "CT Thorax W", 0, ctChestLinks, True)
    documentLink("CTA Thorax Aorta", "CTA Thorax Aorta", 0, ctChestLinks, True)
    documentLink("CT Thorax WO-Abd WO-Pel WO", "CT Thorax WO-Abd WO-Pel WO", 0, ctChestLinks, True)
    documentLink("CT Thorax WO", "CT Thorax WO", 0, ctChestLinks, True)
    documentLink("Chest  3 View", "Chest  3 View", 0, chestXRayLinks, True)
    documentLink("Chest  PA and Lateral", "Chest  PA and Lateral", 0, chestXRayLinks, True)
    documentLink("Chest  Portable", "Chest  Portable", 0, chestXRayLinks, True)
    documentLink("Chest PA and Lateral", "Chest PA and Lateral", 0, chestXRayLinks, True)
    documentLink("Chest  1 View", "Chest  1 View", 0, chestXRayLinks, True)
    #Labs
    dvValue(dvPaO2, "Arterial Blood Oxygen: [VALUE] (Result Date: [RESULTDATETIME])", calcPAO21, 1, labs, True)
    dvValue(dvBNP, "BNP: [VALUE] (Result Date: [RESULTDATETIME])", calcBNP1, 2, labs, True)
    dvValue(dvDDimer, "D Dimer: [VALUE] (Result Date: [RESULTDATETIME])", calcDDimer1, 3, labs, True)
    dvValue(dvProBNP, "Pro BNP: [VALUE] (Result Date: [RESULTDATETIME])", calcProBNP1, 4, labs, True)
    abstractValue("PULMONARY_EDEMA", "Pulmonary Edema '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5, labs, True)
    #Meds
    medValue("Anticoagulant", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, meds, True)
    abstractValue("ANTICOAGULANT", "Anticoagulant '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2, meds, True)
    medValue("Antiplatelet", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 3, meds, True)
    abstractValue("ANTIPLATELET", "Antiplatelet '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4, meds, True)
    medValue("Antiplatelet2", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 5, meds, True)
    abstractValue("ANTIPLATELET_2", "Antiplatelet '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6, meds, True)
    medValue("Aspirin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 7, meds, True)
    abstractValue("ASPIRIN", "Aspirin '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, meds, True)
    medValue("Bronchodilator", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 9, meds, True)
    abstractValue("BRONCHODILATOR", "Bronchodilator '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10, meds, True)
    medValue("Bumetanide", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 11, meds, True)
    abstractValue("BUMETANIDE", "Bumetanide '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12, meds, True)
    medValue("Diuretic", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 13, meds, True)
    abstractValue("DIURETIC", "Diuretic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 14, meds, True)
    medValue("Furosemide", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 15, meds, True)
    abstractValue("FUROSEMIDE", "Furosemide '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 16, meds, True)
    medValue("Thrombolytic", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 17, meds, True)
    abstractValue("THROMBOLYTIC", "Thrombolytic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 18, meds, True)
    medValue("Vasodilator", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 19, meds, True)
    abstractValue("VASODILATOR", "Vasodilator '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 20, meds, True)
    #Oxygen
    multiCodeValue(["5A0935A", "5A0945A", "5A0955A"], "Flow Nasal Oxygen: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, oxygen, True)
    multiCodeValue(["5A1935Z", "5A1945Z", "5A1955Z"], "Invasive Mechanical Ventilation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, oxygen, True)
    abstractValue("NON_INVASIVE_VENTILATION", "Non-Invasive Ventilation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3, oxygen, True)
    dvOxygenCheck(dict(maindiscreteDic), dvOxygenTherapy, "Oxygen Therapy '[VALUE]' (Result Date: [RESULTDATETIME])", 4, oxygen, True)
    abstractValue("OXYGEN_THERAPY", "Oxygen Therapy '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5, oxygen, True)
    #Vitals
    abstractValue("ELEVATED_RIGHT_VENTRICLE_SYSTOLIC_PRESSURE", "Elevated Right Ventricle Systolic Pressure '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1, vitals, True)
    dvValue(dvHeartRate, "Heart Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcHeartRate1, 2, vitals, True)
    codeValue("R09.02", "Hypoxemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, vitals, True)
    dvValue(dvPulmonaryPressure, "Pulmonary Systolic Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcPulmonaryPressure1, 4, vitals, True)
    abstractValue("ELEVATED_RIGHT_VENTRICLE_SYSTOLIC_PRESSUE", "Right Ventricle Systolic Pressure: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5, vitals, True)
    dvValue(dvRespiratoryRate, "Respiratory Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcRespiratoryRate1, 6, vitals, True)

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    if vitals.Links: result.Links.Add(vitals); vitalsLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    if oxygen.Links: result.Links.Add(oxygen); oxygenLinks = True
    if ctChestLinks.Links: result.Links.Add(ctChestLinks); docLinksLinks = True
    if chestXRayLinks.Links: result.Links.Add(chestXRayLinks); docLinksLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: AlertTrigger- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks) + ", vitals- "
        + str(vitalsLinks) + ", meds- " + str(medsLinks) + ", oxygen- " + str(oxygenLinks) + ", docs- " + str(docLinksLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
