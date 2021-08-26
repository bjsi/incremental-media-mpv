local log = require("utils.log")

local GlobalExtracts
local GlobalItems
local GlobalTopics

local menu

-- the active queue
local queue = nil
local locked = false -- TODO

local active = {}

function active.get_queue()
	return queue
end

function active.on_shutdown()
    if active.queue then
        log.debug("Saving reptable before exit.")
        active.queue:save_data()
    end
end

function active.load_global_topics()
    GlobalTopics = GlobalTopics or require("queues.global.topics")
    local gtq = GlobalTopics(nil)
    active.change_queue(gtq)
end

function active.load_global_extracts()
    GlobalExtracts = GlobalExtracts or require("queues.global.extracts")
    local geq = GlobalExtracts(nil)
    active.change_queue(geq)
end

function active.load_global_items()
    GlobalItems = GlobalItems or require("queues.global.items")
    local giq = GlobalItems(nil)
    active.change_queue(giq)
end

function active.enter_update_lock()
	locked = true
end

function active.exit_update_lock() 
	locked = false
end

function active.change_queue(queue)
    if active.queue then
        active.queue:clean_up_events()
        log.debug("Saving reptable before change queue.")
        active.queue:save_data()
    end

    if not queue then
        log.err("New queue was nil.")
        return false
    end

    log.debug("Loading new queue...")
    active.queue = queue

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
