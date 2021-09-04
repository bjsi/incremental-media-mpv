local sounds = require 'systems.sounds'
local sort = require 'reps.reptable.sort'
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

function LocalTopics:subsetter(reps, old_rep)
    -- removes chance of duplication between the first element
    -- and the same element in the subset
    local parent_of_old = function(topic) return old_rep:is_child_of(topic) end
    local predicate = function(r) return r:is_outstanding(false) and not parent_of_old(r) end
    local subset = tbl.filter(reps, predicate)
    sort.by_priority(subset)
    local fst = tbl.first(parent_of_old, reps)
    if not fst then fst = subset[1] end
    return subset, fst
end

return LocalTopics
