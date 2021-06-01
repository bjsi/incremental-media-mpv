local log = require("utils.log")
local active = require("systems.active")
local sys = require("system.system")

local main
do
    local main_executed = false
    main = function()

        if main_executed then return end

        log.debug("Loading incremental video script.")

        if not sys.verify_dependencies() then
            log.err("Quitting: Missing dependencies.")
            return
        end

        if not sys.create_essential_files() then
            log.err("Quitting: Failed to create essential files.")
            return
        end

        mp.observe_property("time-pos", "number", loop_timer.check_loop)
        mp.set_property("loop", "inf")
        mp.register_event("shutdown", db.on_shutdown)

        active.queue = GlobalTopicQueue(nil, topics)

        main_executed = true
    end
end

-- for when loading from idle
main()
