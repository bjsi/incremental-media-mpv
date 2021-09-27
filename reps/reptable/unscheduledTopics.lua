local fs = require("systems.fs")
local TopicRep = require("reps.rep.topic")
local defaultHeader = require("reps.reptable.topic_header")
local UnscheduledRepTable = require("reps.reptable.unscheduled")

local UnscheduledTopicRepTable = {}
UnscheduledTopicRepTable.__index = UnscheduledTopicRepTable

setmetatable(UnscheduledTopicRepTable, {
    __index = UnscheduledRepTable,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function UnscheduledTopicRepTable:_init(subsetter)
    UnscheduledRepTable._init(self, fs.topics_data, defaultHeader, subsetter)
end

function UnscheduledTopicRepTable:as_rep(row) return TopicRep(row) end

return UnscheduledTopicRepTable
