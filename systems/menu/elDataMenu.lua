local active = require "systems.active"
local menuBase


local menu = {}

menu.keybinds = {
    -- Priority
    { key = 'Up', fn = function() menu.adjust_priority(1) end },
    { key = 'Down', fn = function() menu.adjust_priority(-1) end },
    { key = 'Shift+Up', fn = function() menu.adjust_priority(5) end },
    { key = 'Shift+Down', fn = function() menu.adjust_priority(-5) end },

    -- Interval
    { key = 'Ctrl+Up', fn = function() menu.adjust_interval(1) end },
    { key = 'Ctrl+Down', fn = function() menu.adjust_interval(-1) end },

    -- A-Factor
    { key = 'Alt+Up', fn = function() menu.adjust_afactor(1) end },
    { key = 'Alt+Down', fn = function() menu.adjust_afactor(-1) end },

    -- Export
    { key = 'e', fn = function() menu.toggle_export() end },

    -- Dismiss
    { key = 'd', fn = function() menu.toggle_dismiss() end },

    -- Menu 
    { key = "h", fn = function() menu.go_home() end },
}

function menu.go_home()
    menuBase = menuBase or require("systems.menu.menuBase")
    menuBase.state = "home"
    menuBase.remove_binds()
    menuBase.update()
end

function menu.activate(osd)
    menuBase = menuBase or require("systems.menu.menuBase")
    menu.add_osd(osd)
    menu.add_binds()
end

function menu.add_binds()
    menuBase = menuBase or require("systems.menu.menuBase")
    for _, val in pairs(menu.keybinds) do
        table.insert(menuBase.active_binds, val)
    end
end

menu.adjust_priority = function(n)
    local queue = active.queue
    if queue == nil then return end
    queue:adjust_priority(n)
end

menu.adjust_interval = function(n)
    local queue = active.queue
    if queue == nil then return end
    queue:adjust_interval(n)
end

menu.adjust_afactor = function(n)
    local queue = active.queue
    if queue == nil then return end
    queue:adjust_afactor(n)
end

function menu.add_osd(osd)

    if not active.queue then
        osd:item("No queue loaded."):newline()
        return
    end

    local cur = active.queue.playing
    if not cur then
        osd:item("No current element."):newline()
    end

    osd:item('Priority: '):text(tostring(cur.row["priority"])):newline()
    osd:item("Dismissed?: "):text(tostring(cur:is_dismissed())):newline()
    if cur:type() == "topic" or cur:type() == "extract" then
        osd:item("Interval: "):text(cur.row["interval"]):newline()
        osd:item("A-Factor: "):text(cur.row["afactor"]):newline():newline()
    end

    if cur:type() == "extract" or cur:type() == "item" then
        osd:item("To Export?"):text(tostring(cur:to_export())):newline()
    end

    menuBase = menuBase or require("systems.menu.menuBase")

    if menuBase.show_bindings then
        osd:submenu('Bindings'):newline()
        osd:tab():italics("Priority"):newline()
        osd:tab():item('up: '):text('increase '):italics("+shift big increase"):newline()
        osd:tab():item('down: '):text('decrease '):italics("+shift big decrease"):newline():newline()

        osd:tab():italics("Interval"):newline()
        osd:tab():item('ctrl+up: '):text('increase '):newline()
        osd:tab():item('ctrl+down: '):text('decrease '):newline():newline()

        osd:tab():italics("A-Factor"):newline()
        osd:tab():item('alt+up: '):text('increase '):newline()
        osd:tab():item('alt+down: '):text('decrease '):newline():newline()

        osd:tab():item('ESC: '):text('close'):newline()

        osd:italics("Press "):item('b'):italics(" to hide menu bindings."):newline()
    else
        osd:italics("Press "):item('b'):italics(" to show menu bindings."):newline()
    end
end

return menu