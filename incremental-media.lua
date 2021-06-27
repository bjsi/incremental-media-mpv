local log = require("utils.log")
local sounds = require("systems.sounds")
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
    return gi
end

local main
do
    local main_executed = false
    main = function()
        if main_executed then return end

        log.debug("Loading incremental media.")

        sys.verify_dependencies()
        sys.create_essential_files()
        sys.backup()
        
        local queue = getInitialQueue()
        if not queue or ext.empty(queue.reptable.subset) then
            log.debug("No repetitions available.")
            sounds.play("negative")
            return
        end

        if active.change_queue(queue) then
            require("systems.keybinds")
            mp.observe_property("time-pos", "number", player.loop_timer.check_loop)
            mp.set_property("loop", "inf")
            mp.register_event("shutdown", active.on_shutdown)
        else
            log.err("Failed to load the initial queue.")
            sounds.play("negative")
            return
        end

        main_executed = true
    end
end

-- for when loading from idle
main()
