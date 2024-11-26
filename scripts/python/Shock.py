##################################################################################################################
#Evaluation Script - Shock
#
#This script checks an account to see if it matches criteria to be alerted for Shock
#Date - 11/19/2024
#Version - V34
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
    "A48.3": "Toxic Shock Syndrome",
    "R57.0": "Cardiogenic Shock",
    "R57.1": "Hypovolemic Shock",
    "R57.8": "Other Shock",
    "R65.21": "Severe Sepsis with Septic Shock",
    "T78.2XXA": "Anaphylactic Shock",
    "T79.4XXA": "Traumatic Shock, Initial Encounter",
    "T81.10XA": "Postprocedural Shock Unspecified, Initial Encounter",
    "T81.11XA": "Postprocedural Cardiogenic Shock, Initial Encounter",
    "T81.11XD": "Postprocedural Cardiogenic Shock, Subsequent Encounter",
    "T75.01XA": "Shock Due to Being Struck by Lightning, Initial Encounter",
    "T81.12XA": "Postprocedural Septic Shock, Initial Encounter",
    "T81.12XD": "Postprocedural Septic Shock, Subsequent Encounter",
    "T81.12XS": "Postprocedural Septic Shock, Sequela",
    "T81.19XA": "Other Postprocedural Shock, Initial Encounter",
    "T81.19XD": "Other Postprocedural Shock, Subsequent Encounter"
}

codeDic2 = {
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
    "T81.44XS": "Sepsis Following a Procedure, Sequela",
    "R57.0" : "Cardiogenic shock",
    "R57.1" : "Hypovolemic shock",
    "R57.8" : "Other shock",
    "R57.9" : "Shock, unspecified",
    "R65.21" : "Severe sepsis with septic shock",
    "A48.3" : "Toxic shock syndrome",
    "T75.01XA" : "Shock due to being struck by lightning, initial encounter",
    "T78.2XXA" : "Anaphylactic shock, unspecified, initial encounter",
    "T79.4XXA" : "Traumatic shock, initial encounter",
    "T81.10XA" : "Postprocedural shock unspecified, initial encounter",
    "T81.11XA" : "Postprocedural cardiogenic shock, initial encounter",
    "T81.11XD" : "Postprocedural cardiogenic shock, subsequent encounter",
    "T81.12XA" : "Postprocedural septic shock, initial encounter",
    "T81.12XD" : "Postprocedural septic shock, subsequent encounter",
    "T81.12XS" : "Postprocedural septic shock, sequela",
    "T81.19XA" : "Other postprocedural shock, initial encounter",
    "T81.19XD" : "Other postprocedural shock, subsequent encounter"
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
dvAlanineAminotransferase = ["ALT (unit/L)"]
calcAlanineAminotransferase1 = lambda x: x > 56
dvArterialBloodPH = ["pH"]
calcArterialBloodPH1 = lambda x: x < 7.30
dvAspartateAminotransferase = ["AST (unit/L)"]
calcAspartateAminotransferase1 = lambda x: x > 35
dvBloodLoss = [""]
calcBloodLoss1 = lambda x: x > 300
dvCardiacIndex = ["Cardiac Index CAL cc"]
calcCardiacIndex1 = lambda x: x < 1.8
dvCardiacOutput = ["Cardiac Output cc"]
calcCardiacOutput1= lambda x: x < 4
dvCentralVenousPressure = ["CVP cc"]
calcCentralVenousPressure1 = lambda x: x < 18
dvDBP = ["BP Arterial Diastolic cc (mm Hg)", "DBP 3.5 (No Calculation) (mmhg)", "DBP 3.5 (No Calculation) (mm Hg)"]
dvGlasgowComaScale = ["3.5 Neuro Glasgow Score"]
calcGlasgowComaScale1 = lambda x: x < 15
dvHeartRate = ["Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)", "3.5 Heart Rate (Radial) (bpm)",  "SCC Monitor Pulse (bpm)"]
calcHeartRate1 = lambda x: x > 90
calcHeartRate2 = lambda x: x < 60
dvHematocrit = ["HEMATOCRIT (%)", "HEMATOCRIT"]
calcHematocrit1 = lambda x: x < 35
calcHematocrit2 = lambda x: x < 40
dvHemoglobin = ["HEMOGLOBIN", "HEMOGLOBIN (g/dL)"]
calcHemoglobin1 = lambda x: x < 13.5
calcHemoglobin2 = lambda x: x < 11.6
dvMAP = ["Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)"]
calcMAP1 = 70
dvOxygenTherapy = ["DELIVERY"]
dvPaO2 = ["BLD GAS O2 (mmHg)", "PO2 (mmHg)"]
calcPAO21 = lambda x: x < 80
dvPAOP = [""]
calcPAOP1 = lambda x: 6 >= x >= 12
dvPlasmaTransfusion = [""]
dvPVR = [""]
calcPVR1 = lambda x: x > 200
dvRedBloodCellTransfusion = ["Volume (mL)-Transfuse Red Blood Cells (mL)", "Volume (mL)-Transfuse Red Blood Cells, Irradiated (mL)"]
dvRespiratoryRate = ["3.5 Respiratory Rate (#VS I&O) (per Minute)"]
calcRespiratoryRate1 = lambda x: x > 20
dvSBP = ["SBP 3.5 (No Calculation) (mm Hg)"]
calcSBP1 = 90
dvSerumBloodUreaNitrogen = ["BUN (mg/dL)"]
calcSerumBloodUreaNitrogen1 = lambda x: x > 23
dvSerumCreatinine = ["CREATININE (mg/dL)", "CREATININE SERUM (mg/dL)"]
calcSerumCreatinine1 = lambda x: x > 1.3
dvSerumLactate = ["LACTIC ACID (mmol/L)"]
calcSerumLactate1 = lambda x: x >= 4
dvSystemicVascularResistance = [""]
calcSystemicVascularResistance1 = lambda x: x < 800
dvTemperature = ["Temperature Degrees C 3.5 (degrees C)", "Temperature  Degrees C 3.5 (degrees C)", "TEMPERATURE (C)"]
calcTemperature1 = lambda x: x > 38.3
calcTemperature2 = lambda x: x < 36.0
dvTroponinT = ["TROPONIN, HIGH SENSITIVITY (ng/L)"]
calcTroponinT1 = lambda x: x > 59

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
def dvOxygenCheck(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    abstraction = None
    for dv in dvDic or []:
        if (
            dvDic[dv]['Name'] in discreteValueName and
            dvDic[dv]['Result'] is not None and
            not re.search(r'\bRoom Air\b', dvDic[dv].Result, re.IGNORECASE) and
            not re.search(r'\bRA\b', dvDic[dv].Result, re.IGNORECASE)
        ):
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return abstraction
    return abstraction

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

def bloodPressureLookup(dvDic, medDic):
    discreteDic1 = {}
    discreteDic2 = {}
    discreteDic3 = {}
    medsDic = {}
    sbpList = []
    mapList = []
    linkText = "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])"
    medSearchList = ["Dobutamine", "Dopamine", "Epinephrine", "Levophed", "Milrinone", "Neosynephrine"]
    #Default should be set to -1 day back.
    a = 0; w = 0; x = 0; sm = 0
    matchedList = []
    dvr = None
    #Pull all values for discrete values we need
    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in dvDBP and dvr is not None:
            #Diastolic Blood Pressure
            w += 1
            discreteDic1[w] = dvDic[dv]
        elif dvDic[dv]['Name'] in dvHeartRate and dvr is not None:
            #Heart Rate
            x += 1
            discreteDic2[x] = dvDic[dv]
        elif (dvDic[dv]['Name'] in dvSBP and dvr is not None) or (dvDic[dv]['Name'] in dvMAP and dvr is not None):
            #Systolic/Mean Blood Pressure
            sm += 1
            discreteDic3[sm] = dvDic[dv]

    for mv in medDic or []:
        if (
            medDic[mv]['Route'] is not None and
            medDic[mv]['Dosage'] is not None and
            medDic[mv]['CDIAlertCategory'] in medSearchList and
            (re.search(r'\bIntravenous\b', medDic[mv]['Route'], re.IGNORECASE) or
            re.search(r'\bIV Push\b', medDic[mv]['Route'], re.IGNORECASE))
        ):
            a += 1
            medsDic[a] = medDic[mv]
                
    if sm > 0:
        abstractedList = []
        medList = []
        for item in discreteDic3:
            dbpDv = None
            sbpDv = None
            hrDv = None
            mapDv = None
            id = None
            firstMedName = None
            firstMedDosage = None
            matchingDate = None
            if discreteDic3[item]['Name'] in dvSBP and float(discreteDic3[item]['Result']) < float(calcSBP1) and discreteDic3[item]['_id'] not in abstractedList:
                sbpList.append(discreteDic3[item].Result)
                matchingDate = discreteDic3[item].ResultDate
                sbpDv = discreteDic3[item].Result
                abstractedList.append(discreteDic3[item]._id)
                id = discreteDic3[item]._id
                for item1 in discreteDic3:
                    if discreteDic3[item1].ResultDate == matchingDate and discreteDic3[item1].Name in dvMAP:
                        if float(discreteDic3[item1]['Result']) < float(calcMAP1):
                            mapList.append(discreteDic3[item1].Result)
                        mapDv = discreteDic3[item1].Result
                        abstractedList.append(discreteDic3[item1]._id)
                        break
            elif discreteDic3[item]['Name'] in dvMAP and float(discreteDic3[item]['Result']) < float(calcMAP1) and discreteDic3[item]['_id'] not in abstractedList:
                mapList.append(discreteDic3[item].Result)
                matchingDate = discreteDic3[item].ResultDate
                mapDv = discreteDic3[item].Result
                abstractedList.append(discreteDic3[item]._id)
                id = discreteDic3[item]._id
                for item1 in discreteDic3:
                    if discreteDic3[item1].ResultDate == matchingDate and discreteDic3[item1].Name in dvSBP:
                        if float(discreteDic3[item1]['Result']) < float(calcSBP1):
                            sbpList.append(discreteDic3[item1].Result)
                        sbpDv = discreteDic3[item1].Result
                        abstractedList.append(discreteDic3[item1]._id)
                        break
            if w > 0:
                for item2 in discreteDic1:
                    if discreteDic1[item2].ResultDate == matchingDate:
                        dbpDv = discreteDic1[item2].Result
                        break
            if x > 0:
                for item3 in discreteDic2:
                    if discreteDic2[item3].ResultDate == matchingDate:
                        hrDv = discreteDic2[item3].Result
                        break
            if a > 0 and matchingDate is not None:
                dateLimit = matchingDate.AddHours(24)
                for item4 in medsDic:
                    if matchingDate <= medsDic[item4].StartDate <= dateLimit:
                        if medsDic[item4]['ExternalId'] not in medList:
                            medDataConversion(medsDic[item4]['StartDate'], linkText, medsDic[item4]['Medication'], medsDic[item4]['ExternalId'], medsDic[item4]['Dosage'], medsDic[item4]['Route'], meds, 0)
                            medList.append(medsDic[item4]['ExternalId'])
                        firstMedName = medsDic[item4]['Medication']
                        firstMedDosage = medsDic[item4]['Dosage']
                        break
                    
            if dbpDv is None:
                dbpDv = 'XX'
            if hrDv is None:
                hrDv = 'XX'
            if mapDv is None:
                mapDv = 'XX'
            if sbpDv is None:
                sbpDv = 'XX'
            if firstMedName is not None and matchingDate is not None:
                matchedList.append(dataConversion(matchingDate, "[RESULTDATETIME] HR = " + str(hrDv) + ", BP = " + str(sbpDv) + "/" + str(dbpDv) + ", MAP = " + str(mapDv) + ", Vasopressor:  = " + str(firstMedName) + " @ " + str(firstMedDosage), None, id, vitals, 0, True))
            elif matchingDate is not None:
                matchedList.append(dataConversion(matchingDate, "[RESULTDATETIME] HR = " + str(hrDv) + ", BP = " + str(sbpDv) + "/" + str(dbpDv) + ", MAP = " + str(mapDv), None, id, vitals, 0, True))

    #Return the 7 days of low for alert triggers or return false for nothing for trigger purposes.
    if len(sbpList) == 0:
        sbpList = [False]
    if len(mapList) == 0:
        mapList = [False]
    return [sbpList, mapList]

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

codes2 = []
codes2 = codeDic2.keys()
codeList2 = CodeCount(codes2)
codesExist2 = len(codeList2)
str2 = ', '.join([str(elem) for elem in codeList2])

#Standard Variable Declaration
AlertPassed = False
alertTriggered = False
AlertConditions = False
validated = False
outcome = None
subtitle = None
SCI = 0; NCI = 0; CCC = 0; CCI = 0; HCI = 0
allergy = False; sepsis = False; pulmonary = False; spinal = False; burns = False
shock = False; neurogenic = False; hemorrhage = False; cardiogenic = False; hypovolemic = False
dcLinks = False
absLinks = False
labsLinks = False
vitalsLinks = False
medsLinks = False
oxygenLinks = False
noLabs = []

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
vitals = MatchedCriteriaLink("Vital Signs/Intake and Output Data", None, "Vital Signs/Intake and Output Data", None, True, None, None, 2)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 3)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 4)
meds = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 5)
oxygen = MatchedCriteriaLink("Oxygenation/Ventilation", None, "Oxygenation/Ventilation", None, True, None, None, 6)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 7)
systolicBP = MatchedCriteriaLink("Systolic Blood Pressure", None, "Systolic Blood Pressure", None, True, None, None, 85)
meanBP = MatchedCriteriaLink("Mean Arterial Blood Pressure", None, "Mean Arterial Blood Pressure", None, True, None, None, 86)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Shock':
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
    medSearchList = ["Dobutamine", "Dopamine", "Epinephrine", "Levophed", "Milrinone", "Neosynephrine", "Vasopressin"]
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
    
    #Find all discrete values for custom lookups within the last 7 days
    maindiscreteDic = {}
    unsortedDicsreteDic = {}
    dvCount = 0
    #Combine all items into one list to search against
    discreteSearchList = [i for j in [dvSBP, dvMAP, dvOxygenTherapy, dvDBP, dvHeartRate] for i in j]
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
    allergyCode = multiCodeValue(["T78.00xA", "T78.01xA", "T78.02xA", "T78.03xA", "T78.04xA", "T78.05xA", "T78.06xA", "T78.07xA",
                     "T78.08xA", "T78.09xA", "T88.6xxA"], "Allergic Reaction Code Present: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    sepsisCode = multiCodeValue(["A40.0", "A40.1", "A40.8", "A40.9", "A41", "A41.0", "A41.01", "A41.02 ", "A41.1", "A41.2 ",
                      "A41.3", "A41.4", "A41.5", "A41.50", "A41.51", "A41.52", "A41.53", "A41.54", "A41.59", "A41.8", "A41.81",
                      "A41.89", "A41.9", "A42.7", "A22.7", "B37.7", "A26.7", "A54.86", "B00.7", "A32.7", "A24.1",
                      "A20.7", "R65.20 ", "R65.21 ", "T81.44"], "Sepsis Code Present: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    spinalCordInjuryCode = multiCodeValue(["S14.0", "S14.1", "S14.10", "S14.101", "S14.102", "S14.103", "S14.104", "S14.105", "S14.106",
                      "S14.107", "S14.108", "S14.109", "S14.11", "S14.111", "S14.112", "S14.113", "S14.114", "S14.115",
                      "S14.116", "S14.117", "S14.118", "S14.119", "S14.12", "S14.121", "S14.122", "S14.123", "S14.124",
                      "S14.125", "S14.126", "S14.127", "S14.128", "S14.129", "S14.13", "S14.131", "S14.132", "S14.133",
                      "S24.104", "S24.109", "S24.11", "S24.111", "S24.112", "S24.113", "S24.114", "S24.119", "S24.13",
                      "S24.131", "S24.132", "S24.133", "S24.134", "S24.139", "S24.14", "S24.141", "S24.142", "S24.143",
                      "S24.144", "S24.149", "S24.15", "S24.151", "S24.152", "S24.153", "S24.154", "S24.159", "S34.0",
                      "S34.01", "S34.02", "S34.1", "S34.10", "S34.101", "S34.102", "S34.109", "S34.11", "S34.111",
                      "S34.112", "S34.119", "S34.12", "S34.121", "S34.122"], "Spinal Cord Injury Code Present: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    burnCode = multiCodeValue(["T31.1", "T31.10", "T31.11", "T31.2", "T31.20", "T31.21", "T31.22", "T31.3", "T31.30", "T31.31",
                      "T31.32", "T31.33", "T31.4", "T31.40", "T31.42", "T31.43", "T31.44", "T31.5", "T31.50", "T31.51",
                      "T31.52", "T31.53", "T31.54", "T31.55", "T31.6", "T31.60", "T31.61", "T31.62", "T31.63", "T31.64",
                      "T31.65", "T31.66", "T31.7", "T31.71", "T31.72", "T31.73", "T31.74", "T31.75", "T31.76", "T31.77",
                      "T31.8", "T31.81", "T31.82", "T31.83", "T31.84", "T31.85", "T31.86", "T31.87", "T31.88", "T31.9",
                      "T31.91", "T31.92", "T31.93", "T31.94", "T31.95", "T31.96", "T31.97", "T31.98", "T31.99", "T32.1",
                      "T32.11", "T32.2", "T32.20", "T32.21", "T32.22", "T32.3", "T32.30", "T32.31", "T32.32", "T32.33",
                      "T32.4", "T32.41", "T32.42", "T32.43", "T32.44", "T32.5", "T32.50", "T32.51", "T32.52", "T32.53",
                      "T32.54", "T32.55", "T32.6", "T32.60", "T32.61", "T32.62", "T32.63", "T32.64", "T32.65", "T32.66",
                      "T32.7", "T32.70", "T32.71", "T32.72", "T32.73", "T32.74", "T32.75", "T32.76", "T32.77", "T32.8",
                      "T32.81", "T32.82", "T32.83", "T32.84", "T32.85", "T32.86", "T32.87", "T32.88", "T32.9", "T32.91",
                      "T32.92", "T32.93", "T32.94", "T32.95", "T32.96", "T32.97", "T32.98", "T32.99"], "Burn Code Present: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    shockCode = multiCodeValue(["A48.3", "R57.0", "R57.1", "R57.8", "R57.9", "R65.21", "T78.2XXA"],
                               "Shock Code Present: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    r578Code = codeValue("R57.8", "Other shock: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    r571Code = codeValue("R57.1", "Hypovolemic shock: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    r570Code = codeValue("R57.0", "Cardiogenic shock: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    t782XXACode = codeValue("T78.2XXA", "Anaphylactic Shock, Unspecified, Initial encounter: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Alert Trigger
    r579Code = codeValue("R57.9", "Unspecified Shock Code Present: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    bloodLossDV = dvValue(dvBloodLoss, "Blood Loss: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodLoss1, 1)
    #Abs
    i314Code = codeValue("I31.4", "Cardiac Tamponade: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15)
    diarrheaAbs = abstractValue("DIARRHEA", "Diarrhea '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 17)
    endocarditisCode = multiCodeValue(["I33.0", "I33.9", "I38", "I39"], "Endocarditis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 29)
    r232Code = codeValue("R23.2", "Flushed Skin: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 31)
    hfCode = multiCodeValue(["I50.1", "I50.2", "I50.20", "I50.21", "I50.22", "I50.23", "I50.3", "I50.30", "I50.31", "I50.32", "I50.33", "I50.4", "I50.40", "I50.41",
                       "I50.42", "I50.43", "I50.8", "I50.81", "I50.810", "I50.811", "I50.812", "I50.813", "I50.814", "I50.82", "I50.83", "I50.84", "I50.89",
                       "I50.9"], "Heart Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 32)
    hemorrhageAbs = abstractValue("HEMORRHAGE", "Hemorrhage '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 33)
    miCode = multiCodeValue(["I21.0", "I21.01", "I21.02", "I21.09", "I21.1", "I21.11", "I21.19", "I21.2", "I21.2", "I21.21", "I21.29", "I21.3", "I21.4", "I21.A1",
                      "I21.A9"], "Myocardial Infarction: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 38)
    myocarditisCode = multiCodeValue(["I40.0", "I40.1", "I40.8", "I40.9", "I41", "I51.4"], "Myocarditis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 39)
    e860Code = codeValue("E86.0", "Severe Dehydration: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 46)
    e869Code = codeValue("E86.9", "Volume Depletion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 48)
    vomitingAbs = abstractValue("VOMITING", "Vomiting '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 49)
    #Labs
    lowArterialBloodPHDV = dvValue(dvArterialBloodPH, "Arterial Blood PH: [VALUE] (Result Date: [RESULTDATETIME])", calcArterialBloodPH1, 3)
    serumLactateDV = dvValue(dvSerumLactate, "Serum Lactate: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumLactate1, 9)
    #Meds
    dobutamineMed = medValue("Dobutamine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 2)
    dobutamineAbs = abstractValue("DOBUTAMINE", "Dobutamine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3)
    dopamineMed = medValue("Dopamine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 4)
    dopamineAbs = abstractValue("DOPAMINE", "Dopamine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5)
    epinephrineMed = anesthesiaMedValue(dict(mainMedDic), "Epinephrine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 6)
    epinephrineAbs = abstractValue("EPINEPHRINE", "Epinephrine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7)
    fluidBolusMed = medValue("Fluid Bolus", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 8)
    fluidBolusAbs = abstractValue("FLUID_BOLUS", "Fluid Bolus '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9)
    levophedMed = anesthesiaMedValue(dict(mainMedDic), "Levophed", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 10)
    levophedAbs = abstractValue("LEVOPHED", "Levophed '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11)
    milrinoneMed = medValue("Milrinone", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 12)
    milrinoneAbs = abstractValue("MILRINONE", "Milrinone '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13)
    neosynephrineMed = anesthesiaMedValue(dict(mainMedDic), "Neosynephrine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 14)
    neosynephrineAbs = abstractValue("NEOSYNEPHRINE", "Neosynephrine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 15)
    vasoactiveMedicationAbs = abstractValue("VASOACTIVE_MEDICATION", "Vasoactive Medication: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 20)
    #Vitals
    lowCardiacIndexDV = dvValue(dvCardiacIndex, "Cardiac Index: [VALUE] (Result Date: [RESULTDATETIME])", calcCardiacIndex1, 1)
    lowCardiacIndexAbs = abstractValue("LOW_CARDIAC_INDEX", "Cardiac Index: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2)
    lowCardiacOutputDV = dvValue(dvCardiacOutput, "Cardiac Output: [VALUE] (Result Date: [RESULTDATETIME])", calcCardiacOutput1, 3)
    lowCardiacOutputAbs = abstractValue("LOW_CARDIAC_OUTPUT", "Cardiac Output: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4)
    lowHeartRateDV = dvValue(dvHeartRate, "Heart Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcHeartRate2, 9)
    elPulmonaryArtOcculsivePresDV = dvValue(dvPAOP, "Pulmonary Artery Occulsive Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcPAOP1, 12)
    elPulmonaryArtOcculsivePresAbs = abstractValue("ELEVATED_PULMONARY_ARTERY_OCCULSIVE_PRESSURE", "Pulmonary Artery Occulsive Pressure: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13)
    lowSystemicVascularResDV = dvValue(dvSystemicVascularResistance, "Systemic Vascular Resistance: [VALUE] (Result Date: [RESULTDATETIME])", calcSystemicVascularResistance1, 19)
    lowSystemicVascularResAbs = abstractValue("LOW_SYSTEMIC_VASCULAR_RESISTANCE", "Systemic Vascular Resistance: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 20)
    lowTempDV = dvValue(dvTemperature, "Temperature: [VALUE] (Result Date: [RESULTDATETIME])", calcTemperature2, 21)
    highTempDV = dvValue(dvTemperature, "Temperature: [VALUE] (Result Date: [RESULTDATETIME])", calcTemperature1, 22)
    #Blood Pressure
    bpValuesDV = [[False], [False]]
    bpValuesDV = bloodPressureLookup(dict(maindiscreteDic), dict(mainMedDic))

    #Calculating all Clinical Indicator Counts
    #SCI
    if (
        ((bpValuesDV[0][0] is not False and len(bpValuesDV[0] or noLabs) > 2) or (bpValuesDV[1][0] is not False and len(bpValuesDV[1] or noLabs) > 2)) or
        ((bpValuesDV[0][0] is not False and len(bpValuesDV[0] or noLabs) > 1) or (bpValuesDV[1][0] is not False and len(bpValuesDV[1] or noLabs) > 1)) and
        (serumLactateDV is not None or
        vasoactiveMedicationAbs is not None or
        dobutamineMed is not None or
        dobutamineAbs is not None or
        dopamineMed is not None or
        dopamineAbs is not None or
        epinephrineMed is not None or
        epinephrineAbs is not None or
        fluidBolusMed is not None or
        fluidBolusAbs is not None or
        levophedMed is not None or
        levophedAbs is not None or
        milrinoneMed is not None or
        milrinoneAbs is not None or
        neosynephrineMed is not None or
        neosynephrineAbs is not None)
    ):
        SCI += 1
    #NCI
    if lowHeartRateDV is not None: NCI += 1
    if highTempDV is not None: NCI += 1
    if lowTempDV is not None: NCI += 1
    if r232Code is not None: NCI += 1
    if lowSystemicVascularResDV is not None or lowSystemicVascularResAbs is not None: NCI += 1
    #CCC
    if endocarditisCode is not None: CCC += 1
    if myocarditisCode is not None: CCC += 1
    if i314Code is not None: CCC += 1
    if hfCode is not None: CCC += 1
    if miCode is not None: CCC += 1
    #CCI
    if lowCardiacOutputDV is not None or lowCardiacOutputAbs is not None: CCI += 1
    if lowCardiacIndexDV is not None or lowCardiacIndexAbs is not None: CCI += 1
    if elPulmonaryArtOcculsivePresDV is not None or elPulmonaryArtOcculsivePresAbs is not None: CCI += 1
    #HCI
    if vomitingAbs is not None: HCI += 1
    if diarrheaAbs is not None: HCI += 1
    if e860Code is not None: HCI += 1
    if e869Code is not None: HCI += 1

    #Determining Negation Checks
    if allergyCode is not None: allergy = True
    if sepsisCode is not None: sepsis = True
    if spinalCordInjuryCode is not None: spinal = True
    if burnCode is not None: burns = True
    
    #Starting Main Algorithm
    if codesExist == 1:
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

    elif codesExist >= 2:
        for code in codeList:
            desc = codeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, desc +": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            dc.Links.Add(tempCode)
        result.Subtitle = "Possible Conflicting Shock Dx " + str1
        if validated:
            result.Validated = False
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"
        AlertPassed = True
    #1.1/2.1
    elif subtitle == "Possible Hemorrhagic Shock" and r571Code is not None:
        if r571Code is not None: updateLinkText(r571Code, autoCodeText); dc.Links.Add(r571Code)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #1.0
    elif r579Code is not None and (bloodLossDV is not None or hemorrhageAbs is not None) and r571Code is None:
        dc.Links.Add(r579Code)
        if hemorrhageAbs is not None: dc.Links.Add(hemorrhageAbs)
        if bloodLossDV is not None: dc.Links.Add(bloodLossDV)
        result.Subtitle = "Possible Hemorrhagic Shock"
        AlertPassed = True
        hemorrhagic = True
    #2.0
    elif r579Code is None and SCI >= 1 and (bloodLossDV is not None or hemorrhageAbs is not None) and r578Code is None:
        if hemorrhageAbs is not None: dc.Links.Add(hemorrhageAbs)
        if bloodLossDV is not None: dc.Links.Add(bloodLossDV)
        result.Subtitle = "Possible Hemorrhagic Shock"
        AlertPassed = True
        hemorrhagic = True
    #3.1/4.1
    elif subtitle == "Possible Hypovolemic Shock" and r571Code is not None:
        if r571Code is not None: updateLinkText(r571Code, autoCodeText); dc.Links.Add(r571Code)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #3.0
    elif hemorrhageAbs is None and sepsis == False and spinal == False and CCC == 0 and (burns or HCI >= 1) and r579Code is not None and r571Code is None:
        if burns: dc.Links.Add(burnCode)
        dc.Links.Add(r579Code)
        result.Subtitle = "Possible Hypovolemic Shock"
        AlertPassed = True
        hypovolemic = True
    #4.0
    elif (
        codesExist == 0 and r579Code is None and hemorrhageAbs is None and
        sepsis == False and spinal == False and CCC == 0 and SCI >= 1 and
        (burns or HCI >= 1) and
        r571Code is None
    ):
        if burns: dc.Links.Add(burnCode)
        result.Subtitle = "Possible Hypovolemic Shock"
        AlertPassed = True
        hypovolemic = True
    #5.1/6.1
    elif subtitle == "Possible Cardiogenic Shock" and r570Code is not None:
        if r570Code is not None: updateLinkText(r570Code, autoCodeText); dc.Links.Add(r570Code)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #5.0
    elif hemorrhageAbs is None and sepsis == False and CCC > 1 and CCI >= 2 and r579Code is not None and r570Code is None:
        dc.Links.Add(r579Code)
        result.Subtitle = "Possible Cardiogenic Shock"
        AlertPassed = True
        cardiogenic = True
    #6.0
    elif (
        codesExist == 0 and r579Code is None and hemorrhageAbs is None and
        sepsis == False and burns == False and spinal == False and
        HCI == 0 and SCI >= 1 and CCC > 1 and CCI >= 2 and r570Code is None
    ):
        result.Subtitle = "Possible Cardiogenic Shock"
        AlertPassed = True
        cardiogenic = True
    #7.1/8.1
    elif subtitle == "Possible Neurogenic Shock" and r578Code is not None:
        if r578Code is not None: updateLinkText(r578Code, autoCodeText); dc.Links.Add(r578Code)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #7.0
    elif (
        r579Code is not None and hemorrhageAbs is None and sepsis == False and
        burns == False and spinal and r578Code is None and CCC == 0 and HCI == 0
    ):
        result.Subtitle = "Possible Neurogenic Shock"
        AlertPassed = True
        neurogenic = True
    #8.0
    elif (
        codesExist == 0 and r579Code is None and hemorrhageAbs is None and
        sepsis == False and burns == False and spinal and
        CCC == 0 and HCI == 0 and NCI >= 2 and r578Code is None
    ):
        result.Subtitle = "Possible Neurogenic Shock"
        AlertPassed = True
        neurogenic = True
    #9.1/10.1
    elif subtitle == "Possible Anaphylactic Shock" and t782XXACode is not None:
        if t782XXACode is not None: updateLinkText(t782XXACode, autoCodeText); dc.Links.Add(t782XXACode)
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
    #9.0
    elif (
        spinal == False and burns == False and sepsis == False and
        CCC == 0 and HCI == 0 and
        allergy and hemorrhageAbs is None and r579Code is not None and
        t782XXACode is None
    ):
        dc.Links.Add(r579Code)
        result.Subtitle = "Possible Anaphylactic Shock"
        AlertPassed = True
    #10.0
    elif (
        codesExist == 0 and r579Code is None and hemorrhageAbs is None and
        sepsis == False and burns == False and spinal == False and allergy and
        CCC == 0 and HCI == 0 and SCI > 2 and t782XXACode is None
    ):
        result.Subtitle = "Possible Anaphylactic Shock"
        AlertPassed = True
    #11.1
    elif subtitle == "Possible Shock" and codesExist2 > 0:
        for code2 in codeList2:
            desc2 = codeDic2[code2]
            tempCode = accountContainer.GetFirstCodeLink(code2, "Autoresolved Specified Code - " + desc2 + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            if tempCode is not None:
                dc.Links.Add(tempCode)
                break
        AlertConditions = True
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code(s) on the Account"
        result.Validated = True
    #11.0
    elif SCI >= 2 and codesExist2 == 0 and sepsisCode is None:
        result.Subtitle = "Possible Shock"
        AlertPassed = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Abs
    codeValue("J81.0", "Acute Pulmonary Edema: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, abs, True)
    codeValue("E27.40", "Adrenal Insufficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, abs, True)
    codeValue("N17.9", "AKI: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, abs, True)
    r4182Code = codeValue("R41.82", "Altered Level Of Consciousness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4)
    alteredAbs = abstractValue("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level Of Consciousness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5)
    if r4182Code is not None:
        vitals.Links.Add(r4182Code)
        if alteredAbs is not None: alteredAbs.Hidden = True; vitals.Links.Add(alteredAbs)
    elif r4182Code is None and alteredAbs is not None:
        vitals.Links.Add(alteredAbs)
    multiCodeValue(["T31.10", "T31.11"], "Burns Involving 10-19 Percent Of Body Surface Area: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, abs, True)
    multiCodeValue(["T31.20", "T31.21", "T31.22"], "Burns Involving 20-29 Percent Of Body Surface Area: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, abs, True)
    multiCodeValue(["T31.30", "T31.31", "T31.32", "T31.33"], "Burns Involving 30-39 Percent Of Body Surface Area: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8, abs, True)
    multiCodeValue(["T31.40", "T31.41", "T31.42", "T31.43", "T31.44"],
                        "Burns Involving 40-49 Percent Of Body Surface Area: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, abs, True)
    multiCodeValue(["T31.50", "T31.51", "T31.52", "T31.53", "T31.54", "T31.55"],
                        "Burns Involving 50-59 Percent Of Body Surface Area: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, abs, True)
    multiCodeValue(["T31.60", "T31.61", "T31.62", "T31.63", "T31.64", "T31.65", "T31.66"],
                        "Burns Involving 60-69 Percent Of Body Surface Area: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, abs, True)
    multiCodeValue(["T31.70", "T31.71", "T31.72", "T31.73", "T31.74", "T31.75", "T31.76", "T31.77"],
                        "Burns Involving 70-79 Percent Of Body Surface Area: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, abs, True)
    multiCodeValue(["T31.80", "T31.81", "T31.82", "T31.83", "T31.84", "T31.85", "T31.86", "T31.87", "T31.88"],
                        "Burns Involving 80-89 Percent Of Body Surface Area: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13, abs, True)
    multiCodeValue(["T31.90", "T31.91", "T31.92", "T31.93", "T31.94", "T31.95", "T31.96", "T31.97", "T31.98", "T31.99"],
                        "Burns Involving 90 Percent Or More Of Body Surface Area: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, abs, True)
    if cardiogenic and i314Code is not None: abs.Links.Add(i314Code) #15
    multiCodeValue(["T32.10", "T32.11"], "Corrosions Involving 10-19 Percent Of Body Surface Area: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, abs, True)
    multiCodeValue(["T32.20", "T32.21", "T32.22"], "Corrosions Involving 20-29 Percent Of Body Surface Area: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17, abs, True)
    multiCodeValue(["T32.30", "T32.31", "T32.32", "T32.33"], "Corrosions Involving 30-39 Percent Of Body Surface Area: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, abs, True)
    multiCodeValue(["T32.40", "T32.41", "T32.42", "T32.43", "T32.44"],
                        "Corrosions Involving 40-49 Percent Of Body Surface Area: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19, abs, True)
    multiCodeValue(["T32.50", "T32.51", "T32.52", "T32.53", "T32.54", "T32.55"],
                        "Corrosions Involving 50-59 Percent Of Body Surface Area: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20, abs, True)
    multiCodeValue(["T32.60", "T32.61", "T32.62", "T32.63", "T32.64", "T32.65", "T32.66"],
                        "Corrosions Involving 60-69 Percent Of Body Surface Area: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21, abs, True)
    multiCodeValue(["T32.70", "T32.71", "T32.72", "T32.73", "T32.74", "T32.75", "T32.76", "T32.77"],
                        "Corrosions Involving 70-79 Percent Of Body Surface Area: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 22, abs, True)
    multiCodeValue(["T32.80", "T32.81", "T32.82", "T32.83", "T32.84", "T32.85", "T32.86", "T32.87", "T32.88"],
                        "Corrosions Involving 80-89 Percent Of Body Surface Area: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23, abs, True)
    multiCodeValue(["T32.90", "T32.91", "T32.92", "T32.93", "T32.94", "T32.95", "T32.96", "T32.97", "T32.98", "T32.99"],
                        "Corrosions Involving 90 Percent Or More Of Body Surface Area: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 24, abs, True)
    abstractValue("DECREASED_EXTREMITY_PERFUSION", "Decreased Extremity Perfusion: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 25, abs, True)
    abstractValue("DELAYED_CAPILLARY_REFILL", "Delayed Capillary Refill: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 26, abs, True)
    if hypovolemic and diarrheaAbs is not None: abs.Links.Add(diarrheaAbs) #27
    prefixCodeValue("^I71\.0", "Dissection of Aorta: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 28, abs, True)
    if cardiogenic and endocarditisCode is not None: abs.Links.Add(endocarditisCode) #29
    multiCodeValue(["5A15223", "FA1522F", "5A1522G", "FA1522H", "5A15A2F", "5A15A2G", "5A15A2H"], "Extracorporeal Membrane Oxygenation (ECMO): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 30, abs, True)
    if neurogenic and r232Code is not None: abs.Links.Add(r232Code) #31
    if cardiogenic and hfCode is not None: abs.Links.Add(hfCode) #32
    if hemorrhage and hemorrhageAbs is not None: abs.Links.Add(hemorrhageAbs) #33
    if hypovolemic: codeValue("E86.1", "Hypovolemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 34, abs, True)
    multiCodeValue(["5A0211D", "5A0221D"], "Impella Device: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 35, abs, True)
    multiCodeValue(["02HA3QZ", "02HA0QZ"], "Implantable Heart Assist Device: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 36, abs, True)
    multiCodeValue(["5A02110", "5A02210"], "Intra-Aortic Balloon Pump: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 37, abs, True)
    if cardiogenic and miCode is not None: abs.Links.Add(miCode) #38
    if cardiogenic and myocarditisCode is not None: abs.Links.Add(myocarditisCode) #39
    codeValue("I51.2", "Papillary Muscle Rupture: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 40, abs, True)
    abstractValue("PULMONARY_ARTERY_SATURATION", "Pulmonary Artery Saturation: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 41, abs, True)
    multiCodeValue(["I26.01", "I26.02", "I26.09", "I26.90", "I26.92", "I26.93", "I26.94", "I26.99"],
                      "Pulmonary Embolism Code Present: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 42, abs, True)
    prefixCodeValue("^I71\.3", "Ruptured Aortic Aneurysm: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 43, abs, True)
    prefixCodeValue("^I71\.1", "Ruptured Thoracic Aortic Aneurysm: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 44, abs, True)
    prefixCodeValue("^I71\.5", "Ruptured Thoracoabdominal Aortic Aneurysm: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 45, abs, True)
    if hypovolemic and e860Code is not None: abs.Links.Add(e860Code) #46
    multiCodeValue(["02HA0RJ", "02HA0RS", "02HA0RZ", "02HA3RJ", "02HA3RS", "02HA3RZ", "02HA4QZ", "02HA4RJ", "02HA4RS", "02HA4RZ"],
                      "Short-Term Heart Assist Device: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 47, abs, True)
    if hypovolemic and e869Code is not None: abs.Links.Add(e869Code) #48
    if hypovolemic and vomitingAbs is not None: abs.Links.Add(vomitingAbs) #49
    #Labs
    dvValue(dvAlanineAminotransferase, "Alanine Aminotransferase (ALT): [VALUE] (Result Date: [RESULTDATETIME])", calcAlanineAminotransferase1, 1, labs, True)
    dvValue(dvAspartateAminotransferase, "Aspartate Aminotransferase (AST): [VALUE] (Result Date: [RESULTDATETIME])", calcAspartateAminotransferase1, 2, labs, True)
    #3
    if gender == 'F':
        dvValue(dvHematocrit, "Hematocrit: [VALUE] (Result Date: [RESULTDATETIME])", calcHematocrit1, 4, labs, True)
        dvValue(dvHemoglobin, "Hemoglobin: [VALUE] (Result Date: [RESULTDATETIME])", calcHemoglobin2, 5, labs, True)
    elif gender == 'M':
        dvValue(dvHematocrit, "Hematocrit: [VALUE] (Result Date: [RESULTDATETIME])", calcHematocrit2, 4, labs, True)
        dvValue(dvHemoglobin, "Hemoglobin: [VALUE] (Result Date: [RESULTDATETIME])", calcHemoglobin1, 5, labs, True)
    dvValue(dvPaO2, "pa02: [VALUE] (Result Date: [RESULTDATETIME])", calcPAO21, 6, labs, True)
    dvValue(dvSerumBloodUreaNitrogen, "Serum Blood Urea Nitrogen: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumBloodUreaNitrogen1, 7, labs, True)
    dvValue(dvSerumCreatinine, "Serum Creatinine: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumCreatinine1, 8, labs, True)
    if serumLactateDV is not None: labs.Links.Add(serumLactateDV) #9
    troponinTDV = dvValue(dvTroponinT, "Troponin T High Sensitivity: [VALUE] (Result Date: [RESULTDATETIME])", calcTroponinT1, 10, labs, True)
    #Meds
    medValue("Albumin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, meds, True)
    multiCodeValue(["30233N1", "30243N1"], "Blood Transfusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, meds, True)
    if dobutamineMed is not None: meds.Links.Add(dobutamineMed) #3
    if dobutamineAbs is not None: meds.Links.Add(dobutamineAbs) #4
    if dopamineMed is not None: meds.Links.Add(dopamineMed) #5
    if dopamineAbs is not None: meds.Links.Add(dopamineAbs) #6
    if epinephrineMed is not None: meds.Links.Add(epinephrineMed) #7
    if epinephrineAbs is not None: meds.Links.Add(epinephrineAbs) #8
    if fluidBolusMed is not None: meds.Links.Add(fluidBolusMed) #9
    if fluidBolusAbs is not None: meds.Links.Add(fluidBolusAbs) #10
    if levophedMed is not None: meds.Links.Add(levophedMed) #11
    if levophedAbs is not None: meds.Links.Add(levophedAbs) #12
    if milrinoneMed is not None: meds.Links.Add(milrinoneMed) #13
    if milrinoneAbs is not None: meds.Links.Add(milrinoneAbs) #14
    if neosynephrineMed is not None: meds.Links.Add(neosynephrineMed) #15
    if neosynephrineAbs is not None: meds.Links.Add(neosynephrineAbs) #16
    multiCodeValue(["30233R1", "30243R1"], "Platelet Transfusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17, meds, True)
    multiCodeValue(["30233L1", "30243L1"], "Plasma Transfusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, meds, True)
    dvValue(dvPlasmaTransfusion, "Plasma Transfusion: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, 19, meds, True)
    dvValue(dvRedBloodCellTransfusion, "Red Blood Cell Transfusion: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, 20, meds, True)
    if vasoactiveMedicationAbs is not None: meds.Links.Add(vasoactiveMedicationAbs) #21
    anesthesiaMedValue(dict(mainMedDic), "Vasopressin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 22, meds, True)
    abstractValue("VASOPRESSIN", "Vasopressin '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 23, meds, True)
    #Oxygen
    multiCodeValue(["5A0935A", "5A0945A", "5A0955A"], "High Flow Nasal Oxygen: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, oxygen, True)
    codeValue("5A1945Z", "Mechanical Ventilation 24 to 96 hours: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, oxygen, True)
    codeValue("5A1955Z", "Mechanical Ventilation Greater than 96 hours: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, oxygen, True)
    codeValue("5A1935Z", "Mechanical Ventilation Less than 24 hours: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, oxygen, True)
    abstractValue("NON_INVASIVE_VENTILATION", "Non-Invasive Ventilation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5, oxygen, True)
    dvOxygenCheck(dict(maindiscreteDic), dvOxygenTherapy, "Oxygen Therapy '[VALUE]' (Result Date: [RESULTDATETIME])", 6, oxygen, True)
    abstractValue("OXYGEN_THERAPY", "Oxygen Therapy '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7, oxygen, True)
    #Vitals
    if cardiogenic and lowCardiacIndexDV is not None: vitals.Links.Add(lowCardiacIndexDV) #1
    if cardiogenic and lowCardiacIndexAbs is not None: vitals.Links.Add(lowCardiacIndexAbs) #2
    if cardiogenic and lowCardiacOutputDV is not None: vitals.Links.Add(lowCardiacOutputDV) #3
    if cardiogenic and lowCardiacOutputAbs is not None: vitals.Links.Add(lowCardiacOutputAbs) #4
    dvValue(dvCentralVenousPressure, "Central Venous Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcCentralVenousPressure1, 5, vitals, True)
    abstractValue("LOW_CENTRAL_VENOUS_PRESSURE", "Central Venous Pressure: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6, vitals, True)
    codeValue("R41.0", "Disorientation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, abs, True)
    dvValue(dvGlasgowComaScale, "Glasgow Coma Score: [VALUE] (Result Date: [RESULTDATETIME])", calcGlasgowComaScale1, 8, vitals, True)
    if neurogenic and lowHeartRateDV is not None: vitals.Links.Add(lowHeartRateDV) #9
    dvValue(dvHeartRate, "Heart Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcHeartRate1, 10)
    codeValue("R09.02", "Hypoxemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, vitals, True)
    if cardiogenic and elPulmonaryArtOcculsivePresDV is not None: vitals.Links.Add(elPulmonaryArtOcculsivePresDV) #12
    if cardiogenic and elPulmonaryArtOcculsivePresAbs is not None: vitals.Links.Add(elPulmonaryArtOcculsivePresAbs) #13
    dvValue(dvPVR, "Pulmonary Vascular Resistance: [VALUE] (Result Date: [RESULTDATETIME])", calcPVR1, 14, vitals, True)
    abstractValue("ELEVATED_PULMONARY_VASCULAR_RESISTANCE", "Pulmonary Vascular Resistance: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 15, vitals, True)
    dvValue(dvRespiratoryRate, "Respiratory Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcRespiratoryRate1, 16, vitals, True)
    dvValue(dvPVR, "Right Ventricle Systolic Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcPVR1, 17, vitals, True)
    abstractValue("ELEVATED_RIGHT_VENTRICLE_SYSTOLIC_PRESSURE", "Right Ventricle Systolic Pressure: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 18, vitals, True)
    if neurogenic and lowSystemicVascularResDV is not None: vitals.Links.Add(lowSystemicVascularResDV) #19
    if neurogenic and lowSystemicVascularResAbs is not None: vitals.Links.Add(lowSystemicVascularResAbs) #20
    if neurogenic and lowTempDV is not None: vitals.Links.Add(lowTempDV) #21
    if neurogenic and highTempDV is not None: vitals.Links.Add(highTempDV) #22
    
#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    if vitals.Links: result.Links.Add(vitals); vitalsLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    if oxygen.Links: result.Links.Add(oxygen); oxygenLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Documented Dx- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks) + ", vitals- "
        + str(vitalsLinks) + ", meds- " + str(medsLinks) + ", oxygen- " + str(oxygenLinks)
        + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
