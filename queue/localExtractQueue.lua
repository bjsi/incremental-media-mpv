local ExtractQueueBase = require("queue.extractQueueBase")
local UnscheduledExtractRepTable = require("reps.reptable.unscheduledExtracts")
local sounds = require("systems.sounds")
local ext = require("utils.ext")
local log = require "utils.log"

local LocalExtractQueue = {}
LocalExtractQueue.__index = LocalExtractQueue

setmetatable(LocalExtractQueue, {
    __index = ExtractQueueBase,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

--- Create a new GlobalTopicQueue.
--- @param oldRep Rep last playing Rep object.
function LocalExtractQueue:_init(oldRep)
    ExtractQueueBase._init(self, "Local Extract Queue", oldRep,
                           UnscheduledExtractRepTable(function(reps) return self:subsetter(oldRep, reps) end)
                         )
end

function LocalExtractQueue:activate()
    self:loadRep(self.reptable:current_scheduled(), self.oldRep)
    sounds.play("local_extract_queue")
end

function LocalExtractQueue:subsetter(oldRep, reps)    
    local subset = {}
    for i, v in ipairs(reps) do
        subset[i] = v
    end
    return ext.list_filter(subset, function(r) return r:is_child_of(oldRep) end)
end

return LocalExtractQueue