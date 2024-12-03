--------------------------------------------------------------------------------
--- Convert a date string to an integer
---
--- @param dateString string The date string to convert
---
--- @return number - the date as an integer
--------------------------------------------------------------------------------
function DateStringToInt(dateString)
    local pattern = "(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)"
    local year, month, day, hour, min, sec, _ = dateString:match(pattern)
    return os.time({ year = year, month = month, day = day, hour = hour, min = min, sec = sec })
end

--------------------------------------------------------------------------------
--- Check if a date is less than a certain number of days ago
---
--- @param dateString string The date string to check
--- @param days number The number of days to check against
---
--- @return boolean - true if the date is less than the number of days ago, false otherwise
--------------------------------------------------------------------------------
function DateIsLessThanXDaysAgo(dateString, days)
    local date = DateStringToInt(dateString)

    --- @diagnostic disable-next-line: param-type-mismatch
    local nowUtc = os.time(os.date("!*t"))
    local daysInSeconds = days * 24 * 60 * 60
    return nowUtc - date < daysInSeconds
end

--------------------------------------------------------------------------------
--- Check if a date is less than a certain number of minutes ago
---
--- @param dateString string The date string to check
--- @param minutes number The number of minutes to check against
---
--- @return boolean - true if the date is less than the number of minutes ago, false otherwise
--------------------------------------------------------------------------------
function DateIsLessThanXMinutesAgo(dateString, minutes)
    local date = DateStringToInt(dateString)

    local nowUtcStr = os.date("!*t")
    --- @diagnostic disable-next-line: param-type-mismatch
    local nowUtc = os.time(nowUtcStr)

    local minutesInSeconds = minutes * 60
    return nowUtc - date < minutesInSeconds
end