local log = require("utils.log")
local sys = require("systems.system")
local fs = require("systems.fs")
local mpu = require("mp.utils")

local ffmpeg = {}

function ffmpeg.audio_extract(url, output, start, stop)
    local extension = ".wav"
    local fname = tostring(os.time(os.date("!*t"))) .. "-aa"
    local extract = mpu.join_path(fs.media, fname .. extension)
    local args = {
        "ffmpeg", -- "-hide_banner",
        "-nostats", -- "-loglevel", "fatal",
        "-ss", tostring(curRep.row["start"]), "-to",
        tostring(curRep.row["stop"]), "-i", url, -- extract audio stream
        extract
    }
    return sys.subprocess(args)
end

return ffmpeg
