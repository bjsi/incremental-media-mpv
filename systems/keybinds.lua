local active = require 'systems.active'
local mp = require 'mp'
local menu = require 'systems.menu.menuBase'

-- LuaFormatter off
local keys = {
    ["im-set-extract-boundary"] = function() active.queue:set_extract_boundary() end,
    ["im-menu-toggle"] = function() menu.open() end,
    ["im-adjust-priority"] = function(n) active.queue:adjust_priority(n) end,
    ["im-adjust-interval"] = function(n) active.queue:adjust_interval(n) end,
    ["im-adjust-afactor"] = function(n) active.queue:adjust_afactor(n) end,
    ["im-clear-extract-boundaries"] = function() active.queue:clear_abloop() end,
    ["im-set-end-boundary-extract"] = function() active.queue:set_end_boundary_extract() end,
    ["im-copy-url"] = function() active.queue:copy_url(false) end,
    ["im-copy-url-with-timestamp"] = function() active.queue:copy_url(true) end,
    ["im-localize-video"] = function() active.queue:localize_video() end,
    ["im-dismiss"] = function() active.queue:dismiss() end,
    ["im-global-extracts"] = function() active.load_global_extracts() end,
    ["im-global-items"] = function() active.load_global_items() end,
    ["im-global-topics"] = function() active.load_global_topics() end,
    ["im-parent"] = function() active.queue:parent() end,
    ["im-child"] = function() active.queue:child() end,
    ["im-fwd-history"] = function() active.queue:forward_history() end,
    ["im-bwd-history"] = function() active.queue:backward_history() end,
    ["im-extract"] = function() active.queue:extract() end,
    ["im-next-repetition"] = function() active.queue:learn() end,
    ["im-advance-start"] = function(n) active.queue:advance_start(n) end,
    ["im-postpone-start"] = function(n) active.queue:postpone_start(n) end,
    ["im-postpone-stop"] = function(n) active.queue:postpone_stop(n) end,
    ["im-advance-stop"] = function(n) active.queue:advance_stop(n) end,
    ["im-toggle-video"] = function() active.queue:toggle_video() end
}
-- LuaFormatter on

(function()
    for name, cb in pairs(keys) do mp.register_script_message(name, cb) end
end)()
