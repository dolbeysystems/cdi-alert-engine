##################################################################################################################
#Evaluation Script - Cerebral Edma and Brain Compression
#
#This script checks an account to see if it matches criteria to be alerted for Cerebral Edma and Brain Compression
#Date - 10/22/2024
#Version - V13
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
edmaCodeDic = {
    "G93.6": "Cerebral Edema",
    "S06.1X0A": "Traumatic Cerebral Edema Without Loss Of Consciousness",
    "S06.1X1A": "Traumatic Cerebral Edema With Loss Of Consciousness Of 30 Minutes Or Less",
    "S06.1X2A": "Traumatic Cerebral Edema With Loss Of Consciousness Of 31 Minutes To 59 Minutes",
    "SO6.1X3A": "Traumatic Cerebral Edema With Loss Of Consciousness Of 1 Hour To 5 Hours 59 Minutes",
    "SO6.1X4A": "Traumatic Cerebral Edema With Loss Of Consciousness Of 6 Hours To 24 Hours",
    "SO6.1X5A": "Traumatic Cerebral Edema With Loss Of Consciousness Greater Than 24 Hours With Return To Pre-Existing Conscious Level",
    "SO6.1X6A": "Traumatic Cerebral Edema With Loss Of Consciousness Greater Than 24 Hours Without Return To Pre-Existing Conscious Level With Patient Surviving",
    "SO6.1X7A": "Traumatic Cerebral Edema With Loss Of Consciousness Of Any Duration With Death Due To Brain Injury Prior To Regaining Consciousness",
    "S06.1X8A": "Traumatic Cerebral Edema With Loss Of Consciousness Of Any Duration With Death Due To Other Cause Prior To Regaining Consciousness",
    "SO6.1X9A": "Traumatic Cerebral Edema With Loss Of Consciousness Of Unspecified Duration"
}
compressionCodeDic = {
    "G93.5": "Compression Of Brain",
    "S06.A0XA": "Traumatic Brain Compression Without Herniation",
    "S06.A1XA": "Traumatic Brain Compression With Herniation"
}
documentList = [
    "Operative Note Neurosurgery Resident Physician",
    "Operative Note Neurosurgery Physician",
    "Operative Note Neurosurgery HIM"
]

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
dvGlasgowComaScale = ["3.5 Neuro Glasgow Score"]
calcGlasgowComaScale1 = lambda x: x < 15
dvHeartRate = ["Heart Rate cc (bpm)", "3.5 Heart Rate (Apical) (bpm)", "3.5 Heart Rate (Other) (bpm)", "3.5 Heart Rate (Radial) (bpm)",  "SCC Monitor Pulse (bpm)"]
calcHeartRate1 = lambda x: x < 60
dvImmatureReticulocyteFraction = [""]
calcImmatureReticulocyteFraction1 = lambda x: x < 3
dvIntracranialPressure = ["ICP cc (mm Hg)"]
calcIntracranialPressure1 = lambda x: x > 15
dvRespiratoryRate = ["3.5 Respiratory Rate (#VS I&O) (per Minute)"]
calcRespiratoryRate1 = lambda x: x < 12

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

def documentDataConversion(DocumentType, id, sequence, category, abstract):
    if abstract == True:
        category.Links.Add(MatchedCriteriaLink(DocumentType, id,None, None, True, None, None, sequence))
    elif abstract == False:
        abstraction = MatchedCriteriaLink(DocumentType, id, None, None,  True, None, None, sequence)
        return abstraction
    return

def docMedValue(medDic, docList, med, link_text, category, sequence, abstract=True):
    docsPresent = False
    docDate = None
    matchedDic = {}
    documentId = None
    DocumentType = None
    x = 0
    matchedList = []

    for doc in account.Documents:
        if any(item == doc.DocumentType for item in docList):
                docsPresent = True
                docDate = doc.DocumentDateTime
                DocumentType = doc.DocumentType
                documentId = doc.DocumentId

    if docsPresent:
        for mv in medDic or []:
            if medDic[mv]['Category'] in med and medDic[mv]['ResultDate'] <= docDate:
                x += 1
                matchedDic[x] = medDic[mv]

    if x > 0:
        if abstract == True:
            medDataConversion(matchedDic[x].StartDate, link_text, matchedDic[x].Medication, matchedDic[x].ExternalId, matchedDic[x].Dosage, matchedDic[x].Route, category, sequence, abstract)
            documentDataConversion(DocumentType, documentId, sequence, category, abstract)
            return True
        elif abstract == False:
            matchedList.append(medDataConversion(matchedDic[x].StartDate, link_text, matchedDic[x].Medication, matchedDic[x].ExternalId, matchedDic[x].Dosage, matchedDic[x].Route, category, sequence, abstract))
            matchedList.append(documentDataConversion(DocumentType, documentId, sequence, category, abstract))
            return matchedList
    else:
        return None
    
def aerosolMedValue(medDic, med_name, link_text, sequence=0, category=None, abstract=False):
    for mv in medDic or []:
        if (
            medDic[mv]['Route'] is not None and
            medDic[mv]['Category'] == med_name and
            re.search(r'\bAerosol\b', medDic[mv]['Route'], re.IGNORECASE) is None
        ):
            if abstract == True:
                medDataConversion(medDic[mv]['StartDate'], link_text, medDic[mv]['Medication'], medDic[mv]['ExternalId'], medDic[mv]['Dosage'], medDic[mv]['Route'], category, sequence)
                return True
            elif abstract == False:
                abstraction = medDataConversion(medDic[mv]['StartDate'], link_text, medDic[mv]['Medication'], medDic[mv]['ExternalId'], medDic[mv]['Dosage'], medDic[mv]['Route'], category, sequence, abstract)
                return abstraction
    return None
    
#========================================
#  Algorithm
#========================================
db.LogEvaluationScriptMessage("Script starting " + str(account._id), scriptName, scriptInstance, "Debug")
#Determine if if and how many fully spec codes are on the acct
edmaCodes = []
edmaCodes = edmaCodeDic.keys()
edmaCodeList = CodeCount(edmaCodes)
edmaCodesExist = len(edmaCodeList)
str1 = ', '.join([str(elem) for elem in edmaCodeList])
compressionCodes = []
compressionCodes = compressionCodeDic.keys()
compressionCodeList = CodeCount(compressionCodes)
compressionCodesExist = len(compressionCodeList)
str2 = ', '.join([str(elem) for elem in compressionCodeList])

#Standard Variable Declaration
AlertPassed = False
alertTriggered = False
AlertConditions = False
validated = False
subtitle = None
outcome = None
TC = False
CC = False
negationCheck = False
dcLinks = False
absLinks = False
vitalsLinks = False
docLinksLinks = False
treatmentLinks = False

#Initalize categories
dc = MatchedCriteriaLink("Documented Code", None, "Documented Code", None, True, None, None, 1)
vitals = MatchedCriteriaLink("Vital Signs/Intake and Output Data", None, "Vital Signs/Intake and Output Data", None, True, None, None, 2)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 3)
treatment = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 4)
ctHeadBrainLinks = MatchedCriteriaLink("CT Head/Brain", None, "CT Head/Brain", None, True, None, None, 5)
mriBrainLinks = MatchedCriteriaLink("MRI Brain", None, "MRI Brain", None, True, None, None, 5)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 6)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Cerebral Edema/Brain Compression':
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
    medSearchList = ["Mannitol", "Dexamethasone", "Methylprednisolone", "Hypertonic Saline"]
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
    
    #Negations
    cervicalDecompressionAbs = abstractValue("CERVICAL_DECOMPRESSION", "Cervical Decompression '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0)
    cervicalFusionAbs = abstractValue("CERVICAL_FUSION", "Cervical Fusion '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0)
    lumbarDecompressionAbs = abstractValue("LUMBAR_DECOMPRESSION", "Lumbar Decompression '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0)
    lumbarFusionAbs = abstractValue("LUMBAR_FUSION", "Lumbar Fusion '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0)
    sacralDecompressionAbs = abstractValue("SACRAL_DECOMPRESSION", "Sacral Decompression '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0)
    sacralFusionAbs = abstractValue("SACRAL_FUSION", "Sacral Fusion '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0)
    thoracicDecompressionAbs = abstractValue("THORACIC_DECOMPRESSION", "Thoracic Decompression '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0)
    thoracicFusionAbs = abstractValue("THORACIC_FUSION", "Thoracic Fusion '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0)
    #Alert Trigger
    mannitolMedDoc = docMedValue(dict(mainMedDic), documentList, "Mannitol", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", dc, 1, False)
    dexamethasoneMedDoc = docMedValue(dict(mainMedDic), documentList, "Dexamethasone", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", dc, 1, False)
    #Abs
    brainCompressionAbs = abstractValue("BRAIN_COMPRESSION", "Brain Compression '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 3)
    brainHerniationAbs = abstractValue("BRAIN_HERNIATION", "Brain Herniation '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 5)
    brainPressureAbs = abstractValue("BRAIN_PRESSURE", "Brain Pressure '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6)
    cerebralEdemaAbs = abstractValue("CEREBRAL_EDEMA", "Cerebral Edema '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8)
    cerebralVentriEffacAbs = abstractValue("CEREBRAL_VENTRICLE_EFFACEMENT", "Cerebral Ventricle Effacement '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10)
    massEffectAbs = abstractValue("MASS_EFFECT", "Mass Effect '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 24)
    sulcalEffacementAbs = abstractValue("SULCAL_EFFACEMENT", "Sulcal Effacement '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 30)
    #Treatment
    burrHolesCodes = multiCodeValue(["00943ZZ", "00C40ZZ"], "Burr Holes: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7)
    decomCraniectomyCode = codeValue("00N00ZZ", "Decompressive Craniectomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12)
    hyperTonicSalMed = aerosolMedValue(dict(mainMedDic), "Hypertonic Saline", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 18)
    hyperVentTherapyAbs = abstractValue("HYPERVENTILATION_THERAPY", "Hyperventilation Therapy '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 20)
    subarchoidBoltCode = codeValue("00H032Z", "Subarchnoid/Epidural Bolt: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 27)
    ventriculostomyCodes = multiCodeValue(["009600Z", "009630Z", "009640Z"], "Ventriculostomy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 28)
    #Vitals
    intraPressureDV = dvValue(dvIntracranialPressure, "Intracranial Pressure: [VALUE] (Result Date: [RESULTDATETIME])", calcIntracranialPressure1, 3)
    intraPressureAbs = abstractValue("ELEVATED_INTRACRANIAL_PRESSURE", "Intracranial Pressure: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4)
    
    #Negations Check
    if ( 
        cervicalDecompressionAbs is not None or
        cervicalFusionAbs is not None or
        lumbarDecompressionAbs is not None or
        lumbarFusionAbs is not None or
        sacralDecompressionAbs is not None or
        sacralFusionAbs is not None or
        thoracicDecompressionAbs is not None or
        thoracicFusionAbs is not None
    ):
        negationCheck = True

    #Main Algorithm
    #1
    if edmaCodesExist > 1:
        for code in edmaCodeList:
            tempCode = accountContainer.GetFirstCodeLink(code, "Specified Code Present: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            dc.Links.Add(tempCode)
        result.Subtitle = "Cerebral Edema Conflicting Dx " + str1
        if validated:
            result.Validated = False
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"
        AlertPassed = True
    #2
    elif compressionCodesExist > 1:
        for code in compressionCodeList:
            tempCode = accountContainer.GetFirstCodeLink(code, "Specified Code Present: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
            dc.Links.Add(tempCode)
        result.Subtitle = "Brain Compression Conflicting Dx " + str2
        if validated:
            result.Validated = False
            result.Outcome = ""
            result.Reason = "Previously Autoresolved"
        AlertPassed = True
    #3
    elif brainCompressionAbs is not None and compressionCodesExist == 0 and cerebralEdemaAbs is not None and edmaCodesExist == 0:
        if brainCompressionAbs is not None: dc.Links.Add(brainCompressionAbs)
        if cerebralEdemaAbs is not None: dc.Links.Add(cerebralEdemaAbs)
        result.Subtitle = "Brain Compression and Cerebral Edema Dx Possibly only present on Radiology Reports."
        AlertPassed = True
    #4
    elif cerebralEdemaAbs is not None and edmaCodesExist == 0:
        dc.Links.Add(cerebralEdemaAbs)
        result.Subtitle = "Cerebral Edema Dx Possibly Only Present On Radiology Reports"
        AlertPassed = True
    #5
    elif brainCompressionAbs is not None and compressionCodesExist == 0:
        dc.Links.Add(brainCompressionAbs)
        result.Subtitle = "Brain Compression Dx Possibly Only Present On Radiology Reports"
        AlertPassed = True
    #6
    elif brainHerniationAbs is not None and compressionCodesExist == 0:
        dc.Links.Add(brainHerniationAbs)
        result.Subtitle = "Brain Compression Dx Possibly only present on Radiology Reports"
        AlertPassed = True
    #7
    elif (
        compressionCodesExist == 0 and
        (massEffectAbs is not None or
        sulcalEffacementAbs is not None or
        cerebralVentriEffacAbs is not None or
        brainPressureAbs is not None or
        intraPressureDV is not None or
        intraPressureAbs is not None or
        burrHolesCodes is not None or
        decomCraniectomyCode is not None or
        hyperVentTherapyAbs is not None or
        subarchoidBoltCode is not None or
        ventriculostomyCodes is not None)
    ):
        result.Subtitle = "Possible Brain Compression Dx"
        AlertPassed = True
    #8
    elif compressionCodesExist == 0 and edmaCodesExist == 0 and (hyperTonicSalMed or (dexamethasoneMedDoc and negationCheck is False) or (mannitolMedDoc and negationCheck is False)):
        if mannitolMedDoc:
            for entry in mannitolMedDoc:
                dc.Links.Add(entry)
        if dexamethasoneMedDoc:
            for entry in dexamethasoneMedDoc:
                dc.Links.Add(entry)
        result.Subtitle = "Possible Cerebral Edema or Brain Compression"
        AlertPassed = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Abs
    r4182Code = codeValue("R41.82", "Altered Level Of Consciousness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    alteredAbs = abstractValue("ALTERED_LEVEL_OF_CONSCIOUSNESS", "Altered Level Of Consciousness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2)
    if r4182Code is not None:
        abs.Links.Add(r4182Code)
        if alteredAbs is not None: alteredAbs.Hidden = True; abs.Links.Add(alteredAbs)
    elif r4182Code is None and alteredAbs is not None:
        abs.Links.Add(alteredAbs)
    if brainCompressionAbs is not None: abs.Links.Add(brainCompressionAbs) #3
    multiCodeValue(["I60.0", "I60.00", "I60.01", "I60.02", "I60.1", "I60.10", "I60.11", "I60.12", "I60.2", "I60.3", "I60.30",
                   "I60.31", "I60.32", "I60.4", "I60.5", "I60.50", "I60.51", "I60.52", "I60.6", "I60.7", "I60.8", "I60.9",
                   "I61.0", "I61.1", "I61.2", "I61.3", "I61.4", "I61.5", "I61.6", "I61.8", "I61.9", "I62", "I62.0", "I62.00",
                   "I62.01", "I62.02", "I62.03", "I62.1", "I62.9"],
                    "Brain Hemorrhage - Ruptured Aneurysm: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, abs, True)
    if brainHerniationAbs is not None: abs.Links.Add(brainHerniationAbs) #5
    if brainPressureAbs is not None: abs.Links.Add(brainPressureAbs) #6
    codeValue("G93.0", "Cerebral Cysts: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, abs, True)
    if cerebralEdemaAbs is not None: abs.Links.Add(cerebralEdemaAbs) #8
    codeValue("I67.82", "Cerebral Ischemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, abs, True)
    if cerebralVentriEffacAbs is not None: abs.Links.Add(cerebralVentriEffacAbs) #10
    codeValue("G31.9", "Cerebral Volume loss: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, abs, True)
    codeValue("Z98.2", "Cerebrospinal Fluid Drainage Device: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, abs, True)
    abstractValue("COMA", "Coma '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13, abs, True)
    codeValue("R41.0", "Disorientation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14, abs, True)
    codeValue("R29.810", "Facial Droop: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
    abstractValue("FACIAL_NUMBNESS", "Facial Numbness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 16, abs, True)
    codeValue("R51.9", "Headache: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17, abs, True)
    multiCodeValue(["G81.00", "G81.01", "G81.02", "G81.03", "G81.04", "G81.1", "G81.10", "G81.11", "G81.12",
        "G81.13", "G81.14", "G81.90", "G81.91", "G81.92", "G81.93", "G81.94"], "Hemiplegia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, abs, True)
    multiCodeValue(["G81.00", "G81.10", "G81.90"], "Hemiplegia/Hemiparesis of Unspecified Site: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19, abs, True)
    multiCodeValue(["G91.1", "G91.3", "G91.9"], "Hydrocephalus: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20, abs, True)
    codeValue("G04.90", "Encephalitis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21, abs, True)
    prefixCodeValue("^S06\.", "Intracranial Injury: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 22, abs, True)
    abstractValue("IRREGULAR_RADIOLOGY_FINDINGS_BRAIN", "Radiology Findings '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 23, abs, True)
    multiCodeValue(["5A1935Z", "5A1945Z", "5A1955Z"], "Intubation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20, abs, True)
    if massEffectAbs is not None: abs.Links.Add(massEffectAbs) #24
    abstractValue("MIDLINE_SHIFT", "Midline Shift '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 25, abs, True)
    abstractValue("MUSCLE_CRAMPS", "Muscle Cramps '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 26, abs, True)
    multiCodeValue(["I63.0", "I63.00", "I63.01", "I63.011", "I63.012", "I63.013", "I63.019", "I63.02", "I63.03", "I63.031",
                   "I63.032", "I63.033", "I63.039", "I63.09", "I63.1", "I63.10", "I63.11", "I63.111", "I63.112", "I63.113",
                   "I63.119", "I63.12", "I63.13", "I63.131", "I63.132", "I63.133", "I63.139", "I63.19", "I63.2", "I63.20",
                   "I63.21", "I63.211", "I63.212", "I63.213", "I63.219", "I63.22", "I63.23", "I63.231", "I63.232", "I63.233",
                   "I63.239", "I63.29", "I63.3", "I63.30", "I63.31", "I63.311", "I63.312", "I63.313", "I63.319", "I63.32",
                   "I63.321", "I63.322", "I63.323", "I63.329", "I63.33", "I63.331", "I63.332", "I63.333", "I63.339", "I63.34",
                   "I63.341", "I63.342", "I63.343", "I63.349", "I63.39", "I63.4", "I63.40", "I63.41", "I63.411", "I63.412",
                   "I63.413", "I63.419", "I63.432", "I63.433", "I63.439", "I63.44", "I63.441", "I63.442", "I63.443", "I63.449",
                   "I63.49", "I63.5", "I63.50", "I63.51", "I63.511", "I63.512", "I63.513", "I63.519", "I63.52", "I63.521",
                   "I63.522", "I63.523", "I63.529", "I63.53", "I63.531", "I63.532", "I63.533", "I63.539", "I63.54", "I63.541",
                   "I63.542", "I63.543", "I63.549", "I63.59", "I63.6", "I63.8", "I63.81", "I63.89", "I63.9"],
                    "Cerebral Infarction: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 27, abs, True)
    abstractValue("OBTUNDED", "Obtunded '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 28, abs, True)
    abstractValue("SEIZURE", "Seizure '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 29, abs, True)
    if sulcalEffacementAbs is not None: abs.Links.Add(sulcalEffacementAbs) #30
    codeValue("S09.8XXA", "Traumatic Brain Injury - Closed Head Injury: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 31, abs, True)
    codeValue("S09.90XA", "Traumatic Brain Injury - Open Head Injury: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 32, abs, True)
    codeValue("R11.10", "Vomiting: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 33, abs, True)
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
    #Treatment
    medValue("Acetazolamide", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1, treatment, True)
    abstractValue("ACETAZOLAMIDE", "Acetazolamide '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2, treatment, True)
    medValue("Anticonvulsant", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 3, treatment, True)
    abstractValue("ANTICONVULSANT", "Anticonvulsant '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4, treatment, True)
    medValue("Benzodiazepine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 5, treatment, True)
    abstractValue("BENZODIAZEPINE", "Benzodiazepine '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6, treatment, True)
    if burrHolesCodes is not None: treatment.Links.Add(burrHolesCodes) #7
    medValue("Beta Blocker", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 8, treatment, True)
    medValue("Bumetanide", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 9, treatment, True)
    medValue("Calcium Channel Blockers", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 10, treatment, True)
    abstractValue("CALCIUM_CHANNEL_BLOCKER", "Calcium Channel Blocker '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11, treatment, True)
    if decomCraniectomyCode is not None: treatment.Links.Add(decomCraniectomyCode) #12
    medValue("Dexamethasone", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 13, treatment, True)
    medValue("Diuretic", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 14, treatment, True)
    abstractValue("DIURETIC", "Diuretic '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 15, treatment, True)
    medValue("Furosemide", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 16, treatment, True)
    medValue("Hydralazine", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 17, treatment, True)
    if hyperTonicSalMed is not None: treatment.Links.Add(hyperTonicSalMed) #18
    abstractValue("HYPERTONIC_SALINE", "Hypertonic Saline '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 19, treatment, True)
    if hyperVentTherapyAbs is not None: treatment.Links.Add(hyperVentTherapyAbs) #20
    medValue("Lithium", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 21, treatment, True)
    medValue("Mannitol", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 22, treatment, True)
    medValue("Methylprednisolone", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 23, treatment, True)
    medValue("Sodium Nitroprusside", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 24, treatment, True)
    medValue("Steroid", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 25, treatment, True)
    abstractValue("STEROIDS", "Steroid '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 26, treatment, True)
    if subarchoidBoltCode is not None: treatment.Links.Add(subarchoidBoltCode) #27
    if ventriculostomyCodes is not None: treatment.Links.Add(ventriculostomyCodes) #28
    #Vitals
    dvValue(dvGlasgowComaScale, "Glasgow Coma Score: [VALUE] (Result Date: [RESULTDATETIME])", calcGlasgowComaScale1, 1, vitals, True)
    dvValue(dvHeartRate, "Heart Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcHeartRate1, 2, vitals, True)
    if intraPressureDV is not None: vitals.Links.Add(intraPressureDV) #3
    if intraPressureAbs is not None: vitals.Links.Add(intraPressureAbs) #4
    dvValue(dvRespiratoryRate, "Respiratory Rate: [VALUE] (Result Date: [RESULTDATETIME])", calcRespiratoryRate1, 5, vitals, True)

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if vitals.Links: result.Links.Add(vitals); vitalsLinks = True
    if ctHeadBrainLinks.Links: result.Links.Add(ctHeadBrainLinks); docLinksLinks = True
    if mriBrainLinks.Links: result.Links.Add(mriBrainLinks); docLinksLinks = True
    result.Links.Add(treatment)
    if treatment.Links: treatmentLinks = True
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: AlertTrigger- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", vitals- " + str(vitalsLinks) + 
        ", docs- " + str(docLinksLinks) + ", treatment- " + str(treatmentLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
