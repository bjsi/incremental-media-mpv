local Base = require("reps.rep.base")

local ExtractRep = {}
ExtractRep.__index = ExtractRep

setmetatable(ExtractRep, {
    __index = Base,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function ExtractRep:_init(row) Base._init(self, row) end

function ExtractRep:is_child_of(topic) 
    return (self.row["parent"] == topic.row["id"])
end

function ExtractRep:is_parent_of(item)
    return (self.row["id"] == item.row["parent"])
end
