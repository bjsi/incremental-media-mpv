local log = require("utils.log")
local ffmpeg = require("systems.ffmpeg")
local ydl = require("systems.ydl")
local mpu = require("mp.utils")
local ext = require("utils.ext")
local str = require("utils.str")
local extractHeader = require("reps.reptable.extract_header")
local itemHeader = require("reps.reptable.item_header")
local ExtractRep = require("reps.rep.extract")
local fs = require("systems.fs")
local EDL = require("systems.edl")
local ItemRow = require("reps.rep.item")

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

    extractRow["start"] = tostring(ext.round(start, 2))
    extractRow["stop"] = tostring(ext.round(stop, 2))
    extractRow["id"] = repCreators.generateId()
    extractRow["interval"] = 1
    extractRow["nextrep"] = "1970-01-01"
    extractRow["parent"] = parent.row["id"]
    extractRow["speed"] = 1

    return ExtractRep(extractRow)
end

function repCreators.createItemEdl(startTime, stopTime, itemFilePath, relClozeStart, relClozeStop, edlOutputPath)
    return EDL.new(edlOutputPath):write(
        itemFilePath,
        startTime,
        stopTime,
        relClozeStart,
        relClozeStop
    )
end

function repCreators.createYouTubeItem(parent, itemFileName)

    -- local audioStreamUrl = player.get_stream_urls()
    local audioStreamUrl, format = ydl.get_audio_stream(parent.row["url"])
    if ext.empty(audioStreamUrl) or ext.empty(format) then
        log.err("Failed to get youtube audio stream.")
        return nil
    end

    local itemFilePath = itemFileName .. "." .. format
    local ret = ffmpeg.audio_extract(parent, audioStreamUrl, itemFilePath)
    return ret.status == 0 and itemFilePath or nil
end

function repCreators.createItem(parent, clozeStart, clozeStop)
    local filename = tostring(os.time(os.date("!*t")))
    local itemFileName = mpu.join_path(fs.media, filename)
    local itemUrl, startTime, stopTime

    if parent:is_yt() then
        itemUrl = repCreators.createYouTubeItem(parent, itemFileName)
        startTime = 0
        stopTime = -1
        clozeStart = clozeStart - tonumber(parent.row["start"])
        clozeStop = clozeStop - tonumber(parent.row["start"])
    elseif parent:is_local() then
        itemUrl = parent.row["url"]
        startTime = parent.row["start"]
        stopTime = parent.row["stop"]
    else
        error("Unrecognized extract type.")
    end

    if ext.empty(itemUrl) then
        log.err("Failed to create item because url was nil.")
        return nil
    end

    local edlOutputPath = mpu.join_path(fs.media, itemFileName .. ".edl")

    if not repCreators.createItemEdl(startTime, stopTime, itemUrl, clozeStart, clozeStop, edlOutputPath) then
        log.err("Failed to create item EDL file.")
        return nil
    end

    local itemRow = repCreators.copyCommon(parent.row, {}, itemHeader)
    if not itemRow then
        log.err("Failed to create item row")
        return nil
    end

    itemRow["id"] = repCreators.generateId()
    itemRow["url"] = edlOutputPath
    itemRow["parent"] = parent.row["id"]

    return ItemRow(itemRow)
end

return repCreators