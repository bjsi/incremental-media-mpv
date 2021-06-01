local sys = require("systems.system")
local mpu = require("mp.utils")
local log = require("utils.log")
local cfg = require("systems.config")

local curl = {}

curl.tmpfile = mpu.join_path(sys.tmp_dir, "mpv-iv-curl.json")

curl.telnet = function(json, cb)
    local handle = io.open(curl.tmpfile, "w")
    if handle == nil then
        log.err("Failed to curl because the tmpfile could not be written to.")
        return false
    end

    handle:write(json)
    handle:close()

    local script = "./curl_telnet"
    if sys.platform == "win" then script = script .. ".bat" end
    local args = {
        script,
        cfg.host,
        cfg.port,
        curl.tmpfile
    }

    return sys.background_process(args, cb)
end
