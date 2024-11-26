##################################################################################################################
#Evaluation Script - Acidosis
#
#This script checks an account to see if it matches criteria to be alerted for Acidosis
#Date - 11/24/2024
#Version - V25
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
    "E87.21": "Acute Metabolic Acidosis",
    "E10.10": "Type 1 diabetes mellitus with ketoacidosis without coma",
    "E10.11": "Type 1 diabetes mellitus with ketoacidosis with coma",
    "E11.10": "Type 2 diabetes mellitus with ketoacidosis without coma",
    "E11.11": "Type 2 diabetes mellitus with ketoacidosis with coma",
    "E13.10": "Other specified diabetes mellitus with ketoacidosis without coma",
    "E13.11": "Other specified diabetes mellitus with ketoacidosis with coma",
    "E09.10": "Drug or chemical induced diabetes mellitus with ketoacidosis without coma",
    "E09.11": "Drug or chemical induced diabetes mellitus with ketoacidosis with coma",
    "P74.0": "Late metabolic acidosis of newborn",
    "E08.11": "Diabetes mellitus due to underlying condition with ketoacidosis with coma",
    "E09.11": "Drug or chemical induced diabetes mellitus with ketoacidosis with coma",
    "E10.11": "Type 1 diabetes mellitus with ketoacidosis with coma",
    "E11.11": "Type 2 diabetes mellitus with ketoacidosis with coma",
    "E13.11": "Other specified diabetes mellitus with ketoacidosis with coma",
    "E08.10": "Diabetes mellitus due to underlying condition with ketoacidosis without coma",
    "E08.11": "Diabetes mellitus due to underlying condition with ketoacidosis with coma",
    "E13.10": "Other specified diabetes mellitus with ketoacidosis without coma",
    "E13.11": "Other specified diabetes mellitus with ketoacidosis with coma",
    "E10.10": "Type 1 diabetes mellitus with ketoacidosis without coma",
    "E10.11": "Type 1 diabetes mellitus with ketoacidosis with coma",
    "E11.10": "Type 2 diabetes mellitus with ketoacidosis without coma",
    "E11.11": "Type 2 diabetes mellitus with ketoacidosis with coma",
    "E87.4": "Mixed disorder of acid-base balance",
    "E87.22": "Chronic Metabolic Acidosis"
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
dvAnionGap = [""]
calcAnionGap1 = lambda x: x > 14
dvArterialBloodPH = ["pH"]
calcArterialBloodPH1 = lambda x: x < 7.32
calcArterialBloodPH2 = 7.32
dvBaseExcess = ["BASE EXCESS (mmol/L)"]
calcBaseExcess1 = lambda x: x < -2
dvBloodCO2 = ["CO2 (mmol/L)"]
calcBloodCO21 = 21
calcBloodCO22 = lambda x: x > 32
dvBloodGlucose = [ "GLUCOSE (mg/dL)", "GLUCOSE"]
calcBloodGlucose1 = lambda x: x > 250
dvBloodGlucosePOC = ["GLUCOSE ACCUCHECK (mg/dL)"]
calcBloodGlucosePOC1 = lambda x: x > 250
dvFIO2 = ["FIO2"]
calcFIO21 = lambda x: x <= 100
dvGlasgowComaScale = ["3.5 Neuro Glasgow Score"]
calcGlasgowComaScale1 = lambda x: x < 15
dvHCO3 = ["HCO3 VENOUS (meq/L)"]
calcHCO31 = 22
calcHCO32 = 26
dvHeartRate = ["Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)", "3.5 Heart Rate (Radial) (bpm)",  "SCC Monitor Pulse (bpm)"]
calcHeartRate1 = lambda x: x > 90
dvMAP = ["Mean 3.5 (No Calculation) (mm Hg)", "Mean 3.5 DI (mm Hg)"]
calcMAP1 = lambda x: x < 70
dvPaO2 = ["BLD GAS O2 (mmHg)"]
calcPAO21 = 60
dvPO2 = ["BLD GAS O2 (mmHg)", "PO2 (mmHg)"]
calcPO21 = lambda x: x < 80
dvPCO2 = ["BLD GAS CO2 (mmHg)", "PaCO2 (mmHg)"]
calcPCO21 = 50
calcPCO22 = lambda x: x < 30
dvPH = ["pH (VENOUS)", "pH VENOUS"]
calcPH1 = lambda x: x < 7.30
calcPH2 = 7.30
dvRespiratoryRate = ["3.5 Respiratory Rate (#VS I&O) (per Minute)"]
calcRespiratoryRate1 = lambda x: x > 20
calcRespiratoryRate2 = lambda x: x < 12
dvSBP = ["SBP 3.5 (No Calculation) (mm Hg)"]
calcSBP1 = lambda x: x < 90
dvSerumBloodUreaNitrogen = ["BUN (mg/dL)"]
calcSerumBloodUreaNitrogen1 = lambda x: x > 23
dvSerumBicarbonate = ["HCO3 (meq/L)", "HCO3 (mmol/L)"]
calcSerumBicarbonate1 = 26
calcSerumBicarbonate3 = lambda x: x < 22
dvSerumChloride = ["CHLORIDE (mmol/L)"]
calcSerumChloride1 = lambda x: x > 107
dvSerumCreatinine = ["CREATININE (mg/dL)", "CREATININE SERUM (mg/dL)"]
calcSerumCreatinine1 = lambda x: x > 1.3
dvSerumLactate = ["LACTIC ACID (mmol/L)", "LACTATE (mmol/L)"]
calcSerumLactate1 = 4
calcSerumLactate2 = lambda x: 2 < x < 4
dvSPO2 = ["Pulse Oximetry(Num) (%)"]
calcSPO21 = lambda x: x < 90
dvVenousBloodCO2 = ["BLD GAS CO2 VEN (mmHg)"]
calcVenousBloodCO2 = 55

dvSerumKetone = ["KETONES (mg/dL)"]
calcSerumKetone1 = lambda x: x > 0
dvUrineKetones = ["UR KETONES (mg/dL)", "KETONES (mg/dL)"]

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

def limitedMedValue(medDic, dvDic, med_name, value1, value2, value3, link_text, sequence=0, category=None, abstract=False):
    dvDic = {}
    dateList = []
    matchedList = []
    duplicateCheck = []
    id = None
    if value1 is not None:
        for item in value1 or []:
            id = item.DiscreteValueId
            for dv in dvDic or []:
                if dvDic[dv]['UniqueId'] == id or dvDic[dv]['_id'] == id:
                    if dvDic[dv]['ResultDate'] not in dateList:
                        dateList.append(dvDic[dv]['ResultDate'])
    if value2 is not None:
        for item in value2 or []:
            id = item.DiscreteValueId
            for dv in dvDic or []:
                if dvDic[dv]['UniqueId'] == id or dvDic[dv]['_id'] == id:
                    if dvDic[dv]['ResultDate'] not in dateList:
                        dateList.append(dvDic[dv]['ResultDate'])
    if value3 is not None:
        for item in value2 or []:
            id = item.DiscreteValueId
            for dv in dvDic or []:
                if dvDic[dv]['UniqueId'] == id or dvDic[dv]['_id'] == id:
                    if dvDic[dv]['ResultDate'] not in dateList:
                        dateList.append(dvDic[dv]['ResultDate'])
    for item in dateList:
        dateLimit = item.AddHours(-12)
        dateLimit2 = item.AddHours(12)
        for mv in medDic or []:
            if (
                medDic[mv]['Route'] is not None and
                medDic[mv]['CDIAlertCategory'] == med_name and
                dateLimit <= medDic[mv]['StartDate'] <= dateLimit2
            ):
                matchedList = medDataConversion(medDic[mv]['StartDate'], link_text, medDic[mv]['Medication'], medDic[mv]['ExternalId'], medDic[mv]['Dosage'], medDic[mv]['Route'], category, sequence, False)
    
    for item in matchedList:
        if item.MedicationId not in duplicateCheck:
            duplicateCheck.append(item.MedicationId)
        elif item.MedicationId in duplicateCheck:
            matchedList.remove(item)

    if abstract == True and len(matchedList) > 0:
        for item in matchedList:
            category.Links.Add(item)
        return True
    elif abstract == False and len(matchedList) > 0:
        return matchedList
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
        abstraction.MedicationName = med
        category.Links.Add(abstraction)
    elif abstract == False:
        abstraction = MatchedCriteriaLink(linkText, None, None, None, True, None, None, sequence)
        abstraction.MedicationId = id
        abstraction.MedicationName = med
        return abstraction
    return

#========================================
#  Algorithm
#========================================
db.LogEvaluationScriptMessage("Starting Script " + str(account._id), scriptName, scriptInstance, "Debug")
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
abgLinks = False
vbgLinks = False
documentedDxTriggerLinks = False
absLinks = False
labsLinks = False
vitalsLinks = False
medsLinks = False
noLabs = []
fullSpec = False
unSpec = False

#Initalize categories
documentedDx = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 2)
vitals = MatchedCriteriaLink("Vital Signs/Intake and Output Data", None, "Vital Signs/Intake and Output Data", None, True, None, None, 3)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 4)
meds = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 5)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 6)
abg = MatchedCriteriaLink("ABG", None, "ABG", None, True, None, None, 88)
vbg = MatchedCriteriaLink("VBG", None, "VBG", None, True, None, None, 89)
blood = MatchedCriteriaLink("Blood C02", None, "Blood C02", None, True, None, None, 91)
ph = MatchedCriteriaLink("PH", None, "PH", None, True, None, None, 92)
lactate = MatchedCriteriaLink("Lactate", None, "Lactate", None, True, None, None, 93)
venousCO2 = MatchedCriteriaLink("pC02", None, "pC02", None, True, None, None, 94)
vbghc02 = MatchedCriteriaLink("HC03", None, "HC03", None, True, None, None, 95)
pao2 = MatchedCriteriaLink("pa02", None, "pa02", None, True, None, None, 96)
abghc02 = MatchedCriteriaLink("HC03", None, "HC03", None, True, None, None, 97)
pc02 = MatchedCriteriaLink("PC02", None, "PC02", None, True, None, None, 98)
pac02 = MatchedCriteriaLink("paC02", None, "paC02", None, True, None, None, 99)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Acidosis':
        alertTriggered = True
        validated = alert.IsValidated
        subtitle = alert.Subtitle
        outcome = alert.Outcome
        subtitle = alert.Subtitle
        break

#Pulling needed items for unresolving an alert
#Documented Dx
chronicRespAcidosisAbs = abstractValue("CHRONIC_RESPIRATORY_ACIDOSIS", "Chronic Respiratory Acidosis '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
metaAcidosisAbs = abstractValue("METABOLIC_ACIDOSIS", "Metabolic Acidosis '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
acuteAcidosisAbs = abstractValue("ACUTE_ACIDOSIS", "Acute Acidosis '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
chronicAcidosisAbs = abstractValue("CHRONIC_ACIDOSIS", "Chronic Acidosis '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
LacticAcidosisAbs = abstractValue("LACTIC_ACIDOSIS", "Lactic Acidosis '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
e8720Code = codeValue("E87.20", "Acidosis Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
e8729Code = codeValue("E87.29", "Other Acidosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")

#Check if alert was autoresolved or completed.
if validated is False:
    #Find all discrete values for custom lookups within the last X days
    maindiscreteDic = {}
    unsortedDicsreteDic = {}
    dvCount = 0
    #Set datelimit for how far back to 
    dvDateLimit = System.DateTime.Now.AddDays(-7)
    #Combine all items into one list to search against
    discreteSearchList = [i for j in [dvBloodCO2, dvSerumLactate, dvArterialBloodPH, dvPH, dvPCO2, dvSerumBicarbonate, dvVenousBloodCO2, dvUrineKetones] for i in j]
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
    medSearchList = ["Albumin", "Fluid Bolus", "Sodium Bicarbonate"]
    #Set datelimit for how far back to 
    medDateLimit = System.DateTime.Now.AddDays(-7)
    #Loop through all meds finding any that match in the combined list adding to a dictionary the matches
    if 'Medications' in account:    
        for med in account.Medications:
            if med.StartDate >= medDateLimit and 'CDIAlertCategory' in med and med.CDIAlertCategory is not None:
                if any(item == med.CDIAlertCategory for item in medSearchList):
                    medCount += 1
                    unsortedMedDic[medCount] = med
    #Sort List by latest
    mainMedDic = sorted(unsortedMedDic.items(), key=lambda x: x[1]['StartDate'], reverse=True)
    
    #Documented Dx
    acuteRespAcidosisAbs = abstractValue("ACUTE_RESPIRATORY_ACIDOSIS", "Acute Respiratory Acidosis '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    j9602Code = codeValue("J96.02", "Acute Respiratory Failure with Hypercapnia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Labs Subheading
    bloodCO2MultiDV = dvValueMulti(dict(maindiscreteDic), dvBloodCO2, "Blood CO2: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodCO21, lt, 0, blood, False, 10)
    highSerumLactateDV = dvValueMulti(dict(maindiscreteDic), dvSerumLactate, "Serum Lactate: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumLactate1, ge, 0, lactate, False, 10)

    #abg Subheading
    lowArterialBloodPHMultiDV = dvValueMulti(dict(maindiscreteDic), dvArterialBloodPH, "PH: [VALUE] (Result Date: [RESULTDATETIME])", calcArterialBloodPH2, lt, 0, ph, False, 10)
    paco2Dv = dvValueMulti(dict(maindiscreteDic), dvPCO2, "paC02: [VALUE] (Result Date: [RESULTDATETIME])", calcPCO21, gt, 0, pac02, False, 10)
    highSerumBicarbonateDV = dvValueMulti(dict(maindiscreteDic), dvSerumBicarbonate, "HC03: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumBicarbonate1, gt, 0, abghc02, False, 10)
    #vbg Subheading
    phMultiDV = dvValueMulti(dict(maindiscreteDic), dvPH, "PH: [VALUE] (Result Date: [RESULTDATETIME])", calcPH2, lt, 0, ph, False, 10)
    venousCO2Dv = dvValueMulti(dict(maindiscreteDic), dvVenousBloodCO2, "pC02: [VALUE] (Result Date: [RESULTDATETIME])", calcVenousBloodCO2, gt, 0, venousCO2, False, 10)
    #Meds
    albuminMed = limitedMedValue(dict(mainMedDic), dict(maindiscreteDic), "Albumin", lowArterialBloodPHMultiDV, phMultiDV, bloodCO2MultiDV, "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1)
    fluidBolusMed = limitedMedValue(dict(mainMedDic), dict(maindiscreteDic), "Fluid Bolus", lowArterialBloodPHMultiDV, phMultiDV, bloodCO2MultiDV, "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 2)
    fluidBolusAbs = abstractValue("FLUID_BOLUS", "Fluid Bolus: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3)
    fluidResucAbs = abstractValue("FLUID_RESUSCITATION", "Fluid Resuscitation: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4)
    sodiumBicarMed = limitedMedValue(dict(mainMedDic), dict(maindiscreteDic), "Sodium Bicarbonate", lowArterialBloodPHMultiDV, phMultiDV, bloodCO2MultiDV, "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 5)
    sodiumBicarbonateAbs = abstractValue("SODIUM_BICARBONATE", "Sodium Bicarbonate: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6)
    
    #Fully Specified exist
    if (
        codesExist >= 1 or 
        chronicRespAcidosisAbs is not None or 
        LacticAcidosisAbs is not None or 
        metaAcidosisAbs is not None
    ):
        fullSpec = True
    
    #Unspecified exist
    if (
        e8720Code is not None or
        e8729Code is not None or
        acuteAcidosisAbs is not None or
        chronicAcidosisAbs is not None
    ):
        unSpec = True

    #Main Algorithm
    #1.1    
    if subtitle == "Possible Acute Respiratory Acidosis" and (acuteRespAcidosisAbs is not None or j9602Code is not None):
        if codesExist >= 1:
            for code in codeList:
                desc = codeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    documentedDx.Links.Add(tempCode)
                    break
        if j9602Code is not None: updateLinkText(j9602Code, autoEvidenceText); documentedDx.Links.Add(j9602Code)
        if acuteRespAcidosisAbs is not None: updateLinkText(acuteRespAcidosisAbs, autoEvidenceText); documentedDx.Links.Add(acuteRespAcidosisAbs)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertPassed = True
    #1.0    
    elif (
        acuteRespAcidosisAbs is None and 
        unSpec and
        j9602Code is None and
        (venousCO2Dv is not None or paco2Dv is not None) and 
        (len(lowArterialBloodPHMultiDV or noLabs) >= 1 or len(phMultiDV or noLabs) >= 1)
    ):
        if e8720Code is not None: documentedDx.Links.Add(e8720Code)
        if e8729Code is not None: documentedDx.Links.Add(e8729Code)
        if acuteAcidosisAbs is not None: documentedDx.Links.Add(acuteAcidosisAbs)
        if chronicAcidosisAbs is not None: documentedDx.Links.Add(chronicAcidosisAbs)
        result.Subtitle = "Possible Acute Respiratory Acidosis"
        AlertPassed = True
    #2.1    
    elif (
        subtitle == "Acute Respiratory Acidosis Documented Possibly Lacking Supporting Evidence" and 
        (venousCO2Dv is not None or paco2Dv is not None) and 
        (len(lowArterialBloodPHMultiDV or noLabs) >= 1 or len(phMultiDV or noLabs) >= 1)
    ):
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertPassed = True
    #2.0
    elif (
        acuteRespAcidosisAbs is not None and 
        venousCO2Dv is None and 
        paco2Dv is None and 
        len(lowArterialBloodPHMultiDV or noLabs) == 0 and 
        len(phMultiDV or noLabs) == 0
    ):
        if acuteRespAcidosisAbs is not None: documentedDx.Links.Add(acuteRespAcidosisAbs)
        result.Subtitle = "Acute Respiratory Acidosis Documented Possibly Lacking Supporting Evidence"
        AlertPassed = True    
        
    #3.1/4.1    
    elif (subtitle == "Possible Lactic Acidosis" or subtitle == "Possible Acidosis" )and (unSpec or fullSpec):
        if codesExist >= 1:
            for code in codeList:
                desc = codeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    documentedDx.Links.Add(tempCode)
                    break
        if LacticAcidosisAbs is not None: updateLinkText(LacticAcidosisAbs, autoEvidenceText); documentedDx.Links.Add(LacticAcidosisAbs)
        if chronicRespAcidosisAbs is not None: updateLinkText(chronicRespAcidosisAbs, autoEvidenceText); documentedDx.Links.Add(chronicRespAcidosisAbs)
        if metaAcidosisAbs is not None: updateLinkText(metaAcidosisAbs, autoEvidenceText); documentedDx.Links.Add(metaAcidosisAbs)
        if e8720Code is not None: updateLinkText(e8720Code, autoEvidenceText); documentedDx.Links.Add(e8720Code)
        if e8729Code is not None: updateLinkText(e8729Code, autoEvidenceText); documentedDx.Links.Add(e8729Code)
        if acuteAcidosisAbs is not None: updateLinkText(acuteAcidosisAbs, autoEvidenceText); documentedDx.Links.Add(acuteAcidosisAbs)
        if chronicAcidosisAbs is not None: updateLinkText(chronicAcidosisAbs, autoEvidenceText); documentedDx.Links.Add(chronicAcidosisAbs)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #3.0    
    elif fullSpec is False and unSpec is False and highSerumLactateDV is not None:
        result.Subtitle = "Possible Lactic Acidosis"
        AlertPassed = True
    #4.0
    elif (
        unSpec is False and
        fullSpec is False and
        (len(lowArterialBloodPHMultiDV or noLabs) > 1 or len(phMultiDV or noLabs) > 1 or len(bloodCO2MultiDV or noLabs) > 1) or
        (((len(lowArterialBloodPHMultiDV or noLabs) == 1 or len(phMultiDV or noLabs) == 1 or len(bloodCO2MultiDV or noLabs) == 1)) and
        (albuminMed is not None or fluidBolusMed is not None or fluidBolusAbs is not None or 
        fluidResucAbs is not None or sodiumBicarMed is not None or sodiumBicarbonateAbs is not None))
    ):
        if fluidBolusAbs is not None: meds.Links.Add(fluidBolusAbs)
        if fluidResucAbs is not None: meds.Links.Add(fluidResucAbs)
        if sodiumBicarbonateAbs is not None: meds.Links.Add(sodiumBicarbonateAbs)
        if albuminMed is not None: 
            for item in albuminMed or []:
                meds.Links.Add(item)
        if fluidBolusMed is not None: 
            for item in fluidBolusMed or []:
                meds.Links.Add(item)
        if sodiumBicarMed is not None: 
            for item in sodiumBicarMed or []:
                meds.Links.Add(item)
        result.Subtitle = "Possible Acidosis"
        AlertPassed = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #abs
    r4182Code = codeValue("R41.82", "Altered Level Of Consciousness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    alteredAbs = abstractValue("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level Of Consciousness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2)
    if r4182Code is not None:
        abs.Links.Add(r4182Code)
        if alteredAbs is not None: alteredAbs.Hidden = True; abs.Links.Add(alteredAbs)
    elif r4182Code is None and alteredAbs is not None:
        abs.Links.Add(alteredAbs)
    abstractValue("AZOTEMIA", "Azotemia '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3, abs, True)
    codeValue("R11.14", "Bilious Vomiting: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, abs, True)
    codeValue("R11.15", "Cyclical Vomiting: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, abs, True)
    abstractValue("DIARRHEA", "Diarrhea '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6, abs, True)
    codeValue("R41.0", "Disorientation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, abs, True)
    dvValue(dvFIO2, "Fi02: [VALUE] (Result Date: [RESULTDATETIME])", calcFIO21, 8, abs, True)
    codeValue("R53.83", "Fatigue: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8, abs, True)
    abstractValue("OPIOID_OVERDOSE", "Opioid Overdose '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11, abs, True)
    abstractValue("SHORTNESS_OF_BREATH", "Shortness of Breath '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13, abs, True)
    codeValue("R11.10", "Vomiting: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, abs, True)
    codeValue("R11.13", "Vomiting Fecal Matter: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
    codeValue("R11.11", "Vomiting Without Nausea: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, abs, True)
    abstractValue("WEAKNESS", "Weakness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 17, abs, True)
    #Labs
    dvValue(dvAnionGap, "Anion Gap: [VALUE] (Result Date: [RESULTDATETIME])", calcAnionGap1, 1, labs, True)
    if not dvValue(dvBloodGlucose, "Blood Glucose: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodGlucose1, 2, labs, True):
        dvValue(dvBloodGlucosePOC, "Blood Glucose POC: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodGlucosePOC1, 3, labs, True)
    abstractValue("POSITIVE_KETONES_IN_URINE", "Positive Ketones In Urine: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4, labs, True)
    dvValue(dvSerumBloodUreaNitrogen, "Serum Blood Urea Nitrogen: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumBloodUreaNitrogen1, 5, labs, True)
    dvValue(dvSerumChloride, "Serum Chloride: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumChloride1, 6, labs, True)
    dvValue(dvSerumCreatinine, "Serum Creatinine: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumCreatinine1, 7, labs, True)
    dvValue(dvSerumKetone, "Serum Ketones: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumKetone1, 8, labs, True)
    dvPositiveCheck(dict(maindiscreteDic), dvUrineKetones, "Urine Ketones: '[VALUE]' (Result Date: [RESULTDATETIME])", 9, labs, True)
    #Lab Subheading
    dvValue(dvSerumLactate, "Serum Lactate: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumLactate2, 0, lactate, True)
    if highSerumLactateDV is not None:
        for entry in highSerumLactateDV:
            lactate.Links.Add(entry) #0
    if lowArterialBloodPHMultiDV is not None:
        for entry in lowArterialBloodPHMultiDV:
            ph.Links.Add(entry) #0
    if phMultiDV is not None:
        for entry in phMultiDV:
            ph.Links.Add(entry) #0
    dvValue(dvBloodCO2, "Blood CO2: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodCO22, 0, blood, True)
    if bloodCO2MultiDV is not None:
        for entry in bloodCO2MultiDV:
            blood.Links.Add(entry) #0
    #Vitals
    dvValue(dvGlasgowComaScale, "Glasgow Coma Score: [VALUE] (Result Date: [RESULTDATETIME])", calcGlasgowComaScale1, 1, vitals, True)
    dvValue(dvHeartRate, "Heart Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcHeartRate1, 2, vitals, True)
    dvValue(dvMAP, "Mean Arterial Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcMAP1 , 3, vitals, True)
    dvValue(dvRespiratoryRate, "Respiratory Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcRespiratoryRate2, 4, vitals, True)
    dvValue(dvRespiratoryRate, "Respiratory Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcRespiratoryRate1, 5, vitals, True)
    dvValue(dvSPO2, "Sp02: [VALUE] (Result Date: [RESULTDATETIME])", calcSPO21, 6, vitals, True)
    dvValue(dvSBP, "Systolic Blood Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcSBP1, 7, vitals, True)
    #ABG
    dvValue(dvBaseExcess, "Base Excess: [VALUE] (Result Date: [RESULTDATETIME])", calcBaseExcess1, 1, abg, True)
    dvValue(dvFIO2, "Fi02: [VALUE] (Result Date: [RESULTDATETIME])", calcFIO21, 2, abg, True)
    dvValue(dvPO2, "p02: [VALUE] (Result Date: [RESULTDATETIME])", calcPO21, 3, abg, True)
    if paco2Dv is not None: 
        for entry in paco2Dv:
            pac02.Links.Add(entry) #0
    if paco2Dv is None:
        dvValue(dvPCO2, "paC02: [VALUE] (Result Date: [RESULTDATETIME])", calcPCO22, 0, pac02, True)
    if highSerumBicarbonateDV is not None:
        for entry in highSerumBicarbonateDV:
            abghc02.Links.Add(entry) #0
    elif highSerumBicarbonateDV is None:
        dvValue(dvSerumBicarbonate, "HC03: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumBicarbonate3, 0, abghc02, True)
    #ABG Subheadings
    dvValueMulti(dict(maindiscreteDic), dvPaO2, "PaO2: [VALUE] (Result Date: [RESULTDATETIME])", calcPAO21, lt, 0, pao2, True, 10)
    #VBG Subheadings
    dvValueMulti(dict(maindiscreteDic), dvHCO3, "HC03: [VALUE] (Result Date: [RESULTDATETIME])", calcHCO31, lt, 0, vbghc02, True, 10)
    dvValueMulti(dict(maindiscreteDic), dvHCO3, "HC03: [VALUE] (Result Date: [RESULTDATETIME])", calcHCO32, gt, 0, vbghc02, True, 10)
    if venousCO2Dv is not None:
        for entry in venousCO2Dv:
            venousCO2.Links.Add(entry) #0
            
#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if pac02.Links: abg.Links.Add(pac02); abgLinks = True
    if pc02.Links: abg.Links.Add(pc02); abgLinks = True
    if pao2.Links: abg.Links.Add(pao2); abgLinks = True
    if abghc02.Links: abg.Links.Add(abghc02); abgLinks = True
    if abg.Links: labs.Links.Add(abg); abgLinks = True
    if vbghc02.Links: vbg.Links.Add(vbghc02); vbgLinks = True
    if venousCO2.Links: vbg.Links.Add(venousCO2); vbgLinks = True
    if vbg.Links: labs.Links.Add(vbg); vbgLinks = True
    if blood.Links: labs.Links.Add(blood); labsLinks = True
    if ph.Links: labs.Links.Add(ph); labsLinks = True
    if lactate.Links: labs.Links.Add(lactate); labsLinks = True
    if documentedDx.Links: result.Links.Add(documentedDx); documentedDxTriggerLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    if vitals.Links: result.Links.Add(vitals); vitalsLinks = True
    result.Links.Add(meds)
    result.Links.Add(other)
    if meds.Links: medsLinks = True
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: documentedDx- " + str(documentedDxTriggerLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks) + ", vitals- " + str(vitalsLinks)
        + ", meds- " + str(medsLinks) + ", abg- " + str(abgLinks) + ", vbg- " + str(vbgLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
