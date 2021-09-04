local sys = require 'systems.system'
local cfg = require 'systems.config'
local ffmpeg = require 'systems.ffmpeg'
local active = require 'systems.active'
local str = require 'utils.str'
local repCreators = require 'reps.rep.repCreators'
local ydl = require 'systems.ydl'
local log = require 'utils.log'
local rep_factory = require 'reps.rep.repCreators' -- TODO
local tbl = require 'utils.table'
local obj = require 'utils.object'
local num = require 'utils.number'
local Playlist = require 'systems.playlists.playlist'
local PlaylistTable = require 'systems.playlists.playlist_table'

local GlobalTopics
local LocalExtracts

local importer = {}

function importer.create_yt_playlist(playlist_id, playlist_title)
    local row = {
        ["id"] = sys.uuid(),
        ["title"] = playlist_title,
        ["dismissed"] = 0,
        ["url"] = playlist_id
    }
    local playlist = Playlist(row)
    local t = PlaylistTable()
    if not t:add(playlist) then return nil end
    return playlist.row.id
end

---Import a YouTube playlist.
---@param infos table of YouTube video information.
---@param split_chapters boolean true if each video should be split by chapter.
---@param download boolean true if each video should be downloaded.
---@param priority_min number minimum priority.
---@param priority_max number maximum priority.
---@param pending_chapters boolean true if should add chapter backlog to pending queue.
---@param pending_videos boolean true if should add video backlog to pending queue.
---@param playlist_yt_id string YouTube id of the playlist.
---@param playlist_title string title of the playlist.
function importer.import_yt_playlist(infos, split_chapters, download,
                                     priority_min, priority_max,
                                     pending_chapters, pending_videos,
                                     playlist_yt_id, playlist_title)
    if obj.empty(infos) then
        log.debug("No YouTube videos.")
        return false
    end

    -- import playlist
    local imported_playlist_id = importer.create_yt_playlist(playlist_yt_id,
                                                             playlist_title)
    if not imported_playlist_id then
        log.debug("Failed to import playlist row.")
        return false
    end

    local prev_id = ""
    local pri_step = (priority_max - priority_min) / #infos
    local cur_priority = priority_min;
    for _, info in ipairs(infos) do

        -- imported video id, or final chapter id
        local imported_id = importer.import_yt_video(info, split_chapters,
                                                     download, cur_priority,
                                                     pending_chapters, prev_id,
                                                     imported_playlist_id)
        if not imported_id then
            log.notify("Failed to import YouTube video. Cancelling.", "info", 4)
            return false
        end
        cur_priority = num.round(cur_priority + pri_step, 2);
        if pending_videos then prev_id = imported_id end
    end
    return true
end

function importer.import_yt_video(info, split_chapters, download, priority,
                                  pending_chapters, vid_dependency_id,
                                  playlist_id)
    if obj.empty(info) then
        log.debug("Youtube info is nil.")
        return false
    end

    if download then
        local video_file = ydl.download_video(info["id"])
        if not video_file then
            log.debug("Failed to download video.")
            return false
        end
        info["downloaded_file"] = video_file
    end

    if split_chapters and not obj.empty(info["chapters"]) then
        return importer.import_yt_chapters(info, priority, pending_chapters,
                                           vid_dependency_id, playlist_id)
    else
        local topic = importer.create_yt_topic(info, vid_dependency_id,
                                               priority, playlist_id)
        importer.add_topics_to_queue({topic}, false)
        return topic.row.id
    end
end

function importer.import_yt_chapters(info, priority, pending_chapters,
                                     vid_dependency_id, playlist)

    local dependency_id = vid_dependency_id
    local chapter_topics = {}
    for _, chapter in ipairs(info["chapters"]) do
        local chapter_topic = importer.create_yt_chapter(info, chapter,
                                                         priority,
                                                         dependency_id, playlist)
        if not chapter_topic then
            log.debug("Failed to create YouTube video chapter topic.")
            return false
        end

        table.insert(chapter_topics, chapter_topic)
        if pending_chapters then dependency_id = chapter_topic.row.id end
    end
    importer.add_topics_to_queue(chapter_topics, true)
    return dependency_id
end

function importer.create_yt_chapter(info, chapter, priority, dependency,
                                    playlist_id)

    local type
    local url
    if info["downloaded_file"] then
        type = "local"
        url = info["downloaded_file"]
    else
        type = "youtube"
        url = info["id"]
    end

    local title = str.remove_db_delimiters(
                      info["title"] .. ": " .. chapter["title"])
    local topic = rep_factory.createTopic(title, type, url, priority,
                                          info["duration"], dependency,
                                          playlist_id)
    topic.row["start"] = chapter["start_time"]
    topic.row["stop"] = chapter["end_time"]
    topic.row["curtime"] = chapter["start_time"]
    return topic
end

function importer.import_extract(args)
    GlobalTopics = GlobalTopics or require('queues.global.topics')
    local topics = GlobalTopics(nil)
    local predicate = function(r)
        return r.row.title == args["title"] and r.row.type == "local-oc"
    end
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

function importer.add_topics_to_queue(topics, chapters)
    local queue
    if active.queue ~= nil and active.queue.name:find("Topic") then
        queue = active.queue
    else
        GlobalTopics = GlobalTopics or require("queues.global.topics")
        queue = GlobalTopics(nil)
    end

    local imported = false
    for _, topic in ipairs(topics) do
        local exists
        if chapters then
            exists = queue.reptable:chapter_exists(topic)
        else
            exists = queue.reptable:exists(topic)
        end
        if not exists then
            log.notify("Importing: " .. topic.row["title"])
            if queue.reptable:add_to_reps(topic) then imported = true end
        else
            log.debug("Skipping already-existing topic: " .. topic.row["title"])
        end
    end

    if imported then queue:save_data() end

    return imported
end

function importer.create_yt_topic(info, dependency_id, priority, playlist_id)
    local title = str.remove_db_delimiters(info["title"])
    local youtube_id = info["id"]
    local duration = info["duration"]
    return repCreators.createTopic(title, "youtube", youtube_id, priority,
                                   duration, dependency_id, playlist_id)
end

return importer
