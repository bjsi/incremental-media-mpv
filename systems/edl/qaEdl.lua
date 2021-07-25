local log = require("utils.log")
local mpu = require("mp.utils")
local ext = require("utils.ext")
local str= require("utils.str")
local item_format = require("reps.rep.item_format")

local QAEDL = {}
QAEDL.__index = QAEDL

function QAEDL.new(outputPath)
    local self = setmetatable({}, QAEDL)
    self.outputPath = outputPath
    self.header = "# mpv EDL v0\n"
    return self
end

function QAEDL:open(mode)
    local handle = io.open(self.outputPath, mode)
    if handle == nil then
        log.err("Failed to open EDL file: " .. self.outputPath)
        return nil
    end
    return handle
end

-- TODO: make it the same length as the gif if gif?
function QAEDL:format_silence()
    local soundLength = 10
    return table.concat({
        "silence.mp3", 0, soundLength, "title=no"
    }, ",")
end

function QAEDL:format_sound(sound)
    local _, fname = mpu.split_path(sound["path"]) -- need to split?
    local soundLength = tonumber(sound["stop"]) - tonumber(sound["start"])
    return table.concat(
        {
            fname,
            sound["start"], -- TODO - parentStart ?
            tostring(soundLength),
            "showat="..sound["showat"]
        }, ",")
end

function QAEDL:format_media(media)
    return "!new_stream\n" .. table.concat({ media["path"], "title="..media["showat"] }, ",") .. "\n"
end

function QAEDL:write(sound, format, media)
    if format["name"] ~= item_format.qa then
        log.debug("Failed to write edl: ttem format is not qa")
        return false
    end

    local handle = self:open("w")
    if handle == nil then
        log.err("Failed to open EDL file for writing.")
        return false
    end

    handle:write(self.header)
    if sound then
        handle:write(self:format_sound(sound) .. "\n")
    else
        handle:write(self:format_silence() .. "\n")
    end

    if media then
        handle:write(self:format_media(media) .. "\n")
    end

    handle:close()

    log.debug("Successfully wrote qa EDL file: " .. self.outputPath)
    return true
end

function QAEDL:read()
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

    local soundLine = self:parse_line(match())
    local sound
    if soundLine and soundLine[0] ~= "silence.mp3" then
        sound = { 
            path = soundLine[1],
            start=soundLine[2],
            stop=soundLine[3],
            showat= str.remove_newlines(soundLine[4]:sub(7))
        }
    end

    match() -- !new_stream header or nil
    local mediaLine = match() -- media or nil
    local media

    if mediaLine then
        local mediaData = self:parse_line(mediaLine)
        media = { path = mediaData[1], showat = str.remove_newlines(mediaData[2]:sub(7)) }
    end

    log.debug("Successfully parsed qa EDL file: " .. self.outputPath)
    return sound, { name = item_format.qa }, media
end

function QAEDL:parse_line(line)
    local ret = {}
    for v in string.gmatch(line, "[^,]*") do
        if not ext.empty(v) then
            ret[#ret+1] = v
        end
    end
    return ret
end

return QAEDL