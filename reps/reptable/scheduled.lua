local Base = require 'reps.reptable.base'
local af = require 'utils.afactor'
local ivl = require 'utils.interval'
local dt = require 'utils.date'
local sounds = require 'systems.sounds'
local log = require 'utils.log'
local active = require 'systems.active'
local sort = require 'reps.reptable.sort'

local ScheduledRepTable = {}
ScheduledRepTable.__index = ScheduledRepTable

setmetatable(ScheduledRepTable, {
    __index = Base,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function ScheduledRepTable:_init(path, default_header, subsetter)
    Base._init(self, path, default_header, subsetter)
end

function ScheduledRepTable:learn()
    -- updates subset, checks if it is empty
    if not Base.learn(self) then return false end

    -- subset not empty, must at least be a current scheduled rep.
    -- current scheduled rep not necessarily playing eg.
    -- if user navigates history
    local next_scheduled_rep = self.subset[2]
    local cur_scheduled_rep = self.subset[1]
    local playing_rep = active.queue.playing

    -- if the user navigates history then presses learn, it should
    -- take them to the current scheduled element.
    -- also, if the last current scheduled rep (before update_subset)
    -- was removed for being done, this will effectively load the
    -- next rep
    if (playing_rep.row["id"] ~= cur_scheduled_rep.row["id"]) then
        log.debug(
            "Currently playing is not currently scheduled. Loading currently scheduled.")
        return cur_scheduled_rep
    end

    table.remove(self.subset, 1)
    self:schedule(cur_scheduled_rep)

    local toload
    if not next_scheduled_rep then
        log.debug("No more repetitions!")
        sounds.play("negative")
    else
        if next_scheduled_rep:is_due() then
            toload = next_scheduled_rep
            log.debug("Loading the next scheduled repetition.")
        else
            log.debug("No more repetitions!")
            toload = nil
        end
    end

    self:write()
    return toload
end

function ScheduledRepTable:schedule(rep)
    -- add interval to current date to
    -- work out the next date of repetition
    local today = dt.date_today()
    local todayY, todayM, todayD = dt.parse_hhmmss(today)
    local interval = tonumber(rep.row["interval"])
    if not ivl.validate(interval) then interval = 1 end
    local afactor = tonumber(rep.row.afactor)
    if not af.validate(afactor) then afactor = 2 end

    -- works fine if day > no. of days in month.
    local next_rep_table = {
        year = tonumber(todayY),
        month = tonumber(todayM),
        day = tonumber(todayD) + interval
    }

    rep.row["interval"] = afactor * interval
    rep.row["nextrep"] = os.date("%Y-%m-%d", os.time(next_rep_table))
end

function ScheduledRepTable:as_rep(_) error("Need to override as_rep(row)!") end

return ScheduledRepTable
