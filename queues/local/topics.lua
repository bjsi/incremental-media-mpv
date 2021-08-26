local sounds = require 'systems.sounds'
local tbl = require 'utils.table'
local TopicQueueBase = require 'queues.base.topics'

local LocalTopics = {}
LocalTopics.__index = LocalTopics

setmetatable(LocalTopics, {
    __index = TopicQueueBase,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

--- Create a new LocalTopicQueue.
--- @param oldRep Rep last playing Rep object.
function LocalTopics:_init(oldRep)
    TopicQueueBase._init(self, "Local Topic Queue", oldRep,
                         function(reps) return self:subsetter(reps, oldRep) end)
end

function LocalTopics:activate()
    if TopicQueueBase.activate(self) then
        sounds.play("global_topic_queue")
        return true
    end
    return false
end

-- TODO: is there the possibility of duplication between the first element
-- and the same element in the subset
function LocalTopics:subsetter(reps, oldRep)
    local subset = tbl.filter(reps,
                              function(r) return r:is_outstanding(false) end)
    local pred = function(topic) return oldRep:is_child_of(topic) end
    local fst = tbl.first(pred, reps)
    return subset, fst and fst or subset[1]
end

return LocalTopics
