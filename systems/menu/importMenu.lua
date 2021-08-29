local log = require 'utils.log'
local Pipeline = require 'systems.ui.input.pipeline'
local query = require 'systems.ui.input.create_input_handler'
local obj = require 'utils.object'
local mpu = require 'mp.utils'
local Base = require 'systems.menu.submenuBase'
local ydl = require 'systems.ydl'
local importer = require 'systems.importer'
local sounds = require 'systems.sounds'

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
	log.debug(args)
	--local topics = importer.create_yt_topics(args["infos"],
	--args["split-chapters"],
	--args["download"],
	--args["priority-min"],
	--args["priority-max"], true -- TODO: dependencyImport
	--)

	--if obj.empty(topics) then
	--	log.notify("Failed to create topics.")
	--	return
	--end

	--if importer.add_topics_to_queue(topics) then
	--	sounds.play("positive")
	--else
	--	sounds.play("negative")
	--end
end

function ImportSubmenu:import_yt_video(args)
	log.debug(args)
	--local topics = importer.create_yt_topics(args["infos"],
	--args["split-chapters"],
	--args["download"],
	--args["priority-min"],
	--args["priority-max"], true -- TODO: dependencyImport
	--)

	--if obj.empty(topics) then
	--	log.notify("Failed to create topics.")
	--	return
	--end

	--if importer.add_topics_to_queue(topics) then
	--	sounds.play("positive")
	--else
	--	sounds.play("negative")
	--end
end

function ImportSubmenu:create_yt_playlist_import_pipeline()
	local p = Pipeline.new(query.priority_range())
	p:then_(query.yn("split", "n", nil, "Split by chapter if available?: "))
	p:then_(query.yn("download", "n", nil, "Localize YouTube video?: "))
	p:then_(query.confirm())
	p:finally(function(state) self:import_yt_playlist(state) end)
	return p
end

function ImportSubmenu:create_yt_video_import_pipeline()
	local p = Pipeline.new(query.priority())
	p:then_(query.yn("split", "n", nil, "Split by chapter if available?: "))
	p:then_(query.yn("download", "n", nil, "Localize YouTube video?: "))
	p:then_(query.confirm())
	p:finally(function(state) self:import_yt_video(state) end)
	return p
end

function ImportSubmenu:create_local_video_import_pipeline()
	local p = Pipeline.new(query.priority())
	p:then_()
	p:then_(query.confirm())
	p:finally()
	return p
end

function ImportSubmenu:create_local_dir_import_pipeline()
	local p = Pipeline.new(query.priority_range())
	p:then_()
	p:then_(query.confirm())
	p:finally()
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
		    pipeline = self:create_yt_playlist_import_pipeline()
	    else
		    log.notify("Video info found.")
		    pipeline = self:create_yt_video_import_pipeline()
	    end
        end

	pipeline:run(state)
end

function ImportSubmenu:query_import()
	local p = Pipeline.new(query.string("url", nil, nil, "Enter a file, folder or youtube link: "))
	p:finally(function(state) self:choose_import_pipeline(state) end)
	p:run({})
end

return ImportSubmenu
