local Base = require("queue.extractQueueBase")
local UnscheduledExtractRepTable = require("reps.reptable.unscheduledExtracts")
local ext                         = require("utils.ext")

local SingletonExtractQueue = {}
SingletonExtractQueue.__index = SingletonExtractQueue

setmetatable(SingletonExtractQueue, {
    __index = Base, -- this is what makes the inheritance work
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function SingletonExtractQueue:_init(repId)
    local reptable = UnscheduledExtractRepTable(function(reps) return self:subsetter(reps, repId) end);
    Base._init(self, "Singleton Extract Queue", nil, reptable)
end

function SingletonExtractQueue:subsetter(reps, repId)
    local theRep = ext.first_or_nil(function(rep) return rep.row.id == repId end, reps)
    return {[1]=theRep}, theRep
end

return SingletonExtractQueue
