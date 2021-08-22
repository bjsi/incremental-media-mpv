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

function sort.by_created(reps)
    local srt = function(a, b)
        return tonumber(a.row["created"]) > tonumber(b.row["created"])
    end
    table.sort(reps, srt)
end

function sort.by_start_time(reps)
    local srt = function(a, b)
        return tonumber(a.row["start"]) < tonumber(b.row["start"])
    end
    table.sort(reps, srt)
end

return sort
