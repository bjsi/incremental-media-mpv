local log = require("utils.log")

local active = {}

active.queue = nil

function active.on_shutdown()
    if active.queue then
        log.debug("Saving reptable before exit.")
        active.queue:save_data()
    end
end

function active.change_queue(newQueue)
    log.debug("Loading new queue...")
    if active.queue then 
        log.debug("Saving reptable before change queue.")
        active.queue:save_data()
    end

    active.queue = newQueue
    active.queue:activate()
end

return active
