local active_queue = require 'systems.active'
local log = require 'utils.log'

local SingletonTopic
local SingletonExtract
local SingletonItem

local ext = {}

function ext.get_singleton_queue(type, id)
    if type == "Item" then
        SingletonItem = SingletonItem or require("queues.singletons.item")
        return SingletonItem(id)
    elseif type == "Topic" then
        SingletonTopic = SingletonTopic or require("queues.singletons.topic")
        return SingletonTopic(id)
    elseif type == "Extract" then
        SingletonExtract = SingletonExtract or require("queues.singletons.extract")
        return SingletonExtract(id)
    else
	log.err("Failed to get singleton queue - unrecognised type: " .. type)
	return nil
    end
end

function ext.load_singleton_queue(type, id)
    local queue = ext.get_singleton_queue(type, id)
    if queue == nil then
        log.debug("Failed to get singleton queue: it was nil")
        return false
    end

    return active_queue.change_queue(queue)
end

return ext
