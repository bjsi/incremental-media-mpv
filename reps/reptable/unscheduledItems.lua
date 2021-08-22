local UnscheduledRepTable = require("reps.reptable.unscheduled")
local fs = require("systems.fs")
local ItemRep = require("reps.rep.item")
local defaultHeader = require("reps.reptable.item_header")

local ItemRepTable = {}
ItemRepTable.__index = ItemRepTable

setmetatable(ItemRepTable, {
    __index = UnscheduledRepTable,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function ItemRepTable:_init(subsetter)
    UnscheduledRepTable._init(self, fs.items_data, defaultHeader, subsetter)
    self:read_reps()
end

function ItemRepTable:as_rep(row) return ItemRep(row) end

return ItemRepTable
