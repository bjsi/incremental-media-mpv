local ExtractQueueBase = require 'queues.base.extracts'
local UnscheduledExtractRepTable = require 'reps.reptable.unscheduledExtracts'
local tbl = require 'utils.table'

local SingletonExtract = {}
SingletonExtract.__index = SingletonExtract

setmetatable(SingletonExtract, {
    __index = ExtractQueueBase,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

---Creates a singleton extract queue.
---@param id number id of the extract.
function SingletonExtract:_init(id)
    local reptable = UnscheduledExtractRepTable(function(reps)
        return self:subsetter(reps, id)
    end);
    ExtractQueueBase._init(self, "Singleton Extract Queue", nil, reptable)
end

function SingletonExtract:subsetter(reps, id)
    local predicate = function(r) return r.row.id == id end
    local extract = tbl.first(predicate, reps)
    return {[1] = extract}, extract
end

return SingletonExtract
