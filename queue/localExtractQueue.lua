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
    if ExtractQueueBase.activate(self) then
        sounds.play("local_extract_queue")
        return true
    end
    return false
end

function LocalExtractQueue:subsetter(oldRep, reps)    
    local subset = {}
    for i, v in ipairs(reps) do
        subset[i] = v
    end
    
    local getFst = function(reps) return reps[1] end
    local filter = function(r) return r end

    if (oldRep ~= nil) and (oldRep:type() == "topic") then

        -- Get all extracts that are children of the current topic
        filter = function (r) return r:is_child_of(oldRep) end
        
    elseif (oldRep ~= nil) and (oldRep:type() == "item") then

        -- Get all extracts where the topic == the item's grandparent
        -- TODO: what if nil
        local parent = ext.first_or_nil(function(r) r:is_parent_of(oldRep) end, reps)
        filter = function (r)
            return r.row["parent"] == parent.row["parent"]
        end
    end

    subset = ext.list_filter(subset, filter)
    return subset, getFst(subset) -- TODO: should be reps or subset?
end

return LocalExtractQueue