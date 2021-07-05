local log = require("utils.log")
local mpopt = require("mp.options")
local active = require("systems.active")
local sys = require("systems.system")
local GlobalTopicQueue = require("queue.globalTopicQueue")
local GlobalExtractQueue = require("queue.globalExtractQueue")
local GlobalItemQueue = require("queue.globalItemQueue")
local player = require("systems.player")
local ext = require("utils.ext")
local sounds = require "systems.sounds"

local function getInitialQueue()
    local gt = GlobalTopicQueue(nil)
    if gt and not ext.empty(gt.reptable.subset) then return gt end
    local ge = GlobalExtractQueue(nil)
    if ge and not ext.empty(ge.reptable.subset) then return ge end
    local gi = GlobalItemQueue(nil)
    if gi and not ext.empty(gi.reptable.subset) then return gi end
end

local settings = {
    ["autostart"] = false,
}

mpopt.read_options(settings, "im")

local loaded = false

local function run()
    if not loaded then

        sys.verify_dependencies()
        sys.create_essential_files()
        sys.backup()

        local queue = getInitialQueue()
        if not queue or ext.empty(queue.reptable.subset) then
            log.debug("No repetitions available. Creating empty topic queue...")
            queue = GlobalTopicQueue(nil)
        end

        require("systems.keybinds")
        mp.observe_property("time-pos", "number", player.loop_timer.check_loop)
        mp.set_property("loop", "inf")
        mp.register_event("shutdown", active.on_shutdown)
        mp.set_property("force-window", "yes")

        if not active.change_queue(queue) then
            log.err("Failed to load the initial queue.")
            sounds.play("negative")
        end

        loaded = true
    end
end

if settings["autostart"] then
    run()
end

