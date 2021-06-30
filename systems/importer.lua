local sys = require("systems.system")
local GlobalTopicQueue = require("queue.globalTopicQueue")
local str = require("utils.str")
local repCreators = require("reps.rep.repCreators")
local mpu = require("mp.utils")
local ydl = require("systems.ydl")
local ext = require("utils.ext")
local log = require "utils.log"

local importer = {}

function importer.import()
    local url = sys.clipboard_read()
    log.debug("Importer found url: ", url)

    if ext.empty(url) then
        log.debug("Url is nil.")
        return
    end

    local fileinfo, _ = mpu.file_info(url)
    local topics = fileinfo and importer.create_local_topic(url) or importer.create_yt_topic(url)
    local gtq = GlobalTopicQueue(nil)
    for _, v in ipairs(topics) do
        if v then
            log.debug("Importing topic: ", v.row["title"])
            gtq.reptable:add_to_reps(v)
        end
    end
end

function importer.create_local_topic(url)
    local _, fn = mpu.split_path(url)
    local title = str.only_alphanumeric(str.remove_ext(fn))
    local priority = 30
    return {[1]=repCreators.createTopic(title, "local", url, priority)}
end

function importer.create_yt_topic(url)
    local infos = ydl.get_info(url)
    local topics = {}
    for info in pairs(infos) do
        if info then
            local title = str.only_alphanumeric(info["title"])
            table.insert(topics, repCreators.createTopic(title, "youtube", url, 30))
        end
    end
    return topics
end

return importer