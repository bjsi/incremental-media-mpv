local active = require 'systems.active'
local log = require 'utils.log'
local sounds = require 'systems.sounds'
local mp = require 'mp'
local menu = require 'systems.menu.menuBase'

-- LuaFormatter off
local keys = {
    ["im-set-extract-boundary"] ={ cb= function() active.queue:set_extract_boundary() end, queue=true},
    ["im-menu-toggle"] = { cb=function() menu.open() end, queue=false},
    ["im-adjust-priority"] ={ cb= function(n) active.queue:adjust_priority(n) end, queue=true},
    ["im-adjust-interval"] ={ cb= function(n) active.queue:adjust_interval(n) end, queue=true},
    ["im-adjust-afactor"] ={ cb= function(n) active.queue:adjust_afactor(n) end, queue=true},
    ["im-clear-extract-boundaries"] ={ cb= function() active.queue:clear_abloop() end, queue=true},
    ["im-set-end-boundary-extract"] ={ cb= function() active.queue:set_end_boundary_extract() end, queue=true},
    ["im-copy-url"] ={ cb= function() active.queue:copy_url(false) end, queue=true},
    ["im-copy-url-with-timestamp"] ={ cb= function() active.queue:copy_url(true) end, queue=true},
    ["im-localize-video"] ={ cb= function() active.queue:localize_video() end, queue=true},
    ["im-dismiss"] ={ cb= function() active.queue:dismiss() end, queue=true},
    ["im-global-extracts"] ={ cb= function() active.load_global_extracts() end, queue=false},
    ["im-global-items"] ={ cb= function() active.load_global_items() end, queue=false},
    ["im-global-topics"] ={ cb= function() active.load_global_topics() end, queue=false},
    ["im-parent"] ={ cb= function() active.queue:parent() end, queue=true},
    ["im-child"] ={ cb= function() active.queue:child() end, queue=true},
    ["im-fwd-history"] ={ cb= function() active.queue:forward_history() end, queue=true},
    ["im-bwd-history"] ={ cb= function() active.queue:backward_history() end, queue=true},
    ["im-extract"] ={ cb= function() active.queue:extract() end, queue=true},
    ["im-next-repetition"] ={ cb= function() active.queue:learn() end, queue=true},
    ["im-advance-start"] ={ cb= function(n) active.queue:advance_start(n) end, queue=true},
    ["im-postpone-start"] ={ cb= function(n) active.queue:postpone_start(n) end, queue=true},
    ["im-postpone-stop"] ={ cb= function(n) active.queue:postpone_stop(n) end, queue=true},
    ["im-advance-stop"] ={ cb= function(n) active.queue:advance_stop(n) end, queue=true},
    ["im-toggle-video"] ={ cb= function() active.queue:toggle_video() end, queue=true }
}
-- LuaFormatter on

local function queue_guard(func)
    return function(...)
        local queue = active.queue
        if not queue then
            log.notify("No active queue.")
            sounds.play("negative")
        else
            func(...)
        end
    end
end

(function()
    for name, tbl in pairs(keys) do
        local cb = tbl.cb
        if tbl.queue then cb = queue_guard(tbl.cb) end
        mp.register_script_message(name, cb)
    end
end)()
