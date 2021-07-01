local sys = require("systems.system")
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
    log.debug("Importer found url: ", url)

    if not url then
        log.debug("Url is nil.")
        return
    end

    local fileinfo, _ = mpu.file_info(url)
    local topics = fileinfo and importer.create_local_topics(url) or importer.create_yt_topics(url)

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
    local title = str.only_alphanumeric(str.remove_ext(fn))
    local priority = 30
    local topic = repCreators.createTopic(title, "local", url, priority)
    return {topic}
end

function importer.create_yt_topics(url)
    local infos = ydl.get_info(url)
    log.debug("Infos: ", infos)
    if not infos then return nil end
    local topics = {}
    for _, info in ipairs(infos) do
        if info then
            local title = str.only_alphanumeric(info["title"])
            local id = info["id"]
            table.insert(topics, repCreators.createTopic(title, "youtube", id, 30))
        end
    end
    return topics
end

return importer