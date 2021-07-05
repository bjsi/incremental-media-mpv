local sounds = require("systems.sounds")
local sort = require("reps.reptable.sort")
local TopicQueueBase = require("queue.topicQueueBase")
local ext = require "utils.ext"

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
    if TopicQueueBase.activate(self) then
        sounds.play("global_topic_queue")
        return true
    end
    return false
end

function GlobalTopicQueue:subsetter(reps)
    local subset = ext.list_filter(reps, function(r) return r:is_due() and not r:is_done() and not r:has_dependency() end)
    sort.by_priority(subset)
    return subset, subset[1]
end

return GlobalTopicQueue