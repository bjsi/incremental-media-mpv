local af = {}

function af.validate(n)
    local a = tonumber(n)
    return a ~= nil and a >= 1
end

return af
