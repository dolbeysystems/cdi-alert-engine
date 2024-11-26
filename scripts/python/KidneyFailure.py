##################################################################################################################
#Evaluation Script - Kidney Failure
#
#This script checks an account to see if it matches criteria to be alerted for Kidney Failure
#Date - 11/19/2024
#Version - V45
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
specCodeDic = {
    "N17.0": "Acute Kidney Failure With Tubular Necrosis",
    "N17.1": "Acute Kidney Failure With Acute Cortical Necrosis",
    "N17.2": "Acute Kidney Failure With Medullary Necrosis",
    "K76.7": "Hepatorenal Syndrome",
    "K91.83": "Postprocedural Hepatorenal Syndrome"
}
chroCodeDic = {
    "N18.1": "Chronic Kidney Disease, Stage 1",
    "N18.2": "Chronic Kidney Disease, Stage 2 (Mild)",
    "N18.30": "Chronic Kidney Disease, Stage 3 Unspecified",
    "N18.31": "Chronic Kidney Disease, Stage 3a",
    "N18.32": "Chronic Kidney Disease, Stage 3b",
    "N18.4": "Chronic Kidney Disease, Stage 4 (Severe)",
    "N18.5": "Chronic Kidney Disease, Stage 5",
    "N18.6": "End Stage Renal Disease"
}
autoEvidenceText = "Autoresolved Evidence - "
autoCodeText = "Autoresolved Specified Code - "

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
dvGlomerularFiltrationRate = ["GFR (mL/min/1.73m2)"]
calcGlomerularFiltrationRate1 = 60
dvMAP = ["Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)"]
calcMAP1 = lambda x: x < 70
dvSBP = ["SBP 3.5 (No Calculation) (mm Hg)"]
calcSBP1 = lambda x: x < 90
dvSerumBloodUreaNitrogen = ["BUN (mg/dL)"]
calcSerumBloodUreaNitrogen1 = 23
dvSerumCreatinine = ["CREATININE (mg/dL)", "CREATININE SERUM (mg/dL)"]
calcSerumCreatinine1 = 1.02
calcSerumCreatinine2 = 1.50
dvTemperature = ["Temperature Degrees C 3.5 (degrees C)", "Temperature  Degrees C 3.5 (degrees C)", "TEMPERATURE (C)"]
calcTemperature1 = lambda x: x > 38.3
dvUrineSodium = ["URINE SODIUM (mmol/L)"]
calcUrineSodium1 = lambda x: x > 40
calcUrineSodium2 = lambda x: x < 20
dvUrinary = [""]
calcUrinary1 = lambda x: x > 0

dvHeight = [""]

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
def ValueComparison(discreteValue, discreteValue2, value, check=0):
    if value is not None:
        test1 = float(value) / float(discreteValue)
        if test1 >= 1.5:
            return True
    elif value is None and check == 1:
        test3 = ((float(discreteValue2) - float(discreteValue)) / float(discreteValue))
        if test3 >= 0.30:
            return True
    elif value is None and check == 2:
        if (discreteValue > discreteValue2 * 1.5) or (discreteValue < discreteValue2 * 1.5):
            return True
    return False

def creatinineCheck(dvDic, discreteValueName, absValueName, linkText, category, sequence):
    discreteDic = {}
    abstraction = []
    absValue = None
    dateLimit = System.DateTime.Now.AddDays(-2)
    x = 0

    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in discreteValueName and dvr is not None:
                x += 1
                discreteDic[x] = dvDic[dv]
    absValue = None
    for doc in account.Documents:
        for absReference in doc.AbstractionReferences or []:
            if absReference.Code == absValueName and absReference.Value is not None:
                absValue = absReference.Value
    #Check 1
    if absValue is not None:
        for item in discreteDic:
            if ValueComparison(cleanNumbers(discreteDic[item].Result), None, absValue):
                abstraction.append(dataConversion(discreteDic[item].ResultDate, linkText, discreteDic[item].Result, discreteDic[item]._id or discreteDic[item].UniqueId, category, sequence, False))
        if len(abstraction) > 0:
            db.LogEvaluationScriptMessage("Creatinine Check 1 Passed " + str(account._id), scriptName, scriptInstance, "Debug")
            return abstraction
    #Check 2
    if x > 1:
        for item in discreteDic:
            id1 = discreteDic[item]._id or discreteDic[item].UniqueId
            if discreteDic[item].ResultDate >= dateLimit:
                for item2 in discreteDic:
                    id2 = discreteDic[item2]._id or discreteDic[item2].UniqueId
                    if discreteDic[item2].ResultDate >= dateLimit and discreteDic[item2].ResultDate >= discreteDic[item].ResultDate and (id2 != id1) and float(discreteDic[item2].Result) > float(1.0):
                        if ValueComparison(cleanNumbers(discreteDic[item].Result), cleanNumbers(discreteDic[item2].Result), absValue, 1):
                            abstraction.append(dataConversion(discreteDic[item2].ResultDate, linkText, discreteDic[item2].Result, discreteDic[item2]._id or discreteDic[item2].UniqueId, category, sequence, False))
                            abstraction.append(dataConversion(discreteDic[item].ResultDate, linkText, discreteDic[item].Result, discreteDic[item]._id or discreteDic[item].UniqueId, category, sequence, False))
                            db.LogEvaluationScriptMessage("Creatinine Check 2 Passed " + str(account._id), scriptName, scriptInstance, "Debug")
                            return abstraction
    #Check 4
    if x > 1:
        for item in discreteDic:
            id1 = discreteDic[item]._id or discreteDic[item].UniqueId
            for item2 in discreteDic:
                id2 = discreteDic[item2]._id or discreteDic[item2].UniqueId
                if discreteDic[item2].ResultDate >= discreteDic[item] and (id2 != id1):
                    if ValueComparison(cleanNumbers(discreteDic[item].Result), cleanNumbers(discreteDic[item2].Result), absValue, 2):
                        abstraction.append(dataConversion(discreteDic[item2].ResultDate, linkText, discreteDic[item2].Result, discreteDic[item2]._id or discreteDic[item2].UniqueId, category, sequence, False))
                        abstraction.append(dataConversion(discreteDic[item].ResultDate, linkText, discreteDic[item].Result, discreteDic[item]._id or discreteDic[item].UniqueId, category, sequence, False))
                        db.LogEvaluationScriptMessage("Creatinine Check 4 Passed " + str(account._id), scriptName, scriptInstance, "Debug")
                        return abstraction
    #Check 3
    if x > 1:
        abstraction = dvValueMulti(dict(maindiscreteDic), dvSerumCreatinine, "Serum Creatinine: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumCreatinine2, gt, 2, creatinine, False, 10)
        if len(abstraction or noLabs) > 1:
            db.LogEvaluationScriptMessage("Creatinine Check 3 Passed " + str(account._id), scriptName, scriptInstance, "Debug")
            return abstraction

    return None

def IsValuesGreaterThanThreeDays(dvDic, discreteValueName, value, linkText, category, sequence=1):
    dayOne = System.DateTime.Now.AddDays(-1)
    dayTwo = System.DateTime.Now.AddDays(-2)
    dayThree = System.DateTime.Now.AddDays(-3)
    dayFour = System.DateTime.Now.AddDays(-4)
    discreteDic1 = {}
    discreteDic2 = {}
    discreteDic3 = {}
    discreteDic4 = {}
    w = 0
    x = 0
    y = 0
    z = 0
    abstraction = []
    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in discreteValueName and dvDic[dv]['Result'] is not None: convertedResult = dvr
        else: convertedResult = None
        if convertedResult is not None and convertedResult > value and dvDic[dv]['ResultDate'] <= dayOne:
            discreteDic1[w] = dvDic[dv]
        elif convertedResult is not None and convertedResult > value and dayTwo <= dvDic[dv]['ResultDate'] <= dayOne:
            discreteDic2[x] = dvDic[dv]
        elif convertedResult is not None and convertedResult > value and dayThree <= dvDic[dv]['ResultDate'] <= dayTwo:
            discreteDic3[y] = dvDic[dv]
        elif convertedResult is not None and convertedResult > value and dayFour <= dvDic[dv]['ResultDate'] <= dayThree:
            discreteDic4[z] = dvDic[dv]
    if (
        (w > 0 and x > 0 and y > 0) or
        (x > 0 and y > 0 and z > 0)
    ):
        if w > 0:
            abstraction.append(dataConversion(discreteDic1[w].ResultDate, linkText, discreteDic1[w].Result, discreteDic1[w].UniqueId or discreteDic1[w]._id, category, sequence, False))
        if x > 0:
            abstraction.append(dataConversion(discreteDic2[x].ResultDate, linkText, discreteDic2[x].Result, discreteDic2[x].UniqueId or discreteDic2[x]._id, category, sequence, False))
        if y > 0:
            abstraction.append(dataConversion(discreteDic3[y].ResultDate, linkText, discreteDic3[y].Result, discreteDic3[y].UniqueId or discreteDic3[y]._id, category, sequence, False))
        if z > 0:
            abstraction.append(dataConversion(discreteDic4[z].ResultDate, linkText, discreteDic4[z].Result, discreteDic4[z].UniqueId or discreteDic4[z]._id, category, sequence, False))
        return abstraction
    return None

def dvUrineCheck(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    abstraction = None
    for dv in dvDic or []:
        if dvDic[dv]['Name'] in discreteValueName and dvDic[dv]['Result'] is not None and re.search(r'\d\+', dvDic[dv]['Result']) is not None:
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return abstraction
    return abstraction

def dvUrineCheckTwo(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    abstraction = None
    for dv in dvDic or []:
        if dvDic[dv]['Name'] in discreteValueName and dvDic[dv]['Result'] is not None and re.search(r'\b0-5\b', dvDic[dv]['Result'], re.IGNORECASE) is None:
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return abstraction
    return abstraction

def dvUrineCheckThree(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    abstraction = None
    for dv in dvDic or []:
        if dvDic[dv]['Name'] in discreteValueName and dvDic[dv]['Result'] is not None and re.search(r'\b0-4\b', dvDic[dv]['Result'], re.IGNORECASE) is None:
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return abstraction
    return abstraction

def dvUrineCheckFour(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    abstraction = None
    for dv in dvDic or []:
        if dvDic[dv]['Name'] in discreteValueName and dvDic[dv]['Result'] is not None:
            list = []
            list = dvDic[dv]['Result'].split('-')
            list[0]
            if list[0] > 20 or list[1] > 20:
                if abstract:
                    dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                    return True
                else:
                    abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                    return abstraction
    return abstraction

def idealUrineCalc(dvDic, height, urine, gender, category):
    LinkText1 = "Possible Low Urine Output"
    urineDic = {}
    heightDic = {}
    x = 0
    y = 0
    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in height and dvr is not None:
            y += 1
            heightDic[y] = dvDic[dv]
        elif dvDic[dv]['Name'] in urine and dvr is not None:
            x += 1
            urineDic[x] = dvDic[dv]
    if x > 0 and y > 0:
        if gender == 'F':
            output = (((float(heightDic[y].Result) - 105.0) * 0.5) * 24)
            if float(urineDic[x].Result) < float(output):
                category.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None))
                return True
            else:
                return False
        elif gender == 'M':
            output = (((float(heightDic[y].Result) - 100.0) * 0.5) * 24)
            if float(urineDic[x].Result) < float(output):
                category.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None))
                return True
            else:
                return False
        else:
            return False
    else:
            return False
        
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
db.LogEvaluationScriptMessage("Script starting " + str(account._id), scriptName, scriptInstance, "Debug")
#Determine if if and how many fully spec codes are on the acct
chroCodes = []
chroCodes = chroCodeDic.keys()
chroCodeList = CodeCount(chroCodes)
chroCodesExist = len(chroCodeList)
str1 = ', '.join([str(elem) for elem in chroCodeList])

specCodes = []
specCodes = specCodeDic.keys()
specCodeList = CodeCount(specCodes)
specCodesExist = len(specCodeList)
str2 = ', '.join([str(elem) for elem in specCodeList])

#Standard Variable Declaration
AlertPassed = False
alertTriggered = False
AlertConditions = False
validated = False
outcome = None
subtitle = None
CI = 0
triggerAlert = True
reason = None
creatinineLinks = False
gfrLinks = False
dcLinks = False
absLinks = False
labsLinks = False
treatmentLinks = False
vitalsLinks = False
message1 = False
creatinineSpecCheck = False
noLabs = []
check3 = False
otherChecks = False

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 2)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 3)
vitals = MatchedCriteriaLink("Vital Signs/Intake and Output Data", None, "Vital Signs/Intake and Output Data", None, True, None, None, 4)
treatment = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 5)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 6)
gfr = MatchedCriteriaLink("GFR", None, "GFR", None, True, None, None, 89)
creatinine = MatchedCriteriaLink("Serum Creatinine", None, "Serum Creatinine", None, True, None, None, 90)
bun = MatchedCriteriaLink("Blood Urea Nitrogen", None, "Blood Urea Nitrogen", None, True, None, None, 91)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Kidney Failure':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        reason = alert.Reason
        if outcome == 'AUTORESOLVED' or reason == 'Previously Autoresolved':
            triggerAlert = False
        subtitle = alert.Subtitle
        break

#Abstractions or DV values that if true could retrigger the alert.
maindiscreteDic = {}
unsortedDicsreteDic = {}
dvCount = 0
#Combine all items into one list to search against
discreteSearchList = [i for j in [dvGlomerularFiltrationRate, dvSerumCreatinine, dvHeight, dvUrinary, dvSerumBloodUreaNitrogen] for i in j]
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

#Alert Triggers
n179Code = codeValue("N17.9", "Acute Kidney Failure, Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
#Labs
highSerumCreatinineMultiDayDV = IsValuesGreaterThanThreeDays(dict(maindiscreteDic), dvSerumCreatinine, 1.2, "Serum Creatinine Multiple Days: [VALUE] (Result Date: [RESULTDATETIME])", creatinine)

#Check if alert was autoresolved or completed.
if (
    validated is False or
    (outcome == "AUTORESOLVED" and validated and (specCodesExist > 1 or chroCodesExist > 1 or (n179Code is not None and highSerumCreatinineMultiDayDV is not None and specCodesExist == 0)))
):    
    #Negations
    negationKidneyFailure = multiCodeValue(["N17.0", "N17.1", "N17.2", "N18.1", "N18.2 ", "N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6", "N18.9"], "Kidney Failure Codes: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    n181Code = codeValue("N18.1", "Chronic Kidney Disease, Stage 1: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    n182Code = codeValue("N18.2", "Chronic Kidney Disease, Stage 2 (Mild): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    n1830Code = codeValue("N18.30", "Chronic Kidney Disease, Stage 3 Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    n1831Code = codeValue("N18.31", "Chronic Kidney Disease, Stage 3a: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    n1832Code = codeValue("N18.32", "Chronic Kidney Disease, Stage 3b: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    n184Code = codeValue("N18.4", "Chronic Kidney Disease, Stage 4 (Severe): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    n185Code = codeValue("N18.5", "Chronic Kidney Disease, Stage 5: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    n186Code = codeValue("N18.6", "End stage renal disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Alert Triggers
    n19Code = codeValue("N19", "Unspecified Kidney Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    n17Codes = multiCodeValue(["N17.0", "N17.1", "N17.2"], "Kidney Failure Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    n189Code = codeValue("N18.9", "Chronic Kidney Disease, Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    creatinineCheckDV = creatinineCheck(dict(maindiscreteDic), dvSerumCreatinine, "BASELINE_CREATININE", "Serum Creatinine: [VALUE] (Result Date: [RESULTDATETIME])", creatinine, 1)
    creatininieMultiDV = dvValueMulti(dict(maindiscreteDic), dvSerumCreatinine, "Serum Creatinine: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumCreatinine1, ge, 0, creatinine, False, 10)
    acutChroUnspecKFAbs = abstractValue("ACUTE_ON_CHRONIC_KIDNEY_FAILURE", "Acute and Chronic Unspecified Kidney Failure Present '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    baselineCreatinineAbs = abstractValue("BASELINE_CREATININE", "Baseline Creatinine: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    acuteKidneyInjuryAbs = abstractValue("ACUTE_KIDNEY_INJURY", "Acute Kidney Injury: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    acuteRenalInsufficiencyAbs = abstractValue("ACUTE_RENAL_INSUFFICIENCY", "Acute Renal Insufficiency: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    #Abs
    dialysisDependentAbs = abstractValue("DIALYSIS_DEPENDENT", "Dialysis Dependent '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 17)
    #Labs
    gfrDV = dvValueMulti(dict(maindiscreteDic), dvGlomerularFiltrationRate, "Glomerular Filtration: [VALUE] (Result Date: [RESULTDATETIME])", calcGlomerularFiltrationRate1, le, 1, gfr, False, 10)
    #Vitals
    urineCalc = idealUrineCalc(dict(maindiscreteDic), dvHeight, dvUrinary, gender, vitals)

    #Check for creatinine Check check 3
    if creatinineCheckDV is not None:
        for item in creatinineCheckDV:
            if item.Sequence == 2:
                check3 = True
            if item.Sequence == 0:
                otherChecks = True
                
    #Main Algorithm Starting
    #1
    if chroCodesExist > 1 and (n184Code is not None or n185Code is not None or n186Code is not None):
        for code in chroCodeList:
            desc = chroCodeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            dc.Links.Add(tempCode)
        if validated:
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"
            result.Validated = False
        result.Subtitle = "Conflicting CKD Dx " + str1
        AlertPassed = True
    #2
    elif specCodesExist > 1:
        if gfrDV is None:
            dvValueMulti(dict(maindiscreteDic), dvGlomerularFiltrationRate, "Glomerular Filtration: [VALUE] (Result Date: [RESULTDATETIME])", calcGlomerularFiltrationRate1, gt, 3, gfr, True, 5)
        for code in specCodeList:
            desc = specCodeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            dc.Links.Add(tempCode)
        if validated:
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"
            result.Validated = False
        result.Subtitle = "Conflicting Acute Kidney Failure Dx Codes " + str1
        AlertPassed = True
    #3.1
    elif subtitle == "Possible End-Stage Renal Disease" and n186Code is not None:
        if n186Code is not None: updateLinkText(n186Code, autoCodeText); dc.Links.Add(n186Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #3
    elif (
        triggerAlert and 
        (n189Code is not None or n181Code is not None or n182Code is not None or 
         n1830Code is not None or n1831Code is not None or n1832Code is not None or 
         n184Code is not None or n185Code is not None) and 
        dialysisDependentAbs is not None and 
        chroCodesExist < 2 and 
        n186Code is None
    ):
        if n189Code is not None: dc.Links.Add(n189Code)
        if n181Code is not None: dc.Links.Add(n181Code)
        if n182Code is not None: dc.Links.Add(n182Code)
        if n1830Code is not None: dc.Links.Add(n1830Code)
        if n1831Code is not None: dc.Links.Add(n1831Code)
        if n1832Code is not None: dc.Links.Add(n1832Code)
        if n184Code is not None: dc.Links.Add(n184Code)
        if n185Code is not None: dc.Links.Add(n185Code)
        result.Subtitle = "Possible End-Stage Renal Disease"
        AlertPassed = True
    #4.1
    elif chroCodesExist > 0 and specCodesExist > 0 and subtitle == "Acute Kidney Failure Unspecified Present Possible ATN":
        if chroCodesExist > 0:
            for code in chroCodeList:
                desc = chroCodeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    dc.Links.Add(tempCode)
                    break
        if specCodesExist > 0:
            for code in specCodeList:
                desc = specCodeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    dc.Links.Add(tempCode)
                    break
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #4   
    elif n179Code is not None and highSerumCreatinineMultiDayDV is not None and chroCodesExist == 0 and specCodesExist == 0:
        if highSerumCreatinineMultiDayDV is not None:
            for entry in highSerumCreatinineMultiDayDV:
                creatinine.Links.Add(entry)
        dc.Links.Add(n179Code)
        if baselineCreatinineAbs is not None: dc.Links.Add(baselineCreatinineAbs)
        if validated:
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"
            result.Validated = False
        result.Subtitle = "Acute Kidney Failure Unspecified Present Possible ATN"
        AlertPassed = True
    #5.1
    elif subtitle == "Acute Kidney Failure/AKI Present Possible Lacking Clinical Evidence" and creatininieMultiDV is not None: 
        if highSerumCreatinineMultiDayDV is not None:
            for entry in highSerumCreatinineMultiDayDV:
                creatinine.Links.Add(entry)
        if creatinineCheckDV is not None:
            for entry in creatinineCheckDV:
                creatinine.Links.Add(entry)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #5
    elif (
        (n179Code is not None or n17Codes is not None) and 
        n181Code is None and n182Code is None and n1830Code is None and n1831Code is None and n1832Code is None and n184Code is None and n185Code is None and n186Code is None and n189Code is None and
        creatininieMultiDV is None
    ):
        if n179Code is not None: dc.Links.Add(n179Code)
        if n17Codes is not None: dc.Links.Add(n17Codes)
        result.Subtitle = "Acute Kidney Failure/AKI Present Possible Lacking Clinical Evidence"
        AlertPassed = True   
    #6.1
    elif subtitle == "Acute Kidney Failure/AKI Present Possible Lacking Clinical Evidence" and (highSerumCreatinineMultiDayDV is not None or creatinineCheckDV is not None): 
        if highSerumCreatinineMultiDayDV is not None:
            for entry in highSerumCreatinineMultiDayDV:
                creatinine.Links.Add(entry)
        if creatinineCheckDV is not None:
            for entry in creatinineCheckDV:
                creatinine.Links.Add(entry)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #6
    elif (
        (n179Code is not None or n17Codes is not None) and 
        highSerumCreatinineMultiDayDV is None and creatinineCheckDV is None
    ):
        if n179Code is not None: dc.Links.Add(n179Code)
        if n17Codes is not None: dc.Links.Add(n17Codes)
        result.Subtitle = "Acute Kidney Failure/AKI Present Possible Lacking Clinical Evidence"
        AlertPassed = True
    #7.1
    elif chroCodesExist > 0 and subtitle == "CKD No Stage Documented":
        for code in chroCodeList:
            desc = chroCodeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            if tempCode is not None:
                dc.Links.Add(tempCode)
                break
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #7
    elif n189Code is not None and chroCodesExist == 0 and gfrDV is not None:
        dc.Links.Add(n189Code)
        result.Subtitle = "CKD No Stage Documented"
        AlertPassed = True    
    #8.1
    elif subtitle == "Kidney Failure Dx Missing Acuity" and (n179Code is not None or chroCodesExist > 0 or specCodesExist > 0):
        if n179Code is not None: updateLinkText(n179Code, autoCodeText); dc.Links.Add(n179Code)
        if chroCodesExist > 0:
            for code in chroCodeList:
                desc = chroCodeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    dc.Links.Add(tempCode)
                    break
        if specCodesExist > 0:
            for code in specCodeList:
                desc = specCodeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    dc.Links.Add(tempCode)
                    break
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #8
    elif n19Code is not None and chroCodesExist == 0 and specCodesExist == 0:
        dc.Links.Add(n19Code)
        result.Subtitle = "Kidney Failure Dx Missing Acuity"
        AlertPassed = True
    #9.1    
    elif (specCodesExist > 0 or n179Code is not None or chroCodesExist == 1) and subtitle == "Possible Acute Kidney Failure/AKI":
        if chroCodesExist > 0:
            for code in chroCodeList:
                desc = chroCodeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    dc.Links.Add(tempCode)
                    break
        if specCodesExist > 0:
            for code in specCodeList:
                desc = specCodeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    dc.Links.Add(tempCode)
                    break
        if n179Code is not None: updateLinkText(n179Code, autoCodeText); dc.Links.Add(n179Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True  
    #9    
    elif n19Code is None and chroCodesExist == 0 and specCodesExist == 0 and n179Code is None and n189Code is None and creatinineCheckDV is not None:
        if creatinineCheckDV is not None:
            for entry in creatinineCheckDV:
                creatinine.Links.Add(entry)
        creatinineSpecCheck = True
        result.Subtitle = "Possible Acute Kidney Failure/AKI"  
        AlertPassed = True
    
    #10.1
    elif (specCodesExist > 0 or n179Code is not None) and subtitle == "Possible Chronic Kidney Failure with Superimposed AKI":
        for code in chroCodeList:
            desc = chroCodeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            if tempCode is not None:
                dc.Links.Add(tempCode)
                break
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #10
    elif chroCodesExist == 1 and n186Code is None and specCodesExist == 0 and n179Code is None and creatinineCheckDV is not None and (check3 is False or otherChecks is True) and baselineCreatinineAbs is not None:
        if baselineCreatinineAbs is not None: dc.Links.Add(baselineCreatinineAbs)
        for code in chroCodeList:
            desc = chroCodeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            dc.Links.Add(tempCode)
        if creatinineCheckDV is not None:
            for entry in creatinineCheckDV:
                creatinine.Links.Add(entry)
        creatinineSpecCheck = True
        result.Subtitle = "Possible Chronic Kidney Failure with Superimposed AKI"  
        AlertPassed = True
        
    #11.1
    elif subtitle == "Conflicting AKI and Renal Insufficiency Dx, Clarification Needed" and specCodesExist > 0:
        for code in specCodeList:
            desc = specCodeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            if tempCode is not None:
                dc.Links.Add(tempCode)
                break
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #11
    elif acuteKidneyInjuryAbs is not None and acuteRenalInsufficiencyAbs is not None and specCodesExist == 0:
        if acuteKidneyInjuryAbs is not None: dc.Links.Add(acuteKidneyInjuryAbs)
        if acuteRenalInsufficiencyAbs is not None: dc.Links.Add(acuteRenalInsufficiencyAbs)
        AlertPassed = True
        result.Subtitle = "Conflicting AKI and Renal Insufficiency Dx, Clarification Needed"

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        AlertPassed = False
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Abs
    codeValue("R82.998", "Abnormal Urine Findings: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, abs, True)
    codeValue("D62", "Acute Blood Loss Anemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, abs, True)
    prefixCodeValue("^N00\.", "Acute Nephritic Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, abs, True)
    codeValue("N10", "Acute Pyelonephritis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, abs, True)
    codeValue("T39.5X5A", "Adverse effect from Aminoglycoside [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, abs, True)
    codeValue("T39.395A", "Adverse effect from NSAID: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, abs, True)
    codeValue("T39.0X5A", "Adverse effect from Sulfonamide [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, abs, True)
    r4182Code = codeValue("R41.82", "Altered Level Of Consciousness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8)
    alteredAbs = abstractValue("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level Of Consciousness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9)
    if r4182Code is not None:
        abs.Links.Add(r4182Code)
        if alteredAbs is not None: alteredAbs.Hidden = True; abs.Links.Add(alteredAbs)
    elif r4182Code is None and alteredAbs is not None:
        abs.Links.Add(alteredAbs)
    codeValue("R60.1", "Anasarca: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, abs, True)
    codeValue("N26.1", "Atrophic Kidneys: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, abs, True)
    abstractValue("AZOTEMIA", "Azotemia: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12, abs, True)
    codeValue("R57.0", "Cardiogenic Shock: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13, abs, True)
    codeValue("5A1D90Z", "Continuous, Hemodialysis Greater than 18 Hours Per Day: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, abs, True)
    codeValue("N14.11", "Contrast Induced Nephropathy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
    codeValue("T50.8X5A", "Contrast Nephropathy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, abs, True)
    #17
    abstractValue("DECOMPENSATED_HEART_FAILURE", "Decompensated Heart Failure '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 18, abs, True)
    codeValue("E86.0", "Dehydration: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19, abs, True)
    codeValue("R41.0", "Disorientation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20, abs, True)
    codeValue("R53.83", "Fatigue: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21, abs, True)
    abstractValue("FLANK_PAIN", "Flank Pain '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 22, abs, True)
    codeValue("E87.70", "Fluid Overloaded: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23, abs, True)
    codeValue("M32.14", "Glomerular Disease in SLE: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 24, abs, True)
    multiCodeValue(["D59.30", "D59.31", "D59.32", "D59.39"], "Hemolytic-Uremic Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 25, abs, True)
    codeValue("R31.0", "Hematuria: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 26, abs, True)
    abstractValue("HEMORRHAGE", "Hemorrhage: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 27, abs, True)
    codeValue("Z94.0", "History of Kidney Transplant: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 28, abs, True)
    codeValue("B20", "HIV: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 29, abs, True)
    abstractValue("HYDRONEPHROSIS", "Hydronephrosis '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 30, abs, True)
    codeValue("N13.4", "Hydroureter: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 31, abs, True)
    codeValue("E86.1", "Hypovolemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 32, abs, True)
    codeValue("R57.1", "Hypovolemic Shock: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 33, abs, True)
    abstractValue("INCREASED_URINARY_FREQUENCY", "Increased Urinary Frequency '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 34, abs, True)
    codeValue("5A1D70Z", "Intermittent Hemodialysis Less than 6 Hours Per Day: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 35, abs, True)
    abstractValue("KIDNEY_STONES", "Kidney Stones '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 36, abs, True)
    codeValue("N20.2", "Kidney and Ureter Stone: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 37, abs, True)
    codeValue("N15.9", "Kidney Infection: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 38, abs, True)
    abstractValue("LOSS_OF_APPETITE", "Loss of Appetite'[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 39, abs, True)
    abstractValue("LOWER_EXTREMITY_EDEMA", "Lower Extremity Edema '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 40, abs, True)
    codeValue("N14.3", "Nephropathy induced by Heavy Metals: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 41, abs, True)
    codeValue("N14.2", "Nephropathy induced by Unspecified Drug: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 42, abs, True)
    prefixCodeValue("^N04\.", "Nephrotic Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 43, abs, True)
    multiCodeValue(["T39.5X1A", "T39.5X2A", "T39.5X3A", "T39.5X4A"], "Poisoning by Aminoglycoside [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 44, abs, True)
    multiCodeValue(["T39.391A", "T39.392A", "T39.393A", "T39.394A"], "Poisoning by NSAID: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 45, abs, True)
    multiCodeValue(["T39.0X1A", "T39.0X2A", "T39.0X3A", "T39.0X4A"], "Poisoning by Sulfonamide [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 46, abs, True)
    codeValue("5A1D80Z", "Prolonged Intermittent Hemodialysis 6-18 Hours Per Day: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 47, abs, True)
    codeValue("R80.9", "Proteinuria: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 48, abs, True)
    codeValue("M62.82", "Rhabdomyolysis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 49, abs, True)
    prefixCodeValue("^A40\.", "Sepsis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 50, abs, True)
    prefixCodeValue("^A41\.", "Sepsis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 51, abs, True)
    multiCodeValue(["R57.8", "R57.9"], "Shock: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 52, abs, True)
    abstractValue("SHORTNESS_OF_BREATH", "Shortness of Breath '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 53, abs, True)
    codeValue("N14.4", "Toxic Nephropathy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 54, abs, True)
    codeValue("N12", "Tubulo-Interstital Nephritis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 55, abs, True)
    codeValue("M32.15", "Tubulo-Interstitial Nephropathy in SLE: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 56, abs, True)
    codeValue("N20.1", "Ureter Stone: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 57, abs, True)
    abstractValue("URINE_OUTPUT", "Urine Output: [ABSTRACTVALUE] ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 58, abs, True)
    codeValue("E86.9", "Volume Depletion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 59, abs, True)
    codeValue("R11.10", "Vomiting: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 60, abs, True)
    codeValue("R11.11", "Vomiting without Nausea: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 61, abs, True)
    codeValue("R28.0", "Ischemia/Infarction of Kidney: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 62, abs, True)
    abstractValue("URINARY_PAIN", "Urinary Pain '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 63, abs, True)
    #Labs
    abstractValue("BASELINE_CREATININE", "Baseline Creatinine: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1, labs, True)
    abstractValue("BASELINE_GLOMERULAR_FILTRATION_RATE", "Baseline Glomerular Filtration Rate '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2, labs, True)
    dvValue(dvUrineSodium, "Urine Sodium Concentration: [VALUE] (Result Date: [RESULTDATETIME])", calcUrineSodium2, 3, labs, True)
    dvValue(dvUrineSodium, "Urine Sodium Concentration: [VALUE] (Result Date: [RESULTDATETIME])", calcUrineSodium1, 4, labs, True)
    #Lab Sub Categorys
    dvLookUpAllValuesSingleLine(dict(maindiscreteDic), dvSerumCreatinine, 0, creatinine, "Serum Creatinine: (DATE1 - DATE2) - ")
    if creatinineSpecCheck is False:
        dvValueMulti(dict(maindiscreteDic), dvSerumCreatinine, "Serum Creatinine: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumCreatinine1, gt, 1, creatinine, True, 10)
    dvLookUpAllValuesSingleLine(dict(maindiscreteDic), dvGlomerularFiltrationRate, 0, gfr, "Glomerular Filtration: (DATE1 - DATE2) - ")
    if gfrDV is not None:
        for entry in gfrDV:
            gfr.Links.Add(entry) #1
    dvLookUpAllValuesSingleLine(dict(maindiscreteDic), dvSerumBloodUreaNitrogen, 0, bun, "Serum Blood Urea Nitrogen: (DATE1 - DATE2) - ")
    dvValueMulti(dict(maindiscreteDic), dvSerumBloodUreaNitrogen, "Serum Blood Urea Nitrogen: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumBloodUreaNitrogen1, gt, 1, bun, True, 10)
    #Meds
    medValue("Albumin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, treatment, True)
    abstractValue("AVOID_NEPHROTOXIC_AGENT", "Avoid Nephrotoxic Agent: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2, treatment, True)
    medValue("Bumetanide", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 3, treatment, True)
    abstractValue("BUMETANIDE", "Bumetanide '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4, treatment, True)
    medValue("Diuretic", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 5, treatment, True)
    abstractValue("DIURETIC", "Diuretic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6, treatment, True)
    medValue("Fluid Bolus", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 7, treatment, True)
    abstractValue("FLUID_BOLUS", "Fluid Bolus '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, treatment, True)
    medValue("Furosemide", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 9, treatment, True)
    abstractValue("FUROSEMIDE", "Furosemide '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10, treatment, True)
    #Vitals
    dvValue(dvTemperature, "Temperature: [VALUE] (Result Date: [RESULTDATETIME])", calcTemperature1, 1, vitals, True)
    dvValue(dvMAP, "Mean Arterial Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcMAP1, 2, vitals, True)
    dvValue(dvUrinary, "Urine Output: [VALUE] (Result Date: [RESULTDATETIME])", calcUrinary1, 3, vitals, True)
    dvValue(dvSBP, "Systolic Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcSBP1, 4, vitals, True)

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if gfr.Links: labs.Links.Add(gfr); labLinks = True
    if bun.Links: labs.Links.Add(bun); labLinks = True
    if creatinine.Links: labs.Links.Add(creatinine); labLinks = True
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    result.Links.Add(treatment)
    if treatment.Links: treatmentLinks = True
    if vitals.Links: result.Links.Add(vitals); vitalsLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Documented Dx- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks) + ", vitals- " + str(vitalsLinks) +
        ", Treatment- " + str(treatmentLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
