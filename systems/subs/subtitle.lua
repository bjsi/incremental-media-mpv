local Subtitle

------------------------------------------------------------
-- Subtitle class provides methods for comparing subtitle lines

Subtitle = {['text'] = '', ['start'] = -1, ['end'] = -1}

function Subtitle:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

Subtitle.__eq = function(lhs, rhs) return lhs['text'] == rhs['text'] end

Subtitle.__lt = function(lhs, rhs) return lhs['start'] < rhs['start'] end

return Subtitle
