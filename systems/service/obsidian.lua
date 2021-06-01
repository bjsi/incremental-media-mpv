local Base = require("system.service.base")
local log = require("utils.log")

local Obsidian = {}
Obsidian.__index = Obsidian

setmetatable(Obsidian, {
    __index = Base,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end,
})

function Obsidian:_init()
    log.debug("Initialising Obsidian service")
    Base._init()
end

return Obsidian
