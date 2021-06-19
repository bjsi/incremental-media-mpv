local Base = require("reps.reptable.base")
local Scheduler = require("reps.scheduler")
local ext = require("utils.ext")
local sounds = require("systems.sounds")
local log = require("utils.log")
local default_header = require("reps.reptable.topic_header")
local active = require("systems.active")

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

function ScheduledRepTable:_init(dbPath, defaultHeader, subsetter)
    Base._init(self, dbPath, defaultHeader, subsetter)
    self:read_reps()
end

function ScheduledRepTable:next_repetition()
    if ext.empty(self.subset) then
        log.debug("No more repetitions!")
        sounds.play("negative")
        return
    end

    local curRep = self:current_scheduled()
    -- not due; don't schedule or load
    if curRep ~= nil and not curRep:is_due() then
        log.debug("No more repetitions!")
        sounds.play("negative")
        return
    end

    if active.queue.playing ~= curRep then
        log.debug("Currently playing is not currently scheduled. Loading currently scheduled.")
        return curRep
    end

    local nextRep = self:get_next_rep()

    self:remove_current()
    local sched = Scheduler()
    sched:schedule(self, curRep)
    local toload = nil

    if curRep ~= nil and nextRep == nil then
        toload = curRep
        log.debug("No more repetitions!")
        sounds.play("negative")
    elseif curRep ~= nil and nextRep ~= nil then
        if nextRep:is_due() then
            log.debug("Next rep is due. Loading the next scheduled repetition...")
            toload = nextRep
        else
            log.debug("Next rep is not due. Loading the current repetition...")
            toload = curRep
        end
    end

    self:write()
    return toload
end

function ScheduledRepTable:sort()
    self:sort_by_priority()
    self:sort_by_due()
end

function ScheduledRepTable:sort_by_due()
    local srt = function(a, b) return a:is_due() and not b:is_due() end
    table.sort(self.reps, srt)
end

--- Takes a row and returns a Rep object. Override me!
--- @param row table
--- @return Rep
function ScheduledRepTable:as_rep(row)
    error("Need to override as_rep(row)!")
end

return ScheduledRepTable
