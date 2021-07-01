local log = require("utils.log")
local str = require("utils.str")
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
        local t = {}
        for i in ret.stdout:gmatch("([^\n]*)\n?") do
            if i then
                t[#t + 1] = mpu.parse_json(str.remove_newlines(i))
            end
        end 
        log.debug("t: ", t)
        return t
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
