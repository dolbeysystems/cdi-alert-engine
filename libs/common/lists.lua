local module = {}

function module.reduce(list, func, initial)
    local acc = initial
    ---@diagnostic disable-next-line: no-unknown
    for _, v in ipairs(list) do
        acc = func(acc, v)
    end
    return acc
end

function module.map(list, func)
    module.reduce(list, function(acc, v)
        table.insert(acc, func(v))
        return acc
    end, {})
end

function module.filter(list, func)
    module.reduce(list, function(acc, v)
        if func(v) then
            table.insert(acc, v)
        end
        return acc
    end, {})
end

function module.first(list, func)
    for _, v in ipairs(list) do
        if func(v) then
            return v
        end
    end
    return nil
end

function module.last(list, func)
    for i = #list, 1, -1 do
        if func(list[i]) then
            return list[i]
        end
    end
    return nil
end

---@param list any[]
---@param func function?
---@return boolean
function module.every(list, func)
    for _, v in ipairs(list) do
        if func == nil and v == nil or func ~= nil and not func(v) then
            return false
        end
    end
    return true
end

---@param list any[]
---@param func function?
---@return boolean
function module.some(list, func)
    for _, v in pairs(list) do
        if func == nil and v ~= nil or func ~= nil and func(v) then
            return true
        end
    end
    return false
end

function module.includes(list, value)
    return module.some(list, function(v)
        return v == value
    end)
end

return module
