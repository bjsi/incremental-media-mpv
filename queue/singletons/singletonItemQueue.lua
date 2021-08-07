local Base = require("queue.itemQueueBase")
local ext = require("utils.ext")


local SingletonItemQueue = {}
SingletonItemQueue.__index = SingletonItemQueue

setmetatable(SingletonItemQueue, {
    __index = Base, -- this is what makes the inheritance work
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function SingletonItemQueue:_init(repId)
    Base._init(self, "Singleton Item Queue", nil, function(reps) return self:subsetter(reps, repId) end)
end

function SingletonItemQueue:save_updates_to_sm()
    local cur = self.playing
    if cur == nil then return false end
end

function SingletonItemQueue:subsetter(reps, repId)
    local theRep = ext.first_or_nil(function(rep) return rep.row.id == repId end, reps)
    return {[1]=theRep}, theRep
end

return SingletonItemQueue
