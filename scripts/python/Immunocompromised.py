##################################################################################################################
#Evaluation Script - Immunocompromised
#
#This script checks an account to see if it matches criteria to be alerted for Immunocompromised
#Date - 11/24/2024
#Version - V12
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
dvAbsoluteNeutrophil = ["ABS NEUT COUNT (10x3/uL)"]
calcAbsoluteNeutrophil1 = lambda x: x < 1.5
dvhba1c = ["HEMOGLOBIN A1C (%)"]
calchba1c101 = lambda x: x > 10
dvHematocrit = ["HEMATOCRIT (%)", "HEMATOCRIT"]
calcHematocrit1 = lambda x: x < 34
calcHematocrit2 = lambda x: x < 40
dvHemoglobin = ["HEMOGLOBIN", "HEMOGLOBIN (g/dL)"]
calcHemoglobin1 = lambda x: x < 13.5
calcHemoglobin2 = lambda x: x < 12.5
dvPlateletCount = ["PLATELET COUNT (10x3/uL)"]
calcPlateletCount1 = lambda x: x < 150
dvWBC = ["WBC (10x3/ul)"]
calcWBC1 = lambda x: x < 4.5
calcWBC2 = lambda x: x > 11

dvCResp = [""]
dvCBlood = [""]
dvSARSCOVID = ["SARS-CoV2 (COVID-19)"]
dvSARSCOVIDAntigen = [""]
dvInfluenzeScreenA = ["Influenza A"]
dvInfluenzeScreenB = ["Influenza B"]
dvPneumococcalAntigen = [""]

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
            re.search(r'\bpositive\b', dvDic[dv]['Result'], re.IGNORECASE) is not None
        ):
            if abstract:
                dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return True
            else:
                abstraction = dataConversion(dvDic[dv]['ResultDate'], linkText, dvDic[dv]['Result'], dvDic[dv]['UniqueId'] or dvDic[dv]['_id'], category, sequence, abstract)
                return abstraction
    return abstraction

def dvPositiveCheck(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    abstraction = None
    for dv in dvDic or []:
        if (
            dvDic[dv]['Name'] in discreteValueName and
            dvDic[dv]['Result'] is not None and 
            re.search(r'\bpositive\b', dvDic[dv]['Result'], re.IGNORECASE) is not None
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
#Standard Variable Declaration
AlertPassed = False
alertTriggered = False
AlertConditions = False
validated = False
outcome = None
subtitle = None
reason = None
codesTrigger = False
infectionTrigger = False
medicationTrigger = False
chronicTrigger = False
dcLinks = False
infectionProcessLinks = False
medISLinks = False
chronicLinks = False
labsLinks = False
absLinks = False
treatmentLinks = False

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
infectonProcess = MatchedCriteriaLink("Infectious Process", None, "Infectious Process", None, True, None, None, 2)
medIS = MatchedCriteriaLink("Medication that can suppress the immune system", None, "Medication that can suppress the immune system", None, True, None, None, 3)
chronic = MatchedCriteriaLink("Chronic Conditions", None, "Chronic Conditions", None, True, None, None, 4)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 5)
treatment = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 6)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 7)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Immunocompromised':
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
    discreteSearchList = [i for j in [dvCBlood, dvSARSCOVID, dvSARSCOVIDAntigen, dvInfluenzeScreenA, 
                        dvInfluenzeScreenB, dvCResp, dvPneumococcalAntigen] for i in j]
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
    #Full Spec Codes
    d80Codes = prefixCodeValue("^D80\.", "Immunodeficiency with Predominantly Antibody Defects: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6)
    d81Codes = prefixCodeValue("^D81\.", "Combined Immunodeficiencies: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6)
    d82Codes = prefixCodeValue("^D82\.", "Immunodeficiency Associated with other Major Defects: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6)
    d83Codes = prefixCodeValue("^D83\.", "Common Variable Immunodeficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6)
    d84Codes = prefixCodeValue("^D84\.", "Other Immunodeficiencies: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6)
    #Infection
    b44Codes = prefixCodeValue("^B44\.", "Aspergillosis Infection: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    r7881Code = codeValue("R78.81", "Bacteremia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    b40Codes = prefixCodeValue("^B40\.", "Blastomycosis Infection: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3)
    cBloodDV = dvPositiveCheck(dict(maindiscreteDic), dvCBlood, "Blood Culture Result: '[VALUE]' (Result Date: [RESULTDATETIME])", 4)
    b43Codes = prefixCodeValue("^B43\.", "Chromomycosis And Pheomycotic Abscess Infection: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5)
    covidDV = dvPositiveCheck(dict(maindiscreteDic), dvSARSCOVID, "Covid 19 Screen: '[VALUE]' (Result Date: [RESULTDATETIME])", 6)
    covidAntiDV = dvPositiveCheck(dict(maindiscreteDic), dvSARSCOVIDAntigen, "Covid 19 Screen: '[VALUE]' (Result Date: [RESULTDATETIME])", 7)
    b45Codes = prefixCodeValue("^B45\.", "Cryptococcosis Infection: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8)
    b25Codes = prefixCodeValue("^B25\.", "Cytomegaloviral Disease Code: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9)
    infectionAbs = abstractValue("INFECTION", "Infection '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10)
    influenzeADV = dvPositiveCheck(dict(maindiscreteDic), dvInfluenzeScreenA, "Influenza A Screen: '[VALUE]' (Result Date: [RESULTDATETIME])", 11)
    influenzeBDV = dvPositiveCheck(dict(maindiscreteDic), dvInfluenzeScreenB, "Influenza B Screen: '[VALUE]' (Result Date: [RESULTDATETIME])", 12)
    b49Codes = prefixCodeValue("^B49\.", "Mycosis Infection: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13)
    b96Codes = prefixCodeValue("^B96\.", "Other Bacterial Agents As The Cause Of Diseases Infection: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14)
    b41Codes = prefixCodeValue("^B41\.", "Paracoccidioidomycosis Infection: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15)
    r835Code = codeValue("R83.5", "Positive Cerebrospinal Fluid Culture: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16)
    r845Code = codeValue("R84.5", "Positive Respiratory Culture: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17)
    posWoundCultAbs = abstractValue("POSITIVE_WOUND_CULTURE", "Positive Wound Culture '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 18)
    cRespDV = dvmrsaCheck(dict(maindiscreteDic), dvCResp, "Final Report", "Respiratory Blood Culture Result: '[VALUE]' (Result Date: [RESULTDATETIME])", 19)
    b42Codes = prefixCodeValue("^B42\.", "Sporotrichosis Infection: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20)
    pneumococcalAntiDV = dvPositiveCheck(dict(maindiscreteDic), dvPneumococcalAntigen, "Strept Pneumonia Screen: '[VALUE]' (Result Date: [RESULTDATETIME])", 21)
    b95Codes = prefixCodeValue("^B95\.", "Streptococcus, Staphylococcus, and Enterococcus Infection: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 22)
    b46Codes = prefixCodeValue("^B46\.", "Zygomycosis Infection: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23)
    #Medication That Can Suppress The Immune System
    antimetabolitesMed = medValue("Antimetabolite", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1)
    antimetabolitesAbs = abstractValue("ANTIMETABOLITE", "Antimetabolites '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2)
    z5111Code = codeValue("Z51.11", "Antineoplastic Chemotherapy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3)
    z5112Code = codeValue("Z51.12", "Antineoplastic Immunotherapy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4)
    antirejectionMed = medValue("Antirejection Medication", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 5)
    antirejectionMedAbs = abstractValue("ANTIREJECTION_MEDICATION", "Anti-Rejection Medication '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6)
    a3E04305Code = codeValue("3E04305", "Chemotherapy Administration: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7)
    interferonsMed = medValue("Interferon", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 8)
    interferonsAbs = abstractValue("INTERFERON", "Interferon '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9)
    z796Codes = prefixCodeValue("^Z79\.6", "Long term Immunomodulators and Immunosuppressants: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10)
    z7952Code = codeValue("Z79.52", "Long term Systemic Sterioids: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11)
    monoclonalAntibodiesMed = medValue("Monoclonal Antibodies", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 12)
    monoclonalAntibodiesAbs = abstractValue("MONOCLONAL_ANTIBODIES", "Monoclonal Antibodies '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13)
    tumorNecrosisMed = medValue("Tumor Necrosis Factor Alpha Inhibitor", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 14)
    tumorNecrosisAbs = abstractValue("TUMOR_NECROSIS_FACTOR_ALPHA_INHIBITOR", "Tumor Necrosis Factor Alpha Inhibitor '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 15)
    #Chronic Conditions
    alcoholismCodes = multiCodeValue(["F10.20", "F10.220", "F10.2221", "F10.2229", "F10.230",
        "F10.20", "F10.231", "F10.232", "F10.239", "F10.24", "F10.250", "F10.251", "F10.259", "F10.26",
        "F10.27", "F10.280", "F10.281", "F10.282", "F10.288", "F10.29"],
        "Alcoholism: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    q8901Code = codeValue("Q89.01", "Asplenia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    z9481Code = codeValue("Z94.81", "Bone Marrow Transplant: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3)
    e84Codes = prefixCodeValue("^E84\.", "Cystic Fibrosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4)
    k721Codes = prefixCodeValue("^K72\.1", "End Stage Liver Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5)
    n186Code = codeValue("N18.6", "ESRD: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6)
    c82Codes = prefixCodeValue("^C82\.", "Follicular Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7)
    z941Code = codeValue("Z94.1", "Heart Transplant: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8)
    z943Code = codeValue("Z94.3", "Heart and Lung Transplant: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9)
    b20Code = codeValue("B20", "HIV/AIDS: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10)
    c81Codes = prefixCodeValue("^C81\.", "Hodgkin Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11)
    c88Codes = prefixCodeValue("^C88\.", "Immunoproliferative Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12)
    z9482Code = codeValue("Z94.82", "Intestine Transplant: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13)
    z940Code = codeValue("Z94.0", "Kidney Transplant: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14)
    c95Codes = prefixCodeValue("^C95\.", "Leukemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15)
    c94Codes = prefixCodeValue("^C94\.", "Leukemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16)
    c93Codes = prefixCodeValue("^C93\.", "Leukemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17)
    c92Codes = prefixCodeValue("^C92\.", "Leukemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18)
    d72819Code = codeValue("D72.819", "Leukopenia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19)
    z944Code = codeValue("Z94.4", "Liver Transplant: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20)
    z942Code = codeValue("Z94.2", "Lung Transplant: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21)
    c91Codes = prefixCodeValue("^C91\.", "Lymphoid Leukemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 22)
    c85Codes = prefixCodeValue("^C85\.", "Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23)
    c86Codes = prefixCodeValue("^C86\.", "Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 24)
    m32Codes = prefixCodeValue("^M32\.", "Lupus: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 25)
    c96Codes = prefixCodeValue("^C96\.", "Malignant Neoplasms: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 26)
    c84Codes = prefixCodeValue("^C84\.", "Mature T/NK-Cell  Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 27)
    c90Codes = prefixCodeValue("^C90\.", "Multiple Myeloma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 28)
    d46Codes = prefixCodeValue("^D46\.", "Myelodysplastic Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 29)
    c83Codes = prefixCodeValue("^C83\.", "Non-Follicular Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 30)
    z9483Code = codeValue("Z94.83", "Pancreas Transplant: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 31)
    pancytopeniaCodes = multiCodeValue(["D61.810", "D61.811", "D61.818"], "Pancytopenia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 32)
    hba1cDV = dvValue(dvhba1c, "Poorly controlled HbA1c: [VALUE] (Result Date: [RESULTDATETIME])", calchba1c101, 33)
    m05Codes = prefixCodeValue("^M05\.", "RA: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 34)
    m06Codes = prefixCodeValue("^M06\.", "RA: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 35)
    severeMalnutritionCodes = multiCodeValue(["E40", "E41", "E42", "E43"], "Severe Malnutrition: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 36)
    r161Code = codeValue("R16.1", "Splenomegaly: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 37)
    #Labs
    wbcDV = dvValue(dvWBC, "WBC: [VALUE] (Result Date: [RESULTDATETIME])", calcWBC1, 2)
    
    #Spec Code Count
    if d80Codes is not None or d81Codes is not None or d82Codes is not None or d83Codes is not None or d84Codes is not None:
        codesTrigger = True
    #Infection Count
    if (
        b44Codes is not None or r7881Code is not None or  b40Codes is not None or cBloodDV is not None or b43Codes is not None or
        covidDV is not None or covidAntiDV is not None or b45Codes is not None or b25Codes is not None or infectionAbs is not None or
        influenzeADV is not None or influenzeBDV is not None or b49Codes is not None or b96Codes is not None or b41Codes is not None or
        r835Code is not None or r845Code is not None or posWoundCultAbs is not None or cRespDV is not None or b42Codes is not None or
        pneumococcalAntiDV is not None or b95Codes is not None or b46Codes is not None
    ):
        infectionTrigger = True
    #Meds Count
    if (
        antimetabolitesMed is not None or antimetabolitesAbs is not None or z5111Code is not None or z5112Code is not None or antirejectionMed is not None or
        antirejectionMedAbs is not None or a3E04305Code is not None or interferonsMed is not None or interferonsAbs is not None or z796Codes is not None or
        z7952Code is not None or monoclonalAntibodiesMed is not None or monoclonalAntibodiesAbs is not None or
        tumorNecrosisMed is not None or tumorNecrosisAbs is not None
    ):
        medicationTrigger = True
    #Chronic Count
    if (
        alcoholismCodes is not None or q8901Code is not None or z9481Code is not None or
        e84Codes is not None or k721Codes is not None or n186Code is not None or c82Codes is not None or z941Code is not None or
        z943Code is not None or b20Code is not None or c81Codes is not None or c88Codes is not None or z9482Code is not None or
        z940Code is not None or c95Codes is not None or c94Codes is not None or c93Codes is not None or
        c92Codes is not None or z944Code is not None or z942Code is not None or c91Codes is not None or c85Codes is not None or
        c86Codes is not None or m32Codes is not None or c96Codes is not None or c84Codes is not None or c90Codes is not None or
        d46Codes is not None or c83Codes is not None or z9483Code is not None or r161Code is not None or
        hba1cDV is not None or m05Codes is not None or m06Codes is not None or severeMalnutritionCodes is not None
    ):
        chronicTrigger = True
        
    #Algorithm
    if codesTrigger:
        db.LogEvaluationScriptMessage("One or more specific code(s) were on the chart, alert failed" + str(account._id), scriptName, scriptInstance, "Debug")
        if alertTriggered:
            if d80Codes is not None: updateLinkText(d80Codes, autoCodeText); dc.Links.Add(d80Codes)
            if d81Codes is not None: updateLinkText(d81Codes, autoCodeText); dc.Links.Add(d81Codes)
            if d82Codes is not None: updateLinkText(d82Codes, autoCodeText); dc.Links.Add(d82Codes)
            if d83Codes is not None: updateLinkText(d83Codes, autoCodeText); dc.Links.Add(d83Codes)
            if d84Codes is not None: updateLinkText(d84Codes, autoCodeText); dc.Links.Add(d84Codes)
            result.Outcome = "AUTORESOLVED"
            result.Reason = "Autoresolved due to one or more specified code(s) on the Account"
            result.Validated = True
            AlertConditions = True
        else: result.Passed = False

    elif codesTrigger is False and infectionTrigger and medicationTrigger and chronicTrigger:
        result.Subtitle = "Infection Present with Possible Link to Immunocompromised State Due to Chronic Condition and Medication"
        AlertPassed = True

    elif codesTrigger is False and infectionTrigger and medicationTrigger:
        result.Subtitle = "Infection Present with Possible Link to Immunocompromised State Due to Medication"
        AlertPassed = True
        
    elif codesTrigger is False and infectionTrigger and chronicTrigger:
        result.Subtitle = "Infection Present with Possible Link to Immunocompromised State Due to Chronic Condition"
        AlertPassed = True        

    elif codesTrigger is False and (pancytopeniaCodes is not None or d72819Code is not None or wbcDV is not None) and (medicationTrigger or chronicTrigger):
        if d72819Code is not None: chronic.Links.Add(d72819Code)
        if pancytopeniaCodes is not None: chronic.Links.Add(pancytopeniaCodes)
        result.Subtitle = "Possible Immunocompromised State"
        AlertPassed = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        AlertPassed = False
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#Alert Passed Abstractions
if AlertPassed:
    #Infection
    if b44Codes is not None: infectonProcess.Links.Add(b44Codes)
    if r7881Code is not None: infectonProcess.Links.Add(r7881Code)
    if b40Codes is not None: infectonProcess.Links.Add(b40Codes)
    if cBloodDV is not None: infectonProcess.Links.Add(cBloodDV)
    if b43Codes is not None: infectonProcess.Links.Add(b43Codes)
    if covidDV is not None: infectonProcess.Links.Add(covidDV)
    if covidAntiDV is not None: infectonProcess.Links.Add(covidAntiDV)
    if b45Codes is not None: infectonProcess.Links.Add(b45Codes)
    if b25Codes is not None: infectonProcess.Links.Add(b25Codes)
    if infectionAbs is not None: infectonProcess.Links.Add(infectionAbs)
    if influenzeADV is not None: infectonProcess.Links.Add(influenzeADV)
    if influenzeBDV is not None: infectonProcess.Links.Add(influenzeBDV)
    if b49Codes is not None: infectonProcess.Links.Add(b49Codes)
    if b96Codes is not None: infectonProcess.Links.Add(b96Codes)
    if b41Codes is not None: infectonProcess.Links.Add(b41Codes)
    if r835Code is not None: infectonProcess.Links.Add(r835Code)
    if r845Code is not None: infectonProcess.Links.Add(r845Code)
    if posWoundCultAbs is not None: infectonProcess.Links.Add(posWoundCultAbs)
    if cRespDV is not None: infectonProcess.Links.Add(cRespDV)
    if b42Codes is not None: infectonProcess.Links.Add(b42Codes)
    if pneumococcalAntiDV is not None: infectonProcess.Links.Add(pneumococcalAntiDV)
    if b95Codes is not None: infectonProcess.Links.Add(b95Codes)
    if b46Codes is not None: infectonProcess.Links.Add(b46Codes)
    #Meds
    if antimetabolitesMed is not None: medIS.Links.Add(antimetabolitesMed)
    if antimetabolitesAbs is not None: medIS.Links.Add(antimetabolitesAbs)
    if z5111Code is not None: medIS.Links.Add(z5111Code)
    if z5112Code is not None: medIS.Links.Add(z5112Code)
    if antirejectionMed is not None: medIS.Links.Add(antirejectionMed)
    if antirejectionMedAbs is not None: medIS.Links.Add(antirejectionMedAbs)
    if a3E04305Code is not None: medIS.Links.Add(a3E04305Code)
    if interferonsMed is not None: medIS.Links.Add(interferonsMed)
    if interferonsAbs is not None: medIS.Links.Add(interferonsAbs)
    if z796Codes is not None: medIS.Links.Add(z796Codes)
    if z7952Code is not None: medIS.Links.Add(z7952Code)
    if monoclonalAntibodiesMed is not None: medIS.Links.Add(monoclonalAntibodiesMed)
    if monoclonalAntibodiesAbs is not None: medIS.Links.Add(monoclonalAntibodiesAbs)
    if tumorNecrosisMed is not None: medIS.Links.Add(tumorNecrosisMed)
    if tumorNecrosisAbs is not None: medIS.Links.Add(tumorNecrosisAbs)
    #Infection Treatment
    antiboticMedValue(dict(mainMedDic), "Antibiotic", "Antibiotic: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, treatment, True)
    antiboticMedValue(dict(mainMedDic), "Antibiotic2", "Antibiotic: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 2, treatment, True)
    abstractValue("ANTIBIOTIC", "Antibiotic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3, treatment, True)
    abstractValue("ANTIBIOTIC_2", "Antibiotic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4, treatment, True)
    medValue("Antifungal", "Antifungal: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 5, treatment, True)
    abstractValue("ANTIFUNGAL", "Antifungal '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6, treatment, True)
    medValue("Antiviral", "Antiviral: [MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 7, treatment, True)
    abstractValue("ANTIVIRAL", "Antiviral '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, treatment, True)
    #Chronic
    if alcoholismCodes is not None: chronic.Links.Add(alcoholismCodes)
    if q8901Code is not None: chronic.Links.Add(q8901Code)
    if z9481Code is not None: chronic.Links.Add(z9481Code)
    if e84Codes is not None: chronic.Links.Add(e84Codes)
    if k721Codes is not None: chronic.Links.Add(k721Codes)
    if n186Code is not None: chronic.Links.Add(n186Code)
    if c82Codes is not None: chronic.Links.Add(c82Codes)
    if z941Code is not None: chronic.Links.Add(z941Code)
    if z943Code is not None: chronic.Links.Add(z943Code)
    if b20Code is not None: chronic.Links.Add(b20Code)
    if c81Codes is not None: chronic.Links.Add(c81Codes)
    if c88Codes is not None: chronic.Links.Add(c88Codes)
    if z9482Code is not None: chronic.Links.Add(z9482Code)
    if z940Code is not None: chronic.Links.Add(z940Code)
    if c95Codes is not None: chronic.Links.Add(c95Codes)
    if c94Codes is not None: chronic.Links.Add(c94Codes)
    if c93Codes is not None: chronic.Links.Add(c93Codes)
    if c92Codes is not None: chronic.Links.Add(c92Codes)
    if z944Code is not None: chronic.Links.Add(z944Code)
    if z942Code is not None: chronic.Links.Add(z942Code)
    if c91Codes is not None: chronic.Links.Add(c91Codes)
    if c85Codes is not None: chronic.Links.Add(c85Codes)
    if c86Codes is not None: chronic.Links.Add(c86Codes)
    if m32Codes is not None: chronic.Links.Add(m32Codes)
    if c96Codes is not None: chronic.Links.Add(c96Codes)
    if c84Codes is not None: chronic.Links.Add(c84Codes)
    if c90Codes is not None: chronic.Links.Add(c90Codes)
    if d46Codes is not None: chronic.Links.Add(d46Codes)
    if c83Codes is not None: chronic.Links.Add(c83Codes)
    if z9483Code is not None: chronic.Links.Add(z9483Code)
    if hba1cDV is not None: chronic.Links.Add(hba1cDV)
    if m05Codes is not None: chronic.Links.Add(m05Codes)
    if m06Codes is not None: chronic.Links.Add(m06Codes)
    if severeMalnutritionCodes is not None: chronic.Links.Add(severeMalnutritionCodes)
    if r161Code is not None: chronic.Links.Add(r161Code)
    #Labs
    dvValue(dvAbsoluteNeutrophil, "Absolute Neutropils: [VALUE] (Result Date: [RESULTDATETIME])", calcAbsoluteNeutrophil1, 1, labs, True)
    if wbcDV is not None: labs.Links.Add(wbcDV) #2
    
#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if infectonProcess.Links: result.Links.Add(infectonProcess); infectionProcessLinks = True
    if medIS.Links: result.Links.Add(medIS); medISLinks = True
    if chronic.Links: result.Links.Add(chronic); chronicLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    result.Links.Add(treatment)
    if treatment.Links: treatmentLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Infection Process- " + str(infectionProcessLinks) + ", Med IS- " + str(medISLinks) +
        ", Chronic- " + str(chronicLinks) + "Documented Dx- " + str(dcLinks) + "Labs- " + str(labsLinks) + 
        ", Treatment- " + str(treatmentLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
