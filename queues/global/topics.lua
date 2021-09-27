local sounds = require 'systems.sounds'
local ScheduledTopicReptable = require 'reps.reptable.scheduledTopics'
local sort = require 'reps.reptable.sort'
local TopicQueueBase = require 'queues.base.topics'
local tbl = require 'utils.table'

local GlobalTopics = {}
GlobalTopics.__index = GlobalTopics

setmetatable(GlobalTopics, {
    __index = TopicQueueBase,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

--- Create a new GlobalTopicQueue.
--- @param oldRep Rep last playing Rep object.
function GlobalTopics:_init(oldRep)
    local subsetter = function(reps) return self:subsetter(reps) end
    local reptable = ScheduledTopicReptable(subsetter)
    TopicQueueBase._init(self, "Global Topic Queue", oldRep, reptable)
end

function GlobalTopics:activate()
    if TopicQueueBase.activate(self) then
        sounds.play("global_topic_queue")
        return true
    end
    return false
end

function GlobalTopics:subsetter(reps)
    local predicate = function(r) return r:is_outstanding(true) end
    local subset = tbl.filter(reps, predicate)
    sort.by_priority(subset)
    return subset, subset[1]
end

return GlobalTopics
