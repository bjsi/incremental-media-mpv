local menuBase
local active = require("systems.active")

local menu = {}

menu.keybinds = {
    { key = "d", fn = function() menu.activate_menu("el_data") end },
    { key = "i", fn = function() menu.activate_menu("items") end },
    { key = "t", fn = function() menu.activate_menu("topics") end },
    { key = "e", fn = function() menu.activate_menu("extracts") end},
    { key = "I", fn = function() menu.activate_menu("import") end},
}

function menu.activate_menu(m)
    menuBase = menuBase or require("systems.menu.menuBase")
    menuBase.state = m
    menuBase.remove_binds()
    menuBase.update()
end

function menu.activate(osd)
    menuBase = menuBase or require("systems.menu.menuBase")
    menu.add_osd(osd)
    menu.add_binds()
end

function menu.add_osd(osd)
    local queue = active.queue
    osd:submenu("Home"):newline()
    if queue ~= nil then
        osd:item(queue.name):newline()
        osd:item("Reps: "):text(#queue.reptable.subset):newline():newline()
    else
        osd:item("No queue loaded."):newline()
    end

    menuBase = menuBase or require("systems.menu.menuBase")
    osd:item("d: element data menu"):newline()
    osd:item("e: extract tools menu"):newline()
    osd:item("t: topic tools menu"):newline()
    osd:item("i: topic tools menu"):newline()
    osd:item("I: import menu"):newline()
end

function menu.add_binds()
    menuBase = menuBase or require("systems.menu.menuBase")
    for _, val in pairs(menu.keybinds) do
        table.insert(menuBase.active_binds, val)
    end
end

return menu