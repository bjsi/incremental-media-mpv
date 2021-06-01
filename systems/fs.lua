local mpu = require("mp.utils")

local fs = {}

fs.base = mp.get_script_directory()
fs.media = mpu.join_path(fs.base, "media")
fs.data = mpu.join_path(fs.base, "data")
fs.db = mpu.join_path(fs.data, "data.csv")

return fs
