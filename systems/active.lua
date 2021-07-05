local log = require("utils.log")
local GlobalExtractQueue
local GlobalItemQueue
local GlobalTopicQueue

local active = {}

active.queue = nil

function active.on_shutdown()
    if active.queue then
        log.debug("Saving reptable before exit.")
        active.queue:save_data()
    end
end

function active.load_global_topics()
    GlobalTopicQueue = GlobalTopicQueue or require("queue.globalTopicQueue")
    local gtq = GlobalTopicQueue(nil)
    active.change_queue(gtq)
end

function active.load_global_extracts()
    GlobalExtractQueue = GlobalExtractQueue or require("queue.globalExtractQueue")
    local geq = GlobalExtractQueue(nil)
    active.change_queue(geq)
end

function active.load_global_items()
    GlobalItemQueue = GlobalItemQueue or require("queue.globalTopicQueue")
    local geq = GlobalItemQueue(nil)
    active.change_queue(geq)
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
