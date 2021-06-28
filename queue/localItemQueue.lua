local ItemQueueBase = require("queue.itemQueueBase")
local UnscheduledItemRepTable = require("reps.reptable.unscheduledItems")
local ext = require("utils.ext")
local log = require("utils.log")
local sounds = require("systems.sounds")

local LocalItemQueue = {}
LocalItemQueue.__index = LocalItemQueue

setmetatable(LocalItemQueue, {
    __index = ItemQueueBase, -- this is what makes the inheritance work
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function LocalItemQueue:_init(oldRep)
    ItemQueueBase._init(self, "Local Item Queue", oldRep, function(reps) return self:subsetter(oldRep, reps) end)
end

function LocalItemQueue:activate()
    if ItemQueueBase.activate(self) then
        sounds.play("local_item_queue")
        return true
    end
    return false
end

function LocalItemQueue:subsetter(oldRep, reps)    
    local subset = {}
    for i, v in ipairs(reps) do
        subset[i] = v
    end
    local ret = ext.list_filter(subset, function(r) return r:is_child_of(oldRep) end)
    return ret, function(x) return x[1] end
end

return LocalItemQueue