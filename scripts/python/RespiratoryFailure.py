##################################################################################################################
#Evaluation Script - Respiratory Failure
#
#This script checks an account to see if it matches criteria to be alerted for Respiratory Failure
#Date - 11/20/2024
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
specCodeDic = {
    "J96.01": "Acute Respiratory Failure With Hypoxia",
    "J96.02": "Acute Respiratory Failure With Hypercapnia",
    "J96.11": "Chronic Respiratory Failure With Hypoxia",
    "J96.12": "Chronic Respiratory Failure With Hypercapnia",
    "J96.21": "Acute And Chronic Respiratory Failure With Hypoxia",
    "J96.22": "Acute And Chronic Respiratory Failure With Hypercapnia",
    "J95.821": "Acute Postprocedural Respiratory Failure"
}

unspecCodeDic = {
    "J96.90": "Respiratory Failure, Unspecified, Unspecified Whether With Hypoxia Or Hypercapnia",
    "J96.91": "Respiratory Failure, Unspecified With Hypoxia",
    "J96.92": "Respiratory Failure, Unspecified With Hypercapnia",
    "J96.00": "Acute Respiratory Failure, Unspecified Whether With Hypoxia Or Hypercapnia",
    "J96.10": "Chronic Respiratory Failure, Unspecified Whether With Hypoxia Or Hypercapnia",
    "J96.20": "Acute And Chronic Respiratory Failure, Unspecified Whether With Hypoxia Or Hypercapnia"
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
dvArterialBloodC02 = ["PaCO2 (mmHg)", "BLD GAS CO2 (mmHg)"]
calcArterialBloodC021 = 45
dvArterialBloodPH = ["pH"]
calcArterialBloodPH1 = lambda x: x < 7.30
calcArterialBloodPH2 = lambda x: x >= 7.35
dvBloodCO2 = ["CO2 (mmol/L)"]
calcBloodCO2 = lambda x: x > 32
dvFIO2 = ["FiO2"]
calcFIO21 = lambda x: x <= 100
dvGlasgowComaScale = ["3.5 Neuro Glasgow Score"]
calcGlasgowComaScale1 = lambda x: x < 15
dvHeartRate = ["Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)", "3.5 Heart Rate (Radial) (bpm)",  "SCC Monitor Pulse (bpm)"]
calcHeartRate1 = lambda x: x > 90
dvOxygenFlowRate = ["Resp O2 Delivery Flow Num"]
calcOxygenFlowRate1 = lambda x: x >= 2
dvOxygenTherapy = ["DELIVERY"]
dvPaO2 = ["BLD GAS O2 (mmHg)", "PO2 (mmHg)"]
calcPAO21 = 80
calcPAO22 = lambda x: x < 80
dvPa02Fi02 = ["PO2/FiO2 (mmHg)"]
calcPa02Fi021 = 300
calcPa02Fi022 = lambda x: x < 300
dvRespiratoryRate = ["3.5 Respiratory Rate (#VS I&O) (per Minute)"]
calcRespiratoryRate1 = lambda x: x > 20
calcRespiratoryRate2 = lambda x: x < 12
dvSerumBicarbonate = ["HCO3 (meq/L)", "HCO3 (mmol/L)", "HCO3 VENOUS (meq/L)"]
calcSerumBicarbonate1 = lambda x: x < 22
calcSerumBicarbonate2 = lambda x: x > 30
dvSPO2 = ["Pulse Oximetry(Num) (%)"]
calcSPO21 = 91
calcSPO22 = lambda x: x < 90
dvVenousBloodCO2 = ["BLD GAS CO2 VEN (mmHg"]
calcVenousBloodCO2 = lambda x: x > 55

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
            re.search(r'\bRoom Air\b', dvDic[dv].Result, re.IGNORECASE) is None and
            re.search(r'\bRA\b', dvDic[dv].Result, re.IGNORECASE) is None
        ):
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return abstraction
    return abstraction

def fio2Percentage(value, value2):
    percentage = 0.0
    if value2 == 'Nasal Cannula':
        if float(value) == float(1):
            percentage = 0.24
        elif float(value) == float(2):
            percentage = 0.28
        elif float(value) == float(3):
            percentage = 0.32
        elif float(value) == float(4):
            percentage = 0.36
        elif float(value) == float(5):
            percentage = 0.40
        elif float(value) == float(6):
            percentage = 0.44
        else:
            percentage = 'Invalid'
    elif value2 == 'Simple Face Mask':
        if float(value) == float(6):
            percentage = 0.40
        elif float(value) == float(7):
            percentage = 0.45
        elif float(value) == float(8):
            percentage = 0.50
        elif float(value) == float(9):
            percentage = 0.55
        elif float(value) == float(10):
            percentage = 0.60
        else:
            percentage = 'Invalid'
    else:
        percentage = 'Invalid'
    return percentage

def pO2Conversion(value):
    conversion = 0
    if float(value) == float(80):
        conversion = 44
    elif float(value) == float(81):
        conversion = 45
    elif float(value) == float(82):
        conversion = 46
    elif float(value) == float(83):
        conversion = 47
    elif float(value) == float(84):
        conversion = 49
    elif float(value) == float(85):
        conversion = 50
    elif float(value) == float(86):
        conversion = 51
    elif float(value) == float(87):
        conversion = 52
    elif float(value) == float(88):
        conversion = 54
    elif float(value) == float(89):
        conversion = 56
    elif float(value) == float(90):
        conversion = 58
    elif float(value) == float(91):
        conversion = 60
    elif float(value) == float(92):
        conversion = 64
    elif float(value) == float(93):
        conversion = 68
    elif float(value) == float(94):
        conversion = 73
    elif float(value) == float(95):
        conversion = 80
    elif float(value) == float(96):
        conversion = 90
    else:
        conversion = 'Invalid'
    return conversion

def fi02Convert(value):
    value1 = float(value) / float(100)
    return value1

def pao2fio2Calculation(dvDic, DV1, DV2, DV3, DV4, DV5, DV6, DV7, value1, sequence1):
    discreteDic = {}
    discreteDic1 = {}
    discreteDic2 = {}
    discreteDic3 = {}
    discreteDic4 = {}
    discreteDic5 = {}
    discreteDic6 = {}
    linkText1 = "Pa02/Fi02: [VALUE] (Result Date: [RESULTDATETIME])"
    linkText2 = "Pulse Oximetry: [VALUE] (Result Date: [RESULTDATETIME])"
    linkText3 = "pa02: [VALUE] (Result Date: [RESULTDATETIME])"
    linkText4 = "Oxygen Flow Rate '[VALUE]' (Result Date: [RESULTDATETIME])"
    linkText5 = "Oxygen Therapy '[VALUE]' (Result Date: [RESULTDATETIME])"
    linkText6 = "Fi02: [VALUE] (Result Date: [RESULTDATETIME])"
    linkText7 = "Respiratory Rate: [VALUE] (Result Date: [RESULTDATETIME])"
    #Default should be set to -1 day back.
    dateLimit = System.DateTime.Now.AddDays(-1)
    percentage = None
    w = 0
    x = 0
    y = 0
    z = 0
    a = 0
    b = 0
    c = 0
    rrDV = None
    matchedList = []
    #Pull all values for discrete values we need
    for dv in dvDic or []:
        if dvDic[dv]['ResultDate'] >= dateLimit:
            dvr = cleanNumbers(dvDic[dv]['Result'])
            if dvDic[dv]['Name'] in DV1 and dvr is not None and float(dvr) < float(value1):
                #dvPa02Fi02
                w += 1
                discreteDic[w] = dvDic[dv]
                break
            elif dvDic[dv]['Name'] in DV2 and dvr is not None and float(86) <= float(dvr) <= float(96):
                #dvSPO2
                x += 1
                discreteDic1[x] = dvDic[dv]
            elif dvDic[dv]['Name'] in DV3 and dvr is not None and float(51) <= float(dvr) <= float(90):
                #dvPaO2
                y += 1
                discreteDic2[y] = dvDic[dv]
            elif dvDic[dv]['Name'] in DV4 and dvr is not None and float(dvr) > float(0):
                #dvOxygenFlowRate
                z += 1
                discreteDic3[z] = dvDic[dv]
            elif dvDic[dv]['Name'] in DV5 and dvDic[dv]['Result'] is not None:
                #dvOxygenTherapy
                a += 1
                discreteDic4[a] = dvDic[dv]
            elif dvDic[dv]['Name'] in DV6 and dvr is not None and float(dvr) <= float(100):
                #dvFIO2
                b += 1
                discreteDic5[b] = dvDic[dv]
            elif dvDic[dv]['Name'] in DV7 and dvr is not None:
                #dvRespiratoryRate
                c += 1
                discreteDic6[c] = dvDic[dv]
                
    #Determine if we've gotten a site calculated ratio(dv1/discreteDic). Return ratio and exit function if available.
    if w >= 1:
        matchedList.append(dataConversion(discreteDic[w].ResultDate, linkText1, discreteDic[w].Result, discreteDic[w].UniqueId or discreteDic[w]._id, "abg", sequence1, False))
        return matchedList
    
    #Pa02/Fi02 Ratio Calculation
    if y > 0 and b > 0:
        fio2Date1 = discreteDic5[b].ResultDate.AddMinutes(5)
        fio2Date2 = discreteDic5[b].ResultDate.AddMinutes(-5)
        if (
            discreteDic2[y].ResultDate == discreteDic5[b].ResultDate or 
            fio2Date1 >= discreteDic2[y].ResultDate >= fio2Date2
        ):
            percentage = float(fi02Convert(cleanNumbers(discreteDic5[b].Result)))
            if percentage is not None and percentage > 0:
                calculation = float(cleanNumbers(discreteDic2[y].Result)) / float(percentage)
                if float(calculation) <= float(300):
                    for item in discreteDic6:
                        if discreteDic6[item].ResultDate == discreteDic2[y].ResultDate:
                            rrDV = item
                            break
                    if rrDV is not None:
                        respRateDV = discreteDic6[rrDV].Result
                    else:
                        respRateDV = "XX"
                    matchingDate = datetimeFromUtcToLocal(discreteDic2[y].ResultDate)
                    matchingDate = matchingDate.ToString("MM/dd/yyyy, HH:mm")
                    matchedList.append(dataConversion(None, matchingDate + " Respiratory Rate: " + str(respRateDV) + ", Pa02: " + str(discreteDic2[y].Result) + ", FIO2: " + str(discreteDic5[b].Result) + ", Estimated PF Ratio- [VALUE]" , str(round(calculation)), discreteDic2[y].UniqueId or discreteDic2[y]._id, calcpo2fio2, 8, False))
                    db.LogEvaluationScriptMessage("found PF Ratio Match " + str(account._id), scriptName, scriptInstance, "Debug")
                    return matchedList
        
    #Pa02/Oxygen Therapy/Oxygen Flow Rate Ratio Calculation
    if y > 0 and z > 0 and a > 0:   
        oxygenFlowRateDate1 = discreteDic3[z].ResultDate.AddMinutes(5)
        oxygenFlowRateDate2 = discreteDic3[z].ResultDate.AddMinutes(-5)
        oxygenTherapyDate1 = discreteDic4[a].ResultDate.AddMinutes(5)
        oxygenTherapyDate2 = discreteDic4[a].ResultDate.AddMinutes(-5)
        if (
            discreteDic2[y].ResultDate == discreteDic3[z].ResultDate == discreteDic4[a].ResultDate or 
            (oxygenFlowRateDate1 >= discreteDic2[y].ResultDate >= oxygenFlowRateDate2 and
            oxygenTherapyDate1 >= discreteDic2[y].ResultDate >= oxygenTherapyDate2)
        ):
            percentage = fio2Percentage(cleanNumbers(discreteDic3[z].Result), discreteDic4[a].Result)
            if percentage == 'Invalid':
                return None
            calculation = float(cleanNumbers(discreteDic2[y].Result)) / float(percentage)
            if float(calculation) <= float(300):
                for item in discreteDic6:
                    if discreteDic6[item].ResultDate == discreteDic2[y].ResultDate:
                        rrDV = item
                        break
                if rrDV is not None:
                    respRateDV = discreteDic6[rrDV].Result
                else:
                    respRateDV = "XX"
                matchingDate = datetimeFromUtcToLocal(discreteDic2[y].ResultDate)
                matchingDate = matchingDate.ToString("MM/dd/yyyy, HH:mm")
                matchedList.append(dataConversion(None, matchingDate + " Respiratory Rate: " + str(respRateDV) + ", Pa02: " + str(discreteDic2[y].Result) + ", Oxygen Flow Rate: " + str(discreteDic3[z].Result) + ", Oxygen Therapy: " + str(discreteDic4[a].Result) + ", Estimated PF Ratio- [VALUE]" , str(round(calculation)), discreteDic2[y].UniqueId or discreteDic2[y]._id, calcpo2fio2, 8, False))
                db.LogEvaluationScriptMessage("found PF Ratio Match " + str(account._id), scriptName, scriptInstance, "Debug")
                return matchedList
            
    #sp02/Fi02 Ratio Calculation
    if x > 0 and b > 0:
        fio2Date1 = discreteDic5[b].ResultDate.AddMinutes(5)
        fio2Date2 = discreteDic5[b].ResultDate.AddMinutes(-5)
        if (
            discreteDic1[x].ResultDate == discreteDic5[b].ResultDate or 
            fio2Date1 >= discreteDic1[x].ResultDate >= fio2Date2
        ):    
            percentage = float(fi02Convert(cleanNumbers(discreteDic5[b].Result)))
            pO2Converted = pO2Conversion(cleanNumbers(discreteDic1[x].Result))
            if pO2Converted is not None and pO2Converted > 0 and percentage is not None and percentage > 0:
                calculation = float(pO2Converted) / float(percentage)
                if float(calculation) <= float(300):
                    for item in discreteDic6:
                        if discreteDic6[item].ResultDate == discreteDic1[x].ResultDate:
                            rrDV = item
                            break
                    if rrDV is not None:
                        respRateDV = discreteDic6[rrDV].Result
                    else:
                        respRateDV = "XX"
                    matchingDate = datetimeFromUtcToLocal(discreteDic1[x].ResultDate)
                    matchingDate = matchingDate.ToString("MM/dd/yyyy, HH:mm")
                    matchedList.append(dataConversion(None, matchingDate + " Respiratory Rate: " + str(respRateDV) + ", Sp02: " + str(discreteDic1[x].Result) + ", FIO2: " + str(discreteDic5[b].Result) + ", Estimated PF Ratio- [VALUE]" , str(round(calculation)), discreteDic1[x].UniqueId or discreteDic1[x]._id, calcpo2fio2, 8, False))
                    db.LogEvaluationScriptMessage("found PF Ratio Match " + str(account._id), scriptName, scriptInstance, "Debug")
                    return matchedList
        
    #sp02/Oxygen Therapy/Oxygen Flow Rate Ratio Calculation
    if x > 0 and z > 0 and a > 0:   
        oxygenFlowRateDate1 = discreteDic3[z].ResultDate.AddMinutes(5)
        oxygenFlowRateDate2 = discreteDic3[z].ResultDate.AddMinutes(-5)
        oxygenTherapyDate1 = discreteDic4[a].ResultDate.AddMinutes(5)
        oxygenTherapyDate2 = discreteDic4[a].ResultDate.AddMinutes(-5)
        if (
            discreteDic3[z].ResultDate == discreteDic1[x].ResultDate == discreteDic4[a].ResultDate or 
            (oxygenFlowRateDate1 >= discreteDic1[x].ResultDate >= oxygenFlowRateDate2 and
            oxygenTherapyDate1 >= discreteDic1[x].ResultDate >= oxygenTherapyDate2)
        ):    
            pO2Converted = pO2Conversion(cleanNumbers(discreteDic1[x].Result))
            percentage = fio2Percentage(cleanNumbers(discreteDic3[z].Result), discreteDic4[a].Result)
            if percentage == 'Invalid':
                return None
            if pO2Converted is not None and pO2Converted > 0:
                calculation = float(pO2Converted) / float(percentage)
                if float(calculation) <= float(300):
                    for item in discreteDic6:
                        if discreteDic6[item].ResultDate == discreteDic1[x].ResultDate:
                            rrDV = item
                            break
                    if rrDV is not None:
                        respRateDV = discreteDic6[rrDV].Result
                    else:
                        respRateDV = "XX"
                    matchingDate = datetimeFromUtcToLocal(discreteDic1[x].ResultDate)
                    matchingDate = matchingDate.ToString("MM/dd/yyyy, HH:mm")
                    matchedList.append(dataConversion(None, matchingDate + " Respiratory Rate: " + str(respRateDV) + ", Sp02: " + str(discreteDic1[x].Result) + ", Oxygen Flow Rate: " + str(discreteDic3[z].Result) + ", Oxygen Therapy: " + str(discreteDic4[a].Result) + ", Estimated PF Ratio- [VALUE]" , str(round(calculation)), discreteDic1[x].UniqueId or discreteDic1[x]._id, calcpo2fio2, 8, False))
                    db.LogEvaluationScriptMessage("found PF Ratio Match " + str(account._id), scriptName, scriptInstance, "Debug")
                    return matchedList
    return None

def sp02pa02Lookup(dvDic, DV1, DV2, DV3, DV4):
    discreteDic1 = {}
    discreteDic2 = {}
    discreteDic3 = {}
    discreteDic4 = {}
    linkText1 = "sp02: [VALUE] (Result Date: [RESULTDATETIME])"
    linkText2 = "pa02: [VALUE] (Result Date: [RESULTDATETIME])"
    linkText3 = "Oxygen Therapy '[VALUE]' (Result Date: [RESULTDATETIME])"
    linkText4 = "Respiratory Rate: [VALUE] (Result Date: [RESULTDATETIME])"
    rrDV = None
    #Default should be set to -1 day back.
    dateLimit = System.DateTime.Now.AddDays(-1)
    otDv = None
    spDv = None
    paDv = None
    matchingDate = None
    oxygenValue = None
    respRateDV = None
    w = 0
    x = 0
    y = 0
    z = 0
    matchedList = []
    #Pull all values for discrete values we need
    for dv in dvDic or []:
        if dvDic[dv]['ResultDate'] >= dateLimit:
            dvr = cleanNumbers(dvDic[dv]['Result'])
            if dvDic[dv]['Name'] in DV1 and dvr is not None and float(dvr) < float(91):
                #dvSPO2
                w += 1
                discreteDic1[w] = dvDic[dv]
            elif dvDic[dv]['Name'] in DV2 and dvr is not None and float(dvr) <= float(60):
                #dvPaO2
                x += 1
                discreteDic2[x] = dvDic[dv]
            elif dvDic[dv]['Name'] in DV3 and dvDic[dv]['Result'] is not None:
                #dvOxygenTherapy
                y += 1
                discreteDic3[y] = dvDic[dv]
            elif dvDic[dv]['Name'] in DV4 and dvr is not None:
                #dvRespiratoryRate
                z += 1
                discreteDic4[z] = dvDic[dv]
    if x > 0:
        for item in discreteDic2:
            matchingDate = discreteDic2[item].ResultDate
            paDv = item
            if y > 0:
                for item2 in discreteDic3:
                    if discreteDic2[item].ResultDate == discreteDic3[item2].ResultDate:
                        matchingDate = discreteDic2[item].ResultDate
                        otDv = item2
                        oxygenValue = discreteDic3[item2].Result
            else:
                oxygenValue = "XX" 
            if z > 0:
                for item3 in discreteDic4:
                    if discreteDic4[item3].ResultDate == matchingDate:
                        rrDV = item3
                        respRateDV = discreteDic4[item3].Result
                        break
            else:
                respRateDV = "XX"
            matchingDate = datetimeFromUtcToLocal(matchingDate)
            matchingDate = matchingDate.ToString("MM/dd/yyyy, HH:mm")
            matchedList.append(dataConversion(None, matchingDate + " Respiratory Rate: " + str(respRateDV) + ", Oxygen Therapy: " + str(oxygenValue) + ", pa02: " + str(discreteDic2[paDv].Result), None, discreteDic2[paDv].UniqueId or discreteDic2[paDv]._id, oxygenation, 0, False))
            matchedList.append(dataConversion(discreteDic2[paDv].ResultDate, linkText2, discreteDic2[paDv].Result, discreteDic2[paDv].UniqueId or discreteDic2[paDv]._id, paO2, 2, False))
            if otDv is not None:
                matchedList.append(dataConversion(discreteDic3[otDv].ResultDate, linkText3, discreteDic3[otDv].Result, discreteDic3[otDv].UniqueId or discreteDic3[otDv]._id, oxygenTherapy, 3, False))
            if rrDV is not None:
                matchedList.append(dataConversion(discreteDic4[rrDV].ResultDate, linkText4, discreteDic4[rrDV].Result, discreteDic4[rrDV].UniqueId or discreteDic4[rrDV]._id, rr, 4, False))
        db.LogEvaluationScriptMessage("SPO2 log message: SPO2 Found matches" + str(w) + ", PAO2 Found Matches: " + str(x)
            + ", Oxygen Therapy Found Matches: " + str(y) + ", Respiratory Found Matchs: " + str(z) + ", Matching Date: " + str(matchingDate) + " " 
            + str(account._id), scriptName, scriptInstance, "Debug")
        return matchedList
    elif w > 0:
        for item in discreteDic1:
            matchingDate = discreteDic1[item].ResultDate
            spDv = item
            if y > 0:
                for item2 in discreteDic3:
                    if discreteDic1[item].ResultDate == discreteDic3[item2].ResultDate:
                        otDv = item2
                        oxygenValue = discreteDic3[item2].Result
                        break
            else:
                oxygenValue = "XX" 
            if z > 0:
                for item3 in discreteDic4:
                    if discreteDic4[item3].ResultDate == discreteDic1[item].ResultDate:
                        rrDV = item3
                        respRateDV = discreteDic4[item3].Result
                        break
            else:
                respRateDV = "XX"
            matchingDate = datetimeFromUtcToLocal(matchingDate)
            matchingDate = matchingDate.ToString("MM/dd/yyyy, HH:mm")
            matchedList.append(dataConversion(None, matchingDate + " Respiratory Rate: " + str(respRateDV) + ", Oxygen Therapy: " + str(oxygenValue) + ", sp02: " + str(discreteDic1[spDv].Result), None, discreteDic1[spDv].UniqueId or discreteDic1[spDv]._id, oxygenation, 0, False))
            matchedList.append(dataConversion(discreteDic1[spDv].ResultDate, linkText1, discreteDic1[spDv].Result, discreteDic1[spDv].UniqueId or discreteDic1[spDv]._id, spo2, 1, False))
            if otDv is not None:
                matchedList.append(dataConversion(discreteDic3[otDv].ResultDate, linkText3, discreteDic3[otDv].Result, discreteDic3[otDv].UniqueId or discreteDic3[otDv]._id, oxygenTherapy, 5, False))
            if rrDV is not None:
                matchedList.append(dataConversion(discreteDic4[rrDV].ResultDate, linkText4, discreteDic4[rrDV].Result, discreteDic4[rrDV].UniqueId or discreteDic4[rrDV]._id, rr, 7, False))
        db.LogEvaluationScriptMessage("SPO2 log message: SPO2 Found matches" + str(w) + ", PAO2 Found Matches: " + str(x)
            + ", Oxygen Therapy Found Matches: " + str(y) + ", Respiratory Found Matchs: " + str(z) + ", Matching Date: " + str(matchingDate) + " " 
            + str(account._id), scriptName, scriptInstance, "Debug")
        return matchedList
    else:
        db.LogEvaluationScriptMessage("SPO2 log message: SPO2 Found matches" + str(w) + ", PAO2 Found Matches: " + str(x)
            + ", Oxygen Therapy Found Matches: " + str(y) + ", Respiratory Found Matchs: " + str(z) + ", Matching Date: " + str(matchingDate) + " " 
            + str(account._id), scriptName, scriptInstance, "Debug")
        return None
    
#========================================
#  Algorithm
#========================================
db.LogEvaluationScriptMessage("Script starting " + str(account._id), scriptName, scriptInstance, "Debug")
#Determine if if and how many fully spec codes are on the acct
specifiedCodes = []
specifiedCodes = specCodeDic.keys()
specCodeList = CodeCount(specifiedCodes)
specifiedCount = len(specCodeList)
str1 = ', '.join([str(elem) for elem in specCodeList])

unSpecifiedCodes = []
unspecifiedCodes = unspecCodeDic.keys()
unSpecCodeList = CodeCount(unspecifiedCodes)
unspecifiedCount = len(unSpecCodeList)
str2 = ', '.join([str(elem) for elem in unSpecCodeList])

#Standard Variable Declaration
AlertPassed = False
alertTriggered = False
AlertConditions = False
validated = False
outcome = None
subtitle = None
message1 = False; message2 = False; message3 = False; message4 = False
CI = 0; ODC = 0; OC = 0; HC = 0; LOC = 0
abgLinks = False
dcLinks = False
absLinks = False
calcpo2fio2Links = False
labsLinks = False
vitalsLinks = False
oxygenLinks = False
medsLinks = False
docLinksLinks = False

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 2)
oxygen = MatchedCriteriaLink("Oxygenation/Ventilation", None, "Oxygenation/Ventilation", None, True, None, None, 3)
calcpo2fio2 = MatchedCriteriaLink("Calculated P02/Fi02 Ratio", None, "Calculated P02/Fi02 Ratio", None, True, None, None, 4)
oxygenation = MatchedCriteriaLink("O2 Indicators", None, "O2 Indicators", None, True, None, None, 5)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 6)
vitals = MatchedCriteriaLink("Vital Signs/Intake and Output Data", None, "Vital Signs/Intake and Output Data", None, True, None, None, 7)
meds = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 8)
chestXRayLinks = MatchedCriteriaLink("Chest X-Ray", None, "Chest X-Ray", None, True, None, None, 9)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 10)
abg = MatchedCriteriaLink("ABG", None, "ABG", None, True, None, None, 88)
spo2 = MatchedCriteriaLink("Sp02", None, "Sp02", None, True, None, None, 89)
pa02Fi02 = MatchedCriteriaLink("Pa02Fi02", None, "Pa02Fi02", None, True, None, None, 90)
spo22 = MatchedCriteriaLink("Sp02", None, "Sp02", None, True, None, None, 91)
paO2 = MatchedCriteriaLink("Pa02", None, "Pa02", None, True, None, None, 92)
fio2 = MatchedCriteriaLink("FI02", None, "FI02", None, True, None, None, 93)
rr = MatchedCriteriaLink("Respiratory Rate", None, "Respiratory Rate", None, True, None, None, 94)
oxygenFlowRate = MatchedCriteriaLink("Oxygen Flow Rate", None, "Oxygen Flow Rate", None, True, None, None, 95)
oxygenTherapy = MatchedCriteriaLink("Oxygen Therapy", None, "Oxygen Therapy", None, True, None, None, 96)
pC02 = MatchedCriteriaLink("pC02", None, "pC02", None, True, None, None, 95)

#Link Text for special messages for lacking
LinkText1 = "Possible Missing Respiratory Clinical Evidence"
LinkText2 = "Possible Missing Type of Ventilation or Oxygen Delivery Method"
LinkText3 = "Possible Missing Sign(s) of Hypoxia, No Low Oxygen Levels Found"
LinkText4 = "Possible Missing Sign(s) of Hypercapnia, No High Carbon Dioxide Levels Found"

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Respiratory Failure':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        subtitle = alert.Subtitle
        for alertLink in alert.Links:
            if alertLink.LinkText == 'Vital Signs/Intake and Output Data':
                for links in alertLink.Links:
                    if links.LinkText == LinkText3:
                        message3 = True
            if alertLink.LinkText == 'Laboratory Studies':
                for links in alertLink.Links:
                    if links.LinkText == LinkText4:
                        message4 = True
            if alertLink.LinkText == 'Clinical Evidence':
                for links in alertLink.Links:
                    if links.LinkText == LinkText1:
                        message1 = True
            if alertLink.LinkText == 'Oxygenation/Ventilation':
                for links in alertLink.Links:
                    if links.LinkText == LinkText2:
                        message2 = True
        break

#Check if alert was autoresolved or completed.
if validated is False:
    #Find all discrete values for custom lookups within the last X days
    maindiscreteDic = {}
    unsortedDicsreteDic = {}
    dvCount = 0
    #Combine all items into one list to search against
    discreteSearchList = [i for j in [dvPa02Fi02, dvSPO2, dvPaO2, dvOxygenFlowRate, dvOxygenTherapy, dvFIO2, dvRespiratoryRate,
                dvArterialBloodC02, dvPaO2] for i in j]
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
    negationAcuteRespiratoryFailure = multiCodeValue(["J96.01", "J96.02", "J96.11", "J96.12", "J96.21", "J96.22", "J96.90", "J96.91", "J96.92", "J96.00", "J96.10", "J96.20"], "Respiratory Failure Fully Specified Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Documented Dx
    acuteRespiratoryFailureHypox = multiCodeValue(["J96.01", "J96.21"], "Acute Respiratory Failure with Hypoxia Fully Specified Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    acuteRespiratoryFailureHyper= multiCodeValue(["J96.02", "J96.22"], "Acute Respiratory Failure with Hypercapnia Fully Specified Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j9600Code = codeValue("J96.00", "Acute Respiratory Failure, Unspecified Whether With Hypoxia Or Hypercapnia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j9601Code = codeValue("J96.01", "Acute Respiratory Failure With Hypoxia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j9602Code = codeValue("J96.02", "Acute Respiratory Failure With Hypercapnia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j9611Code = codeValue("J96.11", "Chronic Respiratory Failure With Hypoxia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j9612Code = codeValue("J96.12", "Chronic Respiratory Failure With Hypercapnia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j9621Code = codeValue("J96.21", "Autoresolved Alert Due To Acute and Chronic Respiratory Failure with Hypoxia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j9622Code = codeValue("J96.22", "Autoresolved Alert Due To Acute on Chronic Respiratory Failure with Hypercapnia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j9610Code = codeValue("J96.10", "Chronic Respiratory Failure Dx, Unspecified Whether With Hypoxia Or Hypercapnia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j9620Code = codeValue("J96.20", "Acute And Chronic Respiratory Failure, Unspecified Whether With Hypoxia Or Hypercapnia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j9690Code = codeValue("J96.90", "Respiratory Failure, Unspecified, Unspecified Whether With Hypoxia Or Hypercapnia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j9691Code = codeValue("J96.91", "Respiratory Failure, Unspecified With Hypoxia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j9692Code = codeValue("J96.92", "Respiratory Failure, Unspecified With Hypercapnia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    z9911Code = codeValue("Z99.11", "Dependence On Ventilator: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j95821Code = codeValue("J95.821", "Acute Postprocedural Respiratory Failure (MCC): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j80Code = codeValue("J80", "Acute Respiratory Distress Syndrome (MCC): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Abs
    nasalFlaringAbs = abstractValue("NASAL_FLARING", "Nasal Flaring '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 31)
    paradoxicalBreathingAbs = abstractValue("PARADOXICAL_BREATHING", "Paradoxical Breathing '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 33)
    r092Code = codeValue("R09.2", "Respiratory Arrest: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 38)
    retractionsAbs = abstractValue("RETRACTIONS", "Retractions '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 39)
    shortnessOfBreathAbs = abstractValue("SHORTNESS_OF_BREATH", "Shortness of Breath '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 40)
    r061Code = codeValue("R06.1", "Stridor: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 41)
    tripodBreathingAbs = abstractValue("TRIPOD_BREATHING ", "Tripod Breathing '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 42)
    useOfAccessoryMusclesAbs = abstractValue("USE_OF_ACCESSORY_MUSCLES", "Use of Accessory Muscles '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 43)
    wheezingAbs = codeValue("R06.2", "Wheezing: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 45)
    #Labs
    highArterialBloodC02Abs = abstractValue("HIGH_BLOOD_C02", "Blood CO2: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1)
    lowPulseOximetryAbs = abstractValue("LOW_PULSE_OXIMETRY", "Sp02 '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4)
    #abg
    highArterialBloodC02DV = dvValueMulti(dict(maindiscreteDic), dvArterialBloodC02, "paCO2: [VALUE] (Result Date: [RESULTDATETIME])", calcArterialBloodC021, gt, 0, pC02, False, 10)
    pA0280DV = dvValueMulti(dict(maindiscreteDic), dvPaO2, "pa02: [VALUE] (Result Date: [RESULTDATETIME])", calcPAO21, lt, 0, paO2, False, 10)
    venousBloodDV = dvValue(dvVenousBloodCO2, "Venous Blood C02: [VALUE] (Result Date: [RESULTDATETIME])", calcVenousBloodCO2, 3)
    #Oxygen
    baselineAbs = abstractValue("BASELINE_OXYGEN_USE", "Baseline Oxygen Use '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1)
    ecmoCodes = multiCodeValue(["5A1522F", "5A1522G", "5A1522H", "5A15A2F", "5A15A2G", "5A15A2H"], "ECMO: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    z9981Code = codeValue("Z99.81", "Dependence On Supplemental Oxygen: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3)
    z9911Code = codeValue("Z99.11", "Dependence On Ventilator: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4)
    highFlowNasalCodes = multiCodeValue(["5A0935A", "5A0945A", "5A0955A"], "High Flow Nasal Oxygen: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6)
    intubationCode = codeValue("0BH17EZ", "Intubation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7)
    invasiveMechVentCodes = multiCodeValue(["5A1935Z", "5A1945Z", "5A1955Z"], "Invasive Mechanical Ventilation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8)
    nasalCannulaCode = codeValue("3E0F7SF", "Nasal Cannula: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9)
    nonInvasiveMechVentCodes = abstractValue("NON_INVASIVE_VENTILATION", "Non-Invasive Ventilation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10)
    oxygenTherapyDV = dvOxygenCheck(dict(maindiscreteDic), dvOxygenTherapy, "Oxygen Therapy '[VALUE]' (Result Date: [RESULTDATETIME])", 12)
    oxygenTherapyAbs = abstractValue("OXYGEN_THERAPY", "Oxygen Therapy '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13)
    z930Code = codeValue("Z93.0", "Tracheostomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14)
    #Vitals
    lackingPa02DV = dvValue(dvPaO2, "pa02: [VALUE] (Result Date: [RESULTDATETIME])", calcPAO22, 3)
    lackingPa02Fi02DV = dvValue(dvPa02Fi02, "P02(a)/Fi02 Ratio: [VALUE] (Result Date: [RESULTDATETIME])", calcPa02Fi022, 4)
    highRespiratoryRateDV = dvValue(dvRespiratoryRate, "Respiratory Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcRespiratoryRate1, 5)
    lowRespiratoryRateDV = dvValue(dvRespiratoryRate, "Respiratory Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcRespiratoryRate2, 6)
    lackingPulseOximetryDV = dvValue(dvSPO2, "Sp02: [VALUE] (Result Date: [RESULTDATETIME])", calcRespiratoryRate2, 7)
    #Vitals Subheading
    lowPulseOximetryDV = dvValueMulti(dict(maindiscreteDic), dvSPO2, "Sp02: [VALUE] (Result Date: [RESULTDATETIME])", calcSPO21, lt, 0, spo2, False, 10)
    #Calculated Po2/Fio2
    pao2Calc = None
    sp02pao2Dvs = None
    if z9981Code is None:
        pao2Calc = pao2fio2Calculation(dict(maindiscreteDic), dvPa02Fi02, dvSPO2, dvPaO2, dvOxygenFlowRate, dvOxygenTherapy, dvFIO2, dvRespiratoryRate, calcPa02Fi021, 2)
    if pao2Calc is None:
        sp02pao2Dvs = sp02pa02Lookup(dict(maindiscreteDic), dvSPO2, dvPaO2, dvOxygenTherapy, dvRespiratoryRate)
 
    #Clinical Indicator Checks
    if useOfAccessoryMusclesAbs is not None: abs.Links.Add(useOfAccessoryMusclesAbs); CI += 1
    if wheezingAbs is not None: abs.Links.Add(wheezingAbs); CI += 1
    if shortnessOfBreathAbs is not None: abs.Links.Add(shortnessOfBreathAbs); CI += 1
    if (
        lowRespiratoryRateDV is not None or 
        highRespiratoryRateDV is not None
    ):
        CI += 1
        if highRespiratoryRateDV is not None: vitals.Links.Add(highRespiratoryRateDV)
        if lowRespiratoryRateDV is not None: vitals.Links.Add(lowRespiratoryRateDV)
    if r061Code is not None: abs.Links.Add(r061Code); CI += 1
    if tripodBreathingAbs is not None: abs.Links.Add(tripodBreathingAbs); CI += 1
    if r092Code is not None: abs.Links.Add(r092Code); CI += 1
    if paradoxicalBreathingAbs is not None: abs.Links.Add(paradoxicalBreathingAbs); CI += 1
    if retractionsAbs is not None: abs.Links.Add(retractionsAbs); CI += 1
    #Oxygen Delivery Check
    if oxygenTherapyDV is not None or oxygenTherapyAbs is not None: ODC += 1
    if intubationCode is not None: ODC += 1
    if nonInvasiveMechVentCodes is not None: ODC += 1
    if invasiveMechVentCodes is not None: ODC += 1
    if highFlowNasalCodes is not None: ODC += 1
    if nasalCannulaCode is not None: ODC += 1
    #Oxygenation Check
    if pao2Calc is not None: OC += 1
    if sp02pao2Dvs is not None: OC += 1
    #Hypercapnic check
    if highArterialBloodC02DV is not None or highArterialBloodC02Abs is not None:
        HC += 1
        if highArterialBloodC02Abs is not None: labs.Links.Add(highArterialBloodC02Abs)
    if venousBloodDV is not None: HC += 1
    #Lacking Oxygenation Check
    if lackingPa02DV is not None: LOC += 1
    if lackingPa02Fi02DV is not None: LOC += 1
    if lackingPulseOximetryDV is not None: LOC += 1
    if pao2Calc is not None: LOC += 1
    
   #Main Algorithm
   #1.1
    if (
        subtitle == "Acute Respiratory Failure With Hypoxia Possibly Lacking Supporting Evidence" and
        ((message1 is False or (message1 is True and CI > 0)) and
        (message2 is False or (message2 is True and ODC > 0)) and
        (message3 is False or (message3 is True and LOC > 0)))
    ):
        if message1:
            abs.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, False))
        if message2:
            oxygen.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None, False))
        if message3:
            vitals.Links.Add(MatchedCriteriaLink(LinkText3, None, None, None, False))
            if lackingPa02DV is not None: vitals.Links.Add(lackingPa02DV)
            if lackingPa02Fi02DV is not None: vitals.Links.Add(lackingPa02Fi02DV)
            if lackingPulseOximetryDV is not None: vitals.Links.Add(lackingPulseOximetryDV)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to clinical evidence now existing on the Account"
        result.Validated = True
        AlertPassed = True
    #1
    elif (
        acuteRespiratoryFailureHypox is not None and
        (CI == 0 or ODC == 0 or LOC == 0)
    ):
        dc.Links.Add(acuteRespiratoryFailureHypox)
        if CI < 1: abs.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None))
        if ODC < 1: oxygen.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None))
        if LOC < 1: vitals.Links.Add(MatchedCriteriaLink(LinkText3, None, None, None))
        if lackingPa02DV is not None: vitals.Links.Add(lackingPa02DV)
        if lackingPa02Fi02DV is not None: vitals.Links.Add(lackingPa02Fi02DV)
        if lackingPulseOximetryDV is not None: vitals.Links.Add(lackingPulseOximetryDV)
        result.Subtitle = "Acute Respiratory Failure With Hypoxia Possibly Lacking Supporting Evidence"
        result.Passed = True
        AlertPassed = True
    #2.1
    elif (
        subtitle == "Acute Respiratory Failure With Hypercapnia Possibly Lacking Supporting Evidence" and
        ((message1 is False or (message1 is True and CI > 0)) and
        (message2 is False or (message2 is True and ODC > 0)) and
        (message4 is False or (message4 is True and HC > 0)))
     ):
        if message1:
            abs.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, False))
        if message2:
            oxygen.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None, False))
        if message4:
            labs.Links.Add(MatchedCriteriaLink(LinkText4, None, None, None, False))
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to clinical evidence now existing on the Account"
        result.Validated = True
        AlertPassed = True
    #2
    elif (
        acuteRespiratoryFailureHyper is not None and
        (CI == 0 or ODC == 0 or HC == 0)
    ):
        result.Subtitle = "Acute Respiratory Failure With Hypercapnia Possibly Lacking Supporting Evidence"
        dc.Links.Add(acuteRespiratoryFailureHyper)
        if CI < 1: abs.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None))
        if ODC < 1: oxygen.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None))
        if HC < 1: labs.Links.Add(MatchedCriteriaLink(LinkText4, None, None, None))
        AlertPassed = True
        result.Passed = True
    #3.1/4.1/5.1
    elif (
        (subtitle == "Respiratory Failure Dx Missing Acuity and Type" or
        subtitle == "Respiratory Failure with Hypoxia, Acuity Missing" or
        subtitle == "Respiratory Failure with Hypercapnia, Acuity Missing") and
        (j9601Code is not None or
         j9602Code is not None or
         j95821Code is not None or 
         j80Code is not None)
    ):
        if j9602Code is not None: dc.Links.Add(j9602Code)
        if j9601Code is not None: dc.Links.Add(j9601Code)
        if j95821Code is not None: dc.Links.Add(j95821Code)
        if j80Code is not None: dc.Links.Add(j80Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specifed Code now existing on the Account"
        result.Validated = True
        AlertConditions = True
    #3
    elif j9691Code is not None:
        dc.Links.Add(j9691Code)
        result.Subtitle = "Respiratory Failure with Hypoxia, Acuity Missing"
        AlertPassed = True
    #4
    elif j9692Code is not None:
        dc.Links.Add(j9692Code)
        result.Subtitle = "Respiratory Failure with Hypercapnia, Acuity Missing"
        AlertPassed = True 
    #5    
    elif j9690Code is not None:
        dc.Links.Add(j9690Code)
        result.Subtitle = "Respiratory Failure Dx Missing Acuity and Type"
        AlertPassed = True
    #6.1
    elif (
        subtitle == "Possible Acute Respiratory Failure" and
        (j9601Code is not None or
         j9602Code is not None or
         j95821Code is not None or 
         j80Code is not None or
         j9621Code is not None or 
         j9622Code is not None)
    ):
        if j9602Code is not None: dc.Links.Add(j9602Code)
        if j9601Code is not None: dc.Links.Add(j9601Code)
        if j95821Code is not None: dc.Links.Add(j95821Code)
        if j80Code is not None: dc.Links.Add(j80Code)
        if j9621Code is not None: dc.Links.Add(j9621Code)
        if j9622Code is not None: dc.Links.Add(j9622Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specifed Code now existing on the Account"
        result.Validated = True
        AlertConditions = True           
    #6
    elif unspecifiedCount == 0 and specifiedCount == 0 and CI >= 2 and ODC >= 1 and (OC >= 1 or HC >= 1):
        result.Subtitle = "Possible Acute Respiratory Failure"
        AlertPassed = True
    #7.1/8.1
    elif (
        subtitle == "Possible Chronic Respiratory Failure" and
        (j9601Code is not None or
         j9602Code is not None or
         j95821Code is not None or 
         j80Code is not None or
         j9621Code is not None or 
         j9622Code is not None or 
         j9611Code is not None or
         j9612Code is not None)
    ):
        if j9602Code is not None: dc.Links.Add(j9602Code)
        if j9601Code is not None: dc.Links.Add(j9601Code)
        if j95821Code is not None: dc.Links.Add(j95821Code)
        if j80Code is not None: dc.Links.Add(j80Code)
        if j9621Code is not None: dc.Links.Add(j9621Code)
        if j9622Code is not None: dc.Links.Add(j9622Code)
        if j9611Code is not None: dc.Links.Add(j9611Code)
        if j9612Code is not None: dc.Links.Add(j9612Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specifed Code now existing on the Account"
        result.Validated = True
        AlertConditions = True   
    #7
    elif (
        negationAcuteRespiratoryFailure is None and
        z930Code is not None and
        (OC >= 1 or HC >= 1)
    ):
        result.Subtitle = "Possible Chronic Respiratory Failure"
        AlertPassed = True
    #8
    elif z9981Code is not None or z9911Code is not None:
        result.Subtitle = "Possible Chronic Respiratory Failure"
        AlertPassed = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Abs
    codeValue("R06.9", "Abnormalities of Breathing: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, abs, True)
    r4182Code = codeValue("R41.82", "Altered Level Of Consciousness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    alteredAbs = abstractValue("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level Of Consciousness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3)
    if r4182Code is not None:
        abs.Links.Add(r4182Code)
        if alteredAbs is not None: alteredAbs.Hidden = True; abs.Links.Add(alteredAbs)
    elif r4182Code is None and alteredAbs is not None:
        abs.Links.Add(alteredAbs)
    codeValue("G12.21", "Amyotrophic Lateral Sclerosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, abs, True)
    codeValue("T78.3XXA", "Angioedema: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, abs, True)
    codeValue("R06.81", "Apnea: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, abs, True)
    codeValue("J69.0", "Aspiration: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, abs, True)
    multiCodeValue(["J45.21", "J45.31", "J45.41", "J45.51", "J454.901"], "Asthma with Acute Exacerbation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8, abs, True)
    multiCodeValue(["J45.22", "J45.32", "J45.42", "J45.52", "J45.902"], "Asthma with Status Asthmaticus: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, abs, True)
    codeValue("J98.01", "Bronchospasm: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, abs, True)
    codeValue("J44.9", "Chronic Obstructive Pulmonary Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, abs, True)
    codeValue("J44.1", "Chronic Obstructive Pulmonary Disease With (Acute) Exacerbation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, abs, True)
    codeValue("J44.0", "Chronic Obstructive Pulmonary Disease With (Acute) Lower Respiratory Infection: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13, abs, True)
    codeValue("R05.9", "Cough: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, abs, True)
    codeValue("U07.1", "COVID-19 Infection: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
    abstractValue("CYANOSIS", "Cyanosis '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 16, abs, True)
    codeValue("E84.0", "Cystic Fibrosis with Pulmonary Manifestations: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17, abs, True)
    codeValue("E84.9", "Cystic Fibrosis: [CODE] '[PHRASE]' ([DrUMENTTYPE], [DOCUMENTDATE])", 18, abs, True)
    abstractValue("DIAPHORETIC", "Diaphoretic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 19, abs, True)
    codeValue("R41.0", "Disorientation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20, abs, True)
    codeValue("R53.83", "Fatigue: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21, abs, True)
    codeValue("E87.70", "Fluid Overloaded: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 22, abs, True)
    codeValue("K76.7", "Hepatorenal Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23, abs, True)
    codeValue("R09.02", "Hypoxia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 24, abs, True)
    codeValue("J84.9", "Interstitial Lung Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 25, abs, True)
    abstractValue("IRREGULAR_RADIOLOGY_REPORT_LUNGS", "Irregular Radiology Lungs '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 26, abs, True)
    codeValue("N28.0", "Ischemia and Infarction of Kidney: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 27, abs, True)
    codeValue("G71.00", "Muscular Dystrophy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 28, abs, True)
    codeValue("G70.01", "Myasthenia Gravis with Exacerbation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 29, abs, True)
    codeValue("G70.00", "Myasthenia Gravis without Exacerbation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 30, abs, True)
    #31
    abstractValue("OPIOID_OVERDOSE", "Opioid Overdose '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 32, abs, True)
    #33
    abstractValue("PLEURAL_EFFUSION", "Pleural Effusion '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 34, abs, True)
    codeValue("U09.9", "Post COVID-19 Condition: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 35, abs, True)
    abstractValue("PULMONARY_EDEMA", "Pulmonary Edema '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 36, abs, True)
    abstractValue("PULMONARY_TOILET", "Pulmonary Toilet: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 37, abs, True)
    #38-43
    codeValue("J95.851", "Ventilator Associated Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 44, abs, True)
    #45
    #Document Links
    documentLink("Chest  3 View", "Chest  3 View", 0, chestXRayLinks, True)
    documentLink("Chest  PA and Lateral", "Chest  PA and Lateral", 0, chestXRayLinks, True)
    documentLink("Chest  Portable", "Chest  Portable", 0, chestXRayLinks, True)
    documentLink("Chest PA and Lateral", "Chest PA and Lateral", 0, chestXRayLinks, True)
    documentLink("Chest  1 View", "Chest  1 View", 0, chestXRayLinks, True)
    #Labs
    #1
    dvValue(dvSerumBicarbonate, "HCO3: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumBicarbonate1, 2, labs, True)
    dvValue(dvSerumBicarbonate, "HCO3: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumBicarbonate2, 3, labs, True)
    #4
    #Meds
    medValue("Bronchodilator", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, meds, True)
    abstractValue("BRONCHODILATOR", "Bronchodilator '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2, meds, True)
    medValue("Dexamethasone", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 3, meds, True)
    abstractValue("DEXAMETHASONE", "Dexamethasone '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4, meds, True)
    medValue("Inhaled Corticosteroid", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 5, meds, True)
    abstractValue("INHALED_CORTICOSTEROID", "Inhaled Corticosteroid '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6, meds, True)
    medValue("Methylprednisolone", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 7, meds, True)
    abstractValue("METHYLPREDNISOLONE", "Methylprednisolone '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, meds, True)
    medValue("Respiratory Treatment Medication", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 9, meds, True)
    abstractValue("RESPIRATORY_TREATMENT_MEDICATION", "Respiratory Treatment Medication '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10, meds, True)
    medValue("Steroid", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 11, meds, True)
    abstractValue("STEROIDS", "Steroid '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12, meds, True)
    medValue("Vasodilator", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 13, meds, True)
    abstractValue("VASODILATOR", "Vasodilator '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 14, meds, True)
    #Oxygen
    if baselineAbs is not None: oxygen.Links.Add(baselineAbs) #1
    if ecmoCodes is not None: oxygen.Links.Add(ecmoCodes) #2
    if z9981Code is not None: oxygen.Links.Add(z9981Code) #3
    if z9911Code is not None: oxygen.Links.Add(z9911Code) #4
    if pao2Calc is None:
        dvValue(dvFIO2, "Fi02: [VALUE] (Result Date: [RESULTDATETIME])", calcFIO21, 5, oxygen, True)
    if highFlowNasalCodes is not None: oxygen.Links.Add(highFlowNasalCodes) #6
    if intubationCode is not None: oxygen.Links.Add(intubationCode) #7
    if invasiveMechVentCodes is not None: oxygen.Links.Add(invasiveMechVentCodes) #8
    if nasalCannulaCode is not None: oxygen.Links.Add(nasalCannulaCode) #9
    if nonInvasiveMechVentCodes is not None: oxygen.Links.Add(nonInvasiveMechVentCodes) #10
    dvValue(dvOxygenFlowRate, "Oxygen Flow Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcOxygenFlowRate1, 11, oxygen, True)
    if oxygenTherapyDV is not None: oxygen.Links.Add(oxygenTherapyDV) #12
    if oxygenTherapyAbs is not None: oxygen.Links.Add(oxygenTherapyAbs) #13
    if z930Code is not None: oxygen.Links.Add(z930Code) #14
    #Vitals
    dvValue(dvGlasgowComaScale, "Glasgow Coma Score: [VALUE] (Result Date: [RESULTDATETIME])", calcGlasgowComaScale1, 1, vitals, True)
    dvValue(dvHeartRate, "Heart Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcHeartRate1, 2, vitals, True)
    #3-7
    #Vitals Sub Categories
    if lowPulseOximetryDV is not None:
        for entry in lowPulseOximetryDV:
            spo2.Links.Add(entry)
    #ABG
    arterialBloodPHDV = None
    arterialBloodPHDV = dvValue(dvArterialBloodPH, "PH: [VALUE] (Result Date: [RESULTDATETIME])", calcArterialBloodPH1, 1)
    if arterialBloodPHDV is not None: abg.Links.Add(arterialBloodPHDV)
    elif arterialBloodPHDV is None:
        dvValue(dvArterialBloodPH, "PH: [VALUE] (Result Date: [RESULTDATETIME])", calcArterialBloodPH2, 2, abg, True)
    if venousBloodDV is not None: abg.Links.Add(venousBloodDV) #3
    
    #ABG Subheadings
    if highArterialBloodC02DV is not None:
        for entry in highArterialBloodC02DV:
            pC02.Links.Add(entry)
        if pC02.Links: abg.Links.Add(pC02)
    if pA0280DV is not None: 
        for entry in pA0280DV:
            paO2.Links.Add(entry)
        if paO2.Links: abg.Links.Add(paO2)
    #Calculated Ratio
    if pao2Calc is not None:
        for entry in pao2Calc:
            if entry.Sequence == 8:
                calcpo2fio2.Links.Add(MatchedCriteriaLink("Verify the Calculated PF ratio, as it's generated by a computer calculation and requires verification.", None, None, None, True, None, None, 1))
                calcpo2fio2.Links.Add(entry)
            elif entry.Sequence == 2:
                abg.Links.Add(entry)
        if pa02Fi02.Links: calcpo2fio2.Links.Add(pa02Fi02)
    elif sp02pao2Dvs is not None:
        for entry in sp02pao2Dvs:
            if entry.Sequence == 0:
                oxygenation.Links.Add(entry)
            if entry.Sequence == 2:
                paO2.Links.Add(entry)
            elif entry.Sequence == 1:
                spo22.Links.Add(entry)
            elif entry.Sequence == 3:
                oxygenTherapy.Links.Add(entry)
            elif entry.Sequence == 4:
                rr.Links.Add(entry)
        if paO2.Links: oxygenation.Links.Add(paO2)
        if spo22.Links: oxygenation.Links.Add(spo22)
        if oxygenTherapy.Links: oxygenation.Links.Add(oxygenTherapy)
        if rr.Links: oxygenation.Links.Add(rr)

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if spo2.Links: vitals.Links.Add(spo2); vitalsLinks = True
    if abg.Links: labs.Links.Add(abg); abgLinks = True
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if calcpo2fio2.Links: result.Links.Add(calcpo2fio2); calcpo2fio2Links = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    if vitals.Links: result.Links.Add(vitals); vitalsLinks = True
    if oxygen.Links: result.Links.Add(oxygen); oxygenLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    if chestXRayLinks.Links: result.Links.Add(chestXRayLinks); docLinksLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Documented Dx- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks) + ", vitals- " + str(vitalsLinks) + ", meds- " + str(medsLinks) + ", oxygen- " + str(oxygenLinks) + ", abg- "
        + str(abgLinks) + ", calcp02Fio2- " + str(calcpo2fio2Links) + ", docs- " + str(docLinksLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
