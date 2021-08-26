local mpu = require("mp.utils")
local mp = require 'mp'
local fs = require("systems.fs")
local sys = require("systems.system")
local log = require("utils.log")

local sounds = {
    files = {
        negative = "negative.wav",
        click1 = "click.wav",
        click2 = "click_2.wav",
        load = "load.wav",
        positive = "positive.wav",
        echo = "sharp_echo.wav",
        delete = "misc_menu_2.wav",
        global_topic_queue = "global_topic_queue.wav",
        global_extract_queue = "global_extract_queue.wav",
        local_extract_queue = "local_extract_queue.wav",
        global_item_queue = "global_item_queue.wav",
        local_item_queue = "local_item_queue.wav"
    }
}

local pid = tostring(mpu.getpid())
local pipeOrSock
if sys.platform == "win" then
	pipeOrSock = [[\\.\pipe\background-sounds]] .. pid
else
	pipeOrSock = "/tmp/background-sounds" .. pid .. ".sock"
end

sounds.start_background_process = function()
    -- LuaFormatter off
    local args = {
        "mpv",
	"--no-video",
	"--really-quiet",
	"--idle=yes", -- keeps it running after playing files.
        "--input-ipc-server=" .. pipeOrSock
    }
    -- LuaFormatter on

    log.debug("Starting background sounds process.")
    sys.background_process(args)

    -- on exit, send command to quit
    mp.register_event("shutdown", function()
        log.debug("Killing background sounds process.")
        sys.write_to_ipc(pipeOrSock, "quit")
    end)
end

sounds.play = function(sound)
    local fp = mpu.join_path(fs.sounds, sounds.files[sound])
    sys.write_to_ipc(pipeOrSock, "loadfile " .. fp)
end

-- TODO: write to background_process pipe
sounds.play_sync = function(sound)
    local fp = mpu.join_path(fs.sounds, sounds.files[sound])
    local args = {"mpv", "--no-video", "--really-quiet", fp}
    sys.subprocess(args)
end

return sounds
