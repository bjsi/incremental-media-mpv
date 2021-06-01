local Base = require("reps.rep.base")
local dt = require("utils.date")

local TopicRep = {}
TopicRep.__index = TopicRep

setmetatable(TopicRep, {
    __index = Base,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end,
})

function TopicRep:_init(row)
    Base._init(self, row)
end

function TopicRep:is_due()
    local todayDate = dt.date_today()
    local nextRepDate = self.row["nextrep"]
    local todayY, todayM, todayD = dt.parse_hhmmss(todayDate)
    local repY, repM, repD = dt.parse_hhmmss(nextRepDate)
    return (os.time{year=todayY, month=todayM, day=todayD} >= os.time{year=repY, month=repM, day=repD}) and not self:is_done()
end

function TopicRep:is_done()
    local curtime = self.row["curtime"]
    local stop = self.row["stop"]
    if curtime == nil then
        return false
    end

    if stop == nil then
        return false
    end

    return (tonumber(curtime) / tonumber(stop)) >= 0.95
end

--- Returns true if this Rep object is a child of argument rep.
-- @param rep is a Rep object.
function TopicRep:is_child_of()
    return false
end

--- Returns true if this Rep object is a direct parent of argument rep.
-- @param rep is a Rep object.
function TopicRep:is_parent_of(rep)
    return (self.row["title"] == rep.row["title"]) and rep:is_extract()
end

function TopicRep:set_interval(interval)
    self.row["interval"] = interval
    return true
end

return TopicRep
