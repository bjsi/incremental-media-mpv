local mpu = require("mp.utils")
local ext = require "utils.ext"
local mpopts = require("mp.options")

local settings = {
    ["queue"] = "main"
}

mpopts.read_options(settings, "im")

local fs = {}

fs.base = mp.get_script_directory()
fs.media = mpu.join_path(fs.base, "media")
fs.sine = mpu.join_path(fs.media, "sine.opus")
fs.data_base = mpu.join_path(fs.base, "data")
fs.data = mpu.join_path(fs.data_base, settings["queue"])
fs.bkp = mpu.join_path(fs.data, "bkp")
fs.topics_data = mpu.join_path(fs.data, "topics.csv")
fs.extracts_data = mpu.join_path(fs.data, "extracts.csv")
fs.items_data = mpu.join_path(fs.data, "items.csv")
fs.sounds = mpu.join_path(fs.base, "sounds")

return fs
