local mpopt = require 'mp.options'

local config = {}

-- TODO: add to docs
-- Config options can be set directly in this file, passed on the command line
-- or stored in a separate config file.
-- CLI example: mpv --script-opts=imconf-auto_export=yes,imconf-audio_format=mp3
-- Config path: ~/.config/mpv/script-opts/???.conf
-- Config file isn't created automatically.
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

mpopt.read_options(config, "imconf")

return config
