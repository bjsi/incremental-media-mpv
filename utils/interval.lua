local ivl = {}

function ivl.validate(n)
    local i = tonumber(n)
    return i ~= nil and i >= 1
end

return ivl
