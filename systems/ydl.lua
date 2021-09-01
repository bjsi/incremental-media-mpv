local log = require 'utils.log'
local str = require 'utils.str'
local mpu = require 'mp.utils'
local sys = require 'systems.system'
local fs = require 'systems.fs'
local tbl = require 'utils.table'
local mp = require 'mp'

local ydl = {}

ydl.url_prefix = "https://www.youtube.com/watch?v="

function ydl.get_playlist_info(info, url)
	local args = {
		"youtube-dl",
		"--no-check-certificate",
		"--get-filename",
		"--playlist-items", "1",
		"-o", info,
		url
	}
    	local ret = sys.subprocess(args)
	if ret.status == 0 then return str.remove_newlines(ret.stdout) else return nil end
end

function ydl.get_playlist_title(url)
	return ydl.get_playlist_info("%(playlist_title)s", url)
end

function ydl.get_playlist_id(url)
	return ydl.get_playlist_info("%(playlist_id)s", url)
end

function ydl.download_audio(url, goodQuality)
    local quality = "worstaudio"
    if goodQuality then quality = "bestaudio" end
    local args = {
        "youtube-dl", "--no-check-certificate", "-x", "-f", quality,
        mpu.join_path(fs.media, "%(id)s.%(ext)s")
    }

    return ydl.handle_media_download(args, url)
end

-- TODO: Should be background_process?
function ydl.handle_media_download(args, url)
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

function ydl.download_video(youtube_id)
    local format = mp.get_property("ytdl-format")
    local output_path = mpu.join_path(fs.downloads, "%(id)s.%(ext)s")

    -- LuaFormatter off
    local args = {
        "youtube-dl",
	"--no-check-certificate",
	"-f", format,
	"-o", output_path,
	youtube_id
    }
    -- LuaFormatter on

    local ret = sys.subprocess(args)
    if ret.status == 0 then
	    local downloads = mpu.readdir(fs.downloads)
	    local file = tbl.first(function(f)
		    return str.remove_ext(f) == youtube_id
	    end, downloads)
	    return mpu.join_path(fs.downloads, file)
    else
	    return nil
    end
end

function ydl.get_info(url)
    -- LuaFormatter off
    local args = {
        "youtube-dl",
	"--no-warnings",
	"--no-check-certificate",
	"-J",
	"--flat-playlist",
	url
    }
    -- LuaFormatter on

    local ret = sys.subprocess(args)
    local t = {}
    if ret.status == 0 then
	return mpu.parse_json(ret.stdout)
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
