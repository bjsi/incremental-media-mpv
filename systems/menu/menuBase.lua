local log = require "utils.log"
local ext = require "utils.ext"
local cfg = require "systems.config"
local OSD = require('systems.osd_styler')

-- Based on: https://github.com/Ajatt-Tools/mpvacious/blob/master/subs2srs.lua

local home
local import
local subset
local queue

local menu = {
    active = false,
    state = 'home',
    show_bindings = false,
    overlay = mp.create_osd_overlay and mp.create_osd_overlay('ass-events'),
}

menu.overlay_draw = function(text)
    menu.overlay.data = text
    menu.overlay:update()
end

menu.base_binds = {
    { key = 'ESC', desc = "close menu", fn = function() menu.close() end },
    { key = 'H', showif = function() return menu.state ~= "home" end, desc = "home menu", fn = function() menu.activate_menu("home") end },
    { key = "I", showif = function() return menu.state ~= "import" end, desc = "import menu", fn = function() menu.activate_menu("import") end},
    { key = "Alt+c", showif = function() return menu.start ~= "queue" end, desc = "queue menu", fn = function() menu.activate_menu("queue") end},
}

menu.active_binds = {}

ext.table_copy(menu.base_binds, menu.active_binds)

menu.update = function()

    if menu.active == false then
        return
    end

    local osd = OSD:new():size(cfg.menu_font_size):align(4)

    local submenu
    if menu.state == "home" then
        submenu = home or require("systems.menu.homeMenu")
    elseif menu.state == "import" then
        submenu = import or require("systems.menu.importMenu")
    elseif menu.state == "subset" then
        submenu = subset or require("systems.menu.subsetMenu")
    elseif menu.state == "queue" then
        submenu = queue or require("systems.menu.queueMenu")
    end

    menu.reset_binds_to_base()
    local sub = submenu()

    if menu.state == "queue" then
        menu.close()
        return
    end

    sub:activate(osd)
    menu.add_binds()
    menu.add_binds_osd(osd)
    menu.overlay_draw(osd:get_text())
end

function menu.activate_menu(m)
    log.debug("Changing menu state to " .. m)
    menu.state = m
    menu.remove_binds()
    menu.update()
end

menu.open = function()
    if menu.overlay == nil then
        log.notify("OSD overlay is not supported in " .. mp.get_property("mpv-version"), "error", 5)
        return
    end

    if menu.active == true then
        menu.close()
        return
    end

    menu.add_binds()
    menu.active = true
    menu.update()
end

menu.add_binds_osd = function(osd)
    osd:submenu("Commands"):newline()
    for _, val in pairs(menu.active_binds) do
        if not val.showif or (val.showif and val.showif()) then
            osd:tab():item(val.key .. ": "):italics(val.desc):newline()
        end
    end
end

menu.remove_binds = function()
    for _, val in pairs(menu.active_binds) do
        mp.remove_key_binding(val.key)
    end
end

menu.reset_binds_to_base = function()
    menu.remove_binds()
    menu.active_binds = {}
    ext.table_copy(menu.base_binds, menu.active_binds)
    menu.add_binds()
end

menu.add_binds = function()
    for _, val in pairs(menu.active_binds) do
        mp.add_forced_key_binding(val.key, val.key, val.fn)
    end
end

menu.close = function()
    if menu.active == false then
        return
    end

    menu.state = "home"
    menu.remove_binds()
    menu.overlay:remove()
    menu.active = false
    menu.show_bindings = false
end

return menu