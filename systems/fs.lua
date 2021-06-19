local mpu = require("mp.utils")

local fs = {}

fs.base = mp.get_script_directory()
fs.media = mpu.join_path(fs.base, "media")
fs.data = mpu.join_path(fs.base, "data")
fs.bkp = mpu.join_path(fs.data, "bkp")
fs.topics_data = mpu.join_path(fs.data, "topics.csv")
fs.extracts_data = mpu.join_path(fs.data, "extracts.csv")
fs.items_data = mpu.join_path(fs.data, "items.csv")
fs.sounds = mpu.join_path(fs.base, "sounds")

return fs
