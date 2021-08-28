local log = require 'utils.log'
local obj = require 'utils.object'
local tbl = require 'utils.table'
local item_format = require 'reps.rep.item_format'
local mpu = require 'mp.utils'

local ClozeContextEDL = {}
ClozeContextEDL.__index = ClozeContextEDL

function ClozeContextEDL.new(outputPath)
    local self = setmetatable({}, ClozeContextEDL)
    self.outputPath = outputPath
    self.header = "# mpv EDL v0\n"
    return self
end

function ClozeContextEDL:open(mode)
    local handle = io.open(self.outputPath, mode)
    if handle == nil then
        log.err("Failed to open EDL file: " .. self.outputPath)
        return nil
    end
    return handle
end

function ClozeContextEDL:format_cloze(parentPath, clozeStart, clozeEnd)
    local _, fname = mpu.split_path(parentPath)
    local clozeLength = clozeEnd - clozeStart
    return table.concat({
        fname, clozeStart, -- TODO - parentStart ?
        clozeLength
    }, ",")
end

function ClozeContextEDL:format_silence()
    local silenceLength = 0.8
    return table.concat({"silence.mp3", 0, silenceLength}, ",")
end

function ClozeContextEDL:format_context(parentPath, parentStart, parentEnd)
    local contextLength = parentEnd - parentStart
    return table.concat({parentPath, parentStart, contextLength}, ",")
end

function ClozeContextEDL:format_media(mediaPath, showat)
    return "!new_stream\n" .. table.concat({mediaPath, "title=" .. showat}, ",")
end

function ClozeContextEDL:write(sound, format, media)

    local handle = self:open("w")
    if handle == nil then
        log.err("Failed to open EDL file for writing.")
        return false
    end

    handle:write(self.header)
    handle:write(self:format_cloze(sound["path"], format["cloze-start"],
                                   format["cloze-stop"]) .. "\n")
    handle:write(self:format_silence() .. "\n")
    handle:write(self:format_context(sound["path"], sound["start"],
                                     sound["stop"]) .. "\n")

    if media then
        handle:write(self:format_media(media["path"], media["showat"]) .. "\n")
    end

    handle:close()

    log.debug("Successfully wrote cloze context EDL file: " .. self.outputPath)
    return true
end

function ClozeContextEDL:read()
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

    local cloze = self:parse_line(match())
    match() -- silence
    local context = self:parse_line(match())

    match() -- !new_stream header or nil
    local mediaLine = match() -- media or nil

    local media
    if mediaLine then
        local mediaData = self:parse_line(mediaLine)
        media = {path = mediaData[1], showat = "answer"} -- TODO: mixup between showat= and title=
        log.debug("Context cloze media: ", media)
    end

    local function pred(arr) return arr == nil or #arr ~= 3 end
    if tbl.any(pred, {cloze, context}) then
        log.err("Invalid EDL data: unexpected parsed array size.")
        return nil
    end

    local parentPath = cloze[1]

    local parentStart = tonumber(context[2])
    local parentLength = tonumber(context[3]) - parentStart
    local parentEnd = parentStart + parentLength

    local clozeLength = tonumber(cloze[3])
    local clozeStart = tonumber(cloze[2]) + tonumber(parentStart)
    local clozeEnd = clozeStart + clozeLength

    log.debug("Successfully parsed EDL file: " .. self.outputPath)
    local sound = {path = parentPath, start = parentStart, stop = parentEnd}
    local format = {
        name = item_format.cloze_context,
        ["cloze-start"] = clozeStart,
        ["cloze-stop"] = clozeEnd
    }

    return sound, format, media
end

function ClozeContextEDL:parse_line(line)
    local ret = {}
    for v in string.gmatch(line, "[^,]*") do
        if not obj.empty(v) then ret[#ret + 1] = v end
    end
    return ret
end

return ClozeContextEDL
