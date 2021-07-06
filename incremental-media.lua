local log = require("utils.log")
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

local settings = {
    ["start"] = false,
    ["import"] = "",
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
    mp.set_property("force-window", "yes")
    mp.observe_property("time-pos", "number", player.loop_timer.check_loop)
    mp.set_property("loop", "inf")
    local queue = getInitialQueue()
    if not queue or ext.empty(queue.reptable.subset) then
        log.debug("No repetitions available. Creating empty topic queue...")
        queue = GlobalTopicQueue(nil)
    end
    if not active.change_queue(queue) then
        log.err("Failed to load the initial queue.")
        sounds.play("negative")
    end
end

local function run()
    if not loaded then

    loaded = true

    sys.verify_dependencies()
    sys.create_essential_files()
    sys.backup()

    mp.register_event("shutdown", active.on_shutdown)

    if not ext.empty(settings["import"]) then
        local importTarget = settings["import"]
        local ret = importer.import(importTarget)
        log.debug("Exiting after import....")
        mp.commandv("quit", ret and 0 or 1)
    else
        require("systems.keybinds")
        loadMedia()
    end
end
end

if settings["start"] == "yes" or not ext.empty(settings["import"]) then
    run()
end