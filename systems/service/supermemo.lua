local Base = require("system.service.base")
local log = require("utils.log")

local SuperMemo = {}
SuperMemo.__index = SuperMemo

setmetatable(SuperMemo, {
    __index = Base,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function SuperMemo:_init()
    log.debug("Initialising Obsidian service")
    Base._init()
end

function SuperMemo:get_concepts() end

return SuperMemo
