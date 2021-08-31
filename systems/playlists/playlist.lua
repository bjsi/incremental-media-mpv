local Playlist = {}
Playlist.__index = Playlist

setmetatable(Playlist, {
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function Playlist:_init(row) self.row = row end

function Playlist:type() return "playlist" end

function Playlist:is_dismissed() return self.row["dismissed"] == "1" end

function Playlist:is_yt() return self.row["type"] == "youtube" end

function Playlist:is_local() return self.row["type"]:find("local") end

function Playlist:last_updated() return self.row["updated"] end

return Playlist
