local mpopt = require 'mp.options'
local mode = require 'systems.mode'

local options = {}

-- Settings generally passed in script-opts
options.mode = mode.master
options.path = ""
options.queue = "main"
options.type = ""
options.id = ""

mpopt.read_options(options, "im")

return options
