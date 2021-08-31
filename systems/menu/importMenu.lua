local log = require 'utils.log'
local sounds = require 'systems.sounds'
local Pipeline = require 'systems.ui.input.pipeline'
local query = require 'systems.ui.input.create_input_handler'
local obj = require 'utils.object'
local mpu = require 'mp.utils'
local Base = require 'systems.menu.submenuBase'
local ydl = require 'systems.ydl'
local importer = require 'systems.importer'

local ImportSubmenu = {}
ImportSubmenu.__index = ImportSubmenu

setmetatable(ImportSubmenu, {
    __index = Base,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function ImportSubmenu:_init()
    Base._init(self)
    -- LuaFormatter off
    self.keybinds = {
        {
            key = 'i',
            desc = "import video / playlist",
            fn = function() self:query_import() end
        },
	{
            key = 'p',
            desc = "update playlists",
            fn = function() self:query_update_playlists() end
        }
    }
    -- LuaFormatter on
end

function ImportSubmenu:query_update_playlists() log.notify("TODO") end


function ImportSubmenu:add_osd(osd)
    osd:submenu("Import Menu"):newline():newline()
end

function ImportSubmenu:import_yt_playlist(args)
	-- LuaFormatter off
	if importer.import_yt_playlist(
		args["info"],
		args["split_chapters"],
		args["download"],
		args["priority-min"],
		args["priority-max"],
		args["pending_chapters"],
		args["pending_videos"],
		args["playlist_id"],
		args["playlist_title"]
	) then
		sounds.play("positive")
	else
		sounds.play("negative")
	end
	-- LuaFormatter on
end

function ImportSubmenu:import_yt_video(args)
	-- LuaFormatter off
	if importer.import_yt_video(
		args["info"],
		args["split_chapters"],
		args["download"],
		args["priority"],
		args["pending_chapters"]
	) then
		sounds.play("positive")
	else
		sounds.play("negative")
	end
	-- LuaFormatter on
end

local has_chapters = function(info) return not obj.empty(info["chapters"]) end
local run_if_has_chaps = function(state) return has_chapters(state["info"]) end
local confirmed = function(s) return s["confirm"] end

-- TODO: customize title
function ImportSubmenu:create_yt_playlist_import_pipeline()
	local p = Pipeline.new(nil, query.priority_range())
	p:then_(run_if_has_chaps, query.yn("split_chapters", "n", nil, "Split by chapter?: "))
	p:then_(run_if_has_chaps, query.yn("pending_chapters", "n", nil, "Add chapter backlog to pending queue?: "))
	p:then_(nil, query.yn("download", "n", nil, "Localize YouTube video?: "))
	p:then_(nil, query.yn("pending_videos", "y", nil, "Add playlist backlog to pending queue?: "))
	p:then_(nil, query.confirm())
	p:finally({task=function(s) self:import_yt_playlist(s) end, run_if=confirmed})
	return p
end

function ImportSubmenu:create_yt_video_import_pipeline()
	local p = Pipeline.new(nil, query.priority())
	p:then_(run_if_has_chaps, query.yn("split_chapters", "n", nil, "Split by chapter?: "))
	p:then_(run_if_has_chaps, query.yn("pending_chapters", "n", nil, "Add chapter backlog to pending queue?: "))
	p:then_(nil, query.yn("download", "n", nil, "Localize YouTube video?: "))
	p:then_(nil, query.confirm())
	p:finally({task=function(state) self:import_yt_video(state) end, run_if=confirmed})
	return p
end

function ImportSubmenu:create_local_video_import_pipeline()
	local p = Pipeline.new(nil, query.priority())
	p:then_(nil, query.confirm())
	p:finally({task=function(state) self:import_local_video(state) end, run_if=confirmed})
	return p
end

function ImportSubmenu:create_local_dir_import_pipeline()
	local p = Pipeline.new(nil, query.priority_range())
	p:then_(nil, query.confirm())
	p:finally({task=function(state) self:import_local_directory(state) end, run_if=confirmed})
	return p
end

function ImportSubmenu:choose_import_pipeline(state)
	local url = state["url"]
        local fileinfo, _ = mpu.file_info(url)
	local pipeline
        if fileinfo then
            if fileinfo["is_file"] then
                pipeline = self:create_local_video_import_pipeline()
            elseif fileinfo["is_dir"] then
                pipeline = self:create_local_dir_import_pipeline()
            end
        else
	    log.notify("Grabbing YouTube info.")
	    local yt_info = ydl.get_info(url)
	    if obj.empty(yt_info) then
		log.notify("Failed to download YouTube info.")
		return
	    end

	    state["info"] = yt_info
	    if #yt_info > 1 then
		    log.notify("Playlist info found.")
		    state["playlist"] = url:gmatch("%?list=(.+)")()
		    state["title"] = ydl.get_playlist_title(state["playlist"])
		    pipeline = self:create_yt_playlist_import_pipeline()
	    else
		    log.notify("Video info found.")
		    pipeline = self:create_yt_video_import_pipeline()
	    end
        end

	pipeline:run(state)
end

function ImportSubmenu:query_import()
	local p = Pipeline.new(nil, query.string("url", nil, nil, "Enter a file, folder or youtube link: "))
	p:finally({task=function(s) self:choose_import_pipeline(s) end})
	p:run({})
end

return ImportSubmenu
