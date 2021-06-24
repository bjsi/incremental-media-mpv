local log = require("utils.log")
local ffmpeg = require("systems.ffmpeg")
local ydl = require("systems.ydl")
local mpu = require("mp.utils")
local dt = require("utils.date")
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

function repCreators.createItemEdl(parent, itemFilePath, relClozeStart, relClozeStop, edlOutputPath)
    local edl = EDL.new(
        itemFilePath,
        parent.row["start"],
        parent.row["stop"],
        relClozeStart,
        relClozeStop,
        edlOutputPath
    )
    return edl:write()
end

function repCreators.createLocalItem()
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
    local itemFilePath = parent:is_yt() and repCreators.createYouTubeItem(parent, itemFileName) or repCreators.createLocalItem()
    if ext.empty(itemFilePath) then
        log.err("Failed to create item.")
        return nil
    end

    local relClozeStart = clozeStart - tonumber(parent.row["start"])
    local relClozeStop = clozeStop - tonumber(parent.row["start"])
    local edlOutputPath = mpu.join_path(fs.media, itemFileName .. ".edl")
    if not repCreators.createItemEdl(parent, itemFilePath, relClozeStart, relClozeStop, edlOutputPath) then
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