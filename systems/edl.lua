local log = require("utils.log")
local fs = require("systems.fs")

local EDL = {}
EDL.__index = EDL

function EDL.new(parentPath, parentStart, parentEnd, clozeStart, clozeEnd, outputPath)
    local self = setmetatable({}, EDL)
    self.outputPath = outputPath
    self.header = "# mpv EDL v0\n"
    self.parentPath = parentPath
    self.parentStart = parentStart
    self.parentEnd = parentEnd
    self.clozeStart = clozeStart
    self.clozeEnd = clozeEnd
    return self
end

function EDL:open(mode)
    local handle = io.open(self.outputPath, mode)
    if handle == nil then
        log.err("Failed to open EDL file: " .. self.outputPath)
        return nil
    end
    return handle
end

function EDL:pre_cloze()
    return table.concat(
        {
            self.parentPath,
            self.parentStart,
            self.clozeStart
        }, ",")
end

function EDL:cloze()
    return table.concat(
        {
            fs.sine,
            self.clozeStart,
            self.clozeEnd
        }, ",")
end

function EDL:post_cloze()
    return table.concat({
        self.parentPath,
        self.clozeEnd,
        self.parentEnd
    }, ",")
end

function EDL:write()
    local handle = self:open("w")
    if handle == nil then return false end

    handle:write(self.header)
    handle:write(self:pre_cloze() .. "\n")
    handle:write(self:cloze() .. "\n")
    handle:write(self:post_cloze() .. "\n")

    handle:close()

    log.debug("Successfully wrote EDL file: " .. self.outputPath)
    return true
end

-- TODO: cloze adjustments
-- Load EDL file.
function EDL:load()
    local handle = self:open("r")
    if handle == nil then return end

    local content = handle:read("*all")
    local match = content:gmatch("([^\n]*)\n?")
    match()
    local beg = self:parse_line(match())
    local cloze = self:parse_line(match())
    local ending = self:parse_line(match())
    handle:close()

    self.data = {beg = beg, cloze = cloze, ending = ending}

    log.debug("Successfully parsed EDL file: " .. self.outputPath)
    return true
end

-- TODO
-- parses a single line in an EDL file
function EDL:parse_line(line)
    local ret = {}
    local ct = 1
    for v in string.gmatch(line, "[^,]*") do
        if v ~= "" then
            if ct == 1 then ret["fp"] = v end
            if ct == 2 then ret["start"] = v end
            if ct == 3 then ret["stop"] = v end
            ct = ct + 1
        end
    end
    return ret
end

return EDL
