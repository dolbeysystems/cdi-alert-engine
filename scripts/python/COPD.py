##################################################################################################################
#Evaluation Script - COPD
#
#This script checks an account to see if it matches criteria to be alerted for COPD
#Date - 10/24/2024
#Version - V31
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

# ========================================
#   Script Specific Constants
# ========================================
codeDic = {}
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
dvMRSASCreen = ["MRSA DNA"]
dvSARSCOVID = ["SARS-CoV2 (COVID-19)"]
dvSARSCOVIDAntigen = [""]
dvPneumococcalAntigen = [""]
dvInfluenzeScreenA = ["Influenza A"]
dvInfluenzeScreenB = ["Influenza B"]
dvBreathSounds = [""]
dvOxygenFlowRate = ["Resp O2 Delivery Flow Num"]
dvOxygenTherapy = ["DELIVERY"]
dvRespiratoryPattern = [""]

dvFIO2 = ["FI02"]
dvHeartRate = ["Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)", "3.5 Heart Rate (Radial) (bpm)",  "SCC Monitor Pulse (bpm)"]
calcHeartRate1 = lambda x: x > 90
dvOxygenFlowRate = ["Oxygen Flow Rate (L/min)"]
calcOxygenFlowRate1 = lambda x: x > 2
dvPaO2 = ["BLD GAS O2 (mmHg)", "PO2 (mmHg)"]
calcPAO21 = lambda x: x < 60
dvPa02Fi02 = ["PO2/FiO2 (mmHg)"]
calcPa02Fi021 = 300
dvPAOP = [""]
calcPAOP1 = lambda x: x > 18
dvPleuralFluidCulture = [""]
dvRespiratoryRate = ["3.5 Respiratory Rate (#VS I&O) (per Minute)"]
calcRespiratoryRate1 = lambda x: x > 20
dvSPO2 = ["Pulse Oximetry(Num) (%)"]
calcSPO21 = lambda x: x < 90
dvSputumCulture = [""]

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
def dvmrsaCheck(dvDic, discreteValueCategory, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    abstraction = None
    for dv in dvDic or []:
        if (
            dvDic[dv]['Category'] in discreteValueCategory and
            dvDic[dv]['Name'] in discreteValueName and
            dvDic[dv]['Result'] is not None and
            (re.search(r'\bpositive\b', dvDic[dv]['Result'], re.IGNORECASE) is not None or
            re.search(r'\bDetected\b', dvDic[dv]['Result'], re.IGNORECASE) is not None)     
        ):
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, True)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, False)
                return abstraction
    return abstraction

def dvBloodCheck(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    abstraction = None
    for dv in dvDic or []:
        if (
            dvDic[dv]['Category'] in discreteValueName and
            dvDic[dv]['Result'] is not None and
            (re.search(r'\bpositive\b', dvDic[dv]['Result'], re.IGNORECASE) is not None or
            re.search(r'\bDetected\b', dvDic[dv]['Result'], re.IGNORECASE) is not None)  
        ):
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, True)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, False)
                return abstraction
    return abstraction

def dvPositiveCheck(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    abstraction = None
    for dv in dvDic or []:
        if (
            dvDic[dv]['Name'] in discreteValueName and
            dvDic[dv]['Result'] is not None and
            (re.search(r'\bpositive\b', dvDic[dv]['Result'], re.IGNORECASE) is not None or
            re.search(r'\bDetected\b', dvDic[dv]['Result'], re.IGNORECASE) is not None)  
        ):
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, True)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, False)
                return abstraction
    return abstraction

def dvOxygenCheck(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    abstraction = None
    for dv in dvDic or []:
        if (
            dvDic[dv]['Category'] in discreteValueName and
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

def dvBreathCheck(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    abstraction = None
    for dv in dvDic or []:
        if (
            dvDic[dv]['Name'] in discreteValueName and
            dvDic[dv]['Result'] is not None and
            not re.search(r'\bClear\b', dvDic[dv]['Result'], re.IGNORECASE)
        ):
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, True)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, False)
                return abstraction
    return abstraction

def dvRespPatCheck(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    abstraction = None
    for dv in dvDic or []:
        if (
            dvDic[dv]['Name'] in discreteValueName and
            dvDic[dv]['Result'] is not None and
            not re.search(r'\bRegular\b', dvDic[dv]['Result'], re.IGNORECASE)
        ):
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, True)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, False)
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
    dateNow = System.DateTime.Now
    date_time = dateNow.ToString("MM/dd/yyyy, HH:mm")
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

    #Determine percentage based on oxygen therapy (dv5/discreteDic4) and oxygen flow rate(dv4/discreteDic3)
    if z > 0 and a > 0 and b == 0:
        if discreteDic3[z].ResultDate == discreteDic4[a].ResultDate:
            percentage = fio2Percentage(cleanNumbers(discreteDic3[z].Result), discreteDic4[a].Result)
            if percentage == 'Invalid':
                return None

    #Determine ratio from PaO2 attempted first or SpO2 values will be converted to PaO2.
    if y >= 1 and percentage is None and b > 0:
        for item in discreteDic2:
            if y == 0 or b == 0:
                break
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
                    matchedList.append(dataConversion(None, date_time + " Respiratory Rate: " + str(respRateDV) + ", Pa02: " + str(discreteDic2[y].Result) + ", FIO2: " + str(discreteDic5[b].Result) + ", Calculated/Estimated PF Ratio- [VALUE]" , str(round(calculation)), discreteDic2[y].UniqueId or discreteDic2[y]._id, calcpo2fio2, 8, False))
                    return matchedList
                elif float(calculation) > float(300):
                    y = y - 1; b = b - 1
    elif x >= 1 and percentage is None and b > 0:
        for item in discreteDic1:
            if x == 0 or b == 0:
                break
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
                    matchedList.append(dataConversion(None, date_time + " Respiratory Rate: " + str(respRateDV) + ", Sp02: " + str(discreteDic1[x].Result) + ", FIO2: " + str(discreteDic5[b].Result) + ", Calculated/Estimated PF Ratio- [VALUE]" , str(round(calculation)), discreteDic1[x].UniqueId or discreteDic1[x]._id, calcpo2fio2, 8, False))
                    return matchedList
                elif float(calculation) > float(300):
                    x = x - 1; b = b - 1
    elif y >= 1 and percentage is not None and percentage > 0 and b == 0:
        for item in discreteDic2:
            if x == 0:
                break
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
                matchedList.append(dataConversion(None, date_time + " Respiratory Rate: " + str(respRateDV) + ", Pa02: " + str(discreteDic2[y].Result) + ", Oxygen Flow Rate: " + str(discreteDic3[z].Result) + ", Oxygen Therapy: " + str(discreteDic4[a].Result) + ", Calculated/Estimated PF Ratio- [VALUE]" , str(round(calculation)), discreteDic2[y].UniqueId or discreteDic2[y]._id, calcpo2fio2, 8, False))
                return matchedList
            elif float(calculation) > float(300):
                y = y - 1
    elif x >= 1 and percentage is not None and percentage > 0 and b == 0:
        for item in discreteDic1:
            if x == 0:
                break
            pO2Converted = pO2Conversion(cleanNumbers(discreteDic1[x].Result))
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
                    matchedList.append(dataConversion(None, date_time + " Respiratory Rate: " + str(respRateDV) + ", Sp02: " + str(discreteDic1[x].Result) + ", Oxygen Flow Rate: " + str(discreteDic3[z].Result) + ", Oxygen Therapy: " + str(discreteDic4[a].Result) + ", Calculated/Estimated PF Ratio- [VALUE]" , str(round(calculation)), discreteDic1[x].UniqueId or discreteDic1[x]._id, calcpo2fio2, 8, False))
                    return matchedList
                elif float(calculation) > float(300):
                    x = x - 1
    else:
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
subtitle = None
outcome = None
EC = 0; RTMA = 0; SLO = 0; SRD = 0; ODC = 0
dcLinks = False
absLinks = False
oxygenLinks = False
vitalsLinks = False
medsLinks = False
calcpo2fio2Links = False
labsLinks = False
docLinksLinks = False

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
vitals = MatchedCriteriaLink("Vital Signs/Intake and Output Data", None, "Vital Signs/Intake and Output Data", None, True, None, None, 2)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 3)
oxygen = MatchedCriteriaLink("Oxygenation/Ventilation", None, "Oxygenation/Ventilation", None, True, None, None, 4)
meds = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 5)
calcpo2fio2 = MatchedCriteriaLink("Calculated P02/Fi02 Ratio", None, "Calculated P02/Fi02 Ratio", None, True, None, None, 6)
oxygenation = MatchedCriteriaLink("O2 Indicators", None, "O2 Indicators", None, True, None, None, 7)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 8)
chestXRayLinks = MatchedCriteriaLink("Chest X-Ray", None, "Chest X-Ray", None, True, None, None, 9)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 10)
spo2 = MatchedCriteriaLink("Sp02", None, "Sp02", None, True, None, None, 89)
pa02Fi02 = MatchedCriteriaLink("Pa02Fi02", None, "Pa02Fi02", None, True, None, None, 90)
spo22 = MatchedCriteriaLink("Sp02", None, "Sp02", None, True, None, None, 91)
paO2 = MatchedCriteriaLink("Pa02", None, "Pa02", None, True, None, None, 92)
fio2 = MatchedCriteriaLink("FI02", None, "FI02", None, True, None, None, 93)
rr = MatchedCriteriaLink("Respiratory Rate", None, "Respiratory Rate", None, True, None, None, 94)
oxygenFlowRate = MatchedCriteriaLink("Oxygen Flow Rate", None, "Oxygen Flow Rate", None, True, None, None, 95)
oxygenTherapy = MatchedCriteriaLink("Oxygen Therapy", None, "Oxygen Therapy", None, True, None, None, 96)

#Linktext for lacking messages
LinkText1 = "Possible Missing Signs of Low Oxygen"
LinkText2 = "Possible Missing Signs of Respiratory Distress"
LinkText3 = "Possible Missing COPD Exacerbation Treatment Medication"
message1 = False; message2 = False; message3 = False

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'COPD':
        alertTriggered = True
        validated = alert.IsValidated
        subtitle = alert.Subtitle
        outcome = alert.Outcome
        for alertLink in alert.Links:
            if alertLink.LinkText == 'Vital Signs/Intake and Output Data':
                for links in alertLink.Links:
                    if links.LinkText == LinkText1:
                        message1 = True
            if alertLink.LinkText == 'Medication(s)':
                for links in alertLink.Links:
                    if links.LinkText == LinkText3:
                        message3 = True
            if alertLink.LinkText == 'Clinical Evidence':
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
    discreteSearchList = [i for j in [dvPa02Fi02, dvSPO2, dvPaO2, dvOxygenFlowRate, dvOxygenTherapy, dvFIO2, 
        dvRespiratoryPattern, dvBreathSounds, dvSARSCOVID, dvSARSCOVIDAntigen, dvPneumococcalAntigen, 
        dvInfluenzeScreenA, dvInfluenzeScreenB, dvMRSASCreen, dvRespiratoryRate, dvPleuralFluidCulture, dvSputumCulture] for i in j]
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
    opioidOverdoseAbs = abstractValue("OPIOID_OVERDOSE", "Opioid Overdose '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    HeartFailureCodeCheck = multiCodeValue(["I50.21", "I50.23", "I50.31",
        "I50.33", "I50.41", "I50.43"], "Acute Heart Failure Codes present : [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j440Code = codeValue("J44.0", "Chronic Obstructive Pulmonary Disease With (Acute) Lower Respiratory Infection: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j441Code = codeValue("J44.1", "Chronic Obstructive Pulmonary Disease With (Acute) Exacerbation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pulmonaryEmbolismNeg =  prefixCodeValue("^I26\.", "Pulmonary Embolism: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j810Code = codeValue("J81.0", "Acute Pulmonary Edema: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    sepsis40Neg =  prefixCodeValue("^A40\.", "Sepsis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    sepsis41Neg =  prefixCodeValue("^A41\.", "Sepsis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    sepsisNeg = multiCodeValue(["A42.7", "A22.7", "B37.7", "A26.7", "A54.86", "B00.7", "A32.7", "A24.1", "A20.7", "T81.44XA", "T81.44XD"],
            "Sepsis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    f410Code = codeValue("F41.0", "Panic Attack: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pneumonthroaxNeg =  prefixCodeValue("^J93\.", "Pneumothroax: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    acuteMINeg =  prefixCodeValue("^I21\.", "Acute MI: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    copdWithoutExacerbationAbs = abstractValue("COPD_WITHOUT_EXACERBATION", "COPD without Exacerbation abstraction '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    #Documented Dx
    RespiratoryCodeCheck = multiCodeValue(["J96.00", "J96.01", "J96.02"], "Acute Respiratory Failure Codes present : [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j449Code = codeValue("J44.9", "Chronic Obstructive Pulmonary Disease, Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j20Codes =  prefixCodeValue("^J20\.", "Acute Bronchitis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j22Codes =  prefixCodeValue("^J22\.", "Unspecified Acute Lower Respiratory Infection: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pneumoniaJ12 =  prefixCodeValue("^J12\.", "Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pneumoniaJ13 =  prefixCodeValue("^J13\.", "Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pneumoniaJ14 =  prefixCodeValue("^J14\.", "Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pneumoniaJ15 =  prefixCodeValue("^J15\.", "Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pneumoniaJ16 =  prefixCodeValue("^J16\.", "Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pneumoniaJ17 =  prefixCodeValue("^J17\.", "Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pneumoniaJ18 =  prefixCodeValue("^J18\.", "Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    respiratoryTuberculosis =  prefixCodeValue("^A15\.", "Respiratory Tuberculosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j21Codes =  prefixCodeValue("^J21\.", "Acute Bronchitis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Abs
    r0603Code = codeValue("R06.03", "Acute Respiratory Distress: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    j9801Code = codeValue("J98.01", "Bronchospasm: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5)
    shortnessOfBreathAbs = abstractValue("SHORTNESS_OF_BREATH", "Shortness of Breath '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 15)
    useOfAccessoryMusclesAbs = abstractValue("USE_OF_ACCESSORY_MUSCLES", "Use of Accessory Muscles '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 16)
    wheezingAbs = abstractValue("WHEEZING", "Wheezing '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 17)
    #Meds
    bronchodilatorMed = medValue("Bronchodilator", "Bronchodilator: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 3)
    inhaledCorticosteriodMed = medValue("Inhaled Corticosteroid", "Inhaled Corticosteroid: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 5)
    inhaledCorticosteriodTreatmeantsAbs = abstractValue("INHALED_CORTICOSTERIOD_TREATMENTS", "Inhaled Corticosteriod Treatmeants '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6)
    respiratoryTreatmentMedicationMed = medValue("Respiratory Treatment Medication", "Respiratory Treatment Medication: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 8)
    respiratoryTreatmentMedicationAbs = abstractValue("RESPIRATORY_TREATMENT_MEDICATION", "Respiratory Treatment Medication '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9)
    #Oxygen
    highFlowNasalCodes = multiCodeValue(["5A0935A", "5A0945A", "5A0955A"], "High Flow Nasal Oxygen: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    invasiveMechVentCodes = multiCodeValue(["5A1935Z", "5A1945Z", "5A1955Z"], "Invasive Mechanical Ventilation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3)
    nonInvasiveVentAbs = abstractValue("NON_INVASIVE_VENTILATION", "Non-Invasive Ventilation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4)
    oxygenFlowRateDV = dvValue(dvOxygenFlowRate, "Oxygen Flow Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcOxygenFlowRate1, 6)
    oxygenTherapyAbs = abstractValue("OXYGEN_THERAPY", "Oxygen Therapy '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8)
    #Vitals
    r0902Code = codeValue("R09.02", "Hypoxemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    lowPaO2DV = dvValue(dvPaO2, "pa02: [VALUE] (Result Date: [RESULTDATETIME])", calcPAO21, 3)
    lowPulseOximetryDV = dvValue(dvSPO2, "Sp02: [VALUE] (Result Date: [RESULTDATETIME])", calcSPO21, 4)
    highRespiratoryRateDV = dvValue(dvRespiratoryRate, "Respiratory Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcRespiratoryRate1, 5)
    #Calculated Po2/Fio2
    z9981Code = codeValue("Z99.81", "Dependence On Supplemental Oxygen: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pao2Calc = None
    sp02pao2Dvs = None
    if z9981Code is None:
        pao2Calc = pao2fio2Calculation(dict(maindiscreteDic), dvPa02Fi02, dvSPO2, dvPaO2, dvOxygenFlowRate, dvOxygenTherapy, dvFIO2, dvRespiratoryRate, calcPa02Fi021, 2)
    if pao2Calc is None:
        sp02pao2Dvs = sp02pa02Lookup(dict(maindiscreteDic), dvSPO2, dvPaO2, dvOxygenTherapy, dvRespiratoryRate)

    #Copd Exacerbation Treatment Medication
    if respiratoryTreatmentMedicationAbs is not None: meds.Links.Add(respiratoryTreatmentMedicationAbs); RTMA += 1
    if inhaledCorticosteriodTreatmeantsAbs is not None: RTMA += 1
    if respiratoryTreatmentMedicationMed is not None: RTMA += 1
    if bronchodilatorMed is not None: RTMA += 1
    if inhaledCorticosteriodMed is not None: RTMA += 1
    #Signs of Low Oxygen
    if pao2Calc is not None: SLO += 1
    if lowPaO2DV is not None: labs.Links.Add(lowPaO2DV); SLO += 1
    if r0902Code is not None: vitals.Links.Add(r0902Code); SLO += 1
    if lowPulseOximetryDV is not None: vitals.Links.Add(lowPulseOximetryDV); SLO += 1
    #Signs of Resp Distress
    if wheezingAbs is not None: abs.Links.Add(wheezingAbs); SRD += 1
    if useOfAccessoryMusclesAbs is not None: abs.Links.Add(useOfAccessoryMusclesAbs); SRD += 1
    if shortnessOfBreathAbs is not None: abs.Links.Add(shortnessOfBreathAbs); SRD += 1
    if r0603Code is not None: abs.Links.Add(r0603Code); SRD += 1
    if highRespiratoryRateDV is not None: vitals.Links.Add(highRespiratoryRateDV); SRD += 1
    if j9801Code is not None: abs.Links.Add(j9801Code); SRD += 1
    #Oxygen Delievery Check
    if highFlowNasalCodes is not None: ODC += 1
    if invasiveMechVentCodes is not None: ODC += 1
    if nonInvasiveVentAbs is not None: ODC += 1
    if oxygenFlowRateDV is not None: ODC += 1
    if oxygenTherapyAbs is not None: ODC += 1
    
    db.LogEvaluationScriptMessage("Clinical Counts: RTMA " + str(RTMA) + ", SLO " + str(SLO) + ", SRD " + str(SRD) + ", ODC " + str(ODC) + " " + str(account._id), scriptName, scriptInstance, "Debug")

    #Starting Main Algorithm
    if subtitle == "Possible Chronic Obstructive Pulmonary Disease with Acute Lower Respiratory Infection" and j440Code is not None:
        if j440Code is not None: updateLinkText(j440Code, autoCodeText); dc.Links.Add(j440Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
        
    elif (
        j449Code is not None and
        (j20Codes is not None or
        j22Codes is not None or
        pneumoniaJ12 is not None or
        pneumoniaJ13 is not None or
        pneumoniaJ14 is not None or
        pneumoniaJ15 is not None or
        pneumoniaJ16 is not None or
        pneumoniaJ17 is not None or
        pneumoniaJ18 is not None or 
        j21Codes is not None) and
        j440Code is None
        ):
        result.Subtitle = "Possible Chronic Obstructive Pulmonary Disease with Acute Lower Respiratory Infection"
        AlertPassed = True
        dc.Links.Add(j449Code)
        if j20Codes is not None: dc.Links.Add(j20Codes)
        if j22Codes is not None: dc.Links.Add(j22Codes)
        if j21Codes is not None: dc.Links.Add(j21Codes)
        if pneumoniaJ12 is not None: dc.Links.Add(pneumoniaJ12)
        if pneumoniaJ13 is not None: dc.Links.Add(pneumoniaJ13)
        if pneumoniaJ14 is not None: dc.Links.Add(pneumoniaJ14)
        if pneumoniaJ15 is not None: dc.Links.Add(pneumoniaJ15)
        if pneumoniaJ16 is not None: dc.Links.Add(pneumoniaJ16)
        if pneumoniaJ17 is not None: dc.Links.Add(pneumoniaJ17)
        if pneumoniaJ18 is not None: dc.Links.Add(pneumoniaJ18)
        if respiratoryTuberculosis is not None: dc.Links.Add(respiratoryTuberculosis)
    
    elif subtitle == "Possible Chronic Obstructive Pulmonary Disease with Acute Exacerbation" and j441Code is not None:
        if j441Code is not None: updateLinkText(j441Code, autoCodeText); dc.Links.Add(j441Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    
    elif (
        j449Code is not None and
        RespiratoryCodeCheck is not None and
        opioidOverdoseAbs is None and
        j441Code is None and
        pulmonaryEmbolismNeg is None and
        j810Code is None and
        sepsis40Neg is None and
        sepsis41Neg is None and
        sepsisNeg is None and
        f410Code is None and
        pneumonthroaxNeg is None and
        HeartFailureCodeCheck is None and
        acuteMINeg is None and
        copdWithoutExacerbationAbs is None and
        (bronchodilatorMed is not None or
        respiratoryTreatmentMedicationMed is not None or
        respiratoryTreatmentMedicationAbs is not None or
        inhaledCorticosteriodMed is not None or
        inhaledCorticosteriodTreatmeantsAbs is not None)
        ):
        result.Subtitle = "Possible Chronic Obstructive Pulmonary Disease with Acute Exacerbation"
        AlertPassed = True
        dc.Links.Add(j449Code)
        dc.Links.Add(RespiratoryCodeCheck)    
    
    elif (
        j449Code is not None and
        SLO > 0 and
        SRD > 0 and
        RTMA > 0 and
        ODC > 0 and
        opioidOverdoseAbs is None and
        pulmonaryEmbolismNeg is None and
        j810Code is None and
        sepsis40Neg is None and
        sepsis41Neg is None and
        sepsisNeg is None and
        f410Code is None and
        pneumonthroaxNeg is None and
        HeartFailureCodeCheck is None and
        acuteMINeg is None and
        copdWithoutExacerbationAbs is None and
        j441Code is None
    ):
        result.Subtitle = "Possible Chronic Obstructive Pulmonary Disease with Acute Exacerbation"
        AlertPassed = True
        dc.Links.Add(j449Code)
        
    elif subtitle == "COPD with Acute Exacerbation Possibly Lacking Supporting Evidence" and SLO > 0 and SRD > 0 and RTMA > 0:
        if message1 and SLO > 0:
            vitals.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, False))
        if message2 and SRD > 0:
            abs.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None, False))
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to clinical evidence now existing on the Account"
        result.Validated = True
        AlertPassed = True
        
    elif (
        j441Code is not None and
        SLO == 0 and
        SRD == 0 and
        RTMA > 0
    ):
        if SLO < 1: vitals.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None))
        elif message1 and SLO > 0:
            vitals.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, False))
        if SRD < 1: abs.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None))
        elif message2 and SRD > 0:
            abs.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None, False))
        result.Subtitle = "COPD with Acute Exacerbation Possibly Lacking Supporting Evidence"
        AlertPassed = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Abs
    abstractValue("ABNORMAL_SPUTUM", "Abnormal Sputum '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1, abs, True)
    #2
    dvBreathCheck(dict(maindiscreteDic), dvBreathSounds, "Breath Sounds '[VALUE]' (Result Date: [RESULTDATETIME])", 3, abs, True)
    multiCodeValue(["J96.01", "J96.2", "J96.21", "J96.22"], "Acute Respiratory Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, abs, True)
    if j9801Code is not None: abs.Links.Add(j9801Code) #5
    abstractValue("BRONCHOSPASM", "Bronchospasm '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, abs, True)
    codeValue("R05.9", "Cough: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, abs, True)
    codeValue("U07.1", "Covid-19: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, abs, True)
    codeValue("R53.83", "Fatigue: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8, abs, True)
    abstractValue("LOW_FORCED_EXPIRATORY_VOLUME_1", "Low Forced Expiratory Volume 1 '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, abs, True)
    abstractValue("BACTERIAL_PNEUMONIA_ORGANISM", "Possible Bacterial Pneumonia Organism '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10, abs, True)
    abstractValue("FUNGAL_PNEUMONIA_ORGANISM", "Possible Fungal Pneumonia Organism '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11, abs, True)
    abstractValue("VIRAL_PNEUMONIA_ORGANISM", "Possible Viral Pneumonia Organism '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12, abs, True)
    dvRespPatCheck(dict(maindiscreteDic), dvRespiratoryPattern, "Respiratory Pattern '[VALUE]' (Result Date: [RESULTDATETIME])", 13, abs, True)
    #14-17
    #Document Links
    documentLink("Chest  3 View", "Chest  3 View", 0, chestXRayLinks, True)
    documentLink("Chest  PA and Lateral", "Chest  PA and Lateral", 0, chestXRayLinks, True)
    documentLink("Chest  Portable", "Chest  Portable", 0, chestXRayLinks, True)
    documentLink("Chest PA and Lateral", "Chest PA and Lateral", 0, chestXRayLinks, True)
    documentLink("Chest  1 View", "Chest  1 View", 0, chestXRayLinks, True)
    #Labs
    dvPositiveCheck(dict(maindiscreteDic), dvSARSCOVID, "Covid 19 Screen: '[VALUE]' (Result Date: [RESULTDATETIME])", 2, labs, True)
    dvPositiveCheck(dict(maindiscreteDic), dvSARSCOVIDAntigen, "Covid 19 Screen: '[VALUE]' (Result Date: [RESULTDATETIME])", 3, labs, True)
    dvBloodCheck(dict(maindiscreteDic), dvInfluenzeScreenA, "Influenza A Screen: '[VALUE]' (Result Date: [RESULTDATETIME])", 4, labs, True)
    dvBloodCheck(dict(maindiscreteDic), dvInfluenzeScreenB, "Influenza B Screen: '[VALUE]' (Result Date: [RESULTDATETIME])", 5, labs, True)
    dvmrsaCheck(dict(maindiscreteDic), dvMRSASCreen, "Final Report", "MRSA Screen: '[VALUE]' (Result Date: [RESULTDATETIME])", 6, labs, True)
    dvPositiveCheck(dict(maindiscreteDic), dvPleuralFluidCulture, "Positive Pleural Fluid Culture: '[VALUE]' (Result Date: [RESULTDATETIME])", 7)
    abstractValue("POSITIVE_SPUTUM_CULTURE", "Positive Sputum Culture '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, labs, True)
    dvPositiveCheck(dict(maindiscreteDic), dvPneumococcalAntigen, "Strept Pneumonia Screen: '[VALUE]' (Result Date: [RESULTDATETIME])", 9, labs, True)
    #Meds
    medValue("Antibiotic", "Antibiotic: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, meds, True)
    abstractValue("ANTIBIOTIC", "Antibiotic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2, meds, True)
    if bronchodilatorMed is not None: meds.Links.Add(bronchodilatorMed) #3
    medValue("Dexamethasone", "Dexamethasone: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 4, meds, True)
    if inhaledCorticosteriodMed is not None: meds.Links.Add(inhaledCorticosteriodMed) #5
    if inhaledCorticosteriodTreatmeantsAbs is not None: meds.Links.Add(inhaledCorticosteriodTreatmeantsAbs) #6
    medValue("Methylprednisolone", "Methylprednisolone: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 7, meds, True)
    if respiratoryTreatmentMedicationAbs is not None: meds.Links.Add(respiratoryTreatmentMedicationAbs) #8
    if respiratoryTreatmentMedicationMed is not None: meds.Links.Add(respiratoryTreatmentMedicationMed) #9
    #10
    medValue("Steroid", "Steroid: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 11, meds, True)
    abstractValue("STEROIDS", "Steroid '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12, meds, True)
    medValue("Vasodilator", "Vasodilator: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 13, meds, True)
    #Oxygen
    codeValue("Z99.81", "Dependence On Supplemental Oxygen: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, oxygen, True)
    if z9981Code is not None: oxygen.Links.Add(z9981Code) #2
    if highFlowNasalCodes is not None: oxygen.Links.Add(highFlowNasalCodes) #3
    if invasiveMechVentCodes is not None: oxygen.Links.Add(invasiveMechVentCodes) #4
    if nonInvasiveVentAbs is not None: oxygen.Links.Add(nonInvasiveVentAbs) #5
    if oxygenFlowRateDV is not None: oxygen.Links.Add(oxygenFlowRateDV) #6
    dvOxygenCheck(dict(maindiscreteDic), dvOxygenTherapy, "Oxygen Therapy '[VALUE]' (Result Date: [RESULTDATETIME])", 7, oxygen, True)
    if oxygenTherapyAbs is not None: oxygen.Links.Add(oxygenTherapyAbs) #8
    #Vitals
    dvValue(dvHeartRate, "HR: [VALUE] (Result Date: [RESULTDATETIME])", calcHeartRate1, 1, vitals, True)
    #2-5
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
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if oxygen.Links: result.Links.Add(oxygen); oxygenLinks = True
    if vitals.Links: result.Links.Add(vitals); vitalsLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    if calcpo2fio2.Links: result.Links.Add(calcpo2fio2); calcpo2fio2Links = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    if chestXRayLinks.Links: result.Links.Add(chestXRayLinks); docLinksLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Documentation Includes- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks) + ", vitals- " + str(vitalsLinks) +
        ", meds- " + str(medsLinks) + ", oxygen- " + str(oxygenLinks) + ", docs- " + str(docLinksLinks) + ", calcp02Fio2- " + str(calcpo2fio2Links) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
