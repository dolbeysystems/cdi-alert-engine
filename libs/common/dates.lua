local module = {}
--------------------------------------------------------------------------------
--- Convert a date string to an integer
---
--- @param date_string string The date string to convert
---
--- @return number - the date as an integer
--------------------------------------------------------------------------------
function module.date_string_to_int(date_string)
    local pattern = "(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)"
    local year, month, day, hour, min, sec, _ = date_string:match(pattern)
    return os.time({ year = year, month = month, day = day, hour = hour, min = min, sec = sec })
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

return module

