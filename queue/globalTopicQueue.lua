local sounds = require("systems.sounds")
local TopicQueueBase = require("queue.topicQueueBase")

local GlobalTopicQueue = {}
GlobalTopicQueue.__index = GlobalTopicQueue

setmetatable(GlobalTopicQueue, {
    __index = TopicQueueBase,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

--- Create a new GlobalTopicQueue.
--- @param oldRep Rep last playing Rep object.
function GlobalTopicQueue:_init(oldRep)
    TopicQueueBase._init(self, "Global Topic Queue", oldRep,
                         function(reps) return self:subsetter(reps) end)
end

function GlobalTopicQueue:activate()
    self:loadRep(self.reptable:current_scheduled(), self.oldRep)
    self:subscribe_to_events()
    sounds.play("global_topic_queue")
end

function GlobalTopicQueue:subsetter(reps)
    local subset = {}
    for i, v in ipairs(reps) do
        subset[i] = v
    end
    return subset
end

return GlobalTopicQueue