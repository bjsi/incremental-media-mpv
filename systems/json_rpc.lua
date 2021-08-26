local mpu = require 'mp.utils'
local fs = require 'systems.fs'
local file = require 'utils.file'
local log = require 'utils.log'
local sys = require 'systems.system'

local json_rpc = {}

local function format_request(method, params)
	return mpu.format_json({id = 1, method = method, params = params})
end

function json_rpc.send_request(host, port, method, params)
    local payload = format_request(method, params)
    if not payload then
        log.debug("Invalid json.")
        return nil
    end

    -- write the payload to a file before sending to avoid
    -- character escaping issues from sending directly on
    -- the command line.
    local payload_file = mpu.join_path(sys.tmp_dir, "body.json")
    if not file.write_all_text(payload_file, payload) then
	    log.debug("Failed to write json to temporary file.")
	    return nil
    end

    local args
    if sys.platform == "win" then
        local curl_script = mpu.join_path(fs.scripts, "curl_telnet.bat")
	args = {curl_script, host, port, payload_file}
    else
        local curl_script = mpu.join_path(fs.scripts, "curl_telnet.sh")
	args = {curl_script, host, port, payload_file}
    end
    return sys.subprocess(args) -- TODO
end

return json_rpc
