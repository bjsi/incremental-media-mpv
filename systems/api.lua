local mp = require "mp"
local exporter = require "systems.exporter"
local active = require "systems.active"

-- Registers script messsages that are called from SuperMemo Assistant.

local script_messages = {
    export_to_sm = function(time) exporter.export_new_items_to_sm(time) end,
    load_singleton_queue = function(type, id)
        active.load_singleton_queue(type, id)
    end
}

for k, v in pairs(script_messages) do mp.register_script_message(k, v) end
