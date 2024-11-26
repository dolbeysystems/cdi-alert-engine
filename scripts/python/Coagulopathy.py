##################################################################################################################
#Evaluation Script - Coagulopathy
#
#This script checks an account to see if it matches criteria to be alerted for Coagulopathy
#Date - 10/31/2024
#Version - V14
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
    "D65": "Disseminated Intravascular Coagulation",
    "D66": "Hereditary Factor VIII Deficiency",
    "D67": "Hereditary Factor IX Deficiency",
    "D68.0": "Von Willebrand Disease",
    "D68.00": "Von Willebrand Disease, Unspecified",
    "D68.01": "Von Willebrand Disease, Type 1",
    "D68.02": "Von Willebrand Disease, Type 2",
    "D68.020": "Von Willebrand Disease, Type 2A",
    "D68.021": "Von Willebrand Disease, Type 2B",
    "D68.022": "Von Willebrand Disease, Type 2M",
    "D68.023": "Von Willebrand Disease, Type 2N",
    "D68.03": "Von Willebrand Disease, Type 3",
    "D68.04": "Acquired Von Willebrand Disease",
    "D68.09": "Other Von Willebrand Disease",
    "D68.1": "Hereditary Factor XI Deficiency",
    "D68.2": "Hereditary Deficiency Of Other Clotting Factors",
    "D68.311": "Acquired Hemophilia",
    "D68.312": "Antiphospholipid Antibody With Hemorrhagic Disorder",
    "D68.318": "Other Hemorrhagic Disorder Due To Intrinsic Circulating Anticoagulant, Antibodies, Or Inhibitors",
    "D68.32": "Hemorrhagic Disorder Due To Extrinsic Circulating Anticoagulant",
    "D68.4": "Acquired Coagulation Factor Deficiency",
    "D68.5": "Primary Thrombophilia",
    "D68.51": "Activated Protein C Resistance",
    "D68.52": "Prothrombin Gene Mutation",
    "D68.59": "Other Primary Thrombophilia",
    "D68.6": "Other Thrombophilia",
    "D68.61": "Antiphospholipid Syndrome",
    "D68.62": "Lupus Anticoagulant Syndrome",
    "D68.69": "Other Thrombophilia",
    "D68.8": "Other Specified Coagulation Defects",
    "D75.821": "Non-Immune Heparin-Induced Thrombocytopenia",
    "D75.822": "Immune-Mediated Heparin-Induced Thrombocytopenia",
    "D75.828": "Other Heparin-Induced Thrombocytopenia Syndrome",
    "D75.829": "Heparin-Induced Thrombocytopenia, Unspecified",
    "D68.9": "Coagulation Defect, Unspecified"
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
dvActivatedClottingTime = [""]
calcActivatedClottingTime1 = lambda x: x > 120
dvCryoprecipitate = [""]
dvDDimer = ["D-DIMER (mg/L FEU)"]
calcDDimer1 = lambda x: x >= 4
calcDDimer2 = lambda x: 0.48 <= x < 4
dvFibrinogen = ["FIBRINOGEN (mg/dL)"]
calcFibrinogen1 = lambda x: x < 200
dvHomocysteineLevels = [""]
calcHomocysteineLevels1 = lambda x: x > 15
dvInr = ["INR"]
calcInr1 = lambda x: x > 1.7
calcInr2 = lambda x: 1.3 <= x < 1.7
calcInr3 = 1.3
dvPlasmaTransfusion = ["Volume (mL)-Transfuse Plasma (mL)"]
dvPartialThromboplastinTime = ["PTT (SEC)"]
calcPartialThromboplastinTime1 = 30.5
dvPlateletCount = ["PLATELET COUNT (10x3/uL)"]
calcPlateletCount1 = 150
calcPlateletCount2 = lambda x: x < 50
calcPlateletCount3 = lambda x: 50 <= x < 100
dvPlateletTransfusion = [""]
dvProteinCResistance = [""]
calcProteinCResistance1 = lambda x: x < 2.3
dvProthrombinTime = ["PROTIME (SEC)"]
calcProthrombinTime1 = 13.0
dvThrombinTime = ["THROMBIN CLOTTING TM"]
calcThrombinTime1 = lambda x: x > 14
calcAny1 = lambda x: x > 0

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
def dvActionCheck(dvDic, discreteValueName, linkText, sequence=0, category=None, abstract=False):
    dateLimit = System.DateTime.Now.AddDays(-1)
    discreteDic = {}
    w = 0
    matchedList = []

    for dv in dvDic or []:
        if (
            dvDic[dv]['Name'] in discreteValueName and
            dvDic[dv]['Result'] is not None and
            re.search(r'\bNew Bag/Injection\b', dvDic[dv]['Result'], re.IGNORECASE) is not None and
            dvDic[dv]['ResultDate'] >= dateLimit
        ):
            w += 1
            discreteDic[w] = dvDic[dv]

    if w > 3:
        x = w - 1
        y = w - 2
        z = w - 3
        if abstract:
            dataConversion(discreteDic[w].ResultDate, linkText, discreteDic[w].Result, discreteDic[w].UniqueId or discreteDic[w]._id, category, sequence)
            dataConversion(discreteDic[x].ResultDate, linkText, discreteDic[x].Result, discreteDic[x].UniqueId or discreteDic[x]._id, category, sequence)
            dataConversion(discreteDic[y].ResultDate, linkText, discreteDic[y].Result, discreteDic[y].UniqueId or discreteDic[y]._id, category, sequence)
            dataConversion(discreteDic[z].ResultDate, linkText, discreteDic[z].Result, discreteDic[z].UniqueId or discreteDic[z]._id, category, sequence)
            return True
        else:
            matchedList.append(dataConversion(discreteDic[w].ResultDate, linkText, discreteDic[w].Result, discreteDic[w].UniqueId or discreteDic[w]._id, category, sequence, abstract))
            matchedList.append(dataConversion(discreteDic[x].ResultDate, linkText, discreteDic[x].Result, discreteDic[x].UniqueId or discreteDic[x]._id, category, sequence, abstract))
            matchedList.append(dataConversion(discreteDic[y].ResultDate, linkText, discreteDic[y].Result, discreteDic[y].UniqueId or discreteDic[y]._id, category, sequence, abstract))
            matchedList.append(dataConversion(discreteDic[z].ResultDate, linkText, discreteDic[z].Result, discreteDic[z].UniqueId or discreteDic[z]._id, category, sequence, abstract))
            return matchedList
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
outcome = None
subtitle = None
DIC = 0
throm = False
dcLinks = False
absLinks = False
labsLinks = False
bloodLinks = False
medsLinks = False
noLabs = []
multiDvValues = 0
medCheck = False

#Initalize categories
dc = MatchedCriteriaLink("Document Code", None, "Document Code", None, True, None, None, 1)
labs = MatchedCriteriaLink("Laboratory Studies", None, "Laboratory Studies", None, True, None, None, 2)
abs = MatchedCriteriaLink("Clinical Evidence", None, "Clinical Evidence", None, True, None, None, 3)
blood = MatchedCriteriaLink("Blood Product Transfusion", None, "Blood Product Transfusion", None, True, None, None, 4)
meds = MatchedCriteriaLink("Medication(s)", None, "Medication(s)", None, True, None, None, 5)
treatment = MatchedCriteriaLink("Treatment and Monitoring", None, "Treatment and Monitoring", None, True, None, None, 6)
other = MatchedCriteriaLink("Other", None, "Other", None, True, None, None, 7)
pt = MatchedCriteriaLink("PT", None, "PT", None, True, None, None, 89)
ptt = MatchedCriteriaLink("PTT", None, "PTT", None, True, None, None, 90)
inr = MatchedCriteriaLink("INR", None, "INR", None, True, None, None, 91)
platelet = MatchedCriteriaLink("Platelets", None, "Platelets", None, True, None, None, 92)

#Determine if alert was triggered before and if lacking had been triggered
for alert in account.MatchedCriteriaGroups or []:
    if alert.CriteriaGroup == 'Coagulopathy':
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
    discreteSearchList = [i for j in [dvInr, dvPartialThromboplastinTime, dvPlateletCount, dvProthrombinTime] for i in j]
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
    
    #Negation
    anticoagulantAbs = abstractValue("ANTICOAGULANT", "Anticoagulant '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0)
#    disseminatedIntravascularCoagulationCode = codeValue("D65", "Disseminated Intravascular Coagulation not documented: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 0)
#    pancytopeniaNegation = multiCodeValue(["D61.810", "D61.811", "D61.818"], "Pancytopenia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 0)
#    d694Codes = prefixCodeValue("^D69\.4", "Primary Thrombocytopenia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11)
#    d695Codes = prefixCodeValue("^D69\.5", "Secondary Thrombocytopenia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11)
#    d696Code = codeValue("D69.6", "Thrombocytopenia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 0)
    #AlertTrigger
#    massiveTransfuionAbs = abstractValue("MASSIVE_TRANSFUSION_PROTOCOL", "Massive Transfusion Protocol '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 0)
    #Abs
    giBleedCodes = multiCodeValue(["K25.0", "K25.2", "K25.4", "K25.6", "K26.0","K26.2", "K26.4. K26.6", "K27.0", "K27.2", "K27.4", "K27.6", "K28.0", "K28.2", "K28.4", "K28.6",
        "K29.01", "K29.21", "K29.31", "K29.41", "K29.51", "K29.61", "K29.71", "K29.81", "K29.91", "K31.811", "K31.82", "K55.21", "K57.01", "K57.11",
        "K57.13", "K57.21", "K57.31", "K57.33", "K57.41", "K57.51", "K57.53", "K57.81", "K57.91", "K57.93", "K62.5", "K92.0", "K92.1", "K92.2"],
        "GI Bleed: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14)
    hemorrhageAbs = abstractValue("HEMORRHAGE","Hemorrhage: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 17)
    #Labs
    ddimer4DV = dvValue(dvDDimer, "D Dimer: [VALUE] (Result Date: [RESULTDATETIME])", calcDDimer1, 2)
    ddimer0484DV = dvValue(dvDDimer, "D Dimer: [VALUE] (Result Date: [RESULTDATETIME])", calcDDimer2, 3)
    fibrinogenDV = dvValue(dvFibrinogen, "Fibrinogen: [VALUE] (Result Date: [RESULTDATETIME])", calcFibrinogen1, 4)
    #Labs Subheadings
    inr13DV = dvValueMulti(dict(maindiscreteDic), dvInr, "INR: [VALUE] (Result Date: [RESULTDATETIME])", calcInr3, gt, 0, inr, False, 10)
    pttDV = dvValueMulti(dict(maindiscreteDic), dvPartialThromboplastinTime, "Partial Thromboplastin Time: [VALUE] (Result Date: [RESULTDATETIME])", calcPartialThromboplastinTime1, gt, 0, ptt, False, 10)
    plateletCount150DV = dvValueMulti(dict(maindiscreteDic), dvPlateletCount, "Platelet Count: [VALUE] (Result Date: [RESULTDATETIME])", calcPlateletCount1, lt, 0, platelet, False, 10)
    ptDV = dvValueMulti(dict(maindiscreteDic), dvProthrombinTime, "Prothrombin Time: [VALUE] (Result Date: [RESULTDATETIME])", calcProthrombinTime1, gt, 0, pt, False, 10)
    #Meds
    anticoagulantDV = medValue("Anticoagulant", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 1)
    anticoagulantAbs = abstractValue("ANTICOAGULANT", "Anticoagulant '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 2)
    antiplateletDV = medValue("Antiplatelet", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 3)
    antiplateletAbs = abstractValue("ANTIPLATELET", "Antiplatelet '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 4)
    aspirinDV = medValue("Aspirin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 6)
    aspirinAbs = abstractValue("ASPIRIN", "Aspirin '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 7)
    heparinDV = medValue("Heparin", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 10)
    heparinAbs = abstractValue("HEPARIN", "Heparin '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 11)
    z7901Code = codeValue("Z79.01", "Long Term Anticoagulants: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12)
    z7902Code = codeValue("Z79.02", "Long Term use of Antithrombotics/Antiplatelets: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13)
    z7982Code = codeValue("Z79.82", "Long Term Aspirin: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 14)
    #DIC Score Only Items
#    inr17DV = dvValue(dvInr, "INR: [VALUE] (Result Date: [RESULTDATETIME])", calcInr1, 0)
#    inr1317DV = dvValue(dvInr, "INR: [VALUE] (Result Date: [RESULTDATETIME])", calcInr2, 0)
#    plateletCount50DV = dvValue(dvPlateletCount, "Platelet Count: [VALUE] (Result Date: [RESULTDATETIME])", calcPlateletCount2, 13)
#    plateletCount50100DV = dvValue(dvPlateletCount, "Platelet Count: [VALUE] (Result Date: [RESULTDATETIME])", calcPlateletCount3, 13)

    #Evaluating DIC Score
#    if anticoagulantAbs is None:
#        if inr17DV is not None: DIC += 2
#        elif inr1317DV is not None: DIC += 1
#    if fibrinogenDV is not None: DIC += 1
#    if ddimer4DV is not None: DIC += 3
#    elif ddimer0484DV is not None: DIC += 2
#    if plateletCount50DV is not None: DIC += 2
#    elif plateletCount50100DV is not None: DIC += 1
    
    #Check for multiple dv values
    if len(inr13DV or noLabs) > 1:
        multiDvValues += 1
    elif inr13DV is not None:
        multiDvValues += 1
    if len(ptDV or noLabs) > 1:
        multiDvValues += 1
    elif ptDV is not None:
        multiDvValues += 1
    if len(pttDV or noLabs) > 1:
        multiDvValues += 1
    elif pttDV is not None:
        multiDvValues += 1
        
    #Med not taken Check
    if (
        z7901Code is None and 
        z7902Code is None and
        z7982Code is None and
        anticoagulantAbs is None and
        antiplateletAbs is None and 
        anticoagulantDV is None and
        antiplateletDV is None and  
        aspirinDV is None and
        aspirinAbs is None and
        heparinDV is None and
        heparinAbs is None  
    ):
        medCheck = True

    #Main Algorithm Starting
#    if (
#        disseminatedIntravascularCoagulationCode is None and
#        (DIC >= 5 or
#        massiveTransfuionAbs is not None)
#    ):
#        if massiveTransfuionAbs is not None: dc.Links.Add(massiveTransfuionAbs)
#        result.Subtitle = "Possible Disseminated Intravascular Coagulation"
#        AlertPassed = True
#
#    elif (pancytopeniaNegation is not None or d694Codes is not None or d695Codes is not None or d696Code is not None) and subtitle == "Possible Thrombocytopenia":
#        if pancytopeniaNegation is not None: updateLinkText(pancytopeniaNegation, autoCodeText); dc.Links.Add(pancytopeniaNegation)
#        if d694Codes is not None: updateLinkText(d694Codes, autoCodeText); dc.Links.Add(d694Codes)
#        if d695Codes is not None: updateLinkText(d695Codes, autoCodeText); dc.Links.Add(d695Codes)
#        if d696Code is not None: updateLinkText(d696Code, autoCodeText); dc.Links.Add(d696Code)
#        result.Outcome = "AUTORESOLVED"
#        result.Reason = "Autoresolved due to one Specified Code on the Account"
#        result.Validated = True
#        AlertConditions = True
#
#    elif len(plateletCount150DV or noLabs) > 1 and pancytopeniaNegation is None and d694Codes is None and d695Codes is None and d696Code is None:
#        throm = True
#        result.Subtitle = "Possible Thrombocytopenia"
#        AlertPassed = True

    if codesExist >= 1 or medCheck is False:
        db.LogEvaluationScriptMessage("One specific code was on the chart, alert failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        if alertTriggered:
            for code in codeList:
                desc = codeDic[code]
                tempCode = accountContainer.GetFirstCodeLink(code, "Autoresolved Specified Code  - " + desc + ": [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])")
                if tempCode is not None:
                    dc.Links.Add(tempCode)
                    break
            result.Outcome = "AUTORESOLVED"
            result.Reason = "Autoresolved due to one Specified Code on the Account"
            result.Validated = True
            AlertPassed = True
        else: result.Passed = False

    elif hemorrhageAbs is None and giBleedCodes is None and medCheck and multiDvValues > 1:
        result.Subtitle = "Possible Coagulopathy Dx"
        AlertPassed = True

    elif (hemorrhageAbs is not None or giBleedCodes is not None) and medCheck and multiDvValues > 1:
        result.Subtitle = "Possible Coagulopathy Dx"
        AlertPassed = True

    else:
        db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
        result.Passed = False

else:
    db.LogEvaluationScriptMessage("Alert Closed; Exiting script run. Outcome: " + str(outcome) + " " + str(account._id), scriptName, scriptInstance, "Debug")

#If an alert triggered abstract the following
if AlertPassed:
    #Abstractions
    if throm: codeValue("F10.20", "Alcohol Abuse: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 1, abs, True)
    if not throm: codeValue("K70.30", "Alcoholic Cirrhosis of Liver without Acites: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, abs, True)
    if not throm: codeValue("K70.31", "Alcoholic Cirrhosis of Liver with Acites: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, abs, True)
    if not throm: codeValue("K70.41", "Alcoholic Hepatic Failure with Coma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, abs, True)
    if not throm: codeValue("K70.40", "Alcoholic Hepatic Failure without Coma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 5, abs, True)
    abstractValue("CAUSE_OF_COAGULOPATHY", "Causes of Coagulopathy: [ABSTRACTVALUE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 6, labs, True)
    if throm: codeValue("Z51.11", "Chemotherapy: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, abs, True)
    if not throm: codeValue("K72.10", "Chronic Hepatic Failure witout Coma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 8, abs, True)
    if not throm: codeValue("K72.11", "Chronic Hepatic Failure with Coma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 9, abs, True)
    if not throm: codeValue("K72.90", "Hepatic Failure Unspecified without Coma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 10, abs, True)
    if not throm: codeValue("K72.91", "Hepatic Failure Unspecified with Coma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 11, abs, True)
    if throm: prefixCodeValue("^C82\.", "Follicular Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 12, abs, True)
    if throm: codeValue("E75.22", "Gauchers Disease: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 13, abs, True)
    if giBleedCodes is not None: abs.Links.Add(giBleedCodes) #14
    if throm: codeValue("D76.1", "Hemophagocytic Lymphohistiocytosis: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 15, abs, True)
    if throm: codeValue("D76.2", "Hemophagocytic Syndrome: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 16, abs, True)
    if hemorrhageAbs is not None: abs.Links.Add(hemorrhageAbs) #17
    if throm: prefixCodeValue("^C81\.", "Hodgkin Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 18, abs, True)
    if throm: prefixCodeValue("^C95\.", "Leukemia of Unspecified Cell Type: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 19, abs, True)
    if throm: prefixCodeValue("^C91\.", "Lymphoid Leukemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 20, abs, True)
    if throm: prefixCodeValue("^C84\.", "Mature T/NK-Cell Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 21, abs, True)
    if throm: prefixCodeValue("^C93\.", "Monocytic Leukemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 22, abs, True)
    if throm: prefixCodeValue("^C90\.", "Multiple Myeloma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 23, abs, True)
    if throm: prefixCodeValue("^C92\.", "Myeloid Leukemia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 24, abs, True)
    if throm: prefixCodeValue("^C83\.", "Non-Follicular Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 25, abs, True)
    if throm: prefixCodeValue("^C94\.", "Other Leukemias: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 26, abs, True)
    if throm: prefixCodeValue("^C86\.", "Other Types of T/NK-Cell Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 27, abs, True)
    if not throm: codeValue("D61.818", "Pancytopenia: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 28, abs, True)
    if throm: codeValue("R23.3", "Petechiae: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 29, abs, True)
    if throm: codeValue("R16.1", "Splenomegaly: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 30, abs, True)
    if not throm: codeValue("M32.9", "Systemic Lupus Erythematous: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 31, abs, True)
    if throm: codeValue("M31.19", "Thrombotic Thrombocytopenic Purpura: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 32, abs, True)
    if throm: prefixCodeValue("^C85\.", "Unspecified Non-Hodgkin Lymphoma: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 33, abs, True)
    codeValue("E56.1", "Vitamin K Deficiency: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 34, abs, True)
    #Blood
    dvValue(dvCryoprecipitate, "Cryoprecipitate: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, 1, blood, True)
    if not throm: codeValue("30233M1", "Cryoprecipitate Transfusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 2, blood, True)
    if not throm: codeValue("30233T1", "Fibrinogen Transfusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 3, blood, True)
    if not throm: multiCodeValue(["30233L1", "30243L1"], "Fresh Plasma Transfusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 4, blood, True)
    dvValue(dvPlasmaTransfusion, "Plasma Transfusion: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, 5, blood, True)
    dvValue(dvPlateletTransfusion, "Platelet Transfusion: [VALUE] (Result Date: [RESULTDATETIME])", calcAny1, 6, blood, True)
    if throm: multiCodeValue(["30233R1", "30243R1"], "Platelet Transfusion: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", 7, blood, True)
    #Labs
    if not throm: dvValue(dvActivatedClottingTime, "Activated Clotting Time: [VALUE] (Result Date: [RESULTDATETIME])", calcActivatedClottingTime1, 1, labs, True)
    if not throm and ddimer4DV is not None: labs.Links.Add(ddimer4DV) #2
    if not throm and ddimer0484DV is not None and ddimer4DV is None: labs.Links.Add(ddimer0484DV) #3
    if fibrinogenDV is not None: labs.Links.Add(fibrinogenDV) #4
    if not throm: dvValue(dvHomocysteineLevels, "Homocysteine Levels: [VALUE] (Result Date: [RESULTDATETIME])", calcHomocysteineLevels1, 5, labs, True)
    if not throm: dvValue(dvProteinCResistance, "Protein C Resistance: [VALUE] (Result Date: [RESULTDATETIME])", calcProteinCResistance1, 6, labs, True)
    if not throm: dvValue(dvThrombinTime, "Thrombin Time: [VALUE] (Result Date: [RESULTDATETIME])", calcThrombinTime1, 7, labs, True)
    #Lab SubHeadings
    if inr13DV is not None:
        for entry in inr13DV:
            inr.Links.Add(entry)
    if anticoagulantAbs is None:
        if throm is False and pttDV is not None:
            for entry in pttDV:
                ptt.Links.Add(entry)
    if plateletCount150DV is not None:
        for entry in plateletCount150DV:
            platelet.Links.Add(entry)
    if throm is False and ptDV is not None:
        for entry in ptDV:
            pt.Links.Add(entry)
    #Meds
    if anticoagulantDV is not None: meds.Links.Add(anticoagulantDV) #1
    if anticoagulantAbs is not None: meds.Links.Add(anticoagulantAbs) #2
    if antiplateletDV is not None: meds.Links.Add(antiplateletDV) #3
    if antiplateletAbs is not None: meds.Links.Add(antiplateletAbs) #4
    medValue("Antiplatelet2", "[MEDICATION], Dosage [DOSAGE], Route [ROUTE] ([STARTDATE])", 5, meds, True)
    if aspirinDV is not None: meds.Links.Add(aspirinDV) #6
    if aspirinAbs is not None: meds.Links.Add(aspirinAbs) #7
    if not throm: abstractValue("ANTIFIBRINOLYTIC_MEDICATION", "Antifibrinolytic Medication '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 8, meds, True)
    if not throm: abstractValue("DESMOPRESSIN_ACETATE", "Desmopressin Acetate '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 9, meds, True)
    if heparinDV is not None: meds.Links.Add(heparinDV) #10
    if heparinAbs is not None: meds.Links.Add(heparinAbs) #11
    if z7901Code is not None: meds.Links.Add(z7901Code) #12
    if z7902Code is not None: meds.Links.Add(z7902Code) #13
    if z7982Code is not None: meds.Links.Add(z7982Code) #14
    if not throm: abstractValue("PLASMA_DERIVED_FACTOR_CONCENTRATE", "Plasma Derived Factor Concentrate '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 15, meds, True)
    if not throm: abstractValue("RECOMBINANT_FACTOR_CONCENTRATE", "Recombinant Factor Concentrate '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", True, 16, meds, True)
    
#If alert passed or alert conditions was triggered add categories to result if they have links
if AlertPassed or AlertConditions:
    if pt.Links: labs.Links.Add(pt); labsLinks = True
    if ptt.Links: labs.Links.Add(ptt); labsLinks = True
    if inr.Links: labs.Links.Add(inr); labsLinks = True
    if platelet.Links: labs.Links.Add(platelet); labsLinks = True
    if dc.Links: result.Links.Add(dc); dcLinks = True
    if abs.Links: result.Links.Add(abs); absLinks = True
    if labs.Links: result.Links.Add(labs); labsLinks = True
    if blood.Links: result.Links.Add(blood); bloodLinks = True
    result.Links.Add(meds)
    if meds.Links: medsLinks = True
    result.Links.Add(treatment)
    result.Links.Add(other)
    db.LogEvaluationScriptMessage("Alert Passed Adding Links. Alert Triggered: " + str(result.Subtitle) + " Autoresolved: " + str(result.Outcome) + "; " +
        str(result.Validated) + "; Links: Document Code- " + str(dcLinks) + ", Abs- " + str(absLinks) + ", labs- " + str(labsLinks)
        + ", meds- " + str(medsLinks) + "; Acct: " + str(account._id), scriptName, scriptInstance, "Debug")
    result.Passed = True
