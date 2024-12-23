##################################################################################################################
#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Pneumonia':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        subtitle = alert.Subtitle
        reason = alert.Reason
        if outcome == 'AUTORESOLVED' or reason == 'Previously Autoresolved':
            triggerAlert = False
        for alertLink in alert.Links:
            if alertLink.LinkText == 'Documentation Includes':
                for links in alertLink.Links:
                    if re.search(r'\bAssigned\b', links.LinkText, re.IGNORECASE):
                        assignedCode = True
        break
#Evaluation Script - Pneumonia
#
#This script checks an account to see if it matches criteria to be alerted for Pneumonia
#Date - 11/19/2024
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
    "A01.03": "Typhoid Pneumonia",
    "A02.22": "Salmonella Pneumonia",
    "A21.2": "Pulmonary Tularemia ",
    "A22.1": "Pulmonary Anthrax",
    "A42.0": "Pulmonary Actinomycosis",
    "A43.0": "Pulmonary Nocardiosis",
    "A54.84": "Gonococcal Pneumonia",
    "B01.2": "Varicella Pneumonia",
    "B05.2": "Measles Complicated By Pneumonia",
    "B06.81": "Rubella Pneumonia",
    "B25.0": "Cytomegaloviral Pneumonitis",
    "B37.1": "Pulmonary Candidiasis",
    "B38.0": "Acute Pulmonary Coccidioidomycosis",
    "B39.0": "Acute Pulmonary Histoplasmosis Capsulati",
    "B44.0": "Invasive Pulmonary Aspergillosis",
    "B44.1": "Other Pulmonary Aspergillosis",
    "B58.3": "Pulmonary Toxoplasmosis",
    "B59": "Pneumocystosis",
    "B77.81": "Ascariasis Pneumonia",
    "J12.0": "Adenoviral Pneumonia",
    "J12.1": "Respiratory Syncytial Virus Pneumonia",
    "J12.2": "Parainfluenza Virus Pneumonia",
    "J12.3": "Human Metapneumovirus Pneumonia",
    "J12.81": "Pneumonia Due To SARS-Associated Coronavirus",
    "J12.82": "Pneumonia Due To Coronavirus Disease 2019",
    "J14": "Pneumonia Due To Hemophilus Influenzae",
    "J15.0": "Pneumonia Due To Klebsiella Pneumoniae",
    "J15.1": "Pneumonia Due To Pseudomonas",
    "J15.20": "Pneumonia Due To Staphylococcus, Unspecified",
    "J15.211": "Pneumonia Due To Methicillin Susceptible Staphylococcus Aureus",
    "J15.212": "Pneumonia Due To Methicillin Resistant Staphylococcus Aureus",
    "J15.3": "Pneumonia Due To Streptococcus, Group B",
    "J15.4": "Pneumonia Due To Other Streptococci",
    "J15.5": "Pneumonia Due To Escherichia Coli",
    "J15.6": "Pneumonia Due To Other Gram-Negative Bacteria",
    "J15.61": "Pneumonia due to Acinetobacter Baumannii",
    "J15.7": "Pneumonia Due To Mycoplasma Pneumoniae",
    "J16.0": "Chlamydial Pneumonia",
    "J69.0": "Aspiration Pneumonia",
    "J69.1": "Pneumonitis Due To Inhalation Of Oils And Essences",
    "J69.8": "Pneumonitis Due To Inhalation Of Other Solids And Liquids",
    "A15.0": "Tuberculous Pneumonia",
    "J13": "Pneumonia due to Streptococcus Pneumoniae"
}
autoEvidenceText = "Autoresolved Evidence - "
autoCodeText = "Autoresolved Code - "

#========================================
#  Globals
#========================================
db = CACDataRepository()
admitDate = account.AdmitDateTime.Date
birthDate = account.Patient.BirthDate.Date
admitSource = account.AdmitSource
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
dvCBlood = [""]
dvRespCulture = [""]
dvMRSASCreen = ["MRSA DNA"]
dvSARSCOVID = ["SARS-CoV2 (COVID-19)"]
dvInfluenzeScreenA = ["Influenza A"]
dvInfluenzeScreenB = ["Influenza B"]
dvOxygenTherapy = ["DELIVERY"]
dvRSV = ["Respiratory syncytial virus"]
dvOxygenFlowRate = ["Resp O2 Delivery Flow Num"]
dvRespiratoryPattern = [""]

dvCreactiveProtein = ["C REACTIVE PROTEIN (mg/dL)"]
calcCreactiveProtein1 = lambda x: x > 0.3
dvGlasgowComaScale = ["3.5 Neuro Glasgow Score"]
calcGlasgowComaScale1 = lambda x: x < 15
dvInterleukin6 = ["INTERLEUKIN 6"]
calcInterleukin61 = lambda x: x > 7.0
dvPaO2 = ["BLD GAS O2 (mmHg)", "PO2 (mmHg)"]
calcPAO21 = lambda x: x < 80
dvPleuralFluidCulture = [""]
dvProcalcitonin = ["PROCALCITONIN (ng/mL)"]
calcProcalcitonin1 = lambda x: x > 0.50
dvRespiratoryRate = ["3.5 Respiratory Rate (#VS I&O) (per Minute)"]
calcRespiratoryRate1 = lambda x: x > 20
dvSputumCulture = [""]
dvTemperature = ["Temperature Degrees C 3.5 (degrees C)", "Temperature  Degrees C 3.5 (degrees C)", "TEMPERATURE (C)"]
calcTemperature1 = lambda x: x > 38.3
dvWBC = ["WBC (10x3/ul)"]
calcWBC1 = lambda x: x > 11
calcWBC2 = lambda x: x < 4.5

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

def ivMedValue(medDic, med_name, link_text, sequence=0, category=None, abstract=False):
    for mv in medDic or []:
        if (
            medDic[mv]['Route'] is not None and
            medDic[mv]['Category'] == med_name and
            (re.search(r'\bIntravenous\b', medDic[mv]['Route'], re.IGNORECASE) or
            re.search(r'\bIV Push\b', medDic[mv]['Route'], re.IGNORECASE)) and
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
TI = 0
UnspecDX = False
drugLinks = False
dcLinks = False
absLinks = False
labsLinks = False
vitalsLinks = False
oxygenLinks = False
medsLinks = False
docLinksLinks = False
assignedCode = False
gramPositive = 0
gramNegative = 0
fullSpec = 0
str0 = ": "

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 2)
vitals = MatchedCriteriaLink("Vital Signs/Intake and Output Data", None, "Vital Signs/Intake and Output Data", None, True, None, None, 3)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 4)
oxygen = MatchedCriteriaLink("Oxygenation/Ventilation", None, "Oxygenation/Ventilation", None, True, None, None, 5)
meds = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 6)
ctChestLinks = MatchedCriteriaLink("CT Chest", None, "CT Chest", None, True, None, None, 7)
chestXRayLinks = MatchedCriteriaLink("Chest X-Ray", None, "Chest X-Ray", None, True, None, None, 7)
speechLinks = MatchedCriteriaLink("Speech and Language Pathologist Notes", None, "Speech and Language Pathologist Notes", None, True, None, None, 7)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 8)
drug = MatchedCriteriaLink("Pneumonia Panel", None, "Pneumonia Panel", None, True, None, None, 89)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Pneumonia':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        subtitle = alert.Subtitle
        reason = alert.Reason
        if outcome == 'AUTORESOLVED' or reason == 'Previously Autoresolved':
            triggerAlert = False
        for alertLink in alert.Links:
            if alertLink.LinkText == 'Documentation Includes':
                for links in alertLink.Links:
                    if re.search(r'\bAssigned\b', links.LinkText, re.IGNORECASE):
                        assignedCode = True
        break

#Alert Trigger
unspecCodes = multiCodeValue(["J12.89", "J12.9", "J16.8", "J18", "J18.0", "J18.1", "J18.2", "J18.8", "J18.9", "J15.69", "J15.8", "J15.9"], "Unspecified Pneumonia Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 0)

#Check if alert was autoresolved or completed.
if (
    validated is False or
    (outcome == "AUTORESOLVED" and validated and (codesExist > 1 or unspecCodes is not None))
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
    
    #Find all discrete values for custom lookups within the last X days
    maindiscreteDic = {}
    unsortedDicsreteDic = {}
    dvCount = 0
    #Combine all items into one list to search against
    discreteSearchList = [i for j in [dvCBlood, dvRespCulture, dvPleuralFluidCulture, dvMRSASCreen, dvSARSCOVID, dvInfluenzeScreenA, 
        dvInfluenzeScreenB, dvInfluenzeScreenB, dvRSV, dvOxygenTherapy, dvSputumCulture] for i in j]
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
    
    #Conflicting Codes Gram Negative Bacteria
    j156Code = codeValue("J15.6", "Pneumonia due to Other Gram-negative bacteria: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    a0103Code = codeValue("A01.03", "Typhoid Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    a0222Code = codeValue("A02.22", "Salmonella Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    a212Code = codeValue("A21.2", "Tularemia Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    a5484Code = codeValue("A54.84", "Gonococcal Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    a698Code = codeValue("A69.8", "Spirochetal Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    b440Code = codeValue("B44.0", "Aspergillosis Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    b4411Code = codeValue("B44.11", "Aspergillosis Pneumonia Other: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    b583Code = codeValue("B58.3", "Toxoplasmosis Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    b59Code = codeValue("B59", "Pneumonia due to Pneumocystis Carinii, Pneumonia due to Pneumocystis Jiroveci: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j150Code = codeValue("J15.0", "Pneumonia due to Klebsiella Pneumoniae: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j151Code = codeValue("J15.1", "Pneumonia due to Pseudomonas: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j155Code = codeValue("J15.5", "Pneumonia due to Escherichia coli: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j1561Code = codeValue("J15.61", "Pneumonia due to Acinetobacter Baumannii: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j157Code = codeValue("J15.7", "Pneumonia due to Mycoplasma pneumoniae: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j160Code = codeValue("J16.0", "Chlamydial pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Conflicting Codes Gram Postive Bacteria
    j159Code = codeValue("J15.9", "Pneumonia due to due to gram-positive bacteria: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j152Code = codeValue("J15.2", "Pneumonia due to staphylococcus: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j1521Code = codeValue("J15.21", "Pneumonia due to staphylococcus aureus: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    a221Code = codeValue("A22.1", "Anthrax Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    a420Code = codeValue("A42.0", "Actinomycosis Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    a430Code = codeValue("A43.0", "Nocardiosis Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j13Code = codeValue("J13", "Pneumonia due to Streptococcus pneumoniae: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j15211Code = codeValue("J15.211", "Pneumonia due to Methicillin susceptible Staphylococcus aureus: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j15212Code = codeValue("J15.212", "Pneumonia due to Methicillin resistant Staphylococcus aureus: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j153Code = codeValue("J15.3", "Pneumonia due to streptococcus, group B: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j154Code = codeValue("J15.4", "Pneumonia due to Other Streptococci: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Conflicting Codes Other Full Spec Codes
    b012Code = codeValue("B01.2", "Varicella Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    b052Code = codeValue("B05.2", "Measles Complicated By Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    b0681Code = codeValue("B06.81", "Rubella Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    b250Code = codeValue("B25.0", "Cytomegaloviral Pneumonitis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    b371Code = codeValue("B37.1", "Pulmonary Candidiasis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    b380Code = codeValue("B38.0", "Acute Pulmonary Coccidioidomycosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    b390Code = codeValue("B39.0", "Acute Pulmonary Histoplasmosis Capsulati: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    b441Code = codeValue("B44.1", "Other Pulmonary Aspergillosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    b7781Code = codeValue("B77.81", "Ascariasis Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j120Code = codeValue("J12.0", "Adenoviral Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j121Code = codeValue("J12.1", "Respiratory Syncytial Virus Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j122Code = codeValue("J12.2", "Parainfluenza Virus Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j123Code = codeValue("J12.3", "Human Metapneumovirus Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j1281Code = codeValue("J12.81", "Pneumonia Due To SARS-Associated Coronavirus: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j1282Code = codeValue("J12.82", "Pneumonia Due To Coronavirus Disease 2019: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j14Code = codeValue("J14", "Pneumonia Due To Hemophilus Influenzae: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j1520Code = codeValue("J15.20", "Pneumonia Due To Staphylococcus, Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j1569Code = codeValue("J15.69", "Pneumonia due to Other Gram-Negative Bacteria: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j158Code = codeValue("J15.8", "Pneumonia Due To Other Specified Bacteria: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j690Code = codeValue("J69.0", "Aspiration Pneumonia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j691Code = codeValue("J69.1", "Pneumonitis Due To Inhalation Of Oils And Essences: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    j698Code = codeValue("J69.8", "Pneumonitis Due To Inhalation Of Other Solids And Liquids: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")       
    #Negations
    z7969Code = codeValue("Z79.69", "Unspecified Immunomodulators and Immunosuppressants: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    #Alert Trigger
    T17GasticCodes = multiCodeValue(["T17.310", "T17.308"], "Gastric Contents in Larynx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 0)
    T17FoodCodes = multiCodeValue(["T17.320", "T17.328"], "Food in Larynx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 0)
    #Abs
    abnormalSputumAbs = abstractValue("ABNORMAL_SPUTUM", "Abnormal Sputum '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1)
    r4182Code = codeValue("R41.82", "Altered Level of Consciousness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    alteredAbs = abstractValue("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level of Consciousness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3)
    aspirationAbs = abstractValue("ASPIRATION", "Aspiration '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4)
    bacterialPneumoniaOrganismAbs = abstractValue("BACTERIAL_PNEUMONIA_ORGANISM", "Possible Bacterial Pneumonia Organism '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5)
    r059Code = codeValue("R05.9", "Cough: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6)
    cracklesAbs = abstractValue("CRACKLES", "Crackles '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7)
    r131Codes = prefixCodeValue("^R13\.1", "Dysphagia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8)
    swallowStudyAbs = abstractValue("FAILED_SWALLOW_STUDY", "Failed Swallow study '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9)
    glascowComaScaleDV = dvValue(dvGlasgowComaScale, "Glascow Coma Scale: [VALUE] (Result Date: [RESULTDATETIME])", calcGlasgowComaScale1, 10)
    glascowComaScaleAbs = abstractValue("GLASCOW_COMA_SCALE", "Glascow Coma Scale: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11)
    gagReflexAbs = abstractValue("IMPAIRED_GAG_REFLEX", "Impaired Gag Reflex '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 12)
    irregularRadRepPneumoniaAbs = abstractValue("IRREGULAR_RADIOLOGY_REPORT_PNEUMONIA", "Irregular Radiology Report Lungs '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13)
    pleuralRubAbs = abstractValue("PLEURAL_RUB", "Pleural Rub '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 14)
    fungalPneumoniaOrganismAbs = abstractValue("FUNGAL_PNEUMONIA_ORGANISM", "Possible Fungal Pneumonia Organism '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 15)
    viralPneumoniaOrganismAbs = abstractValue("VIRAL_PNEUMONIA_ORGANISM", "Possible Viral Pneumonia Organism '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 16)
    rhonchiAbs = abstractValue("RHONCHI", "Rhonchi '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 18)
    sobAbs = abstractValue("SHORTNESS_OF_BREATH", "Shortness of Breath '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 19)
    accessoryMusclesAbs = abstractValue("USE_OF_ACCESSORY_MUSCLES", "Use of Accessory Muscles '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 20)
    wheezingAbs = abstractValue("WHEEZING", "Wheezing '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 21)
    #Labs
    CBloodDV = dvPositiveCheck(dict(maindiscreteDic), dvCBlood, "Blood Culture: '[VALUE]' (Result Date: [RESULTDATETIME])", 1)
    cReactiveProteinElevDV = dvValue(dvCreactiveProtein, "C Reactive Protein: [VALUE] (Result Date: [RESULTDATETIME])", calcCreactiveProtein1, 2)
    sARSCOVIDDV = dvPositiveCheck(dict(maindiscreteDic), dvSARSCOVID, "Covid 19 Screen: '[VALUE]' (Result Date: [RESULTDATETIME])", 3)
    r0902Code = codeValue("R09.02", "Hypoxemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4)
    interleukin6ElevDV = dvValue(dvInterleukin6, "Interleukin 6: [VALUE] (Result Date: [RESULTDATETIME])", calcInterleukin61, 5)
    MRSASCreenDV = dvPositiveCheck(dict(maindiscreteDic), dvMRSASCreen, "MRSA Screen: '[VALUE]' (Result Date: [RESULTDATETIME])", 6)
    pA02DV = dvValue(dvPaO2, "pa02: [VALUE] (Result Date: [RESULTDATETIME])", calcPAO21, 7)
    pleuralFluidCultureDV = dvPositiveCheck(dict(maindiscreteDic), dvPleuralFluidCulture, "Positive Pleural Fluid Culture: '[VALUE]' (Result Date: [RESULTDATETIME])", 8)
    r845Code = codeValue("R84.5", "Positive Respiratory Culture: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9)
    positiveSputumCultureDV = dvPositiveCheck(dict(maindiscreteDic), dvSputumCulture, "Positive Sputum Culture: '[VALUE]' (Result Date: [RESULTDATETIME])", 10)
    procalcitoninDV = dvValue(dvProcalcitonin, "Procalcitonin: [VALUE] (Result Date: [RESULTDATETIME])", calcProcalcitonin1, 11)
    RespCultureDV = dvPositiveCheck(dict(maindiscreteDic), dvRespCulture, "Respiratory Culture: '[VALUE]' (Result Date: [RESULTDATETIME])", 12)
    InfluenzeScreenADV = dvPositiveCheck(dict(maindiscreteDic), dvInfluenzeScreenA, "Respiratory Pathogen Panel (Influenza A): '[VALUE]' (Result Date: [RESULTDATETIME])", 13)
    InfluenzeScreenBDV = dvPositiveCheck(dict(maindiscreteDic), dvInfluenzeScreenB, "Respiratory Pathogen Panel (Influenza B): '[VALUE]' (Result Date: [RESULTDATETIME])", 14)
    rSVDV = dvPositiveCheck(dict(maindiscreteDic), dvRSV, "Respiratory Pathogen Panel (RSV): '[VALUE]' (Result Date: [RESULTDATETIME])", 15)
    #16
    highWBCDV = dvValue(dvWBC, "White Blood Cell Count: [VALUE] (Result Date: [RESULTDATETIME])", calcWBC1, 17)
    lowWBCDV = dvValue(dvWBC, "White Blood Cell Count: [VALUE] (Result Date: [RESULTDATETIME])", calcWBC2, 18)
    #Meds
    antibioticMed = antiboticMedValue(dict(mainMedDic), "Antibiotic", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1)
    antibiotic2Med = ivMedValue(dict(mainMedDic), "Antibiotic2", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 2)
    antibioticAbs = abstractValue("ANTIBIOTIC", "Antibiotic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3)
    antibiotic2Abs = abstractValue("ANTIBIOTIC_2", "Antibiotic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4)
    antifungalMed = medValue("Antifungal", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 5)
    antifungalAbs = abstractValue("ANTIFUNGAL", "Antifungal '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6)
    antiviralMed = medValue("Antiviral", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 7)
    antiviralAbs = abstractValue("ANTIVIRAL", "Antiviral '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8)
    #Oxygen
    oxygenTherapy = dvOxygenCheck(dict(maindiscreteDic), dvOxygenTherapy, "Oxygen Therapy '[VALUE]' (Result Date: [RESULTDATETIME])", 7)
    oxygenTherapyAbs = abstractValue("OXYGEN_THERAPY", "Oxygen Therapy '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8)
    #Vitals
    respiratoryRateDV = dvValue(dvRespiratoryRate, "Respiratory Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcRespiratoryRate1, 1)
    highTempDV = dvValue(dvTemperature, "Temperature: [VALUE] (Result Date: [RESULTDATETIME])", calcTemperature1, 3)

    #Checking Clinical Indicators
    if bacterialPneumoniaOrganismAbs is not None: abs.Links.Add(bacterialPneumoniaOrganismAbs); CI += 1
    if viralPneumoniaOrganismAbs is not None: abs.Links.Add(viralPneumoniaOrganismAbs); CI += 1
    if fungalPneumoniaOrganismAbs is not None: abs.Links.Add(fungalPneumoniaOrganismAbs); CI += 1
    if highTempDV is not None: CI += 1; vitals.Links.Add(highTempDV)
    if (highWBCDV is not None or
        lowWBCDV is not None
    ): 
        CI += 1
        if highWBCDV is not None: labs.Links.Add(highWBCDV)
        if lowWBCDV is not None: labs.Links.Add(lowWBCDV)
    if interleukin6ElevDV is not None: CI += 1; labs.Links.Add(interleukin6ElevDV)
    if cReactiveProteinElevDV is not None: CI += 1; labs.Links.Add(cReactiveProteinElevDV)
    if procalcitoninDV is not None: CI += 1; labs.Links.Add(procalcitoninDV)
    if glascowComaScaleDV is not None or glascowComaScaleAbs is not None:
        CI += 1
        if glascowComaScaleDV is not None: abs.Links.Add(glascowComaScaleDV)
        if glascowComaScaleAbs is not None: abs.Links.Add(glascowComaScaleAbs)
    if r4182Code is not None or alteredAbs is not None: 
        if r4182Code is not None:
            abs.Links.Add(r4182Code)
            if alteredAbs is not None: alteredAbs.Hidden = True; abs.Links.Add(alteredAbs)
        elif r4182Code is None and alteredAbs is not None:
            abs.Links.Add(alteredAbs)
        CI += 1
    if pA02DV is not None or r0902Code is not None:
        CI += 1
        if pA02DV is not None: labs.Links.Add(pA02DV)
        if r0902Code is not None: labs.Links.Add(r0902Code)
    if r059Code is not None: abs.Links.Add(r059Code); CI += 1
    if sobAbs is not None: abs.Links.Add(sobAbs); CI += 1
    if respiratoryRateDV is not None: CI += 1; vitals.Links.Add(respiratoryRateDV)
    if cracklesAbs is not None: abs.Links.Add(cracklesAbs); CI += 1
    if rhonchiAbs is not None: abs.Links.Add(rhonchiAbs); CI += 1
    if abnormalSputumAbs is not None: abs.Links.Add(abnormalSputumAbs); CI += 1
    if pleuralRubAbs is not None: abs.Links.Add(pleuralRubAbs); CI += 1
    if positiveSputumCultureDV is not None: CI += 1; labs.Links.Add(positiveSputumCultureDV)
    if pleuralFluidCultureDV is not None: CI += 1; labs.Links.Add(pleuralFluidCultureDV)
    if oxygenTherapy is not None or oxygenTherapyAbs is not None:
        if oxygenTherapy is not None: oxygen.Links.Add(oxygenTherapy)
        if oxygenTherapyAbs is not None: oxygen.Links.Add(oxygenTherapyAbs)
        CI += 1
    if r131Codes is not None: abs.Links.Add(r131Codes); CI += 1
    if swallowStudyAbs is not None: abs.Links.Add(swallowStudyAbs); CI += 1
    if gagReflexAbs is not None: abs.Links.Add(gagReflexAbs); CI += 1
    if accessoryMusclesAbs is not None: abs.Links.Add(accessoryMusclesAbs); CI += 1
    if wheezingAbs is not None: abs.Links.Add(wheezingAbs); CI += 1
    if irregularRadRepPneumoniaAbs is not None: abs.Links.Add(irregularRadRepPneumoniaAbs); CI += 1
    #Treatement Indicators
    if antiviralAbs is not None or antiviralMed is not None:
        if antiviralAbs is not None: meds.Links.Add(antiviralAbs)
        if antiviralMed is not None: meds.Links.Add(antiviralMed)
        TI += 1
    if antibioticAbs is not None or antibioticMed is not None or antibiotic2Med is not None or antibiotic2Abs is not None:
        if antibioticAbs is not None: meds.Links.Add(antibioticAbs)
        if antibioticMed is not None: meds.Links.Add(antibioticMed)
        if antibiotic2Med is not None: meds.Links.Add(antibiotic2Med)
        if antibiotic2Abs is not None: meds.Links.Add(antibiotic2Abs)
        TI += 1
    if antifungalAbs is not None or antifungalMed is not None:
        if antifungalAbs is not None: meds.Links.Add(antifungalAbs)
        if antifungalMed is not None: meds.Links.Add(antifungalMed)
        TI += 1
        
    #Conflicting Codes Calculations
    if a0103Code is not None: gramNegative += 1
    if a0222Code is not None: gramNegative += 1
    if a212Code is not None: gramNegative += 1
    if a5484Code is not None: gramNegative += 1
    if a698Code is not None: gramNegative += 1
    if b440Code is not None: gramNegative += 1
    if b4411Code is not None: gramNegative += 1
    if b583Code is not None: gramNegative += 1
    if b59Code is not None: gramNegative += 1
    if j150Code is not None: gramNegative += 1
    if j151Code is not None: gramNegative += 1
    if j155Code is not None: gramNegative += 1
    if j1561Code is not None: gramNegative += 1
    if j157Code is not None: gramNegative += 1
    if j160Code is not None: gramNegative += 1
    if j159Code is not None: gramPositive += 1
    if j152Code is not None: gramPositive += 1
    if j1521Code is not None: gramPositive += 1
    if a221Code is not None: gramPositive += 1
    if a420Code is not None: gramPositive += 1
    if a430Code is not None: gramPositive += 1
    if j13Code is not None: gramPositive += 1
    if j15211Code is not None: gramPositive += 1
    if j15212Code is not None: gramPositive += 1
    if j153Code is not None: gramPositive += 1
    if j154Code is not None: gramPositive += 1
    if b012Code is not None: fullSpec += 1
    if b052Code is not None: fullSpec += 1
    if b0681Code is not None: fullSpec += 1
    if b250Code is not None: fullSpec += 1
    if b371Code is not None: fullSpec += 1
    if b380Code is not None: fullSpec += 1
    if b390Code is not None: fullSpec += 1
    if b441Code is not None: fullSpec += 1
    if b7781Code is not None: fullSpec += 1
    if j120Code is not None: fullSpec += 1
    if j121Code is not None: fullSpec += 1
    if j122Code is not None: fullSpec += 1
    if j123Code is not None: fullSpec += 1
    if j1281Code is not None: fullSpec += 1
    if j1282Code is not None: fullSpec += 1
    if j14Code is not None: fullSpec += 1
    if j1520Code is not None: fullSpec += 1
    if j1569Code is not None: fullSpec += 1
    if j158Code is not None: fullSpec += 1
    if j690Code is not None: fullSpec += 1
    if j691Code is not None: fullSpec += 1
    if j698Code is not None: fullSpec += 1

    #Admit Source Translation
    admitTrans = None
    if admitSource == "4":
        admitTrans = "Transferred from Another Hospital"
    elif admitSource == "5":
        admitTrans = "Transfer from Skilled Nursing"
    elif admitSource == "6":
        admitTrans = "Transfer from Another Health Care Center"
        
    #Main Algorithm
    if triggerAlert and (unspecCodes is not None or codesExist == 1) and ((admitSource == "TH" or admitSource == "TE" or admitSource == "TA") and admitTrans is not None):
        if codesExist == 1:
            for code in codeList:
                desc = codeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    dc.Links.Add(tempCode)
                    break
        if unspecCodes is not None: dc.Links.Add(unspecCodes)
        if admitTrans is not None: dc.Links.Add(MatchedCriteriaLink("Admit Source: " + str(admitTrans), None, None, None))
        result.Subtitle = "Possible Hospital Acquired Pneumonia"
        AlertConditions = True
        result.Passed = True

    elif codesExist == 1:
        db.LogEvaluationScriptMessage("One specific code was on the chart, alert failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        if alertTriggered:
            for code in codeList:
                desc = codeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code  - " + desc + ": [CODE] '[PHRASE]' '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    dc.Links.Add(tempCode)
                    break
            result.Outcome = "AUTORESOLVED"
            result.Reason = "Autoresolved due to one Specified Code on the Account"
            result.Validated = True
            AlertConditions = True
        else: result.Passed = False
        
    elif (
        #1
        ((j156Code is not None and (fullSpec > 0 or gramPositive > 0 or gramNegative > 2)) or (j156Code is None and fullSpec > 0 and (gramPositive > 0 or gramNegative > 0))) or
        #2
        ((j159Code is not None and (fullSpec > 0 or gramPositive > 2 or gramNegative > 0)) or (j159Code is None and fullSpec > 0 and (gramPositive > 0 or gramNegative > 0))) or
        #3
        ((j15211Code is not None and j1521Code is None and (fullSpec > 0 or gramPositive > 2 or gramNegative > 0)) or
        (j15211Code is None and j1521Code is not None and (fullSpec > 0 or gramPositive > 2 or gramNegative > 0)) or
        (j15211Code is not None and j1521Code is not None and (fullSpec > 0 or gramPositive > 3 or gramNegative > 0))) or
        #4
        ((j158Code is not None and (fullSpec > 0 or gramPositive > 2 or gramNegative > 0)) or (j158Code is None and fullSpec > 0 and (gramPositive > 0 or gramNegative > 0))) or
        #5
        (fullSpec > 1)
    ):
        if b012Code is not None: dc.Links.Add(b012Code); str0 = str0 + b012Code.Code + ", "
        if b052Code is not None: dc.Links.Add(b052Code); str0 = str0 + b052Code.Code + ", "
        if b0681Code is not None: dc.Links.Add(b0681Code); str0 = str0 + b0681Code.Code + ", "
        if b250Code is not None: dc.Links.Add(b250Code); str0 = str0 + b250Code.Code + ", "
        if b371Code is not None: dc.Links.Add(b371Code); str0 = str0 + b371Code.Code + ", "
        if b380Code is not None: dc.Links.Add(b380Code); str0 = str0 + b380Code.Code + ", "
        if b390Code is not None: dc.Links.Add(b390Code); str0 = str0 + b390Code.Code + ", "
        if b441Code is not None: dc.Links.Add(b441Code); str0 = str0 + b441Code.Code + ", "
        if b7781Code is not None: dc.Links.Add(b7781Code); str0 = str0 + b7781Code.Code + ", "
        if j120Code is not None: dc.Links.Add(j120Code); str0 = str0 + j120Code.Code + ", "
        if j121Code is not None: dc.Links.Add(j121Code); str0 = str0 + j121Code.Code + ", "
        if j122Code is not None: dc.Links.Add(j122Code); str0 = str0 + j122Code.Code + ", "
        if j123Code is not None: dc.Links.Add(j123Code); str0 = str0 + j123Code.Code + ", "
        if j1281Code is not None: dc.Links.Add(j1281Code); str0 = str0 + j1281Code.Code + ", "
        if j1282Code is not None: dc.Links.Add(j1282Code); str0 = str0 + j1282Code.Code + ", "
        if j14Code is not None: dc.Links.Add(j14Code); str0 = str0 + j14Code.Code + ", "
        if j1520Code is not None: dc.Links.Add(j1520Code); str0 = str0 + j1520Code.Code + ", "
        if j1569Code is not None: dc.Links.Add(j1569Code); str0 = str0 + j1569Code.Code + ", "
        if j158Code is not None: dc.Links.Add(j158Code); str0 = str0 + j158Code.Code + ", "
        if j690Code is not None: dc.Links.Add(j690Code); str0 = str0 + j690Code.Code + ", "
        if j691Code is not None: dc.Links.Add(j691Code); str0 = str0 + j691Code.Code + ", "
        if j698Code is not None: dc.Links.Add(j698Code); str0 = str0 + j698Code.Code + ", "
        if j159Code is not None: dc.Links.Add(j159Code); str0 = str0 + j159Code.Code + ", "
        if j152Code is not None: dc.Links.Add(j152Code); str0 = str0 + j152Code.Code + ", "
        if j1521Code is not None: dc.Links.Add(j1521Code); str0 = str0 + j1521Code.Code + ", "
        if a221Code is not None: dc.Links.Add(a221Code); str0 = str0 + a221Code.Code + ", "
        if a420Code is not None: dc.Links.Add(a420Code); str0 = str0 + a420Code.Code + ", "
        if a430Code is not None: dc.Links.Add(a430Code); str0 = str0 + a430Code.Code + ", "
        if j13Code is not None: dc.Links.Add(j13Code); str0 = str0 + j13Code.Code + ", "
        if j15211Code is not None: dc.Links.Add(j15211Code); str0 = str0 + j15211Code.Code + ", "
        if j15212Code is not None: dc.Links.Add(j15212Code); str0 = str0 + j15212Code.Code + ", "
        if j153Code is not None: dc.Links.Add(j153Code); str0 = str0 + j153Code.Code + ", "
        if j154Code is not None: dc.Links.Add(j154Code); str0 = str0 + j154Code.Code + ", "
        if j156Code is not None: dc.Links.Add(j156Code); str0 = str0 + j156Code.Code + ", "
        if a0103Code is not None: dc.Links.Add(a0103Code); str0 = str0 + a0103Code.Code + ", "
        if a0222Code is not None: dc.Links.Add(a0222Code); str0 = str0 + a0222Code.Code + ", "
        if a212Code is not None: dc.Links.Add(a212Code); str0 = str0 + a212Code.Code + ", "
        if a5484Code is not None: dc.Links.Add(a5484Code); str0 = str0 + a5484Code.Code + ", "
        if a698Code is not None: dc.Links.Add(a698Code); str0 = str0 + a698Code.Code + ", "
        if b440Code is not None: dc.Links.Add(b440Code); str0 = str0 + b440Code.Code + ", "
        if b4411Code is not None: dc.Links.Add(b4411Code); str0 = str0 + b4411Code.Code + ", "
        if b583Code is not None: dc.Links.Add(b583Code); str0 = str0 + b583Code.Code + ", "
        if b59Code is not None: dc.Links.Add(b59Code); str0 = str0 + b59Code.Code + ", "
        if j150Code is not None: dc.Links.Add(j150Code); str0 = str0 + j150Code.Code + ", "
        if j151Code is not None: dc.Links.Add(j151Code); str0 = str0 + j151Code.Code + ", "
        if j155Code is not None: dc.Links.Add(j155Code); str0 = str0 + j155Code.Code + ", "
        if j1561Code is not None: dc.Links.Add(j1561Code); str0 = str0 + j1561Code.Code + ", "
        if j157Code is not None: dc.Links.Add(j157Code); str0 = str0 + j157Code.Code + ", "
        if j160Code is not None: dc.Links.Add(j160Code); str0 = str0 + j160Code.Code + ", "
        result.Subtitle = "Pneumonia Conflicting Dx" + str0
        if validated:
            result.Validated = False
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"
        AlertPassed = True

    elif triggerAlert and unspecCodes is not None and (aspirationAbs is not None or T17GasticCodes is not None or T17FoodCodes is not None):
        if unspecCodes is not None: dc.Links.Add(unspecCodes)
        if aspirationAbs is not None: dc.Links.Add(aspirationAbs)
        if T17GasticCodes is not None: dc.Links.Add(T17GasticCodes)
        if T17FoodCodes is not None: dc.Links.Add(T17FoodCodes)
        result.Subtitle = "Possible Aspiration Pneumonia"
        AlertPassed = True

    elif (
        unspecCodes is not None and
        (r845Code is not None or
        CBloodDV is not None or
        RespCultureDV is not None or
        MRSASCreenDV is not None or
        sARSCOVIDDV is not None or
        InfluenzeScreenADV is not None or
        InfluenzeScreenBDV is not None or
        rSVDV is not None or
        viralPneumoniaOrganismAbs is not None or
        bacterialPneumoniaOrganismAbs is not None or
        fungalPneumoniaOrganismAbs is not None or
        drug.Links)
    ):
        dc.Links.Add(unspecCodes)
        if r845Code is not None: dc.Links.Add(r845Code)
        if CBloodDV is not None: dc.Links.Add(CBloodDV)
        if RespCultureDV is not None: dc.Links.Add(RespCultureDV)
        if MRSASCreenDV is not None: dc.Links.Add(MRSASCreenDV)
        if sARSCOVIDDV is not None: dc.Links.Add(sARSCOVIDDV)
        if InfluenzeScreenADV is not None: dc.Links.Add(InfluenzeScreenADV)
        if InfluenzeScreenBDV is not None: dc.Links.Add(InfluenzeScreenBDV)
        if rSVDV is not None: dc.Links.Add(rSVDV)
        result.Subtitle = "Pneumonia Dx Unspecified"
        AlertPassed = True
        UnspecDX = True
        
    elif triggerAlert and unspecCodes is None and CI >= 2 and irregularRadRepPneumoniaAbs is not None and (aspirationAbs is not None or T17GasticCodes is not None or T17FoodCodes is not None):
        dc.Links.Add(irregularRadRepPneumoniaAbs)
        if aspirationAbs is not None: dc.Links.Add(aspirationAbs)
        if T17GasticCodes is not None: dc.Links.Add(T17GasticCodes)
        if T17FoodCodes is not None: dc.Links.Add(T17FoodCodes)
        result.Subtitle = "Possible Aspiration Pneumonia"
        AlertConditions = True
        result.Passed = True
        
    elif unspecCodes is not None and antibiotic2Med is not None:
        dc.Links.Add(unspecCodes)
        result.Subtitle = "Possible Complex Pneumonia"
        AlertConditions = True
        result.Passed = True
        
    elif subtitle == "Possible Pneumonia Dx" and unspecCodes is not None:
        updateLinkText(unspecCodes, autoCodeText); dc.Links.Add(unspecCodes)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code on the Account"
        result.Validated = True
        AlertConditions = True
    
    elif triggerAlert and CI >= 2 and TI >= 1 and irregularRadRepPneumoniaAbs is not None and unspecCodes is None:
        dc.Links.Add(irregularRadRepPneumoniaAbs)
        result.Subtitle = "Possible Pneumonia Dx"
        AlertConditions = True
        result.Passed = True       

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Abs
    abstractValue("RESPIRATORY_BREATH_SOUNDS", "Respiratory Breath Sounds '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 17, abs, True)
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
    documentLink("OP SLP Evaluation - Clinical Swallow (Dysphagia), Speech and Cognitive", "OP SLP Evaluation - Clinical Swallow (Dysphagia), Speech and Cognitive", 0, speechLinks, True)
    documentLink("OP SLP Evaluation - Clinical Swallow (Dysphagia), Motor Speech and Voice", "OP SLP Evaluation - Clinical Swallow (Dysphagia), Motor Speech and Voice", 0, speechLinks, True)
    documentLink("OP SLP Evaluation - Language -Motor Speech-Dysphagia", "OP SLP Evaluation - Language -Motor Speech-Dysphagia", 0, speechLinks, True)
    documentLink("OP SLP Evaluation - Motor Speech-Dysphagia", "OP SLP Evaluation - Motor Speech-Dysphagia", 0, speechLinks, True)
    #Labs
    if r845Code is not None and UnspecDX == False: labs.Links.Add(r845Code) #16
    #Oxygen
    multiCodeValue(["5A0935A", "5A0945A", "5A0955A"], "Flow Nasal Oxygen: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, oxygen, True)
    codeValue("5A1945Z", "Mechanical Ventilation 24 to 96 hours: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, oxygen, True)
    codeValue("5A1955Z", "Mechanical Ventilation Greater than 96 hours: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, oxygen, True)
    codeValue("Z99.1", "Mechanical Ventilation/Invasive Ventilation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, oxygen, True)
    codeValue("5A1935Z", "Mechanical Ventilation Less than 24 hours: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, oxygen, True)
    abstractValue("NON_INVASIVE_VENTILATION", "Non-Invasive Ventilation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6, oxygen, True)
    #7-8
    
#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if drug.Links: labs.Links.Add(drug); drugLinks = True
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    if vitals.Links: result.Links.Add(vitals); vitalsLinks = True
    if oxygen.Links: result.Links.Add(oxygen); oxygenLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    if speechLinks.Links: result.Links.Add(speechLinks); docLinksLinks = True
    if ctChestLinks.Links: result.Links.Add(ctChestLinks); docLinksLinks = True
    if chestXRayLinks.Links: result.Links.Add(chestXRayLinks); docLinksLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Documented Dx- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks) + ", vitals- " + str(vitalsLinks) + ", meds- " + str(medsLinks) + ", oxygen- " + str(oxygenLinks) + ", drug- "
        + str(drugLinks) + ", docs- " + str(docLinksLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
