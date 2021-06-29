local sys = require("systems.system")
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

    if mpu.file_info(url) then
        importer.import_local(url)
    else
        importer.import_yt(url)
    end
end

function importer.import_local(url)
    -- TODO: title?

    local topic = repCreators.createTopic()
end

function importer.import_yt(url)
    local infos = ydl.get_info(url)
    log.debug(infos)
end

return importer