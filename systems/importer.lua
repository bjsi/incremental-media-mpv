local sys = require("systems.system")
local ffmpeg = require("systems.ffmpeg")
local active = require("systems.active")
local GlobalTopicQueue = require("queue.globalTopicQueue")
local str = require("utils.str")
local repCreators = require("reps.rep.repCreators")
local mpu = require("mp.utils")
local ydl = require("systems.ydl")
local log = require "utils.log"

local importer = {}

function importer.import()
    local url, _ = sys.clipboard_read()
    if not url then
        log.debug("Url is nil.")
        return
    end

    local fileinfo, _ = mpu.file_info(url)
    local topics
    if fileinfo then
        if fileinfo then -- if file
            topics = importer.create_local_topics(url)
        else -- if directory
            topics = importer.create_local_topics(url)
        end
    else
        topics = importer.create_yt_topics(url)
    end

    if active.queue and active.queue.name:find("Topic") then
        importer.add_topics_to_queue(topics, active.queue)
    else
        importer.add_topics_to_queue(topics, GlobalTopicQueue(nil))
    end
end

function importer.add_topics_to_queue(topics, queue)
    local imported = false
    for _, topic in ipairs(topics) do
        if not queue.reptable:exists(topic) then
            log.debug("Importing: " .. topic.row["title"])
            queue.reptable:add_to_reps(topic)
            imported = true
        else
            log.debug("Skipping already-existing topic: " .. topic.row["title"])
        end
    end

    if imported then
        queue:save_data()
    end
end

-- TODO: import directory
function importer.create_local_topics(url)
    local _, fn = mpu.split_path(url)
    local title = str.db_friendly(str.remove_ext(fn))
    local priority = 30
    local duration = ffmpeg.get_duration(url)
    local topic = repCreators.createTopic(title, "local", url, priority, duration)
    return {topic}
end

function importer.create_yt_topics(url)
    local infos = ydl.get_info(url)
    log.debug("Infos: ", infos)
    if not infos then return nil end
    local topics = {}
    local prevId = ""
    for _, info in ipairs(infos) do
        if info then
            local title = str.db_friendly(info["title"])
            local ytId = info["id"]
            local duration = info["duration"]
            local topic = repCreators.createTopic(title, "youtube", ytId, 30, duration, prevId)
            table.insert(topics, topic)
            prevId = topic.row["id"]
        end
    end
    return topics
end

return importer