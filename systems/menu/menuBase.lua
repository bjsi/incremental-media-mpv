local log = require "utils.log"
local cfg = require "systems.config"
local OSD = require('systems.osd_styler')

-- Based on: https://github.com/Ajatt-Tools/mpvacious/blob/master/subs2srs.lua

local el_data
local home
local import

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
    { key = 'ESC', fn = function() menu.close() end },
    { key = 'h', fn = function() menu.activate_menu("home") end },
}

menu.active_binds = menu.base_binds

menu.update = function()
    if menu.active == false then
        return
    end

    local osd = OSD:new():size(cfg.menu_font_size):align(4)

    local submenu
    if menu.state == 'el_data' then
        submenu = el_data or require("systems.menu.elDataMenu")
    elseif menu.state == "home" then
        submenu = home or require("systems.menu.homeMenu")
    elseif menu.state == "import" then
        submenu = import or require("systems.menu.importMenu")
    end

    submenu.activate(osd)
    menu.add_binds()
    menu.overlay_draw(osd:get_text())
end

function menu.activate_menu(m)
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

menu.remove_binds = function()
    for _, val in pairs(menu.active_binds) do
        mp.remove_key_binding(val.key)
    end
end

menu.reset_binds_to_base = function()
    menu.remove_binds()
    menu.active_binds = menu.base_binds
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

    menu.remove_binds()

    menu.overlay:remove()
    menu.active = false
end

return menu