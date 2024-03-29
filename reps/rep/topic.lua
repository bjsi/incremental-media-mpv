local ScheduledRep = require "reps.rep.scheduled"
local obj = require 'utils.object'

local TopicRep = {}
TopicRep.__index = TopicRep

setmetatable(TopicRep, {
    __index = ScheduledRep,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function TopicRep:_init(row) ScheduledRep._init(self, row) end

function TopicRep:is_chapter() return self.row["chapter"] == "1" end

function TopicRep:is_outstanding(checkDue)
    local default = not self:is_deleted() and not self:is_done() and
                        not self:is_dismissed() and not self:has_dependency()
    if checkDue then
        return self:is_due() and default
    else
        return default
    end
end

function TopicRep:has_dependency() return not obj.empty(self.row["dependency"]) end

function TopicRep:type() return "topic" end

function TopicRep:is_done()
    local curtime = tonumber(self.row["curtime"])
    local stop = tonumber(self.row["stop"])
    if curtime == nil or stop == nil then return false end
    return (stop - curtime) <= 2
end

function TopicRep:is_child_of() return false end

function TopicRep:is_parent_of(extract)
    return (self.row["id"] == extract.row["parent"])
end

return TopicRep
