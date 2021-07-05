local Base = require("reps.reptable.base")
local Scheduler = require("reps.scheduler")
local ext = require("utils.ext")
local sounds = require("systems.sounds")
local log = require("utils.log")
local active = require("systems.active")
local sort = require "reps.reptable.sort"

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

    -- Base:next_repetition(self) -- Not working for some reason

    self:update_subset()

    if ext.empty(self.subset) then
        log.debug("Subset is empty. No more repetitions!")
        sounds.play("negative")
        return
    end

    local curSchedRep = self:current_scheduled()
    local nextSchedRep = self:get_next_rep()
    local curPlayRep = active.queue.playing

    -- not due; don't schedule or load
    if curSchedRep and not curSchedRep:is_due() then
        log.debug("CurRep is not due. No more repetitions!")
        sounds.play("negative")
        return
    end

    if curPlayRep.row["id"] ~= curSchedRep.row["id"] then
        log.debug("Currently playing is not currently scheduled. Loading currently scheduled.")
        return curSchedRep
    end

    self:remove_current()
    self:schedule(curPlayRep)

    local toload = nil

    if curSchedRep and not nextSchedRep then
        toload = nil
        log.debug("No more repetitions!")
        sounds.play("negative")
    elseif curSchedRep and nextSchedRep then
        if nextSchedRep:is_due() then
            toload = nextSchedRep
            log.debug("Loading the next scheduled repetition.")
        else
            log.debug("No more repetitions!")
            toload = nil
        end
    end

    self:update_subset()
    self:write()

    return toload
end

function ScheduledRepTable:schedule(rep)
    local sched = Scheduler()
    sched:schedule(self, rep)
end

function ScheduledRepTable:sort()
    sort.by_priority(self.subset)
    sort.by_due(self.subset)
end

--- Takes a row and returns a Rep object. Override me!
--- @param row table
--- @return Rep
function ScheduledRepTable:as_rep(row)
    error("Need to override as_rep(row)!")
end

return ScheduledRepTable
