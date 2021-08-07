local Base = require("queue.topicQueueBase")
local ext = require("utils.ext")

local SingletonTopicQueue = {}
SingletonTopicQueue.__index = SingletonTopicQueue

setmetatable(SingletonTopicQueue, {
    __index = Base, -- this is what makes the inheritance work
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function SingletonTopicQueue:_init(repId)
    Base._init(self, "Singleton Topic Queue", nil, function(reps) return self:subsetter(reps, repId) end)
end

function SingletonTopicQueue:subsetter(reps, repId)
    local theRep = ext.first_or_nil(function(rep) return rep.row.id == repId end, reps)
    return {[1]=theRep}, theRep
end

return SingletonTopicQueue