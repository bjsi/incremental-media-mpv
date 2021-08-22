package.path = mp.command_native({"expand-path", "~~/script-modules/?.lua;"}) ..
                   package.path
local ui = require "user-input-module"
local get_user_input = ui.get_user_input
return get_user_input
