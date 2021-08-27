local mpopt = require 'mp.options'
local cfg = require 'systems.config'

local options = {}

-- Settings generally passed in script-opts
options.mode = ""
options.path = ""
options.queue = cfg.default_queue
options.type = ""
options.id = ""

mpopt.read_options(options, "im")

return options
