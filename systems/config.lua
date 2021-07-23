local mpopt = require('mp.options')
local sys = require("systems.system")

local config = {}

config.menu_font_size = 24
config.default_priority_min = 20
config.default_priority_max = 60

config.audio = {
    format = "mp3", -- mp3
    bitrate = "18k", -- from 16k to 32k
    padding = 0.12, -- Pad dialog timings. 0.5 = audio is padded by .5 seconds. 0 = disable.
    tie_volumes = false -- if true, volume of audio output == volume of player at time of export
}

config.obsidian = {}

config.supermemo = {}

config.set_networking = function()
    if next(config.supermemo) ~= nil then
        config.port = config.supermemo.port
        config.host = config.supermemo.host
    elseif next(config.obsidian) ~= nil then
        config.port = config.obsidian.port
        config.host = config.obsidian.host
    end
end

config.opus_supported = function()
    local ret = sys.subprocess {'mpv', '--oac=help'}
    return ret.status == 0 and ret.stdout:match('--oac=libopus')
end

config.set_audio_format = function()
    if config.audio.format == 'opus' and config.opus_supported() then
        config.audio.codec = 'libopus'
        config.audio.extension = '.ogg'
    else
        config.audio.codec = 'libmp3lame'
        config.audio.extension = '.mp3'
    end
end

mpopt.read_options(config.supermemo, "supermemo-iv")
mpopt.read_options(config.obsidian, "obsidian-iv")
config.set_audio_format()
config.set_networking()

return config
