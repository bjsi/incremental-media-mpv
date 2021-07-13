local sys = require("systems.system")
local mpu = require("mp.utils")
local log = require "utils.log"
local fs = require("systems.fs")

local ffmpeg = {}

function ffmpeg.generate_item_files(parentPath, parentStart, parentEnd, clozeStart, clozeEnd, question_fp, cloze_fp)
    local clozeLength = clozeEnd - clozeStart
    local args = {
        "ffmpeg",
        "-i", parentPath,
        "-i", fs.sine,
        "-filter_complex",

        table.concat({
            -- Cut the beginning of the extract before the cloze
            ("[0:a]atrim=%f:%f[beg];"):format(parentStart, clozeStart),
            -- Cut the beginning of the cloze to the end of the cloze
            ("[0:a]atrim=%f:%f[cloze];"):format(clozeStart, clozeEnd),

            -- Cut the end of the extract after the cloze
            ("[0:a]atrim=%f:%f[end];"):format(clozeEnd, parentEnd),
            ("[1:a]atrim=%f:%f[beep];"):format(0, clozeLength),

            -- concatenate the files
            '[beg][beep][end]concat=n=3:v=0:a=1[question]',
        }, ""),
        '-map',
        -- Output the clozed extract
        '[question]',
        question_fp,
        '-map',
        -- Output the clozed word / phrase
        '[cloze]',
        cloze_fp
    }

    log.debug("ffmpeg: ", table.concat(args, " "))

    local ret = sys.subprocess(args)
    return ret.status == 0
end

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
