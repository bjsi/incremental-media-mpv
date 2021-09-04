local Base = require 'reps.reptable.base'
local sort = require 'reps.reptable.sort'
local sounds = require 'systems.sounds'
local active = require 'systems.active'
local log = require 'utils.log'

local UnscheduledRepTable = {}
UnscheduledRepTable.__index = UnscheduledRepTable

setmetatable(UnscheduledRepTable, {
    __index = Base,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function UnscheduledRepTable:_init(dbPath, defaultHeader, subsetter)
    Base._init(self, dbPath, defaultHeader, subsetter)
end

function UnscheduledRepTable:learn()
    if not Base.learn(self) then return false end

    sort.by_priority(self.subset)

    local cur_scheduled_rep = self.subset[1]
    local next_scheduled_rep = self.subset[2]
    local playing_rep = active.queue.playing

    if playing_rep.row.id ~= cur_scheduled_rep.row.id then
        log.debug(
            "Currently playing is not currently scheduled. Loading currently scheduled.")
        return cur_scheduled_rep
    end

    if not next_scheduled_rep then
        log.debug("No more repetitions!")
        sounds.play("negative")
        return
    end

    table.remove(self.subset, 1)
    table.insert(self.subset, cur_scheduled_rep)

    self:write()
    return next_scheduled_rep
end

return UnscheduledRepTable
