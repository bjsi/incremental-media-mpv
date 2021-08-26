local sys = require 'systems.system'
local cfg = require 'systems.config'
local ffmpeg = require 'systems.ffmpeg'
local active = require 'systems.active'
local str = require 'utils.str'
local repCreators = require 'reps.rep.repCreators'
local mpu = require 'mp.utils'
local ydl = require 'systems.ydl'
local log = require 'utils.log'
local rep_factory = require 'reps.rep.repCreators' -- TODO
local tbl = require 'utils.table'
local obj = require 'utils.object'
local num = require 'utils.number'

local GlobalTopics
local LocalExtracts

local importer = {}

function importer.import_extract(args)
    GlobalTopics = GlobalTopics or require('queues.global.topics')
    local topics = GlobalTopics(nil)
    local predicate = function(r) return r.row.title == args["title"] and r.row.type == "local-oc" end
    local folder = tbl.first(predicate, topics.reptable.reps)
    if folder == nil then
        local duration = ffmpeg.get_duration(args["path"])
        folder = rep_factory.createTopic(args["title"], "local-oc",
                                         args["path"], args["priority"],
                                         duration, nil)
        if not importer.add_topics_to_queue({folder}) then
            log.notify("Failed to import extract.")
            return false
        end
    end

    local extract = rep_factory.createExtract(folder, folder.row.start,
                                              folder.row.stop, "",
                                              args["priority"])
    extract.row["url"] = cfg["add_extract"]
    LocalExtracts = LocalExtracts or require('queues.local.extracts')
    local extracts = LocalExtracts(nil)
    extracts.reptable:add_to_reps(extract)
    extracts:save_data()
    return extract
end

function importer.split_and_import_chapters(info, cur)

    if obj.empty(info) then
        log.debug("Youtube info is nil.")
        return false
    end

    local chapters = info["chapters"]
    if obj.empty(chapters) then
        log.debug("Chapters are nil.")
        return false
    end

    local topics = {}
    local prevId = ""
    for _, chapter in ipairs(chapters) do
        local topic = importer.create_yt_topic(info, prevId)
        prevId = topic.row["id"]
        topic.row["start"] = chapter["start"]
        topic.row["stop"] = chapter["stop"]
        table.insert(topics, topic)
    end

    local duplicateIds = {cur.row["id"]}
    return importer.add_topics_to_queue(topics, duplicateIds)
end

function importer.import_from_clipboard()
    local url, _ = sys.clipboard_read()
    if obj.empty(url) then
        log.debug("Url is nil.")
        return
    end
    return importer.import(url)
end

function importer.import(url)

    local fileinfo, _ = mpu.file_info(url)
    local topics
    if fileinfo then
        if fileinfo then -- if file
            topics = importer.create_local_topics(url)
        else -- if directory
            topics = importer.create_local_topics(url)
        end
    else
        local infos = ydl.get_info(url)
        topics = importer.create_yt_topics(infos)
    end

    return importer.add_topics_to_queue(topics)
end

function importer.add_topics_to_queue(topics, allowedDuplicateIds)

    local queue
    if active.queue ~= nil and active.queue.name:find("Topic") then
        queue = active.queue
    else
        GlobalTopics = GlobalTopics or require("queues.global.topics")
        queue = GlobalTopics(nil)
    end

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

    if imported then queue:save_data() end

    return imported
end

-- TODO: import directory
function importer.create_local_topics(url)
    local _, fn = mpu.split_path(url)
    local title = str.remove_db_delimiters(str.remove_ext(fn))
    local priority = 30
    local duration = ffmpeg.get_duration(url)
    local topic = repCreators.createTopic(title, "local", url, priority,
                                          duration)
    return {topic}
end

function importer.create_yt_topic(info, prevId, priority)
    local title = str.remove_db_delimiters(info["title"])
    local ytId = info["id"]
    local duration = info["duration"]
    return repCreators.createTopic(title, "youtube", ytId, priority, duration,
                                   prevId)
end

function importer.create_yt_topics(infos, splitChaps, download, priMin, priMax,
                                   dependencyImport)
    if infos == nil then return {} end

    if tonumber(priMin) == nil or tonumber(priMax) == nil then
        priMin = cfg.default_priority_min
        priMax = cfg.default_priority_max
    end

    local topics = {}
    local prevId = ""
    for _, info in ipairs(infos) do
        if info then

            -- TODO: chapters
            -- TODO: download
            local priStep = (priMax - priMin) / #infos
            local curPriority = priMin;
            local topic = importer.create_yt_topic(info, prevId, curPriority)
            table.insert(topics, topic)
            prevId = dependencyImport and topic.row["id"] or ""
            curPriority = num.round(curPriority + priStep, 2);
        end
    end
    return topics
end

return importer
