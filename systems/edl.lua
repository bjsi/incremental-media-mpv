local log = require("utils.log")

local EDL = {}
EDL.__index = EDL

function EDL.new(fp)
    local self = setmetatable({}, EDL)
    self.fp = fp
    self.header = "# mpv EDL v0\n"
    self.data = {}
    return self
end

function EDL:open(mode)
    local handle = io.open(self.fp, mode)
    if handle == nil then
        log.err("Failed to open EDL file: " .. self.fp)
        return nil
    end
    return handle
end

function EDL:write()
    local handle = self:open("w")
    if handle == nil then return end

    handle:write(self.header)
    handle:write(self.data["beg"]["fp"] .. "," .. self.data["beg"]["start"] ..
                     "," .. self.data["beg"]["stop"] .. "\n")
    handle:write(
        self.data["cloze"]["fp"] .. "," .. self.data["cloze"]["start"] .. "," ..
            self.data["cloze"]["stop"] .. "\n")
    handle:write(self.data["ending"]["fp"] .. "," ..
                     self.data["ending"]["start"] .. "," ..
                     self.data["ending"]["stop"] .. "\n")
    handle:close()

    log.debug("Successfully wrote EDL file: " .. self.fp)
    return true
end

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

    log.debug("Successfully parsed EDL file: " .. self.fp)
    return true
end

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
