local mpu = require 'mp.utils'
local str = require 'utils.str'
local log = require 'utils.log'
local fs = require 'systems.fs'
local mp = require 'mp'
local file = require 'utils.file'
local platforms = require 'systems.platform'

local sys = {}

local function is_win() return sys.platform == platforms.win end

function sys.already_running()
    local pid_file = mpu.join_path(fs.data, "pid_file")
    local pid = file.read_all_text(pid_file)
    return pid and sys.is_process_running(pid)
end

function sys.write_pid_file()
    local pid_file = mpu.join_path(fs.data, "pid_file")
    file.write_all_text(pid_file, mpu.getpid())
    mp.register_event("shutdown", function() file.delete(pid_file) end)
end

function sys.setup_ipc()
    local pid = tostring(mpu.getpid())
    local path
    if is_win() then
        path = [[\\.\pipe\mpv-socket-]] .. pid
    else
        path = "/tmp/mpv-socket-" .. pid
    end
    mp.set_property("input-ipc-server", path)
    mp.register_event("shutdown", function() os.remove(path) end)
end

function sys.write_to_ipc(path, data)
    local args
    if is_win() then
        local echo_data_to_pipe = table.concat({"echo", data, ">", path}, " ")
        args = {"cmd", "/c", echo_data_to_pipe}
    else
        local payload = mpu.format_json({command = str.split(data)})
        local echo_data_to_sock = "echo '" .. payload .. "' | socat - " .. path
        args = {"sh", "-c", echo_data_to_sock}
    end
    sys.background_process(args) -- TODO
end

function sys.is_process_running(pid)
    pid = tostring(pid)
    local args
    if sys.platform == "win" then
        -- LuaFormatter off
        args = {
            "powershell",
	    "-NoProfile",
	    "-Command",
	    "Get-Process -Id " .. pid
        }
	-- LuaFormatter on
    else
        args = {"ps", "-p", pid}
    end
    return sys.subprocess(args).status == 0
end

function sys.get_bkp_name(ogPath)
    local _, fname = mpu.split_path(ogPath)
    log.debug(fname)
    local no_ext = str.remove_ext(fname)
    return mpu.join_path(fs.bkp, no_ext .. tostring(os.time()) .. ".csv")
end

function sys.backup() -- TODO
    local files = {fs.extracts_data, fs.topics_data, fs.items_data}
    for _, v in pairs(files) do
        if file.exists(v) then
            log.debug("Backing up file: " .. v)
            local h1 = io.open(v, "r")
            local s = h1:read("*a")
            h1:close()

            local h2 = io.open(sys.get_bkp_name(v), "w")
            h2:write(s)
            h2:close()
        end
    end
end

function sys.verify_dependencies()
    local deps = {"youtube-dl", "ffmpeg"}
    for _, dep in pairs(deps) do
        if not sys.has_dependency(dep) then
            log.debug("Could not find dependency " .. dep ..
                          " in path. Exiting...")
            mp.commmandv("quit")
            return
        end
    end
    log.debug("All dependencies available in path.")
end

sys.platform = (function()
    local ostype = os.getenv("OSTYPE")
    if ostype and ostype == "linux-gnu" then return platforms.lnx end

    local os_env = os.getenv("OS")
    if os_env and os_env == "Windows_NT" then return platforms.win end

    -- TODO macOS

    -- taken from mpv's built-in console
    local default = {}
    if mp.get_property_native("options/vo-mmcss-profile", default) ~= default then
        return platforms.win
    elseif mp.get_property_native("options/macos-force-dedicated-gpu", default) ~=
        default then
        return platforms.mac
    end
    return platforms.lnx
end)()

sys.tmp_dir = (function()
    if is_win() then
        return os.getenv("TEMP")
    else
        local tmpdir_env = os.getenv("TMPDIR")
        if tmpdir_env then
            return tmpdir_env
        else
            return "/tmp"
        end
    end
end)()

local function handle_process_result(success, res, err)
    if not success then
        log.err("failed to run subprocess: '" .. err)
        return
    end
    return {
        ["status"] = res.status,
        ["stdout"] = res.stdout,
        ["error"] = res.error_string,
        ["killed"] = res.killed_by_us
    }
end

function sys.subprocess(args)
    local res, err = mp.command_native {
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = args
    }
    return handle_process_result(res, res, err)
end

function sys.has_dependency(dependency)
    local args
    if is_win() then
        args = {"where", "/q", dependency}
    else
        args = {"which", dependency}
    end
    local ret = sys.subprocess(args)
    return ret.status == 0
end

function sys.background_process(args, callback) -- TODO
    return mp.command_native_async({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = args
    }, function(success, res, err)
        if callback then
            callback(handle_process_result(success, res, err))
        end
    end)
end

function sys.uuid()
    local args
    if is_win() then
        -- LuaFormatter off
        args = {
            "powershell",
	    "-NoProfile",
	    "-Command",
            "[guid]::NewGuid().ToString()"
        }
	-- LuaFormatter on
    else
        -- LuaFormatter off
        args = {
            "sh",
	    "-c",
            "cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | head -c 32"
        }
	-- LuaFormatter on
    end
    local ret = sys.subprocess(args)
    if ret.status == 0 then
        return str.remove_leading_trailing_spaces(ret.stdout)
    else
        error("Failed to generate uuid with error: " .. ret.error)
    end
end

return sys
