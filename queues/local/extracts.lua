local ExtractQueueBase = require 'queues.base.extracts'
local tbl = require 'utils.table'
local sort = require 'reps.reptable.sort'
local UnscheduledExtractRepTable = require 'reps.reptable.unscheduledExtracts'
local sounds = require 'systems.sounds'

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
    self.sorted = false
    ExtractQueueBase._init(self, "Local Extract Queue", oldRep,
                           UnscheduledExtractRepTable(function(reps)
        return self:subsetter(oldRep, reps)
    end))
end

function LocalExtractQueue:activate()
    if ExtractQueueBase.activate(self) then
        sounds.play("local_extract_queue")
        return true
    end
    return false
end

function LocalExtractQueue:subsetter(oldRep, reps)
    local subset = tbl.filter(reps,
                              function(r) return r:is_outstanding(false) end)
    local from_topics = (oldRep ~= nil) and (oldRep:type() == "topic")
    local from_items = (oldRep ~= nil) and (oldRep:type() == "item")
    local from_nil = oldRep == nil
    local filter

    -- Filtering subset

    if from_topics then

        -- Get all extracts that are children of the current topic
        filter = function(r) return r:is_child_of(oldRep) end

    elseif from_items then

        -- Get all extracts where the topic == the item's grandparent
        -- TODO: what if nil
        local predicate = function(r) return r:is_parent_of(oldRep) end
        local parent = tbl.first(predicate, reps)
        filter = function(r)
            return r.row["parent"] == parent.row["parent"]
        end

    elseif from_nil then
        filter = function(r) return r end
    end

    subset = tbl.filter(subset, filter)
    sort.by_created(subset)

    -- Determining first element
    if from_items then
        local pred = function(extract) return oldRep:is_child_of(extract) end
        tbl.move_to_first_where(pred, subset)
    end

    return subset, subset[1]
end

return LocalExtractQueue
