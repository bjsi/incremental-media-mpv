local ext = require("utils.ext")
local msg = ext.prequire('mp.msg')
local dt = require("utils.date")

local log = {}

log.level = "DEBUG"

function log.notify(message, level, duration)
    level = level or 'info'
    duration = duration or 1
    msg[level](message)
    mp.osd_message(message, duration)
end

function log.debug(...)
    if log.level == "DEBUG" then
        local tbl = ext.list_map({...}, ext.dump)
        local joined = table.concat(tbl, " ")
        local message = "[DBG] " .. dt.time() .. ": " .. joined
        msg.info(message)
    end
end

function log.err(...)
    local tbl = ext.list_map({...}, ext.dump)
    local joined = table.concat(tbl, " ")
    local x = "[ERR] " .. dt.time() .. ": " .. joined
    msg.info(x)
end

return log
