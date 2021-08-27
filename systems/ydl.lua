local log = require 'utils.log'
local str = require 'utils.str'
local mpu = require 'mp.utils'
local sys = require 'systems.system'
local fs = require 'systems.fs'
local tbl = require 'utils.table'
local mp = require 'mp'

local ydl = {}

ydl.url_prefix = "https://www.youtube.com/watch?v="

function ydl.download_audio(url, goodQuality)
    local quality = "worstaudio"
    if goodQuality then quality = "bestaudio" end
    local args = {
        "youtube-dl", "--no-check-certificate", "-x", "-f", quality,
        mpu.join_path(fs.media, "%(id)s.%(ext)s")
    }

    return ydl.handle_download(args, url)
end

-- TODO: Should be background_process?
function ydl.handle_download(args, url)
    local ret = sys.subprocess(args)
    if ret.status == 0 then
        local mediaFiles = mpu.readdir(fs.media)
        local file = tbl.first(function(f)
            return str.remove_ext(f) == url
        end, mediaFiles)
        return mpu.join_path(fs.media, file)
    end

    return nil
end

function ydl.download_video(url)
    local format = mp.get_property("ytdl-format")

    -- LuaFormatter off
    local args = {
        "youtube-dl",
	"--no-check-certificate",
	"-f",
	format,
	"-o",
        "%(id)s.%(ext)s",
	url
    }
    -- LuaFormatter on

    return ydl.handle_download(args, url)
end

function ydl.get_info(url)
    -- LuaFormatter off
    local args = {
        "youtube-dl",
	"--no-check-certificate",
	"-j",
	"--flat-playlist",
	url
    }
    -- LuaFormatter on

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

function ydl.get_streams(url, quality)
    -- LuaFormatter off
    local args = {
        "youtube-dl",
	"--no-check-certificate",
	"-f",
	quality,
        "--youtube-skip-dash-manifest",
	"-g",
	url
    }
    -- LuaFormatter on
    return sys.subprocess(args)
end

function ydl.get_video_stream(url, goodQuality)
    local quality = "worst"
    if goodQuality then quality = "best" end
    local ret = ydl.get_streams(url, quality)
    if ret.status == 0 then
        local lines = ret.stdout
        local matches = lines:gmatch("([^\n]*)\n?")
        url = matches()
        local format = url:gmatch("mime=video%%2F([a-z0-9]+)&")()
        return url, format
    else
        log.debug("Failed to get video stream.")
        return nil, nil
    end
end

function ydl.get_audio_stream(url, goodQuality)
    local quality = "worstaudio"
    if goodQuality then quality = "bestaudio" end
    local ret = ydl.get_streams(url, quality)
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
