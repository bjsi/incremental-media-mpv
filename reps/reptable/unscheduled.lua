local Base = require("reps.reptable.base")
local ext = require("utils.ext")
local sounds = require("systems.sounds")
local active = require("systems.active")
local log = require("utils.log")


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

-- noop
function UnscheduledRepTable:sort(reps)
end

function UnscheduledRepTable:next_repetition()
    -- Base:next_repetition(self)
    self:update_subset()

    if ext.empty(self.subset) then
        log.debug("Subset is empty. No more repetitions!")
        sounds.play("negative")
        return
    end

    local curRep = self:current_scheduled()
    if active.queue.playing ~= curRep then
        log.debug("Currently playing is not currently scheduled. Loading currently scheduled.")
        return curRep
    end

    local nextRep = self:get_next_rep()
    if not nextRep then
        log.debug("No more repetitions!")
        sounds.play("negative")
        return
    end

    table.remove(self.subset, 1)
    table.insert(self.subset, curRep)
    self:write()
    log.debug("Loading the next scheduled repetition...")
    return nextRep
end

return UnscheduledRepTable