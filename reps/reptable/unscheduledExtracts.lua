local fs = require("systems.fs")
local ExtractRep = require("reps.rep.extract")
local defaultHeader = require("reps.reptable.extract_header")
local UnscheduledRepTable = require("reps.reptable.unscheduled")

local UnscheduledExtractRepTable = {}
UnscheduledExtractRepTable.__index = UnscheduledExtractRepTable

setmetatable(UnscheduledExtractRepTable, {
    __index = UnscheduledRepTable,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function UnscheduledExtractRepTable:_init(subsetter)
    UnscheduledRepTable._init(self, fs.extracts_data, defaultHeader, subsetter)
    self:read_reps()
end

function UnscheduledExtractRepTable:as_rep(row)
    return ExtractRep(row)
end

return UnscheduledExtractRepTable
