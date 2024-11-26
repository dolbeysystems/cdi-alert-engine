##################################################################################################################
#Evaluation Script - Diabetes and Ketoacidosis, Hyperosmolarity and Coma
#
#This script checks an account to see if it matches criteria to be alerted for Diabetes and Ketoacidosis, Hyperosmolarity and Coma
#Date - 11/19/2024
#Version - V18
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
dvAcetone = [""]
calcAcetone1 = lambda x: x > 0
dvAnionGap = [""]
calcAnionGap1 = lambda x: x > 14
dvArterialBloodPH = ["pH"]
calcArterialBloodPH1 = lambda x: x < 7.35
dvBetaHydroxybutyrate = ["BETAHYDROXY BUTYRATE (mmol/L)"]
calcBetaHydroxybutyrate1 = lambda x: x > 0.27
dvBloodGlucose = ["GLUCOSE (mg/dL)", "GLUCOSE"]
calcBloodGlucose1 = 600
calcBloodGlucose2 = 70
calcBloodGlucose3 = 250
dvBloodGlucosePOC = ["GLUCOSE ACCUCHECK (mg/dL)"]
calcBloodGlucosePOC1 = 250
calcBloodGlucosePOC2 = 600
calcBloodGlucosePOC3 = 70
dvGlasgowComaScale = ["3.5 Neuro Glasgow Score"]
calcGlasgowComaScale1 = lambda x: x < 8
dvHeartRate = ["Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)", "3.5 Heart Rate (Radial) (bpm)",  "SCC Monitor Pulse (bpm)"]
calcHeartRate1 = lambda x: x > 90
dvHemoglobinA1c = ["HEMOGLOBIN A1C (%)"]
calcHemoglobinA1c1 = lambda x: x > 0
dvSerumBicarbonate = ["HCO3 (meq/L)", "HCO3 (mmol/L)", "HCO3 VENOUS (meq/L)"]
calcSerumBicarbonate1 = lambda x: x < 22
dvSerumKetone = [""]
calcSerumKetone1 = lambda x: x > 0
dvSerumOsmolality = ["OSMOLALITY (mOsm/kg)"]
calcSerumOsmolality1 = lambda x: x > 320
dvTemperature = ["Temperature Degrees C 3.5 (degrees C)", "Temperature  Degrees C 3.5 (degrees C)", "TEMPERATURE (C)"]
calcTemperature1 = lambda x: x > 38.3
dvUrineKetone = ["UR KETONES (mg/dL)", "KETONES (mg/dL)"]
calcUrineKetone1 = lambda x: x > 0

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
            dvDic[dv]['Result'] is not None
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
#Standard Variable Declaration
AlertPassed = False
alertTriggered = False
AlertConditions = False
validated = False
outcome = None
subtitle = None
SoC = False
DKA = 0
HHNS = 0
DKAAlertPassed = False
HHNSAlertPassed = False
DKACheck = False
dcLinks = False
absLinks = False
labsLinks = False
vitalsLinks = False
medsLinks = False
comaLinks = False
noLabs = []

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 2)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 3)
coma = MatchedCriteriaLink("Signs of Coma", None, "Signs of Coma", None, True, None, None, 4)
vitals = MatchedCriteriaLink("Vital Signs/Intake and Output Data", None, "Vital Signs/Intake and Output Data", None, True, None, None, 5)
meds = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 6)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 7)
bloodGlucose = MatchedCriteriaLink("Blood Glucose", None, "Blood Glucose", None, True, None, None, 88)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Diabetes':
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
    discreteSearchList = [i for j in [dvOxygenTherapy, dvBloodGlucose, dvBloodGlucosePOC] for i in j]
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
    e1011Code = codeValue("E10.11", "Type 1 Diabetes Mellitus With Ketoacidosis With Coma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    e1641Code = codeValue("E10.641", "Type 1 Diabetes Mellitus With Hypoglycemia With Coma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    e1101Code = codeValue("E11.01", "Type 2 Diabetes Mellitus With Hyperosmolarity With Coma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    e1111Code = codeValue("E11.11", "Type 2 Diabetes Mellitus With Ketoacidosis With Coma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    e11641Code = codeValue("E11.641", "Type 2 Diabetes Mellitus With Hypoglycemia With Coma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    e10649Code = codeValue("E10.649", "Type 1 Diabetes with Hypoglycemia without Coma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    e10641Code = codeValue("E10.641", "Type 1 Diabetes Mellitus with Hypoglycemia with Coma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    r4020Code = codeValue("R40.20", "Unspecified Coma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    unspecTypeIDiabetes = abstractValue("DIABETES_TYPE_1", "Type 1 Diabetes Present: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    e1010Code = codeValue("E10.10", "Type 1 Diabetes with Ketoacidosis without Coma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    unspecTypeIIDiabetes = abstractValue("DIABETES_TYPE_2", "Type 2 Diabetes Present: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    e1100Code = codeValue("E11.00", "Type 2 Diabetes Mellitus With Hyperosmolarity Without Nonketotic Hyperglycemic-Hyperosmolar Coma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    e1110Code = codeValue("E11.10", "Type 2 Diabetes Mellitus With Ketoacidosis Without Coma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    e1165Code = codeValue("E11.65", "Type 2 Diabetes Mellitus With Hyperglycemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    e11649Code = codeValue("E11.649", "Type 2 Diabetes Mellitus With Hypoglycemia Without Coma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Abs
    r824Code = codeValue("R82.4", "Ketonuria : [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12)
    #Coma
    decrLvlConsciousnessAbs = abstractValue("DECREASED_LEVEL_OF_CONSCIOUSNESS", "Decreased Level of Consciousness: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1)
    glasgowComaScoreDV = dvValue(dvGlasgowComaScale, "Glasgow Coma Score: [VALUE] (Result Date: [RESULTDATETIME])", calcGlasgowComaScale1, 2)
    glasgowComaScoreAbs = abstractValue("LOW_GLASGOW_COMA_SCORE_SEVERE", "Glasgow Coma Score: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3)
    a5a193Codes = multiCodeValue(["5A1935Z", "5A1945Z", "5A1955Z"], "Invasive Mechanical Ventilation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4)
    obtundedAbs = abstractValue("OBTUNDED", "Obtunded: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5)
    a0bh18ezCode = multiCodeValue(["0BH18EZ", "0BH17EZ"], "Patient Intubated: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6)
    r401Code = codeValue("R40.1", "Stupor: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8)
    #Labs
    lowArterialBloodPHDV = dvValue(dvArterialBloodPH, "Arterial Blood PH: [VALUE] (Result Date: [RESULTDATETIME])", calcArterialBloodPH1, 4)
    BetaHydroxybutyrateDV = dvValue(dvBetaHydroxybutyrate, "Beta-Hydroxybutyrate (BHB): [VALUE] (Result Date: [RESULTDATETIME])", calcBetaHydroxybutyrate1, 5)
    serumBicarbonateDV = dvValue(dvSerumBicarbonate, "Blood C02: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumBicarbonate1, 6)    
    elevatedSerumOsmolalityDV = dvValue(dvSerumOsmolality, "Serum Osmolality: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumOsmolality1, 10)
    urineKetonesDV = dvValue(dvUrineKetone, "Urine Ketones Present: [VALUE] (Result Date: [RESULTDATETIME])", calcUrineKetone1, 12)
    serumKetonesDV = dvValue(dvSerumKetone, "Urine Ketones Present: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumKetone1, 13)
    #Labs Subheadings
    lowBloodGlucoseDV = dvValueMulti(dict(maindiscreteDic), dvBloodGlucose, "Blood Glucose: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodGlucose2, lt, 0, None, False, 10)
    if lowBloodGlucoseDV is None: lowBloodGlucoseDV = dvValueMulti(dict(maindiscreteDic), dvBloodGlucosePOC, "Blood Glucose: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodGlucosePOC3, lt, 0, None, False, 10)
    highBloodGlucoseHHNSDV = dvValueMulti(dict(maindiscreteDic), dvBloodGlucose, "Blood Glucose: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodGlucose1, gt, 0, None, False, 10)
    if highBloodGlucoseHHNSDV is None: highBloodGlucoseHHNSDV = dvValueMulti(dict(maindiscreteDic), dvBloodGlucosePOC, "Blood Glucose: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodGlucosePOC2, gt, 0, None, False, 10)
    highBloodGlucoseDKADV = dvValueMulti(dict(maindiscreteDic), dvBloodGlucose, "Blood Glucose: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodGlucose3, gt, 0, None, False, 10)
    if highBloodGlucoseDKADV is None: highBloodGlucoseDKADV = dvValueMulti(dict(maindiscreteDic), dvBloodGlucosePOC, "Blood Glucose: [VALUE] (Result Date: [RESULTDATETIME])", calcBloodGlucosePOC1, gt, 0, None, False, 10)
    #Abstracting Main Clinical Indicators
    if highBloodGlucoseHHNSDV is not None: HHNS += 1
    if elevatedSerumOsmolalityDV is not None: HHNS += 1
    if lowArterialBloodPHDV is not None: DKA += 1
    if serumBicarbonateDV is not None: DKA += 1

    #Signs of Coma Check
    if (
        (a5a193Codes is None and
        a0bh18ezCode is None) and
        glasgowComaScoreDV is not None or
        glasgowComaScoreAbs is not None or
        decrLvlConsciousnessAbs is not None or
        obtundedAbs is not None or
        r401Code is not None
    ):
        SoC = True

    #DKA Check
    if (
        (urineKetonesDV is not None or r824Code is not None or serumKetonesDV is not None or BetaHydroxybutyrateDV is not None) and
        highBloodGlucoseDKADV
    ):
        DKACheck = True
        
    #Main Algorithm
    #1
    if (
        (e1011Code is not None or e1641Code is not None) and
        (e1101Code is not None or e1111Code is not None or e11641Code is not None)
    ):
        if e1011Code is not None: dc.Links.Add(e1011Code)
        if e1641Code is not None: dc.Links.Add(e1641Code)
        if e1101Code is not None: dc.Links.Add(e1101Code)
        if e1111Code is not None: dc.Links.Add(e1111Code)
        if e11641Code is not None: dc.Links.Add(e11641Code)
        result.Subtitle = "Conflicting Diabetes Mellitus Type 1 and Type 2 with Coma Dx, Clarification Needed"
        AlertPassed = True
    #2
    elif e1010Code is not None and e1110Code is not None:
        dc.Links.Add(e1010Code)
        dc.Links.Add(e1110Code)
        result.Subtitle = "Conflicting Type 1 and Type 2 with Ketoacidosis without Coma Dx"
        AlertPassed = True
    #3.1/4.1
    elif subtitle == "Possible Type 1 Diabetes Mellitus with Ketoacidosis with Coma" and e1011Code is not None:
        dc.Links.Add(e1011Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #3.0
    elif DKA >= 1 and DKACheck and (SoC or r4020Code is not None) and unspecTypeIDiabetes is not None and e1011Code is None:
        dc.Links.Add(unspecTypeIDiabetes)
        if r4020Code is not None: dc.Links.Add(r4020Code)
        DKAAlertPassed = True
        result.Subtitle = "Possible Type 1 Diabetes Mellitus with Ketoacidosis with Coma"
        AlertPassed = True
    #4
    elif e1010Code is not None and (SoC or r4020Code is not None) and e1011Code is None:
        dc.Links.Add(e1010Code)
        if r4020Code is not None: dc.Links.Add(r4020Code)
        result.Subtitle = "Possible Type 1 Diabetes Mellitus with Ketoacidosis with Coma"
        DKAAlertPassed = True
        AlertPassed = True
    #5.1
    elif subtitle == "Possible Type 1 Diabetes Mellitus with Ketoacidosis without Coma" and (e1011Code is not None or e1010Code is not None):
        if e1011Code is not None: updateLinkText(e1011Code, autoCodeText); dc.Links.Add(e1011Code)
        if e1010Code is not None: updateLinkText(e1010Code, autoCodeText); dc.Links.Add(e1010Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #5
    elif DKA >= 1 and DKACheck and (r4020Code is None or SoC is False) and unspecTypeIDiabetes is not None and e1010Code is None and e1011Code is None:
        dc.Links.Add(unspecTypeIDiabetes)
        DKAAlertPassed = True
        result.Subtitle = "Possible Type 1 Diabetes Mellitus with Ketoacidosis without Coma"
        AlertPassed = True
    #6.1/7.1
    elif subtitle == "Possible Type 1 Diabetes Mellitus with Hypoglycemia with Coma" and e10641Code is not None:
        if e10641Code is not None: updateLinkText(e10641Code, autoCodeText); dc.Links.Add(e10641Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #6
    elif (r4020Code is not None or SoC) and len(lowBloodGlucoseDV or noLabs) > 1 and unspecTypeIDiabetes is not None and e10641Code is None:
        dc.Links.Add(unspecTypeIDiabetes)
        if r4020Code is not None: dc.Links.Add(r4020Code)
        for entry in lowBloodGlucoseDV:
            bloodGlucose.Links.Add(entry)
        if bloodGlucose.Links: dc.Links.Add(bloodGlucose)
        result.Subtitle = "Possible Type 1 Diabetes Mellitus with Hypoglycemia with Coma"
        AlertPassed = True
    #7
    elif e10649Code is not None and (SoC or r4020Code is not None) and e10641Code is None:
        dc.Links.Add(e10649Code)        
        if r4020Code is not None: dc.Links.Add(r4020Code)
        result.Subtitle = "Possible Type 1 Diabetes Mellitus with Hypoglycemia with Coma"
        AlertPassed = True
    #8.1/10.1
    elif subtitle == "Possible Type 2 Diabetes Mellitus with Hyperosmolarity with Coma" and e1101Code is not None:
        if e1101Code is not None: dc.Links.Add(e1101Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #8
    elif HHNS > 1 and unspecTypeIIDiabetes is not None and (r4020Code is not None and SoC) and e1101Code is None:
        dc.Links.Add(unspecTypeIIDiabetes)
        if r4020Code is not None: dc.Links.Add(r4020Code)
        HHNSAlertPassed = True
        result.Subtitle = "Possible Type 2 Diabetes Mellitus with Hyperosmolarity with Coma"
        AlertPassed = True
    #9.1
    elif subtitle == "Possible Type 2 Diabetes Mellitus with Hyperosmolarity without Coma" and (e1100Code is not None or e1101Code is not None):
        if e1101Code is not None: dc.Links.Add(e1101Code)
        if e1100Code is not None: updateLinkText(e1100Code, autoCodeText); dc.Links.Add(e1100Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #9
    elif HHNS > 1 and (r4020Code is None or SoC is False) and unspecTypeIIDiabetes is not None and e1100Code is None and e1101Code is None:
        dc.Links.Add(unspecTypeIIDiabetes)
        result.Subtitle = "Possible Type 2 Diabetes Mellitus with Hyperosmolarity without Coma"
        HHNSAlertPassed = True
        AlertPassed = True
    #10
    elif (SoC or r4020Code is not None) and e1100Code is not None and e1101Code is None:
        dc.Links.Add(e1100Code)
        if r4020Code is not None: dc.Links.Add(r4020Code)
        HHNSAlertPassed = True
        result.Subtitle = "Possible Type 2 Diabetes Mellitus with Hyperosmolarity with Coma"
        AlertPassed = True
    #11.1/12.1
    elif subtitle == "Possible Type 2 Diabetes Mellitus with Ketoacidosis with Coma" and e1111Code is not None:
        if e1111Code is not None: dc.Links.Add(e1111Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #11
    elif DKA >= 1 and DKACheck and (SoC or r4020Code is not None) and unspecTypeIIDiabetes is not None and e1111Code is None:
        dc.Links.Add(unspecTypeIIDiabetes)
        if r4020Code is not None: dc.Links.Add(r4020Code)
        DKAAlertPassed = True
        result.Subtitle = "Possible Type 2 Diabetes Mellitus with Ketoacidosis with Coma"
        AlertPassed = True
    #12
    elif (SoC or r4020Code is not None) and e1110Code is not None and e1111Code is None:
        dc.Links.Add(e1110Code)
        if r4020Code is not None: dc.Links.Add(r4020Code)
        DKAAlertPassed = True
        result.Subtitle = "Possible Type 2 Diabetes Mellitus with Ketoacidosis with Coma"
        AlertPassed = True
    #13.1
    elif subtitle == "Possible Type 2 Diabetes Mellitus with Hyperosmolarity with Coma" and e1101Code is not None:
        if e1101Code is not None: dc.Links.Add(e1101Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #13
    elif e1165Code is not None and (SoC or r4020Code is not None) and elevatedSerumOsmolalityDV is not None and e1101Code is None:
        dc.Links.Add(e1165Code)
        if r4020Code is not None: dc.Links.Add(r4020Code)
        HHNSAlertPassed = True
        result.Subtitle = "Possible Type 2 Diabetes Mellitus with Hyperosmolarity with Coma"
        AlertPassed = True
    #14.1
    elif subtitle == "Possible Type 2 Diabetes Mellitus with Hyperosmolarity without Coma" and e1101Code is not None:
        if e1101Code is not None: dc.Links.Add(e1101Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #14
    elif e1165Code is not None and (SoC is False and r4020Code is None) and elevatedSerumOsmolalityDV is not None and e1101Code is None:
        dc.Links.Add(e1165Code)
        if r4020Code is not None: dc.Links.Add(r4020Code)
        HHNSAlertPassed = True
        result.Subtitle = "Possible Type 2 Diabetes Mellitus with Hyperosmolarity without Coma"
        AlertPassed = True        
    #15.1
    elif subtitle == "Possible Type 2 Diabetes Mellitus with Ketoacidosis without Coma" and (e1100Code is not None or e1101Code is not None):
        if e1110Code is not None: updateLinkText(e1110Code, autoCodeText); dc.Links.Add(e1110Code)
        if e1111Code is not None: dc.Links.Add(e1111Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #15
    elif (SoC is False and r4020Code is None) and DKA >= 1 and DKACheck and unspecTypeIIDiabetes is not None and e1110Code is None and e1111Code is None:
        dc.Links.Add(unspecTypeIIDiabetes)
        DKAAlertPassed = True
        result.Subtitle = "Possible Type 2 Diabetes Mellitus with Ketoacidosis without Coma"
        AlertPassed = True
    #16.1/17.1
    elif subtitle == "Possible Type 2 Diabetes Mellitus with Hypoglycemia with Coma" and e11641Code is not None:
        if e11641Code is not None: dc.Links.Add(e11641Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #16
    elif unspecTypeIIDiabetes is not None and (r4020Code is not None or SoC) and len(lowBloodGlucoseDV or noLabs) > 1 and e11641Code is None:
        dc.Links.Add(unspecTypeIIDiabetes)
        if r4020Code is not None: dc.Links.Add(r4020Code)
        for entry in lowBloodGlucoseDV:
            bloodGlucose.Links.Add(entry)
        if bloodGlucose.Links: dc.Links.Add(bloodGlucose)
        result.Subtitle = "Possible Type 2 Diabetes Mellitus with Hypoglycemia with Coma"
        AlertPassed = True
    #17
    elif e11649Code is not None and (SoC or r4020Code is not None) and e11641Code is None:
        dc.Links.Add(e11649Code)
        if r4020Code is not None: dc.Links.Add(r4020Code)
        result.Subtitle = "Possible Type 2 Diabetes Mellitus with Hypoglycemia with Coma"
        AlertPassed = True
    #18
    elif unspecTypeIDiabetes is not None and unspecTypeIIDiabetes is not None:
        dc.Links.Add(unspecTypeIDiabetes)
        dc.Links.Add(unspecTypeIIDiabetes)
        result.Subtitle = "Conflicting Diabetes Type 1 and Diabetes Type 2 Dx"
        AlertPassed = True
    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Abs
    if HHNSAlertPassed: r4182Code = codeValue("R41.82", "Altered Level Of Consciousness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    if HHNSAlertPassed: alteredAbs = abstractValue("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level Of Consciousness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2)
    if HHNSAlertPassed: 
        if r4182Code is not None:
            abs.Links.Add(r4182Code)
            if alteredAbs is not None: alteredAbs.Hidden = True; abs.Links.Add(alteredAbs)
        elif r4182Code is None and alteredAbs is not None:
            abs.Links.Add(alteredAbs)
    if DKAAlertPassed: codeValue("G93.6", "Cerebral Edema: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, abs, True)
    codeValue("R41.0", "Confusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, abs, True)
    if HHNSAlertPassed: abstractValue("EXTREME_THIRST","Extreme Thirst: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5, abs, True)
    if DKAAlertPassed: codeValue("R53.83", "Fatigue: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6, abs, True)
    abstractValue("FRUITY_BREATH","Fruity Breath '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7, abs, True)
    codeValue("Z90.410", "History of Pancreatectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8, abs, True)
    codeValue("Z90.411", "History of Partial Pancreatectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, abs, True)
    if DKAAlertPassed: codeValue("E87.6", "Hypokalemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, abs, True)
    abstractValue("INCREASED_URINARY_FREQUENCY","Increased Urinary Frequency: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11, abs, True)
    if DKAAlertPassed and r824Code is not None: abs.Links.Add(r824Code) #12
    dvOxygenCheck(dict(maindiscreteDic), dvOxygenTherapy, "Oxygen Therapy: [VALUE] (Result Date: [RESULTDATETIME])", 13, abs, True)
    if HHNSAlertPassed: codeValue("R63.1", "Polydipsia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, abs, True)
    if HHNSAlertPassed: abstractValue("PSYCHOSIS","Psychosis: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 15, abs, True)
    abstractValue("SEIZURE", "Seizure: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 15, abs, True)
    if DKAAlertPassed: abstractValue("SHORTNESS_OF BREATH","Shortness of Breath '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 16, abs, True)
    if HHNSAlertPassed: codeValue("R47.81", "Slurred Speech: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17, abs, True)
    if HHNSAlertPassed: codeValue("R11.10", "Vomiting: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, abs, True)
    if DKAAlertPassed: abstractValue("VOMITING","Vomiting '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 19, abs, True)
    if HHNSAlertPassed: codeValue("R11.11", "Vomiting without Nausea: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20, abs, True)
    #Coma
    if decrLvlConsciousnessAbs is not None: coma.Links.Add(decrLvlConsciousnessAbs) #1
    if glasgowComaScoreDV is not None: coma.Links.Add(glasgowComaScoreDV) #2
    if glasgowComaScoreAbs is not None: coma.Links.Add(glasgowComaScoreAbs) #3
    if a5a193Codes is not None: coma.Links.Add(a5a193Codes) #4
    if obtundedAbs is not None: coma.Links.Add(obtundedAbs) #5
    if a0bh18ezCode is not None: coma.Links.Add(a0bh18ezCode) #6
    if r401Code is not None: coma.Links.Add(r401Code) #8
    #Labs
    if DKAAlertPassed: dvValue(dvAcetone, "Acetone: [VALUE] (Result Date: [RESULTDATETIME])", calcAcetone1, 1, labs, True)
    if DKAAlertPassed: dvValue(dvAnionGap, "Anion Gap: [VALUE] (Result Date: [RESULTDATETIME])", calcAnionGap1, 2, labs, True)
    if DKAAlertPassed: abstractValue("ANION_GAP","Anion Gap: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3, labs, True)
    if DKAAlertPassed and lowArterialBloodPHDV is not None: labs.Links.Add(lowArterialBloodPHDV) #4
    if DKAAlertPassed and BetaHydroxybutyrateDV is not None: labs.Links.Add(BetaHydroxybutyrateDV) #5
    if DKAAlertPassed and serumBicarbonateDV is not None: labs.Links.Add(serumBicarbonateDV) #6
    if DKAAlertPassed: abstractValue("LOW_SERUM_BICABONATE", "Arterial Blood PH: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7, labs, True)
    if DKAAlertPassed: abstractValue("HIGH_BLOOD_GLUCOSE_DKA", "Blood Glucose: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, labs, True)
    if DKAAlertPassed: abstractValue("HIGH_BLOOD_GLUCOSE_DKA","Blood Glucose: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, labs, True)
    if HHNSAlertPassed and elevatedSerumOsmolalityDV is not None: labs.Links.Add(elevatedSerumOsmolalityDV) #10
    if DKAAlertPassed: abstractValue("LOW_SERUM_POTASSIUM","Serum Potassium '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11, labs, True)
    if DKAAlertPassed and urineKetonesDV is not None: labs.Links.Add(urineKetonesDV) #12
    if DKAAlertPassed and serumKetonesDV is not None: labs.Links.Add(serumKetonesDV) #13
    #Labs Subheadings
    if DKAAlertPassed and highBloodGlucoseDKADV is not None:
        for entry in highBloodGlucoseDKADV:
            bloodGlucose.Links.Add(entry)
    if HHNSAlertPassed and highBloodGlucoseHHNSDV is not None:
        for entry in highBloodGlucoseHHNSDV:
            bloodGlucose.Links.Add(entry)
    #Meds
    medValue("Albumin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, meds, True)
    medValue("Anti-Hypoglycemic Agent", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 2, meds, True)
    medValue("Dextrose 50%", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 3, meds, True)
    medValue("Fluid Bolus", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 4, meds, True)
    abstractValue("FLUID_BOLUS","Fluid Bolus '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5, meds, True)
    medValue("Insulin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 6, meds, True)
    abstractValue("INSULIN_ADMINISTRATION","Insulin Administration '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7, meds, True)
    medValue("Sodium Bicarbonate", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 8, meds, True)
    abstractValue("SODIUM_BICARBONATE","Sodium Bicarbonate '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, meds, True)
    #Vitals
    if HHNSAlertPassed: dvValue(dvTemperature, "Fever: [VALUE] (Result Date: [RESULTDATETIME])", calcTemperature1, 1, vitals, True)
    dvValue(dvHeartRate, "Heart Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcHeartRate1, 2, vitals, True)
    
#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if bloodGlucose.Links: labs.Links.Add(bloodGlucose); labsLinks = True
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    if vitals.Links: result.Links.Add(vitals); vitalsLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    if coma.Links: result.Links.Add(coma); comaLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Documented Dx- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks) + ", vitals- "
        + str(vitalsLinks) + ", meds- " + str(medsLinks) + ", Coma- " + str(comaLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
