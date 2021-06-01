local queue = nil

local active = {}

active.load_queue = function(q)
    queue = q
end

return active
