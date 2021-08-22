local ItemQueueBase = require("queue.itemQueueBase")
local sort = require("reps.reptable.sort")
local sounds = require("systems.sounds")
local ext = require("utils.ext")

local GlobalItemQueue = {}
GlobalItemQueue.__index = GlobalItemQueue

setmetatable(GlobalItemQueue, {
    __index = ItemQueueBase,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

--- Create a new GlobalTopicQueue.
--- @param oldRep Rep last playing Rep object.
function GlobalItemQueue:_init(oldRep)
    ItemQueueBase._init(self, "Global Item Queue", oldRep,
                        function(reps) return self:subsetter(reps) end)
end

function GlobalItemQueue:activate()
    if ItemQueueBase.activate(self) then
        sounds.play("global_item_queue")
        return true
    end
    return false
end

function GlobalItemQueue:subsetter(reps)
    local subset = ext.list_filter(reps, function(r)
        return r:is_outstanding(true)
    end)
    self:sort(subset)
    return subset, subset[1]
end

function GlobalItemQueue:sort(reps)
    if not self.sorted then sort.by_priority(reps) end
    self.sorted = true
end

return GlobalItemQueue
