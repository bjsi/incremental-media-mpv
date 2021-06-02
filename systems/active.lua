local log = require("utils.log")

local active = {}

active.queue = nil

function active.on_shutdown()
    if active.queue ~= nil then
        log.debug("Saving reptable before exit.")
        active.queue.reptable:write()
    end
end

return active
