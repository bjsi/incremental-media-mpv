local mpu = require("mp.utils")
local str = require("utils.str")
local log = require("utils.log")
local fs = require("systems.fs")
local ext = require "utils.ext"

-- mostly from: https://github.com/Ben-Kerman/immersive/blob/master/systems/system.lua

local sys = {}

function sys.create_essential_files()
    local folders = {fs.data, fs.media, fs.bkp}
    for _, folder in pairs(folders) do
        if not sys.exists(folder) then
            if not sys.create_dir(folder) then
                log.debug("Could not create essential folder: " .. folder ..
                              ". Exiting...")
                mp.commmandv("exit")
                return false
            end
        end
    end

    if not ext.file_exists(fs.sine) then
        sys.copy(fs.sine_base, fs.sine)
    end

    if not ext.file_exists(fs.meaning_zh) then
        sys.copy(fs.meaning_zh_base, fs.meaning_zh)
    end
end

function sys.get_bkp_name(ogPath)
    local _, fname = mpu.split_path(ogPath)
    log.debug(fname)
    local no_ext = str.remove_ext(fname)
    return mpu.join_path(fs.bkp, no_ext .. tostring(os.time()) .. ".csv")
end

function sys.backup()
    local files = {fs.extracts_data, fs.topics_data, fs.items_data}
    for _, v in pairs(files) do
        if sys.exists(v) then
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

--- Check if a file or directory exists in this path
function sys.exists(file)
    local ok, err, code = os.rename(file, file)
    if not ok then
        if code == 13 then
            -- Permission denied, but it exists
            return true
        end
    end
    return ok, err
end

function sys.verify_dependencies()
    local deps = {"youtube-dl", "ffmpeg"}
    for _, dep in pairs(deps) do
        if not sys.has_dependency(dep) then
            log.debug("Could not find dependency " .. dep ..
                          " in path. Exiting...")
            mp.commmandv("exit")
            return
        end
    end
    log.debug("All dependencies available in path.")
end

function sys.copy(from, to)
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

sys.platform = (function()
    local ostype = os.getenv("OSTYPE")
    if ostype and ostype == "linux-gnu" then return "lnx" end

    local os_env = os.getenv("OS")
    if os_env and os_env == "Windows_NT" then return "win" end

    -- TODO macOS

    -- taken from mpv's built-in console
    local default = {}
    if mp.get_property_native("options/vo-mmcss-profile", default) ~= default then
        return "win"
    elseif mp.get_property_native("options/macos-force-dedicated-gpu", default) ~=
        default then
        return "mac"
    end
    return "lnx"
end)()

sys.tmp_dir = (function()
    if sys.platform == "lnx" or sys.platform == "mac" then
        local tmpdir_env = os.getenv("TMPDIR")
        if tmpdir_env then
            return tmpdir_env
        else
            return "/tmp"
        end
    elseif sys.platform == "win" then
        return os.getenv("TEMP")
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
    local args = sys.platform == "win" and {"where", "/q"} or {"which"}
    table.insert(args, dependency)
    local ret = sys.subprocess(args)
    return ret.status == 0
end

function sys.file2base64(fp)
    local script = "./file2base64"
    if sys.platform == "win" then script = script .. ".bat" end
    local args = {script, fp}
    return sys.subprocess(args)
end

-- TODO: test: join_path should return url if it is absolute
function sys.is_absolute_path(url)
    return mpu.join_path("testing", url) == url
end

function sys.background_process(args, callback)
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

function sys.list_files(dir) return mpu.readdir(dir, "files") end

function sys.create_dir(path)
    local stat_res = mpu.file_info(path)
    if stat_res then return stat_res.is_dir end

    local args
    if sys.platform == "lnx" or sys.platform == "mac" then
        args = {"mkdir", "-p", path}
    elseif sys.platform == "win" then
        args = {"cmd", "/d", "/c", "mkdir", (path:gsub("/", "\""))}
    end
    return sys.subprocess(args).status == 0
end

function sys.move_file(src_path, tgt_path)
    local cmd
    if sys.platform == "lnx" or sys.platform == "mac" then
        cmd = "mv"
    elseif sys.platform == "win" then
        cmd = "move"
    end
    return sys.subprocess {cmd, src_path, tgt_path} == 0
end

local ps_clip_write_fmt =
    "Set-Clipboard ([Text.Encoding]::UTF8.GetString((%s)))"
local function ps_clip_write(str)
    local bytes = {}
    for i = 1, #str do table.insert(bytes, (str:byte(i))) end
    return string.format(ps_clip_write_fmt, table.concat(bytes, ","))
end

local ps_clip_read = [[
Add-Type -AssemblyName System.Windows.Forms
$clip = [Windows.Forms.Clipboard]::GetText()
$utf8 = [Text.Encoding]::UTF8.GetBytes($clip)
[Console]::OpenStandardOutput().Write($utf8, 0, $utf8.length)]]

function sys.clipboard_read()
    if sys.platform == "mac" then
        local pipe = io.popen("LANG=en_US.UTF-8 pbpaste", "r")
        local clip = pipe:read("*a")
        pipe:close()
        return clip
    else
        local args
        if sys.platform == "lnx" then
            args = {"xclip", "-out", "-sel", "clipboard"}
        elseif sys.platform == "win" then
            args = {"powershell", "-NoProfile", "-Command", ps_clip_read}
        end

        local ret = sys.subprocess(args)
        if ret.status == 0 then
            return ret.stdout
        else
            return false, ret.error
        end
    end
end

function sys.uuid()
    local args
    if sys.platform == "lnx" or sys.platform == "mac" then
        args = { "sh", "-c", "cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | head -c 32" }
    elseif sys.platform == "win" then
        args = {"powershell", "-NoProfile", "-Command", "[guid]::NewGuid().ToString()"}
    end
    local ret = sys.subprocess(args)
    if ret.status == 0 then
        return str.remove_leading_trailing_spaces(ret.stdout)
    else 
        error("Failed to generate uuid with error: " .. ret.error)
    end
end

function sys.clipboard_write(str)
    if sys.platform == "lnx" or sys.platform == "mac" then
        local cmd
        if sys.platform == "lnx" then
            cmd = "xclip -in -selection clipboard"
        else
            cmd = "LANG=en_US.UTF-8 pbcopy"
        end

        local pipe = io.popen(cmd, "w")
        pipe:write(str)
        pipe:close()
    elseif sys.platform == "win" then
        sys.background_process {
            "powershell", "-NoProfile", "-Command", ps_clip_write(str)
        }
    end
end

function sys.set_primary_sel(str)
    if sys.platform ~= "lnx" then
        log.err("Primary selection is only available in X11 environments")
        return
    end

    local pipe = io.popen("xclip -in -selection primary", "w")
    pipe:write(str)
    pipe:close()
end

return sys
