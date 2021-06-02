local mpu = require("mp.utils")

local fs = {}

fs.base = mp.get_script_directory()
fs.media = mpu.join_path(fs.base, "media")
fs.data = mpu.join_path(fs.base, "data")
fs.topic_data = mpu.join_path(fs.data, "topics.csv")
fs.sounds = mpu.join_path(fs.base, "sounds")

return fs
