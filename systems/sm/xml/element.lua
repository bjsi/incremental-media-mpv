local str = require 'utils.str'
local obj = require 'utils.object'

local element = {}
element.__index = element

function element.new(tag, content)
    local self = setmetatable({}, element)
    self.tag = tag
    self.open_tag = "<" .. tag .. ">"
    self.close_tag = "</" .. tag .. ">"
    self.content = content and content or ""
    self.children = {}
    return self
end

function element:as_content_string()
    return self.open_tag .. self.content .. self.close_tag
end

function element:as_has_children_string()
    return table.concat({self.open_tag, self:children_string(), self.close_tag},
                        "\n")
end

function element:as_string()
    if obj.empty(self.content) then
        return self:as_has_children_string()
    else
        return self:as_content_string()
    end
end

function element:children_string()
    local data = {}
    for _, el in ipairs(self.children) do table.insert(data, el:as_string()) end
    return table.concat(data, "\n")
end

function element:add_child(el) table.insert(self.children, el) end

function element:with_title(title)
    self:add_child(element.new("Title", title))
    return self
end

function element:with_id(id)
    self:add_child(element.new("ID", id))
    return self
end

function element:with_type(type)
    self:add_child(element.new("Type", type))
    return self
end

function element:with_text(s)
    self:add_child(element.new("Text", s))
    return self
end

function element:with_url(url)
    self:add_child(element.new("URL", url))
    return self
end

function element:with_name(name)
    self:add_child(element.new("Name", name))
    return self
end

function element:add_image(url)
    local image = element.new("Image")
    image:add_child(element.new("URL", url))
    image:add_child(element.new("Name", url))
    self:add_child(image)
end

function element:add_sound(question, url, name)
    local text = question and "Question" or "Answer"
    local sound = element.new("Sound")
    sound:add_child(
        element.new("Text", table.concat({"Audio Cloze", text}, " ")))
    sound:add_child(element.new("URL", url))
    sound:add_child(element.new("Name", name))
    self:add_child(sound)
end

function element:add_question(content, refs)
    local question = element.new("Question", content)
    question.content = question.content .. "\n" ..
                           str.escape_special_chars(refs:as_string())
    self:add_child(question)
end

return element
