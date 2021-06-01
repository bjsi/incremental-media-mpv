local active = require("systems.active")

local keys = {
    ["iv-parent"]={
        ["key"]="w",
        ["callback"]=function() active.queue:parent() end,
    },
    ["iv-child"]={
        ["key"]="s",
        ["callback"]=function() active.queue:child() end,
    },
    ["iv-backward"]={
        ["key"]="a",
        ["callback"]=function() active.queue:handle_backward() end,
    }
}

(function()
    for k, v in pairs(keys) do
        local name = k
        local key = v["key"]
        local callback = v["callback"]
        mp.add_forced_key_binding(key, name, callback)
    end
end)()

-- Key bindings
-- mp.add_forced_key_binding("d", "iv-forward", function() active_queue:handle_forward() end )
-- mp.add_forced_key_binding("2", "iv-extract", function() active_queue:extract() end )
-- mp.add_forced_key_binding("1", "iv-prev", function() active_queue:prev() end )
-- mp.add_forced_key_binding("4", "iv-next", function() active_queue:next() end )
-- mp.add_forced_key_binding("3", "iv-toggle", function() active_queue:toggle() end)
-- mp.add_forced_key_binding("5", "iv-loop", function() active_queue:loop() end)

-- mp.add_forced_key_binding("y", "iv-advance-start", function() active_queue:advance_start() end )
-- mp.add_forced_key_binding("u", "iv-postpone-start", function() active_queue:postpone_start() end )
-- mp.add_forced_key_binding("o", "iv-postpone-stop", function() active_queue:postpone_stop() end )
-- mp.add_forced_key_binding("i", "iv-advance-stop", function() active_queue:advance_stop() end )
-- mp.add_forced_key_binding("t", "iv-toggle-video", function() active_queue:toggle_video() end)
