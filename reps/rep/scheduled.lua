local Base = require("reps.rep.base")
local dt = require("utils.date")

local ScheduledRep = {}
ScheduledRep.__index = ScheduledRep

setmetatable(ScheduledRep, {
    __index = Base,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function ScheduledRep:_init(row) Base._init(self, row) end

function ScheduledRep:is_due()
    local todayDate = dt.date_today()
    local nextRepDate = self.row["nextrep"]
    local todayY, todayM, todayD = dt.parse_hhmmss(todayDate)
    local repY, repM, repD = dt.parse_hhmmss(nextRepDate)
    return (os.time {year = todayY, month = todayM, day = todayD} >=
               os.time {year = repY, month = repM, day = repD})

end

-- TODO:
function ScheduledRep:set_interval(interval)
    self.row["interval"] = interval
    return true
end

function ScheduledRep:valid_interval()
    return self.row["interval"] ~= nil and self.row["interval"] > 0
end

return ScheduledRep
