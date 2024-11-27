---------------------------------------------------------------------------------------------------------------------
--- CDI Alert Script - Urinary Tract Infection
---
--- This script checks an account to see if it matches the criteria for a Urinary Tract Infection alert.
---
--- Date: 11/22/2024
--- Version: 1.0
--- Site: Sarasota County Health District
---------------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--- Requires
--------------------------------------------------------------------------------
require("libs.common")



--------------------------------------------------------------------------------
--- Setup
--------------------------------------------------------------------------------
local alertSubtitle = "Urinary Tract Infection"

local existingAlert = GetExistingCdiAlert { scriptName = ScriptName }
local subtitle = existingAlert and existingAlert.subtitle or nil

if not existingAlert or not existingAlert.validated then
    local resultLinks = {}
    local documentedDxHeader = MakeHeaderLink("Documented Dx")
    local documentedDxLinks = {}
    local clinicalEvidenceHeader = MakeHeaderLink("Clinical Evidence")
    local clinicalEvidenceLinks = {}
    local treatmentAndMonitoringHeader = MakeHeaderLink("Treatment and Monitoring")
    local treatmentAndMonitoringLinks = {}
    local urinaryDevicesHeader = MakeHeaderLink("Treatment and Monitoring")
    local urinaryDevicesLinks = {}
    local laboratoryStudiesHeader = MakeHeaderLink("Treatment and Monitoring")
    local laboratoryStudiesLinks = {}
    local vitalSignsHeader = MakeHeaderLink("Treatment and Monitoring")
    local vitalSignsLinks = {}
    local otherHeader = MakeHeaderLink("Treatment and Monitoring")
    local otherLinks = {}
    local urineAnalysisHeader = MakeHeaderLink("Treatment and Monitoring")
    local urineAnalysisLinks = {}

    --------------------------------------------------------------------------------
    --- Alert Variables
    --------------------------------------------------------------------------------
    local alertCodeDictionary = {
        ["T83.510A"] = "Infection And Inflammatory Reaction Due To Cystostomy Catheter",
        ["T83.510D"] = "Infection And Inflammatory Reaction Due To Cystostomy Catheter",
        ["T83.510S"] = "Infection And Inflammatory Reaction Due To Cystostomy Catheter",
        ["T83.511A"] = "Infection And Inflammatory Reaction Due To Indwelling Urethral Catheter",
        ["T83.511D"] = "Infection And Inflammatory Reaction Due To Indwelling Urethral Catheter",
        ["T83.511S"] = "Infection And Inflammatory Reaction Due To Indwelling Urethral Catheter",
        ["T83.512A"] = "Infection And Inflammatory Reaction Due To Nephrostomy Catheter",
        ["T83.512D"] = "Infection And Inflammatory Reaction Due To Nephrostomy Catheter",
        ["T83.512S"] = "Infection And Inflammatory Reaction Due To Nephrostomy Catheter",
        ["T83.518A"] = "Infection And Inflammatory Reaction Due To Other Urinary Catheter",
        ["T83.518D"] = "Infection And Inflammatory Reaction Due To Other Urinary Catheter",
        ["T83.518S"] = "Infection And Inflammatory Reaction Due To Other Urinary Catheter"
    }
    local accountAlertCodes = GetAccountCodesInDictionary(Account, alertCodeDictionary)

    --------------------------------------------------------------------------------
    --- Initial Qualification Link Collection
    --------------------------------------------------------------------------------
    -- #Find all discrete values for custom lookups within the last 7 days
    -- maindiscreteDic = {}
    -- unsortedDicsreteDic = {}
    -- dvCount = 0
    -- #Combine all items into one list to search against
    -- discreteSearchList = [i for j in [dvCUrine, dvUABacteria, dvUAWBC, dvUASquamousEpithelias,
    --                     dvUARBC, dvUAProtein, dvUAHyalineCast, dvUABlood, dvUAGranCast, dvUALeakEsterase] for i in j]
    -- #Set datelimit for how far back to
    -- dvDateLimit = System.DateTime.Now.AddDays(-7)
    -- #Loop through all dvs finding any that match in the combined list adding to a dictionary the matches
    -- for dv in discreteValues or []:
    --     if dv.ResultDate >= dvDateLimit:
    --         if any(item == dv.Name for item in discreteSearchList):
    --             dvCount += 1
    --             unsortedDicsreteDic[dvCount] = dv
    -- #Sort List by latest
    -- maindiscreteDic = sorted(unsortedDicsreteDic.items(), key=lambda x: x[1]['ResultDate'], reverse=True)

    -- #Alert Trigger
    local utiCode = GetCodeLinks {
        codes = { "T83.510A", "T83.511A", "T83.512A", "T83.518" },
        text = "UTI with Device Link Codes: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
        sequence = 1,
    }
    local n390Code = GetCodeLinks { code = "N39.0", text = "Urinary Tract Infection: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])" }
    local r8271Code = GetCodeLinks { code = "R82.71", text = "Bacteriuria: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", sequence = 1 }
    local r8279Code = GetCodeLinks { code = "R82.79", text = "Positive Urine Culture: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", sequence = 7 }
    local r8281Code = GetCodeLinks { code = "R82.81", text = "Pyuria: [CODE] '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])", sequence = 8 }
    -- #Labs
    -- cUrineDV = dvcUrineCheck(dict(maindiscreteDic), dvCUrine, "Urine Culture: '[VALUE]' (Result Date: [RESULTDATETIME])", 4)
    -- #Urine
    -- bacteriaUrineDV = dvUrineCheck(dict(maindiscreteDic), dvUABacteria, "UA Bacteria: [VALUE] (Result Date: [RESULTDATETIME])", 1)
    -- #uti
    local chronicCystostomyCatheterAbstractionLink = GetAbstractionValueLinks {
        code = "CHRONIC_CYSTOSTOMY_CATHETER",
        text = "Cystostomy Catheter '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
        seq = 1
    }
    local cystostomyCatheterAbstractionLink = GetAbstractionValueLinks {
        code = "CYSTOSTOMY_CATHETER",
        text = "Cystostomy Catheter '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
        seq = 2
    }
    local chronicIndwellingUrethralCatheterAbstractionLink = GetAbstractionValueLinks {
        code = "CHRONIC_INDWELLING_URETHRAL_CATHETER",
        text = "Indwelling Urethral Catheter '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
        seq = 3
    }
    local indwellingUrethralCatheterAbstractionLink = GetAbstractionValueLinks {
        code = "INDWELLING_URETHRAL_CATHETER",
        text = "Indwelling Urethral Catheter '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
        seq = 4
    }
    local chronicNephrostomyCatheterAbstractionLink = GetAbstractionValueLinks {
        code = "CHRONIC_NEPHROSTOMY_CATHETER",
        text = "Nephrostomy Catheter '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
        seq = 5
    }
    local nephrostomyCatheterAbstractionLink = GetAbstractionValueLinks {
        code = "NEPHROSTOMY_CATHETER",
        text = "Nephrostomy Catheter '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
        seq = 6
    }
    local selfCatheterizationAbstractionLink = GetAbstractionValueLinks {
        code = "SELF_CATHETERIZATION",
        text = "Self Catheterization '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
        seq = 7
    }
    local straightCatheterizationAbstractionLink = GetAbstractionValueLinks {
        code = "STRAIGHT_CATHETERIZATION",
        text = "Straight Catheterization '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
        seq = 8
    }
    local chronicUrinaryDrainageDeviceAbstractionLink = GetAbstractionValueLinks {
        code = "CHRONIC_OTHER_URINARY_DRAINAGE_DEVICE",
        text = "Urinary Drainage Device '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
        seq = 9
    }
    local urinaryDrainageDeviceAbstractionLink = GetAbstractionValueLinks {
        code = "OTHER_URINARY_DRAINAGE_DEVICE",
        text = "Urinary Drainage Device '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
        seq = 10
    }
    local chronicUreteralStentAbstractionLink = GetAbstractionValueLinks {
        code = "CHRONIC_URETERAL_STENT",
        text = "Ureteral Stent '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
        seq = 11
    }
    local ureteralStentAbstractionLink = GetAbstractionValueLinks {
        code = "URETERAL_STENT",
        text = "Ureteral Stent '[PHRASE]' ([DOCUMENTTYPE], [DOCUMENTDATE])",
        seq = 12
    }

    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------

    if #accountAlertCodes > 0 then
        local code = accountAlertCodes[1]
        local codeDesc = alertCodeDictionary[code]
        local autoResolvedCodeLink = GetCodeLinks { code = code, text = "Autoresolved Specified Code - " .. codeDesc, seq = 1 }
        table.insert(documentedDxLinks, autoResolvedCodeLink)

        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true
    elseif utiCode == nil and n390Code ~= nil and (chronicCystostomyCatheterAbstractionLink ~= nil or cystostomyCatheterAbstractionLink ~= nil) then
        if chronicCystostomyCatheterAbstractionLink ~= nil then
            for _, link in ipairs(chronicCystostomyCatheterAbstractionLink) do
                table.insert(documentedDxLinks, link)
            end
        end
        if cystostomyCatheterAbstractionLink ~= nil then
            for _, link in ipairs(cystostomyCatheterAbstractionLink) do
                table.insert(documentedDxLinks, link)
            end
        end
        table.insert(documentedDxLinks, n390Code)
        Result.subtitle = "UTI Dx Possible Link To Cystostomy Catheter"
        Result.passed = true
    end
    -- elif UTICode is None and n390Code is not None and (chronicIndwellingUrethralCatheterAbs is not None or indwellingUrethralCatheterAbs is not None):
    --     if chronicIndwellingUrethralCatheterAbs is not None: dc.Links.Add(chronicIndwellingUrethralCatheterAbs)
    --     if indwellingUrethralCatheterAbs is not None: dc.Links.Add(indwellingUrethralCatheterAbs)
    --     dc.Links.Add(n390Code)
    --     result.Subtitle = "UTI Dx Possible Link To Indwelling Urethral Catheter"
    --     AlertPassed = True
    -- #4
    -- elif UTICode is None and n390Code is not None and (chronicNephrostomyCatheterAbs is not None or nephrostomyCatheterAbs is not None):
    --     if chronicNephrostomyCatheterAbs is not None: dc.Links.Add(chronicNephrostomyCatheterAbs)
    --     if nephrostomyCatheterAbs is not None: dc.Links.Add(nephrostomyCatheterAbs)
    --     dc.Links.Add(n390Code)
    --     result.Subtitle = "UTI Dx Possible Link To Nephrostomy Catheter"
    --     AlertPassed = True
    -- #5
    -- elif UTICode is None and n390Code is not None and (chronicUrinaryDrainageDeviceAbs is not None or urinaryDrainageDeviceAbs is not None):
    --     if chronicUrinaryDrainageDeviceAbs is not None: dc.Links.Add(chronicUrinaryDrainageDeviceAbs)
    --     if urinaryDrainageDeviceAbs is not None: dc.Links.Add(urinaryDrainageDeviceAbs)
    --     dc.Links.Add(n390Code)
    --     result.Subtitle = "UTI Dx Possible Link To Other Urinary Drainage Device"
    --     AlertPassed = True
    -- #6
    -- elif UTICode is None and n390Code is not None and (chronicUreteralStentAbs is not None or ureteralStentAbs is not None):
    --     dc.Links.Add(n390Code)
    --     if chronicUreteralStentAbs is not None: dc.Links.Add(chronicUreteralStentAbs)
    --     if ureteralStentAbs is not None: dc.Links.Add(ureteralStentAbs)
    --     result.Subtitle = "UTI Dx Possible Link To Ureteral Stent"
    --     AlertPassed = True
    -- #7
    -- elif UTICode is None and n390Code is not None and (selfCatheterizationAbs is not None or straghtCatheterizationAbs is not None):
    --     dc.Links.Add(n390Code)
    --     if selfCatheterizationAbs is not None: dc.Links.Add(selfCatheterizationAbs)
    --     if straghtCatheterizationAbs is not None: dc.Links.Add(straghtCatheterizationAbs)
    --     result.Subtitle = "UTI Dx Possible Link To Intermittent Catheterization"
    --     AlertPassed = True
    -- #8
    -- elif (
    --     n390Code is None and
    --     (cUrineDV or
    --     r8271Code is not None or
    --     r8279Code is not None or
    --     bacteriaUrineDV is not None or
    --     r8281Code is not None) and
    --     chronicCystostomyCatheterAbs is not None
    -- ):
    --     dc.Links.Add(chronicCystostomyCatheterAbs)
    --     result.Subtitle = "Possible UTI with Possible Link to Cystostomy Catheter"
    --     AlertPassed = True
    -- #9
    -- elif (
    --     n390Code is None and
    --     (cUrineDV or
    --     r8271Code is not None or
    --     r8279Code is not None or
    --     bacteriaUrineDV is not None or
    --     r8281Code is not None) and
    --     chronicIndwellingUrethralCatheterAbs is not None
    -- ):
    --     dc.Links.Add(chronicIndwellingUrethralCatheterAbs)
    --     result.Subtitle = "Possible UTI With Possible Link to Indwelling Urethral Catheter"
    --     AlertPassed = True
    -- #10
    -- elif (
    --     n390Code is None and
    --     (cUrineDV or
    --     r8271Code is not None or
    --     r8279Code is not None or
    --     bacteriaUrineDV is not None or
    --     r8281Code is not None) and
    --     chronicNephrostomyCatheterAbs is not None
    -- ):
    --     if chronicNephrostomyCatheterAbs is not None: dc.Links.Add(chronicNephrostomyCatheterAbs)
    --     result.Subtitle = "Possible UTI With Possible Link to Nephrostomy Catheter"
    --     AlertPassed = True
    -- #11
    -- elif (
    --     n390Code is None and
    --     (cUrineDV or
    --     r8271Code is not None or
    --     r8279Code is not None or
    --     bacteriaUrineDV is not None or
    --     r8281Code is not None) and
    --     chronicUrinaryDrainageDeviceAbs is not None
    -- ):
    --     if chronicUrinaryDrainageDeviceAbs is not None: dc.Links.Add(chronicUrinaryDrainageDeviceAbs)
    --     result.Subtitle = "Possible UTI With Possible Link to Other Urinary Drainage Device"
    --     AlertPassed = True
    -- #12
    -- elif (
    --     (cUrineDV or
    --     r8271Code is not None or
    --     r8279Code is not None or
    --     bacteriaUrineDV is not None or
    --     r8281Code is not None) and
    --     (chronicUreteralStentAbs is not None or
    --     ureteralStentAbs is not None)
    -- ):
    --     if bacteriaUrineDV is not None: dc.Links.Add(bacteriaUrineDV)
    --     if r8271Code is not None: dc.Links.Add(r8271Code)
    --     if chronicUreteralStentAbs is not None: dc.Links.Add(chronicUreteralStentAbs)
    --     if ureteralStentAbs is not None: dc.Links.Add(ureteralStentAbs)
    --     result.Subtitle = "Possible UTI with Possible Link to Ureteral Stent"
    --     AlertPassed = True
    -- #13
    -- elif (
    --     (cUrineDV or
    --     r8271Code is not None or
    --     r8279Code is not None or
    --     bacteriaUrineDV is not None or
    --     r8281Code is not None) and
    --     (selfCatheterizationAbs is not None or
    --     straghtCatheterizationAbs is not None)
    -- ):
    --     if bacteriaUrineDV is not None: dc.Links.Add(bacteriaUrineDV)
    --     if r8271Code is not None: dc.Links.Add(r8271Code)
    --     if selfCatheterizationAbs is not None: dc.Links.Add(selfCatheterizationAbs)
    --     if straghtCatheterizationAbs is not None: dc.Links.Add(straghtCatheterizationAbs)
    --     result.Subtitle = "Possible UTI with Possible Link to Intermittent Catheterization"
    --     AlertPassed = True
    -- #14
    -- elif codesExist == 0 and n390Code is None and (cUrineDV or bacteriaUrineDV):
    --     result.Subtitle = "Possible UTI"
    --     AlertPassed = True

    -- else:
    --     db.LogEvaluationScriptMessage("Not enough data to warrent alert, Alert Failed. " + str(account._id), scriptName, scriptInstance, "Debug")
    --     result.Passed = False
    --     AlertPassed = False

    if Result.passed then
        --------------------------------------------------------------------------------
        --- Link Collection
        --------------------------------------------------------------------------------
        local resultLinks = {}

        if Result.validated then
            -- Autoclose
        else
            -- Normal Alert
        end



        ----------------------------------------
        --- Result Finalization
        ----------------------------------------
        if existingAlert then
            resultLinks = MergeLinks(existingAlert.links, resultLinks)
        end
        Result.links = resultLinks
    end
end
