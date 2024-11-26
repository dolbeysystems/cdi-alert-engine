##################################################################################################################
#Evaluation Script - Functional Quadriplegia
#
#This script checks an account to see if it matches criteria to be alerted for Functional Quadriplegia
#Date - 11/25/2024
#Version - V15
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
dvBradenRiskAssessmentScore = ["3.5 Activity (Braden Scale)"]
calcBradenRiskAssessmentScore1 = lambda x: x < 2
dvBradenMobilityScore = ["3.5 Mobility"]
calcBradenMobilityScore1 = lambda x: x < 2

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
CI = 0
codePresent = 0
dcLinks = False
absLinks = False
illnessLinks = False

#Initalize categories
dc = MatchedCriteriaLink("Documented Dx", None, "Documented Dx", None, True, None, None, 1)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 2)
illness = MatchedCriteriaLink("Supporting Illness Dx", None, "Supporting Illness Dx", None, True, None, None, 3)
treatment = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 4)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 5)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Functional Quadriplegia':
        alertTriggered = True
        validated = alert.IsValidated
        outcome = alert.Outcome
        subtitle = alert.Subtitle
        break

#Check if alert was autoresolved or completed.
if validated is False:
    #Alert Trigger
    r532Code = codeValue("R53.2", "Functional Quadriplegia Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
    spinalCodes = multiCodeValue(["G82.20", "G82.21", "G82.22", "G82.50", "G82.51", "G82.52", "G82.53", "G82.54"], "Spinal Cord Injury Dx: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19)
    #Abs
    assistanceADLSAbs = abstractValue("ASSISTANCE_WITH_ADLS", "Assistance with ADLS '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 1)
    z741Code = codeValue("Z74.1", "Assistance with Personal Care: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    z7401Code = codeValue("Z74.01", "Bed Bound: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3)
    bradenRiskAssessmentScoreAbs = abstractValue("BRADEN_RISK_ASSESSMENT_SCORE_FUNCTIONAL_QUADRIPLEGIA", "Braden Risk Assessment Score: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4)
    bradenRiskAssessmentScoreDV = dvValue(dvBradenRiskAssessmentScore, "Braden Scale Activity Score: [VALUE] (Result Date: [RESULTDATETIME])", calcBradenRiskAssessmentScore1, 5)
    bradenRiskMobilityDV = dvValue(dvBradenMobilityScore, "Braden Scale Mobility Score: [VALUE] (Result Date: [RESULTDATETIME])", calcBradenMobilityScore1, 6)
    completeAssistanceADLsAbs = abstractValue("COMPLETE_ASSISTANCE_WITH_ADLS", "Complete Assistance with ADLs '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8)
    debilitatedAbs = abstractValue("DEBILITATED", "Debilitated '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9)
    extremitiesAbs = abstractValue("MOVES_ALL_EXTREMITIES", "Extremities '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11)
    flaccidLimbsAbs = abstractValue("FLACCID_LIMBS", "Flaccid Limbs '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 13)
    footDropCodes = multiCodeValue(["M21.371", "M21.372", "M21.379"], "Foot Drop: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14)
    muscleContractureAbs = abstractValue("MUSCLE_CONTRACTURE", "Muscle Contracture '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 17)
    sacralDecubitusCodes = multiCodeValue(["L89.153", "L89.154"], "Sacral Decubitus Ulcer: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20)
    severeWeaknessAbs = abstractValue("SEVERE_WEAKNESS", "Severe Weakness '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 21)
    spasticHemiplegia = multiCodeValue(["G81.10", "G81.11", "G81.12", "G81.13", "G81.14"], "Spastic Hemiplegia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 22)
    z930Code = codeValue("Z93.0", "Trach Dependent: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23)
    transferWithALiftAbs = abstractValue("TRANSFER_WITH_A_LIFT", "Transfer With A Lift '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 24)
    z9911Code = codeValue("Z99.11", "Ventilator Dependent: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 25)
    wristDropCodes = multiCodeValue(["M21.331", "M21.332", "M21.339"], "Wrist Drop: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 27)
    #Illness
    g301Code = codeValue("G30.1", "Alzheimers Disease with Late Onset: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1)
    g1221Code = codeValue("G12.21", "Amyotrophic Latertal Sclerosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2)
    g804Code = codeValue("G80.4", "Ataxic Cerebral Palsy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3)
    g803Code = codeValue("G80.3", "Athetoid Cerebral Palsy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4)
    g71031Code = codeValue("G71.031", "Autosomal Dominant Limb Girdle Muscular: Dystrophy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5)
    g71032Code = codeValue("G71.032", "Autosomal recessive limb girdle muscular dystrophy due to calpain-3 dysfunction: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 6)
    g809Code = codeValue("G80.9", "Cerebral Palsy, Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7)
    g7101Code = codeValue("G71.01", "Duchenne or Becker Muscular Dystrophy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8)
    g7102Code = codeValue("G71.02", "Facioscapulohumeral Muscular Dystrophy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9)
    guillainBarreSyndromeAbs = abstractValue("GUILLAIN_BARRE_SYNDROME", "Guillain-Barre Syndrome '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 10)
    g10Code = codeValue("G10", "Huntingtons Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12)
    g71035Code = codeValue("G71.035", "Limb Girdle Muscular Dystrophy due to Anoctamin-5 Dysfunction Muscular Dystrophy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13)
    g71033Code = codeValue("G71.033", "Limb Girdle Muscular Dystrophy due to Dysferlin Dysfunction: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14)
    g71034Code = codeValue("G71.034", "Limb Girdle Muscular Dystrophy due to Sarcoglycan Dysfunction: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15)
    g71039Code = codeValue("G71.039", "Limb Girdle Muscular Dystrophy, Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16)
    g35Code = codeValue("G35", "Multiple Sclerosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 17)
    g7100Code = codeValue("G71.00", "Muscular Dystrophy Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18)
    myastheniaGravisCodes = multiCodeValue(["G70.00", "G70.01"], "Myasthenia Gravis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19)
    g808Code = codeValue("G80.8", "Other Cerebral Palsy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20)
    g20Code = codeValue("G20", "Parkinson's: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21)
    g20A1Code = codeValue("G20.A1", "Parkinson's Disease without Dyskinesia, without Mention of Fluctuations: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 22)
    g20A2Code = codeValue("G20.A2", "Parkinson's Disease without Dyskinesia, with Fluctuations: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23)
    g20B1Code = codeValue("G20.B1", "Parkinson's Disease with Dyskinesia, without Mention of Fluctuations: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 24)
    g20B2Code = codeValue("G20.B2", "Parkinson's Disease with Dyskinesia, with Fluctuations: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 25)
    g20CCode = codeValue("G20.C", "Parkinsonism, Unspecified: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 26)
    g801Code = codeValue("G80.1", "Spastic Diplegic Cerebral Palsy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 27)
    g802Code = codeValue("G80.2", "Spastic Hemiplegic Cerebral Palsy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 28)
    g800Code = codeValue("G80.0", "Spastic Quadriplegic Cerebral Palsy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 29)
    z8673Code = codeValue("Z86.73", "Stroke: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 30)
    f03C11Code = codeValue("F03.C11", "Unspecified Dementia, Severe, with Agitation: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 31)
    f03C4Code = codeValue("F03.C4", "Unspecified Dementia, Severe, with Anxiety: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 32)
    f03C1Code = codeValue("F03.C1", "Unspecified Dementia, Severe, with Behavioral Disturbance: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 33)
    f03C0Code = codeValue("F03.C0", "Unspecified Dementia, Severe, without Behavioral Disturbance, Psychotic Disturbance, Mood Disturbance, and Anxiety: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 34)
    f03C3Code = codeValue("F03.C3", "Unspecified Dementia, Severe, with Mood Disturbance: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 35)
    f03C18Code = codeValue("F03.C18", "Unspecified Dementia, Severe, with Other Behavioral Disturbance: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 36)
    f03C2Code = codeValue("F03.C2", "Unspecified Dementia, Severe, with Psychotic Disturbance: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 37)

    #Abstracting Clincial Indicators
    if assistanceADLSAbs is not None: abs.Links.Add(assistanceADLSAbs); CI += 1
    if z741Code is not None: abs.Links.Add(z741Code); CI += 1
    if muscleContractureAbs is not None: abs.Links.Add(muscleContractureAbs); CI += 1
    if spasticHemiplegia is not None: abs.Links.Add(spasticHemiplegia); CI += 1
    if transferWithALiftAbs is not None: abs.Links.Add(transferWithALiftAbs); CI += 1
    if flaccidLimbsAbs is not None: abs.Links.Add(flaccidLimbsAbs); CI += 1
    if debilitatedAbs is not None: abs.Links.Add(debilitatedAbs); CI += 1
    if bradenRiskAssessmentScoreDV is not None or bradenRiskAssessmentScoreAbs is not None:
        if bradenRiskAssessmentScoreDV is not None: abs.Links.Add(bradenRiskAssessmentScoreDV)
        if bradenRiskAssessmentScoreAbs is not None: abs.Links.Add(bradenRiskAssessmentScoreAbs)
        CI += 1
    if bradenRiskMobilityDV is not None: abs.Links.Add(bradenRiskMobilityDV); CI += 1
    if completeAssistanceADLsAbs is not None: abs.Links.Add(completeAssistanceADLsAbs); CI += 1
    if severeWeaknessAbs is not None: abs.Links.Add(severeWeaknessAbs); CI += 1
    if footDropCodes is not None: abs.Links.Add(footDropCodes); CI += 1
    if sacralDecubitusCodes is not None: abs.Links.Add(sacralDecubitusCodes); CI += 1
    if z930Code is not None: abs.Links.Add(z930Code); CI += 1
    if z9911Code is not None: abs.Links.Add(z9911Code); CI += 1
    if wristDropCodes is not None: abs.Links.Add(wristDropCodes); CI += 1

    #Abstracting Disease Codes
    if g800Code is not None: illness.Links.Add(g800Code); codePresent += 1
    if g801Code is not None: illness.Links.Add(g801Code); codePresent += 1
    if g802Code is not None: illness.Links.Add(g802Code); codePresent += 1
    if g803Code is not None: illness.Links.Add(g803Code); codePresent += 1
    if g804Code is not None: illness.Links.Add(g804Code); codePresent += 1
    if g808Code is not None: illness.Links.Add(g808Code); codePresent += 1
    if g809Code is not None: illness.Links.Add(g809Code); codePresent += 1
    if g35Code is not None: illness.Links.Add(g35Code); codePresent += 1
    if g20Code is not None: illness.Links.Add(g20Code); codePresent += 1
    if g20A1Code is not None: illness.Links.Add(g20A1Code); codePresent += 1
    if g20A2Code is not None: illness.Links.Add(g20A2Code); codePresent += 1
    if g20B1Code is not None: illness.Links.Add(g20B1Code); codePresent += 1
    if g20B2Code is not None: illness.Links.Add(g20B2Code); codePresent += 1
    if g20CCode is not None: illness.Links.Add(g20CCode); codePresent += 1
    if g1221Code is not None: illness.Links.Add(g1221Code); codePresent += 1
    if g7100Code is not None: illness.Links.Add(g7100Code); codePresent += 1
    if g7101Code is not None: illness.Links.Add(g7101Code); codePresent += 1
    if g7102Code is not None: illness.Links.Add(g7102Code); codePresent += 1
    if g71031Code is not None: illness.Links.Add(g71031Code); codePresent += 1
    if g71032Code is not None: illness.Links.Add(g71032Code); codePresent += 1
    if g71033Code is not None: illness.Links.Add(g71033Code); codePresent += 1
    if g71034Code is not None: illness.Links.Add(g71034Code); codePresent += 1
    if g71035Code is not None: illness.Links.Add(g71035Code); codePresent += 1
    if g71039Code is not None: illness.Links.Add(g71039Code); codePresent += 1
    if f03C0Code is not None: illness.Links.Add(f03C0Code); codePresent += 1
    if f03C1Code is not None: illness.Links.Add(f03C1Code); codePresent += 1
    if f03C11Code is not None: illness.Links.Add(f03C11Code); codePresent += 1
    if f03C18Code is not None: illness.Links.Add(f03C18Code); codePresent += 1
    if f03C2Code is not None: illness.Links.Add(f03C2Code); codePresent += 1
    if f03C3Code is not None: illness.Links.Add(f03C3Code); codePresent += 1
    if f03C4Code is not None: illness.Links.Add(f03C4Code); codePresent += 1
    if g301Code is not None: illness.Links.Add(g301Code); codePresent += 1
    if g10Code is not None: illness.Links.Add(g10Code); codePresent += 1
    if z8673Code is not None: illness.Links.Add(z8673Code); codePresent += 1
    if guillainBarreSyndromeAbs is not None: illness.Links.Add(guillainBarreSyndromeAbs); codePresent += 1
    if myastheniaGravisCodes is not None: illness.Links.Add(myastheniaGravisCodes); codePresent += 1

    #Main Algorithm
    if spinalCodes is not None and extremitiesAbs is not None or r532Code is not None and subtitle == "Possible Functional Quadriplegia Dx":
        if spinalCodes is not None: updateLinkText(spinalCodes, autoCodeText); dc.Links.Add(spinalCodes)
        if extremitiesAbs is not None: updateLinkText(extremitiesAbs, autoCodeText); abs.Links.Add(extremitiesAbs)
        if r532Code is not None: updateLinkText(r532Code, autoCodeText); dc.Links.Add(r532Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code/Abstraction on the Account"
        result.Validated = True
        AlertPassed = True
    
    elif spinalCodes is None and r532Code is None and extremitiesAbs is None and (z7401Code is not None or (CI >= 2 and codePresent >= 1)):
        result.Subtitle = "Possible Functional Quadriplegia Dx"
        AlertPassed = True
    
    elif r532Code is not None and spinalCodes is not None:
        dc.Links.Add(r532Code)
        dc.Links.Add(spinalCodes)
        result.Subtitle = "Possible Conflicting Functional Quadriplegia Dx with Spinal Cord Injury Dx, Seek Clarification"
        AlertPassed = True
        
    elif subtitle == "Functional Quadriplegia Dx Possibly Lacking Supporting Evidence" and (z7401Code is not None or (CI > 0 and codePresent > 0)):
        if z7401Code is not None: updateLinkText(z7401Code, autoEvidenceText); abs.Links.Add(z7401Code)
        result.Outcome = "AUTORESOLVED"
        result.Reason = "Autoresolved due to one Specified Code/Abstraction on the Account"
        result.Validated = True
        AlertPassed = True
        
    elif spinalCodes is None and r532Code is not None and z7401Code is None and CI == 0 and codePresent == 0:
        if extremitiesAbs is not None: abs.Links.Add(extremitiesAbs)
        result.Subtitle = "Functional Quadriplegia Dx Possibly Lacking Supporting Evidence"
        AlertPassed = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#Alert Passed Abstractions
if AlertPassed:
    #Abstractions
    if assistanceADLSAbs is not None: abs.Links.Add(assistanceADLSAbs) #1
    #2 
    if z7401Code is not None: abs.Links.Add(z7401Code) #3
    #4-6
    abstractValue("CHAIRFAST", "Chairfast '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7)
    #8-9
    codeValue("3E0G76Z", "Enteral Nutrition: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, abs, True)
    #11
    codeValue("R15.9", "Fecal Incontinence: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, abs, True)
    #13-14
    codeValue("R39.81", "Functional Urinary Incontinence: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
    codeValue("3E0H76Z", "J Tube Nutrition: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, abs, True)
    #17
    codeValue("N31.9", "Neurogenic Bladder: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, abs, True)
    codeValue("R29.6", "Recurrent Falls: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19, abs, True)
    #20-25
    codeValue("R53.1", "Weakness: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 26, abs, True)
    #27

#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if illness.Links: result.Links.Add(illness); illnessLinks = True
    result.Links.Add(treatment)
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: AlertTrigger- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", illness- " + str(illnessLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
