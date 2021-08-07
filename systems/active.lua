local log = require("utils.log")
local cfg = require("systems.config")

local GlobalExtractQueue
local GlobalItemQueue
local GlobalTopicQueue
local SingletonItemQueue
local SingletonTopicQueue
local SingletonExtractQueue

local menu

local active = {}

active.queue = nil
active.locked = false

function active.on_shutdown()
    if active.queue then
        log.debug("Saving reptable before exit.")
        active.queue:save_data()
    end
end

function active.get_singleton_queue(type, id)
    local queue
    if type == "Item" then
        SingletonItemQueue = SingletonItemQueue or require("queue.singletons.singletonItemQueue")
        queue = SingletonItemQueue(id)
    elseif type == "Topic" then
        SingletonTopicQueue = SingletonTopicQueue or require("queue.singletons.singletonTopicQueue")
        queue = SingletonTopicQueue(id)
    elseif type == "Extract" then
        SingletonExtractQueue = SingletonExtractQueue or require("queue.singletons.singletonExtractQueue")
        queue = SingletonExtractQueue(id)
    end
    return queue
end

function active.load_singleton_queue(type, id)
    local queue = active.get_singleton_queue(type, id)
    if queue == nil then
        log.debug("Failed to get singleton queue: it was nil")
        return false
    end

    log.debug("Changing to a singleton queue.")
    return active.change_queue(queue)
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
    GlobalItemQueue = GlobalItemQueue or require("queue.globalItemQueue")
    local giq = GlobalItemQueue(nil)
    active.change_queue(giq)
end

function active.enter_update_lock()
    active.locked = true
end

function active.exit_update_lock()
    active.locked = false
end

function active.change_queue(newQueue)
    if active.queue then
        active.queue:clean_up_events()
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

    menu = menu or require("systems.menu.menuBase")
    menu.update()
    active.queue:subscribe_to_events()
    return true
end

return active
