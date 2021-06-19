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
    self:loadRep(self.reptable:current_scheduled(), self.oldRep)
    sounds.play("global_topic_queue")
end

function LocalTopicQueue:subsetter(reps, oldRep)
    local subset = {}
    for i, v in ipairs(reps) do
        subset[i] = v
    end

    local pred = function(topic) return oldRep:is_child_of(topic) end

    if oldRep ~= nil then
        ext.move_to_first_where(pred, subset)
    end
    return subset
end

return LocalTopicQueue