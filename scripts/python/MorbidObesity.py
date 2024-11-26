##################################################################################################################
#Evaluation Script - Morbid Obesity
#
#This script checks an account to see if it matches criteria to be alerted for Morbid Obesity
#Date - 11/05/2024
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
dvArterialBloodC02 = ["CO2 (mmol/L)", "PaCO2 (mmHg)"]
calcArterialBloodC021 = lambda x: x > 50
dvArterialBloodPH = ["pH"]
calcArterialBloodPH1 = lambda x: x < 7.35
dvBMI = ["3.5 BMI Calculation (kg/m2)"]
calcBMI1 = lambda x: x >= 40.0
calcBMI2 = lambda x: 35.0 <= x < 40.0
calcBMI3 = lambda x: x < 35.0
dvHCO3 = ["HCO3 BldV-sCnc (mmol/L)", "HCO3 (meq/L)", "HCO3 (mmol/L)", "HCO3 VENOUS (meq/L)"]
calcHCO31 = lambda x: x > 26
dvGlasgowComaScale = ["3.5 Neuro Glasgow Score"]
calcGlasgowComaScale1 = lambda x: x < 15
dvPaO2 = ["BLD GAS O2 (mmHg)", "PO2 (mmHg)"]
calcPAO21 = lambda x: x < 80
dvPH = ["pH (VENOUS)", "pH VENOUS"]
calcPH1 = lambda x: x < 7.30
dvSerumBicarbonate = ["HCO3 BldA-sCnc (mmol/L)", "CO2 SerPl-sCnc (mmol/L)", "CO2 (SAH) (mmol/L)"]
calcSerumBicarbonate1 = lambda x: x > 30
dvSPO2 = ["Pulse Oximetry(Num) (%)"]
calcSPO21 = lambda x: x < 90
dvVenousBloodCO2 = ["BLD GAS CO2 VEN (mmHg)"]
calcVenousBloodCO2 = lambda x: x > 55

dvWeightkg = ["Weight lbs 3.5 (kg)"]
dvWeightLbs = ["Weight lbs 3.5 (lb)"]
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
negation = False
coMorbidity = 0
dcLinks = False
absLinks = False
labsLinks = False
oxygenLinks = False
morbidityLinks = False

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
oxygen = MatchedCriteriaLink("Oxygenation/Ventilation", None, "Oxygenation/Ventilation", None, True, None, None, 2)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 3)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 4)
morbidity = MatchedCriteriaLink("Obesity Co-Morbidities", None, "Obesity Co-Morbidities", None, True, None, None, 5)
treatment = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 6)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 7)

#Link Text for special messages for lacking
LinkText1 = "Possibly Missing BMI to meet Morbid Obesity Criteria"
LinkText2 = "Possibly Missing Sign of Hypoventilation"

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Morbid Obesity':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        subtitle = alert.Subtitle
        for alertLink in alert.Links:
            if alertLink.LinkText == 'Alert Trigger(s)':
                for links in alertLink.Links:
                    if links.LinkText == LinkText1:
                        message1 = True
                    if links.LinkText == LinkText2:
                        message2 = True
        break

#Check if alert was autoresolved or completed.
if validated is False:
    #Negations
    pregenancyNegation =  prefixCodeValue("^O", "Pregenacy Negation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pregenancyNegation2 =  prefixCodeValue("^Z3A", "Pregenacy Negation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pneumoniaNegations1 = multiCodeValue(["A01.03", "A02.22", "A21.2", "A22.1", "A42.0", "A43.0", "A54.84", "B01.2", "B05.2",
                        "B06.81", "B25.0", "B37.1", "B38.0", "B39.0", "B44.0", "B44.1", "B58.3", "B59", "B77.81"],
                        "Pneumonia Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pneumoniaNegations2 = prefixCodeValue("^J12\.", "Pneumonia Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pneumoniaNegations3 = prefixCodeValue("^J14\.", "Pneumonia Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pneumoniaNegations4 = prefixCodeValue("^J15\.", "Pneumonia Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pneumoniaNegations5 = codeValue("J16.0", "Pneumonia Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pneumoniaNegations6 = prefixCodeValue("^J69\.", "Pneumonia Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pulmonaryEdemaNegation = multiCodeValue(["J81.0", "J81.1"], "Pulmonary Edema Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pulmonaryEmbolismNegation = prefixCodeValue("^I26\.", "Pulmonary Embolism Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    heartFailureNegation = multiCodeValue(["I50.21", "I50.23", "I50.31", "I50.33", "I50.41", "I50.43"], "Acute Heart Failure Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    cardiacArrestNegations = prefixCodeValue("^I46\.", "Cardiac Arrest Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    r6521Negations = codeValue("R65.21", "Septic Shock Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    shockNegations = prefixCodeValue("^R57\.", "Shock Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    sepsisNegations1 = prefixCodeValue("^A40\.", "Sepsis Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    sepsisNegations2 = prefixCodeValue("^A41\.", "Sepsis Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    asthmaAttackNegation = multiCodeValue(["J45.901", "J45.902"], "Asthma Attack Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j441Negation = codeValue("J44.1", "COPD Exacerbation Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    opioidOverdoseNegation = abstractValue("OPIOID_OVERDOSE", "Opioid Overdose: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True)
    glascowComaNegation = dvValue(dvGlasgowComaScale, "Arterial Blood CO2: [VALUE] (Result Date: [RESULTDATETIME])", calcGlasgowComaScale1)
    encephalopathyNegation = multiCodeValue(["E51.2", "G31.2", "G92.8", "G93.41", "I67.4", "G92.9", "G93.41"], "Encephalopathy Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    e669Negation = codeValue("E66.9", "Obesity: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Alert Trigger
    r0689Code = codeValue("R06.89", "Hypoventilation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6)
    e662Code = codeValue("E66.2", "Morbid (Severe) Obesity With Alveolar Hypoventilation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    e6601Code = codeValue("E66.01", "Morbid (Severe) Obesity Due To Excess Calories: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    e66811Code = codeValue("E66.811", "Obesity, Class 1: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    e66812Code = codeValue("E66.812", "Obesity, Class 2: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    e66813Code = codeValue("E66.812", "Obesity, Class 3: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    obesityCodes = multiCodeValue(["E66.8", "E66.9"], "Obesity Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    bmiGTE40Codes = multiCodeValue(["Z68.41", "Z68.42", "Z68.43","Z68.44", "Z68.45"], "BMI >or= 40: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    bmiGTE35Codes = multiCodeValue(["Z68.35", "Z68.36", "Z68.37", "Z68.38", "Z68.39"], "BMI: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    bMILT35DV = dvValue(dvBMI, "BMI: [VALUE] (Result Date: [RESULTDATETIME])", calcBMI3)
    bMIGTE40DV = dvValue(dvBMI, "BMI: [VALUE] (Result Date: [RESULTDATETIME])", calcBMI1)
    bMILT40GE35DV = dvValue(dvBMI, "BMI: [VALUE] (Result Date: [RESULTDATETIME])", calcBMI2)
    bmiLT40Codes = multiCodeValue(["Z68.1", "Z68.20", "Z68.21", "Z68.22", "Z68.23", "Z68.24", "Z68.25",
        "Z68.26", "Z68.27", "Z68.28", "Z68.29", "Z68.3", "Z68.30", "Z68.31", "Z68.32", "Z68.33","Z68.34", 
        "Z68.35", "Z68.36", "Z68.37", "Z68.38", "Z68.39"], "BMI: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    bmiLT35Codes = multiCodeValue(["Z68.1", "Z68.20", "Z68.21", "Z68.22", "Z68.23", "Z68.24", "Z68.25", "Z68.26", "Z68.27",
        "Z68.28", "Z68.29", "Z68.30", "Z68.31", "Z68.32", "Z68.33", "Z68.34"], 
        "BMI: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j9612Code = codeValue("J96.12", "Chronic Respiratory Failure with Hypercarbia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    pilmonaryHypertensionAbs = abstractValue("PULMONARY_HYPERTENSION_DUE_TO_HYPOVENTILATION", "Pulmonary Hypertension '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0)
    bmiGE35L40Abs = abstractValue("HIGH_BMI_1", "BMI: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0)
    bmiGE40Abs = abstractValue("HIGH_BMI_2", "BMI: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0)
    bmiGE185L35Abs = abstractValue("MID_BMI", "BMI: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0)
    bmiL185Abs = abstractValue("LOW_BMI", "BMI: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0)
    #Co-Morbidities
    coronaryArteryAngina = multiCodeValue(["I25.110", "I25.111", "I25.112", "I25.118", "I25.119"], "Coronary Artery Disease with Angina: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    i2510Code = codeValue("I25.10", "Coronary Artery Disease without Angina: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    e785Code = codeValue("E78.5", "Hyperlipidemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3)
    i10Code = codeValue("I10", "Hypertension: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4)
    hypertensiveChronicKidney = multiCodeValue(["I12.0", "I12.9"], "Hypertensive Chronic Kidney Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5)
    hypertensiveHeartChronicKidney = multiCodeValue(["I13.0", "I13.10", "I13.11", "I13.2"], "Hypertensive Heart and Chronic Kidney Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6)
    hypertensiveHeart = multiCodeValue(["E11.0", "E11.9"], "Hypertensive Heart Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7)
    k760Code = codeValue("K76.0", "Non-Alcoholic Fatty Liver Disease (NAFLD): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8)
    g4733Code = codeValue("G47.33", "Obstructive Sleep Apnea (OSA): [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9)
    osteoarthritis = multiCodeValue(["M19.90", "M19.93"], "Osteoarthritis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10)
    osteoarthritisHip = multiCodeValue(["M16.6", "M16.7", "M16.9"], "Osteoarthritis of Hip: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11)
    osteoarthritisKnee = multiCodeValue(["M17.4", "M17.5", "M17.9"], "Osteoarthritis of Knee: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12)
    a4730Code = codeValue("A47.30", "Sleep Apnea: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16)
    type2DiabetesAbs = abstractValue("DIABETES_TYPE_2", "Type 2 Diabetes: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 14)
    #Labs
    arterialBloodCO2DV = dvValue(dvArterialBloodC02, "PaCO2: [VALUE] (Result Date: [RESULTDATETIME])", calcArterialBloodC021, 1)
    venousBloodCO2DV = dvValue(dvVenousBloodCO2, "Venous Blood C02: [VALUE] (Result Date: [RESULTDATETIME])", calcVenousBloodCO2, 8)
    #Oxygen
    nonInvasiveMechanicalVentilation = abstractValue("NON_INVASIVE_VENTILATION", "Non-Invasive Ventilation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2)
    invasiveMechanicalVentilation = multiCodeValue(["5A1935Z", "5A1945Z", "5A1955Z"], "Invasive Mechanical Ventilation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4)

    #Alert Checks
    if (pneumoniaNegations1 is not None or
        pneumoniaNegations2 is not None or
        pneumoniaNegations3 is not None or
        pneumoniaNegations4 is not None or
        pneumoniaNegations5 is not None or
        pneumoniaNegations6 is not None or
        pulmonaryEdemaNegation is not None or
        pulmonaryEmbolismNegation is not None or
        heartFailureNegation is not None or
        cardiacArrestNegations is not None or
        r6521Negations is not None or
        shockNegations is not None or
        sepsisNegations1 is not None or
        sepsisNegations2 is not None or
        asthmaAttackNegation is not None or
        j441Negation is not None or
        opioidOverdoseNegation is not None or
        glascowComaNegation is not None or
        encephalopathyNegation is not None
    ):
        negation = True

    #Co-Morbitities Count and Abstraction
    if coronaryArteryAngina is not None: morbidity.Links.Add(coronaryArteryAngina); coMorbidity += 1
    if i2510Code is not None: morbidity.Links.Add(i2510Code); coMorbidity += 1
    if e785Code is not None: morbidity.Links.Add(e785Code); coMorbidity += 1
    if i10Code is not None: morbidity.Links.Add(i10Code); coMorbidity += 1
    if hypertensiveChronicKidney is not None: morbidity.Links.Add(hypertensiveChronicKidney); coMorbidity += 1
    if hypertensiveHeartChronicKidney is not None: morbidity.Links.Add(hypertensiveHeartChronicKidney); coMorbidity += 1
    if hypertensiveHeart is not None: morbidity.Links.Add(hypertensiveHeart); coMorbidity += 1
    if k760Code is not None: morbidity.Links.Add(k760Code); coMorbidity += 1
    if g4733Code is not None: morbidity.Links.Add(g4733Code); coMorbidity += 1
    if osteoarthritis is not None: morbidity.Links.Add(osteoarthritis); coMorbidity += 1
    if osteoarthritisHip is not None: morbidity.Links.Add(osteoarthritisHip); coMorbidity += 1
    if osteoarthritisKnee is not None: morbidity.Links.Add(osteoarthritisKnee); coMorbidity += 1
    if a4730Code is not None: morbidity.Links.Add(a4730Code); coMorbidity += 1
    if type2DiabetesAbs is not None: morbidity.Links.Add(type2DiabetesAbs); coMorbidity += 1
    
    #Main Algorithm
    if pregenancyNegation is not None or pregenancyNegation2 is not None:
        db.LogEvaluationScriptMessage("Pregnancy Codes detected on chart, alert failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False
    #1.1
    elif (
        subtitle == "Morbid Obesity with Alveolar Hypoventilation Dx Lacking Supporting Evidence" and 
        ((bmiGTE40Codes is not None or bMIGTE40DV is not None or bmiGE40Abs is not None or
        ((bmiGTE35Codes is not None or bMILT40GE35DV is not None or bmiGE35L40Abs is not None) and coMorbidity > 0) and message1) or 
         ((nonInvasiveMechanicalVentilation is not None or invasiveMechanicalVentilation is not None or 
         r0689Code is not None or arterialBloodCO2DV is not None or venousBloodCO2DV is not None) and message2))
    ):
        if message1:
            if bmiGTE40Codes is not None: updateLinkText(bmiGTE40Codes, autoCodeText); dc.Links.Add(bmiGTE40Codes)
            if bmiGE40Abs is not None: updateLinkText(bmiGE40Abs, autoEvidenceText); dc.Links.Add(bmiGE40Abs)
            if bMIGTE40DV is not None: updateLinkText(bMIGTE40DV, autoEvidenceText); dc.Links.Add(bMIGTE40DV)
            if bmiGTE35Codes is not None: updateLinkText(bmiGTE35Codes, autoCodeText); dc.Links.Add(bmiGTE35Codes)
            if bmiGE35L40Abs is not None: updateLinkText(bmiGE35L40Abs, autoEvidenceText); dc.Links.Add(bmiGE35L40Abs)
            if bMILT40GE35DV is not None: updateLinkText(bMILT40GE35DV, autoEvidenceText); dc.Links.Add(bMILT40GE35DV)
            dc.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None, False))
        if message2:
            dc.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None, False))
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True  
    #1
    elif (
        e662Code is not None and
        ((bmiGTE40Codes is None and bMIGTE40DV is None and bmiGE40Abs is None) or (bmiGTE35Codes is None and bMILT40GE35DV is None and bmiGE35L40Abs is None and coMorbidity == 0)) and
        (nonInvasiveMechanicalVentilation is None and invasiveMechanicalVentilation is None and 
        r0689Code is not None and arterialBloodCO2DV is None and venousBloodCO2DV is None)
    ):
        if e662Code is not None: dc.Links.Add(e662Code)
        if ((bmiGTE40Codes is None and bMIGTE40DV is None and bmiGE40Abs is None) or (bmiGTE35Codes is None and bMILT40GE35DV is None and bmiGE35L40Abs is None and coMorbidity == 0)):
            dc.Links.Add(MatchedCriteriaLink(LinkText1, None, None, None))
        if (
            (nonInvasiveMechanicalVentilation is None and 
            invasiveMechanicalVentilation is None and 
            r0689Code is not None and 
            arterialBloodCO2DV is None and 
            venousBloodCO2DV is None)
        ):
            dc.Links.Add(MatchedCriteriaLink(LinkText2, None, None, None))
        result.Subtitle = "Morbid Obesity with Alveolar Hypoventilation Dx Lacking Supporting Evidence"
        AlertPassed = True
    #2.1
    elif (
        subtitle == "Morbid (Severe) Obesity Documented, but BMI Criteria Not Met" and 
        (bmiGTE40Codes is not None or bMIGTE40DV is not None or bmiGE40Abs is not None or 
        ((bmiGTE35Codes is not None or bMILT40GE35DV is not None or bmiGE35L40Abs is not None) and coMorbidity > 0))
    ):
        if bmiGTE40Codes is not None: updateLinkText(bmiGTE40Codes, autoCodeText); dc.Links.Add(bmiGTE40Codes)
        if bmiGE40Abs is not None: updateLinkText(bmiGE40Abs, autoEvidenceText); dc.Links.Add(bmiGE40Abs)
        if bMIGTE40DV is not None: updateLinkText(bMIGTE40DV, autoEvidenceText); dc.Links.Add(bMIGTE40DV)
        if bmiGTE35Codes is not None: updateLinkText(bmiGTE35Codes, autoCodeText); dc.Links.Add(bmiGTE35Codes)
        if bmiGE35L40Abs is not None: updateLinkText(bmiGE35L40Abs, autoEvidenceText); dc.Links.Add(bmiGE35L40Abs)
        if bMILT40GE35DV is not None: updateLinkText(bMILT40GE35DV, autoEvidenceText); dc.Links.Add(bMILT40GE35DV)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True   
    #2
    elif (
        (e662Code is not None or e6601Code is not None) and 
        (((bmiGTE35Codes is not None or bMILT40GE35DV is not None or bmiGE35L40Abs is not None) and coMorbidity == 0) or
        (bmiLT35Codes is not None or bMILT35DV is not None) or
        (bmiLT40Codes is None and bmiGTE35Codes is None and bmiLT35Codes is None and bMILT40GE35DV is None and bMILT35DV is None)) and 
        bMIGTE40DV is None and 
        bmiGTE40Codes is None and bmiGE40Abs is None
    ):
        if e662Code is not None: dc.Links.Add(e662Code)
        if e6601Code is not None: dc.Links.Add(e6601Code)
        if bmiGTE40Codes is not None: dc.Links.Add(bmiGTE40Codes)
        if bmiLT35Codes is not None: dc.Links.Add(bmiLT35Codes)
        if bMILT35DV is not None: dc.Links.Add(bMILT35DV)
        if bmiGTE35Codes is not None: dc.Links.Add(bmiGTE35Codes)
        if bmiGE35L40Abs is not None: dc.Links.Add(bmiGE35L40Abs)
        if bMILT40GE35DV is not None: dc.Links.Add(bMILT40GE35DV)
        if bmiL185Abs is not None: dc.Links.Add(bmiL185Abs)
        if bmiGE185L35Abs is not None: dc.Links.Add(bmiGE185L35Abs)
        if bmiGE35L40Abs is not None: dc.Links.Add(bmiGE35L40Abs)
        result.Subtitle = "Morbid (Severe) Obesity Documented, but BMI Criteria Not Met"
        AlertPassed = True
    #3.1
    elif subtitle == "Possible Morbid (Severe) Obesity with Hypoventilation" and e662Code is not None:
        if e662Code is not None: updateLinkText(e662Code, autoCodeText); dc.Links.Add(e662Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    #3
    elif (
        e662Code is None and 
        (bmiGTE40Codes is not None or bMIGTE40DV is not None or bmiGE40Abs is not None or 
         ((bmiGTE35Codes is not None or bMILT40GE35DV is not None or bmiGE35L40Abs is not None) and coMorbidity > 0)) and
        (nonInvasiveMechanicalVentilation is not None or invasiveMechanicalVentilation is not None or 
         r0689Code is not None or arterialBloodCO2DV is not None or venousBloodCO2DV is not None) and
        negation is False
    ):
        if bmiGTE40Codes is not None: dc.Links.Add(bmiGTE40Codes)
        if bmiGE40Abs is not None: dc.Links.Add(bmiGE40Abs)
        if bMIGTE40DV is not None: dc.Links.Add(bMIGTE40DV)
        if bmiGTE35Codes is not None: dc.Links.Add(bmiGTE35Codes)
        if bmiGE35L40Abs is not None: dc.Links.Add(bmiGE35L40Abs)
        if bMILT40GE35DV is not None: dc.Links.Add(bMILT40GE35DV)
        result.Subtitle = "Possible Morbid (Severe) Obesity with Hypoventilation"
        AlertPassed = True
    #4
    elif (e6601Code is not None or e662Code is not None or e669Negation is not None or e66811Code is not None or e66812Code is not None or e66813Code is not None) and subtitle == "Possible Morbid (Severe) Obesity":
        AlertConditions = True
        if e6601Code is not None: updateLinkText(e6601Code, autoCodeText); dc.Links.Add(e6601Code)
        if e662Code is not None: updateLinkText(e662Code, autoCodeText); dc.Links.Add(e662Code)
        if e669Negation is not None: updateLinkText(e669Negation, autoCodeText); dc.Links.Add(e669Negation)
        if e66811Code is not None: updateLinkText(e66811Code, autoCodeText); dc.Links.Add(e66811Code)
        if e66812Code is not None: updateLinkText(e66812Code, autoCodeText); dc.Links.Add(e66812Code)
        if e66813Code is not None: updateLinkText(e66813Code, autoCodeText); dc.Links.Add(e66813Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to a fully specified code now existing on the Account"
        result.Validated = True

    elif e669Negation is None and e6601Code is None and e662Code is None and e66811Code is None and e66812Code is None and e66813Code is None and (bmiGTE40Codes is not None or bMIGTE40DV is not None or bmiGE40Abs is not None):
        if bmiGTE40Codes is not None: dc.Links.Add(bmiGTE40Codes)
        if bmiGE40Abs is not None: dc.Links.Add(bmiGE40Abs)
        if bMIGTE40DV is not None: dc.Links.Add(bMIGTE40DV)
        result.Subtitle = "Possible Morbid (Severe) Obesity"
        AlertPassed = True
    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Abs
    multiCodeValue(["Z68.41", "Z68.42", "Z68.43","Z68.44", "Z68.45"], "BMI: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, abs, True)
    multiCodeValue(["Z68.35", "Z68.36", "Z68.37", "Z68.38", "Z68.39"], "BMI: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, abs, True)
    abstractValue("DECREASED_FUNCTIONAL_CAPACITY", "Decreased Functional Capacity '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3, abs, True)
    abstractValue("DIAPHORETIC", "Diaphoretic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4, abs, True)
    abstractValue("DYSPNEA_ON_EXERTION", "Dyspnea on Exertion '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5, abs, True)
    abstractValue("HEIGHT", "Height: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6, abs, True)
    codeValue("G47.33", "Obstructive Sleep Apnea: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, abs, True)
    abstractValue("RESPIRATORY_ACIDOSIS", "Respiratory Acidosis '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, abs, True)
    abstractValue("SHORTNESS_OF_BREATH", "Shortness of Breath '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, abs, True)
    codeValue("G47.30", "Sleep Apnea: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, abs, True)
    abstractValue("WEIGHT", "Weight: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11, abs, True)
    #Labs
    if arterialBloodCO2DV is not None: labs.Links.Add(arterialBloodCO2DV) #1
    dvValue(dvPaO2, "Pa02: [VALUE] (Result Date: [RESULTDATETIME])", calcPAO21, 2, labs, True)
    if dvValue(dvArterialBloodPH, "Blood PH: [VALUE] (Result Date: [RESULTDATETIME])", calcArterialBloodPH1, 3, labs, True) is False:
        dvValue(dvPH, "PH: [VALUE] (Result Date: [RESULTDATETIME])", calcPH1, 4, labs, True)
    codeValue("R09.02", "Hypoxemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, labs, True)
    dvValue(dvSPO2, "Sp02: [VALUE] (Result Date: [RESULTDATETIME])", calcSPO21, 6, labs, True)
    dvValue(dvSerumBicarbonate, "Serum Bicarbonate: [VALUE] (Result Date: [RESULTDATETIME])", calcSerumBicarbonate1, 7, labs, True)
    if venousBloodCO2DV is not None: labs.Links.Add(venousBloodCO2DV) #8
    #Oxygen
    codeValue("Z99.81", "Home Oxygen Use: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, oxygen, True)
    if invasiveMechanicalVentilation is not None: oxygen.Links.Add(invasiveMechanicalVentilation) #2
    codeValue("3E0F7SF", "Nasal Cannula: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, oxygen, True)
    if nonInvasiveMechanicalVentilation is not None: oxygen.Links.Add(nonInvasiveMechanicalVentilation) #4

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    if oxygen.Links: result.Links.Add(oxygen); oxygenLinks = True
    if morbidity.Links: result.Links.Add(morbidity); morbidityLinks = True
    result.Links.Add(treatment)
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Documented Dx- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks) + ", Morbidity- "
        + str(morbidityLinks) + ", oxygen- " + str(oxygenLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
