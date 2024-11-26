##################################################################################################################
#Evaluation Script - Urinary Tract Infection
#
#This script checks an account to see if it matches criteria to be alerted for Urinary Tract Infection
#Date - 11/19/2024
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
# Script Specific Constants
#========================================
codeDic = {
    "T83.510A": "Infection And Inflammatory Reaction Due To Cystostomy Catheter",
    "T83.510D": "Infection And Inflammatory Reaction Due To Cystostomy Catheter",
    "T83.510S": "Infection And Inflammatory Reaction Due To Cystostomy Catheter",
    "T83.511A": "Infection And Inflammatory Reaction Due To Indwelling Urethral Catheter",
    "T83.511D": "Infection And Inflammatory Reaction Due To Indwelling Urethral Catheter",
    "T83.511S": "Infection And Inflammatory Reaction Due To Indwelling Urethral Catheter",
    "T83.512A": "Infection And Inflammatory Reaction Due To Nephrostomy Catheter",
    "T83.512D": "Infection And Inflammatory Reaction Due To Nephrostomy Catheter",
    "T83.512S": "Infection And Inflammatory Reaction Due To Nephrostomy Catheter",
    "T83.518A": "Infection And Inflammatory Reaction Due To Other Urinary Catheter",
    "T83.518D": "Infection And Inflammatory Reaction Due To Other Urinary Catheter",
    "T83.518S": "Infection And Inflammatory Reaction Due To Other Urinary Catheter"
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
dvBloodInUrine = ["BLOOD"]
calcBloodInUrine1 = lambda x: x > 0
dvCUrine = ["BACTERIA (/HPF)"]
dvGlasgowComaScale = ["3.5 Neuro Glasgow Score"]
calcGlasgowComaScale1 = lambda x: x < 15
dvPusInUrine = [""]
calcPusInUrine1 = lambda x: x > 0
dvTemperature = ["Temperature Degrees C 3.5 (degrees C)", "Temperature  Degrees C 3.5 (degrees C)", "TEMPERATURE (C)"]
calcTemperature1 = lambda x: x > 38.3
dvWBC = ["WBC (10x3/ul)"]
calcwbc1 = lambda x: x > 11

dvUABacteria = ["BACTERIA (/HPF)"]
dvUABlood = ["BLOOD"]
dvUARBC = ["RBC/HPF (/HPF)"]
dvUAProtein = ["PROTEIN (mg/dL)"]
dvUASquamousEpithelias = [""]
dvUAGranCast = [""]
dvUALeakEsterase = ["LEUK ESTERASE"]
dvUAWBC = ["WBC/HPF (/HPF)"]
dvUAHyalineCast = ["HYALINE CASTS (/LPF)"]

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
def dvcUrineCheck(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    abstraction = None
    for dv in dvDic or []:
        if (
            dvDic[dv]['Name'] in discreteValueName and
            dvDic[dv]['Result'] is not None and
            (re.search(r'\bpositive\b', dvDic[dv]['Result'], re.IGNORECASE) is not None or
            re.search(r'\bDetected\b', dvDic[dv]['Result'], re.IGNORECASE) is not None)
        ):
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return abstraction
    return abstraction

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

def dvUrineCheckTwo(dvDic, discreteValueName, value, sign, linkText, sequence=0, category=None, abstract=False):
    abstraction = None
    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in discreteValueName and dvDic[dv]['Result'] is not None and dvr is not None and sign(float(dvr), float(value)):
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

def dvUrineCheckFive(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    abstraction = None
    for dv in dvDic or []:
        if (
            dvDic[dv]['Name'] in discreteValueName and
            dvDic[dv]['Result'] is not None and
            not re.search(r'\bNegative\b', dvDic[dv]['Result'], re.IGNORECASE) and
            not re.search(r'\bTrace\b', dvDic[dv]['Result'], re.IGNORECASE) and
            not re.search(r'\bNot Seen\b', dvDic[dv]['Result'], re.IGNORECASE)
        ):
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, True)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, False)
                return abstraction
    return abstraction

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
CI = 0
urineLinks = False
dcLinks = False
absLinks = False
labsLinks = False
vitalsLinks = False
medsLinks = False
utiLinks = False

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
uti = MatchedCriteriaLink("Urinary Device(s)", None, "Urinary Device(s)", None, True, None, None, 2)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 3)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 4)
vitals = MatchedCriteriaLink("Vital Signs/Intake and Output Data", None, "Vital Signs/Intake and Output Data", None, True, None, None, 5)
meds = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 6)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 7)
urine = MatchedCriteriaLink("Urine Analysis", None, "Urine Analysis", None, True, None, None, 90)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Urinary Tract Infection':
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
    discreteSearchList = [i for j in [dvCUrine, dvUABacteria, dvUAWBC, dvUASquamousEpithelias,
                        dvUARBC, dvUAProtein, dvUAHyalineCast, dvUABlood, dvUAGranCast, dvUALeakEsterase] for i in j]
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
    
    #Alert Trigger
    UTICode = multiCodeValue(["T83.510A","T83.511A","T83.512A","T83.518"], "UTI with Device Link Codes: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    n390Code = codeValue("N39.0", "Urinary Tract Infection: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Abs
    r8271Code = codeValue("R82.71", "Bacteriuria: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    r8279Code = codeValue("R82.79", "Positive Urine Culture: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7)
    r8281Code = codeValue("R82.81", "Pyuria: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8)
    #Labs
    cUrineDV = dvcUrineCheck(dict(maindiscreteDic), dvCUrine, "Urine Culture: '[VALUE]' (Result Date: [RESULTDATETIME])", 4)
    #Urine
    bacteriaUrineDV = dvUrineCheck(dict(maindiscreteDic), dvUABacteria, "UA Bacteria: [VALUE] (Result Date: [RESULTDATETIME])", 1)
    #uti
    chronicCystostomyCatheterAbs = abstractValue("CHRONIC_CYSTOSTOMY_CATHETER", "Cystostomy Catheter '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1)
    cystostomyCatheterAbs = abstractValue("CYSTOSTOMY_CATHETER", "Cystostomy Catheter '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2)
    chronicIndwellingUrethralCatheterAbs = abstractValue("CHRONIC_INDWELLING_URETHRAL_CATHETER", "Indwelling Urethral Catheter '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3)
    indwellingUrethralCatheterAbs = abstractValue("INDWELLING_URETHRAL_CATHETER", "Indwelling Urethral Catheter '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4)
    chronicNephrostomyCatheterAbs = abstractValue("CHRONIC_NEPHROSTOMY_CATHETER", "Nephrostomy Catheter '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5)
    nephrostomyCatheterAbs = abstractValue("NEPHROSTOMY_CATHETER", "Nephrostomy Catheter '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6)
    selfCatheterizationAbs = abstractValue("SELF_CATHETERIZATION", "Self Catheterization '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7)
    straghtCatheterizationAbs = abstractValue("STRAIGHT_CATHETERIZATION", "Straight Catheterization '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8)
    chronicUrinaryDrainageDeviceAbs = abstractValue("CHRONIC_OTHER_URINARY_DRAINAGE_DEVICE", "Urinary Drainage Device '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9)
    urinaryDrainageDeviceAbs = abstractValue("OTHER_URINARY_DRAINAGE_DEVICE", "Urinary Drainage Device '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10)
    chronicUreteralStentAbs = abstractValue("CHRONIC_URETERAL_STENT", "Ureteral Stent '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11)
    ureteralStentAbs = abstractValue("URETERAL_STENT", "Ureteral Stent '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12)
    #Starting Main Algorithm
    #1
    if codesExist >= 1:
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
    #2
    elif UTICode is None and n390Code is not None and (chronicCystostomyCatheterAbs is not None or cystostomyCatheterAbs is not None):
        if chronicCystostomyCatheterAbs is not None: dc.Links.Add(chronicCystostomyCatheterAbs)
        if cystostomyCatheterAbs is not None: dc.Links.Add(cystostomyCatheterAbs)
        dc.Links.Add(n390Code)
        result.Subtitle = "UTI Dx Possible Link To Cystostomy Catheter"
        AlertPassed = True
    #3
    elif UTICode is None and n390Code is not None and (chronicIndwellingUrethralCatheterAbs is not None or indwellingUrethralCatheterAbs is not None):
        if chronicIndwellingUrethralCatheterAbs is not None: dc.Links.Add(chronicIndwellingUrethralCatheterAbs)
        if indwellingUrethralCatheterAbs is not None: dc.Links.Add(indwellingUrethralCatheterAbs)
        dc.Links.Add(n390Code)
        result.Subtitle = "UTI Dx Possible Link To Indwelling Urethral Catheter"
        AlertPassed = True
    #4
    elif UTICode is None and n390Code is not None and (chronicNephrostomyCatheterAbs is not None or nephrostomyCatheterAbs is not None):
        if chronicNephrostomyCatheterAbs is not None: dc.Links.Add(chronicNephrostomyCatheterAbs)
        if nephrostomyCatheterAbs is not None: dc.Links.Add(nephrostomyCatheterAbs)
        dc.Links.Add(n390Code)
        result.Subtitle = "UTI Dx Possible Link To Nephrostomy Catheter"
        AlertPassed = True
    #5
    elif UTICode is None and n390Code is not None and (chronicUrinaryDrainageDeviceAbs is not None or urinaryDrainageDeviceAbs is not None):
        if chronicUrinaryDrainageDeviceAbs is not None: dc.Links.Add(chronicUrinaryDrainageDeviceAbs)
        if urinaryDrainageDeviceAbs is not None: dc.Links.Add(urinaryDrainageDeviceAbs)
        dc.Links.Add(n390Code)
        result.Subtitle = "UTI Dx Possible Link To Other Urinary Drainage Device"
        AlertPassed = True
    #6
    elif UTICode is None and n390Code is not None and (chronicUreteralStentAbs is not None or ureteralStentAbs is not None):
        dc.Links.Add(n390Code)
        if chronicUreteralStentAbs is not None: dc.Links.Add(chronicUreteralStentAbs)
        if ureteralStentAbs is not None: dc.Links.Add(ureteralStentAbs)
        result.Subtitle = "UTI Dx Possible Link To Ureteral Stent"
        AlertPassed = True
    #7
    elif UTICode is None and n390Code is not None and (selfCatheterizationAbs is not None or straghtCatheterizationAbs is not None):
        dc.Links.Add(n390Code)
        if selfCatheterizationAbs is not None: dc.Links.Add(selfCatheterizationAbs)
        if straghtCatheterizationAbs is not None: dc.Links.Add(straghtCatheterizationAbs)
        result.Subtitle = "UTI Dx Possible Link To Intermittent Catheterization"
        AlertPassed = True
    #8
    elif (
        n390Code is None and
        (cUrineDV or
        r8271Code is not None or
        r8279Code is not None or
        bacteriaUrineDV is not None or
        r8281Code is not None) and
        chronicCystostomyCatheterAbs is not None
    ):
        dc.Links.Add(chronicCystostomyCatheterAbs)
        result.Subtitle = "Possible UTI with Possible Link to Cystostomy Catheter"
        AlertPassed = True
    #9
    elif (
        n390Code is None and
        (cUrineDV or
        r8271Code is not None or
        r8279Code is not None or
        bacteriaUrineDV is not None or
        r8281Code is not None) and
        chronicIndwellingUrethralCatheterAbs is not None
    ):
        dc.Links.Add(chronicIndwellingUrethralCatheterAbs)
        result.Subtitle = "Possible UTI With Possible Link to Indwelling Urethral Catheter"
        AlertPassed = True
    #10
    elif (
        n390Code is None and
        (cUrineDV or
        r8271Code is not None or
        r8279Code is not None or
        bacteriaUrineDV is not None or
        r8281Code is not None) and
        chronicNephrostomyCatheterAbs is not None
    ):
        if chronicNephrostomyCatheterAbs is not None: dc.Links.Add(chronicNephrostomyCatheterAbs)
        result.Subtitle = "Possible UTI With Possible Link to Nephrostomy Catheter"
        AlertPassed = True
    #11
    elif (
        n390Code is None and
        (cUrineDV or
        r8271Code is not None or
        r8279Code is not None or
        bacteriaUrineDV is not None or
        r8281Code is not None) and
        chronicUrinaryDrainageDeviceAbs is not None
    ):
        if chronicUrinaryDrainageDeviceAbs is not None: dc.Links.Add(chronicUrinaryDrainageDeviceAbs)
        result.Subtitle = "Possible UTI With Possible Link to Other Urinary Drainage Device"
        AlertPassed = True
    #12
    elif (
        (cUrineDV or
        r8271Code is not None or
        r8279Code is not None or
        bacteriaUrineDV is not None or
        r8281Code is not None) and
        (chronicUreteralStentAbs is not None or
        ureteralStentAbs is not None)
    ):
        if bacteriaUrineDV is not None: dc.Links.Add(bacteriaUrineDV)
        if r8271Code is not None: dc.Links.Add(r8271Code)
        if chronicUreteralStentAbs is not None: dc.Links.Add(chronicUreteralStentAbs)
        if ureteralStentAbs is not None: dc.Links.Add(ureteralStentAbs)
        result.Subtitle = "Possible UTI with Possible Link to Ureteral Stent"
        AlertPassed = True
    #13
    elif (
        (cUrineDV or
        r8271Code is not None or
        r8279Code is not None or
        bacteriaUrineDV is not None or
        r8281Code is not None) and
        (selfCatheterizationAbs is not None or
        straghtCatheterizationAbs is not None)
    ):
        if bacteriaUrineDV is not None: dc.Links.Add(bacteriaUrineDV)
        if r8271Code is not None: dc.Links.Add(r8271Code)
        if selfCatheterizationAbs is not None: dc.Links.Add(selfCatheterizationAbs)
        if straghtCatheterizationAbs is not None: dc.Links.Add(straghtCatheterizationAbs)
        result.Subtitle = "Possible UTI with Possible Link to Intermittent Catheterization"
        AlertPassed = True    
    #14
    elif codesExist == 0 and n390Code is None and (cUrineDV or bacteriaUrineDV):
        result.Subtitle = "Possible UTI"
        AlertPassed = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False
        AlertPassed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Abs
    if r8271Code is not None: abs.Links.Add(r8271Code) #1
    codeValue("R41.0", "Disorientation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, abs, True)
    codeValue("R31.0", "Hematuria: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, abs, True)
    abstractValue("INCREASED_URINARY_FREQUENCY", "Increased Urinary Frequency '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4, abs, True)
    codeValue("R82.998", "Positive Urine Analysis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, abs, True)
    codeValue("R82.89", "Positive Urine Culture: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, abs, True)
    if r8279Code is not None: abs.Links.Add(r8279Code) #7
    if r8281Code is not None: abs.Links.Add(r8281Code) #8
    abstractValue("URINARY_PAIN", "Urinary Pain '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, abs, True)
    abstractValue("UTI_CAUSATIVE_AGENT", "UTI Causative Agent '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10, abs, True)
    #Labs
    dvValue(dvBloodInUrine, "Blood in Urine: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodInUrine1, 1, abs, True)
    dvValue(dvPusInUrine, "Pus in Urine: [VALUE] (Result Date: [RESULTDATETIME])", calcPusInUrine1, 2, labs, True)
    if cUrineDV is not None: labs.Links.Add(cUrineDV) #3
    dvValue(dvWBC, "WBC: [VALUE] (Result Date: [RESULTDATETIME])", calcwbc1, 4, labs, True)
    #Meds
    medValue("Antibiotic", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, meds, True)
    medValue("Antibiotic2", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 2, meds, True)
    abstractValue("ANTIBIOTIC", "Antibiotic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3, meds, True)
    abstractValue("ANTIBIOTIC_2", "Antibiotic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4, meds, True)
    #UTI
    #1-4
    codeValue("0T25X0Z", "Nephrostomy Tube Exchange: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, uti, True)
    codeValue("0T2BX0Z", "Suprapubic/Foley Catheter Exchange: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, uti, True)
    #7
    #Vitals
    r4182Code = codeValue("R41.82", "Altered Level Of Consciousness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    alteredAbs = abstractValue("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level Of Consciousness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2)
    if r4182Code is not None:
        vitals.Links.Add(r4182Code)
        if alteredAbs is not None: alteredAbs.Hidden = True; vitals.Links.Add(alteredAbs)
    elif r4182Code is None and alteredAbs is not None:
        vitals.Links.Add(alteredAbs)
    dvValue(dvGlasgowComaScale, "Glasgow Coma Score: [VALUE] (Result Date: [RESULTDATETIME])", calcGlasgowComaScale1, 3, vitals, True)
    dvValue(dvTemperature, "Temperature: [VALUE] (Result Date: [RESULTDATETIME])", calcTemperature1, 4, vitals, True)
    #Urine
    if bacteriaUrineDV is not None: urine.Links.Add(bacteriaUrineDV) #1
    dvUrineCheck(dict(maindiscreteDic), dvUABlood, "UA Blood: [VALUE] (Result Date: [RESULTDATETIME])", 2, urine, True)
    dvUrineCheck(dict(maindiscreteDic), dvUAGranCast, "UA Gran Cast: [VALUE] (Result Date: [RESULTDATETIME])", 3, urine, True)
    dvUrineCheckFive(dict(maindiscreteDic), dvUAHyalineCast, "UA Hyaline Casts: [VALUE] (Result Date: [RESULTDATETIME])", 4, urine, True)
    dvUrineCheckFive(dict(maindiscreteDic), dvUALeakEsterase, "UA Leak Esterase: [VALUE] (Result Date: [RESULTDATETIME])", 5, urine, True)
    dvUrineCheck(dict(maindiscreteDic), dvUAProtein, "UA Protein: [VALUE] (Result Date: [RESULTDATETIME])", 6, urine, True)
    dvUrineCheckTwo(dict(maindiscreteDic), dvUARBC, 3, gt, "UA RBC: [VALUE] (Result Date: [RESULTDATETIME])", 7, urine, True)
    dvUrineCheckFour(dict(maindiscreteDic), dvUASquamousEpithelias, "UA Squamous Epithelias: [VALUE] (Result Date: [RESULTDATETIME])", 8, urine, True)
    dvUrineCheckTwo(dict(maindiscreteDic), dvUAWBC, 5, gt, "UA WBC: [VALUE] (Result Date: [RESULTDATETIME])", 9, urine, True)
    
#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if urine.Links: labs.Links.Add(urine); urineLinks = True
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    if vitals.Links: result.Links.Add(vitals); vitalsLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    if uti.Links: result.Links.Add(uti); utiLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Documented Dx- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks) + ", vitals- " + str(vitalsLinks) + ", meds- " + str(medsLinks) + ", Uti- " + str(utiLinks) + ", Urine- "
        + str(urineLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
