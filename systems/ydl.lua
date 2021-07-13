local log = require("utils.log")
local str = require("utils.str")
local mpu = require("mp.utils")
local sys = require("systems.system")
local fs = require "systems.fs"
local ext = require "utils.ext"


local ydl = {}

ydl.url_prefix = "https://www.youtube.com/watch?v="

function ydl.download_audio(url, goodQuality)
    local quality = goodQuality and "bestaudio" or "worstaudio"
    local args = {
        "youtube-dl",
        "--no-check-certificate",
        "-x",
        "-f", quality,
        mpu.join_path(fs.media, "%(id)s.%(ext)s")
    }

    return ydl.handle_download(args, url)
end

-- TODO: Should be background_process?
function ydl.handle_download(args, url)
    local ret = sys.subprocess(args)
    if ret.status == 0 then
        local mediaFiles = mpu.readdir(fs.media)
        local theFile = ext.first_or_nil(function(f) return str.remove_ext(f) == url end, mediaFiles)
        return mpu.join_path(fs.media, theFile)
    end
    
    return nil
end

function ydl.download_video(url)
    local format = mp.get_property("ytdl-format")
    local args = {
        "youtube-dl",
        "--no-check-certificate",
        "-f", format,
        "-o", "%(id)s.%(ext)s",
        url
    }

    return ydl.handle_download(args, url)
end

function ydl.get_info(url)
    local args = {
        "youtube-dl",
        "--no-check-certificate",
        "-j",
        "--flat-playlist",
        url
    }

    local ret = sys.subprocess(args)
    local t = {}
    if ret.status == 0 then
        for i in ret.stdout:gmatch("([^\n]*)\n?") do
            if i then
                t[#t + 1] = mpu.parse_json(str.remove_newlines(i))
            end
        end
        return t
    end

    return t
end

function ydl.get_audio_stream(url, goodQuality)
    local quality = goodQuality and "bestaudio" or "worstaudio"
    local args = {
        "youtube-dl",
        "--no-check-certificate",
        "-f", quality,
        "--youtube-skip-dash-manifest",
        "-g",
        url
    }

    local ret = sys.subprocess(args)
    if ret.status == 0 then
        local lines = ret.stdout
        local matches = lines:gmatch("([^\n]*)\n?")
        url = matches()
        local format = url:gmatch("mime=audio%%2F([a-z0-9]+)&")()
        return url, format
    else
        log.debug("Failed to get audio stream.")
        return nil, nil
    end
end

return ydl
