local sys = require("systems.system")
local str = require("utils.str")
local mpu = require("mp.utils")
local log = require "utils.log"
local fs = require("systems.fs")

local ffmpeg = {}

function ffmpeg.extract_gif(url, start, stop, outputPath)
    log.debug("GIF extract. Start: ", start, "Stop: ", stop)
    local args = {
        "ffmpeg",
        "-reconnect", "1",
        "-reconnect_streamed", "1",
        "-reconnect_delay_max", "5",
        "-ss", tostring(start),
        "-t", tostring(stop - start),
        "-i", url,
        "-vf", "fps=10,scale=320:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse",
        "-loop", "0",
        outputPath
    }
    return sys.subprocess(args).status == 0
end

function ffmpeg.screenshot(url, start, outputPath)
    local args = {
        "ffmpeg",
        "-reconnect", "1",
        "-reconnect_streamed", "1",
        "-reconnect_delay_max", "5",
        "-ss", tostring(start),
        "-i", url,
        "-vframes", "1",
        "-q:v", "3",
        outputPath
    }

    log.debug("Screenshot args", args)

    return sys.subprocess(args).status == 0
end

-- basicallly just converts to mp3?
function ffmpeg.generate_qa_item_files(soundPath, outputFullPathWithExt)

    local args = {
        "ffmpeg", 
        "-i", soundPath,
        outputFullPathWithExt
    }

    log.debug("ffmpeg: ", table.concat(args, " "))
    local ret = sys.subprocess(args)
    return ret.status == 0
end

function ffmpeg.generate_cloze_context_item_files(parentPath, sound, format, outputFullPathWithExt)
    local parentStart = tonumber(sound["start"])
    local parentEnd = tonumber(sound["stop"])
    local clozeStart = tonumber(format["cloze-start"])
    local clozeStop = tonumber(format["cloze-stop"])
    
    local args = {
        "ffmpeg",
        "-i", parentPath,
        "-i", fs.silence,
        "-filter_complex",

        table.concat({
            -- Cut the beginning of the cloze to the end of the cloze
            ("[0:a]atrim=%f:%f[cloze];"):format(clozeStart, clozeStop),

            -- Create the context part that comes after the cloze and silence
            ("[0:a]atrim=%f:%f[context];"):format(parentStart, parentEnd),

            -- Create the silence that separates the cloze from the context
            ("[1:a]atrim=%f:%f[silence];"):format(0, 0.8),

            -- concatenate the files
            '[cloze][silence][context]concat=n=3:v=0:a=1[output]',
        }),

        "-map",
        "[output]", outputFullPathWithExt,
    }

    log.debug("ffmpeg: ", table.concat(args, " "))
    local ret = sys.subprocess(args)
    return ret.status == 0
end

function ffmpeg.generate_cloze_item_files(parentPath, sound, format, question_fp, cloze_fp)
    local clozeLength = tonumber(format["cloze-stop"]) - tonumber(format["cloze-start"])

    local args = {
        "ffmpeg",
        "-i", parentPath,
        "-i", fs.sine,
        "-filter_complex",

        table.concat({
            -- Cut the beginning of the extract before the cloze
            ("[0:a]atrim=%f:%f[beg];"):format(sound["start"], format["cloze-start"]),
            -- Cut the beginning of the cloze to the end of the cloze
            ("[0:a]atrim=%f:%f[cloze];"):format(format["cloze-start"], format["cloze-stop"]),

            -- Cut the end of the extract after the cloze
            ("[0:a]atrim=%f:%f[end];"):format(format["cloze-stop"], sound["stop"]),
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
        localUrl,
        "-v", "quiet",
        "-print_format", "json=compact=0",
        "-show_entries", "format"
    }
    local ret = sys.subprocess(args)
    log.debug("duration", ret)
    if ret.status == 0 then
        return tonumber(mpu.parse_json(str.remove_newlines(ret.stdout))["format"]["duration"])
    else
        return nil
    end
end


local function get_active_track(track_type)
    local track_list = mp.get_property_native('track-list')
    for _, track in pairs(track_list) do
        if track.type == track_type and track.selected == true then
            return track
        end
    end
    return nil
end


local function get_audio_info()
	local source_path = mp.get_property("path")
	local audio_track = get_active_track('audio')
	local audio_track_id = mp.get_property("aid")
	if audio_track and audio_track.external == true then
		source_path = audio_track['external-filename']
		audio_track_id = 'auto'
	end
	return source_path, audio_track_id
end

function ffmpeg.audio_extract(start, stop, audioUrl, outputPath)
    local args = {
        "ffmpeg",
        "-reconnect", "1",
        "-reconnect_streamed", "1",
        "-reconnect_delay_max", "5",
        "-nostats",
        "-ss", tostring(start),
        "-to", tostring(stop),
        "-i", audioUrl,
        "-acodec", "copy",
        outputPath
    }
    return sys.subprocess(args)
end

return ffmpeg
