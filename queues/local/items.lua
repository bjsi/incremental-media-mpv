local ItemQueueBase = require 'queues.base.items'
local tbl = require 'utils.table'
local sort = require 'reps.reptable.sort'
local sounds = require 'systems.sounds'

local LocalItems = {}
LocalItems.__index = LocalItems

setmetatable(LocalItems, {
    __index = ItemQueueBase, -- this is what makes the inheritance work
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function LocalItems:_init(oldRep)
    ItemQueueBase._init(self, "Local Item Queue", oldRep,
                        function(reps) return self:subsetter(oldRep, reps) end)
end

function LocalItems:activate()
    if ItemQueueBase.activate(self) then
        sounds.play("local_item_queue")
        return true
    end
    return false
end

function LocalItems:subsetter(old_rep, reps)
    local predicate = function(r)
        return not r:is_deleted() and r:is_child_of(old_rep)
    end
    local subset = tbl.filter(reps, predicate)
    sort.by_created(reps)
    return subset, subset[1]
end

return LocalItems
