local log = require "utils.log"
local mpu = require("mp.utils")
local ydl = require("systems.ydl")

local ext = require "utils.ext"
package.path = mp.command_native({"expand-path", "~~/script-modules/?.lua;"})..package.path
local ui = require "user-input-module"
local get_user_input = ui.get_user_input

local menu = {}

local menuBase

menu.keybinds = {
    { key = 'i', fn = function() menu.import() end },
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

function menu.add_osd(osd)
    osd:submenu("Import"):newline():newline()
    osd:item("i: import"):newline()
    osd:item("p: update playlist"):newline()
    osd:item("h: return home"):newline()
end

function menu.add_binds()
    menuBase = menuBase or require("systems.menu.menuBase")
    for _, val in pairs(menu.keybinds) do
        table.insert(menuBase.active_binds, val)
    end
end

function menu.import_file(file)
    log.notify("File: " .. file)
end

function menu.import_directory(folder)
    log.notify("Folder: " .. folder)
end

function menu.import_yt(url)
    log.notify("YT: " .. url)

    local split
    while split ~= "n" and split ~= "y" do
        get_user_input(function(input) split = input end,
            {
                text = "Split Chapters? (y/n): ",
                replace = true,
                default_input = "n"
            })
    end
end

function menu.handle_input(input)
    if ext.empty(input) then return end

    local url = input
    local fileinfo, _ = mpu.file_info(url)
    if fileinfo then
        if fileinfo["is_file"] then -- if file
            menu.import_file(url)
        elseif fileinfo["is_dir"] then  -- if directory
            menu.import_directory(url)
        end
    else
        menu.import_yt(url)
    end
end

function menu.import()
    get_user_input(function(input) menu.handle_input(input) end,
        {
            text = "Enter URL (file/folder/youtube link): ",
            replace = true
        })
end

return menu