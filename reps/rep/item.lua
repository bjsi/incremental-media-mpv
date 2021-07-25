local Base = require("reps.rep.base")
local ClozeContextEDL = require("systems.edl.clozeContextEdl")
local item_format = require("reps.rep.item_format")
local player = require("systems.player")

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


function ItemRep:_init(row) Base._init(self, row) end

function ItemRep:is_outstanding()
    return not self:is_deleted() and not self:is_dismissed()
end

function ItemRep:type() return "item" end

function ItemRep:is_child_of(extract) 
    return (self.row["parent"] == extract.row["id"])
end

function ItemRep:is_parent_of(_)
    return false
end

-- TODO: dirty hack
function ItemRep:duration()
    if self.row.format ~= item_format.cloze_context then
        return Base.duration(self)
    else
        local edl = ClozeContextEDL.new(player.get_full_url(self))
        local sound, format, _ = edl:read()
        return 0.8 + (sound["stop"] - sound["start"]) + (format["cloze-stop"] - format["cloze-start"])
    end
end

return ItemRep