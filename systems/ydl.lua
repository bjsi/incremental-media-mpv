local log = require("utils.log")
local sys = require("systems.system")

local ydl = {}

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
