local log = require("utils.log")
local ffmpeg = require("systems.ffmpeg")
local ydl = require("systems.ydl")
local mpu = require("mp.utils")
local ext = require("utils.ext")
local extractHeader = require("reps.reptable.extract_header")
local itemHeader = require("reps.reptable.item_header")
local ExtractRep = require("reps.rep.extract")
local fs = require("systems.fs")
local ClozeEDL = require("systems.edl.edl")
local ClozeContextEDL = require("systems.edl.clozeContextEdl")
local QAEDL = require("systems.edl.qaEdl")
local item_format = require("reps.rep.item_format")
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

function repCreators.download_yt_audio(fullUrl, start, stop)
    local audioFileNameNoExt = tostring(os.time())

    -- Get direct link to audio stream.
    local audioStreamUrl, format = ydl.get_audio_stream(fullUrl, false)
    if ext.empty(audioStreamUrl) or ext.empty(format) then
        log.err("Failed to get youtube audio stream.")
        return nil
    end

    local audioFileNameWithExt = audioFileNameNoExt..".".. format
    local ret = ffmpeg.audio_extract(start, stop, audioStreamUrl, mpu.join_path(fs.media, audioFileNameWithExt))
    return ret.status == 0 and audioFileNameWithExt or nil
end

function repCreators.download_media(parent, start, stop, type)
    local vidStreamUrl
    local vidFullUrl = player.get_full_url(parent)
    local mediaFileNameNoExt = tostring(os.time())

    if parent:is_yt() then
        vidStreamUrl = ydl.get_video_stream(vidFullUrl, false)
    elseif parent:is_local() then
        vidStreamUrl = vidFullUrl
    end

    local ret
    local mediaFileNameWithExt

    if type == "screenshot" then
        mediaFileNameWithExt = mediaFileNameNoExt..".jpg"
        ret = ffmpeg.screenshot(vidStreamUrl, start, mpu.join_path(fs.media, mediaFileNameWithExt))
    elseif type == "gif" then
        mediaFileNameWithExt = mediaFileNameNoExt..".gif"
        ret = ffmpeg.extract_gif(vidStreamUrl, start, stop, mpu.join_path(fs.media, mediaFileNameWithExt))
    end

    if ret then
        log.debug("Successfully downloaded " .. type .. " media")
        return mediaFileNameWithExt
    else
        log.debug("Failed to download " .. type .. " media")
        return nil
    end
end

function repCreators.createItem1(parent, sound, media, text, format)
    local fullUrl = player.get_full_url(parent)

    if sound ~= nil then
        if parent:is_local() then
            -- sound["path"] = fullUrl -- TODO: audio extraction?
        elseif parent:is_yt() then

            -- here, sound["path"] is relative to fs.media!
            sound["path"] = repCreators.download_yt_audio(fullUrl, sound["start"], sound["stop"])

            -- Adjust to relative times after extracting audio
            format["cloze-start"] = format["cloze-start"] - sound["start"]
            format["cloze-stop"] = format["cloze-stop"] - sound["start"]
            sound["stop"] = sound["stop"] - sound["start"]
            sound["start"] = 0
        end

        if not sound["path"] or not sys.exists(mpu.join_path(fs.media, sound["path"])) then
            log.debug("Failed to get audio.")
            return nil
        end
    end

    log.debug("sound: ", sound)
    
    -- download / extract media
    -- media["path"] always relative to fs.media
    if media ~= nil then
        if parent:is_local() then
            -- TODO
        elseif parent:is_yt() then
            media["path"] = repCreators.download_media(parent, media["start"], media["stop"], media["type"])
        end

        if not media["path"] or not sys.exists(mpu.join_path(fs.media, media["path"])) then
            log.debug("Failed to get media.")
            return nil
        end
    end

    log.debug("media: ", media)

    local edlFileNameWithExt = tostring(os.time())..".edl"
    local edlFullPathWithExt = mpu.join_path(fs.media, edlFileNameWithExt)

    local ret

    -- Normal cloze
    if format["name"] == item_format.cloze then
        log.debug("Creating cloze edl.")
        local edl = ClozeEDL.new(edlFullPathWithExt)
        ret = edl:write(sound, format, media)

    -- QA
    elseif format["name"] == item_format.qa then
        log.debug("Creating qa edl.")
        local edl = QAEDL.new(edlFullPathWithExt)
        ret = edl:write(sound, format, media)

    -- Cloze context
    elseif format["name"] == item_format.cloze_context then
        log.debug("Creating cloze context edl.")
        local edl = ClozeContextEDL.new(edlFullPathWithExt)

        -- TODO: relative or full start / stop
        ret = edl:write(sound, format, media)
    end

    if not ret or not sys.exists(edlFullPathWithExt) then
        log.debug("Failed to create item: failed to write EDL file.")
        return nil
    end

    -- Create item row
    local itemRep = repCreators.create_item_rep(parent, sound, text, format, edlFileNameWithExt)
    if not itemRep then
        log.debug("Failed to create item: item rep was nil.")
        return false
    end

    log.debug("Successfully created item: ", itemRep)
    return itemRep
end

function repCreators.create_item_rep(parent, sound, text, format, edlFileNameWithExt)
    local itemRow = repCreators.copyCommon(parent.row, {}, itemHeader)
    if not itemRow then
        log.err("Failed to create item row.")
        return nil
    end

    itemRow["id"] = sys.uuid()
    itemRow["created"] = os.time()
    itemRow["dismissed"] = 0
    itemRow["toexport"] = 1
    itemRow["parent"] = parent.row["id"]

    -- Sound
    itemRow["url"] = edlFileNameWithExt
    itemRow["start"] = parent.row.start
    itemRow["stop"] = parent.row.stop

    -- Text
    itemRow["question"] = text and text["question"] or ""
    itemRow["answer"] = text and text["answer"] or ""

    -- Format
    itemRow["format"] = format["name"]

    -- Misc
    itemRow["speed"] = 1

    return ItemRep(itemRow)
end

-- function repCreators.createItem(parent, clozeStart, clozeStop, mediaType, question, answer, format)
--     local filename = tostring(os.time(os.date("!*t")))
--     local itemFileName = mpu.join_path(fs.media, filename)
--     local itemUrl, startTime, stopTime

--     local parentStart = tonumber(parent.row["start"])
--     local parentStop = tonumber(parent.row["stop"])

--     if parent:is_yt() then
--         itemUrl = repCreators.download_yt_audio(parent, itemFileName)
--         local parentLength = parentStop - parentStart
--         startTime = 0
--         stopTime = parentLength
--         clozeStart = clozeStart - parentStart
--         clozeStop = clozeStop - parentStart
--     elseif parent:is_local() then
--         itemUrl = parent.row["url"]
--         startTime = parentStart
--         stopTime = parentStop
--     end

--     if ext.empty(itemUrl) then
--         log.err("Failed to create item because url was nil.")
--         return nil
--     end

--     local edlOutputPath = mpu.join_path(fs.media, itemFileName .. ".edl")

--     local mediaName
--     if mediaType then
--         mediaName = repCreators.download_media(parent, clozeStart, clozeStop, mediaType)
--     end

--     if not repCreators.createItemEdl(startTime, stopTime, itemUrl, clozeStart, clozeStop, edlOutputPath, mediaName, format) then
--         log.err("Failed to create item EDL file.")
--         return nil
--     end

--     local itemRow = repCreators.copyCommon(parent.row, {}, itemHeader)
--     if not itemRow then
--         log.err("Failed to create item row")
--         return nil
--     end

--     local _, fname = mpu.split_path(edlOutputPath)
--     itemRow["id"] = sys.uuid()
--     itemRow["created"] = os.time()
--     itemRow["dismissed"] = 0
--     itemRow["toexport"] = 1
--     itemRow["url"] = fname
--     itemRow["parent"] = parent.row["id"]
--     itemRow["speed"] = 1
--     itemRow["start"] = parentStart
--     itemRow["stop"] = parentStop
--     itemRow["question"] = question and question or ""
--     itemRow["answer"] = answer and answer or ""
--     itemRow["format"] = format and format or ""

--     return ItemRep(itemRow)
-- end

return repCreators