##################################################################################################################
#Evaluation Script - Pulmonary Edema
#
#This script checks an account to see if it matches criteria to be alerted for Pulmonary Edema
#Date - 11/24/2024
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
codeDic = {}
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
dvArterialBloodC02 = ["BLD GAS CO2 (mmHg)", "PaCO2 (mmHg)"]
calcArterialBloodC021 = lambda x: x > 46
dvArterialBloodPH = ["pH"]
calcArterialBloodPH1 = lambda x: x < 7.30
dvBNP = ["BNP(NT proBNP) (pg/mL)"]
calcBNP1 = lambda x: x > 900
dvDBP = ["BP Arterial Diastolic cc (mm Hg)", "DBP 3.5 (No Calculation) (mmhg)", "DBP 3.5 (No Calculation) (mm Hg)"]
calcDBP1 = lambda x: x > 110
dvHeartRate = ["Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)", "3.5 Heart Rate (Radial) (bpm)",  "SCC Monitor Pulse (bpm)"]
calcHeartRate1 = lambda x: x > 90
dvPaO2 = ["BLD GAS O2 (mmHg)", "PO2 (mmHg)"]
calcPAO21 = lambda x: x < 80
dvProBNP = [""]
calcProBNP1 = lambda x: x > 900
dvReducedEjectionFraction = [""]
calcReducedEjectionFraction1 = lambda x: x < 41
dvRespiratoryRate = ["3.5 Respiratory Rate (#VS I&O) (per Minute)"]
calcRespiratoryRate1 = lambda x: x > 20
dvSBP = ["SBP 3.5 (No Calculation) (mm Hg)"]
calcSBP1 = lambda x: x > 180
dvSPO2 = ["Pulse Oximetry(Num) (%)"]
calcSPO21 = lambda x: x < 90
dvTroponinT = ["TROPONIN, HIGH SENSITIVITY (ng/L)"]
calcTroponinT1 = lambda x: x > 59
dvOxygenTherapy = ["DELIVERY"]

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

#========================================
#  Algorithm
#========================================
db.LogEvaluationScriptMessage("Script starting " + str(account._id), scriptName, scriptInstance, "Debug")
#Calaculate Age
age = math.floor((admitDate - birthDate).TotalDays / 365.2425)

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
treatmentCheck = 0
dcLinks = False
absLinks = False
labsLinks = False
vitalsLinks = False
medsLinks = False
oxygenLinks = False
docLinksLinks = False
contriLinks = False
cardiogenicLinks = False

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 2)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 3)
vitals = MatchedCriteriaLink("Vital Signs/Intake and Output Data", None, "Vital Signs/Intake and Output Data", None, True, None, None, 4)
oxygen = MatchedCriteriaLink("Oxygenation/Ventilation", None, "Oxygenation/Ventilation", None, True, None, None, 5)
meds = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 6)
chestXRayLinks = MatchedCriteriaLink("Chest X-Ray", None, "Chest X-Ray", None, True, None, None, 7)
ctChestLinks = MatchedCriteriaLink("CT Chest", None, "CT Chest", None, True, None, None, 8)
contri = MatchedCriteriaLink("Contributing Dx", None, "Contributing Dx", None, True, None, None, 9)
cardiogenic = MatchedCriteriaLink("Cardiogenic Indicators", None, "Cardiogenic Indicators", None, True, None, None, 10)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 11)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Pulmonary Edema':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        subtitle = alert.Subtitle
        break

#Check if alert was autoresolved or completed.
if validated is False:    
    #Find all discrete values for custom lookups within the last X days
    maindiscreteDic = {}
    unsortedDicsreteDic = {}
    dvCount = 0
    #Combine all items into one list to search against
    discreteSearchList = [i for j in [dvOxygenTherapy] for i in j]
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
    j690Code = codeValue("J69.0", "Aspiration Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j681Code = codeValue("J68.1", "Pulmonary Edema due to Chemicals, Gases, Fumes and Vapors: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    i501Code = codeValue("I50.1", "Pulmonary Edema with Heart Failure/Heart Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    acuteHFCodes = multiCodeValue(["I50.21", "I50.23", "I50.31", "I50.33", "I50.41", "I50.43", "I50.811", "I50.813"], "Acute Heart Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    acuteHFAbs = abstractValue("ACUTE_HEART_FAILURE", "Acute Heart Failure '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    acuteChronicHFAbs = abstractValue("ACUTE_ON_CHRONIC_HEART_FAILURE", "Acute on Chronic Heart Failure '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    #Alert Trigger
    chronicPulmonaryEdemaAbs = abstractValue("CHRONIC_PULMONARY_EDEMA", "Chronic Pulmonary Edema '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    j810Code = codeValue("J81.0", "Acute Pulmonary Edema: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j960Code = codeValue("J96.0", "Aspiration Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pulmonaryEdemaAbs = abstractValue("PULMONARY_EDEMA", "Pulmonary Edema '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    #Abs
    acuteRespFailure = multiCodeValue(["J96.00", "J96.01", "J96.02"], "Acute Respiratory Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    j80Code = codeValue("J80", "Acute Respiratory Distress Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    r079Code = codeValue("R07.9", "Chest Pain: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3)
    chestTightnessAbs = abstractValue("CHEST_TIGHTNESS", "Chest Tightness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4)
    cracklesAbs = abstractValue("CRACKLES", "Crankles '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7)
    r0600Code = codeValue("R06.00", "Dyspnea: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8)
    e8740Code = codeValue("E87.40", "Fluid Overloaded: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12)
    r042Code = codeValue("R04.2", "Hemoptysis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14)
    pinkFrothySputumAbs = abstractValue("PINK_FROTHY_SPUTUM", "Pink Frothy Sputum '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 18)
    r062Code = codeValue("R06.2", "Wheezing: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23)
    #Labs
    r0902Code = codeValue("R09.02", "Hypoxemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3)
    pAO2Dv = dvValue(dvPaO2, "pa02: [VALUE] (Result Date: [RESULTDATETIME])", calcPAO21, 4)
    #Meds
    diureticMed = abstractValue("DIURETIC", "Diuretic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4)
    sodiumNitroMed = medValue("Sodium Nitroprusside", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 6)
    vasodilatorMed = medValue("Vasodilator", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 7)
    #Oxygen
    flowNasalOxygen = multiCodeValue(["5A0935A", "5A0945A", "5A0955A"], "Flow Nasal Oxygen: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    a5a1945zCode = codeValue("5A1945Z", "Mechanical Ventilation 24 to 96 hours: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    a5a1955zCode = codeValue("5A1955Z", "Mechanical Ventilation Greater than 96 hours: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3)
    a5a1935zCode = codeValue("5A1935Z", "Mechanical Ventilation Less than 24 hours: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4)
    a3e0f7sfCode = codeValue("3E0F7SF", "Nasal Cannula: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5)
    nonInvasiveVentAbs = abstractValue("NON_INVASIVE_VENTILATION", "Non-Invasive Ventilation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6)
    oxygenTherapyDV = dvOxygenCheck(dict(maindiscreteDic), dvOxygenTherapy, "Oxygen Therapy '[VALUE]' (Result Date: [RESULTDATETIME])", 7)
    oxygenTherapyAbs = abstractValue("OXYGEN_THERAPY", "Oxygen Therapy '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8)
    #Vitals
    elevRightVentricleSyPressureAbs = abstractValue("ELEVATED_RIGHT_VENTRICLE_SYSTOLIC_PRESSUE", "Elevated Right Ventricle Systolic Pressure: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2)
    sp02Dv = dvValue(dvSPO2, "Sp02: [VALUE] (Result Date: [RESULTDATETIME])", calcSPO21, 4)
    highRespRateDv = dvValue(dvRespiratoryRate, "Respiratory Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcRespiratoryRate1, 5)
    #Cardiogenic Indicators
    codeValue("I51.1", "Acute Heart Valve Failure Rupture of Chordae Tendineae: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, cardiogenic, True)
    prefixCodeValue("^I21\.", "Acute Myocardial Infarction: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, cardiogenic, True)
    codeValue("I35.1", "Aortic Regurgitation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, cardiogenic, True)
    codeValue("I35.2", "Aortic Stenosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, cardiogenic, True)
    codeValue("I31.4", "Cardiac Tamponade: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, cardiogenic, True)
    prefixCodeValue("^I42\.", "Cardiomyopathy : [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, cardiogenic, True)
    dvValue(dvReducedEjectionFraction, "Ejection Fraction: [VALUE] (Result Date: [RESULTDATETIME])", calcReducedEjectionFraction1, 7, cardiogenic, True)
    abstractValue("REDUCED_EJECTION_FRACTION", "Ejection Fraction: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",  True, 8, cardiogenic, True)
    codeValue("I38", "Endocarditis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, cardiogenic, True)
    multiCodeValue(["I50.21", "I50.22", "I50.23", "I50.31", "I50.32", "I50.33", "I50.41", "I50.42", "I50.43",
        "I50.812 ", "I50.814", "I50.82", "I50.83", "I50.84", "I50.1", "I50.20", "I50.30", "I50.40",
        "I50.810", "I50.89", "I50.9"], "Heart Failure: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, cardiogenic, True)
    codeValue("I34.0", "Mitral Regurgitation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, cardiogenic, True)
    codeValue("I34.2", "Mitral Stenosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, cardiogenic, True)
    codeValue("I51.4", "Myocarditis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13, cardiogenic, True)
    codeValue("I31.39", "Pericardial Effusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, cardiogenic, True)
    codeValue("I51.2", "Rupture of Papillary Muscle: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, cardiogenic, True)
    codeValue("I49.01", "Ventricular Fibrillation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, cardiogenic, True)
    codeValue("I49.02", "Ventricular Flutter: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17, cardiogenic, True)
    prefixCodeValue("^I47\.2", "Ventricular Tachycardia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, cardiogenic, True)

    #Determining Clinical Indicators
    if acuteRespFailure is not None: abs.Links.Add(acuteRespFailure); CI += 1
    if j80Code is not None: abs.Links.Add(j80Code); CI += 1
    if r0902Code is not None or sp02Dv is not None or pAO2Dv is not None:
        if r0902Code is not None: abs.Links.Add(r0902Code)
        if sp02Dv is not None: vitals.Links.Add(sp02Dv)
        if pAO2Dv is not None: labs.Links.Add(pAO2Dv)
        CI += 1
    if highRespRateDv is not None: vitals.Links.Add(highRespRateDv); CI += 1
    if r079Code is not None: abs.Links.Add(r079Code); CI += 1
    if pinkFrothySputumAbs is not None: abs.Links.Add(pinkFrothySputumAbs); CI += 1
    if elevRightVentricleSyPressureAbs is not None: abs.Links.Add(elevRightVentricleSyPressureAbs); CI += 1
    if r0600Code is not None: abs.Links.Add(r0600Code); CI += 1
    if chestTightnessAbs is not None: abs.Links.Add(chestTightnessAbs); CI += 1
    if cracklesAbs is not None: abs.Links.Add(cracklesAbs); CI += 1
    if e8740Code is not None: abs.Links.Add(e8740Code); CI += 1
    if r042Code is not None: abs.Links.Add(r042Code); CI += 1
    if r062Code is not None: abs.Links.Add(r062Code); CI += 1
    
    #Treatment Check Count
    if diureticMed is not None: treatmentCheck += 1
    if sodiumNitroMed is not None: treatmentCheck += 1
    if vasodilatorMed is not None: treatmentCheck += 1
    if flowNasalOxygen is not None: treatmentCheck += 1
    if a5a1945zCode is not None: treatmentCheck += 1
    if a5a1955zCode is not None: treatmentCheck += 1
    if a5a1935zCode is not None: treatmentCheck += 1
    if a3e0f7sfCode is not None: treatmentCheck += 1
    if nonInvasiveVentAbs is not None: treatmentCheck += 1
    if oxygenTherapyDV is not None: treatmentCheck += 1
    if oxygenTherapyAbs is not None: treatmentCheck += 1

    #Main Algorithm
    if chronicPulmonaryEdemaAbs is not None or j810Code is not None or i501Code is not None or j681Code is not None or j960Code is not None or acuteHFCodes is not None or cardiogenic.Links:
        db.LogEvaluationScriptMessage("One specific code was on the chart, alert failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        if alertTriggered:
            if chronicPulmonaryEdemaAbs is not None: updateLinkText(chronicPulmonaryEdemaAbs, "Autoresolved Evidence - "); dc.Links.Add(chronicPulmonaryEdemaAbs)
            if j810Code is not None: updateLinkText(j810Code, "Autoresolved Code - "); dc.Links.Add(j810Code)
            if i501Code is not None: updateLinkText(i501Code, "Autoresolved Code - "); dc.Links.Add(i501Code)
            if j681Code is not None: updateLinkText(j681Code, "Autoresolved Code - "); dc.Links.Add(j681Code)
            if j960Code is not None: updateLinkText(j960Code, "Autoresolved Code - "); dc.Links.Add(j960Code)
            if acuteHFCodes is not None: updateLinkText(acuteHFCodes, "Autoresolved Code - "); dc.Links.Add(acuteHFCodes)
            result.Outcome = "AUTORESOLVED"
            result.Reason = "Autoresolved due to one Specified Code on the Account"
            result.Validated = True
            AlertConditions = True
        else: result.Passed = False
        
    elif (subtitle == "Possible Acute Pulmonary Edema" or subtitle == "Pulmonary Edema Documented Missing Acuity") and pulmonaryEdemaAbs is not None and acuteHFCodes is not None and j690Code is not None:
        if pulmonaryEdemaAbs is not None: updateLinkText(pulmonaryEdemaAbs, "Autoresolved Code - "); dc.Links.Add(pulmonaryEdemaAbs)
        if acuteHFCodes is not None: updateLinkText(acuteHFCodes, "Autoresolved Code - "); dc.Links.Add(acuteHFCodes)
        if j690Code is not None: updateLinkText(j690Code, "Autoresolved Code - "); dc.Links.Add(j690Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to specified dx existing now."
        result.Validated = True
        AlertConditions = True

    elif pulmonaryEdemaAbs is not None and codesExist == 0 and CI >= 2 and acuteHFCodes is None and j690Code is None and acuteHFAbs is None and acuteChronicHFAbs is None:
        dc.Links.Add(pulmonaryEdemaAbs)
        result.Subtitle = "Possible Acute Pulmonary Edema"
        AlertPassed = True
        
    elif pulmonaryEdemaAbs is not None and CI >= 2 and acuteHFCodes is None and j690Code is None:
        dc.Links.Add(pulmonaryEdemaAbs)
        result.Subtitle = "Pulmonary Edema Documented Missing Acuity"
        AlertPassed = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Abs
    #1-4
    codeValue("R23.1", "Cold Clammy Skin: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, abs, True)
    codeValue("I25.10", "Coronary Artery Disease  [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, abs, True)
    #7-8
    abstractValue("DYSPNEA_ON_EXERTION", "Dyspnea on Exertion '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, abs, True)
    abstractValue("EJECTION_FRACTION", "Ejection Fraction: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10, abs, True)
    codeValue("R53.83", "Fatigue: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, abs, True)
    #12
    abstractValue("HEART_PALPITATIONS", "Heart Palpitations '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13, abs, True)
    #14
    codeValue("I10", "HTN: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
    abstractValue("IRREGULAR_RADIOLOGY_REPORT_LUNGS", "Irregular Radiology Report Lungs '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 16, abs, True)
    abstractValue("LOWER_EXTREMITY_EDEMA", "Lower Extremity Edema '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 17, abs, True)
    #18
    abstractValue("PLEURAL_EFFUSION", "Pleural Effusion '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 19, abs, True)
    abstractValue("RESTLESSNESS", "Restlessness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 20, abs, True)
    abstractValue("SHORTNESS_OF_BREATH_LYING_FLAT", "Shortness of Breath Lying Flat '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 21, abs, True)
    codeValue("R61", "Sweating: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 22, abs, True)
    #23
    #Contributing Dx
    abstractValue("ASPIRATION", "Aspiration '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1, contri, True)
    multiCodeValue(["I46.2", "I46.8", "I46.9"], "Cardiac Arrest: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, contri, True)
    multiCodeValue(["T50.901A", "T50.902A", "T50.903A", "T50.904A"], "Drug Overdose: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, contri, True)
    codeValue("N18.6", "End-Stage Renal Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, contri, True)
    multiCodeValue(["T17.200A", "T17.290A", "T17.290A", "T17.300A", "T17.390A", "T17.400A",
        "T17.420A", "T17.490A", "T17.500A", "T17.590A", "T17.800A", "T17.890A"],
        "Foreign Body in Respiratory Tract Causing Asphyxiation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, contri, True)
    multiCodeValue(["T17.210A", "T17.310A", "T17.410A", "T17.510A", "T17.810A", "T17.910A"],
        "Gastric Contents in Respiratory Tract Causing Asphyxiation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, contri, True)
    multiCodeValue(["I16.0", "I16.1", "I16.9"], "Hypertensive Crisis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, contri, True)
    abstractValue("OPIOID_OVERDOSE", "Overdose '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, contri, True)
    codeValue("J69.1", "Pneumonitis due to Inhalation of Oils and Essences : [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, contri, True)
    codeValue("J68.1", "Pulmonary Edema due to Chemicals, Gases, Fumes and Vapors: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, contri, True)
    prefixCodeValue("^I26\.", "Pulmonary Embolism: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, contri, True)
    codeValue("J70.0", "Radiation Pneumonitis (Acute Pulmonary Manifestations due to Radiation): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, contri, True)
    multiCodeValue(["A41.2", "A41.3", "A41.4", "A41.50", "A41.51", "A41.52", "A41.53", "A41.54", "A41.59", "A41.81", "A41.89", "A41.9",
                                  "A42.7", "A22.7", "B37.7", "A26.7", "A54.86", "B00.7", "A32.7", "A24.1", "A20.7", "T81.44XA", "T81.44XD"],
                                 "Sepsis Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13, contri, True)
    prefixCodeValue("^T59\.4", "Toxic effect of Chlorine Gas: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, contri, True)
    prefixCodeValue("^T59\.5", "Toxic effect of Fluorine Gas: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, contri, True)
    prefixCodeValue("^T59\.2", "Toxic effect of Formaldehyde: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, contri, True)
    prefixCodeValue("^T59\.6", "Toxic effect of Hydrogen Sulfide: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17, contri, True)
    prefixCodeValue("^T59\.0", "Toxic effect of Nitrogen Oxides: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, contri, True)
    prefixCodeValue("^T59\.8", "Toxic effect of Smoke Inhalation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19, contri, True)
    prefixCodeValue("^T59\.1", "Toxic effect of Sulfur Dioxide: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20, contri, True)
    codeValue("J95.84", "Transfusion-Related Acute Lung Injury (TRALI): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21, contri, True)
    #Document Links
    documentLink("Chest  3 View", "Chest  3 View", 0, chestXRayLinks, True)
    documentLink("Chest  PA and Lateral", "Chest  PA and Lateral", 0, chestXRayLinks, True)
    documentLink("Chest  Portable", "Chest  Portable", 0, chestXRayLinks, True)
    documentLink("Chest PA and Lateral", "Chest PA and Lateral", 0, chestXRayLinks, True)
    documentLink("Chest  1 View", "Chest  1 View", 0, chestXRayLinks, True)
    documentLink("CT Thorax W", "CT Thorax W", 0, ctChestLinks, True)
    documentLink("CTA Thorax Aorta", "CTA Thorax Aorta", 0, ctChestLinks, True)
    documentLink("CT Thorax WO-Abd WO-Pel WO", "CT Thorax WO-Abd WO-Pel WO", 0, ctChestLinks, True)
    documentLink("CT Thorax WO", "CT Thorax WO", 0, ctChestLinks, True)
    #Labs
    dvValue(dvArterialBloodPH, "Arterial PH: [VALUE] (Result Date: [RESULTDATETIME])", calcArterialBloodPH1, 1, labs, True)
    dvValue(dvBNP, "BNP: [VALUE] (Result Date: [RESULTDATETIME])", calcBNP1, 2, labs, True)
    #3-4
    dvValue(dvArterialBloodC02, "paCO2: [VALUE] (Result Date: [RESULTDATETIME])", calcArterialBloodC021, 5, labs, True)
    dvValue(dvProBNP, "Pro BNP: [VALUE] (Result Date: [RESULTDATETIME])", calcProBNP1, 6, labs, True)
    dvValue(dvTroponinT, "Troponin T High Sensitivity: [VALUE] (Result Date: [RESULTDATETIME])", calcTroponinT1, 7, labs, True)
    #Meds
    medValue("Bronchodilator", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, meds, True)
    medValue("Bumetanide", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 2, meds, True)
    medValue("Sodium Nitroprusside", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 3, meds, True)
    if diureticMed is not None: meds.Links.Add(diureticMed) #4
    medValue("Furosemide", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 5, meds, True)
    if sodiumNitroMed is not None: meds.Links.Add(sodiumNitroMed) #6
    if vasodilatorMed is not None: meds.Links.Add(vasodilatorMed) #7
    #Oxygen
    if flowNasalOxygen is not None: oxygen.Links.Add(flowNasalOxygen) #1
    if a5a1945zCode is not None: oxygen.Links.Add(a5a1945zCode) #2
    if a5a1955zCode is not None: oxygen.Links.Add(a5a1955zCode) #3
    if a5a1935zCode is not None: oxygen.Links.Add(a5a1935zCode) #4
    if a3e0f7sfCode is not None: oxygen.Links.Add(a3e0f7sfCode) #5
    if nonInvasiveVentAbs is not None: oxygen.Links.Add(nonInvasiveVentAbs) #6
    if oxygenTherapyDV is not None: oxygen.Links.Add(oxygenTherapyDV) #7
    if oxygenTherapyAbs is not None: oxygen.Links.Add(oxygenTherapyAbs) #8
    abstractValue("VENTILATOR_DAYS", "Ventilator Days: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, oxygen, True)
    #Vitals
    dvValue(dvDBP, "Diastolic Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcDBP1, 1, vitals, True)
    #2
    dvValue(dvHeartRate, "Heart Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcHeartRate1, 3, vitals, True)
    #4-5
    dvValue(dvSBP, "Systolic Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcSBP1, 6, vitals, True)

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if cardiogenic.Links: result.Links.Add(cardiogenic); cardiogenicLinks = True
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    if vitals.Links: result.Links.Add(vitals); vitalsLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    if oxygen.Links: result.Links.Add(oxygen); oxygenLinks = True
    if chestXRayLinks.Links: result.Links.Add(chestXRayLinks); docLinksLinks = True
    if ctChestLinks.Links: result.Links.Add(ctChestLinks); docLinksLinks = True
    if contri.Links: result.Links.Add(contri); contriLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Documented Dx- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks) + ", vitals- " + str(vitalsLinks) + ", meds- " + str(medsLinks) + ", oxygen- " + str(oxygenLinks) + ", contri- "
        + str(contriLinks) + ", docs- " + str(docLinksLinks) + ", cardiogenic- " + str(cardiogenicLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
