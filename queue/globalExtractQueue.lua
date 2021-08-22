local ExtractQueueBase = require("queue.extractQueueBase")
local sort = require("reps.reptable.sort")
local ScheduledExtractRepTable = require("reps.reptable.scheduledExtracts")
local sounds = require("systems.sounds")
local ext = require "utils.ext"

local GlobalExtractQueue = {}
GlobalExtractQueue.__index = GlobalExtractQueue

setmetatable(GlobalExtractQueue, {
    __index = ExtractQueueBase,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

--- Create a new GlobalTopicQueue.
--- @param oldRep Rep last playing Rep object.
function GlobalExtractQueue:_init(oldRep)
    ExtractQueueBase._init(self, "Global Extract Queue", oldRep,
                           ScheduledExtractRepTable(
                               function(reps) return self:subsetter(reps) end))
end

function GlobalExtractQueue:activate()
    if ExtractQueueBase.activate(self) then
        sounds.play("global_extract_queue")
        return true
    end
    return false
end

function GlobalExtractQueue:subsetter(reps)
    local subset = ext.list_filter(reps, function(r)
        return r:is_outstanding(true)
    end)
    sort.by_priority(subset)
    return subset, subset[1]
end

return GlobalExtractQueue
