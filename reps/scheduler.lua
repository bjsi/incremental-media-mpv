local log = require("utils.log")
local dt = require("utils.date")

local Scheduler = {afactor = 2}
Scheduler.__index = Scheduler

setmetatable(Scheduler, {
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function Scheduler:_init(afactor)
    afactor = tonumber(afactor)
    if self:verify_afactor(afactor) then self.afactor = afactor end
    log.debug("Init scheduler with afactor: ", self.afactor)
end

function Scheduler:verify_afactor(n) return n ~= nil and n > 0 end

function Scheduler:verify_interval(n) return n ~= nil and n > 0 end

function Scheduler:schedule(repTable, rep)

    -- add interval days to current date
    local today = dt.date_today()
    local todayY, todayM, todayD = dt.parse_hhmmss(today)
    local interval = tonumber(rep.row["interval"])
    if not self:verify_interval(interval) then interval = 1 end

    local timeTable = {
        year = tonumber(todayY),
        month = tonumber(todayM),
        day = tonumber(todayD) + interval
    }

    rep.row["interval"] = self.afactor * interval
    rep.row["nextrep"] = os.date("%Y-%m-%d", os.time(timeTable))
    log.debug("Next rep date: ", rep.row["nextrep"])
    log.debug("Next interval: ", rep.row["interval"])
    repTable:add_to_subset(rep)
end

return Scheduler
