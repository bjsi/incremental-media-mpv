local log = require "utils.log"
local dt = require "utils.date"
local mpu = require("mp.utils")
local ext = require("utils.ext")
local element = require "systems.sm.xml.element"

local collection = {}
collection.__index = collection

function collection.create_root()
    local root = element.new("SuperMemoElement")
    local title = table.concat({"IM Export", "::", dt.date_today(), dt.time()},
                               " ")
    root:with_id("1"):with_title(title):with_type("Topic")
    return root
end

function collection.new(outputPath)
    local self = setmetatable({}, collection)
    self.open_tag = "<SuperMemoCollection>"
    self.close_tag = "</SuperMemoCollection>"
    self.outputFolder = outputPath
    self.children = {element.new("Count"), self:create_root()}
    self.count = self.children[1]
    self.root = self.children[2]
    return self
end

function collection:children_string()
    local data = {}
    for _, child in ipairs(self.children) do
        table.insert(data, child:as_string())
    end
    return table.concat(data, "\n")
end

function collection:as_string()
    return table.concat({self.open_tag, self:children_string(), self.close_tag},
                        "\n")
end

function collection:write(n)
    self.count.content = tostring(n)

    if ext.empty(self.root.children) then
        log.debug("No elements to write!")
        return false
    end

    local data = self:as_string()
    if ext.empty(data) then
        log.err("XML data string was nil or empty.")
        return false
    end

    local xmlPath = mpu.join_path(self.outputFolder, "im-export.xml")
    local handle = io.open(xmlPath, "w")
    if handle == nil then log.err("Failed to open: " .. xmlPath) end

    handle:write(data)
    handle:close()

    return true
end

return collection
