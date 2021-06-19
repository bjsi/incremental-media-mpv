local mpu = require("mp.utils")
local fs = require("systems.fs")
local sys = require("systems.system")

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

-- TODO: Keep a background process to run sounds
sounds.play = function(sound)
    local fp = mpu.join_path(fs.sounds, sounds.files[sound])
    local args = {"mpv", "--no-video", "--really-quiet", fp}
    sys.background_process(args)
end

return sounds
