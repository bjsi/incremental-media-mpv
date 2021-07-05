local sounds = require("systems.sounds")
local TopicQueueBase = require("queue.topicQueueBase")
local ext = require("utils.ext")

local LocalTopicQueue = {}
LocalTopicQueue.__index = LocalTopicQueue

setmetatable(LocalTopicQueue, {
    __index = TopicQueueBase,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

--- Create a new LocalTopicQueue.
--- @param oldRep Rep last playing Rep object.
function LocalTopicQueue:_init(oldRep)
    TopicQueueBase._init(self, "Local Topic Queue", oldRep,
                         function(reps) return self:subsetter(reps, oldRep) end)
end

function LocalTopicQueue:activate()
    if TopicQueueBase.activate(self) then
        sounds.play("global_topic_queue")
        return true
    end
    return false
end

-- TODO: is there the possibility of duplication between the first element
-- and the same element in the subset
function LocalTopicQueue:subsetter(reps, oldRep)
    local subset = ext.list_filter(reps, function(r) return r:is_due() and not r:has_dependency() and not r:is_deleted() end)
    local pred = function(topic) return oldRep:is_child_of(topic) end
    local fst = ext.first_or_nil(pred, reps)
    return subset, fst and fst or subset[1]
end

return LocalTopicQueue