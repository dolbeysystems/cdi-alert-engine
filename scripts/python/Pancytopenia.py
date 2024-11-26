##################################################################################################################
#Evaluation Script - Pancytopenia
#
#This script checks an account to see if it matches criteria to be alerted for Pancytopenia
#Date - 11/13/2024
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
    "D61.810": "Antineoplastic Chemotherapy Induced Pancytopenia",
    "D61.811": "Other Drug-Induced Pancytopenia",
    "D61.818": "Other Pancytopenia"
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
dvAbsoluteBasophil = [""]
calcAbsoluteBasophil1 = lambda x: x > 200
dvBasophilAuto = ["BASOPHILS (%)", "BASOS (%)"]
dvAbsoluteEosinophil = ["EOSIN ABSOLUTE (10X3/uL)"]
calcAbsoluteEosinophil1 = lambda x: x > 500
dvEosinophilAuto = ["EOS (%)"]
dvAbsoluteLymphocyte = [""]
calcabsoluteLymphocyte1 = lambda x: x < 1000
dvLymphocyteAuto = ["LYMPHS (%)"]
dvAbsoluteMonocyte = [""]
calcabsoluteMonocyte1 = lambda x: x < 200
dvMonocyteAuto = ["MONOS (%)"]
dvAbsoluteNeutrophil = ["ABS NEUT COUNT (10x3/uL)"]
calcAbsoluteNeutrophil1 = lambda x: x < 1.5
dvNeutrophilAuto = [""]
calcAbSoNeut1 = lambda x: x < 1700
calcAbSoNeut2 = lambda x: x >= 1500
calcdbc1 = lambda x: x >= 0.0
dvHematocrit = ["HEMATOCRIT (%)", "HEMATOCRIT"]
calcHematocrit1 = lambda x: x < 35
calcHematocrit2 = lambda x: x < 40
dvHemoglobin = ["HEMOGLOBIN", "HEMOGLOBIN (g/dL)"]
calcHemoglobin1 = lambda x: x < 13.5
calcHemoglobin2 = lambda x: x < 11.6
calcHemoglobin3 = 13.5
calcHemoglobin4 = 11.6
dvPlateletCount = ["PLATELET COUNT (10x3/uL)"]
calcPlateletCount1 = 150
dvPlateletTransfusion = [""]
dvRBC = [""]
calcRBC1 = lambda x: x > 4.4
dvRedBloodCellTransfusion = [""]
dvSerumFolate = [""]
calcSerumFolate1 = lambda x: x < 18
dvVitaminB12 = ["VITAMIN B12 (pg/mL)"]
calcVitaminB121 = lambda x: x < 180
dvWBC = ["WBC (10x3/ul)"]
calcWBC1 =  4.5

calcAny1 = lambda x: x > 0

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
def HemoglobinPancytopeniaValues(dvDic, gender, value, Needed):
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

def dvValueMultiPancytopenia(dvDic, DV1, linkText, value, sign, sequence=0, category=None, abstract=False, needed=2):
    # Find Discrete Value and if abstract is true abstract it to the provided category
    matchedList = []
    x = 0
    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in DV1 and dvr is not None and sign(float(dvr), float(value)):
            matchedList.append(dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract))
            x += 1
            if x >= needed:
                break
    if abstract and len(matchedList) > 0:
        return True
    elif abstract is False and len(matchedList) > 0:
        return matchedList
    else:
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
dbcLinks = False
dcLinks = False
absLinks = False
labsLinks = False
medsLinks = False
noLabs = []

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 2)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 3)
meds = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 4)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 5)
wbc = MatchedCriteriaLink("White Blood Cells", None, "White Blood Cells", None, True, None, None, 90)
hemoglobin = MatchedCriteriaLink("Hemoglobin", None, "Hemoglobin", None, True, None, None, 91)
hematocrit = MatchedCriteriaLink("Hematocrit", None, "Hematocrit", None, True, None, None, 92)
platelet = MatchedCriteriaLink("Platelet", None, "Platelet", None, True, None, None, 93)
dbc = MatchedCriteriaLink("Differential Blood Count (Auto Diff)", None, "Differential Blood Count (Auto Diff)", None, True, None, None, 94)

#Link Text for special messages for lacking
LinkText1 = "Possibly No Low Hemoglobin Values Found"
LinkText2 = "Possibly No Low White Blood Cell Values Found"
LinkText3 = "Possibly No Low Platelet Values Found"
message1 = False; message2 = False; message3 = False

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Pancytopenia':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        subtitle = alert.Subtitle
        break

#Check if alert was autoresolved or completed.
if validated is False:
    #Find all discrete values for custom lookups within the last 7 days
    maindiscreteDic = {}
    unsortedDicsreteDic = {}
    dvCount = 0
    #Combine all items into one list to search against
    discreteSearchList = [i for j in [dvHemoglobin, dvHematocrit, dvPlateletCount, dvWBC] for i in j]
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
    
    #Negations
    d62Code = codeValue("D62", "Acute Posthemorrhagic Anemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    hemorrhageAbs = abstractValue("HEMORRHAGE", "Hemorrhage: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    #Documented Dx
    d61810Code = codeValue("D61.810", "Antineoplastic chemotherapy induced pancytopenia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    d61811Code = codeValue("D61.811", "Other drug-induced pancytopenia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    d61818Code = codeValue("D61.818", "Other pancytopenia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #abs
    a3e04305Code = codeValue("3E04305", "Chemotherapy Medication Administration: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8)
    currentChemotherapyAbs = abstractValue("CURRENT_CHEMOTHERAPY", "Current Chemotherapy: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11)
    #Meds
    z5111Code = codeValue("Z51.11", "Antineoplastic Chemotherapy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3)
    #Hemoglobin/Hematocrit
    if gender == 'F':
        lowHemoglobinMultiDV = HemoglobinPancytopeniaValues(dict(maindiscreteDic), "Female", 11.6, 10)
    if gender == 'M':
        lowHemoglobinMultiDV = HemoglobinPancytopeniaValues(dict(maindiscreteDic), "Male", 13.5, 10)
    #Platelet
    lowPlateletDV = dvValueMultiPancytopenia(dict(maindiscreteDic), dvPlateletCount, "Platelet Count: [VALUE] (Result Date: [RESULTDATETIME])", calcPlateletCount1, lt, 0, platelet, False, 10)
    #WBC
    lowWBCDV = dvValueMultiPancytopenia(dict(maindiscreteDic), dvWBC, "White Blood Cell Count: [VALUE] (Result Date: [RESULTDATETIME])", calcWBC1, lt, 0, wbc, False, 10)

    #Main Algorithm
    if subtitle == "Pancytopenia Dx Lacking Supporting Evidence" and ((lowHemoglobinMultiDV[0][0] is not False and len(lowHemoglobinMultiDV[0] or noLabs) > 0) and len(lowWBCDV or noLabs) > 0 and len(lowPlateletDV or noLabs) > 0):
        if lowHemoglobinMultiDV[0][0] is not False and len(lowHemoglobinMultiDV[0] or noLabs) > 0 and message1:
            dc.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, False))
        if len(lowWBCDV or noLabs) > 0 and message2:
            dc.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None, False))
        if len(lowPlateletDV or noLabs) > 0 and message3:
            dc.Links.Add(MatchedCriteriaLink(LinkText3, None, None, None, False))
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
        
    elif codesExist > 0 and ((lowHemoglobinMultiDV[0][0] is False and len(lowHemoglobinMultiDV[0] or noLabs) == 0) or len(lowWBCDV or noLabs) == 0 or len(lowPlateletDV or noLabs) == 0):
        for code in codeList:
            desc = codeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, desc +": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            dc.Links.Add(tempCode)
        if (lowHemoglobinMultiDV[0][0] is False and len(lowHemoglobinMultiDV[0] or noLabs) == 0):
            dc.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, True))
        elif lowHemoglobinMultiDV[0][0] is not False and len(lowHemoglobinMultiDV[0] or noLabs) > 0 and message1:
            dc.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, False))
        if len(lowWBCDV or noLabs) == 0:
            dc.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None, True))
        elif len(lowWBCDV or noLabs) > 0 and message2:
            dc.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None, False))
        if len(lowPlateletDV or noLabs) == 0:
            dc.Links.Add(MatchedCriteriaLink(LinkText3, None, None, None, True))
        elif len(lowPlateletDV or noLabs) > 0 and message3:
            dc.Links.Add(MatchedCriteriaLink(LinkText3, None, None, None, False))
        result.Subtitle = "Pancytopenia Dx Lacking Supporting Evidence"
        AlertPassed = True
        
    elif (d61810Code is not None or d61811Code is not None) and subtitle == "Pancytopenia with Possible Link to Chemotherapy":
        if d61810Code is not None: updateLinkText(d61810Code, autoCodeText); dc.Links.Add(d61810Code)
        if d61811Code is not None: updateLinkText(d61811Code, autoCodeText); dc.Links.Add(d61811Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True

    elif d61810Code is None and d61811Code is None and d61818Code is not None and (z5111Code is not None or a3e04305Code is not None or currentChemotherapyAbs is not None):
        dc.Links.Add(d61818Code)
        result.Subtitle = "Pancytopenia with Possible Link to Chemotherapy"
        AlertPassed = True
        
    elif codesExist > 0 and subtitle == "Possible Pancytopenia Dx":
        for code in codeList:
            desc = codeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] ([DOCUMENTTYPE], [DOCUMENTDATE])")
            if tempCode is not None:
                dc.Links.Add(tempCode)
                break
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True

    elif codesExist == 0 and d62Code is None and hemorrhageAbs is None and len(lowWBCDV or noLabs) > 1 and len(lowPlateletDV or noLabs) > 1 and (lowHemoglobinMultiDV[0][0] is not False and len(lowHemoglobinMultiDV[0] or noLabs) > 1) :
        result.Subtitle = "Possible Pancytopenia Dx"
        AlertPassed = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Abs
    prefixCodeValue("^B15\.", "Acute Hepatitis A: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, abs, True)
    prefixCodeValue("^B16\.", "Acute Hepatitis B: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, abs, True)
    prefixCodeValue("^B17\.", "Acute Hepatitis Viral Hepatitis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, abs, True)
    codeValue("T45.1X5A", "Adverse Effect of Antineoplastic and Immunosuppressive Drug: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, abs, True)
    codeValue("F10.20", "Alcohol Abuse: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, abs, True)
    codeValue("D61.9", "Aplastic Anemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, abs, True)
    if a3e04305Code is not None: abs.Links.Add(a3e04305Code) #7
    prefixCodeValue("^B18\.", "Chronic Viral Hepatitis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8, abs, True)
    multiCodeValue(["N18.1","N18.2","N18.30","N18.31","N18.32","N18.4","N18.5", "N18.9"], "Chronic Kidney Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, abs, True)
    if currentChemotherapyAbs is not None: abs.Links.Add(currentChemotherapyAbs) #10
    codeValue("N18.6", "End-Stage Renal Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, abs, True)
    codeValue("R53.83", "Fatigue: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, abs, True)
    prefixCodeValue("^C82\.", "Follicular Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13, abs, True)
    codeValue("E75.22", "Gauchers Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, abs, True)
    codeValue("D76.1", "Hemophagocytic Lymphohistiocytosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
    codeValue("D76.2", "Hemophagocytic Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, abs, True)
    prefixCodeValue("^B20\.", "HIV: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17, abs, True)
    prefixCodeValue("^C81\.", "Hodgkin Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, abs, True)
    codeValue("Z51.12", "Immunotherapy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19, abs, True)
    abstractValue("INFECTION", "Infection: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 20, abs, True)
    prefixCodeValue("^C95\.", "Leukemia of Unspecified Cell Type: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21, abs, True)
    codeValue("K74.60", "Liver Cirrhosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 22, abs, True)
    prefixCodeValue("^C91\.", "Lymphoid Leukemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23, abs, True)
    prefixCodeValue("^C84\.", "Mature T/NK-Cell Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 24, abs, True)
    prefixCodeValue("^C93\.", "Monocytic Leukemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 25, abs, True)
    prefixCodeValue("^C90\.", "Multiple Myeloma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 26, abs, True)
    codeValue("D46.9", "Myelodysplastic Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 27, abs, True)
    prefixCodeValue("^C92\.", "Myeloid Leukemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 28, abs, True)
    prefixCodeValue("^C83\.", "Non-Follicular Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 29, abs, True)
    prefixCodeValue("^C94\.", "Other Leukemias: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 30, abs, True)
    prefixCodeValue("^C86\.", "Other Types of T/NK-Cell Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 31, abs, True)
    codeValue("R23.3", "Petechiae: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 32, abs, True)
    codeValue("Z51.0", "Radiation Therapy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 33, abs, True)
    prefixCodeValue("^M05\.", "Rheumatoid Arthritis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 34, abs, True)
    prefixCodeValue("^M06\.", "Rheumatoid Arthritis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 35, abs, True)
    multiCodeValue(["A41.2", "A41.3", "A41.4", "A41.50", "A41.51", "A41.52", "A41.53", "A41.59", "A41.81", "A41.89", "A41.9", "A42.7", 
            "A22.7", "B37.7", "A26.7", "A54.86", "B00.7", "A32.7", "A24.1", "A20.7", "T81.44XA", "T81.44XD"], 
            "Sepsis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 36, abs, True)
    abstractValue("SHORTNESS_OF_BREATH", "Shortness of Breath '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 37, abs, True)
    codeValue("R16.1", "Splenomegaly: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 38, abs, True)
    prefixCodeValue("^M32\.", "Systemic Lupus Erthematosus (SLE): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 39, abs, True)
    prefixCodeValue("^C85\.", "Unspecified Non-Hodgkin Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 40, abs, True)
    prefixCodeValue("^B19\.", "Unspecified Viral Hepatitis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 41, abs, True)
    abstractValue("WEAKNESS", "Weakness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 42, abs, True)
    #DBC
    dvValue(dvAbsoluteBasophil, "Absolute Basophil Count: [VALUE] (Result Date: [RESULTDATETIME])", calcAbsoluteBasophil1, 1, dbc, True)
    dvValue(dvBasophilAuto, "Basophil %: [VALUE] (Result Date: [RESULTDATETIME])", calcdbc1, 2, dbc, True)
    dvValue(dvAbsoluteEosinophil, "Absolute Eosinophil Count: [VALUE] (Result Date: [RESULTDATETIME])", calcAbsoluteEosinophil1, 3, dbc, True)
    dvValue(dvEosinophilAuto, "Eosinophil %: [VALUE] (Result Date: [RESULTDATETIME])", calcdbc1, 4, dbc, True)
    dvValue(dvAbsoluteLymphocyte, "Absolute Lymphocyte Count: [VALUE] (Result Date: [RESULTDATETIME])", calcabsoluteLymphocyte1, 5, dbc, True)
    dvValue(dvLymphocyteAuto, "Lymphocyte %: [VALUE] (Result Date: [RESULTDATETIME])", calcabsoluteLymphocyte1, 6, dbc, True)
    dvValue(dvAbsoluteMonocyte, "Absolute Monocyte Count: [VALUE] (Result Date: [RESULTDATETIME])", calcabsoluteMonocyte1, 7, dbc, True)
    dvValue(dvMonocyteAuto, "Monocyte %: [VALUE] (Result Date: [RESULTDATETIME])", calcdbc1, 8, dbc, True)
    dvValue(dvAbsoluteNeutrophil, "Absolute Neutrophil Count: [VALUE] (Result Date: [RESULTDATETIME])", calcAbsoluteNeutrophil1, 9, dbc, True)
    dvValue(dvNeutrophilAuto, "Neutrophil %: [VALUE] (Result Date: [RESULTDATETIME])", calcdbc1, 10, dbc, True)
    #Labs
    dvValue(dvRBC, "RBC: [VALUE] (Result Date: [RESULTDATETIME])", calcRBC1, 1)
    dvValue(dvSerumFolate, "Serum Folate: [VALUE] (Result Date: [RESULTDATETIME])", lambda x: True, 2)
    dvValue(dvVitaminB12, "Vitamin B12: [VALUE] (Result Date: [RESULTDATETIME])", calcVitaminB121, 3)
    #Lab Subheadings
    if len(lowPlateletDV or noLabs) > 0:
        for entry in lowPlateletDV:
            platelet.Links.Add(entry)
    if len(lowWBCDV or noLabs) > 0:
        for entry in lowWBCDV:
            wbc.Links.Add(entry)
    if lowHemoglobinMultiDV[0][0] is not False:
        for entry in lowHemoglobinMultiDV[0]:
            hemoglobin.Links.Add(entry)
    if lowHemoglobinMultiDV[1][0] is not False:
        for entry in lowHemoglobinMultiDV[1]:
            hematocrit.Links.Add(entry)
    #Meds
    medValue("Antimetabolite", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, meds, True)
    abstractValue("ANTIMETABOLITE", "Antimetabolite '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2, meds, True)
    if z5111Code is not None: meds.Links.Add(z5111Code) #3
    codeValue("Z51.12", "Antineoplastic Immunotherapy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, meds, True)
    medValue("Antirejection Medication", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 5, meds, True)
    abstractValue("ANTIREJECTION_MEDICATION", "Antirejection Medication '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6, meds, True)
    codeValue("3E04305", "Chemotherapy Administration: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, meds, True)
    medValue("Hemopoietic Agent", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 8, meds, True)
    abstractValue("HEMATOPOIETIC_AGENT", "Hematopoietic Agent '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, meds, True)
    medValue("Interferon", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 10, meds, True)
    abstractValue("INTERFERON", "Interferon '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11, meds, True)
    prefixCodeValue("^Z79\.6", "Long term Immunomodulators and Immunosuppressants: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, abs, True)
    codeValue("Z79.52", "Long term Systemic Steroids: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13, meds, True)
    medValue("Monoclonal Antibodies", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 14, meds, True)
    abstractValue("MONOCLONAL_ANTIBODIES", "Monoclonal Antibodies '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 15, meds, True)
    multiCodeValue(["30233R1", "30243R1"], "Platelet Transfusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, meds, True)
    dvValue(dvPlateletTransfusion, "Platelet Transfusion: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, 17, meds, True)
    multiCodeValue(["30233N1", "30243N1"], "Red Blood Cell Transfusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, meds, True)
    dvValue(dvRedBloodCellTransfusion, "Red Blood Cell Transfusion: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, 19, meds, True)

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if dbc.Links: labs.Links.Add(dbc); dbcLinks = True
    if hematocrit.Links: labs.Links.Add(hematocrit); labsLinks = True
    if hemoglobin.Links: labs.Links.Add(hemoglobin); labsLinks = True
    if platelet.Links: labs.Links.Add(platelet); labsLinks = True
    if wbc.Links: labs.Links.Add(wbc); labsLinks = True
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Documented Dx- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks) + ", dbc- " +
        str(dbcLinks) + ", meds- " + str(medsLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
