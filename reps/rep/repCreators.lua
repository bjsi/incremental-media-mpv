local log = require 'utils.log'
local tbl = require 'utils.table'
local ffmpeg = require 'systems.ffmpeg'
local mpu = require 'mp.utils'
local extractHeader = require 'reps.reptable.extract_header'
local itemHeader = require 'reps.reptable.item_header'
local ExtractRep = require 'reps.rep.extract'
local fs = require 'systems.fs'
local ClozeEDL = require 'systems.edl.edl'
local ClozeContextEDL = require 'systems.edl.clozeContextEdl'
local QAEDL = require 'systems.edl.qaEdl'
local item_format = require 'reps.rep.item_format'
local ItemRep = require 'reps.rep.item'
local TopicRep = require 'reps.rep.topic'
local sys = require 'systems.system'
local player = require 'systems.player'
local num = require 'utils.number'
local mp = require 'mp'
local obj = require 'utils.object'
local file = require 'utils.file'

local repCreators = {}

function repCreators.createTopic(title, type, url, priority, stop, dependency)
    if not stop then stop = -1 end
    if not dependency then dependency = "" end
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
        if tbl.contains(childHeader, k) then childRow[k] = v end
    end
    return childRow
end

function repCreators.createExtract(parent, start, stop, subText, priority)
    if not parent then
        log.err("Failed to create extract because parent is nil")
        return nil
    end

    local extractRow = repCreators.copyCommon(parent.row, {}, extractHeader)
    if not extractRow then
        log.err("Failed to create extract row")
        return nil
    end

    if not priority then priority = parent.row.priority end
    if not subText then subText = "" end

    extractRow["start"] = tostring(num.round(start, 2))
    extractRow["dismissed"] = 0
    extractRow["toexport"] = 0
    extractRow["created"] = tostring(os.time())
    extractRow["afactor"] = 2
    extractRow["stop"] = tostring(num.round(stop, 2))
    extractRow["id"] = sys.uuid()
    extractRow["interval"] = 1
    extractRow["nextrep"] = "1970-01-01"
    extractRow["parent"] = parent.row["id"]
    extractRow["speed"] = 1
    extractRow["notes"] = ""
    extractRow["priority"] = priority
    extractRow["subs"] = subText

    return ExtractRep(extractRow)
end

local function get_audio_stream_path()
    local stream = mp.get_property("stream-path")
    local matches = stream:gmatch("https://[^;]+")
    local audioUrl
    local format
    for v in matches do
        format = v:gmatch("mime=audio%%2F([a-z0-9]+)&")()
        if format then
            audioUrl = v
            break
        end
    end
    return audioUrl, format
end

local function get_video_stream_path()
    local stream = mp.get_property("stream-path")
    local matches = stream:gmatch("https://[^;]+")
    local videoUrl
    local format
    for v in matches do
        format = v:gmatch("mime=video%%2F([a-z0-9]+)&")()
        if format then
            videoUrl = v
            break
        end
    end
    return videoUrl, format
end

function repCreators.download_yt_audio(fullUrl, start, stop)
    local audioFileNameNoExt = tostring(os.time())

    local audioUrl, format = get_audio_stream_path()
    if obj.empty(audioUrl) or obj.empty(format) then
        log.err("Failed to get youtube audio stream.")
        return nil
    end

    local audioFileNameWithExt = audioFileNameNoExt .. "." .. format
    local ret = ffmpeg.audio_extract(start, stop, audioUrl, mpu.join_path(
                                         fs.media, audioFileNameWithExt))
    return ret.status == 0 and audioFileNameWithExt or nil
end

function repCreators.extract_media(parent, start, stop, type)
    local vidStreamUrl
    local mediaFileNameNoExt = tostring(os.time())

    if parent:is_yt() then
        vidStreamUrl = get_video_stream_path()
    elseif parent:is_local() then
        vidStreamUrl = player.get_full_url(parent)
    end

    local ret
    local mediaFileNameWithExt

    if type == "screenshot" then
        mediaFileNameWithExt = mediaFileNameNoExt .. ".jpg"
        ret = ffmpeg.screenshot(vidStreamUrl, start,
                                mpu.join_path(fs.media, mediaFileNameWithExt))
    elseif type == "gif" then
        mediaFileNameWithExt = mediaFileNameNoExt .. ".gif"
        ret = ffmpeg.extract_gif(vidStreamUrl, start, stop,
                                 mpu.join_path(fs.media, mediaFileNameWithExt))
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
            sound["path"] = fullUrl
        elseif parent:is_yt() then

            -- here, sound["path"] is relative to fs.media!
            sound["path"] = repCreators.download_yt_audio(fullUrl,
                                                          sound["start"],
                                                          sound["stop"])

            -- Adjust to relative times after extracting audio
            if format["name"] == item_format.cloze or format["name"] ==
                item_format.cloze_context then
                format["cloze-start"] = format["cloze-start"] - sound["start"]
                format["cloze-stop"] = format["cloze-stop"] - sound["start"]
            end
            sound["stop"] = sound["stop"] - sound["start"]
            sound["start"] = 0
        end

        if not sound["path"] or
            not file.exists(mpu.join_path(fs.media, sound["path"])) then
            log.debug("Failed to get audio.")
            return nil
        end
    end

    if media ~= nil then
        media["path"] = repCreators.extract_media(parent, media["start"],
                                                  media["stop"], media["type"])
        if not media["path"] or
            not file.exists(mpu.join_path(fs.media, media["path"])) then
            log.debug("Failed to get media.")
            return nil
        end
    end

    log.debug("media: ", media)

    local edlFileNameWithExt = tostring(os.time()) .. ".edl"
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
        ret = edl:write(sound, format, media)
    end

    if not ret or not file.exists(edlFullPathWithExt) then
        log.debug("Failed to create item: failed to write EDL file.")
        return nil
    end

    -- Create item row
    local itemRep = repCreators.create_item_rep(parent, sound, text, format,
                                                edlFileNameWithExt)
    if not itemRep then
        log.debug("Failed to create item: item rep was nil.")
        return false
    end

    log.debug("Successfully created item: ", itemRep)
    return itemRep
end

function repCreators.create_item_rep(parent, sound, text, format,
                                     edlFileNameWithExt)
    local itemRow = repCreators.copyCommon(parent.row, {}, itemHeader)
    if not itemRow then
        log.err("Failed to create item row.")
        return nil
    end

    local answer = ""
    local question = ""
    if text then
        answer = text["answer"]
        question = text["question"]
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
    itemRow["question"] = question
    itemRow["answer"] = answer

    -- Format
    itemRow["format"] = format["name"]

    -- Misc
    itemRow["speed"] = 1
    itemRow["subs"] = parent.row.subs and parent.row.subs or ""

    return ItemRep(itemRow)
end

return repCreators
