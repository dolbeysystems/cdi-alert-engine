##################################################################################################################
#Evaluation Script - Substance Abuse
#
#This script checks an account to see if it matches criteria to be alerted for Substance Abuse
#Date - 10/22/2024
#Version - V12
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
alcoholCodeDic = {
    "F10.130": "Alcohol abuse with withdrawal, uncomplicated",
    "F10.131": "Alcohol abuse with withdrawal delirium",
    "F10.132": "Alcohol Abuse with Withdrawal",
    "F10.139": "Alcohol abuse with withdrawal, unspecified",
    "F10.230": "Alcohol Dependence with Withdrawal, Uncomplicated",
    "F10.231": "Alcohol Dependence with Withdrawal Delirium",
    "F10.232": "Alcohol Dependence with Withdrawal with Perceptual Disturbance",
    "F10.239": "Alcohol Dependence with Withdrawal, Unspecified",
    "F10.930": "Alcohol use, unspecified with withdrawal, uncomplicated",
    "F10.931": "Alcohol use, unspecified with withdrawal delirium",
    "F10.932": "Alcohol use, unspecified with withdrawal with perceptual disturbance",
    "F10.939": "Alcohol use, unspecified with withdrawal, unspecified"
}

opioidCodeDic = {
    "F11.20": "Opioid Dependence, Uncomplicated",
    "F11.21": "Opioid Dependence, In Remission",
    "F11.22": "Opioid Dependence with Intoxication",
    "F11.220": "Opioid Dependence with Intoxication, Uncomplicated",
    "F11.221": "Opioid Dependence with Intoxication, Delirium",
    "F11.222": "Opioid Dependence with Intoxication, Perceptual Disturbance",
    "F11.229": "Opioid Dependence with Intoxication, Unspecified",
    "F11.23": "Opioid Dependence with Withdrawal",
    "F11.24": "Opioid Dependence with Withdrawal Delirium",
    "F11.25": "Opioid dependence with opioid-induced psychotic disorder",
    "F11.250": "Opioid dependence with opioid-induced psychotic disorder with delusions",
    "F11.251": "Opioid dependence with opioid-induced psychotic disorder with hallucinations",
    "F11.259": "Opioid dependence with opioid-induced psychotic disorder, unspecified",
    "F11.28": "Opioid dependence with other opioid-induced disorder",
    "F11.281": "Opioid dependence with opioid-induced sexual dysfunction",
    "F11.282": "Opioid dependence with opioid-induced sleep disorder",
    "F11.288": "Opioid dependence with other opioid-induced disorder",
    "F11.29": "Opioid dependence with unspecified opioid-induced disorder"    
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
dvCIWAScore = ["alcohol CIWA Calc score 1112"]
calcCIWAScore1 = lambda x: x > 9

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
        abstraction.MedicationName = med
        category.Links.Add(abstraction)
    elif abstract == False:
        abstraction = MatchedCriteriaLink(linkText, None, None, None, True, None, None, sequence)
        abstraction.MedicationId = id
        abstraction.MedicationName = med
        return abstraction
    return

def medValueMulti(medDic, DV1, linkText, sequence=0, category=None, abstract=False, needed=2):
    # Find multiple medication Values and if abstract is true abstract it to the provided category
    matchedList = []
    dateList = []
    x = 0
    for mv in medDic or []:
        if medDic[mv]['Name'] == DV1 and medDic[mv]['StartDate'] not in dateList:
            matchedList.append(medDataConversion(medDic[mv]['StartDate'], linkText, medDic[mv]['Medication'], medDic[mv]['ExternalId'], medDic[mv]['Dosage'], medDic[mv]['Route'], category, sequence, abstract))
            dateList.append(medDic[mv]['StartDate'])
            x += 1
            if x >= needed:
                break
    if abstract and x > 0:
        return True
    elif abstract is False and len(matchedList) > 0 and needed > 0:
        return matchedList
    else:
        return None

#========================================
#  Algorithm
#========================================
db.LogEvaluationScriptMessage("Script starting " + str(account._id), scriptName, scriptInstance, "Debug")
#Determine if if and how many fully spec codes are on the acct
opioidCodes = []
opioidCodes = opioidCodeDic.keys()
opioidCodeList = CodeCount(opioidCodes)
opioidCodesExist = len(opioidCodeList)
str1 = ', '.join([str(elem) for elem in opioidCodeList])
alcoholCodes = []
alcoholCodes = alcoholCodeDic.keys()
alcoholCodeList = CodeCount(alcoholCodes)
alcoholCodesExist = len(alcoholCodeList)
str1 = ', '.join([str(elem) for elem in alcoholCodeList])

#Standard Variable Declaration
AlertPassed = False
alertTriggered = False
AlertConditions = False
validated = False
outcome = None
subtitle = None
dcLinks = False
absLinks = False
medsLinks = False
docLinksLinks = False
noLabs = []

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 2)
meds = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 3)
painLinks = MatchedCriteriaLink("Pain Team Consult", None, "Pain Team Consult", None, True, None, None, 4)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 5)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Substance Abuse':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        subtitle = alert.Subtitle
        break

#Check if alert was autoresolved or completed.
if validated is False:
    #Get meds within last X days
    mainMedDic = {}
    unsortedMedDic = {}
    medCount = 0
    #Combine all items into one list to search against
    medSearchList = ["Methadone"]
    #Set datelimit for how far back to 
    medDateLimit = System.DateTime.Now.AddDays(-7)
    #Loop through all meds finding any that match in the combined list adding to a dictionary the matches
    if 'Medications' in account:    
        for med in account.Medications:
            if med.StartDate >= medDateLimit and 'CDIAlertCategory' in med and med.CDIAlertCategory is not None:
                if any(item == med.CDIAlertCategory for item in medSearchList):
                    medCount += 1
                    unsortedMedDic[medCount] = med
    #Sort List by latest
    mainMedDic = sorted(unsortedMedDic.items(), key=lambda x: x[1]['StartDate'], reverse=True)
    
    #General Subtitle Declaration
    opioidSub = "Possible Opioid Dependence"
    alcoholSub = "Possible Alcohol Withdrawal"
    #Negation
    f1120Code = codeValue("F11.20", "Opioid Dependence: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 0)
    #Abs
    ciwaScoreDV = dvValue(dvCIWAScore, "CIWA Score: [VALUE] (Result Date: [RESULTDATETIME])", calcCIWAScore1, 5)
    ciwaScoreAbs = abstractValue("CIWA_SCORE", "CIWA Score: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6)
    ciwaProtocolAbs = abstractValue("CIWA_PROTOCOL", "CIWA Protocol: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7)
    methadoneClinicAbs = abstractValue("METHADONE_CLINIC", "Methadone Clinic: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13)
    #Meds
    methadoneMed = medValueMulti(dict(mainMedDic), "Methadone", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 7, meds, False)
    methadoneAbs = abstractValue("METHADONE", "Methadone: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8)
    suboxoneMed = medValue("Suboxone", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 11)
    suboxoneAbs = abstractValue("SUBOXONE", "Suboxone: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12)

    #Algorithm
    if (alcoholCodesExist >= 1 and subtitle == alcoholSub) or (opioidCodesExist >= 1 and subtitle == opioidSub):
        db.LogEvaluationScriptMessage("One specific code was on the chart, alert failed" + str(account._id), scriptName, scriptInstance, "Debug")
        if alertTriggered:
            if subtitle == alcoholSub:
                for code in alcoholCodeList:
                    desc = alcoholCodeDic[code]
                    tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code  - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                    if tempCode is not None:
                        dc.Links.Add(tempCode)
                        break
            elif subtitle == opioidSub:
                for code in opioidCodeList:
                    desc = opioidCodeDic[code]
                    tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code  - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                    if tempCode is not None:
                        dc.Links.Add(tempCode)
                        break
            result.Outcome = "AUTORESOLVED"
            result.Reason = "Autoresolved due to one Specified Code on the Account"
            result.Validated = True
            AlertConditions = True
        else: result.Passed = False

    elif opioidCodesExist == 0 and (len(methadoneMed or noLabs) > 1 or methadoneAbs is not None or suboxoneMed is not None or suboxoneAbs is not None or methadoneClinicAbs is not None):
        result.Subtitle = opioidSub
        AlertPassed = True

    elif alcoholCodesExist == 0 and (ciwaScoreDV is not None or ciwaScoreAbs is not None or ciwaProtocolAbs is not None):
        result.Subtitle = alcoholSub
        AlertPassed = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

#Alert Passed Abstractions
if AlertPassed:
    #Abstractions
    multiCodeValue(["F10.20", "F10.21", "F10.220", "F10.221", "F10.229", "F10.24", "F10.250", "F10.251",
                    "F10.259", "F10.26", "F10.27", "F10.280", "F10.281", "F10.282", "F10.288", "F10.29"],
                    "Alcohol Dependence: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, abs, True)
    r4182Code = codeValue("R41.82", "Altered Level Of Consciousness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    alteredAbs = abstractValue("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level Of Consciousness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3)
    if r4182Code is not None:
        abs.Links.Add(r4182Code)
        if alteredAbs is not None: alteredAbs.Hidden = True; abs.Links.Add(alteredAbs)
    elif r4182Code is None and alteredAbs is not None:
        abs.Links.Add(alteredAbs)
    codeValue("R44.0", "Auditory Hallucinations: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, abs, True)
    if ciwaScoreDV is not None: abs.Links.Add(ciwaScoreDV) #5
    if ciwaScoreAbs is not None: abs.Links.Add(ciwaScoreAbs) #6
    if ciwaProtocolAbs is not None: abs.Links.Add(ciwaProtocolAbs) #7
    abstractValue("COMBATIVE", "Combative '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, abs, True)
    abstractValue("DELIRIUM", "Delirum '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, abs, True)
    codeValue("R44.3", "Hallucinations: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, abs, True)
    codeValue("R51.9", "Headache: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, abs, True)
    codeValue("R45.4", "Irritability and Anger: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, abs, True)
    if methadoneClinicAbs is not None: abs.Links.Add(methadoneClinicAbs) #13
    codeValue("R11.0", "Nausea: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, abs, True)
    codeValue("R45.0", "Nervousness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
    abstractValue("ONE_TO_ONE_SUPERVISION", "One to one supervision: '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 16, abs, True)
    codeValue("R11.12", "Projectile Vomiting: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17, abs, True)
    codeValue("R45.1", "Restless and Agitation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, abs, True)
    codeValue("R61", "Sweating: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19, abs, True)
    codeValue("R25.1", "Tremor: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20, abs, True)
    codeValue("R44.1", "Visual Hallucinations: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21, abs, True)
    codeValue("R11.10", "Vomiting: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 22, abs, True)
    #Meds
    medValue("Benzodiazepine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, meds, True)
    abstractValue("BENZODIAZEPINE", "Benzodiazepine: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2, meds, True)
    medValue("Dexmedetomidine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 3, meds, True)
    abstractValue("DEXMEDETOMIDINE", "Dexmedetomidine: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4, meds, True)
    medValue("Lithium", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 5, meds, True)
    abstractValue("LITHIUM", "Lithium: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6, meds, True)
    if methadoneMed is not None:
        for med in methadoneMed:
            meds.Links.Add(med) #7
    if methadoneAbs is not None: meds.Links.Add(methadoneAbs) #8
    medValue("Propofol", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 9, meds, True)
    abstractValue("PROPOFOL", "Propofol: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10, meds, True)
    if suboxoneMed is not None: meds.Links.Add(suboxoneMed) #11
    if suboxoneAbs is not None: meds.Links.Add(suboxoneAbs) #12
    #Document Links
    documentLink("Pain Team Consultation Note", "Pain Team Consultation Note", 0, painLinks, True)
    documentLink("zzPain Team Consultation Note", "zzPain Team Consultation Note", 0, painLinks, True)
    documentLink("Pain Team Progress Note", "Pain Team Progress Note", 0, painLinks, True)

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    if painLinks.Links: result.Links.Add(painLinks); docLinksLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Documented Dx- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", meds- " + str(medsLinks) + ", docs- " + str(docLinksLinks) +
        "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
