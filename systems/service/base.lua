local log = require("utils.log")
local cfg = require("systems.cfg")
local curl = require("systems.curl")

local Base = {}
Base.__index = Base

setmetatable(Base, {
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end,
})

function Base:_init(name)
    log.debug("Initialising service: " .. name)
end
