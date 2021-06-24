local ExtractQueueBase = require("queue.extractQueueBase")
local ScheduledExtractRepTable = require("reps.reptable.scheduledExtracts")
local sounds = require("systems.sounds")
local ext = require("utils.ext")
local log = require("utils.log")

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
                           ScheduledExtractRepTable(function(reps) return self:subsetter(reps) end)
                         )
end

function GlobalExtractQueue:activate()
    self:loadRep(self.reptable:current_scheduled(), self.oldRep)
    sounds.play("global_extract_queue")
end

function GlobalExtractQueue:subsetter(reps)
    local subset = {}
    for i, v in ipairs(reps) do
        subset[i] = v
    end
    return subset
end

return GlobalExtractQueue