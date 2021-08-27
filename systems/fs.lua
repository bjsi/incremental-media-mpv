local mpu = require 'mp.utils'
local options = require 'systems.options'
local mp = require 'mp'

local fs = {}

fs.base = mp.get_script_directory()
fs.assets = mpu.join_path(fs.base, 'assets')
fs.scripts = mpu.join_path(fs.base, 'scripts')
fs.data_base = mpu.join_path(fs.base, 'data')
fs.data = mpu.join_path(fs.data_base, options.queue)
fs.media = mpu.join_path(fs.data, 'media')
fs.bkp = mpu.join_path(fs.data, 'bkp')
fs.topics_data = mpu.join_path(fs.data, 'topics.csv')
fs.extracts_data = mpu.join_path(fs.data, 'extracts.csv')
fs.items_data = mpu.join_path(fs.data, 'items.csv')
fs.sounds = mpu.join_path(fs.assets, 'sounds')
fs.images = mpu.join_path(fs.assets, 'images')
fs.edl = mpu.join_path(fs.assets, 'edl')
fs.sine = mpu.join_path(fs.media, 'sine.mp3')
fs.sine_base = mpu.join_path(fs.sounds, 'sine.mp3')
fs.meaning_zh_base = mpu.join_path(fs.sounds, 'meaning_zh.mp3')
fs.meaning_zh = mpu.join_path(fs.media, 'meaning_zh.mp3')
fs.silence_base = mpu.join_path(fs.sounds, 'silence.mp3')
fs.silence = mpu.join_path(fs.media, 'silence.mp3')
fs.splashscreen = mpu.join_path(fs.edl, 'splashscreen.edl')

return fs
