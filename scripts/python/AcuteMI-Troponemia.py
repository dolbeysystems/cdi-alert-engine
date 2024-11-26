##################################################################################################################
#Evaluation Script - Acute Myocardial Infraction - Troponemia
#
#This script checks an account to see if it matches criteria to be alerted for Acute Myocardial Infraction
#Date - 11/25/2024
#Version - V33
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
stemicodeDic = {
    "I21.01": "ST Elevation (STEMI) Myocardial Infarction Involving Left Main Coronary Artery",
    "I21.02": "ST Elevation (STEMI) Myocardial Infarction Involving Left Anterior Descending Coronary Artery",
    "I21.09": "ST Elevation (STEMI) Myocardial Infarction Involving Other Coronary Artery Of Anterior Wall",
    "I21.11": "ST Elevation (STEMI) Myocardial Infarction Involving Right Coronary Artery",
    "I21.19": "ST Elevation (STEMI) Myocardial Infarction Involving Other Coronary Artery Of Inferior Wall",
    "I21.21": "ST Elevation (STEMI) Myocardial Infarction Involving Left Circumflex Coronary Artery",
    "I21.29": "ST Elevation (STEMI) Myocardial Infarction Involving Other Sites",
    "I21.3": "ST Elevation (STEMI) Myocardial Infarction of Unspecified Site"
}
othercodeDic = {
    "I21.A1": "Myocardial Infarction Type 2",
    "I21.A9": "Other Myocardial Infarction Type",
    "I21.B": "Myocardial Infarction with Coronary Microvascular Dysfunction",
    "I5A": "Non-Ischemic Myocardial Injury (Non-Traumatic)",
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
calcHeartRate2 = lambda x: x < 60
dvHematocrit = ["HEMATOCRIT (%)", "HEMATOCRIT"]
calcHematocrit1 = lambda x: x < 34
calcHematocrit2 = lambda x: x < 40
dvHemoglobin = ["HEMOGLOBIN", "HEMOGLOBIN (g/dL)"]
calcHemoglobin1 = lambda x: x < 13.5
calcHemoglobin2 = lambda x: x < 11.6
dvMAP = ["MAP Non-Invasive (Calculated) (mmHg)", "MAP Invasive (mmHg)"]
calcMAP1 = lambda x: x < 70
dvOxygenTherapy = ["DELIVERY"]
dvPaO2 = ["BLD GAS O2 (mmHg)", "PO2 (mmHg)"]
calcPAO21 = lambda x: x < 80
dvSBP = ["SBP 3.5 (No Calculation) (mm Hg)"]
calcSBP1 = lambda x: x < 90
calcSBP2 = lambda x: x > 180
dvSPO2 = ["Pulse Oximetry(Num) (%)"]
calcSPO21 = lambda x: x < 90
dvTroponinT = ["TROPONIN, HIGH SENSITIVITY (ng/L)"]
calcTroponinT1 = 59

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
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, True)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, False)
                return abstraction
    return abstraction

def dvAnythingCheck(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    abstraction = None
    for dv in dvDic or []:
        if dvDic[dv]['Name'] in discreteValueName:
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, True)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, False)
                return abstraction
    return abstraction

def dvLookUpAllValuesSingleLine(dvDic, DV1, sequence, category, linkText):
    date1 = None
    date2 = None
    id = None
    FirstLoop = True
    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in DV1 and dvr is not None:
            if FirstLoop:
                FirstLoop = False
                linkText = linkText + dvr 
            else:
                linkText = linkText + ", " + dvr 
            if date1 is None:
                date1 = dvDic[dv]['ResultDate']
            date2 = dvDic[dv]['ResultDate']
            if id is None:
                id = dvDic[dv]['UniqueId'] or dvDic[dv]['_id']
            
    if date1 is not None and date2 is not None:
        date1 = datetimeFromUtcToLocal(date1)
        date1 = date1.ToString("MM/dd/yyyy")
        date2 = datetimeFromUtcToLocal(date2)
        date2 = date2.ToString("MM/dd/yyyy")
        linkText = linkText.replace("DATE1", date1)
        linkText = linkText.replace("DATE2", date2)
        category.Links.Add(MatchedCriteriaLink(linkText, None, None, id, True, None, None, sequence))

#========================================
#  Algorithm
#========================================
db.LogEvaluationScriptMessage("Starting Script " + str(account._id), scriptName, scriptInstance, "Debug")
#Determine if if and how many fully spec codes are on the acct
stemiCodes = []
stemiCodes = stemicodeDic.keys()
stemiCodeList = CodeCount(stemiCodes)
stemiCodesExist = len(stemiCodeList)
stemiStr1 = ', '.join([str(elem) for elem in stemiCodeList])
otherCodes = []
otherCodes = othercodeDic.keys()
otherCodeList = CodeCount(otherCodes)
otherCodesExist = len(otherCodeList)
otherStr1 = ', '.join([str(elem) for elem in otherCodeList])

#Standard Variable Declaration
AlertPassed = False
alertTriggered = False
AlertConditions = False
validated = False
outcome = None
subtitle = None
triggerAlert = True
reason = None
documentedDxTriggerLinks = False
absLinks = False
labsLinks = False
vitalsLinks = False
medsLinks = False
oxygenLinks = False
contriLinks = False
docLinksLinks = False
codeCount = 0

#Initalize categories
documentedDx = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 2)
vitals = MatchedCriteriaLink("Vital Signs/Intake and Output Data", None, "Vital Signs/Intake and Output Data", None, True, None, None, 3)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 4)
oxygen = MatchedCriteriaLink("Oxygenation/Ventilation", None, "Oxygenation/Ventilation", None, True, None, None, 5)
meds = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 6)
ekgLinks = MatchedCriteriaLink("EKG", None, "EKG", None, True, None, None, 7)
echoLinks = MatchedCriteriaLink("Echo", None, "Echo", None, True, None, None, 7)
ctLinks = MatchedCriteriaLink("CT", None, "CT", None, True, None, None, 7)
heartCathLinks = MatchedCriteriaLink("Heart Cath", None, "Heart Cath", None, True, None, None, 7)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 8)
troponin = MatchedCriteriaLink("Troponin", None, "Troponin", None, True, None, None, 89)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup ==  'Acute MI':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        subtitle = alert.Subtitle
        reason = alert.Reason
        if outcome == 'AUTORESOLVED' or reason == 'Previously Autoresolved':
            triggerAlert = False
        subtitle = alert.Subtitle
        break

#Determine if alert can run links
i214Code = codeValue("I21.4", "Non-ST Elevation (NSTEMI) Myocardial Infarction: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")

if stemiCodesExist > 0:
    codeCount += 1
if i214Code is not None:
    codeCount += 1
if otherCodesExist > 0:
    codeCount += 1

#Check if alert was autoresolved or completed.
if (
    validated is False or
    (outcome == "AUTORESOLVED" and validated and codeCount > 1)
):
    #Find all discrete values for custom lookups within the last 7 days
    maindiscreteDic = {}
    unsortedDicsreteDic = {}
    dvCount = 0
    #Combine all items into one list to search against
    discreteSearchList = [i for j in [dvTroponinT, dvOxygenTherapy] for i in j]
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
    
    #Documented Dx
    i219Code = codeValue("I21.9", "Acute Myocardial Infarction Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    r778Code = codeValue("R77.8", "Other Specified Abnormalities of Plasma Proteins: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i21A1Code = codeValue("I21.A1", "Myocardial Infarction Type 2: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Abs
    r07Codes = multiCodeValue(["R07.89", "R07.9"], "Chest Pain: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14)
    i2489Code = codeValue("I24.89", "Demand Ischemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23)
    irregularEKGFindingsAbs = abstractValue("IRREGULAR_EKG_FINDINGS_MI", "Irregular EKG Finding: '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 43)
    #Meds
    antiplatlet2Med = medValue("Antiplatelet2", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 7)
    aspirinMed = medValue("Aspirin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 9)
    heparinMed = medValue("Heparin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 15)
    morphineMed = medValue("Morphine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 17)
    nitroglycerinMed = medValue("Nitroglycerin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 18)
    #Labs
    dvLookUpAllValuesSingleLine(dict(maindiscreteDic), dvTroponinT, 0, troponin, "Troponin T High Sensitivity: (DATE1 - DATE2) - ")
    troponinTDV = dvValueMulti(dict(maindiscreteDic), dvTroponinT, "Troponin T High Sensitivity: [VALUE] (Result Date: [RESULTDATETIME])", calcTroponinT1, gt, 1, troponin, False, 10)

    #Starting Main Algorithm
    if codeCount == 1 and i2489Code is None:
        db.LogEvaluationScriptMessage("One specific code was on the chart, alert failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        if alertTriggered:
            if stemiCodesExist > 0:
                for code in stemiCodeList:
                    desc = stemicodeDic[code]
                    tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                    if tempCode is not None:
                        documentedDx.Links.Add(tempCode)
                        break
            if otherCodesExist > 0:
                for code in otherCodeList:
                    desc = othercodeDic[code]
                    tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                    if tempCode is not None:
                        documentedDx.Links.Add(tempCode)
                        break
            if i214Code is not None: updateLinkText(i214Code, autoCodeText); documentedDx.Links.Add(i214Code)
            result.Outcome = "AUTORESOLVED"
            result.Reason = "Autoresolved due to one Specified Code on the Account"
            result.Validated = True
            AlertConditions = True
        else: result.Passed = False
        
    elif codeCount > 1:
        if stemiCodesExist > 0:
            for code in stemiCodeList:
                desc = stemicodeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    documentedDx.Links.Add(tempCode)
                    break
        if otherCodesExist > 0:
            for code in otherCodeList:
                desc = othercodeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    documentedDx.Links.Add(tempCode)
                    break
        if i214Code is not None: documentedDx.Links.Add(i214Code)
        if validated:
            result.Validated = False
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"
        result.Subtitle = "Acute MI Conflicting Dx"
        AlertPassed = True
        
    elif triggerAlert and i21A1Code is not None and i2489Code is not None:
        if i21A1Code is not None: documentedDx.Links.Add(i21A1Code)
        if i2489Code is not None: documentedDx.Links.Add(i2489Code)
        result.Subtitle = "Acute MI Type 2 and Demand Ischemia Documented Seek Clarification."
        AlertPassed = True
                
    elif triggerAlert and codeCount == 0 and (troponinTDV is not None or i219Code is not None) and i2489Code is not None :
        if i2489Code is not None: abs.Links.Add(i2489Code)
        if i219Code is not None: abs.Links.Add(i219Code)
        result.Subtitle = "Possible Acute MI Type 2"
        AlertPassed = True
            
    elif triggerAlert and codeCount > 0 and i2489Code is not None:
        if i2489Code is not None: documentedDx.Links.Add(i2489Code)
        if stemiCodesExist > 0:
            for code in stemiCodeList:
                desc = stemicodeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    documentedDx.Links.Add(tempCode)
                    break
        if otherCodesExist > 0:
            for code in otherCodeList:
                desc = othercodeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    documentedDx.Links.Add(tempCode)
                    break
        if i214Code is not None: documentedDx.Links.Add(i214Code)
        result.Subtitle = "Acute MI Type Needs Claification"
        AlertPassed = True
    
    elif triggerAlert and i219Code is not None:
        documentedDx.Links.Add(i219Code)
        result.Subtitle = "Acute MI Unspecified Present Confirm if Further Specification of Type Needed"
        AlertPassed = True
    #5
    elif triggerAlert and troponinTDV is not None and irregularEKGFindingsAbs is not None:
        result.Subtitle = "Possible Acute MI"
        AlertPassed = True
    #6
    elif (
        triggerAlert and
        (r07Codes is not None or troponinTDV is not None) and
        heparinMed is not None and
        (morphineMed is not None or nitroglycerinMed is not None) and
        aspirinMed is not None and antiplatlet2Med is not None
    ):
        if heparinMed is not None: meds.Links.Add(heparinMed)
        result.Subtitle = "Possible Acute MI"
        AlertPassed = True
    #7
    elif triggerAlert and troponinTDV is not None:
        result.Subtitle = "Elevated Troponins Present"
        AlertPassed = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Abs
    codeValue("R94.39", "Abnormal Cardiovascular Function Study: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, abs, True)
    codeValue("D62", "Acute Blood Loss Anemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, abs, True)
    codeValue("I24.81", "Acute Coronary microvascular Dysfunction: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, abs, True)
    multiCodeValue(["N17.0", "N17.1", "N17.2", "K76.7", "K91.83"], "Acute Kidney Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, abs, True)
    codeValue("I20.9", "Angina: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, abs, True)
    codeValue("I20.81", "Angina Pectoris with Coronary Microvascular Dysfunction: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, abs, True)
    codeValue("I20.1", "Angina Pectoris with Documented Spasm/with Coronary Vasospasm: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, abs, True)
    abstractValue("ATRIAL_FIBRILLATION_WITH_RVR", "Atrial Fibrillation with RVR '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, abs, True)
    codeValue("I46.9", "Cardiac Arrest, Cause Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, abs, True)
    codeValue("I46.8", "Cardiac Arrest Due to Other Underlying Condition: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, abs, True)
    codeValue("I46.2", "Cardiac Arrest due to Underlying Cardiac Condition: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, abs, True)
    prefixCodeValue("^I42\.", "Cardiomyopathy Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, abs, True)
    prefixCodeValue("^I43\.", "Cardiomyopathy Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13, abs, True)
    if r07Codes is not None: abs.Links.Add(r07Codes) #14
    codeValue("I25.85", "Chronic Coronary Microvascular Dysfunction: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
    multiCodeValue(["N18.1", "N18.2", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5"], "Chronic Kidney Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, abs, True)
    codeValue("I44.2", "Complete Heart Block: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17, abs, True)
    codeValue("J44.1", "COPD Exacerbation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, abs, True)
    codeValue("Z98.61", "Coronary Angioplasty Hx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19, abs, True)
    codeValue("Z95.5", "Coronary Angioplasty Implant and Graft Hx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20, abs, True)
    codeValue("I25.10", "Coronary Artery Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21, abs, True)
    codeValue("I25.119", "Coronary Artery Disease with Angina: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 22, abs, True)
    #23
    multiCodeValue(["270046", "027004Z", "0270056", "027005Z", "0270066", "027006Z", "0270076", "027007Z", "02700D6", "02700DZ", "02700E6", "02700EZ",
                "02700F6", "02700FZ", "02700G6", "02700GZ", "02700T6", "02700TZ", "02700Z6", "02700ZZ", "0271046", "027104Z", "0271056", "027105Z",
                "0271066", "027106Z", "0271076", "027107Z", "02710D6", "02710DZ", "02710E6", "02710EZ", "02710F6", "02710FZ", "02710G6", "02710GZ",
                "02710T6", "02710TZ", "02710Z6", "02710ZZ", "0272046", "027204Z", "0272056", "027205Z", "0272066", "027206Z", "0272076", "027207Z",
                "02720D6", "02720DZ", "02720E6", "02720EZ", "02720F6", "02720FZ", "02720G6", "02720GZ", "02720T6", "02720TZ", "02720Z6", "02720ZZ",
                "0273046", "027304Z", "0273056", "027305Z", "0273066", "027306Z", "0273076", "027307Z", "02730D6", "02730DZ", "02730E6", "02730EZ",
                "02730F6", "02730FZ", "02730G6", "02730GZ", "02730T6", "02730TZ", "02730Z6", "02730ZZ"], 
                "Dilation of Coronary Artery: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 24, abs, True)
    abstractValue("DYSPNEA_ON_EXERTION", "Dyspnea On Exertion: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 25, abs, True)
    abstractValue("PRESERVED_EJECTION_FRACTION", "Ejection Fraction: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 26, abs, True)
    abstractValue("PRESERVED_EJECTION_FRACTION_2", "Ejection Fraction: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 27, abs, True)
    abstractValue("REDUCED_EJECTION_FRACTION", "Ejection Fraction: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 28, abs, True)
    abstractValue("MODERATELY_REDUCED_EJECTION_FRACTION", "Ejection Fraction: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 29, abs, True)
    abstractValue("ELEVATED_TROPONINS", "Elevated Tropinins '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 30, abs, True)
    codeValue("N18.6", "End-Stage Renal Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 31, abs, True)
    prefixCodeValue("^I38\.", "Endocarditis Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 32, abs, True)
    prefixCodeValue("^I39\.", "Endocarditis Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 33, abs, True)
    multiCodeValue(["I50.1", "I50.20", "I50.22", "I50.23", "I50.30", "I50.32", "I50.33", "I50.40", "I50.42", "I50.43", "I50.810", "I50.812", "I50.813", "I50.84", "I50.89", "I50.9"], "Heart Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 34, abs, True)
    codeValue("Z95.1", "History of CABG: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 35, abs, True)
    codeValue("I16.1", "Hypertensive Emergency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 36, abs, True)
    codeValue("I16.0", "Hypertensive Urgency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 37, abs, True)
    codeValue("E86.1", "Hypovolemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 38, abs, True)
    codeValue("R09.02", "Hypoxemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 39, abs, True)
    codeValue("I47.11", "Inappropriate Sinus Tachycardia, So Stated: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 40, abs, True)
    abstractValue("IRREGULAR_ECHO_FINDING", "Irregular Echo Finding '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 41, abs, True)
    codeValue("R94.31", "Irregular Echo Finding: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 42, abs, True)
    if irregularEKGFindingsAbs is not None: abs.Links.Add(irregularEKGFindingsAbs) #43
    multiCodeValue(["4A023N7", "4A023N8"], "Left Heart Cath: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 44)
    prefixCodeValue("^I40\.", "Myocarditis Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 45, abs, True)
    codeValue("I35.0", "Non-Rheumatic Aortic Valve Stenosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 46, abs, True)
    codeValue("I35.1", "Non-Rheumatic Aortic Valve Insufficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 47, abs, True)
    codeValue("I35.2", "Non-Rheumatic Aortic Valve Stenosis with Insufficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 48, abs, True)
    codeValue("I25.2", "Old MI: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 49, abs, True)
    codeValue("I20.8", "Other Angina Pectoris: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 50, abs, True)
    codeValue("I47.19", "Other Supraventricular Tachycardia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 51, abs, True)
    prefixCodeValue("^I47\.", "Paroxysmal Tachycardia Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 52, abs, True)
    prefixCodeValue("^I30\.", "Pericarditis Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 53, abs, True)
    prefixCodeValue("^I26\.", "Pulmonary Embolism Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 54, abs, True)
    multiCodeValue(["I27.0", "I27.20", "I27.21", "I27.22", "I27.23", "I27.24", "I27.29"], "Pulmonary Hypertension: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 55, abs, True)
    multiCodeValue(["0270346", "027034Z", "0270356", "027035Z", "0270366", "027036Z", "02730376", "027037Z", "02703D6", "02703DZ", "02703E6", "02703EZ",
                      "02703F6", "02703FZ", "02703G6", "02703GZ", "02703T6", "02703TZ", "02703Z6", "02703ZZ", "0271346", "027134Z", "0271356", "027135Z",
                      "0271366", "027136Z", "0271376", "027137Z", "02713D6", "02713DZ", "02713E6", "02713EZ", "02713F6", "02713FZ", "02713G6", "02713GZ",
                      "02713T6", "02713TZ", "02713Z6", "02713ZZ", "0272346", "027234Z", "0272356", "027235Z", "0272366", "027236Z", "0272376", "027237Z",
                      "02723D6", "02723DZ", "02723E6", "02723EZ", "02723F6", "02723FZ", "02723G6", "02723GZ", "02723T6", "02723TZ", "02723Z6", "02723ZZ",
                      "0273346", "027334Z", "0273356", "027335Z", "0273366", "027336Z", "0273376", "027337Z", "02733D6", "02733DZ", "02733E6", "02733EZ",
                      "02733F6", "02733FZ", "02733G6", "02733GZ", "02733T6", "02733TZ", "02733Z6", "02733ZZ"],
                    "Percutaneous Coronary Intervention: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 56, abs, True)
    multiCodeValue(["M62.82", "T79.6XXA", "T79.6XXD", "T79.6XXS"], "Rhabdomyolysis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 57, abs, True)
    codeValue("4A023N6", "Right Heart Cath: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 58, abs, True)
    codeValue("I20.2", "Refractory Angina Pectoris: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 59, abs, True)
    abstractValue("RESOLVING_TROPONINS", "Resolving Troponins '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 60, abs, True)
    prefixCodeValue("^A40\.", "Sepsis Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 61, abs, True)
    prefixCodeValue("^A41\.", "Sepsis Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 62, abs, True)
    multiCodeValue(["A42.7", "A22.7", "B37.7", "A26.7", "A54.86", "B00.7", "A32.7", "A24.1", "A20.7", "R65.20", "R65.21", "T81.44XA", "T81.44XD", "T81.44XS"], "Sepsis Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 63, abs, True)
    abstractValue("SHORTNESS_OF_BREATH", "Shortness of Breath '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 64, abs, True)
    codeValue("I47.10", "Supraventricular Tachycardia, Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 65, abs, True)
    codeValue("I51.81", "Takotsubo Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 66, abs, True)
    codeValue("I25.82", "Total Occlusion of Coronary Artery: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 67, abs, True)
    multiCodeValue(["I35.8", "I35.9"], "Unspecified Non-Rheumatic Aortic Valve Disorders: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 68, abs, True)
    codeValue("I20.0", "Unstable Angina: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 69, abs, True)
    codeValue("I49.01", "Ventricular Fibrillation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 70, abs, True)
    codeValue("I49.02", "Ventricular Flutter: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 71, abs, True)
    abstractValue("WALL_MOTION_ABNORMALITIES", "Wall Motion Abnormalities '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 72, abs, True)
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
    documentLink("CT Thorax W", "CT Thorax W", 0, ctLinks, True)
    documentLink("CTA Thorax Aorta", "CTA Thorax Aorta", 0, ctLinks, True)
    documentLink("CT Thorax WO-Abd WO-Pel WO", "CT Thorax WO-Abd WO-Pel WO", 0, ctLinks, True)
    documentLink("CT Thorax WO", "CT Thorax WO", 0, ctLinks, True)
    #Labs
    if gender == 'F':
        dvValue(dvHemoglobin, "Hemoglobin: [VALUE] (Result Date: [RESULTDATETIME])", calcHemoglobin2, 1, labs, True)
        dvValue(dvHematocrit, "Hematocrit: [VALUE] (Result Date: [RESULTDATETIME])", calcHematocrit1, 2, labs, True)
    if gender == 'M':
        dvValue(dvHemoglobin, "Hemoglobin: [VALUE] (Result Date: [RESULTDATETIME])", calcHemoglobin1, 1, labs, True)
        dvValue(dvHematocrit, "Hematocrit: [VALUE] (Result Date: [RESULTDATETIME])", calcHematocrit2, 2, labs, True)
    #Lab Subheadings
    if troponinTDV is not None:
        for entry in troponinTDV:
            troponin.Links.Add(entry) #0
    #Meds
    medValue("Ace Inhibitor", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, meds, True)
    medValue("Antianginal Medication", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 2, meds, True)
    abstractValue("ANTIANGINAL_MEDICATION", "Antianginal Medication '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3, meds, True)
    medValue("Anticoagulant", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 4, meds, True)
    abstractValue("ANTICOAGULANT", "Anticoagulant '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5, meds, True)
    medValue("Antiplatelet", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 6, meds, True)
    if antiplatlet2Med is not None: meds.Links.Add(antiplatlet2Med) #7
    abstractValue("ANTIPLATELET", "Antiplatelet '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, meds, True)
    if aspirinMed is not None: meds.Links.Add(aspirinMed) #9
    medValue("Beta Blocker", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 10, meds, True)
    abstractValue("BETA_BLOCKER", "Beta Blocker '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11, meds, True)
    medValue("Calcium Channel Blockers", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 12, meds, True)
    abstractValue("CALCIUM_CHANNEL_BLOCKER", "Calcium Channel Blocker '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13, meds, True)
    #15
    if morphineMed is not None: meds.Links.Add(morphineMed) #17
    if nitroglycerinMed is not None: meds.Links.Add(nitroglycerinMed) #18
    abstractValue("NITROGLYCERIN", "Nitroglycerin '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 19, meds, True)
    medValue("Statin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 20, meds, True)
    abstractValue("STATIN", "Statin '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 21, meds, True)
    #Oxygen
    dvOxygenCheck(dict(maindiscreteDic), dvOxygenTherapy, "Oxygen Therapy '[VALUE]' (Result Date: [RESULTDATETIME])", 1, oxygen, True)
    abstractValue("OXYGEN_THERAPY", "Oxygen Therapy '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2, oxygen, True)
    #Vitals
    dvValue(dvPaO2, "Arterial P02: [VALUE] (Result Date: [RESULTDATETIME])", calcPAO21, 1, labs, True)
    dvValue(dvHeartRate, "Heart Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcHeartRate1, 2, vitals, True)
    dvValue(dvHeartRate, "Heart Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcHeartRate2, 3, vitals, True)
    dvValue(dvMAP, "MAP: [VALUE] (Result Date: [RESULTDATETIME])", calcMAP1, 4, vitals, True)
    dvValue(dvSPO2, "Sp02: [VALUE] (Result Date: [RESULTDATETIME])", calcSPO21, 5, vitals, True)
    dvValue(dvSBP, "SBP: [VALUE] (Result Date: [RESULTDATETIME])", calcSBP1, 6, vitals, True)
    dvValue(dvSBP, "SBP: [VALUE] (Result Date: [RESULTDATETIME])", calcSBP2, 7, vitals, True)

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if troponin.Links: labs.Links.Add(troponin); labsLinks = True
    if documentedDx.Links: result.Links.Add(documentedDx); documentedDxTriggerLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    if vitals.Links: result.Links.Add(vitals); vitalsLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    if oxygen.Links: result.Links.Add(oxygen); oxygenLinks = True
    if ekgLinks.Links: result.Links.Add(ekgLinks); docLinksLinks = True
    if echoLinks.Links: result.Links.Add(echoLinks); docLinksLinks = True
    if ctLinks.Links: result.Links.Add(ctLinks); docLinksLinks = True
    if heartCathLinks.Links: result.Links.Add(heartCathLinks); docLinksLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: AlertTrigger- " + str(documentedDxTriggerLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks) + ", vitals- " + str(vitalsLinks) + ", meds- " + str(medsLinks) + ", oxygen- " + str(oxygenLinks) +
        ", docs- " + str(docLinksLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
