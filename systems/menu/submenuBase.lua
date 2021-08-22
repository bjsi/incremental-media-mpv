local menuBase = require("systems.menu.menuBase")

local SubmenuBase = {}
SubmenuBase.__index = SubmenuBase

setmetatable(SubmenuBase, {
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function SubmenuBase:_init() end

function SubmenuBase:activate_menu(m)
    menuBase.state = m
    menuBase.remove_binds()
    menuBase.update()
end

function SubmenuBase:activate(osd)
    self:add_osd(osd)
    self:add_binds()
end

function SubmenuBase:add_binds()
    for _, val in pairs(self.keybinds) do
        table.insert(menuBase.active_binds, val)
    end
end

return SubmenuBase
