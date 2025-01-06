local module = {}
--------------------------------------------------------------------------------
--- Convert a date string to an integer
---
--- @param date_string string The date string to convert
--- @param convert_from_utc boolean? Whether to convert from UTC (default is true)
---
--- @return number - the date as an integer
--------------------------------------------------------------------------------
function module.date_string_to_int(date_string, convert_from_utc)
    local pattern = "(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)"
    local year, month, day, hour, min, sec, _ = date_string:match(pattern)
    local from_utc = convert_from_utc == nil and true or convert_from_utc

    local time = os.time({ year = year, month = month, day = day, hour = hour, min = min, sec = sec })
    if from_utc then
        local tmp_time = os.time()
        local d1 = os.date("*t", tmp_time)
        local d2 = os.date("!*t", tmp_time)
        d1.isdst = false

        ---@diagnostic disable-next-line: param-type-mismatch
        local zone_diff = os.difftime(os.time(d1), os.time(d2))
        time = time + zone_diff
    end
    return time
end

--------------------------------------------------------------------------------
--- Convert a date integer to a string
---
--- @param date_int number The date integer to convert
--- @param format string? The format to convert to
---
--- @return string - the date as a string
--------------------------------------------------------------------------------
function module.date_int_to_string(date_int, format)
    local fmt = format or "%m/%d/%Y %H:%M"
    ---@diagnostic disable-next-line: return-type-mismatch
    return os.date(fmt, date_int)
end

--------------------------------------------------------------------------------
--- Check if a date is less than a certain number of days ago
---
--- @param date_string string The date string to check
--- @param days number The number of days to check against
---
--- @return boolean - true if the date is less than the number of days ago, false otherwise
--------------------------------------------------------------------------------
function module.date_is_less_than_x_days_ago(date_string, days)
    local date = module.date_string_to_int(date_string)

    --- @diagnostic disable-next-line: param-type-mismatch
    local now_utc = os.time(os.date("!*t"))
    local days_in_seconds = days * 24 * 60 * 60
    return now_utc - date < days_in_seconds
end

--------------------------------------------------------------------------------
--- Get the date of a certain number of days ago
---
--- @param days number The number of days ago
---
--- @return number - the date as an integer
--------------------------------------------------------------------------------
function module.days_ago(days)
    --- @diagnostic disable-next-line: param-type-mismatch
    local now_utc = os.time(os.date("!*t"))
    local days_in_seconds = days * 24 * 60 * 60
    return now_utc - days_in_seconds
end

--------------------------------------------------------------------------------
--- Check if a date is less than a certain number of minutes ago
---
--- @param date_string string The date string to check
--- @param minutes number The number of minutes to check against
---
--- @return boolean - true if the date is less than the number of minutes ago, false otherwise
--------------------------------------------------------------------------------
function module.date_is_less_than_x_minutes_ago(date_string, minutes)
    local date = module.date_string_to_int(date_string)

    local now_utc_str = os.date("!*t")
    --- @diagnostic disable-next-line: param-type-mismatch
    local now_utc = os.time(now_utc_str)

    local minutes_in_seconds = minutes * 60
    return now_utc - date < minutes_in_seconds
end

--------------------------------------------------------------------------------
--- Check if two dates are less than a certain number of minutes apart
---
--- @param date1 string The first date string to check
--- @param date2 string The second date string to check
--- @param minutes number The number of minutes to check against
---
--- @return boolean - true if the dates are less than the number of minutes apart, false otherwise
--------------------------------------------------------------------------------
function module.dates_are_less_than_x_minutes_apart(date1, date2, minutes)
    local date1_int = module.date_string_to_int(date1)
    local date2_int = module.date_string_to_int(date2)

    local minutes_in_seconds = minutes * 60
    return math.abs(date1_int - date2_int) < minutes_in_seconds
end

return module

