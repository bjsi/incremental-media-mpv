local log = require("utils.log")
local mpu = require("mp.utils")
local sys = require("systems.system")
local ext = require "utils.ext"

local ydl = {}

ydl.url_prefix = "https://www.youtube.com/watch?v="

function ydl.get_info(url)
    local args = {
        "youtube-dl",
        "-j",
        "--flat-playlist",
        url
    }

    local ret = sys.subprocess(args)
    if ret.status == 0 then
        local matches = ret.stdout:gmatch("([^\n]*)\n?") -- TODO: windows? \r\n
        return ext.list_map(matches, function(x) return mpu.parse_json(x) end)
    end

    return nil
end

function ydl.get_audio_stream(url)
    local args = {
        "youtube-dl",
        "-f",
        "worstaudio",
        "--youtube-skip-dash-manifest",
        "-g",
        url
    }

    local ret = sys.subprocess(args)
    if ret.status == 0 then
        local lines = ret.stdout
        local matches = lines:gmatch("([^\n]*)\n?")
        url = matches()
        local format = url:gmatch("mime=audio%%2F([a-z]+)&")()
        return url, format
    else
        log.debug("Failed to get audio stream.")
        return nil, nil
    end
end

return ydl
