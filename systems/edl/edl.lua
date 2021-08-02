local log = require("utils.log")
local str = require("utils.str")
local mpu = require("mp.utils")
local ext = require("utils.ext")
local fs = require("systems.fs")
local item_format = require("reps.rep.item_format")

local ClozeEDL = {}
ClozeEDL.__index = ClozeEDL

function ClozeEDL.new(outputPath)
    local self = setmetatable({}, ClozeEDL)
    self.outputPath = outputPath
    self.header = "# mpv EDL v0\n"
    return self
end

function ClozeEDL:open(mode)
    local handle = io.open(self.outputPath, mode)
    if handle == nil then
        log.err("Failed to open EDL file: " .. self.outputPath)
        return nil
    end
    return handle
end

function ClozeEDL:format_pre_cloze(parentPath, parentStart, clozeStart)
    local preClozeLength = clozeStart - parentStart
    return table.concat(
        {
            parentPath,
            parentStart,
            preClozeLength
        }, ",")
end

function ClozeEDL:format_cloze(clozeEnd, clozeStart)
    local _, fname = mpu.split_path(fs.sine)
    local clozeLength = clozeEnd - clozeStart
    return table.concat(
        {
            fname,
            0,
            clozeLength
        }, ",")
end

function ClozeEDL:format_post_cloze(parentPath, clozeEnd, parentEnd)
    local postClozeLength = parentEnd - clozeEnd
    return table.concat(
        {
            parentPath,
            clozeEnd,
            postClozeLength
        }, ",")
end

function ClozeEDL:media(mediaPath, showat)
    return "!new_stream\n" .. table.concat({ mediaPath, "title="..showat }, ",")
end

-- sound, format, media
function ClozeEDL:write(sound, format, media)
    if format.name ~= item_format.cloze then
        log.debug("Failed to write edl: item format is not cloze")
        return false
    end

    local handle = self:open("w")
    if handle == nil then
        log.err("Failed to open EDL file for writing.")
        return false
    end

    handle:write(self.header)
    handle:write(self:format_pre_cloze(sound["path"], sound["start"], format["cloze-start"]) .. "\n")
    handle:write(self:format_cloze(format["cloze-stop"], format["cloze-start"]) .. "\n")
    handle:write(self:format_post_cloze(sound["path"], format["cloze-stop"], sound["stop"]) .. "\n")

    if media then
        handle:write(self:media(media["path"], media["showat"]) .. "\n")
    end

    handle:close()

    log.debug("Successfully wrote EDL file: " .. self.outputPath)
    return true
end

function ClozeEDL:read()
    local handle = self:open("r")
    if handle == nil then 
        log.err("Failed to open EDL file: " .. self.outputPath)
        return
    end

    local content = handle:read("*all")
    handle:close()

    local match = content:gmatch("([^\n]*)\n?")
    if not (match() == "# mpv EDL v0") then
        log.err("Invalid EDL file header.")
        return nil
    end

    local preCloze = self:parse_line(match())
    local cloze = self:parse_line(match())
    local postCloze = self:parse_line(match())

    match() -- !new_stream header
    local mediaLine = match()
    local media
    if mediaLine then
        local mediaData = self:parse_line(mediaLine)
        media = { path = mediaData[1], showat = str.remove_newlines(mediaData[2]:sub(7)) }
    end

    local function pred(arr) return arr == nil or #arr ~= 3 end
    if ext.list_any(pred, {preCloze, cloze, postCloze}) then
        log.err("Invalid EDL data.")
        return nil
    end

    local parentPath = preCloze[1]
    local parentStart = tonumber(preCloze[2])

    local preClozeLength = tonumber(preCloze[3])
    local clozeStart = parentStart + preClozeLength

    local clozeLength = tonumber(cloze[3])
    local clozeEnd = clozeStart + clozeLength

    local postClozeLength = tonumber(postCloze[3])
    local parentEnd = clozeEnd + postClozeLength

    log.debug("Successfully parsed EDL file: " .. self.outputPath)
    local sound = { path=parentPath, start=parentStart, stop=parentEnd }
    local format = { name=item_format.cloze, ["cloze-start"]=clozeStart, ["cloze-stop"] = clozeEnd }
    return sound, format, media
end

function ClozeEDL:adjust_cloze(postpone, start)
    local adj = 0.02
    local advance = not postpone
    local stop = not start

    local sound, format, media = self:read()

    if advance and start then
        format["cloze-start"] = format["cloze-start"] - adj
    elseif postpone and start then
        format["cloze-start"] = format["cloze-start"] + adj
    elseif advance and stop then
        format["cloze-stop"] = format["cloze-stop"] - adj
    elseif postpone and stop then
        format["cloze-stop"] = format["cloze-stop"] + adj
    end

    -- TODO: validate!!!

    local succ = self:write(sound, format, media)
    return succ and format["cloze-start"] - sound["start"], format["cloze-stop"] - sound["start"] or nil, nil
end

function ClozeEDL:parse_line(line)
    local ret = {}
    for v in string.gmatch(line, "[^,]*") do
        if not ext.empty(v) then
            ret[#ret+1] = v
        end
    end
    return ret
end

return ClozeEDL
