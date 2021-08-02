local log = require("utils.log")
local mpu = require("mp.utils")
local exporter = require("systems.exporter")
local importer = require("systems.importer")
local mpopt = require("mp.options")
local active = require("systems.active")
local sys = require("systems.system")
local GlobalTopicQueue = require("queue.globalTopicQueue")
local GlobalExtractQueue = require("queue.globalExtractQueue")
local GlobalItemQueue = require("queue.globalItemQueue")
local player = require("systems.player")
local ext = require("utils.ext")
local sounds = require "systems.sounds"
local fs = require "systems.fs"
local menuBase = require "systems.menu.menuBase"

local settings = {
    ["start"] = false,
    ["import"] = "",
    ["queue"] = "main",
    ["mode"] = "master",
    ["export"] = "",
}

mpopt.read_options(settings, "im")

local loaded = false

local function getInitialQueue()
    local gt = GlobalTopicQueue(nil)
    if gt and not ext.empty(gt.reptable.subset) then return gt end
    local ge = GlobalExtractQueue(nil)
    if ge and not ext.empty(ge.reptable.subset) then return ge end
    local gi = GlobalItemQueue(nil)
    if gi and not ext.empty(gi.reptable.subset) then return gi end
end

local function loadMedia()
    log.debug("Loading Media")

    sys.set_ipc_socket()
    if not mp.get_property_bool("audio-only") then
        mp.set_property("force-window", "yes")
    end

    mp.observe_property("time-pos", "number", player.loop_timer.check_loop)
    mp.set_property("loop", "inf")

    local queue = getInitialQueue()
    if not queue or ext.empty(queue.reptable.subset) then
        log.debug("No repetitions available. Creating empty topic queue...")
        queue = GlobalTopicQueue(nil)
    end

    if not active.change_queue(queue) then
        menuBase.open()
    end
end

local function run()
    if not loaded then
        loaded = true

        log.debug("Queue: ", fs.data)

        sys.verify_dependencies()
        sys.create_essential_files()
        sys.backup()

        sounds.start_background_process()
        mp.register_script_message("export_to_sm", function(time) exporter.export_to_sm(time) end)
        mp.register_event("shutdown", active.on_shutdown)

        if not ext.empty(settings["import"]) then
            local importTarget = settings["import"]
            local ret = importer.import(importTarget)
            log.debug("Exiting after import....")
            local sound = ret and "positive" or "negative"
            sounds.play_sync(sound)
            mp.commandv("quit", ret and 0 or 1)

        elseif not ext.empty(settings["export"]) then
            local exportFolder = settings["export"]
            local ret = exporter.as_sm_xml(exportFolder)
            log.debug("Exiting after export...")
            local sound = ret and "positive" or "negative"
            sounds.play_sync(sound)
            mp.commandv("quit", ret and 0 or 1)
        else
            require("systems.keybinds")
            loadMedia()
        end
    end
end

-- Only allows one instance of the script to
-- run for each queue.

local pid_file = mpu.join_path(fs.data, "pid_file")

local read_pid_file = function()
    local h = io.open(pid_file, "r")
    if h == nil then return -1 end
    local pid = h:read("*all")
    h:close()
    return pid
end

local write_pid_file = function()
    local h = io.open(pid_file, "w")
    if h == nil then return end
    h:write(mpu.getpid())
    h:close()
end

local delete_pid_file = function()
    log.debug("Removing PID file.")
    os.remove(pid_file)
end


if settings["start"] or not ext.empty(settings["import"]) or not ext.empty(settings["export"]) then
    local pid = read_pid_file()
    if pid ~= -1 and sys.pid_running(pid) then
        log.debug("Already running with PID: ", pid, ". Exiting.")
        mp.commandv("quit", 65)
    else
        write_pid_file()
        mp.register_event("shutdown", delete_pid_file)
        run()
    end
end