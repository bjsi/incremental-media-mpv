local obj = {}

---Returns human readable string of the object.
---@param object any
function obj.dump(object)
    if type(object) == "table" then
        local s = '{'
        for k, v in pairs(object) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. ']' .. obj.dump(v) .. ','
        end
        return s .. '}'
    else
        return tostring(object)
    end
end

function obj.empty(object)
    return object == nil or object == '' or
               (type(object) == 'table' and next(object) == nil)
end

return obj
