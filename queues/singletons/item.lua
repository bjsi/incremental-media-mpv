local ItemQueueBase = require 'queues.base.items'
local tbl = require 'utils.table'

local SingletonItem = {}
SingletonItem.__index = SingletonItem

---Creates a singleton extract queue.
---@param id number id of the extract.
setmetatable(SingletonItem, {
    __index = ItemQueueBase, -- this is what makes the inheritance work
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function SingletonItem:_init(repId)
    ItemQueueBase._init(self, "Singleton Item Queue", nil,
                        function(reps) return self:subsetter(reps, repId) end)
end

function SingletonItem:subsetter(reps, id)
    local predicate = function(r) return r.row.id == id end
    local rep = tbl.first(predicate, reps)
    return {[1] = rep}, rep
end

return SingletonItem
