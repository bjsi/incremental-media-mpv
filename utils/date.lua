local dt = {}

function dt.time() return os.date("%H:%M:%S") end

function dt.date_today() return os.date("%Y-%m-%d") end

function dt.parse_hhmmss(str) return string.match(str, "(%d+)-(%d+)-(%d+)") end

function dt.human_readable_time(secs)
    if type(secs) ~= 'number' or secs < 0 then return 'empty' end

    local parts = {
        h = math.floor(secs / 3600),
        m = math.floor(secs / 60) % 60,
        s = math.floor(secs % 60),
        ms = math.floor((secs * 1000) % 1000)
    }

    local ret = string.format("%02dm%02ds%03dms", parts.m, parts.s, parts.ms)

    if parts.h > 0 then ret = string.format('%dh%s', parts.h, ret) end

    return ret
end

return dt
