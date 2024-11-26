##################################################################################################################
#Evaluation Script - Bleeding
#
#This script checks an account to see if it matches criteria to be alerted for Bleeding
#Date - 11/24/2024
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
    "D68.32": "Hemorrhagic Disorder Due To Extrinsic Circulating Anticoagulant"
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
dvBloodLoss = [""]
calcBloodLoss1 = lambda x: x > 300
dvHematocrit = ["HEMATOCRIT (%)", "HEMATOCRIT"]
calcHematocrit1 = lambda x: x < 34
calcHematocrit2 = lambda x: x < 40
dvHemoglobin = ["HEMOGLOBIN", "HEMOGLOBIN (g/dL)"]
calcHemoglobin1 = lambda x: x < 13.5
calcHemoglobin2 = lambda x: x < 11.6
dvINR = ["INR"]
calcINR1 = 1.2
dvPT = ["PROTIME (SEC)"]
calcPT1 = 13
dvPTT = ["PTT (SEC)"]
calcPTT1 = 30.5

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
def HemoglobinHematocritValues(dvDic, gender, value, value1, Needed):
    linkText1 = "Hemoglobin [GENDER]: [VALUE] (Result Date: [RESULTDATETIME])"
    linkText2 = "Hematocrit [GENDER]: [VALUE] (Result Date: [RESULTDATETIME])"
    discreteDic = {}
    discreteDic1 = {}
    x = 0
    a = 0
    z = 0
    hemoglobinList = []
    hematocritList = []
    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in dvHemoglobin and dvr is not None:
            x += 1
            discreteDic[x] = dvDic[dv]
        elif dvDic[dv]['Name'] in dvHematocrit and dvr is not None:
            a += 1
            discreteDic1[a] = dvDic[dv]

    if x > 0:
        for item in discreteDic:
            if z == Needed:
                break
            if x > 0 and float(cleanNumbers(discreteDic[x].Result)) < float(value):
                hemoglobinList.append(dataConversion(discreteDic[x].ResultDate, linkText1, discreteDic[x].Result, discreteDic[x].UniqueId or discreteDic[x]._id, hemoglobin, 0, False, gender))
                if a > 0 and discreteDic[x].ResultDate == discreteDic1[a].ResultDate:
                    hematocritList.append(dataConversion(discreteDic1[a].ResultDate, linkText2, discreteDic1[a].Result, discreteDic1[a].UniqueId or discreteDic1[a]._id, hematocrit, 0, False, gender))
                else:
                    for item in discreteDic1:
                        if discreteDic[x].ResultDate == discreteDic1[item].ResultDate:
                            hematocritList.append(dataConversion(discreteDic1[item].ResultDate, linkText2, discreteDic1[item].Result, discreteDic1[item].UniqueId or discreteDic1[item]._id, hematocrit, 0, False, gender))
                            break
                z += 1; a = a - 1; x = x - 1
            elif a > 0 and float(cleanNumbers(discreteDic1[a].Result)) < float(value1):
                hematocritList.append(dataConversion(discreteDic1[a].ResultDate, linkText2, discreteDic1[a].Result, discreteDic1[a].UniqueId or discreteDic1[a]._id, hematocrit, 0, False, gender))
                if x > 0 and discreteDic[x].ResultDate == discreteDic1[a].ResultDate:
                    hemoglobinList.append(dataConversion(discreteDic[x].ResultDate, linkText1, discreteDic[x].Result, discreteDic[x].UniqueId or discreteDic[x]._id, hemoglobin, 0, False, gender))
                else:
                    for item in discreteDic:
                        if discreteDic1[a].ResultDate == discreteDic[item].ResultDate:
                            hemoglobinList.append(dataConversion(discreteDic[item].ResultDate, linkText1, discreteDic[item].Result, discreteDic[item].UniqueId or discreteDic[item]._id, hematocrit, 0, False, gender))
                            break
                z += 1; a = a - 1; x = x - 1
            else:
                a = a - 1
                x = x - 1

    if len(hemoglobinList) > 0 or len(hematocritList) > 0:
        if len(hemoglobinList) == 0:
            hemoglobinList = [False]
        if len(hematocritList) == 0:
            hematocritList = [False]
        return [hemoglobinList, hematocritList]
    elif len(hemoglobinList) == 0 and len(hematocritList) == 0:
        if len(hemoglobinList) == 0:
            hemoglobinList = [False]
        if len(hematocritList) == 0:
            hematocritList = [False]

    return [hemoglobinList, hematocritList]
   
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
soBleedingLinks = False
labsLinks = False
medsLinks = False
hemoglobinLinks = False
hematocritLinks = False
SOB = False

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 2)
soBleeding = MatchedCriteriaLink("Signs of Bleeding", None, "Signs of Bleeding", None, True, None, None, 3)
meds = MatchedCriteriaLink("Medication(s)/Transfusion(s)", None, "Medication(s)/Transfusion(s)", None, True, None, None, 4)
treatment = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 5)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 6)
hemoglobin = MatchedCriteriaLink("Hemoglobin", None, "Hemoglobin", None, True, None, None, 1)
hematocrit = MatchedCriteriaLink("Hematocrit", None, "Hematocrit", None, True, None, None, 2)
inr = MatchedCriteriaLink("INR", None, "INR", None, True, None, None, 3)
pt = MatchedCriteriaLink("PT", None, "PT", None, True, None, None, 4)
ptt = MatchedCriteriaLink("PTT", None, "PTT", None, True, None, None, 5)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Bleeding':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        subtitle = alert.Subtitle
        break

#Check if alert was autoresolved or completed.
if validated is False:
    #Signs of Bleeding
    d62Code = codeValue("D62", "Acute Blood Loss Anemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    bleedingAbs = abstractValue("BLEEDING", "Bleeding: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2)
    bloodLossDV = dvValue(dvBloodLoss, "Blood Loss: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodLoss1, 3)
    n99510Code = codeValue("N99.510", "Cystostomy Hemorrhage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4)
    r040Code = codeValue("R04.0", "Epistaxis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5)
    estBloodLossAbs = abstractValue("ESTIMATED_BLOOD_LOSS", "Estimated Blood Loss: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6)
    giBleedCodes = multiCodeValue(["K25.0", "K25.2", "K25.4", "K25.6", "K26.0","K26.2", "K26.4. K26.6", "K27.0", "K27.2", "K27.4", "K27.6", "K28.0",
        "K28.2", "K28.4", "28.6", "K29.01", "K29.21", "K29.31", "K29.41", "K29.51", "K29.61", "K29.71", "K29.81", "K29.91", "K31.811", "K31.82",
        "K55.21", "K57.01", "K57.11", "K57.13", "K57.21", "K57.31", "K57.33", "K57.41", "K57.51", "K57.53", "K57.81", "K57.91", "K57.93", "K62.5"],
        "GI Bleed: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7)
    k922Code = codeValue("K92.2", "GI Hemorrhage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8)
    k920Code = codeValue("K92.0", "Hematemesis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9)
    hematocheziaAbs = abstractValue("HEMATCHEZIA", "Hematochezia '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10)
    hematomaAbs = abstractValue("HEMATOMA", "Hematoma '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11)
    r310Code = prefixCodeValue("^R31\.", "Hematuria: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12)
    k661Code = codeValue("K66.1", "Hemoperitoneum: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13)
    hemoptysisCode = codeValue("R04.2", "Hemoptysis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14)
    hemorrhageAbs = abstractValue("HEMORRHAGE", "Hemorrhage '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 15)
    r049Code = codeValue("R04.9", "Hemorrhage from Respiratory Passages: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16)
    r041Code = codeValue("R04.1", "Hemorrhage from Throat: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17)
    j9501Code = codeValue("J95.01", "Hemorrhage from Tracheostomy Stoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18)
    k921Code = codeValue("K92.1", "Melena: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19)
    i62Codes = prefixCodeValue("^I61\.", "Non-Traumatic Subarachnoid Hemorrhage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20)
    i60Codes = prefixCodeValue("^I60\.", "Non-Traumatic Subarachnoid Hemorrhage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21)
    h922Codes = prefixCodeValue("^H92\.2", "Otorrhagia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 22)
    r0489Code = codeValue("R04.89", "Pulmonary Hemorrhage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23)
    #Meds
    anticoagulantMed = medValue("Anticoagulant", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1)
    anticoagulantAbs = abstractValue("ANTICOAGULANT", "Anticoagulant '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2)
    antiplateletMed = medValue("Antiplatelet", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 3)
    antiplatelet2Med = medValue("Antiplatelet2", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 4)
    antiplateletAbs = abstractValue("ANTIPLATELET", "Antiplatelet '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5)
    antiplatelet2Abs = abstractValue("ANTIPLATELET_2", "Antiplatelet '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6)
    aspirinMed = medValue("Aspirin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 7)
    aspirinAbs = abstractValue("ASPIRIN", "Aspirin '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8)
    heparinMed = medValue("Heparin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 15)
    heparinAbs = abstractValue("HEPARIN", "Heparin '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 16)
    z7901Code = codeValue("Z79.01", "Long Term use of Anticoagulants: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17)
    z7982Code = codeValue("Z79.82", "Long-Term use of Asprin: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18)
    z7902Code = codeValue("Z79.02", "Long-term use of Antithrombotics/Antiplatelets: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19)

    #Signs of Bleeding
    if (
        d62Code is not None or 
        bleedingAbs is not None or
        r041Code is not None or
        r0489Code is not None or
        r049Code is not None or
        h922Codes is not None or
        i62Codes is not None or
        i60Codes is not None or
        n99510Code is not None or
        r040Code is not None or
        k922Code is not None or
        giBleedCodes is not None or
        hemorrhageAbs is not None or
        j9501Code is not None or
        hematocheziaAbs is not None or
        k920Code is not None or
        hematomaAbs is not None or
        r310Code is not None or
        k661Code is not None or
        hemoptysisCode is not None or
        k921Code is not None or
        estBloodLossAbs is not None or
        bloodLossDV is not None
    ):
        SOB = True

    #Algorithm
    if codesExist > 0:
        db.LogEvaluationScriptMessage("One specific code was on the chart, alert failed. " + str(alertTriggered) + " " + str(account._id), scriptName, scriptInstance, "Debug")
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

    elif (
        SOB and
        codesExist == 0 and
        (anticoagulantMed is not None or anticoagulantAbs is not None or antiplateletMed is not None or
        antiplatelet2Med is not None or antiplateletAbs is not None or antiplatelet2Abs is not None or aspirinMed is not None or
        heparinMed is not None or heparinAbs is not None or z7901Code is not None or z7982Code is not None or
        z7902Code is not None or aspirinAbs is not None)
    ):
        result.Subtitle = "Bleeding with possible link to Anticoagulant."
        AlertPassed = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#Alert Passed Abstractions
if AlertPassed:
    #Find all discrete values for custom lookups within the last X days
    maindiscreteDic = {}
    unsortedDicsreteDic = {}
    dvCount = 0
    #Combine all items into one list to search against
    discreteSearchList = [i for j in [dvHemoglobin, dvHematocrit, dvINR, dvPT, dvPTT] for i in j]
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

    #Labs
    lowHemoglobinMultiDV = [[False], [False]]
    if gender == 'F':
        lowHemoglobinMultiDV = HemoglobinHematocritValues(dict(maindiscreteDic), "Female", 12, 34, 3)
    elif gender == 'M':
        lowHemoglobinMultiDV = HemoglobinHematocritValues(dict(maindiscreteDic), "Male", 13.5, 40, 3)
    if lowHemoglobinMultiDV[0][0] is not False:
        for entry in lowHemoglobinMultiDV[0]:
            hemoglobin.Links.Add(entry)
    if lowHemoglobinMultiDV[1][0] is not False:
        for entry in lowHemoglobinMultiDV[1]:
            hematocrit.Links.Add(entry)
    dvValueMulti(dict(maindiscreteDic), dvINR, "INR: [VALUE] (Result Date: [RESULTDATETIME])", calcINR1, gt, 0, inr, True, 10)
    dvValueMulti(dict(maindiscreteDic), dvPT, "PT: [VALUE] (Result Date: [RESULTDATETIME])", calcPT1, gt, 0, pt, True, 10)
    dvValueMulti(dict(maindiscreteDic), dvPTT, "PTT: [VALUE] (Result Date: [RESULTDATETIME])", calcPTT1, gt, 0, ptt, True, 10)
    #Meds
    if anticoagulantMed is not None: meds.Links.Add(anticoagulantMed) #1
    if anticoagulantAbs is not None: meds.Links.Add(anticoagulantAbs) #2
    if antiplateletMed is not None: meds.Links.Add(antiplateletMed) #3
    if antiplatelet2Med is not None: meds.Links.Add(antiplatelet2Med) #4
    if antiplateletAbs is not None: meds.Links.Add(antiplateletAbs) #5
    if antiplatelet2Abs is not None: meds.Links.Add(antiplatelet2Abs) #6
    if aspirinMed is not None: meds.Links.Add(aspirinMed) #7
    if aspirinAbs is not None: meds.Links.Add(aspirinAbs) #8
    abstractValue("CLOT_SUPPORTING_THERAPY", "Clot Supporting Therapy [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, meds, True)
    medValue("Clot Supporting Therapy Reversal Agent", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 10, meds, True)
    codeValue("30233M1", "Cryoprecipitate: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, meds, True)
    abstractValue("DESMOPRESSIN_ACETATE", "Desmopressin Acetate [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12, meds, True)
    codeValue("30233T1", "Fibrinogen Transfusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13, meds, True)
    multiCodeValue(["30233L1", "30243L1"], "Fresh Frozen Plasma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, meds, True)
    if heparinMed is not None: meds.Links.Add(heparinMed) #15
    if heparinAbs is not None: meds.Links.Add(heparinAbs) #16
    if z7901Code is not None: meds.Links.Add(z7901Code) #17
    if z7982Code is not None: meds.Links.Add(z7982Code) #18
    if z7902Code is not None: meds.Links.Add(z7902Code) #19
    abstractValue("PLASMA_DERIVED_FACTOR_CONCENTRATE", "Plasma Derived Factor Concentrate [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 20, meds, True)
    multiCodeValue(["30233R1", "30243R1"], "Platelet Transfusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21, meds, True)
    abstractValue("RECOMBINANT_FACTOR_CONCENTRATE", "Recombinant Factor Concentrate [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 22, meds, True)
    multiCodeValue(["30233N1", "30243N1"], "Red Blood Cell Transfusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23, meds, True)
    #Signs of Bleeding
    if d62Code is not None: soBleeding.Links.Add(d62Code) #1
    if bleedingAbs is not None: soBleeding.Links.Add(bleedingAbs) #2
    if bloodLossDV is not None: soBleeding.Links.Add(bloodLossDV) #3
    if n99510Code is not None: soBleeding.Links.Add(n99510Code) #4
    if r040Code is not None: soBleeding.Links.Add(r040Code) #5
    if estBloodLossAbs is not None: soBleeding.Links.Add(estBloodLossAbs) #6
    if k922Code is not None: soBleeding.Links.Add(k922Code) #7
    if giBleedCodes is not None: soBleeding.Links.Add(giBleedCodes) #8
    if hematocheziaAbs is not None: soBleeding.Links.Add(hematocheziaAbs) #9
    if k920Code is not None: soBleeding.Links.Add(k920Code) #10
    if hematomaAbs is not None: soBleeding.Links.Add(hematomaAbs) #11
    if r310Code is not None: soBleeding.Links.Add(r310Code) #12
    if k661Code is not None: soBleeding.Links.Add(k661Code) #13
    if hemoptysisCode is not None: soBleeding.Links.Add(hemoptysisCode) #14
    if hemorrhageAbs is not None: soBleeding.Links.Add(hemorrhageAbs) #15
    if r049Code is not None: soBleeding.Links.Add(r049Code) #16
    if j9501Code is not None: soBleeding.Links.Add(j9501Code) #17
    if r041Code is not None: soBleeding.Links.Add(r041Code) #18
    if k921Code is not None: soBleeding.Links.Add(k921Code) #19
    if i62Codes is not None: soBleeding.Links.Add(i62Codes) #20
    if i60Codes is not None: soBleeding.Links.Add(i60Codes) #21
    if h922Codes is not None: soBleeding.Links.Add(h922Codes) #22
    if r0489Code is not None: soBleeding.Links.Add(r0489Code) #23

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if inr.Links: labs.Links.Add(inr); labsLinks = True
    if pt.Links: labs.Links.Add(pt); labsLinks = True
    if ptt.Links: labs.Links.Add(ptt); labsLinks = True
    if hemoglobin.Links: labs.Links.Add(hemoglobin); hemoglobinLinks = True
    if hematocrit.Links: labs.Links.Add(hematocrit); hematocritLinks = True
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if soBleeding.Links: result.Links.Add(soBleeding); soBleedingLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: AlertTrigger- " + str(dcLinks) + ", soBleeding- " + str(soBleedingLinks) + ", labs- " + str(labsLinks) +
        ", meds- " + str(medsLinks) + ", Hemoglobin- " + str(hemoglobinLinks) + ", hematocrit- " + str(hematocritLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
