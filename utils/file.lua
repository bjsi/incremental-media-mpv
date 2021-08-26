local mpu = require 'mp.utils'
local log = require 'utils.log'

local file = {}

function file.exists(f)
	local info, _ = mpu.file_info(f)
	if not info then
		return false
	end
	return info.is_file
end

function file.copy(from, to)
    local fromFile = io.open(from, "r")
    if fromFile == nil then
        log.debug("Failed to read " .. to)
        return false
    end

    local fromData = fromFile:read("*a")
    fromFile:close()

    local toFile = io.open(to, "w")
    if toFile == nil then
        log.debug("Failed to write to " .. to)
        return false
    end

    toFile:write(fromData)
    toFile:close()
    return true
end

function file.read_all_text(path)
    local h = io.open(path, "r")
    local data
    if h ~= nil then data = h:read("*all") end
    return data
end

function file.write_all_text(path, data)
    local h = io.open(path, "w")
    if h == nil then return end
    h:write(data)
    h:close()
end

function file.delete(f)
    os.remove(f)
end

return file
