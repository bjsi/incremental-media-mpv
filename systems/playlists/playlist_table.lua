local default_header = require 'systems.playlists.playlist_header'
local log = require 'utils.log'
local str = require 'utils.str'
local CSVDB = require 'db.csv'
local MarkdownDB = require 'db.md'
local Playlist = require 'systems.playlists.playlist'
local fs = require 'systems.fs'

local PlaylistTable = {}
PlaylistTable.__index = PlaylistTable

setmetatable(PlaylistTable, {
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function PlaylistTable:_init()
	self.default_header = default_header
	self.db = self:create_db(fs.playlists_data, self.default_header)
	self:read_reps()
end

function PlaylistTable:create_db(fp, header)
    local extension = str.get_extension(fp)
    local db = nil
    if extension == "md" then
        db = MarkdownDB(fp, header)
    elseif extension == "csv" then
        db = CSVDB(fp, header)
    else
        local x = "Unrecognised database file extension."
        log.err(x)
        error(x)
    end
    return db
end

function PlaylistTable:write() return self.db:write(self) end

function PlaylistTable:read_reps()
    local as_playlist_objects = function(row) return Playlist(row) end
    local header, reps = self.db:read_reps(as_playlist_objects)
    if reps then
        self.reps = reps
    else
        self.reps = {}
    end
    if header then
        self.header = header
    else
        self.header = self.default_header
    end
end

function PlaylistTable:add(playlist)
    self.reps[#self.reps + 1] = playlist
    return self:write()
end

return PlaylistTable
