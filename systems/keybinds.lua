local active = require("systems.active")
local importer = require("systems.importer")

local keys = {
    ["iv-parent"] = {
        ["key"] = "w",
        ["callback"] = function() active.queue:parent() end
    },
    ["iv-import"] = {
        ["key"] = "Ctrl+Shift+v",
        ["callback"] = function() importer.import() end
    },
    ["iv-child"] = {
        ["key"] = "s",
        ["callback"] = function() active.queue:child() end
    },
    ["iv-backward"] = {
        ["key"] = "a",
        ["callback"] = function() active.queue:handle_backward() end
    },
    ["iv-forward"] = {
        ["key"] = "d",
        ["callback"] = function() active.queue:handle_forward() end
    },
    ["iv-fwd-history"] = {
        ["key"] = "Alt+right",
        ["callback"] = function() active.queue:forward_history() end
    },
    ["iv-bwd-history"] = {
        ["key"] = "Alt+left",
        ["callback"] = function() active.queue:backward_history() end
    },
    ["iv-extract"] = {
        ["key"] = "2",
        ["callback"] = function() active.queue:extract() end
    },
    ["iv-prev"] = {
        ["key"] = "1",
        ["callback"] = function() active.queue:prev() end
    },
    ["iv-next"] = {
        ["key"] = "4",
        ["callback"] = function() active.queue:next_repetition() end
    },
    ["iv-toggle"] = {
        ["key"] = "3",
        ["callback"] = function() active.queue:toggle() end
    },
    ["iv-loop"] = {
        ["key"] = "5",
        ["callback"] = function() active.queue:loop() end
    },
    ["iv-advance-start"] = {
        ["key"] = "y",
        ["callback"] = function() active.queue:advance_start() end
    },
    ["iv-postpone-start"] = {
        ["key"] = "u",
        ["callback"] = function() active.queue:postpone_start() end
    },
    ["iv-postpone-stop"] = {
        ["key"] = "o",
        ["callback"] = function() active.queue:postpone_stop() end
    },
    ["iv-advance-stop"] = {
        ["key"] = "i",
        ["callback"] = function() active.queue:advance_stop() end
    },
    ["iv-toggle-video"] = {
        ["key"] = "t",
        ["callback"] = function() active.queue:toggle_video() end
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
