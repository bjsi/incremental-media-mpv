local fs = require("systems.fs")
local default_header = require("reps.reptable.extract_header")
local ScheduledRepTable = require("reps.reptable.scheduled")
local ExtractRep = require("reps.rep.extract")

local ScheduledExtractRepTable = {}
ScheduledExtractRepTable.__index = ScheduledExtractRepTable

setmetatable(ScheduledExtractRepTable, {
    __index = ScheduledRepTable,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function ScheduledExtractRepTable:_init(subsetter)
    ScheduledRepTable._init(self, fs.extracts_data, default_header, subsetter)
end

function ScheduledRepTable:as_rep(row) return ExtractRep(row) end

return ScheduledExtractRepTable
