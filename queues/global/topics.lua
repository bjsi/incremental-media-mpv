local sounds = require 'systems.sounds'
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
    TopicQueueBase._init(self, "Global Topic Queue", oldRep,
                         function(reps) return self:subsetter(reps) end)
end

function GlobalTopics:activate()
    if TopicQueueBase.activate(self) then
        sounds.play("global_topic_queue")
        return true
    end
    return false
end

function GlobalTopics:subsetter(reps)
    local subset = tbl.filter(reps, function(r)
        return r:is_outstanding(true)
    end)
    sort.by_priority(subset)
    return subset, subset[1]
end

return GlobalTopics
