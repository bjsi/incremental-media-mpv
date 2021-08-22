local active = require("systems.active")
local menu = require("systems.menu.menuBase")

local keys = {
    ["incmedia-set-extract-boundary"] = function()
        active.queue:set_extract_boundary()
    end,
    ["incmedia-menu-toggle"] = function() menu.open() end,
    ["incmedia-adjust-priority"] = function(n)
        active.queue:adjust_priority(n)
    end,
    ["incmedia-adjust-interval"] = function(n)
        active.queue:adjust_interval(n)
    end,
    ["incmedia-adjust-afactor"] = function(n) active.queue:adjust_afactor(n) end,
    ["incmedia-clear-extract-boundaries"] = function()
        active.queue:clear_abloop()
    end,
    ["incmedia-set-end-boundary-extract"] = function()
        active.queue:set_end_boundary_extract()
    end,
    ["incmedia-copy-url"] = function() active.queue:copy_url(false) end,
    ["incmedia-copy-url-with-timestamp"] = function()
        active.queue:copy_url(true)
    end,
    ["incmedia-localize-video"] = function() active.queue:localize_video() end,
    ["incmedia-dismiss"] = function() active.queue:dismiss() end,
    ["incmedia-global-extracts"] = function() active.load_global_extracts() end,
    ["incmedia-global-items"] = function() active.load_global_items() end,
    ["incmedia-global-topics"] = function() active.load_global_topics() end,
    ["incmedia-parent"] = function() active.queue:parent() end,
    ["incmedia-child"] = function() active.queue:child() end,
    ["incmedia-fwd-history"] = function() active.queue:forward_history() end,
    ["incmedia-bwd-history"] = function() active.queue:backward_history() end,
    ["incmedia-extract"] = function() active.queue:extract() end,
    ["incmedia-next-repetition"] = function() active.queue:next_repetition() end,
    ["incmedia-advance-start"] = function(n) active.queue:advance_start(n) end,
    ["incmedia-postpone-stop"] = function(n) active.queue:postpone_stop(n) end,
    ["incmedia-advance-stop"] = function(n) active.queue:advance_stop(n) end,
    ["incmedia-toggle-video"] = function() active.queue:toggle_video() end
}

(function()
    for name, cb in pairs(keys) do mp.register_script_message(name, cb) end
end)()
