local log = require "utils.log"
local mpu = require("mp.utils")
local Base = require("systems.menu.submenuBase")
local ydl = require("systems.ydl")
local importer = require("systems.importer")
local sounds = require("systems.sounds")

local ext = require "utils.ext"
package.path = mp.command_native({"expand-path", "~~/script-modules/?.lua;"}) ..
                   package.path
local ui = require "user-input-module"
local get_user_input = ui.get_user_input

local ImportSubmenu = {}
ImportSubmenu.__index = ImportSubmenu

setmetatable(ImportSubmenu, {
    __index = Base,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function ImportSubmenu:_init()
    Base._init(self)
    -- osd:tab():item("i: "):italics("import videos / playlists"):newline()
    -- osd:tab():item("p: "):italics("update playlists"):newline()

    self.keybinds = {
        {
            key = 'i',
            desc = "import video / playlist",
            fn = function() self:query_import() end
        }, {
            key = 'p',
            desc = "update playlists",
            fn = function() self:query_update_playlists() end
        }
    }

    self.yt_chain = {
        function(args, chain, idx) self:query_download(args, chain, idx) end,
        function(args, chain, idx)
            self:query_split_chapters(args, chain, idx)
        end,
        function(args, chain, idx)
            self:query_priority_yt(args, chain, idx)
        end, function(args, chain, idx)
            self:query_confirm(args, chain, idx)
        end
    }
end

function ImportSubmenu:query_priority_yt(args, chain, i)
    if #args["infos"] > 1 then
        self:query_priority_range(args, chain, i)
    else
        self:query_priority_single(args, chain, i)
    end
end

function ImportSubmenu:query_update_playlists() log.notify("TODO") end

function ImportSubmenu:query_priority_single(args, chain, i)
    local handler = function(input)
        local p = tonumber(input)
        if not ext.validate_priority(p) then
            log.notify("Invalid input.")
        else
            args["priority-min"] = p
            args["priority-max"] = p
            i = i + 1
        end

        self:call_chain(args, chain, i)
    end

    get_user_input(handler, {text = "Priority (0-100): ", replace = true})
end

function ImportSubmenu:query_download(args, chain, i)
    local handler = function(input)
        if input == nil then log.notify("Cancelling.") end

        if input == "y" then
            args["download"] = true
            i = i + 1
        elseif input == "n" or input == "" then
            args["download"] = false
            i = i + 1
        else
            log.notify("Invalid input.")
        end

        self:call_chain(args, chain, i)
    end

    get_user_input(handler,
                   {text = "Localize YouTube video? (y/[n]): ", replace = true})
end

function ImportSubmenu:import_yt(url)
    log.notify("Grabbing YouTube info.")
    local infos = ydl.get_info(url)
    if infos == nil then
        log.notify("Failed to download YouTube info.")
        return
    end

    local type = #infos > 1 and "Playlist" or "Video"
    log.notify(type .. " info found.")
    local args = {url = url, infos = infos}
    self:call_chain(args, self.yt_chain, 1)
end

function ImportSubmenu:query_confirm(args, chain, i)
    local handle = function(input)
        if input == nil or input == "n" then
            log.notify("Cancelling.")
            return
        elseif input == "y" or input == "" then
            log.debug(args)
            log.notify("Importing.")
        else
            log.notify("Invalid input.")
            self:call_chain(args, chain, i)
            return
        end

        local topics = importer.create_yt_topics(args["infos"],
                                                 args["split-chapters"],
                                                 args["download"],
                                                 args["priority-min"],
                                                 args["priority-max"], true -- TODO: dependencyImport
        )

        if ext.empty(topics) then
            log.notify("Failed to create topics.")
            return
        end

        if importer.add_topics_to_queue(topics) then
            sounds.play("positive")
        else
            sounds.play("negative")
        end
    end

    get_user_input(handle, {text = "Confirm? ([y]/n):", replace = true})
end

function ImportSubmenu:add_osd(osd)
    osd:submenu("Import Menu"):newline():newline()
end

function ImportSubmenu:import_file(file) log.notify("File: " .. file) end

function ImportSubmenu:import_directory(folder) log.notify("Folder: " .. folder) end

function ImportSubmenu:call_chain(args, chain, i)
    if chain ~= nil and i <= #chain then
        chain[i](args, chain, i)
    else
        log.debug("End of chain: ", args)
    end
end

function ImportSubmenu:query_interval(args, chain, i)
    local handle = function(input)
        if input == nil then return end

        local n = tonumber(input)
        if n ~= nil and ext.validate_interval(n) then
            args["interval"] = n
            self:call_chain(args, chain, i + 1)
        else
            self:call_chain(args, chain, i)
            log.notify("Invalid interval.")
        end
    end

    get_user_input(handle, {text = "Interval: ", replace = true})
end

function ImportSubmenu:query_priority_range(args, chain, i)

    local handle = function(input)
        if input == nil then return end

        local min, max = input:gmatch("(%d+)%s*-%s*(%d+)")()
        min = tonumber(min)
        max = tonumber(max)

        if not ext.validate_priority(min) or not ext.validate_priority(max) or
            min > max then
            log.notify("Invalid priority range.")
            self:call_chain(args, chain, i)
            return
        end

        args["priority-min"] = min
        args["priority-max"] = max

        self:call_chain(args, chain, i + 1)
    end

    get_user_input(handle,
                   {text = "Priority range (eg. 5-30): ", replace = true})
end

function ImportSubmenu:query_split_chapters(args, chain, i)
    local handle = function(input)
        if input == nil then return end

        if input == "n" or input == "" then
            args["split-chapters"] = false
        elseif input == "y" then
            args["split-chapters"] = true
        else
            log.notify("Invalid input.")
            self:call_chain(args, chain, i)
            return
        end

        self:call_chain(args, chain, i + 1)
    end

    get_user_input(handle, {
        text = "Split video chapters if available? (y/[n]): ",
        replace = true
    })
end

function ImportSubmenu:query_import()
    local handle = function(input)
        if ext.empty(input) then return end

        local fileinfo, _ = mpu.file_info(input)
        if fileinfo then
            if fileinfo["is_file"] then -- if file
                self:import_file(input)
            elseif fileinfo["is_dir"] then -- if directory
                self:import_directory(input)
            end
        else
            self:import_yt(input)
        end
    end

    get_user_input(function(input) handle(input) end, {
        text = "Enter a file, folder or youtube link: ",
        replace = true
    })
end

return ImportSubmenu
