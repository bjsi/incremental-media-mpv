local active = require("systems.active")
local importer = require("systems.importer")

local keys = {

    ["iv-localize-video"] = {
        ["key"] = "V",
        ["callback"] = function() active.queue:localize_video() end
    },

    ["iv-dismiss"] = {
        ["key"] = "Ctrl+d",
        ["callback"] = function() active.queue:dismiss() end
    },

    -- Load a grandparent / grandchild queue
    ["iv-grand"] = {
        ["key"] = "G",
        ["callback"] = function() active.queue:load_grand_queue() end
    },

    ["iv-global-extracts"] = {
        ["key"] = "E",
        ["callback"] = function() active.load_global_extracts() end
    },

    ["iv-global-items"] = {
        ["key"] = "I",
        ["callback"] = function() active.load_global_items() end
    },

    --- Load the global topic queue.
    ["iv-global-topics"] = {
        ["key"] = "T",
        ["callback"] = function() active.load_global_topics() end
    },

    --- Go to the parent of the current element.
    --- Eg. When executed on an extract, it will attempt to load a topic queue
    --- with the parent topic as the first element.
    ["iv-parent"] = {
        ["key"] = "w",
        ["callback"] = function() active.queue:parent() end
    },

    --- Read the clipboard and import into the topics.csv queue.
    --- Works with local files, youtube videos and youtube playlists.
    ["iv-import"] = {
        ["key"] = "Ctrl+Shift+v",
        ["callback"] = function() importer.import_from_clipboard() end
    },

    --- Go to the child of the current element.
    --- Eg. When executed on an extract, it will attempt to load an item queue
    --- containing audio clozes created from the extract.
    ["iv-child"] = {
        ["key"] = "s",
        ["callback"] = function() active.queue:child() end
    },

    --- Seek backward
    ["iv-backward"] = {
        ["key"] = "a",
        ["callback"] = function() active.queue:handle_backward(false) end
    },

    --- Seek forward
    ["iv-forward"] = {
        ["key"] = "d",
        ["callback"] = function() active.queue:handle_forward(false) end
    },

    ["iv-big-backward"] = {
        ["key"] = "A",
        ["callback"] = function() active.queue:handle_backward(true) end
    },

    ["iv-big-foward"] = {
        ["key"] = "D",
        ["callback"] = function() active.queue:handle_forward(true) end
    },

    --- Move forward in element history.
    ["iv-fwd-history"] = {
        ["key"] = "Alt+right",
        ["callback"] = function() active.queue:forward_history() end
    },

    --- Move backward in element history.
    ["iv-bwd-history"] = {
        ["key"] = "Alt+left",
        ["callback"] = function() active.queue:backward_history() end
    },

    --- Create an extract or cloze based on the current ab-loop settings
    ["iv-extract"] = {
        ["key"] = "2",
        ["callback"] = function() active.queue:extract() end
    },

    --- Load the next repetition, scheduling the current repetition if necessary.
    ["iv-next"] = {
        ["key"] = "4",
        ["callback"] = function() active.queue:next_repetition() end
    },

    --- Set the ab loop - used for setting extract and cloze boundaries.
    ["iv-loop"] = {
        ["key"] = "5",
        ["callback"] = function() active.queue:loop() end
    },

    --- Advance the start of an extract or cloze by a small amount.
    ["iv-advance-start"] = {
        ["key"] = "y",
        ["callback"] = function() active.queue:advance_start() end
    },

    --- Postpone the start of the active ab loop, extract or cloze by a small amount.
    ["iv-postpone-start"] = {
        ["key"] = "u",
        ["callback"] = function() active.queue:postpone_start() end
    },

    --- Postpone the end of the active ab loop, extract or cloze by a small amount.
    ["iv-postpone-stop"] = {
        ["key"] = "o",
        ["callback"] = function() active.queue:postpone_stop() end
    },

    --- Advance the end of the active ab loop, extract or cloze by a small amount.
    ["iv-advance-stop"] = {
        ["key"] = "i",
        ["callback"] = function() active.queue:advance_stop() end
    },

    --- Toggle between video+audio or just audio.
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
