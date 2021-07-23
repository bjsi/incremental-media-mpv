local active = require("systems.active")
local menu = require("systems.menu.menuBase")
local importer = require("systems.importer")
local system   = require("systems.system")

local keys = {

    ["iv-create-qa"] = {
        ["key"] = "Alt+e",
        ["callback"] = function() active.queue:extract("QA") end
    },

    ["iv-menu-open"] = {
        ["key"] = "m",
        ["callback"] = function() menu.open() end
    },

    ["iv-toggle-export"] = {
        ["key"] = "X",
        ["callback"] = function() active.queue:toggle_export() end
    },

    -- Priority
    --
    ["iv-increase-priority"] = {
        ["key"] = "Up",
        ["callback"] = function() active.queue:adjust_priority(1) end
    },
    ["iv-decrease-priority"] = {
        ["key"] = "Down",
        ["callback"] = function() active.queue:adjust_priority(-1) end
    },
    ["iv-increase-priority-big"] = {
        ["key"] = "Shift+Up",
        ["callback"] = function() active.queue:adjust_priority(5) end
    },
    ["iv-decrease-priority-big"] = {
        ["key"] = "Shift+Down",
        ["callback"] = function() active.queue:adjust_priority(-5) end
    },

    -- Interval
    --
    ["iv-increase-interval"] = {
        ["key"] = "Ctrl+Up",
        ["callback"] = function() active.queue:adjust_interval(1) end,
    },
    ["iv-decrease-interval"] = {
        ["key"] = 'Ctrl+Down', 
        ["callback"] = function() active.queue:adjust_interval(-1) end,
    },

    -- A-Factor
    --
    ["iv-increase-afactor"] = {
        ["key"] = "Alt+Up",
        ["callback"] = function() active.queue:adjust_afactor(1) end
    },
    ["iv-decrease-afactor"] = {
        ["key"] = "Alt+Down",
        ["callback"] = function() active.queue:adjust_afactor(-1) end
    },

    -- ["iv-split-chapters"] = {
    --     ["key"] = "S",
    --     ["callback"] = function() active.queue:split_chapters() end
    -- },

    ["iv-clear-ab-loop"] = {
        ["key"] = "c",
        ["callback"] = function() active.queue:clear_abloop() end
    },

    ["iv-set-speed-110"] = {
        ["key"] = "1",
        ["callback"] = function() active.queue:set_speed(1.1) end
    },

    ["iv-set-speed-120"] = {
        ["key"] = "2",
        ["callback"] = function() active.queue:set_speed(1.2) end
    },

    ["iv-set-speed-70"] = {
        ["key"] = "7",
        ["callback"] = function() active.queue:set_speed(0.7) end
    },

    ["iv-set-speed-80"] = {
        ["key"] = "8",
        ["callback"] = function() active.queue:set_speed(0.8) end
    },

    ["iv-set-speed-90"] = {
        ["key"] = "9",
        ["callback"] = function() active.queue:set_speed(0.9) end
    },

    ["iv-set-speed-100"] = {
        ["key"] = "0",
        ["callback"] = function() active.queue:set_speed(1) end
    },

    ["iv-set-end-boundary-extract"] = {
        ["key"] = "@",
        ["callback"] = function() active.queue:set_end_boundary_extract() end
    },

    ["iv-copy-url"] = {
        ["key"] = "Ctrl+c",
        ["callback"] = function() active.queue:copy_url(false) end
    },

    ["iv-copy-url-with-timestamp"] = {
        ["key"] = "Ctrl+Shift+c",
        ["callback"] = function() active.queue:copy_url(true) end
    },

    ["iv-has-children"] = {
        ["key"] = "H",
        ["callback"] = function() active.queue:has_children() end
    },

    ["iv-localize-video"] = {
        ["key"] = "V",
        ["callback"] = function() active.queue:localize_video() end
    },

    ["iv-dismiss"] = {
        ["key"] = "Ctrl+d",
        ["callback"] = function() active.queue:dismiss() end
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
        ["key"] = "e",
        ["callback"] = function() active.queue:extract() end
    },

    ["iv-extract-extract"] = {
        ["key"] = "Ctrl+e",
        ["callback"] = function() active.queue:extract("extract") end
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

    ["iv-advance-start-big"] = {
        ["key"] = "Y",
        ["callback"] = function() active.queue:advance_start(2) end
    },

    --- Advance the start of an extract or cloze by a small amount.
    ["iv-advance-start"] = {
        ["key"] = "y",
        ["callback"] = function() active.queue:advance_start(0.05) end
    },

    ["iv-postpone-start-big"] = {
        ["key"] = "U",
        ["callback"] = function() active.queue:postpone_start(2) end
    },

    --- Postpone the start of the active ab loop, extract or cloze by a small amount.
    ["iv-postpone-start"] = {
        ["key"] = "u",
        ["callback"] = function() active.queue:postpone_start(0.05) end
    },

    ["iv-postpone-stop-big"] = {
        ["key"] = "O",
        ["callback"] = function() active.queue:postpone_stop(2) end
    },

    --- Postpone the end of the active ab loop, extract or cloze by a small amount.
    ["iv-postpone-stop"] = {
        ["key"] = "o",
        ["callback"] = function() active.queue:postpone_stop(0.05) end
    },

    ["iv-advance-stop-big"] = {
        ["key"] = "I",
        ["callback"] = function() active.queue:advance_stop(2) end
    },
    
    --- Advance the end of the active ab loop, extract or cloze by a small amount.
    ["iv-advance-stop"] = {
        ["key"] = "i",
        ["callback"] = function() active.queue:advance_stop(0.05) end
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
