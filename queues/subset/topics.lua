local sort = require 'reps.reptable.sort'
local TopicQueueBase = require 'queues.base.topics'
local UnscheduledTopicRepTable = require 'reps.reptable.unscheduledTopics'
local tbl = require 'utils.table'

local TopicSubset = {}
TopicSubset.__index = TopicSubset

setmetatable(TopicSubset, {
    __index = TopicQueueBase,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function TopicSubset:_init(old_rep, id_list)
    local subsetter = function(reps) return self:subsetter(reps, id_list) end
    local reptable = UnscheduledTopicRepTable(subsetter)
    TopicQueueBase._init(self, "Topic Subset Queue", old_rep, reptable)
end

function TopicSubset:activate()
    return TopicQueueBase.activate(self)
end

function TopicSubset:subsetter(reps, id_list)
    local predicate = function(r) return tbl.contains(id_list, r.row.id) end
    local subset = tbl.filter(reps, predicate)
    sort.by_priority(subset)
    return subset, subset[1]
end

return TopicSubset
