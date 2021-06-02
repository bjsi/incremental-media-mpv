local Base = require("reps.reptable.base")
local fs = require("systems.fs")
local log = require("utils.log")
local ExtractRep = require("reps.rep.extracts")

-- TODO: add id
-- TODO: add parent
local default_header = {
    [1]="title",
    [2]="type",
    [3]="url",
    [4]="start",
    [5]="stop",
    [6]="priority",
    [7]="interval",
    [8]="nextrep",
    [9]="speed",
}

local ExtractRepTable = {}
ExtractRepTable.__index = ExtractRepTable

setmetatable(ExtractRepTable, {
    __index = Base,
    __call = function(cls, ...)
            local self = setmetatable({}, cls)
            self:_init(...)
            return self
        end,
    })

function ExtractRepTable:_init()
    Base._init(self, fs.topic_data, default_header)
    self:read_reps()
end

function ExtractRepTable:sort()
    self:sort_by_priority()
    self:sort_by_due()
end

function ExtractRepTable:sort_by_due()
    local srt = function(a, b)
        return a:is_due() and not b:is_due()
    end
    table.sort(self.reps, srt)
end

function ExtractRepTable:read_reps()
    log.debug("Reading topic reps.")
    local header, reps = self.db:read_reps(function(row) return ExtractRep(row) end)
    self.reps = reps and reps or {}
    self.header = header and header or default_header
    self:sort()
end

return ExtractRepTable
