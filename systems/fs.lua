local mpu = require("mp.utils")
local mpopts = require("mp.options")

local settings = {
    ["start"] = false,
    ["import"] = "",
    ["queue"] = "main",
    ["export"] = "",
}

mpopts.read_options(settings, "im")

local fs = {}

fs.base = mp.get_script_directory()
fs.data_base = mpu.join_path(fs.base, "data")
fs.data = mpu.join_path(fs.data_base, settings["queue"])
fs.media = mpu.join_path(fs.data, "media")
fs.bkp = mpu.join_path(fs.data, "bkp")
fs.topics_data = mpu.join_path(fs.data, "topics.csv")
fs.extracts_data = mpu.join_path(fs.data, "extracts.csv")
fs.items_data = mpu.join_path(fs.data, "items.csv")
fs.sounds = mpu.join_path(fs.base, "sounds")
fs.sine = mpu.join_path(fs.media, "sine.mp3")
fs.sine_base = mpu.join_path(fs.sounds, "sine.mp3")
fs.meaning_zh_base = mpu.join_path(fs.sounds, "meaning_zh.mp3")
fs.meaning_zh = mpu.join_path(fs.media, "meaning_zh.mp3")

return fs
