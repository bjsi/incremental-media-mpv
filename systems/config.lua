local mpopt = require('mp.options')

local config = {}

config.auto_export = true
config.menu_font_size = 24
config.default_priority_min = 20
config.default_priority_max = 60
config.audio_format = "mp3" -- mp3
config.audio_codec = "libmp3lame"
config.image_format = "jpg"
config.sma_server_host = "127.0.0.1"
config.sma_server_port = 9898
config.cloze_auto_add_screenshot = false

-- Settings generally passed in script-opts

config.start = false
config.import = ""
config.queue = "main"
config.mode = "master"
config.export = ""
config.add_extract = ""
config.singleton_type = ""
config.singleton_id = ""

mpopt.read_options(config, "im")

return config
