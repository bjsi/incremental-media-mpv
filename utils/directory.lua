local mpu = require 'mp.utils'
local sys = require 'systems.system'
local platforms = require 'systems.platform'

local dir = {}

function dir.exists(f)
	local info, _ = mpu.file_info(f)
	if not info then
		return false
	end
	return info.is_dir
end

function dir.create(path)
    local stat_res = mpu.file_info(path)
    if stat_res then return stat_res.is_dir end
    local args
    if sys.platform == platforms.lnx or sys.platform == platforms.mac then
        args = {"mkdir", "-p", path}
    elseif sys.platform == platforms.win then
        args = {"cmd", "/d", "/c", "mkdir", (path:gsub("/", "\""))}
    end
    return sys.subprocess(args).status == 0
end

return dir
