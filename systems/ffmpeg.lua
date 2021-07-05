local sys = require("systems.system")
local mpu = require("mp.utils")
local log = require "utils.log"

local ffmpeg = {}

function ffmpeg.get_duration(localUrl)
    local args = {
        "ffprobe",
        "-v", "quiet",
        "-print_format", "json_compact=1",
        "-show_format",
        localUrl
    }
    local ret = sys.subprocess(args)
    if ret.status == 0 then
        return tonumber(mpu.parse_json(ret.stdout)["format"]["duration"])
    else
        return nil
    end
end

function ffmpeg.audio_extract(parent, audioUrl, outputPath)
    log.debug("Extracting audio from: " .. parent.row["url"])
    local args = {
        "ffmpeg",
        "-nostats",
        "-ss", tostring(parent.row["start"]), "-to",
        tostring(parent.row["stop"]), "-i", audioUrl, -- extract audio stream
        outputPath
    }
    return sys.subprocess(args)
end

return ffmpeg
