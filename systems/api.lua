local mp = require "mp"
local exporter = require "systems.exporter"
local active = require "systems.active"

-- Registers script messsages that are called from SuperMemo Assistant.

local script_messages = {
    -- LuaFormatter off
    export_to_sm = function(time) exporter.export_new_items_to_sm(time) end,
    load_singleton_queue = function(type, id) active.load_singleton_queue(type, id) end,
    load_subset = function(id_list) active.load_subset_queue(id_list) end
    -- LuaFormatter on
}

for k, v in pairs(script_messages) do mp.register_script_message(k, v) end
