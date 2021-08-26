local ItemQueueBase = require 'queues.base.items'
local sort = require 'reps.reptable.sort'
local sounds = require 'systems.sounds'
local tbl = require 'utils.table'

local GlobalItems = {}
GlobalItems.__index = GlobalItems

setmetatable(GlobalItems, {
    __index = ItemQueueBase,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

--- Create a new GlobalTopicQueue.
--- @param oldRep Rep last playing Rep object.
function GlobalItems:_init(oldRep)
    ItemQueueBase._init(self, "Global Item Queue", oldRep,
                        function(reps) return self:subsetter(reps) end)
end

function GlobalItems:activate()
    if ItemQueueBase.activate(self) then
        sounds.play("global_item_queue")
        return true
    end
    return false
end

function GlobalItems:subsetter(reps)
    local subset = tbl.filter(reps, function(r)
        return r:is_outstanding(true)
    end)
    self:sort(subset)
    return subset, subset[1]
end

function GlobalItems:sort(reps)
    if not self.sorted then sort.by_priority(reps) end
    self.sorted = true
end

return GlobalItems
