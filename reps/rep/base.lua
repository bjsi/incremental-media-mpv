local Rep = {}
Rep.__index = Rep

setmetatable(Rep, {
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end,
})

function Rep:_init(row)
    self.row = row
end

function Rep:is_yt()
    return self.row["type"] == "youtube"
end

function Rep:is_local()
    return self.row["type"] == "local"
end

function Rep:valid_interval(interval)
    return interval ~= nil and interval > 0
end

function Rep:valid_speed(speed)
    return speed == nil or speed < 0
end

function Rep:set_speed(speed)
    if speed == nil or speed < 0 or speed > 5 then
        print("Invalid speed.")
        return false
    end
    self.row["speed"] = speed
    return true
end

-- TODO: Call player.play
function Rep:play()
    -- Set speed
    local speed = self.row["speed"]
    if not self:valid_speed(speed) then speed = 1 end

    -- set start stop boundaries
    local start = self.row["start"]
    if start == nil then start = 0 end

    local stop = self.row["stop"]
    if stop == nil then stop = -1 end

    -- TODO: loop

    -- Play
    -- Seek
    -- Update curtime
end

return Rep
