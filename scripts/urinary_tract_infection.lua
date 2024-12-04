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

local function numeric_result_predicate(discreteValue)
    return discreteValue.name ~= nil and string.find(discreteValue.name, "%d+") ~= nil
end

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
    local utiCode = GetCodeLinks {
        codes = { "T83.510A", "T83.511A", "T83.512A", "T83.518" },
        text = "UTI with Device Link Codes",
        sequence = 1,
    }
    local n390Code = GetCodeLink { code = "N39.0", text = "Urinary Tract Infection" }
    local r8271Code = GetCodeLink { code = "R82.71", text = "Bacteriuria", sequence = 1 }
    local r8279Code = GetCodeLink { code = "R82.79", text = "Positive Urine Culture", sequence = 7 }
    local r8281Code = GetCodeLink { code = "R82.81", text = "Pyuria", sequence = 8 }

    local urineCulture = GetDiscreteValueLink {
        discreteValueName = "BACTERIA (/HPF)",
        linkText = "Urine Culture",
        sequence = 4,
        predicate = function(discreteValue)
            return discreteValue.result ~= nil and
                (string.find(discreteValue.result, "positive") ~= nil or string.find(discreteValue.result, "negative") ~= nil)
        end,
    }
    local urineBacteria = GetDiscreteValueLink {
        discreteValueName = "BACTERIA (/HPF)",
        linkText = "UA Bacteria",
        sequence = 1,
        predicate = numeric_result_predicate,
    }

    local chronicCystostomyCatheterAbstractionLink = GetAbstractionValueLinks {
        code = "CHRONIC_CYSTOSTOMY_CATHETER",
        text = "Cystostomy Catheter",
        seq = 1
    }
    local cystostomyCatheterAbstractionLink = GetAbstractionValueLinks {
        code = "CYSTOSTOMY_CATHETER",
        text = "Cystostomy Catheter",
        seq = 2
    }
    local chronicIndwellingUrethralCatheterAbstractionLink = GetAbstractionValueLinks {
        code = "CHRONIC_INDWELLING_URETHRAL_CATHETER",
        text = "Indwelling Urethral Catheter",
        seq = 3
    }
    local indwellingUrethralCatheterAbstractionLink = GetAbstractionValueLinks {
        code = "INDWELLING_URETHRAL_CATHETER",
        text = "Indwelling Urethral Catheter",
        seq = 4
    }
    local chronicNephrostomyCatheterAbstractionLink = GetAbstractionValueLinks {
        code = "CHRONIC_NEPHROSTOMY_CATHETER",
        text = "Nephrostomy Catheter",
        seq = 5
    }
    local nephrostomyCatheterAbstractionLink = GetAbstractionValueLinks {
        code = "NEPHROSTOMY_CATHETER",
        text = "Nephrostomy Catheter",
        seq = 6
    }
    local selfCatheterizationAbstractionLink = GetAbstractionValueLinks {
        code = "SELF_CATHETERIZATION",
        text = "Self Catheterization",
        seq = 7
    }
    local straightCatheterizationAbstractionLink = GetAbstractionValueLinks {
        code = "STRAIGHT_CATHETERIZATION",
        text = "Straight Catheterization",
        seq = 8
    }
    local chronicUrinaryDrainageDeviceAbstractionLink = GetAbstractionValueLinks {
        code = "CHRONIC_OTHER_URINARY_DRAINAGE_DEVICE",
        text = "Urinary Drainage Device",
        seq = 9
    }
    local urinaryDrainageDeviceAbstractionLink = GetAbstractionValueLinks {
        code = "OTHER_URINARY_DRAINAGE_DEVICE",
        text = "Urinary Drainage Device",
        seq = 10
    }
    local chronicUreteralStentAbstractionLink = GetAbstractionValueLinks {
        code = "CHRONIC_URETERAL_STENT",
        text = "Ureteral Stent",
        seq = 11
    }
    local ureteralStentAbstractionLink = GetAbstractionValueLinks {
        code = "URETERAL_STENT",
        text = "Ureteral Stent",
        seq = 12
    }

    --------------------------------------------------------------------------------
    --- Alert Qualification
    --------------------------------------------------------------------------------

    --- This function returns false if all of its parameters are nil,
    --- in order to make it usable as a condition.
    ---@param ... CdiAlertLink[]?
    ---@return boolean
    local function addLinks(...)
        local hadNonNil = false
        for _, links in pairs { ... } do
            if links ~= nil then
                for _, link in ipairs(links) do
                    table.insert(documentedDxLinks, link)
                end
                hadNonNil = true
            end
        end
        return hadNonNil
    end

    if #accountAlertCodes > 0 then
        local code = accountAlertCodes[1]
        local codeDesc = alertCodeDictionary[code]
        local autoResolvedCodeLink = GetCodeLink { code = code, text = "Autoresolved Specified Code - " .. codeDesc, seq = 1 }
        table.insert(documentedDxLinks, autoResolvedCodeLink)

        Result.outcome = "AUTORESOLVED"
        Result.reason = "Autoresolved due to one Specified Code on the Account"
        Result.validated = true
        Result.passed = true
    elseif utiCode == nil and n390Code ~= nil then
        if addLinks(chronicCystostomyCatheterAbstractionLink, cystostomyCatheterAbstractionLink) then
            table.insert(documentedDxLinks, n390Code)
            Result.subtitle = "UTI Dx Possible Link To Cystostomy Catheter"
            Result.passed = true
        elseif addLinks(chronicIndwellingUrethralCatheterAbstractionLink, indwellingUrethralCatheterAbstractionLink) then
            table.insert(documentedDxLinks, n390Code)
            Result.subtitle = "UTI Dx Possible Link To Indwelling Urethral Catheter"
            Result.passed = true
        elseif addLinks(chronicNephrostomyCatheterAbstractionLink, nephrostomyCatheterAbstractionLink) then
            table.insert(documentedDxLinks, n390Code)
            Result.subtitle = "UTI Dx Possible Link To Nephrostomy Catheter"
            Result.passed = true
            -- #5
        elseif addLinks(chronicUrinaryDrainageDeviceAbstractionLink, urinaryDrainageDeviceAbstractionLink) then
            table.insert(documentedDxLinks, n390Code)
            Result.subtitle = "UTI Dx Possible Link To Other Urinary Drainage Device"
            Result.passed = true
            -- #6
        elseif addLinks(chronicUreteralStentAbstractionLink, ureteralStentAbstractionLink) then
            table.insert(documentedDxLinks, n390Code)
            Result.subtitle = "UTI Dx Possible Link To Ureteral Stent"
            Result.passed = true
            -- #7
        elseif addLinks(selfCatheterizationAbstractionLink, straightCatheterizationAbstractionLink) then
            table.insert(documentedDxLinks, n390Code)
            Result.subtitle = "UTI Dx Possible Link To Intermittent Catheterization"
            Result.passed = true
        end
    elseif urineCulture or r8271Code or r8279Code or r8281Code or urineBacteria then
        if n390Code == nil then
            if addLinks(chronicCystostomyCatheterAbstractionLink) then
                Result.subtitle = "Possible UTI with Possible Link to Cystostomy Catheter"
                Result.passed = true
            elseif addLinks(chronicIndwellingUrethralCatheterAbstractionLink) then
                Result.subtitle = "Possible UTI With Possible Link to Indwelling Urethral Catheter"
                Result.passed = true
            elseif addLinks(chronicNephrostomyCatheterAbstractionLink) then
                Result.subtitle = "Possible UTI With Possible Link to Nephrostomy Catheter"
                Result.passed = true
            elseif addLinks(chronicUrinaryDrainageDeviceAbstractionLink) then
                Result.subtitle = "Possible UTI With Possible Link to Other Urinary Drainage Device"
                Result.passed = true
            end
        elseif addLinks(chronicUreteralStentAbstractionLink, ureteralStentAbstractionLink) then
            addLinks(urineBacteria)
            addLinks(r8271Code)
            Result.subtitle = "Possible UTI with Possible Link to Ureteral Stent"
            Result.passed = true
        elseif addLinks(selfCatheterizationAbstractionLink, straightCatheterizationAbstractionLink) then
            addLinks(urineBacteria)
            addLinks(r8271Code)
            Result.subtitle = "Possible UTI with Possible Link to Intermittent Catheterization"
            Result.passed = true
        end
    elseif #accountAlertCodes == 0 and n390Code == nil and (urineCulture or urineBacteria) then --TODO
        Result.subtitle = "Possible UTI"
        Result.passed = true
    end

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
