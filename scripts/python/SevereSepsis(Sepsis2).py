##################################################################################################################
#Evaluation Script - Severe Sepsis
#
#This script checks an account to see if it matches criteria to be alerted for Severe Sepsis using Sepsis 2 Criteria
#Date - 11/14/2024
#Version - V24
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
    "A40.0": "Sepsis Due To Streptococcus, Group A",
    "A40.1": "Sepsis due to Streptococcus, Group B",
    "A40.3": "Sepsis due to Streptococcus Pneumoniae",
    "A40.8": "Other Streptococcal Sepsis",
    "A40.9": "Streptococcal Sepsis, Unspecified",
    "A41.01": "Sepsis due to Methicillin Susceptible Staphylococcus Aureus",
    "A41.02": "Sepsis due To Methicillin Resistant Staphylococcus Aureus",
    "A41.1": "Sepsis due to Other Specified Staphylococcus",
    "A41.2": "Sepsis due to Unspecified Staphylococcus",
    "A41.3": "Sepsis due to Hemophilus Influenzae",
    "A41.4": "Sepsis due to Anaerobes",
    "A41.50": "Gram-Negative Sepsis, Unspecified",
    "A41.51": "Sepsis due to Escherichia Coli [E. Coli]",
    "A41.52": "Sepsis due to Pseudomonas",
    "A41.53": "Sepsis due to Serratia",
    "A41.54": "Sepsis Due to Acinetobacter Baumannii",
    "A41.59": "Other Gram-Negative Sepsis",
    "A41.81": "Sepsis due to Enterococcus",
    "A41.89": "Other Specified Sepsis ",
    "A42.7": "Actinomycotic Sepsis",
    "A22.7": "Anthrax Sepsis",
    "B37.7": "Candidal Sepsis",
    "A26.7": "Erysipelothrix Sepsis",
    "A54.86": "Gonococcal Sepsis",
    "B00.7": "Herpesviral Sepsis",
    "A32.7": "Listerial Sepsis",
    "A24.1": "Melioidosis Sepsis",
    "A20.7": "Septicemic Plague",
    "T81.44XA": "Sepsis Following A Procedure",
    "T81.44XD": "Sepsis Following A Procedure",
    "T81.44XS": "Sepsis Following a Procedure, Sequela"
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
dvArterialBloodOxygen = ["BLD GAS O2 (mmHg)", "PO2 (mmHg)"]
calcArterialBloodOxygen1 = lambda x: x < 60
dvDBP = ["BP Arterial Diastolic cc (mm Hg)", "DBP 3.5 (No Calculation) (mmhg)", "DBP 3.5 (No Calculation) (mm Hg)"]
dvGlasgowComaScale = ["3.5 Neuro Glasgow Score"]
calcGlasgowComaScale1 = lambda x: x < 15
calcGlasgowComaScale2 = lambda x: x < 12
dvHeartRate = ["Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)", "3.5 Heart Rate (Radial) (bpm)",  "SCC Monitor Pulse (bpm)"]
dvMAP = ["Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)"]
calcMAP1 = lambda x: x < 60
calcMAP2 = 60
dvPlateletCount = ["PLATELET COUNT (10x3/uL)"]
calcPlateletCountSevereSepsis1 = lambda x: x <= 100
calcPlateletCount1 = lambda x: x < 150
calcPlateletCount2 = lambda x: x < 100
dvP02FIO2 = ["PO2/FiO2 (mmHg)"]
calcP02FIO21 = lambda x: x <= 300
dvPOCLactate = [""]
calcPOCLactate1 = lambda x: 2 >= x < 4
calcPOCLactate2 = lambda x: x >= 4
dvSBP = ["SBP 3.5 (No Calculation) (mm Hg)"]
calcSBP1 = lambda x: x < 90
calcSBP2 = 90
dvSerumBilirubin = ["BILIRUBIN (mg/dL)"]
calcSerumBilirubin1 = lambda x: x >= 2.0
dvSerumCreatinine = ["CREATININE (mg/dL)", "CREATININE SERUM (mg/dL)"]
calcSerumCreatinine1 = lambda x: x > 1.3
dvSerumLactate = ["LACTIC ACID (mmol/L)", "LACTATE (mmol/L)"]
calcSerumLactate1 = 4
calcSerumLactate2 = lambda x: 2 <= x < 4
dvSpO2 = ["Pulse Oximetry(Num) (%)"]
calcSpO21 = lambda x: x < 90

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
def anesthesiaMedValue(medDic, med_name, link_text, sequence=0, category=None, abstract=False):
    for mv in medDic or []:
        if (
            medDic[mv]['Route'] is not None and
            medDic[mv]['Dosage'] is not None and
            medDic[mv]['Category'] == med_name and
            (re.search(r'\bhr\b', medDic[mv]['Dosage'], re.IGNORECASE) or
            re.search(r'\bhour\b', medDic[mv]['Dosage'], re.IGNORECASE) or 
            re.search(r'\bmin\b', medDic[mv]['Dosage'], re.IGNORECASE) or
            re.search(r'\bminute\b', medDic[mv]['Dosage'], re.IGNORECASE)) and
            (re.search(r'\bIntravenous\b', medDic[mv]['Route'], re.IGNORECASE) or
            re.search(r'\bIV Push\b', medDic[mv]['Route'], re.IGNORECASE))
        ):
            if abstract == True:
                medDataConversion(medDic[mv]['StartDate'], link_text, medDic[mv]['Medication'], medDic[mv]['ExternalId'], medDic[mv]['Dosage'], medDic[mv]['Route'], category, sequence)
                return True
            elif abstract == False:
                abstraction = medDataConversion(medDic[mv]['StartDate'], link_text, medDic[mv]['Medication'], medDic[mv]['ExternalId'], medDic[mv]['Dosage'], medDic[mv]['Route'], category, sequence, abstract)
                return abstraction
    return None

def medDataConversion(datetime, linkText, med, id, dosage, route, category, sequence, abstract=True):
    date_time = datetimeFromUtcToLocal(datetime)
    date_time = date_time.ToString("MM/dd/yyyy, HH:mm")
    linkText = linkText.replace("[STARTDATE]", date_time)
    linkText = linkText.replace("[MEDICATION]", med)
    linkText = linkText.replace("[DOSAGE]", dosage)
    abstracation = None
    if route is not None: linkText = linkText.replace("[ROUTE]", route)
    else: linkText = linkText.replace(", Route [ROUTE]", "")
    if abstract == True:
        abstraction = MatchedCriteriaLink(linkText, None, None, None, True, None, None, sequence)
        abstraction.MedicationId = id
        category.Links.Add(abstraction)
    elif abstract == False:
        abstraction = MatchedCriteriaLink(linkText, None, None, None, True, None, None, sequence)
        abstraction.MedicationId = id
        return abstraction
    return
    
def dvValueMultiMin(dvDic):
    discreteDic1 = {}
    discreteDic2 = {}
    discreteDic3 = {}
    discreteDic4 = {}
    discreteDic5 = {}
    mapLinkText = "Mean Arterial Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])"
    sbpLinkText = "Systolic Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])"
    s = 0
    d = 0
    m = 0
    h = 0
    mM = 0
    sM = 0
    sm = 0
    matchedSBPList = []
    matchedMAPList = []

    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in dvMAP and dvr is not None:
            #Mean Arterial Blood Pressure
            m += 1
            discreteDic1[m] = dvDic[dv]
            if float(cleanNumbers(dvDic[dv].Result)) < float(calcMAP2):
                sm += 1
                mM += 1
                discreteDic5[sm] = dvDic[dv]
        elif dvDic[dv]['Name'] in dvSBP and dvr is not None:
            #Systolic Blood Pressure
            s += 1
            discreteDic2[s] = dvDic[dv]
            if float(cleanNumbers(dvDic[dv].Result)) < float(calcSBP2):
                sm += 1
                sM += 1
                discreteDic5[sm] = dvDic[dv]
        elif dvDic[dv]['Name'] in dvHeartRate and dvr is not None:
            #Heart Rate
            h += 1
            discreteDic3[h] = dvDic[dv]
        elif dvDic[dv]['Name'] in dvDBP and dvr is not None:
            #Diastolic Blood Pressure
            d += 1
            discreteDic4[d] = dvDic[dv]
                
    if sM > 1 or mM > 1:
        abstractedList = []
        for item in discreteDic5:
            dbpDv = None
            hrDv = None
            mapDv = None
            sbpDv = None
            id = None
            matchingDate = discreteDic5[item].ResultDate
            if discreteDic5[item]['Name'] in dvSBP and discreteDic3[item]['_id'] not in abstractedList:
                matchingDate = discreteDic5[item].ResultDate
                sbpDv = discreteDic5[item].Result
                abstractedList.append(discreteDic5[item]._id)
                id = discreteDic5[item]._id
                matchedSBPList.append(dataConversion(discreteDic5[item].ResultDate, sbpLinkText, discreteDic5[item].Result, discreteDic5[item]._id, sbpODS, 0, False))
                for item1 in discreteDic1:
                    if discreteDic1[item1].ResultDate == matchingDate and discreteDic1[item1].Name in dvMAP:
                        mapDv = discreteDic1[item1].Result
                        abstractedList.append(discreteDic1[item1]._id)
                        break
            elif discreteDic5[item]['Name'] in dvMAP and float(discreteDic5[item]['Result']) < float(calcMAP1) and discreteDic5[item]['_id'] not in abstractedList:
                matchingDate = discreteDic5[item].ResultDate
                mapDv = discreteDic5[item].Result
                abstractedList.append(discreteDic5[item]._id)
                id = discreteDic5[item]._id
                matchedMAPList.append(dataConversion(discreteDic5[item].ResultDate, mapLinkText, discreteDic5[item].Result, discreteDic5[item]._id, mapODS, 0, False))
                for item1 in discreteDic2:
                    if discreteDic2[item1].ResultDate == matchingDate and discreteDic2[item1].Name in dvSBP:
                        sbpDv = discreteDic2[item1].Result
                        abstractedList.append(discreteDic2[item1]._id)
                        break
            if h > 0:
                for item2 in discreteDic3:
                    if discreteDic3[item2].ResultDate == matchingDate:
                        hrDv = discreteDic3[item2].Result
                        break
            if d > 0:
                for item3 in discreteDic4:
                    if discreteDic4[item3].ResultDate == matchingDate:
                        dbpDv = discreteDic4[item3].Result
                        break

            if dbpDv is None:
                dbpDv = 'XX'
            if hrDv is None:
                hrDv = 'XX'
            if mapDv is None:
                mapDv = 'XX'
            if sbpDv is None:
                sbpDv = 'XX'
            if id is not None and matchingDate is not None:
                dataConversion(matchingDate, "[RESULTDATETIME] HR = " + str(hrDv) + ", BP = " + str(sbpDv) + "/" + str(dbpDv) + ", MAP = " + str(mapDv), None, id, septic, 0, True)

    elif sM == 1 or mM == 1:    
        for item in discreteDic5:
            if discreteDic5[item].Name in dvSBP:
                matchedSBPList.append(dataConversion(discreteDic5[item].ResultDate, sbpLinkText, discreteDic5[item].Result, discreteDic5[item]._id, sbpODS, 0, False))
            elif discreteDic5[item].Name in dvMAP:
                matchedMAPList.append(dataConversion(discreteDic5[item].ResultDate, mapLinkText, discreteDic5[item].Result, discreteDic5[item]._id, mapODS, 0, False))
        
    if len(matchedSBPList) == 0:
        matchedSBPList = [False]
    if len(matchedMAPList) == 0:
        matchedMAPList = [False]
    return [matchedSBPList, matchedMAPList]    

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
SSI = 0; ODS = 0
outcome = None
subtitle = None
dcLinks = False
organLinks = False
medsLinks = False
septicLinks = False

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
organ = MatchedCriteriaLink("Organ Dysfunction Sign", None, "Organ Dysfunction Sign", None, True, None, None, 2)
septic = MatchedCriteriaLink("Septic Shock Indicators", None, "Septic Shock Indicators", None, True, None, None, 3)
meds = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 4)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 5)
sbpODS = MatchedCriteriaLink("SBP", None, "SBP", None, True, None, None, 90)
mapODS = MatchedCriteriaLink("MAP", None, "MAP", None, True, None, None, 91)
lactateODS = MatchedCriteriaLink("Lactate", None, "Lactate", None, True, None, None, 92)
lactateSSI = MatchedCriteriaLink("Lactate", None, "Lactate", None, True, None, None, 92)

#Link Text for lacking messages
LinkText1 = "Possible Missing Signs of Septic Shock Please Review"
LinkText2 = "Possible Missing Signs of Organ Dysfunction Please Review"
message1 = False
message2 = False

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Severe Sepsis':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        subtitle = alert.Subtitle
        reason = alert.Reason
        subtitle = alert.Subtitle
        for alertLink in alert.Links:
            if alertLink.LinkText == 'Septic Shock Evidence':
                for links in alertLink.Links:
                    if links.LinkText == LinkText1:
                        message1 = True
            if alertLink.LinkText == 'Organ Dysfunction Sign':
                for links in alertLink.Links:
                    if links.LinkText == LinkText2:
                        message2 = True
        break

#Check if alert was autoresolved or completed.
if validated is False:
    #Find all discrete values for custom lookups within the last 7 days
    maindiscreteDic = {}
    unsortedDicsreteDic = {}
    dvCount = 0
    #Combine all items into one list to search against
    discreteSearchList = [i for j in [dvSBP, dvMAP, dvSerumLactate, dvPOCLactate, dvDBP, dvHeartRate] for i in j]
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
    
    #Get meds within last X days
    mainMedDic = {}
    unsortedMedDic = {}
    medCount = 0
    #Combine all items into one list to search against
    medSearchList = ["Beta Blocker", "Bumetanide", "Furosemide", "Epinephrine", "Levophed", "Vasopressin", "Neosynephrine"]
    #Set datelimit for how far back to 
    medDateLimit = System.DateTime.Now.AddDays(-7)
    #Loop through all meds finding any that match in the combined list adding to a dictionary the matches
    if 'Medications' in account:    
        for med in account.Medications:
            if med.StartDate >= medDateLimit and 'Category' in med and med.Category is not None:
                if any(item == med.Category for item in medSearchList):
                    medCount += 1
                    unsortedMedDic[medCount] = med
    #Sort List by latest
    mainMedDic = sorted(unsortedMedDic.items(), key=lambda x: x[1]['StartDate'], reverse=True)
    
    #Negations
    liverCirrhosisCheck = multiCodeValue(["K70.0", "K70.10", "K70.11", "K70.2", "K70.30", "K70.31", "K70.40", "K70.41", "K70.9", "K74.60", "K72.1",
            "K71", "K71.0", "K71.10", "K71.11", "K71.2", "K71.3", "K71.4", "K71.50", "K71.51", "K71.6", "K71.7", "K71.8",
            "K71.9", "K72.10", "K72.11", "K73.0", "K73.1", "K73.2", "K73.8", "K73.9", "R18.0"],
            "Liver Cirrhosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    alcoholAndOpioidAbuseCheck = multiCodeValue(["F10.920", "F10.921", "F10.929", "F10.930", "F10.931", "F10.932",
            "F10.939", "F11.120", "F11.121", "F11.122", "F11.129", "F11.13"], "Alcohol and Opioid Abuse: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    chronicKidneyFailureCheck = multiCodeValue(["N18.30", "N18.31", "N18.32", "N18.4", "N18.5", "N18.6", "N18.9"],
            "Chronic Kidney Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Alert Trigger
    r579Code = codeValue("R57.9", "Shock, unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    r6520Code = codeValue("R65.20", "Severe Sepsis without Septic Shock: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    r6521Code = codeValue("R65.21", "Severe Sepsis with Septic Shock: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    sepsisCode = multiCodeValue(["A40.0", "A40.1", "A40.3", "A40.8", "A40.9", " A41.01", "A41.02", "A41.1", "A41.2", "A41.3", "A41.4",
            "A41.9", "A41.50", "A41.51", "A41.52", "A41.53", "A41.54", "A41.59", "A41.8", "A41.81", "A41.89", "A42.7", "A22.7", "B37.7",
            "A26.7", "A54.86", "B00.7", "A32.7", "A24.1", "A20.7", "T81.44XA", "T81.44XD", "T81.44XS"],
            "Sepsis Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Meds
    dobutamine = medValue("Dobutamine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 2)
    if dobutamine is None:
        dobutamine = abstractValue("DOBUTAMINE", "Dobutamine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3)
    dopamine = medValue("Dopamine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 4)
    if dopamine is None:
        dopamine = abstractValue("DOPAMINE", "Dopamine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5)
    epinephrine = anesthesiaMedValue(dict(mainMedDic), "Epinephrine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 6)
    if epinephrine is None:
        epinephrine = abstractValue("EPINEPHRINE", "Epinephrine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7)
    levophed = anesthesiaMedValue(dict(mainMedDic), "Levophed", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 9)
    if levophed is None:        
        levophed = abstractValue("LEVOPHED", "Levophed '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10)
    milrinone = medValue("Milrinone", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 11)
    if milrinone is None:
        milrinone = abstractValue("MILRINONE", "Milrinone '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12)
    neosynephrine = anesthesiaMedValue(dict(mainMedDic), "Neosynephrine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 13)
    if neosynephrine is None:
        neosynephrine = abstractValue("NEOSYNEPHRINE", "Neosynephrine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 14)
    vasoactiveMedicationAbs = abstractValue("VASOACTIVE_MEDICATION", "Vasoactive Medication '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 15)
    vasopressin = anesthesiaMedValue(dict(mainMedDic), "Vasopressin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 16)
    if vasopressin is None:        
        vasopressin = abstractValue("VASOPRESSIN", "Vasopressin '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 17)
    #Organ Dysfunction
    g9341Code = codeValue("G93.41", "Acute Metabolic Encephalopathy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    acuteHeartFailure = multiCodeValue(["I50.21", "I50.31", "I50.41"], "Acute Heart Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    acuteKidneyFailure = prefixCodeValue("^N17\.", "Acute Kidney Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3)
    acuteLiverFailure = multiCodeValue(["K72.00", "K72.01"], "Acute Liver Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4)
    i21aCode = codeValue("I21.A", "Acute MI Type 2: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5)
    acuteRespiratroyFailure = multiCodeValue(["J96.00", "J96.01", "J96.02"], "Acute Respiratory Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6)
    r4182Code = codeValue("R41.82", "Altered Level of Consciousness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7)
    alteredAbs = abstractValue("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level Of Consciousness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8)
    lowBloodPressureAbs = abstractValue("LOW_BLOOD_PRESSURE", "Blood Pressure: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9)
    r410Code = codeValue("R41.0", "Disorientation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10)
    glasgowComaScoreDV = dvValue(dvGlasgowComaScale, "Glasgow Coma Score: [VALUE] (Result Date: [RESULTDATETIME])", calcGlasgowComaScale2, 11)
    lowMeanArterialBloodPressureDV = dvValue(dvMAP, "Mean Arterial Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcMAP1, 12)
    pa02DV = dvValue(dvArterialBloodOxygen, "pa02: [VALUE] (Result Date: [RESULTDATETIME])", calcArterialBloodOxygen1, 13)
    p02fio2DV = dvValue(dvP02FIO2, "PaO2/FIO2 Ratio: [VALUE] (Result Date: [RESULTDATETIME])", calcP02FIO21, 14)
    lowPlateletCountDV = dvValue(dvPlateletCount, "Platelet Count: [VALUE] (Result Date: [RESULTDATETIME])", calcPlateletCountSevereSepsis1, 15)
    highSerumBilirubinDV = dvValue(dvSerumBilirubin, "Serum Bilirubin: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumBilirubin1, 16)
    highSerumCreatinineDV = dvValue(dvSerumCreatinine, "Serum Creatinine: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumCreatinine1, 17)
    highSerumLactate2DV = compareValuesMulti(dict(maindiscreteDic), dvSerumLactate, 2, 4, "Serum Lactate: [VALUE] (Result Date: [RESULTDATETIME])", le, lt, 0, lactateODS, False, 10)
    highPOCLactate2DV = compareValuesMulti(dict(maindiscreteDic), dvSerumLactate, 2, 4, "Serum Lactate: [VALUE] (Result Date: [RESULTDATETIME])", le, lt, 0, lactateODS, False, 10)
    spO2DV = dvValue(dvSpO2, "SP02: [VALUE] (Result Date: [RESULTDATETIME])", calcSpO21, 20)
    lowSystolicBloodPressureDV = dvValue(dvSBP, "Systolic Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcSBP1, 21)
    lowUrineOutputAbs = abstractValue("LOW_URINE_OUTPUT", "Urine Output '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 22)
    #Septic Shock
    highSerumLactate4DV = dvValueMulti(dict(maindiscreteDic), dvSerumLactate, "Serum Lactate: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumLactate1, ge, 0, lactateSSI, False, 10)
    highPOCLactate4DV = dvValueMulti(dict(maindiscreteDic), dvPOCLactate, "Serum Lactate: [VALUE] (Result Date: [RESULTDATETIME])", calcPOCLactate2, ge, 0, lactateSSI, False, 10)    #Septic Shock Subheadings
    multiSBPmapDV = dvValueMultiMin(dict(maindiscreteDic))
    
    #Organ Dysfunction Sign  
    if (
        ((g9341Code is not None or glasgowComaScoreDV is not None) and alcoholAndOpioidAbuseCheck is None) or
        (r4182Code is not None or alteredAbs is not None ) or
        r410Code is not None
    ):
        ODS += 1

    if (
        lowBloodPressureAbs is not None or
        lowMeanArterialBloodPressureDV is not None or
        lowSystolicBloodPressureDV is not None
    ):
        ODS += 1
    
    if (
        p02fio2DV is not None or
        acuteRespiratroyFailure is not None or
        spO2DV is not None or
        pa02DV is not None
    ):
        ODS += 1 
    
    if (highSerumBilirubinDV is not None and liverCirrhosisCheck is None) or acuteLiverFailure is not None: ODS += 1
    
    if (
        (highSerumCreatinineDV is not None and chronicKidneyFailureCheck is None) or 
        lowUrineOutputAbs is not None or
        acuteKidneyFailure is not None
    ):
        ODS += 1
    if acuteHeartFailure is not None: ODS += 1
    if lowPlateletCountDV is not None: ODS += 1
    if highSerumLactate2DV is not None or highPOCLactate2DV is not None: ODS += 1
    if i21aCode is not None: ODS += 1
    if multiSBPmapDV[0][0] is not False and len(multiSBPmapDV[0]) == 1:
        ODS += 1
        for entry in multiSBPmapDV[0]:
            sbpODS.Links.Add(entry)
        organ.Links.Add(sbpODS)
    if multiSBPmapDV[1][0] is not False and len(multiSBPmapDV[1]) == 1:
        ODS += 1
        for entry in multiSBPmapDV[1]:
            mapODS.Links.Add(entry)
        organ.Links.Add(mapODS)

    #Septic Shock Indicators
    if multiSBPmapDV[0][0] is not False and len(multiSBPmapDV[0]) > 1:
        SSI += 1
    if multiSBPmapDV[1][0] is not False and len(multiSBPmapDV[1]) > 1:
        SSI += 1
    if highSerumLactate4DV is not None or highPOCLactate4DV is not None:
        SSI += 1
    if (
        epinephrine is not None or
        levophed is not None or
        milrinone is not None or
        neosynephrine is not None or
        vasoactiveMedicationAbs is not None or
        vasopressin is not None or
        dobutamine is not None or
        dopamine is not None
    ):
        SSI += 1
        
    #Main alert Algorithm
    if subtitle == "Severe Sepsis with Septic Shock Possibly Lacking Supporting Evidence" and ODS > 0 and SSI > 0:
        if message1:
            septic.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, False))
        if message2:
            organ.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None, False))
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to clinical evidence now existing on the Account"
        result.Validated = True
        AlertPassed = True
            
    elif r6521Code is not None and (ODS == 0 or SSI == 0):
        if ODS == 0:
            organ.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None, True))
        if SSI == 0:
            septic.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, True))
        if r6521Code is not None: dc.Links.Add(r6521Code)
        result.Subtitle = "Severe Sepsis with Septic Shock Possibly Lacking Supporting Evidence"
        AlertPassed = True
        
    elif subtitle == "Severe Sepsis without Septic Shock Possibly Lacking Supporting Evidence" and ODS > 0:
        if message2:
            organ.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None, False))
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to clinical evidence now existing on the Account"
        result.Validated = True
        AlertPassed = True
        
    elif r6520Code is not None and ODS == 0:
        organ.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None, True))
        dc.Links.Add(r6520Code)
        result.Subtitle = "Severe Sepsis without Septic Shock Possibly Lacking Supporting Evidence"
        AlertPassed = True
    
    elif subtitle == "Possible Severe Sepsis without Septic Shock present" and (r6520Code is not None or r6521Code is not None):
        if r6520Code is not None: dc.Links.Add(r6520Code)
        if r6521Code is not None: dc.Links.Add(r6521Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to specified code now existing on the Account"
        AlertConditions = True
     
    elif sepsisCode is not None and r6520Code is None and r6521Code is None and ODS >= 2 and SSI == 0:
        dc.Links.Add(sepsisCode)
        result.Subtitle = "Possible Severe Sepsis without Septic Shock present"
        AlertPassed = True
        
    elif subtitle == "Possible Severe Sepsis with Septic Shock present" and r6521Code is not None:
        dc.Links.Add(r6521Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to specified code now existing on the Account"
        AlertConditions = True
        
    elif (sepsisCode is not None or r6520Code is not None) and r6521Code is None and ODS >= 2 and (SSI >= 1 or r579Code is not None):
        if sepsisCode is not None: dc.Links.Add(sepsisCode)
        if r579Code is not None: dc.Links.Add(r579Code)
        if r6520Code is not None: dc.Links.Add(r6520Code)
        result.Subtitle = "Possible Severe Sepsis with Septic Shock present"
        AlertPassed = True
     
    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Organ Dysfunction Sign Abstractions
    if g9341Code is not None: organ.Links.Add(g9341Code)
    if acuteHeartFailure is not None: organ.Links.Add(acuteHeartFailure)
    if acuteKidneyFailure is not None: organ.Links.Add(acuteKidneyFailure)
    if acuteLiverFailure is not None: organ.Links.Add(acuteLiverFailure)
    if i21aCode is not None: organ.Links.Add(i21aCode)
    if acuteRespiratroyFailure is not None: organ.Links.Add(acuteRespiratroyFailure)
    if r4182Code is not None: organ.Links.Add(r4182Code)
    if alteredAbs is not None: organ.Links.Add(alteredAbs)
    if lowBloodPressureAbs is not None: organ.Links.Add(lowBloodPressureAbs)
    if r410Code is not None: organ.Links.Add(r410Code)
    if glasgowComaScoreDV is not None: organ.Links.Add(glasgowComaScoreDV)
    if lowMeanArterialBloodPressureDV is not None: organ.Links.Add(lowMeanArterialBloodPressureDV)
    if pa02DV is not None: organ.Links.Add(pa02DV)
    if p02fio2DV is not None: organ.Links.Add(p02fio2DV)
    if lowPlateletCountDV is not None: organ.Links.Add(lowPlateletCountDV)
    if highSerumBilirubinDV is not None: organ.Links.Add(highSerumBilirubinDV)
    if highSerumCreatinineDV is not None: organ.Links.Add(highSerumCreatinineDV)
    if highSerumLactate2DV is not None: 
        for entry in highSerumLactate2DV:
            lactateODS.Links.Add(entry) #12
    if highPOCLactate2DV is not None: 
        for entry in highPOCLactate2DV:
            lactateODS.Links.Add(entry) #12
    if spO2DV is not None: organ.Links.Add(spO2DV)
    if lowSystolicBloodPressureDV is not None: organ.Links.Add(lowSystolicBloodPressureDV)
    if lowUrineOutputAbs is not None: organ.Links.Add(lowUrineOutputAbs)
    #Septic Shock Indicator abstractions
    if highSerumLactate4DV is not None: 
        for entry in highSerumLactate4DV:
            lactateSSI.Links.Add(entry)
    if highPOCLactate4DV is not None: 
        for entry in highPOCLactate4DV:
            lactateSSI.Links.Add(entry)
    #Meds
    medValue("Albumin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, meds, True)
    if dobutamine is not None: meds.Links.Add(dobutamine)
    if dopamine is not None: meds.Links.Add(dopamine)
    if epinephrine is not None: meds.Links.Add(epinephrine)
    if medValue("Fluid Bolus", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 8, meds, True) is False:
        abstractValue("FLUID_BOLUS", "Fluid Bolus: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, meds, True)
    if levophed is not None: meds.Links.Add(levophed)
    if milrinone is not None: meds.Links.Add(milrinone)
    if neosynephrine is not None: meds.Links.Add(neosynephrine)
    if vasoactiveMedicationAbs is not None: meds.Links.Add(vasoactiveMedicationAbs)
    if vasopressin is not None: meds.Links.Add(vasopressin)

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if lactateODS.Links: organ.Links.Add(lactateODS)
    if lactateSSI.Links: septic.Links.Add(lactateSSI)
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if organ.Links: result.Links.Add(organ); organLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    if septic.Links: result.Links.Add(septic); septicLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Documented Dx- " + str(dcLinks) + ", Organ- " + str(organLinks) + ", meds- "
        + str(medsLinks) + ", septic- " + str(septicLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
