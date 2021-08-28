local tbl = {}

function tbl.filter(list, predicate)
    local res = {}
    for i, val in ipairs(list) do
        if predicate(val, i) then table.insert(res, val) end
    end
    return res
end

function tbl.map(list, mapper)
    if not mapper then mapper = function(val) return val end end

    local res = {}
    for _, val in ipairs(list) do table.insert(res, mapper(val)) end
    return res
end

function tbl.add_range(list1, list2)
    for _, v in pairs(list2) do table.insert(list1, v) end
    return list1
end

function tbl.group_by(list, grouper)
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

function tbl.move_to_first_where(predicate, elements)
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

function tbl.first(pred, list)
    for _, value in pairs(list) do if pred(value) then return value end end
end

function tbl.contains(table, element)
    for _, value in pairs(table) do if value == element then return true end end
    return false
end

function tbl.max(table)
    local max = table[1]
    for _, value in ipairs(table) do if value > max then max = value end end
    return max
end

function tbl.get(table, key, default)
    if table[key] == nil then
        return default or 'nil'
    else
        return table[key]
    end
end

function tbl.copy(list)
    local ret = {}
    for i, v in ipairs(list) do ret[i] = v end
    return ret
end

function tbl.any(pred, list)
    for _, v in pairs(list) do if pred(v) then return true end end
    return false
end

function tbl.slice(list, start, length)
    local slice = {}
    for i = start, start + length do table.insert(slice, list[i]) end
    return slice
end

function tbl.range(list, from, to)
    if not to then
        to = #list
    elseif to < 0 then
        to = #list + to + 1
    end
    return tbl.slice(list, from, to - from)
end

function tbl.reverse(list)
    local res = {}
    for i = #list, 1, -1 do table.insert(res, list[i]) end
    return res
end

function tbl.copy_to(from, to)
    for _, v in ipairs(from) do table.insert(to, v) end
end

function tbl.index_by_key(list, key)
    local ret = {}
    for _, v in ipairs(list) do ret[v.row[key]] = v end
    return ret
end

return tbl
