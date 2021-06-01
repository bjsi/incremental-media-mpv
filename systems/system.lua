local mpu = require("mp.utils")
local log = require("utils.log")

-- mostly from: https://github.com/Ben-Kerman/immersive/blob/master/systems/system.lua

local system = {}

function system.verify_dependencies()
    local deps = { "youtube-dl", "ffmpeg" }
    for _, dep in pairs(deps) do
        if not system.has_dependency(dep) then
            log.debug("Could not find dependency " .. dep .. " in path. Exiting...")
            mp.commmandv("exit")
            return
        end
    end
    log.debug("All dependencies available in path.")
end

system.platform = (function()
	local ostype = os.getenv("OSTYPE")
	if ostype and ostype == "linux-gnu" then
		return "lnx"
	end

	local os_env = os.getenv("OS")
	if os_env and os_env == "Windows_NT" then
		return "win"
	end

	-- TODO macOS

	-- taken from mpv's built-in console
	local default = {}
	if mp.get_property_native("options/vo-mmcss-profile", default) ~= default then
		return "win"
	elseif mp.get_property_native("options/macos-force-dedicated-gpu", default) ~= default then
		return "mac"
	end
	return "lnx"
end)()

system.tmp_dir = (function()
	if system.platform == "lnx" or system.platform == "mac" then
		local tmpdir_env = os.getenv("TMPDIR")
		if tmpdir_env then return tmpdir_env
		else return "/tmp" end
	elseif system.platform == "win" then
		return os.getenv("TEMP")
	end
end)()

local function handle_process_result(success, res, err)
	if not success then
		log.err("failed to run subprocess: '" .. err .. "'; arguments: " .. mpu.format_json(args))
		return
	end
	return res.status, res.stdout, res.error_string, res.killed_by_us
end

function system.subprocess(args)
	local res, err = mp.command_native{
		name = "subprocess",
		playback_only = false,
		capture_stdout = true,
		args = args
	}
	return handle_process_result(res, res, err)
end

-- TODO: Check
function system.has_dependency(dependency)
    local args = {
        "which",
    }
    if system.platform == "win" then table.insert(args, "/q") end
    table.insert(args, dependency)
    local ret = system.subprocess(args)
    return ret.status == 0
end

function system.file2base64(fp)
    local script = "./file2base64"
    if system.platform == "win" then script = script .. ".bat" end
    local args = {
        script,
        fp
    }
    return system.subprocess(args)
end

function system.background_process(args, callback)
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

function system.list_files(dir)
	return mpu.readdir(dir, "files")
end

function system.create_dir(path)
	local stat_res = mpu.file_info(path)
	if stat_res then
		return stat_res.is_dir
	end

	local args
	if system.platform == "lnx" or system.platform == "mac" then
		args = {"mkdir", "-p", path}
	elseif system.platform == "win" then
		args = {"cmd", "/d", "/c", "mkdir", (path:gsub("/", "\""))}
	end
	return system.subprocess(args) == 0
end

function system.move_file(src_path, tgt_path)
	local cmd
	if system.platform == "lnx" or system.platform == "mac" then
		cmd = "mv"
	elseif system.platform == "win" then
		cmd = "move"
	end
	return system.subprocess{cmd, src_path, tgt_path} == 0
end

local ps_clip_write_fmt = "Set-Clipboard ([Text.Encoding]::UTF8.GetString((%s)))"
local function ps_clip_write(str)
	local bytes = {}
	for i = 1, #str do
		table.insert(bytes, (str:byte(i)))
	end
	return string.format(ps_clip_write_fmt, table.concat(bytes, ","))
end

local ps_clip_read = [[
Add-Type -AssemblyName System.Windows.Forms
$clip = [Windows.Forms.Clipboard]::GetText()
$utf8 = [Text.Encoding]::UTF8.GetBytes($clip)
[Console]::OpenStandardOutput().Write($utf8, 0, $utf8.length)]]

function system.clipboard_read()
	if system.platform == "mac" then
		local pipe = io.popen("LANG=en_US.UTF-8 pbpaste", "r")
		local clip = pipe:read("*a")
		pipe:close()
		return clip
	else
		local args
		if system.platform == "lnx" then
			args = {"xclip", "-out", "-selection", "clipboard"}
		elseif system.platform == "win" then
			args = {"powershell", "-NoProfile", "-Command", ps_clip_read}
		end

		local status, clip, err_str = system.subprocess(args)
		if status == 0 then return clip
		else return false, err_str end
	end
end

function system.clipboard_write(str)
	if system.platform == "lnx" or system.platform == "mac" then
		local cmd
		if system.platform == "lnx" then
			cmd = "xclip -in -selection clipboard"
		else cmd = "LANG=en_US.UTF-8 pbcopy" end

		local pipe = io.popen(cmd, "w")
		pipe:write(str)
		pipe:close()
	elseif system.platform == "win" then
        system.background_process{"powershell", "-NoProfile", "-Command", ps_clip_write(str)}
	end
end

function system.set_primary_sel(str)
	if system.platform ~= "lnx" then
		log.err("Primary selection is only available in X11 environments")
		return
	end

	local pipe = io.popen("xclip -in -selection primary", "w")
	pipe:write(str)
	pipe:close()
end

return system
