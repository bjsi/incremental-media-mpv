local ExtractQueueBase = require 'queues.base.extracts'
local sort = require 'reps.reptable.sort'
local ScheduledExtractRepTable = require 'reps.reptable.scheduledExtracts'
local sounds = require 'systems.sounds'
local tbl = require 'utils.table'

local GlobalExtracts = {}
GlobalExtracts.__index = GlobalExtracts

setmetatable(GlobalExtracts, {
    __index = ExtractQueueBase,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

--- Create a new GlobalTopicQueue.
--- @param oldRep Rep last playing Rep object.
function GlobalExtracts:_init(oldRep)
    ExtractQueueBase._init(self, "Global Extract Queue", oldRep,
                           ScheduledExtractRepTable(
                               function(reps) return self:subsetter(reps) end))
end

function GlobalExtracts:activate()
    if ExtractQueueBase.activate(self) then
        sounds.play("global_extract_queue")
        return true
    end
    return false
end

function GlobalExtracts:subsetter(reps)
    local predicate = function(rep) return rep:is_outstanding(true) end
    local subset = tbl.filter(reps, predicate)
    sort.by_priority(subset)
    sort.by_due(subset)
    return subset, subset[1]
end

return GlobalExtracts
