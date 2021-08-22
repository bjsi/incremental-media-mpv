local ext = {}

-- inclusive
function ext.randomWithinInterval(min, max)
    return math.floor(math.random() * (max - min + 1) + min)
end

function ext.table_copy(from, to)
    for _, v in ipairs(from) do table.insert(to, v) end
end

function ext.list_slice(list, start, length)
    local slice = {}
    for i = start, start + length do table.insert(slice, list[i]) end
    return slice
end

function ext.list_range(list, from, to)
    if not to then
        to = #list
    elseif to < 0 then
        to = #list + to + 1
    end
    return ext.list_slice(list, from, to - from)
end

function ext.list_reverse(list)
    local res = {}
    for i = #list, 1, -1 do table.insert(res, list[i]) end
    return res
end

function ext.index_by_key(tbl, key)
    local ret = {}
    for _, v in ipairs(tbl) do ret[v.row[key]] = v end
    return ret
end

function ext.validate_afactor(n)
    local af = tonumber(n)
    return af ~= nil and af >= 1
end

function ext.validate_interval(n)
    local int = tonumber(n)
    return int ~= nil and int >= 1
end

function ext.validate_priority(n)
    local pri = tonumber(n)
    return pri ~= nil and pri >= 0 and pri <= 100
end

function ext.list_copy(list)
    local ret = {}
    for i, v in ipairs(list) do ret[i] = v end
    return ret
end

function ext.list_any(pred, list)
    for _, v in pairs(list) do if pred(v) then return true end end
    return false
end

function ext.stack_first(pred, stack)
    local ret
    while true do
        ret = stack:pop()
        if pred(ret) or ret == nil then return ret end
    end
end

function ext.first_or_nil(pred, list)
    for _, value in pairs(list) do if pred(value) then return value end end
end

function ext.round(n, digits)
    local shift = 10 ^ digits
    return math.floor(n * shift + 0.5) / shift
end

function ext.list_contains(table, element)
    for _, value in pairs(table) do if value == element then return true end end
    return false
end

function ext.list_max_num(table)
    local max = table[1]
    for _, value in ipairs(table) do if value > max then max = value end end
    return max
end

function ext.list_get(table, key, default)
    if table[key] == nil then
        return default or 'nil'
    else
        return table[key]
    end
end

function ext.file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then
        f:close()
        return true
    else
        return false
    end
end

function ext.list_add_range(list1, list2)
    for _, v in pairs(list2) do table.insert(list1, v) end
    return list1
end

function ext.list_group_by(list, grouper)
    local res = {}
    for i, v in pairs(list) do
        local key = grouper(v, i)
        if key ~= nil then
            if not res[key] then res[key] = {} end
            table.insert(res[key], v)
        end
    end
    return res
end

function ext.move_to_first_where(predicate, elements)
    local idx = nil
    for i, v in ipairs(elements) do
        if predicate(v) then
            idx = i
            break
        end
    end
    if idx ~= nil then
        local target = table.remove(elements, idx)
        table.insert(elements, 1, target)
    end
end

---Catches errors from require and returns lib or nil.
function ext.prequire(...)
    local status, lib = pcall(require, ...)
    if (status) then return lib end
    return nil
end

---Returns human readable string of the object.
---@param object any
function ext.dump(object)
    if type(object) == "table" then
        local s = '{'
        for k, v in pairs(object) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. ']' .. ext.dump(v) .. ','
        end
        return s .. '}'
    else
        return tostring(object)
    end
end

function ext.empty(object)
    return object == nil or object == '' or
               (type(object) == 'table' and next(object) == nil)
end

function ext.list_filter(list, predicate)
    local res = {}
    for i, val in ipairs(list) do
        if predicate(val, i) then table.insert(res, val) end
    end
    return res
end

function ext.list_map(list, mapper)
    if not mapper then mapper = function(val) return val end end

    local res = {}
    for i, val in ipairs(list) do table.insert(res, mapper(val)) end
    return res
end

return ext
