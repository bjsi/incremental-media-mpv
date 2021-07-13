-- From: https://github.com/Ben-Kerman/immersive/blob/master/systems/encoder.lua

local sys = require("systems.system")
local log = require("utils.log")
local cfg = require("systems.config")

local function calc_dimension(cfg_val, prop_name)
	if cfg_val < 0 then return -2 end
	local prop = mp.get_property_number(prop_name)
	return cfg_val < prop and cfg_val or prop
end

local function encode(args, path)
	local start_time = mp.get_time()
	sys.background_process(args, function(status, stdout, error_string, killed_by_us)
		if status and status ~= 0 then
			log.err(string.format("encoding failed: '%s'", path))
			log.debug("exit code: " .. status .. "; stdout: " .. stdout)
		end

		log.debug(string.format("encoded '%s' in %f s", path, mp.get_time() - start_time))
	end)
end

local encoder = {}

function encoder.any_audio(params)
	local args = {
		"mpv",
		params.src_path,
		"--o=" .. params.tgt_path,
		"--no-ocopy-metadata",
		"--vid=no",
		"--aid=" .. (params.track or "1"),
		"--sid=no",
		"--of=" ..params. format,
		"--oac=" .. params.codec,
		"--oacopts=b=" .. params.bitrate
	}
	if params.start then table.insert(args, "--start=" .. params.start) end
	if params.stop then table.insert(args, "--end=" .. params.stop) end

	encode(args, params.tgt_path)
end

function encoder.audio(path, start, stop)
	encoder.any_audio{
		src_path = helper.current_path_abs(),
		tgt_path = path,
		track = mp.get_property("aid"),
		format = cfg.format,
		codec = cfg.codec,
		bitrate = cfg.bitrate,
		start = start,
		stop = stop,
	}
end

function encoder.image(path, time)
	local width = calc_dimension(cfg.max_width, "width")
	local height = calc_dimension(cfg.max_height, "height")

	local args = {
		"mpv",
		helper.current_path_abs(),
		"--o=" .. path,
		"--no-ocopy-metadata",
		"--vid=" .. mp.get_property("vid"),
		"--aid=no",
		"--sid=no",
		"--start=" .. time,
		"--frames=1",
		"--of=image2",
		"--ovc=" .. cfg.codec,
		"--vf-add=scale=" .. width .. ":" .. height
	}

	if cfg.codec == "mjpeg" then
		table.insert(args, "--ovcopts-add=qmin=" .. cfg.jpeg.qscale)
		table.insert(args, "--ovcopts-add=qmax=" .. cfg.jpeg.qscale)
	elseif cfg.codec == "libwebp" then
		table.insert(args, "--ovcopts-add=lossless=" .. (cfg.webp.lossless and 1 or 0))
		table.insert(args, "--ovcopts-add=compression_level=" .. cfg.webp.compression)
		table.insert(args, "--ovcopts-add=quality=" .. cfg.webp.quality)
	elseif cfg.codec == "png" then
		table.insert(args, "--ovcopts-add=compression_level=" .. cfg.png.compression)
	end

	encode(args, path)
end

return encoder