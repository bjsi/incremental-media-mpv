-- from: https://github.com/Ajatt-Tools/mpvacious/blob/master/osd_styler.lua
local OSD = {}
OSD.__index = OSD

function OSD:new() return setmetatable({messages = {}}, self) end

function OSD:append(s)
    table.insert(self.messages, s)
    return self
end

function OSD:newline() return self:append([[\N]]) end

function OSD:tab() return self:append([[\h\h\h\h]]) end

function OSD:size(size) return self:append('{\\fs'):append(size):append('}') end

function OSD:align(number) return
    self:append('{\\an'):append(number):append('}') end

function OSD:get_text() return table.concat(self.messages) end

function OSD:color(code)
    return self:append('{\\1c&H'):append(code:sub(5, 6)):append(code:sub(3, 4))
               :append(code:sub(1, 2)):append('&}')
end

function OSD:text(text) return self:append(text) end

function OSD:bold(s) return self:append('{\\b1}'):append(s):append('{\\b0}') end

function OSD:italics(s) return self:append('{\\i1}'):append(s):append('{\\i0}') end

function OSD:submenu(text) return
    self:color('ffe1d0'):bold(text):color('ffffff') end

function OSD:item(text) return self:color('fef6dd'):bold(text):color('ffffff') end

return OSD
