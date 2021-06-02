local log = require("utils.log")
local active = require("systems.active")
local sys = require("systems.system")
local TopicQueue = require("queue.topics")
local player = require("systems.player")
local TopicRepTable = require("reps.reptable.topics")

local main
do
    local main_executed = false
    main = function()
        if main_executed then return end

        log.debug("Loading incremental media.")

        sys.verify_dependencies()
        sys.create_essential_files()

        mp.observe_property("time-pos", "number", player.loop_timer.check_loop)
        mp.set_property("loop", "inf")
        mp.register_event("shutdown", active.on_shutdown)

        require("systems.keybinds")

        active.queue = TopicQueue(nil, TopicRepTable())

        main_executed = true
    end
end

-- for when loading from idle
main()
