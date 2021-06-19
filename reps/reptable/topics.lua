local fs = require("systems.fs")
local defaultHeader = require("reps.reptable.topic_header")
local ScheduledRepTable = require("reps.reptable.scheduled")
local TopicRep = require("reps.rep.topic")

local TopicRepTable = {}
TopicRepTable.__index = TopicRepTable

setmetatable(TopicRepTable, {
    __index = ScheduledRepTable,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function TopicRepTable:_init(subsetter)
    ScheduledRepTable._init(self, fs.topics_data, defaultHeader, subsetter)
end

function ScheduledRepTable:as_rep(row)
    return TopicRep(row)
end

return TopicRepTable
