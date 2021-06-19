local Scheduled = require("reps.rep.scheduled")

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

function TopicRep:_init(row) Scheduled._init(self, row) end

function TopicRep:is_done()
    local curtime = self.row["curtime"]
    local stop = self.row["stop"]
    if curtime == nil then return false end

    if stop == nil then return false end

    return (tonumber(curtime) / tonumber(stop)) >= 0.95
end

function TopicRep:is_child_of() return false end

function TopicRep:is_parent_of(extract)
    return (self.row["id"] == extract.row["parent"])
end

return TopicRep
