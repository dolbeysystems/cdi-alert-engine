##################################################################################################################
#Evaluation Script - Encephalopathy
#
#This script checks an account to see if it matches criteria to be alerted for Encephalopathy
#Date - 11/19/2024
#Version - V26
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
    "E51.2": "Wernicke's Encephalopathy",
    "G31.2": "Alcoholic Encephalopathy",
    "G92.8": "Other Toxic Encephalopathy",
    "G93.41": "Metabolic Encephalopathy",
    "I67.4": "Hypertensive Encephalopathy",
    "G92.9" : "Unspecified toxic encephalopathy",
    "G32.89" : "Degenerative Encephalopathy in Diseases Classified Elsewhere",
    "J11.81" : "Influenzal Encephalopathy",
    "F07.81" : "Postconcussional Encephalopathy",
    "E51.2" : "Wernickes Encephalopathy",
    "G93.49" : "Other Encephalopathy",
    "K76.82" : "Hepatic Encephalopathy",
    "G04.30" : "Acute necrotizing hemorrhagic encephalopathy",
    "G04.31" : "Postinfectious acute necrotizing hemorrhagic encephalopathy",
    "G04.32" : "Postimmunization acute necrotizing hemorrhagic encephalopathy",
    "G04.39" : "Other acute necrotizing hemorrhagic encephalopathy"
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
dvAlkalinePhos = ["ALKALINE PHOS", "ALK PHOS TOTAL (U/L)"]
calcAlkalinePhos1 = lambda x: x > 149
dvArterialBloodPH = ["pH"]
calcArterialBloodPH1 = 7.30
dvBilirubinTotal = ["TOTAL BILIRUBIN (mg/dL)"]
calcBilirubinTotal1 = lambda x: x > 1.2
dvBloodGlucose = ["GLUCOSE (mg/dL)", "GLUCOSE"]
calcBloodGlucose1 = 200
calcBloodGlucose2 = 50
dvBloodGlucosePOC = ["GLUCOSE ACCUCHECK (mg/dL)"]
calcBloodGlucosePOC1 = 200
calcBloodGlucosePOC2 = 50
dvDBP = ["BP Arterial Diastolic cc (mm Hg)", "DBP 3.5 (No Calculation) (mmhg)", "DBP 3.5 (No Calculation) (mm Hg)"]
calcDBP1 = lambda x: x > 110
dvEthanolLevel = ["ALCOHOL,ETHYL UR"]
calcEthanolLevel1 = lambda x: x > 0.2
dvGlasgowComaScale = ["3.5 Neuro Glasgow Score"]
calcGlasgowComaScale1 = 14
calcGlasgowComaScale2 = 12
dvPaO2 = ["BLD GAS O2 (mmHg)", "PO2 (mmHg)"]
calcPAO21 = 80
dvPC02 = ["BLD GAS CO2 (mmHg)", "PaCO2 (mmHg)"]
calcPC021 = 46
dvSBP = ["SBP 3.5 (No Calculation) (mm Hg)"]
calcSBP1 = lambda x: x > 180
dvSerumAmmonia = [""]
calcSerumAmmonia1 = 71
dvSerumBloodUreaNitrogen = ["BUN (mg/dL)"]
calcSerumBloodUreaNitrogen1 = 20
dvSerumCalcium = ["CALCIUM (mg/dL)"]
calcSerumCalcium1 = 10.2
calcSerumCalcium2 = 8.3
dvSerumCreatinine = ["CREATININE (mg/dL)", "CREATININE SERUM (mg/dL)"]
calcSerumCreatinine1 = 1.2
dvSerumSodium = ["SODIUM (mmol/L)"]
calcSerumSodium1 = 148
calcSerumSodium2 = 135
dvSPO2 = ["Pulse Oximetry(Num) (%)"]
calcSPO21 = lambda x: x < 90
dvTemperature = ["Temperature Degrees C 3.5 (degrees C)", "Temperature  Degrees C 3.5 (degrees C)", "TEMPERATURE (C)"]
calcTemperature1 = lambda x: x > 38.3
calcTemperature2 = lambda x: x < 36.0

dvAmphetamineScreen = ["AMP/METH UR", "AMPHETAMINE URINE"]
dvBarbiturateScreen = ["BARBITURATES URINE", "BARBS UR"]
dvBenzodiazepineScreen = ["BENZO URINE", "BENZO UR"]
dvBuprenorphineScreen = [""]
dvCBlood = [""]
dvCUrine = ["BACTERIA (/HPF)"]
dvCannabinoidScreen = ["CANNABINOIDS UR", "Cannabinoids (THC) UR"]
dvCocaineScreen = ["COCAINE URINE", "COCAINE UR CONF"]
dvFentanylScreen = ["FENTANYL URINE", "FENTANYL UR"]
dvMethadoneScreen = ["METHADONE URINE", "METHADONE UR"]
dvOpiateScreen = ["OPIATES URINE", "OPIATES UR"]
dvOxycodoneScreen = ["OXYCODONE UR", "OXYCODONE URINE"]

dvGlasgowEyeOpening = ["3.5 Neuro Glasgow Eyes (Adult)"]
dvGlasgowVerbal = ["3.5 Neuro Glasgow Verbal (Adult)"]
dvGlasgowMotor = ["3.5 Neuro Glasgow Motor"]
dvOxygenTherapy = ["O2 Device"]
dvUABacteria = ["UA Bacteria (/HPF)"]

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

def dvVentCheck(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    abstraction = None
    for dv in dvDic or []:
        if (
            dvDic[dv]['Name'] in discreteValueName and
            dvDic[dv]['Result'] is not None and
            (re.search(r'\bVent\b', dvDic[dv]['Result'], re.IGNORECASE) is not None or
            re.search(r'\bVentilator\b', dvDic[dv]['Result'], re.IGNORECASE) is not None)
        ):
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return abstraction
    return abstraction

def GlasgowLinkedValues(dvDic, DV1, DV2, DV3, DV4, DV5, value, consecutive):
    discreteDic = {}
    discreteDic1 = {}
    discreteDic2 = {}
    discreteDic3 = {}
    discreteDic4 = {}
    matchedList = []
    matchingDate = None
    matchingDate1 = None
    matchingDate2 = None
    a = 0; b = 0; c = 0; d = 0; e = 0; w = 0; x = 0; y = 0; z = 0
    for dv in dvDic or []:
        dvr = cleanNumbers(dvDic[dv]['Result'])
        if dvDic[dv]['Name'] in DV1 and dvr is not None: #Score
            a += 1
            discreteDic[a] = dvDic[dv]
        elif dvDic[dv]['Name'] in DV2 and dvDic[dv]['Result'] is not None: #Eye
            b += 1
            discreteDic1[b] = dvDic[dv]
        elif dvDic[dv]['Name'] in DV3 and dvDic[dv]['Result'] is not None: #Verbal
            c += 1
            discreteDic2[c] = dvDic[dv]
        elif dvDic[dv]['Name'] in DV4 and dvDic[dv]['Result'] is not None: #Motor
            d += 1
            discreteDic3[d] = dvDic[dv]
        elif (
            dvDic[dv]['Name'] in DV5 and dvDic[dv]['Result'] is not None and 
            (re.search(r'\bVent\b', dvDic[dv]['Result'], re.IGNORECASE) is not None or
            re.search(r'\bVentilator\b', dvDic[dv]['Result'], re.IGNORECASE) is not None or
            re.search(r'\bMechanical Ventilation\b', dvDic[dv]['Result'], re.IGNORECASE) is not None)
        ): #Oxygen Therapy
            e += 1
            discreteDic4[e] = dvDic[dv]
            
    db.LogEvaluationScriptMessage("Oxygen logging Score Count: " + str(a) + " " + ", Eye: " + str(b) + " " + ", Verbal: " + str(c) + " " + ", Motor: " + str(d) + " "  + ", Oxygen: " + str(e) + " " + str(account._id), scriptName, scriptInstance, "Debug")


    if consecutive:
        w = a - 1
        x = b - 1
        y = c - 1
        z = d - 1
        if a >= 1:
            for item in discreteDic:
                if (
                    a >= 1 and b >= 1 and c >= 1 and d >= 1 and w >= 1 and x >= 1 and y >= 1 and z >= 1 and
                    (discreteDic2[c].Result != 'Oriented' and float(cleanNumbers(discreteDic[a].Result)) <= float(value) and discreteDic[a].ResultDate == discreteDic1[b].ResultDate == discreteDic2[c].ResultDate == discreteDic3[d].ResultDate and twelveHourCheck(discreteDic[a].ResultDate, discreteDic4) is True) and
                    (discreteDic2[y].Result != 'Oriented' and float(cleanNumbers(discreteDic[w].Result)) <= float(value) and discreteDic[w].ResultDate == discreteDic1[x].ResultDate == discreteDic2[y].ResultDate == discreteDic3[z].ResultDate and twelveHourCheck(discreteDic[w].ResultDate, discreteDic4) is True)
                ):
                    db.LogEvaluationScriptMessage("Found glasgow match; oxygen therapy negation count " + str(e) + " " + str(account._id), scriptName, scriptInstance, "Debug")
                    matchingDate1 = datetimeFromUtcToLocal(discreteDic[a].ResultDate)
                    matchingDate1 = matchingDate1.ToString("MM/dd/yyyy, HH:mm")
                    matchingDate2 = datetimeFromUtcToLocal(discreteDic[w].ResultDate)
                    matchingDate2 = matchingDate2.ToString("MM/dd/yyyy, HH:mm")
                    matchedList.append(dataConversion(None, matchingDate1 + " Total GCS = " + str(discreteDic[a].Result) + " (Eye Opening: " + str(discreteDic1[b].Result) + ", Verbal Response: " + str(discreteDic2[c].Result) + ", Motor Response: " + str(discreteDic3[d].Result) + ")", None, discreteDic[a]._id, glasgow, 0, False))
                    matchedList.append(dataConversion(None, matchingDate2 + " Total GCS = " + str(discreteDic[w].Result) + " (Eye Opening: " + str(discreteDic1[x].Result) + ", Verbal Response: " + str(discreteDic2[y].Result) + ", Motor Response: " + str(discreteDic3[z].Result) + ")", None, discreteDic[w]._id, glasgow, 0, False))
                    return matchedList
                else:
                   a = a - 1; b = b - 1; c = c - 1; d = d - 1; w = w - 1; x = x - 1; y = y - 1; z = z - 1
        else:
            for item in discreteDic:
                if a >= 1 and b >= 1 and c >= 1 and d >= 1:
                    if discreteDic2[c].Result != 'Oriented' and float(cleanNumbers(discreteDic[a].Result)) <= float(value) and discreteDic[a].ResultDate == discreteDic1[b].ResultDate == discreteDic2[c].ResultDate == discreteDic3[d].ResultDate and twelveHourCheck(discreteDic[a].ResultDate, discreteDic4) is True:
                        db.LogEvaluationScriptMessage("Found glasgow match; oxygen therapy negation count " + str(e) + " " + str(account._id), scriptName, scriptInstance, "Debug")
                        matchingDate = datetimeFromUtcToLocal(discreteDic[a].ResultDate)
                        matchingDate = matchingDate.ToString("MM/dd/yyyy, HH:mm")
                        matchedList.append(dataConversion(None, matchingDate + " Total GCS = " + str(discreteDic[a].Result) + " (Eye Opening: " + str(discreteDic1[b].Result) + ", Verbal Response: " + str(discreteDic2[c].Result) + ", Motor Response: " + str(discreteDic3[d].Result) + ")", None, discreteDic[a]._id, glasgow, 0, False))
                        return matchedList
                    else:
                        a = a - 1; b = b - 1; c = c - 1; d = d - 1
    elif consecutive is False:
        for item in discreteDic:
            if a >= 1 and b >= 1 and c >= 1 and d >= 1:
                if discreteDic2[c].Result != 'Oriented' and float(cleanNumbers(discreteDic[a].Result)) <= float(value) and discreteDic[a].ResultDate == discreteDic1[b].ResultDate == discreteDic2[c].ResultDate == discreteDic3[d].ResultDate and twelveHourCheck(discreteDic[a].ResultDate, discreteDic4) is True:
                    db.LogEvaluationScriptMessage("Found glasgow match; oxygen therapy negation count " + str(e) + " " + str(account._id), scriptName, scriptInstance, "Debug")
                    matchingDate = datetimeFromUtcToLocal(discreteDic[a].ResultDate)
                    matchingDate = matchingDate.ToString("MM/dd/yyyy, HH:mm")
                    matchedList.append(dataConversion(None, matchingDate + " Total GCS = " + str(discreteDic[a].Result) + " (Eye Opening: " + str(discreteDic1[b].Result) + ", Verbal Response: " + str(discreteDic2[c].Result) + ", Motor Response: " + str(discreteDic3[d].Result) + ")", None, discreteDic[a]._id, glasgow, 0, False))
                    return matchedList
                else:
                    a = a - 1; b = b - 1; c = c - 1; d = d - 1
    return matchedList

def twelveHourCheck(glasgowDateTime, OxygenTherapyDic):
    if len(OxygenTherapyDic) > 0:
        db.LogEvaluationScriptMessage("Entered Oxygen len check " + str(account._id), scriptName, scriptInstance, "Debug")
        for item in OxygenTherapyDic:
            startDate = item.ResultDate.AddHours(-12)
            endDate = item.ResultDate.AddHours(12)
            if startDate <= glasgowDateTime <= endDate:
                db.LogEvaluationScriptMessage("Date was found to be within a negated oxygen therapy value " + str(account._id), scriptName, scriptInstance, "Debug")
                return False
    return True

def dvUrineCheck(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    abstraction = None
    for dv in dvDic or []:
        if (
            dvDic[dv]['Name'] in discreteValueName and
            dvDic[dv]['Result'] is not None and 
            (re.search(r'\bpositive\b', dvDic[dv]['Result'], re.IGNORECASE) is not None or
            re.search(r'\bPresent\b', dvDic[dv]['Result'], re.IGNORECASE) is not None)
        ):
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return abstraction
    return abstraction

def antiboticMedValue(medDic, med_name, link_text, sequence=0, category=None, abstract=False):
    for mv in medDic or []:
        if (
            medDic[mv]['Route'] is not None and
            medDic[mv]['Category'] == med_name and
            (re.search(r'\bEye\b', medDic[mv]['Route'], re.IGNORECASE) is None and 
            re.search(r'\btopical\b', medDic[mv]['Route'], re.IGNORECASE) is None and 
            re.search(r'\bocular\b', medDic[mv]['Route'], re.IGNORECASE) is None and 
            re.search(r'\bophthalmic\b', medDic[mv]['Route'], re.IGNORECASE) is None)
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
triggerAlert = True
reason = None
CI = 0
NCI = 0
abgLinks = False
drugLinks = False
dcLinks = False
absLinks = False
labsLinks = False
vitalsLinks = False
medsLinks = False
docLinksLinks = False
glasgowLinks = False

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
glasgow = MatchedCriteriaLink("Glasgow Coma Score", None, "Glasgow Coma Score", None, True, None, None, 2)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 3)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 4)
vitals = MatchedCriteriaLink("Vital Signs/Intake and Output Data", None, "Vital Signs/Intake and Output Data", None, True, None, None, 5)
meds = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 6)
mriBrainLinks = MatchedCriteriaLink("MRI Brain", None, "MRI Brain", None, True, None, None, 7)
ctHeadBrainLinks = MatchedCriteriaLink("CT Head/Brain", None, "CT Head/Brain", None, True, None, None, 8)
eegLinks = MatchedCriteriaLink("EEG", None, "EEG", None, True, None, None, 8)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 9)
abg = MatchedCriteriaLink("ABG", None, "ABG", None, True, None, None, 88)
drug = MatchedCriteriaLink("Drug Screen", None, "Drug Screen", None, True, None, None, 89)
ph = MatchedCriteriaLink("PH", None, "PH", None, True, None, None, 89)
glucose = MatchedCriteriaLink("Glucose", None, "Glucose", None, True, None, None, 90)
ammonia = MatchedCriteriaLink("Serum Ammonia", None, "Serum Ammonia", None, True, None, None, 91)
bun = MatchedCriteriaLink("BUN", None, "BUN", None, True, None, None, 92)
creatinine = MatchedCriteriaLink("Creatinine", None, "Creatinine", None, True, None, None, 93)
calcium = MatchedCriteriaLink("Serum Calcium", None, "Serum Calcium", None, True, None, None, 94)
sodium = MatchedCriteriaLink("Serum Sodium", None, "Serum Sodium", None, True, None, None, 95)
pao2 = MatchedCriteriaLink("Pa02", None, "Pa02", None, True, None, None, 96)
pco2 = MatchedCriteriaLink("PC02", None, "PC02", None, True, None, None, 97)

#Link Text for special messages for lacking
LinkText1 = "No Documented Signs of Alerted Mental Status"

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Encephalopathy':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        subtitle = alert.Subtitle
        reason = alert.Reason
        if outcome == 'AUTORESOLVED' or reason == 'Previously Autoresolved':
            triggerAlert = False
        subtitle = alert.Subtitle
        for alertLink in alert.Links:
            if alertLink.LinkText == 'Documented Dx':
                for links in alertLink.Links:
                    if links.LinkText == LinkText1:
                        message1 = True
        break

#Check if alert was autoresolved or completed.
if (
    validated is False or
    (outcome == "AUTORESOLVED" and validated and codesExist > 1)
):
    #Get meds within last X days
    mainMedDic = {}
    unsortedMedDic = {}
    medCount = 0
    #Combine all items into one list to search against
    medSearchList = ["Antibiotic2", "Antibiotic"]
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
    discreteSearchList = [i for j in [dvOxygenTherapy, dvCBlood, dvCUrine, dvGlasgowComaScale, dvGlasgowEyeOpening, 
        dvGlasgowVerbal, dvGlasgowMotor, dvAmphetamineScreen, dvBarbiturateScreen, dvBenzodiazepineScreen, dvBuprenorphineScreen, 
        dvCannabinoidScreen, dvCocaineScreen, dvMethadoneScreen, dvOpiateScreen, dvOxycodoneScreen, dvUABacteria, dvBloodGlucose, 
        dvBloodGlucosePOC, dvSerumAmmonia, dvSerumBloodUreaNitrogen, dvSerumCalcium, dvSerumCreatinine, dvSerumSodium, 
        dvArterialBloodPH, dvPC02, dvPaO2] for i in j]
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
    g931Code = codeValue("G93.1", "Anoxic Brain Damage: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    Dementia1 = prefixCodeValue("^F01\.", "Dementia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    Dementia2 = prefixCodeValue("^F02\.", "Dementia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    Dementia3 = prefixCodeValue("^F03\.", "Dementia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    alzheimersNeg = prefixCodeValue("^G30\.", "Alzheimers Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    ventDV = dvVentCheck(dict(maindiscreteDic), dvOxygenTherapy, "Ventilator Mentioned In Oxygen Therapy")
    #Documented Dx
    g9340Code = codeValue("G93.40", "Unspecified Encephalopathy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    g928Code = codeValue("G92.8", "Encephalopathy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    g9341Code = codeValue("G93.41", "Encephalopathy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    k7682Code = codeValue("K76.82", "Liver Disease or Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    severeAlzheimersAbs = abstractValue("SEVERE_ALZHEIMERS_DISEASE", "Severe Alzheimers Disease: '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5)
    severeDementiaAbs = abstractValue("SEVERE_DEMENTIA", "Severe Dementia: '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5)
    liverNeg1 = prefixCodeValue("^K70\.", "Liver Disease or Failure DX Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    liverNeg2 = prefixCodeValue("^K71\.", "Liver Disease or Failure DX Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    liverNeg3 = prefixCodeValue("^K72\.", "Liver Disease or Failure DX Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    liverNeg4 = prefixCodeValue("^K73\.", "Liver Disease or Failure DX Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    liverNeg5 = prefixCodeValue("^K74\.", "Liver Disease or Failure DX Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    liverNeg6 = prefixCodeValue("^K75\.", "Liver Disease or Failure DX Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    liverNeg7 = multiCodeValue(["K76.1", "K76.2", "K76.3", "K76.4", "K76.5", "K76.6", "K76.7", "K76.81", "K76.9"],
                               "Liver Disease or Failure DX Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    liverNeg8 = prefixCodeValue("^K77\.", "Liver Disease or Failure DX Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Abs
    r9402Code = codeValue("R94.02", "Abnormal Brain Scan: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    acuteSubacuteHepaticFailCode = multiCodeValue(["K72.00", "K72.01"], "Acute and Subacute Hepatic Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4)
    acuteKidneyFailureAbs = abstractValue("ACUTE_KIDNEY_FAILURE", "Acute Kidney Failure '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5)
    f101Codes = prefixCodeValue("^F10.1", "Alcohol Abuse: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7)
    f102Codes = prefixCodeValue("^F10.2", "Alcohol Dependence: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8)
    AlcoholIntoxicationCode = multiCodeValue(["F10.120", "F10.121", "F10.129"], "Alcohol Intoxication: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9)
    alcoholWithdrawalAbs = abstractValue("ALCOHOL_WITHDRAWAL", "Alcohol Withdrawal '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10)
    AlcoholHeptacFailCode = multiCodeValue(["K70.40", "K70.41"], "Alcoholic Hepatic Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11)
    r4182Code = codeValue("R41.82", "Altered Mental Status: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12)
    #13
    cerebralEdemaAbs = abstractValue("CEREBRAL_EDEMA", "Cerebral Edema: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 17)
    i63Codes = prefixCodeValue("^I63\.", "Cerebral Infarction: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18)
    cerebralIschemiaAbs = abstractValue("CEREBRAL_ISCHEMIA", "Cerebral Edema: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 19)
    chBaselineMenStatusAbs = abstractValue("CHANGE_IN_BASELINE_MENTAL_STATUS", "Change in Baseline Mental Status '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 20)
    chronicHepaticFailureCode = multiCodeValue(["K72.10", "K72.11"], "Chronic Hepatic Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21)
    comaAbs = abstractValue("COMA", "Coma '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 22)
    s07Codes = prefixCodeValue("^S07\.", "Crushing Head Injury: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 24)
    r410Code = codeValue("R41.0", "Disorientation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 25)
    heavyMetalPoisioningAbs = abstractValue("HEAVY_METAL_POISIONING", "Heavy Metal Poisioning '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 29)
    hepaticFailureCode = multiCodeValue(["K72.90", "K72.91"], "Hepatic Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 30)
    i160Code = prefixCodeValue("^I16\.0", "Hypertensive Crisis Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 32)
    infectionAbs = abstractValue("INFECTION", "Infection '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 33)
    influenzaAAbs = abstractValue("INFLUENZA_A", "Influenza A '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 34)
    s06Codes = prefixCodeValue("^S06\.", "Intracranial Injury: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 35)
    g0481Code = codeValue("G04.81", "Liver: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 38)
    k7460Code = codeValue("K74.60", "Liver Cirrhosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 39)
    e8841Code = codeValue("E88.41", "MELAS Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 40)
    e8840Code = codeValue("E88.40", "Mitochondrial Metabolism Disorder: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 41)
    e035Code = codeValue("E03.5", "Myxedema Coma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 42)
    obtundedAbs = abstractValue("OBTUNDED", "Obtunded '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 43)
    opiodidOverdoseAbs = abstractValue("OPIOID_OVERDOSE", "Opioid Overdose '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 45)
    opioidWithdrawalAbs = abstractValue("OPIOID_WITHDRAWAL", "Opioid Withdrawal '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 46)
    t36Codes = prefixCodeValue("^T36\.", "Poisoning: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 47)
    t37Codes = prefixCodeValue("^T37\.", "Poisoning: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 48)
    t38Codes = prefixCodeValue("^T38\.", "Poisoning: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 49)
    t39Codes = prefixCodeValue("^T39\.", "Poisoning: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 50)
    t40Codes = prefixCodeValue("^T40\.", "Poisoning: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 51)
    t41Codes = prefixCodeValue("^T41\.", "Poisoning: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 52)
    t42Codes = prefixCodeValue("^T42\.", "Poisoning: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 53)
    t43Codes = prefixCodeValue("^T43\.", "Poisoning: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 54)
    t44Codes = prefixCodeValue("^T44\.", "Poisoning: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 55)
    t45Codes = prefixCodeValue("^T45\.", "Poisoning: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 56)
    t46Codes = prefixCodeValue("^T46\.", "Poisoning: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 57)
    t47Codes = prefixCodeValue("^T47\.", "Poisoning: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 58)
    t48Codes = prefixCodeValue("^T48\.", "Poisoning: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 59)
    t49Codes = prefixCodeValue("^T49\.", "Poisoning: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 60)
    t50Codes = prefixCodeValue("^T50\.", "Poisoning: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 61)
    f29Code = codeValue("F29", "Postconcussional Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 63)
    psychosisAbs = abstractValue("PSYCHOSIS", "Psychosis '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 64)
    sepsisCode = multiCodeValue(["A41.2", "A41.3", "A41.4", "A41.50", "A41.51", "A41.52", "A41.53", "A41.54", "A41.59", 
        "A41.81", "A41.89", "A41.9", "A42.7", "A22.7", "B37.7", "A26.7", "A54.86", "B00.7", "A32.7", "A24.1", "A20.7", 
        "T81.44XA", "T81.44XD"], "Sepsis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 68)
    severeMalnutrition = multiCodeValue(["E40", "E41", "E42", "E43"], "Severe Malnutrition: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 69)
    stimulantIntoxication = multiCodeValue(["F15.120", "F15.121", "F15.129"], "Stimulant Intoxication: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 72)
    f1510Code = codeValue("F15.10", "Stimulant Abuse: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 73)
    r401Code = codeValue("R40.1", "Stupor: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 74)
    t51Codes = prefixCodeValue("^T51\.", "Toxic Effects of Alcohol: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 76)
    t58Codes = prefixCodeValue("^T58\.", "Toxic Effects of Carbon Monoxide: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 77)
    t57Codes = prefixCodeValue("^T57\.", "Toxic Effects of Inorganic Substance: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 78)
    t56Codes = prefixCodeValue("^T56\.", "Toxic Effects of Metals: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 79)
    k712Code = codeValue("K71.2", "Toxic Liver Disease with Acute Hepatitis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 80)
    toxicLiverDiseaseCode = multiCodeValue(["K71.10", "K71.11"], "Toxic Liver Disease with Hepatic Necrosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 81)
    typeIDiabeticKeto = multiCodeValue(["E10.10", "E10.11"], "Type I Diabetic Ketoacidosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 82)
    typeIIDiabeticKeto = multiCodeValue(["E11.10", "E11.11"], "Type II Diabetic Ketoacidosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 83)
    e1100Code = codeValue("E11.00", "Type II Diabetes with Hyperosmolarity without NKHHC: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 84)
    e1101Code = codeValue("E11.01", "Type II Diabetes with Hyperosmolarity with Coma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 85)
    #Labs
    cbloodDV = dvPositiveCheck(dict(maindiscreteDic), dvCBlood, "Blood Culture Result: '[VALUE]' (Result Date: [RESULTDATETIME])", 3, labs, False)
    ethanolDV = dvValue(dvEthanolLevel, "Ethanol Level: [VALUE] (Result Date: [RESULTDATETIME])", calcEthanolLevel1, 4)
    e162Code = codeValue("E16.2", "Hypoglycemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5)
    r0902Code = codeValue("R09.02", "Hypoxemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6)
    positiveCerebrospinalFluidCultureAbs = abstractValue("POSITIVE_CEREBROSPINAL_FLUID_CULTURE", "Positive Cerebrospinal Fluid Culture '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7)
    uremiaAbs = abstractValue("UREMIA", "Uremia '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8)
    uaBacteriaDV = dvUrineCheck(dict(maindiscreteDic), dvUABacteria, "UA Bacteria: [VALUE] (Result Date: [RESULTDATETIME])", 9)
    urineDV = dvPositiveCheck(dict(maindiscreteDic), dvCUrine, "Urine Culture Result: '[VALUE]' (Result Date: [RESULTDATETIME])", 10, labs, False)
    #Lab Sub Categories
    highBloodGlucoseDV = dvValueMulti(dict(maindiscreteDic), dvBloodGlucose, "Blood Glucose: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodGlucose1, gt, 0, glucose, False, 10)
    highBloodGlucosePOCDV = dvValueMulti(dict(maindiscreteDic), dvBloodGlucosePOC, "Blood Glucose: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodGlucosePOC1, gt, 0, glucose, False, 10)
    lowBloodGlucoseDV = dvValueMulti(dict(maindiscreteDic), dvBloodGlucose, "Blood Glucose: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodGlucose2, lt, 0, glucose, False, 10)
    lowBloodGlucosePOCDV = dvValueMulti(dict(maindiscreteDic), dvBloodGlucosePOC, "Blood Glucose: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodGlucosePOC2, lt, 0, glucose, False, 10)
    serumAmmoniaDV = dvValueMulti(dict(maindiscreteDic), dvSerumAmmonia, "Serum Ammonia: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumAmmonia1, gt, 0, ammonia, False, 10)
    highSerumBloodUreaNitrogenDV = dvValueMulti(dict(maindiscreteDic), dvSerumBloodUreaNitrogen, "Serum Blood Urea Nitrogen: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumBloodUreaNitrogen1, gt, 0, bun, False, 10)
    serumCalcium1DV = dvValueMulti(dict(maindiscreteDic), dvSerumCalcium, "Serum Calcium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumCalcium1, gt, 0, calcium, False, 10)
    serumCalcium2DV = dvValueMulti(dict(maindiscreteDic), dvSerumCalcium, "Serum Calcium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumCalcium2, lt, 0, calcium, False, 10)
    serumCreatinine1DV = dvValueMulti(dict(maindiscreteDic), dvSerumCreatinine, "Serum Creatinine: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumCreatinine1, gt, 0, creatinine, False, 10)
    serumSodium1DV = dvValueMulti(dict(maindiscreteDic), dvSerumSodium, "Serum Sodium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumSodium1, gt, 0, sodium, False, 10)
    serumSodium2DV = dvValueMulti(dict(maindiscreteDic), dvSerumSodium, "Serum Sodium: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumSodium2, lt, 0, sodium, False, 10)
    #ABG Sub Categories
    pao2DV = dvValueMulti(dict(maindiscreteDic), dvPaO2, "p02: [VALUE] (Result Date: [RESULTDATETIME])", calcPAO21, lt, 0, pao2, False, 10)
    lowArterialBloodPHDV = dvValueMulti(dict(maindiscreteDic), dvArterialBloodPH, "PH: [VALUE] (Result Date: [RESULTDATETIME])", calcArterialBloodPH1, lt, 0, ph, False, 10)
    pco2DV = dvValueMulti(dict(maindiscreteDic), dvPC02, "paC02: [VALUE] (Result Date: [RESULTDATETIME])", calcPC021, gt, 0, pco2, False, 10)
    #Meds
    antibioticMed = antiboticMedValue(dict(mainMedDic), "Antibiotic", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 2)
    antibioticAbs = abstractValue("ANTIBIOTIC", "Antibiotic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3)
    antibiotic2Med = antiboticMedValue(dict(mainMedDic), "Antibiotic2", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 4)
    antibiotic2Abs = abstractValue("ANTIBIOTIC_2", "Antibiotic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5)
    anticonvulsantMed = medValue("Anticonvulsant", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 6)
    anticonvulsantAbs = abstractValue("ANTICONVULSANT", "Anticonvulsant '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7)
    antifungalMed = medValue("Antifungal", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 8)
    antifungalAbs = abstractValue("ANTIFUNGAL", "Antifungal '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9)
    antiviralMed = medValue("Antiviral", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 10)
    antiviralAbs = abstractValue("ANTIVIRAL", "Antiviral '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11)
    dextroseMed = medValue("Dextrose 50%", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 14)
    encephalopathyMedicationAbs = abstractValue("ENCEPHALOPATHY_MEDICATION", "Encephalopathy Medication '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 15)
    #Vitals
    diastolicHyperTensiveCrisisDV = dvValue(dvDBP, "Diastolic Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcDBP1, 2)
    systolicHyperTensiveCrisisDV = dvValue(dvSBP, "Systolic Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcSBP1, 3)
    lowPulseOximetryDV = dvValue(dvSPO2, "Sp02: [VALUE] (Result Date: [RESULTDATETIME])", calcSPO21, 4)
    highTempDV = dvValue(dvTemperature, "Temperature: [VALUE] (Result Date: [RESULTDATETIME])", calcTemperature1, 5)
    temp2DV = dvValue(dvTemperature, "Temperature: [VALUE] (Result Date: [RESULTDATETIME])", calcTemperature2, 6)
    #Drug
    amphetamineDrug = dvPositiveCheck(dict(maindiscreteDic), dvAmphetamineScreen, "Amphetamine Screen Urine: '[VALUE]' (Result Date: [RESULTDATETIME])", 1)
    barbiturateDrug = dvPositiveCheck(dict(maindiscreteDic), dvBarbiturateScreen, "Barbiturate Screen Urine: '[VALUE]' (Result Date: [RESULTDATETIME])", 2)
    benzodiazepineDrug = dvPositiveCheck(dict(maindiscreteDic), dvBenzodiazepineScreen, "Benzodiazepine Screen Urine: '[VALUE]' (Result Date: [RESULTDATETIME])", 3)
    buprenorphineDrug = dvPositiveCheck(dict(maindiscreteDic), dvBuprenorphineScreen, "Buprenorphine Screen Urine: '[VALUE]' (Result Date: [RESULTDATETIME])", 4)
    cannabinoidDrug = dvPositiveCheck(dict(maindiscreteDic), dvCannabinoidScreen, "Cannabinoid Screen Urine: '[VALUE]' (Result Date: [RESULTDATETIME])", 5)
    cocaineDrug = dvPositiveCheck(dict(maindiscreteDic), dvCocaineScreen, "Cocaine Screen Urine: '[VALUE]' (Result Date: [RESULTDATETIME])", 6)
    methadoneDrug = dvPositiveCheck(dict(maindiscreteDic), dvMethadoneScreen, "Methadone Screen Urine: '[VALUE]' (Result Date: [RESULTDATETIME])", 7)
    opiateDrug = dvPositiveCheck(dict(maindiscreteDic), dvOpiateScreen, "Opiate Screen Urine: '[VALUE]' (Result Date: [RESULTDATETIME])", 8)
    oxycodoneDrug = dvPositiveCheck(dict(maindiscreteDic), dvOxycodoneScreen, "Oxycodone Screen Urine: '[VALUE]' (Result Date: [RESULTDATETIME])", 9)
    
    #Neurologic Change Indicators Count
    if psychosisAbs is not None: abs.Links.Add(psychosisAbs); NCI += 1
    if r410Code is not None: abs.Links.Add(r410Code); NCI += 1
    if r4182Code is not None: abs.Links.Add(r4182Code); NCI += 1
    if obtundedAbs is not None: abs.Links.Add(obtundedAbs); NCI += 1
    if r401Code is not None: abs.Links.Add(r401Code); NCI += 1
    if comaAbs is not None: abs.Links.Add(comaAbs); NCI += 1
    if chBaselineMenStatusAbs is not None: abs.Links.Add(chBaselineMenStatusAbs); NCI += 1
    db.LogEvaluationScriptMessage("NCI Score " + str(NCI) + " " + str(account._id), scriptName, scriptInstance, "Debug")

    #Abstracting Glasgow based on NCI score
    glasgowComaScoreDV = []
    if (Dementia1 is not None or Dementia2 is not None or Dementia3 is not None or alzheimersNeg is not None) and chBaselineMenStatusAbs is None:
        if NCI > 0:
            glasgowComaScoreDV = GlasgowLinkedValues(dict(maindiscreteDic), dvGlasgowComaScale, dvGlasgowEyeOpening, dvGlasgowVerbal, dvGlasgowMotor, dvOxygenTherapy, calcGlasgowComaScale2, False)
        elif NCI == 0:
            glasgowComaScoreDV = GlasgowLinkedValues(dict(maindiscreteDic), dvGlasgowComaScale, dvGlasgowEyeOpening, dvGlasgowVerbal, dvGlasgowMotor, dvOxygenTherapy, calcGlasgowComaScale2, True)

    else:
        if NCI > 0:
            glasgowComaScoreDV = GlasgowLinkedValues(dict(maindiscreteDic), dvGlasgowComaScale, dvGlasgowEyeOpening, dvGlasgowVerbal, dvGlasgowMotor, dvOxygenTherapy, calcGlasgowComaScale1, False)
        elif NCI == 0:
            glasgowComaScoreDV = GlasgowLinkedValues(dict(maindiscreteDic), dvGlasgowComaScale, dvGlasgowEyeOpening, dvGlasgowVerbal, dvGlasgowMotor, dvOxygenTherapy, calcGlasgowComaScale1, True)

    #Clinical Indicators Count
    if serumAmmoniaDV is not None: CI += 1
    if highTempDV is not None or temp2DV is not None:
        if highTempDV is not None: vitals.Links.Add(highTempDV)
        CI += 1
    if lowArterialBloodPHDV is not None: CI += 1
    if positiveCerebrospinalFluidCultureAbs is not None: labs.Links.Add(positiveCerebrospinalFluidCultureAbs); CI += 1
    if serumSodium1DV is not None or serumSodium2DV is not None:
        CI += 1
    if uremiaAbs is not None: labs.Links.Add(uremiaAbs); CI += 1
    if (
        diastolicHyperTensiveCrisisDV is not None or
        systolicHyperTensiveCrisisDV is not None
    ):
        if diastolicHyperTensiveCrisisDV is not None: vitals.Links.Add(diastolicHyperTensiveCrisisDV)
        if systolicHyperTensiveCrisisDV is not None: vitals.Links.Add(systolicHyperTensiveCrisisDV)
        CI += 1
    if serumCalcium1DV is not None or serumCalcium2DV is not None:
        CI += 1
    if cerebralEdemaAbs is not None: abs.Links.Add(cerebralEdemaAbs); CI += 1
    if cerebralIschemiaAbs is not None: abs.Links.Add(cerebralIschemiaAbs); CI += 1
    if pao2DV is not None or r0902Code is not None:
        if r0902Code is not None: vitals.Links.Add(r0902Code)
        CI += 1
    if lowPulseOximetryDV is not None: vitals.Links.Add(lowPulseOximetryDV); CI += 1
    if (
        (highBloodGlucoseDV is not None or
        highBloodGlucosePOCDV is not None or
        e162Code is not None) or
        (lowBloodGlucoseDV is not None or
        lowBloodGlucosePOCDV is not None)
    ):
        if e162Code is not None: labs.Links.Add(e162Code)
        CI += 1
    if opioidWithdrawalAbs is not None: abs.Links.Add(opioidWithdrawalAbs); CI += 1
    if sepsisCode is not None: abs.Links.Add(sepsisCode); CI += 1
    if alcoholWithdrawalAbs is not None: abs.Links.Add(alcoholWithdrawalAbs); CI += 1
    if (
        acuteSubacuteHepaticFailCode is not None or
        AlcoholHeptacFailCode is not None or
        chronicHepaticFailureCode is not None or
        hepaticFailureCode is not None or
        k712Code is not None or
        toxicLiverDiseaseCode is not None
    ):
        if acuteSubacuteHepaticFailCode is not None: abs.Links.Add(acuteSubacuteHepaticFailCode)
        if AlcoholHeptacFailCode is not None: abs.Links.Add(AlcoholHeptacFailCode)
        if chronicHepaticFailureCode is not None: abs.Links.Add(chronicHepaticFailureCode)
        if hepaticFailureCode is not None: abs.Links.Add(hepaticFailureCode)
        if k712Code is not None: abs.Links.Add(k712Code)
        if toxicLiverDiseaseCode is not None: abs.Links.Add(toxicLiverDiseaseCode)
        CI += 1
    if highSerumBloodUreaNitrogenDV is not None: CI += 1
    if opiodidOverdoseAbs is not None: abs.Links.Add(opiodidOverdoseAbs); CI += 1
    if stimulantIntoxication is not None: abs.Links.Add(stimulantIntoxication); CI += 1
    if f1510Code is not None: abs.Links.Add(f1510Code); CI += 1
    if heavyMetalPoisioningAbs is not None: abs.Links.Add(heavyMetalPoisioningAbs); CI += 1
    if infectionAbs is not None: abs.Links.Add(infectionAbs); CI += 1
    if acuteKidneyFailureAbs is not None: abs.Links.Add(acuteKidneyFailureAbs); CI += 1
    if encephalopathyMedicationAbs is not None: meds.Links.Add(encephalopathyMedicationAbs); CI += 1
    if antiviralAbs is not None or antiviralMed is not None:
        if antiviralMed is not None: meds.Links.Add(antiviralMed)
        if antiviralAbs is not None: meds.Links.Add(antiviralAbs)
        CI += 1
    if antifungalAbs is not None or antifungalMed is not None:
        if antifungalMed is not None: meds.Links.Add(antifungalMed)
        if antifungalAbs is not None: meds.Links.Add(antifungalAbs)
        CI += 1
    if antibioticAbs is not None or antibioticMed is not None or antibiotic2Abs is not None or antibiotic2Med is not None:
        if antibioticMed is not None: meds.Links.Add(antibioticMed)
        if antibioticAbs is not None: meds.Links.Add(antibioticAbs)
        if antibiotic2Med is not None: meds.Links.Add(antibiotic2Med)
        if antibiotic2Abs is not None: meds.Links.Add(antibiotic2Abs)
        CI += 1
    if anticonvulsantMed is not None or anticonvulsantAbs is not None:
        if anticonvulsantMed is not None: meds.Links.Add(anticonvulsantMed)
        if anticonvulsantAbs is not None: meds.Links.Add(anticonvulsantAbs)
        CI += 1
    if dextroseMed is not None: meds.Links.Add(dextroseMed); CI += 1
    if g0481Code is not None: abs.Links.Add(g0481Code); CI += 1
    if i160Code is not None: abs.Links.Add(i160Code); CI += 1
    if typeIDiabeticKeto is not None: abs.Links.Add(typeIDiabeticKeto); CI += 1
    if typeIIDiabeticKeto is not None: abs.Links.Add(typeIIDiabeticKeto); CI += 1
    if e1100Code is not None: abs.Links.Add(e1100Code); CI += 1
    if e1101Code is not None: abs.Links.Add(e1101Code); CI += 1
    if f101Codes is not None: abs.Links.Add(f101Codes); CI += 1
    if f102Codes is not None: abs.Links.Add(f102Codes); CI += 1
    if s07Codes is not None: abs.Links.Add(s07Codes); CI += 1
    if influenzaAAbs is not None: abs.Links.Add(influenzaAAbs); CI += 1
    if e8841Code is not None: abs.Links.Add(e8841Code); CI += 1
    if e8840Code is not None: abs.Links.Add(e8840Code); CI += 1
    if e035Code is not None: abs.Links.Add(e035Code); CI += 1
    if f29Code is not None: abs.Links.Add(f29Code); CI += 1
    if severeMalnutrition is not None: abs.Links.Add(severeMalnutrition); CI += 1
    if s06Codes is not None: abs.Links.Add(s06Codes); CI += 1
    if cbloodDV is not None: CI += 1
    if uaBacteriaDV is not None: CI += 1
    if urineDV is not None: CI += 1
    if serumCreatinine1DV is not None: CI += 1
    if pco2DV is not None: CI += 1
    if (
        t36Codes is not None or 
        t37Codes is not None or 
        t38Codes is not None or 
        t39Codes is not None or 
        t40Codes is not None or 
        t41Codes is not None or 
        t42Codes is not None or 
        t43Codes is not None or 
        t44Codes is not None or 
        t45Codes is not None or 
        t46Codes is not None or 
        t47Codes is not None or 
        t48Codes is not None or 
        t49Codes is not None or 
        t50Codes is not None
    ):
        CI += 1
        if t36Codes is not None: abs.Links.Add(t36Codes)
        if t37Codes is not None: abs.Links.Add(t37Codes)
        if t38Codes is not None: abs.Links.Add(t38Codes)
        if t39Codes is not None: abs.Links.Add(t39Codes)
        if t40Codes is not None: abs.Links.Add(t40Codes)
        if t41Codes is not None: abs.Links.Add(t41Codes)
        if t42Codes is not None: abs.Links.Add(t42Codes)
        if t43Codes is not None: abs.Links.Add(t43Codes)
        if t44Codes is not None: abs.Links.Add(t44Codes)
        if t45Codes is not None: abs.Links.Add(t45Codes)
        if t46Codes is not None: abs.Links.Add(t46Codes)
        if t47Codes is not None: abs.Links.Add(t47Codes)
        if t48Codes is not None: abs.Links.Add(t48Codes)
        if t49Codes is not None: abs.Links.Add(t49Codes)
        if t50Codes is not None: abs.Links.Add(t50Codes)
    if t51Codes is not None: CI += 1; abs.Links.Add(t51Codes)
    if t58Codes is not None: CI += 1; abs.Links.Add(t58Codes)
    if t57Codes is not None: CI += 1; abs.Links.Add(t57Codes)
    if t56Codes is not None: CI += 1; abs.Links.Add(t56Codes)
    if amphetamineDrug is not None: drug.Links.Add(amphetamineDrug); CI += 1
    if barbiturateDrug is not None: drug.Links.Add(barbiturateDrug); CI += 1
    if benzodiazepineDrug is not None: drug.Links.Add(benzodiazepineDrug); CI += 1
    if buprenorphineDrug is not None: drug.Links.Add(buprenorphineDrug); CI += 1
    if cannabinoidDrug is not None: drug.Links.Add(cannabinoidDrug); CI += 1
    if cocaineDrug is not None: drug.Links.Add(cocaineDrug); CI += 1
    if methadoneDrug is not None: drug.Links.Add(methadoneDrug); CI += 1
    if opiateDrug is not None: drug.Links.Add(opiateDrug); CI += 1
    if oxycodoneDrug is not None: drug.Links.Add(oxycodoneDrug); CI += 1
    if ethanolDV is not None: labs.Links.Add(ethanolDV); CI += 1
    if i63Codes is not None: abs.Links.Add(i63Codes); CI += 1
    
    #Main Algorithm
    if triggerAlert and subtitle == "Encephalopathy Dx Documented Possibly Lacking Supporting Evidence" and codesExist == 1 and (r4182Code is not None or glasgowComaScoreDV):
        if r4182Code is not None: updateLinkText(r4182Code, "Autoclosed Due To - "); dc.Links.Add(r4182Code)
        if glasgowComaScoreDV:
            dc.Links.Add(MatchedCriteriaLink("AutoClosed due to most recent Glasgow Coma Score", None, None, None))
            dc.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, False))
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Glascow Coma Score Existing on the Account"
        result.Validated = True
        AlertConditions = True

    elif triggerAlert and codesExist == 1 and r4182Code is None and glasgowComaScoreDV is None and NCI == 0:
        for code in codeList:
            desc = codeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            if tempCode is not None:
                dc.Links.Add(tempCode)
                break
        if not glasgowComaScoreDV: dc.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, True))
        result.Subtitle = "Encephalopathy Dx Documented Possibly Lacking Supporting Evidence"
        AlertPassed = True
        
    elif codesExist == 1 or severeAlzheimersAbs is not None or severeDementiaAbs is not None:
        db.LogEvaluationScriptMessage("One specific code was on the chart, alert failed. " + str(alertTriggered) + " " + str(account._id), scriptName, scriptInstance, "Debug")
        if alertTriggered:
            for code in codeList:
                desc = codeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    dc.Links.Add(tempCode)
                    break
            if severeAlzheimersAbs is not None: dc.Links.Add(severeAlzheimersAbs)
            if severeDementiaAbs is not None: dc.Links.Add(severeDementiaAbs)
            result.Outcome = "AUTORESOLVED"
            result.Reason = "Autoresolved due to one Specified Code on the Account"
            result.Validated = True
            AlertConditions = True
            db.LogEvaluationScriptMessage("Alert Autoclosed due to one specific code" + str(account._id), scriptName, scriptInstance, "Debug")
        else: result.Passed = False
        
    elif codesExist > 1 and not (g928Code is not None and g9341Code is not None) or codesExist > 2:
        for code in codeList:
            desc = codeDic[code]
            tempCode = accountContainer.GetFirstCodeLink(code, desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            dc.Links.Add(tempCode)
        if validated:
            result.Validated = False
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"
        result.Subtitle = "Encephalopathy Conflicting Dx " + str1
        AlertPassed = True

    elif triggerAlert and g9340Code is not None:
        dc.Links.Add(g9340Code)
        result.Subtitle = "Unspecified Encephalopathy Dx"
        AlertPassed = True

    elif triggerAlert and (len(glasgowComaScoreDV) > 2 or (len(glasgowComaScoreDV) == 1 and NCI > 0)) and CI > 0:
        result.Subtitle = "Possible Encephalopathy Dx"
        AlertPassed = True

    elif (
        subtitle == "Hepatic Encephalopathy Documented, but No Evidence of Liver Failure Found" and
        (liverNeg1 is not None or liverNeg2 is not None or liverNeg3 is not None or
        liverNeg4 is not None or liverNeg5 is not None or liverNeg6 is not None or
        liverNeg7 is not None) and
        k7682Code is not None
    ):
        if liverNeg1 is not None: dc.Links.Add(liverNeg1)
        if liverNeg2 is not None: dc.Links.Add(liverNeg2)
        if liverNeg3 is not None: dc.Links.Add(liverNeg3)
        if liverNeg4 is not None: dc.Links.Add(liverNeg4)
        if liverNeg5 is not None: dc.Links.Add(liverNeg5)
        if liverNeg6 is not None: dc.Links.Add(liverNeg6)
        if liverNeg7 is not None: dc.Links.Add(liverNeg7)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Liver Disease/Failure DX Code Existing On Account."
        result.Validated = True
        AlertConditions = True

    elif (
        triggerAlert and
        k7682Code is not None and
        (liverNeg1 is None and liverNeg2 is None and liverNeg3 is None and
         liverNeg4 is None and liverNeg5 is None and liverNeg6 is None and
         liverNeg7 is None)
    ):
        dc.Links.Add(k7682Code)
        result.Subtitle = "Hepatic Encephalopathy Documented, but No Evidence of Liver Failure Found"
        AlertPassed = True

    elif (
        len(glasgowComaScoreDV) > 0 or
        (NCI >= 1 and Dementia1 is None and Dementia2 is None and Dementia3 is None and alzheimersNeg is None) or
        (chBaselineMenStatusAbs is not None and (Dementia1 is not None or Dementia2 is not None or Dementia3 is not None or alzheimersNeg is not None))
    ):
        if (chBaselineMenStatusAbs is not None and (Dementia1 is not None or Dementia2 is not None or Dementia3 is not None or alzheimersNeg is not None)):
            if chBaselineMenStatusAbs is not None: dc.Links.Add(chBaselineMenStatusAbs)
            if Dementia1 is not None: dc.Links.Add(Dementia1)
            if Dementia2 is not None: dc.Links.Add(Dementia2)
            if Dementia3 is not None: dc.Links.Add(Dementia3)
            if alzheimersNeg is not None: dc.Links.Add(alzheimersNeg)
        result.Subtitle = "Altered Mental Status"
        AlertPassed = True
        
    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:   
    #Abs
    #1
    codeValue("R94.01", "Abnormal Electroencephalogram (EEG): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, abs, True)
    abstractValue("ACE_CONSULT", "ACE Consult '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3, abs, True)
    #4-5
    abstractValue("AGITATION", "Agitation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6, abs, True)
    #7-12
    alteredAbs = abstractValue("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level Of Consciousness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13)
    if r4182Code is not None:
        if alteredAbs is not None: alteredAbs.Hidden = True; abs.Links.Add(alteredAbs)
    elif r4182Code is None and alteredAbs is not None:
        abs.Links.Add(alteredAbs)
    codeValue("R47.01", "Aphasia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, abs, True)
    codeValue("R18.8", "Ascities: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
    abstractValue("ATAXIA", "Ataxia '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 16, abs, True)
    #17-22
    abstractValue("COMBATIVE", "Combativeness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 23, abs, True)
    #24-25
    codeValue("E86.0", "Dehydration: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 26, abs, True)
    codeValue("F07.81", "Fatigue: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 27, abs, True)
    codeValue("R44.3", "Hallucinations: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 28, abs, True)
    #29-30
    codeValue("E87.0", "Hypernatremia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 31, abs, True)
    #32-35
    codeValue("R17", "Jaundice: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 36, abs, True)
    codeValue("R53.83", "Lethargy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 37, abs, True)
    #38-43
    abstractValue("ONE_TO_ONE_SUPERVISION", "One to one supervision: '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 44, abs, True)
    #45-61
    abstractValue("POSSIBLE_ENCEPHALOPATHY", "Possible Encephalopathy '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 62, abs, True)
    #63-64
    abstractValue("RESTLESSNESS", "Restlessness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 65, abs, True)
    codeValue("R10.811", "Right Upper Quadrant Tenderness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 66, abs, True)
    abstractValue("SEIZURE", "Seizure '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 67, abs, True)
    #68-69
    codeValue("R47.81", "Slurred Speech: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 70, abs, True)
    codeValue("R40.0", "Somnolence: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 71, abs, True)
    #72-74
    abstractValue("SUNDOWNING", "Sundowning '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 75, abs, True)
    #76-85
    codeValue("S09.90", "Unspecified Injury of Head: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 86, abs, True)
    #Document Links
    documentLink("CT Head WO", "CT Head WO", 0, ctHeadBrainLinks, True)
    documentLink("CT Head Stroke Alert", "CT Head Stroke Alert", 0, ctHeadBrainLinks, True)
    documentLink("CTA Head-Neck", "CTA Head-Neck", 0, ctHeadBrainLinks, True)
    documentLink("CTA Head", "CTA Head", 0, ctHeadBrainLinks, True)
    documentLink("CT Head  WWO", "CT Head  WWO", 0, ctHeadBrainLinks, True)
    documentLink("CT Head  W", "CT Head  W", 0, ctHeadBrainLinks, True)
    documentLink("MRI Brain WWO", "MRI Brain WWO", 0, mriBrainLinks, True)
    documentLink("MRI Brain  W and W/O Contrast", "MRI Brain  W and W/O Contrast", 0, mriBrainLinks, True)
    documentLink("WO", "WO", 0, mriBrainLinks, True)
    documentLink("MRI Brain W/O Contrast", "MRI Brain W/O Contrast", 0, mriBrainLinks, True)
    documentLink("MRI Brain W/O Con", "MRI Brain W/O Con", 0, mriBrainLinks, True)
    documentLink("MRI Brain  W and W/O Con", "MRI Brain  W and W/O Con", 0, mriBrainLinks, True)
    documentLink("MRI Brain  W", "MRI Brain  W", 0, mriBrainLinks, True)
    documentLink("MRI Brain  W/ Contrast", "MRI Brain  W/ Contrast", 0, mriBrainLinks, True)
    documentLink("EEG Report", "EEG Report", 0, eegLinks, True)
    documentLink("EEG", "EEG", 0, eegLinks, True)
    #Labs
    dvValue(dvAlkalinePhos, "Alkaline Phos: [VALUE] (Result Date: [RESULTDATETIME])", calcAlkalinePhos1, 1, labs, True)
    dvValue(dvBilirubinTotal, "Bilirubin Total: [VALUE] (Result Date: [RESULTDATETIME])", calcBilirubinTotal1, 2, labs, True)
    if cbloodDV is not None: labs.Links.Add(cbloodDV) #3
    #4-8
    if uaBacteriaDV is not None: labs.Links.Add(uaBacteriaDV) #9
    if urineDV is not None: labs.Links.Add(urineDV) #10
    #Meds
    medValue("Anti-Hypoglycemic Agent", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, meds, True)
    #2-11
    medValue("Benzodiazepine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 12, meds, True)
    abstractValue("BENZODIAZEPINE", "Benzodiazepine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13, meds, True)
    #14-15
    medValue("Haloperidol", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 16, meds, True)
    abstractValue("HALOPERIDOL", "Haloperidol '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 17, meds, True)
    medValue("Lactulose", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 18, meds, True)
    abstractValue("LACTULOSE", "Lactulose '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 19, meds, True)
    #Vitals
    multiCodeValue(["F10.220", "F10.221", "F10.229"], "Acute Alcohol Intoxication: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, vitals, True)
    #2-5
    if temp2DV is not None: vitals.Links.Add(temp2DV) #6

    #Glasgow
    if len(glasgowComaScoreDV) > 0:
        for entry in glasgowComaScoreDV:
            glasgow.Links.Add(entry)
    if glasgowComaScoreDV is None:
        abstractValue("LOW_GLASGOW_COMA_SCORE", "Glasgow Coma Score: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0, glasgow, True)
    #Sub category links
    if highBloodGlucoseDV is not None:
        for entry in highBloodGlucoseDV:
            glucose.Links.Add(entry)
    if highBloodGlucosePOCDV is not None:
        for entry in highBloodGlucosePOCDV:
            glucose.Links.Add(entry)
    if lowBloodGlucoseDV is not None:
        for entry in lowBloodGlucoseDV:
            glucose.Links.Add(entry)
    if lowBloodGlucosePOCDV is not None:
        for entry in lowBloodGlucosePOCDV:
            glucose.Links.Add(entry)
    if serumAmmoniaDV is not None:
        for entry in serumAmmoniaDV:
            ammonia.Links.Add(entry)
    if highSerumBloodUreaNitrogenDV is not None:
        for entry in highSerumBloodUreaNitrogenDV:
            bun.Links.Add(entry)
    if serumCalcium1DV is not None:
        for entry in serumCalcium1DV:
            calcium.Links.Add(entry)
    if serumCalcium2DV is not None:
        for entry in serumCalcium2DV:
            calcium.Links.Add(entry)
    if serumCreatinine1DV is not None:
        for entry in serumCreatinine1DV:
            creatinine.Links.Add(entry)
    if serumSodium1DV is not None:
        for entry in serumSodium1DV:
            sodium.Links.Add(entry)
    if serumSodium2DV is not None:
        for entry in serumSodium2DV:
            sodium.Links.Add(entry)
    if lowArterialBloodPHDV is not None:
        for entry in lowArterialBloodPHDV:
            ph.Links.Add(entry)
    if pao2DV is not None:
        for entry in pao2DV:
            pao2.Links.Add(entry)
    if pco2DV is not None:
        for entry in pco2DV:
            pco2.Links.Add(entry)

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if pao2.Links: abg.Links.Add(pao2); abgLinks = True
    if pco2.Links: abg.Links.Add(pco2); abgLinks = True
    if ph.Links: abg.Links.Add(ph); abgLinks = True
    if glucose.Links: labs.Links.Add(glucose); labsLinks = True
    if ammonia.Links: labs.Links.Add(ammonia); labsLinks = True
    if bun.Links: labs.Links.Add(bun); labsLinks = True
    if creatinine.Links: labs.Links.Add(creatinine); labsLinks = True
    if calcium.Links: labs.Links.Add(calcium); labsLinks = True
    if sodium.Links: labs.Links.Add(sodium); labsLinks = True
    if abg.Links: labs.Links.Add(abg); abgLinks = True
    if drug.Links: labs.Links.Add(drug); drugLinks = True
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    if vitals.Links: result.Links.Add(vitals); vitalsLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    if mriBrainLinks.Links: result.Links.Add(mriBrainLinks); docLinksLinks = True
    if ctHeadBrainLinks.Links: result.Links.Add(ctHeadBrainLinks); docLinksLinks = True
    if eegLinks.Links: result.Links.Add(eegLinks); docLinksLinks = True
    if glasgow.Links: result.Links.Add(glasgow); glasgowLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Documented Dx- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks) + ", vitals- " + str(vitalsLinks) + ", meds- " + str(medsLinks) + ", abg- " + str(abgLinks) 
        + ", docs- " + str(docLinksLinks) + ", drugs- " + str(drugLinks) + ", glasgow- " + str(glasgowLinks)+ "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
