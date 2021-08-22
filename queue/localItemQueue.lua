local ItemQueueBase = require("queue.itemQueueBase")
local sort = require("reps.reptable.sort")
local ext = require("utils.ext")
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
    ItemQueueBase._init(self, "Local Item Queue", oldRep,
                        function(reps) return self:subsetter(oldRep, reps) end)
end

function LocalItemQueue:activate()
    if ItemQueueBase.activate(self) then
        sounds.play("local_item_queue")
        return true
    end
    return false
end

function LocalItemQueue:subsetter(oldRep, reps)
    local subset = ext.list_filter(reps, function(r)
        return not r:is_deleted() and r:is_child_of(oldRep)
    end)

    -- Sorting subset
    self:sort(subset)

    return subset, subset[1]
end

function LocalItemQueue:sort(reps)
    if not self.sorted then sort.by_created(reps) end
    self.sorted = true
end

return LocalItemQueue
