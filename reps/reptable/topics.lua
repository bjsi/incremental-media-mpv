local fs = require('systems.fs')
local defaultHeader = require('reps.reptable.topic_header')
local ScheduledRepTable = require('reps.reptable.scheduled')
local TopicRep = require('reps.rep.topic')

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

local function same_start(a, b)
	return a.row.start == b.row.start
end

local function same_stop(a, b)
	return a.row.stop == b.row.stop
end

local function same_url(a, b)
	return a.row["url"] == b.row["url"]
end

function TopicRepTable:chapter_exists(chapter)
    for _, rep in ipairs(self.reps) do
        return same_start(rep, chapter) and same_stop(rep, chapter) and same_url(rep, chapter)
    end
    return false
end

function TopicRepTable:as_rep(row) return TopicRep(row) end

return TopicRepTable
