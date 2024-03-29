local TopicQueueBase = require 'queues.base.topics'
local ScheduledTopicReptable = require 'reps.reptable.scheduledTopics'
local tbl = require 'utils.table'

local SingletonTopic = {}
SingletonTopic.__index = SingletonTopic

setmetatable(SingletonTopic, {
    __index = TopicQueueBase, -- this is what makes the inheritance work
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function SingletonTopic:_init(id)
    local subsetter = function(reps) return self:subsetter(reps, id) end
    local reptable = ScheduledTopicReptable(subsetter)
    TopicQueueBase._init(self, "Singleton Topic Queue", nil, reptable)
end

function SingletonTopic:subsetter(reps, id)
    local predicate = function(r) return r.row.id == id end
    local rep = tbl.first(predicate, reps)
    return {[1] = rep}, rep
end

return SingletonTopic
