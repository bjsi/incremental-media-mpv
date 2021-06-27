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
    if active.queue then 
        log.debug("Saving reptable before change queue.")
        active.queue:save_data()
    end

    if not newQueue then
        log.err("New queue was nil.")
        return false
    end

    log.debug("Loading new queue...")
    active.queue = newQueue
    if not active.queue:activate() then
        log.err("Failed to activate new queue.")
        return false
    end
    
    return true
end

return active
