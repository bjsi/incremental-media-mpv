local Base = require("reps.reptable.base")
local log = require("utils.log")
local TopicRep = require("reps.rep.topic")

local default_header = {
    [1]="title",
    [2]="type",
    [3]="url",
    [4]="element",
    [5]="start",
    [6]="stop",
    [7]="curtime",
    [8]="priority",
    [9]="interval",
    [10]="nextrep",
    [11]="speed",
}

local TopicRepTable = {}
TopicRepTable.__index = TopicRepTable

setmetatable(TopicRepTable, {
    __index = Base,
    __call = function(cls, ...)
            local self = setmetatable({}, cls)
            self:_init(...)
            return self
        end,
    })

function TopicRepTable:_init(fp)
    Base._init(self, fp, default_header)
    self:read_reps()
end

function TopicRepTable:sort()
    self:sort_by_priority()
    self:sort_by_due()
end

function TopicRepTable:sort_by_due()
    local srt = function(a, b)
        return a:is_due() and not b:is_due()
    end
    table.sort(self.reps, srt)
end

function TopicRepTable:read_reps()
    log.debug("Reading topic reps.")
    local header, reps = self.db:read_reps(function(row) return TopicRep(row) end)
    self.reps = reps and reps or {}
    self.header = header and header or default_header
    self:sort()
end

return TopicRepTable
