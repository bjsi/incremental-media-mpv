local base64 = require 'utils.base64'
local date = require 'utils.date'
local str = require 'utils.str'
local file = require 'utils.file'
local path = require 'utils.path'

-- provides access to most of the utility objects for convenience

local utils = {}

utils.base64 = base64
utils.date = date
utils.file = file
utils.str = str
utils.path = path

return utils
