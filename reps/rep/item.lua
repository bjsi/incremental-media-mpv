local Base = require("reps.rep.base")

local ItemRep = {}
ItemRep.__index = ItemRep

setmetatable(ItemRep, {
    __index = Base,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function ItemRep:type() return "item" end

function ItemRep:_init(row) Base._init(self, row) end

function ItemRep:is_child_of(extract) 
    return (self.row["parent"] == extract.row["id"])
end

function ItemRep:is_parent_of(_)
    return false
end

return ItemRep