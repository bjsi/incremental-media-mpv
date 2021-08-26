local msg = require 'mp.msg'
local dt = require 'utils.date'
local mp = require 'mp'
local tbl = require 'utils.table'
local obj = require 'utils.object'

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
        local t = tbl.map({...}, obj.dump)
        local joined = table.concat(t, " ")
        local message = "[DBG] " .. dt.time() .. ": " .. joined
        msg.info(message)
    end
end

function log.err(...)
    local t = tbl.map({...}, obj.dump)
    local joined = table.concat(t, " ")
    local x = "[ERR] " .. dt.time() .. ": " .. joined
    msg.info(x)
end

return log
