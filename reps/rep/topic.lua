local Scheduled = require("reps.rep.scheduled")
local ext = require('utils.ext')

local TopicRep = {}
TopicRep.__index = TopicRep

setmetatable(TopicRep, {
    __index = Scheduled,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function TopicRep:has_dependency()
    return not ext.empty(self.row["dependency"])
end

function TopicRep:_init(row) Scheduled._init(self, row) end

function TopicRep:type() return "topic" end

function TopicRep:is_done()
    local curtime = tonumber(self.row["curtime"])
    local stop = tonumber(self.row["stop"])
    if curtime == nil or stop == nil then return false end
    return curtime / stop >= 0.95
end

function TopicRep:is_child_of() return false end

function TopicRep:is_parent_of(extract)
    return (self.row["id"] == extract.row["parent"])
end

return TopicRep
