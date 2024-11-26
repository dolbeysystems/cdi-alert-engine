##################################################################################################################
#Evaluation Script - Nicotine Dependence With Withdrawal
#
#This script checks an account to see if it matches criteria to be alerted for Nicotine Dependence With Withdrawal
#Date - 10/24/2024
#Version - V8
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
    "F17.203": "Nicotine Dependence Unspecified, With Withdrawal",
    "F17.213": "Nicotine Dependence, Cigarettes, With Withdrawal",
    "F17.223": "Nicotine Dependence, Chewing Tobacco, With Withdrawal",
    "F17.293": "Nicotine Dependence, Other Tobacco Product, With Withdrawal"
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
#dvAcetone = ["Acetone (Ketones)"]
#calcAcetone1 = lambda x: x > 0

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
codePresent = False
dcLinks = False
treatmentLinks = False
withdrawalLinks = False

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
treatment = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 2)
withdrawal = MatchedCriteriaLink("Withdrawal Symptoms", None, "Withdrawal Symptoms", None, True, None, None, 3)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 4)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Nicotine Dependence':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        subtitle = alert.Subtitle
        break

#Check if alert was autoresolved or completed.
if validated is False:
    #Alert Trigger
    f17200Code = codeValue("F17.200", "Nicotine Dependence, Unspecified, Uncomplicated: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    f17208Code = codeValue("F17.208", "Nicotine Dependence, Unspecified, With Other Nicotine-Induced Disorders: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    f17209Code = codeValue("F17.209", "Nicotine Dependence, Unspecified, With Unspecified Nicotine-Induced Disorders: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    f1721Code = codeValue("F17.21", "Nicotine Dependence, Cigarettes: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    f17210Code = codeValue("F17.210", "Nicotine Dependence, Cigarettes, Uncomplicated: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    f17218Code = codeValue("F17.218", "Nicotine Dependence, Cigarettes, With Other Nicotine-Induced Disorders: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    f17219Code = codeValue("F17.219", "Nicotine Dependence, Cigarettes, With Unspecified Nicotine-Induced Disorders: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    f1722Code = codeValue("F17.22", "Nicotine Dependence, Chewing Tobacco: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    f17220Code = codeValue("F17.220", "Nicotine Dependence, Chewing Tobacco, Uncomplicated: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    f17228Code = codeValue("F17.228", "Nicotine Dependence, Chewing Tobacco, With Other Nicotine-Induced Disorders: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    f17229Code = codeValue("F17.229", "Nicotine Dependence, Chewing Tobacco, With Unspecified Nicotine-Induced Disorders: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    f1729Code = codeValue("F17.29", "Nicotine Dependence, Other Tobacco Product: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    f17290Code = codeValue("F17.290", "Nicotine Dependence, Other Tobacco Product, Uncomplicated: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    f17298Code = codeValue("F17.298", "Nicotine Dependence, Other Tobacco Product, With Other Nicotine-Induced Disorders: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    f17299Code = codeValue("F17.299", "Nicotine Dependence, Other Tobacco Product, Wwith Unspecified Nicotine-Induced Disorders: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Meds
    nicotineWithdrawalMeds = medValue("Nicotine Withdrawal Medication", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, treatment, True)
    nicotineWithdrawalMedsAbs = abstractValue("NICOTINE_WITHDRAWAL_MEDICATION", "Nicotine Withdrawal Medication '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2)
    #Withdrawal Symptoms
    r41840Code = codeValue("R41.840", "Difficulty Concentrating: [CODE] ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    headacheAbs = abstractValue("HEADACHE", "Headache ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2)
    r454Code = codeValue("R45.4", "Irritability: [CODE] ([DOCUMENTTYPE], [DOCUMENTDATE])", 3)
    g4700Code = codeValue("G47.00", "Insomnia: [CODE] ([DOCUMENTTYPE], [DOCUMENTDATE])", 4)
    r450Code = codeValue("R45.0", "Nervousness/Anxious: [CODE] ([DOCUMENTTYPE], [DOCUMENTDATE])", 5)
    nicotineCravingsAbs = abstractValue("NICOTINE_CRAVINGS", "Nicotine Cravings ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6)
    r451Code = codeValue("R45.1", "Restlessness and Agitated: [CODE] ([DOCUMENTTYPE], [DOCUMENTDATE])", 7)

    #Code Present Determination
    if f17200Code is not None: dc.Links.Add(f17200Code); codePresent = True
    if f17208Code is not None: dc.Links.Add(f17208Code); codePresent = True
    if f17209Code is not None: dc.Links.Add(f17209Code); codePresent = True
    if f1721Code is not None: dc.Links.Add(f1721Code); codePresent = True
    if f17210Code is not None: dc.Links.Add(f17210Code); codePresent = True
    if f17218Code is not None: dc.Links.Add(f17218Code); codePresent = True
    if f17219Code is not None: dc.Links.Add(f17219Code); codePresent = True
    if f1722Code is not None: dc.Links.Add(f1722Code); codePresent = True
    if f17220Code is not None: dc.Links.Add(f17220Code); codePresent = True
    if f17228Code is not None: dc.Links.Add(f17228Code); codePresent = True
    if f17229Code is not None: dc.Links.Add(f17229Code); codePresent = True
    if f1729Code is not None: dc.Links.Add(f1729Code); codePresent = True
    if f17290Code is not None: dc.Links.Add(f17290Code); codePresent = True
    if f17298Code is not None: dc.Links.Add(f17298Code); codePresent = True
    if f17299Code is not None: dc.Links.Add(f17299Code); codePresent = True

    #Main Algorithm
    if codesExist >= 1:
        db.LogEvaluationScriptMessage("Nicotine Withdrawal Code Present, alert failed. " + str(account._id), scriptName, scriptInstance, "Debug")
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
        codePresent and (nicotineWithdrawalMedsAbs is not None or nicotineWithdrawalMeds is not None) and
        (headacheAbs is not None or r454Code is not None or g4700Code is not None or r450Code is not None or
        nicotineCravingsAbs is not None or r451Code is not None or r41840Code is not None)
        ):
        if nicotineWithdrawalMeds is not None: treatment.Links.Add(nicotineWithdrawalMeds)
        if nicotineWithdrawalMedsAbs is not None: treatment.Links.Add(nicotineWithdrawalMedsAbs)
        if headacheAbs is not None: dc.Links.Add(headacheAbs)
        if r454Code is not None: dc.Links.Add(r454Code)
        if g4700Code is not None: dc.Links.Add(g4700Code)
        if r450Code is not None: dc.Links.Add(r450Code)
        if nicotineCravingsAbs is not None: dc.Links.Add(nicotineCravingsAbs)
        if r451Code is not None: dc.Links.Add(r451Code)
        if r41840Code is not None: dc.Links.Add(r41840Code)
        AlertPassed = True
        result.Subtitle = "Nicotine Dependence present with possible Withdrawal"

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #abs
    abstractValue("CIGARETTE_PACK_HISTORY", "Cigarette Pack History '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1)

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if dc.Links: result.Links.Add(dc); dcLinks = True
    result.Links.Add(treatment)
    if treatment.Links: treatmentLinks = True
    if withdrawal.Links: result.Links.Add(withdrawal); withdrawalLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Documented Dx- " + str(dcLinks) + ", Withdrawal- " + str(withdrawalLinks) + ", treatment- "
        + str(treatmentLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
