--- @class (exact) HematocritHemoglobinDiscreteValuePair
--- @field hemoglobinLink CdiAlertLink
--- @field hematocritLink CdiAlertLink

--------------------------------------------------------------------------------
--- Get Low Hemoglobin Discrete Value Pairs
---
--- @param gender string Gender of the patient
--- 
--- @return HematocritHemoglobinDiscreteValuePair[]
--------------------------------------------------------------------------------
function GetLowHemoglobinDiscreteValuePairs(gender)
    local lowHemoglobinValue = 12

    if gender == "M" then
        lowHemoglobinValue = 13.5
    end

    --- @type HematocritHemoglobinDiscreteValuePair[]
    local lowHemoglobinPairs = {}

    local lowHemoglobinValues = GetOrderedDiscreteValues({
        discreteValueName = "Hemoglobin",
        predicate = function(dv)
            return GetDvValueNumber(dv) <= lowHemoglobinValue
        end,
        daysBack = 31
    })
    for i = 1, #lowHemoglobinValues do
        local dvHemoglobin = lowHemoglobinValues[i]
        local dvDate = dvHemoglobin.result_date
        local dvHematocrit = GetDiscreteValueNearestToDate({
            discreteValueName = "Hematocrit",
            --- @cast dvDate string
            date = dvDate
        })
        if dvHematocrit then
            local hemoglobinLink = GetLinkForDiscreteValue(dvHemoglobin, "Hemoglobin", 1, true)
            local hematocritLink = GetLinkForDiscreteValue(dvHematocrit, "Hematocrit", 2, true)
            --- @type HematocritHemoglobinDiscreteValuePair
            local pair = { hemoglobinLink = hemoglobinLink, hematocritLink = hematocritLink }

            table.insert(lowHemoglobinPairs, pair)
        end
    end

    return lowHemoglobinPairs
end

--------------------------------------------------------------------------------
--- Get Low Hemoglobin Discrete Value Pairs
--- 
--- @param gender string Gender of the patient
---
--- @return HematocritHemoglobinDiscreteValuePair[]
--------------------------------------------------------------------------------
function GetLowHematocritDiscreteValuePairs(gender)
    local lowHematocritValue = 35

    if gender == "M" then
        lowHematocritValue = 38
    end

    --- @type HematocritHemoglobinDiscreteValuePair[]
    local lowHematocritPairs = {}

    local lowHematomocritValues = GetOrderedDiscreteValues({
        discreteValueName = "Hematocrit",
        predicate = function(dv)
            return GetDvValueNumber(dv) <= lowHematocritValue
        end,
        daysBack = 31
    })
    for i = 1, #lowHematomocritValues do
        local dvHematocrit = lowHematomocritValues[i]
        local dvDate = dvHematocrit.result_date
        local dvHemoglobin = GetDiscreteValueNearestToDate({
            discreteValueName = "Hemoglobin",
            --- @cast dvDate string
            date = dvDate
        })
        if dvHemoglobin then
            local hematocritLink = GetLinkForDiscreteValue(dvHematocrit, "Hematocrit", 1, true)
            local hemoglobinLink = GetLinkForDiscreteValue(dvHemoglobin, "Hemoglobin", 2, true)
            --- @type HematocritHemoglobinDiscreteValuePair
            local pair = { hemoglobinLink = hemoglobinLink, hematocritLink = hematocritLink }
            table.insert(lowHematocritPairs, pair)
        end
    end
    return lowHematocritPairs
end

--- @class (exact) HematocritHemoglobinPeakDropLinks
--- @field hemoglobinPeakLink CdiAlertLink
--- @field hemoglobinDropLink CdiAlertLink
--- @field hematocritPeakLink CdiAlertLink
--- @field hematocritDropLink CdiAlertLink

--------------------------------------------------------------------------------
--- Get Hemoglobin and Hematocrit Links denoting a significant drop in hemoglobin 
---
--- @return HematocritHemoglobinPeakDropLinks? - Peak and Drop links for Hemoglobin and Hematocrit if present
--------------------------------------------------------------------------------
function GetHemoglobinDropPairs()
    local hemoglobinPeakLink = nil
    local hemoglobinDropLink = nil
    local hematocritPeakLink = nil
    local hematocritDropLink = nil

    local highestHemoglobinInPastWeek = GetHighestDiscreteValue({
        discreteValueName = "Hemoglobin",
        daysBack = 7
    })
    local lowestHemoglobinInPastWeekAfterHighest = GetLowestDiscreteValue({
        discreteValueName = "Hemoglobin",
        daysBack = 7,
        predicate = function(dv)
            return highestHemoglobinInPastWeek ~= nil and dv.result_date > highestHemoglobinInPastWeek.result_date
        end
    })
    local hemoglobinDelta = 0

    if highestHemoglobinInPastWeek and lowestHemoglobinInPastWeekAfterHighest then
        hemoglobinDelta = GetDvValueNumber(highestHemoglobinInPastWeek) - GetDvValueNumber(lowestHemoglobinInPastWeekAfterHighest)
        if hemoglobinDelta >= 2 then
            hemoglobinPeakLink = GetLinkForDiscreteValue(highestHemoglobinInPastWeek, "Peak Hemoglobin", 1, true)
            hemoglobinDropLink = GetLinkForDiscreteValue(lowestHemoglobinInPastWeekAfterHighest, "Dropped Hemoglobin", 2, true)
            local hemoglobinPeakHemocrit = GetDiscreteValueNearestToDate({
                discreteValueName = "Hematocrit",
                date = highestHemoglobinInPastWeek.result_date
            })
            local hemoglobinDropHemocrit = GetDiscreteValueNearestToDate({
                discreteValueName = "Hematocrit",
                date = lowestHemoglobinInPastWeekAfterHighest.result_date
            })
            if hemoglobinPeakHemocrit then
                hematocritPeakLink = GetLinkForDiscreteValue(hemoglobinPeakHemocrit, "Hematocrit at Hemoglobin Peak", 3, true)
            end
            if hemoglobinDropHemocrit then
                hematocritDropLink = GetLinkForDiscreteValue(hemoglobinDropHemocrit, "Hematocrit at Hemoglobin Drop", 4, true)
            end
        end
    end

    if hemoglobinPeakLink and hemoglobinDropLink and hematocritPeakLink and hematocritDropLink then
        return {
            hemoglobinPeakLink = hemoglobinPeakLink,
            hemoglobinDropLink = hemoglobinDropLink,
            hematocritPeakLink = hematocritPeakLink,
            hematocritDropLink = hematocritDropLink
        }
    else
        return nil
    end
end

--------------------------------------------------------------------------------
--- Get Hemoglobin and Hematocrit Links denoting a significant drop in hematocrit
---
--- @return HematocritHemoglobinPeakDropLinks? - Peak and Drop links for Hemoglobin and Hematocrit if present
--------------------------------------------------------------------------------
function GetHematocritDropPairs()
    local hemoglobinPeakLink = nil
    local hemoglobinDropLink = nil
    local hematocritPeakLink = nil
    local hematocritDropLink = nil

    -- If we didn't find the hemoglobin drop, look for a hematocrit drop
    local highestHematocritInPastWeek = GetHighestDiscreteValue({
        discreteValueName = "Hematocrit",
        daysBack = 7
    })
    local lowestHematocritInPastWeekAfterHighest = GetLowestDiscreteValue({
        discreteValueName = "Hematocrit",
        daysBack = 7,
        predicate = function(dv)
            return highestHematocritInPastWeek ~= nil and dv.result_date > highestHematocritInPastWeek.result_date
        end
    })
    local hematocritDelta = 0

    if highestHematocritInPastWeek and lowestHematocritInPastWeekAfterHighest then
        hematocritDelta = GetDvValueNumber(highestHematocritInPastWeek) - GetDvValueNumber(lowestHematocritInPastWeekAfterHighest)
        if hematocritDelta >= 6 then
            hematocritPeakLink = GetLinkForDiscreteValue(highestHematocritInPastWeek, "Peak Hematocrit", 5, true)
            hematocritDropLink = GetLinkForDiscreteValue(lowestHematocritInPastWeekAfterHighest, "Dropped Hematocrit", 6, true)
            local hemocritPeakHemoglobin = GetDiscreteValueNearestToDate({
                discreteValueName = "Hemoglobin",
                date = highestHematocritInPastWeek.result_date
            })
            local hemocritDropHemoglobin = GetDiscreteValueNearestToDate({
                discreteValueName = "Hemoglobin",
                date = lowestHematocritInPastWeekAfterHighest.result_date
            })
            if hemocritPeakHemoglobin then
                hemoglobinPeakLink = GetLinkForDiscreteValue(hemocritPeakHemoglobin, "Hemoglobin at Hematocrit Peak", 7, true)
            end
            if hemocritDropHemoglobin then
                hemoglobinDropLink = GetLinkForDiscreteValue(hemocritDropHemoglobin, "Hemoglobin at Hematocrit Drop", 8, true)
            end
        end
    end

    if hemoglobinPeakLink and hemoglobinDropLink and hematocritPeakLink and hematocritDropLink then
        return {
            hemoglobinPeakLink = hemoglobinPeakLink,
            hemoglobinDropLink = hemoglobinDropLink,
            hematocritPeakLink = hematocritPeakLink,
            hematocritDropLink = hematocritDropLink
        }
    else
        return nil
    end
end