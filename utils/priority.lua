local pri = {}

function pri.validate(n)
    local p = tonumber(n)
    return p ~= nil and p >= 0 and p <= 100
end

return pri
