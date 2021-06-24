local sys = require("systems.system")
local log = require "utils.log"

local ffmpeg = {}

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
