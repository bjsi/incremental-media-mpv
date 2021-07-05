local ext = require("utils.ext")

local Rep = {}
Rep.__index = Rep

setmetatable(Rep, {
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function Rep:_init(row) self.row = row end

function Rep:is_deleted()
    if self:is_yt() then
        return false
    elseif self:is_local() then
        return not ext.file_exists(self.row["url"])
    end
end

function Rep:type()
    error("override me!")
end

function Rep:is_dismissed()
    return self.row["dismissed"] == 1
end

function Rep:is_yt() return self.row["type"] == "youtube" end

function Rep:is_local() return self.row["type"] == "local" end

function Rep:valid_speed() 
    local speed = tonumber(self.row["speed"])
    return speed ~= nil and speed > 0 and speed < 5
end

function Rep:valid_stop()
    return tonumber(self.row["stop"]) ~= nil
end

function Rep:valid_start()
    return tonumber(self.row["start"]) ~= nil
end

return Rep
