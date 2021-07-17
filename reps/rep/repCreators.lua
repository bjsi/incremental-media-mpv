local log = require("utils.log")
local ffmpeg = require("systems.ffmpeg")
local ydl = require("systems.ydl")
local mpu = require("mp.utils")
local ext = require("utils.ext")
local extractHeader = require("reps.reptable.extract_header")
local itemHeader = require("reps.reptable.item_header")
local ExtractRep = require("reps.rep.extract")
local fs = require("systems.fs")
local EDL = require("systems.edl")
local ItemRep = require("reps.rep.item")
local TopicRep = require("reps.rep.topic")
local sys = require("systems.system")
local player = require("systems.player")

local repCreators = {}

function repCreators.createTopic(title, type, url, priority, stop, dependency)
    stop = stop and stop or -1
    local topicRow = {
        ["id"] = sys.uuid(),
        ["title"] = title,
        ["dismissed"] = 0,
        ["chapter"] = 0,
        ["type"] = type,
        ["url"] = url,
        ["afactor"] = 2,
        ["start"] = 0,
        ["stop"] = stop,
        ["curtime"] = 0,
        ["priority"] = priority,
        ["interval"] = 1,
        ["dependency"] = dependency,
        ["nextrep"] = "1970-01-01",
        ["speed"] = 1
    }
    return TopicRep(topicRow)
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
    extractRow["dismissed"] = 0
    extractRow["toexport"] = 0
    extractRow["created"] = tostring(os.time())
    extractRow["afactor"] = 2
    extractRow["stop"] = tostring(ext.round(stop, 2))
    extractRow["id"] = sys.uuid()
    extractRow["interval"] = 1
    extractRow["nextrep"] = "1970-01-01"
    extractRow["parent"] = parent.row["id"]
    extractRow["speed"] = 1
    extractRow["notes"] = ""
    extractRow["subs"] = ""

    return ExtractRep(extractRow)
end

function repCreators.createItemEdl(startTime, stopTime, itemFilePath, relClozeStart, relClozeStop, edlOutputPath, mediaName)
    return EDL.new(edlOutputPath):write(
        itemFilePath,
        startTime,
        stopTime,
        relClozeStart,
        relClozeStop,
        mediaName
    )
end

function repCreators.createYouTubeItem(parent, itemFileName)

    -- local audioStreamUrl = player.get_stream_urls()
    local audioStreamUrl, format = ydl.get_audio_stream(parent.row["url"], false)
    if ext.empty(audioStreamUrl) or ext.empty(format) then
        log.err("Failed to get youtube audio stream.")
        return nil
    end

    local itemFilePath = itemFileName .. "." .. format
    local ret = ffmpeg.audio_extract(parent, audioStreamUrl, itemFilePath)
    return ret.status == 0 and itemFilePath or nil
end

function repCreators.download_media(parent, clozeStart, clozeStop, type)
    local vidstream
    local vidUrl = player.get_full_url(parent)
    local mediafp = mpu.join_path(fs.media, tostring(os.time()))

    local mediaName

    if parent:is_yt() then
        vidstream = ydl.get_video_stream(vidUrl, false)
    elseif parent:is_local() then
        vidstream = vidUrl
    end

    if type == "screenshot" then
        mediafp = mediafp .. ".jpg"
        -- TODO: wrong start time
        if ffmpeg.screenshot(vidstream, clozeStart, mediafp) then
            local _
            _, mediaName = mpu.split_path(mediafp)
        end
    elseif type == "gif" then
        mediafp = mediafp .. ".gif"
        -- TODO: wrong start time
        if ffmpeg.extract_gif(vidstream, clozeStart, clozeStop, mediafp) then
            local _
            _, mediaName = mpu.split_path(mediafp)
        end
    end

    return mediaName
end

function repCreators.createItem(parent, clozeStart, clozeStop, mediaType)
    local filename = tostring(os.time(os.date("!*t")))
    local itemFileName = mpu.join_path(fs.media, filename)
    local itemUrl, startTime, stopTime

    local parentStart = tonumber(parent.row["start"])
    local parentStop = tonumber(parent.row["stop"])

    if parent:is_yt() then
        itemUrl = repCreators.createYouTubeItem(parent, itemFileName)
        local parentLength = parentStop - parentStart
        startTime = 0
        stopTime = parentLength
        clozeStart = clozeStart - parentStart
        clozeStop = clozeStop - parentStart
    elseif parent:is_local() then
        itemUrl = parent.row["url"]
        startTime = parentStart
        stopTime = parentStop
    else
        error("Unrecognized extract type.")
    end

    if ext.empty(itemUrl) then
        log.err("Failed to create item because url was nil.")
        return nil
    end

    local edlOutputPath = mpu.join_path(fs.media, itemFileName .. ".edl")

    local mediaName
    if mediaType then
        mediaName = repCreators.download_media(parent, clozeStart, clozeStop, mediaType)
    end

    if not repCreators.createItemEdl(startTime, stopTime, itemUrl, clozeStart, clozeStop, edlOutputPath, mediaName) then
        log.err("Failed to create item EDL file.")
        return nil
    end

    local itemRow = repCreators.copyCommon(parent.row, {}, itemHeader)
    if not itemRow then
        log.err("Failed to create item row")
        return nil
    end

    local _, fname = mpu.split_path(edlOutputPath)
    itemRow["id"] = sys.uuid()
    itemRow["created"] = os.time()
    itemRow["dismissed"] = 0
    itemRow["toexport"] = 1
    itemRow["url"] = fname
    itemRow["parent"] = parent.row["id"]
    itemRow["speed"] = 1
    itemRow["start"] = parentStart
    itemRow["stop"] = parentStop

    return ItemRep(itemRow)
end

return repCreators