local utils = require("mp.utils")
local basedir = mp.get_script_directory()
local soundsdir = utils.join_path(basedir, "sounds")

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
        local_item_queue = "local_item_queue.wav",
    }
}

sounds.play = function(sound)
    local fp = utils.join_path(soundsdir, sounds.files[sound])
    local args = {
        "mpv",
        "--no-video",
        "--really-quiet",
        fp
    }
    subprocess(args, function() end)
end
