local sort = {}

sort.by_priority = function(reps)
    local sort_func = function(a, b)
        local ap = tonumber(a.row["priority"])
        local bp = tonumber(b.row["priority"])
        return ap < bp
    end
    table.sort(reps, sort_func)
end

function sort.by_due(reps)
    local srt = function(a, b) return a:is_due() and not b:is_due() end
    table.sort(reps, srt)
end

return sort