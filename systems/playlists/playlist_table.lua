local default_header = require 'systems.playlists.playlist_header'
local log = require 'utils.log'
local str = require 'utils.str'
local CSVDB = require 'db.csv'
local MarkdownDB = require 'db.md'
local Playlist = require 'systems.playlists.playlist'
local fs = require 'systems.fs'

local PlaylistTable = {}
PlaylistTable.__index = PlaylistTable

function PlaylistTable:_init()
	self.default_header = default_header
	self.db = self:create_db(fs.playlists_data, self.default_header)
	self:read_playlists()
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

function PlaylistTable:read_playlists()
    local as_playlist_objects = function(row) return Playlist(row) end
    local header, playlists = self.db:read_reps(as_playlist_objects)
    if playlists then
        self.playlists = playlists
    else
        self.playlists = {}
    end
    if header then
        self.header = header
    else
        self.header = self.default_header
    end
end

function PlaylistTable:add(playlist)
    self.reps[#self.playlists + 1] = playlist
    return self:write()
end


return Playlist
