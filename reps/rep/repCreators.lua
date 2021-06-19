local log = require("utils.log")
local ffmpeg = require("systems.ffmpeg")
local sounds = require("systems.sounds")
local ydl = require("systems.ydl")
local mpu = require("mp.utils")
local dt = require("utils.date")
local ext = require("utils.ext")
local str = require("utils.str")
local extractHeader = require("reps.reptable.extract_header")
local ExtractRep = require("reps.rep.extract")
local fs = require("systems.fs")
local EDL = require("systems.edl")

local repCreators = {}

function repCreators.generateId()
    return str.random(8)
end

--- Copy common kv pairs
function repCreators.copyCommon(parentRow, childRow, childHeader)
    for k, v in pairs(parentRow) do
        if ext.list_contains(childHeader, k) then
            childRow[k] = v
        end
    end
    return childRow
end

function repCreators.createExtract(parent, start, stop)
    if not parent then 
        log.err("Failed to create extract because parent is nil")
        return nil
    end

    local extractRow = repCreators.copyCommon(parent.row, {}, extractHeader)
    if not extractRow then
        log.err("Failed to create extract row")
        return nil
    end

    extractRow["start"] = tostring(ext.round(2, start))
    extractRow["stop"] = tostring(ext.round(2, stop))
    extractRow["id"] = repCreators.generateId()
    extractRow["interval"] = 1
    extractRow["nextrep"] = "1970-01-01"
    extractRow["parent"] = parent.row["id"]
    extractRow["speed"] = 1

    return ExtractRep(extractRow)
end

function repCreators.createLocalItem()
    local cloze = "sine.opus"
    local edl = mpu.join_path(fs.media, fname .. ".edl")

    -- Create virtual file using EDL
    local handle = io.open(edl, "w")
    handle:write("# mpv EDL v0\n")
    handle:write(fname .. extension .. ",0," .. tostring(start) .. "\n")
    handle:write(cloze .. ",0," .. tostring(stop - start) .. "\n")
    handle:write(fname .. extension .. "," .. tostring(stop) .. "," ..
                     tostring(
                         tonumber(curRep.row["stop"]) -
                             tonumber(curRep.row["start"]) - stop) .. "\n")
    handle:close()
end

function repCreators.createYouTubeItem(url, extension, extractFileName, start, stop)
    local audioStreamUrl = ydl.get_audio_stream(url)
    if ext.empty(audioStreamUrl) then
        return nil
    end

    local ret = ffmpeg.audio_extract(audioStreamUrl, extractFileName, start, stop)
                                    
    if ret.stdout ~= 0 then
        return nil
    end

end

-- TODO
function repCreators.createItem(parent, clozeStart, clozeStop)
    local url = parent.row["url"]
    local relativeClozeStart = clozeStart - tonumber(parent.row["start"])
    local relativeClozeStop = clozeStop - tonumber(parent.row["start"])
    local extension = ".wav"
    local fname = tostring(os.time(os.date("!*t")))
    local itemFilePath = mpu.join_path(fs.media, fname .. extension)
    local item = parent:is_yt() and repCreators.createYouTubeItem() or repCreators.createLocalItem()
end

return repCreators