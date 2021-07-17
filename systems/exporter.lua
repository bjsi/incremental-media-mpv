local ext = require("utils.ext")
local b64 = require("utils.base64")
local EDL = require("systems.edl")
local ffmpeg = require("systems.ffmpeg")
local player = require("systems.player")
local mpu = require("mp.utils")
local sys = require("systems.system")
local log = require "utils.log"
local collection = require "systems.sm.xml.collection"
local element = require "systems.sm.xml.element"
local references = require "systems.sm.xml.references"
local fs         = require "systems.fs"
local str        = require "utils.str"

local GlobalItemQueue
local GlobalExtractQueue
local GlobalTopicQueue

local exporter = {}

local function getParent(parents, child)
    return parents[child.row["parent"]]
end

local function getGrandparent(grandparents, parents, child)
    local parent = getParent(parents, child)
    if parent then
        return grandparents[parent.row["parent"]]
    end
end

function exporter.as_sm_xml(outputFolder)

    GlobalTopicQueue = GlobalTopicQueue or require("queue.globalTopicQueue")
    local gtq = GlobalTopicQueue(nil)
    local grandParents = ext.index_by_key(gtq.reptable.reps, "id")

    GlobalItemQueue = GlobalItemQueue or require("queue.globalItemQueue")
    local giq = GlobalItemQueue(nil)
    local toExport = ext.list_filter(giq.reptable.reps, function(r) return r:to_export() end)
    if ext.empty(toExport) then
        log.debug("No item repetitions to export.")
        return false
    end

    GlobalExtractQueue = GlobalExtractQueue or require("queue.globalExtractQueue")
    local geq = GlobalExtractQueue(nil)
    local parents = ext.index_by_key(geq.reptable.reps, "id")

    local info, _ = mpu.file_info(outputFolder)
    if ext.empty(outputFolder) or info ~= nil then
        log.debug("Invalid outputFolder path or already exists.")
        return false
    end
    
    if not sys.create_dir(outputFolder) then
        log.debug("Failed to create export output folder: " .. outputFolder)
        return false
    end

    local filesFolder = mpu.join_path(outputFolder, "files")
    if not sys.create_dir(filesFolder) then
        log.debug("Failed to create media files folder for export.")
        return false
    end

    local moveMeFolder = mpu.join_path(outputFolder, "export-" .. os.time())
    if not sys.create_dir(moveMeFolder) then
        log.err("Failed to create the move inside sm folder.")
        return false
    end

    log.debug("Successfully created output folder: " .. outputFolder)
    log.debug(tostring(#toExport) .. " items to export.")

    local collection = collection.new(outputFolder)
    local root = collection.root

    local ct = 1

    for _, extract in pairs(parents) do
        local children = ext.list_filter(toExport, function(r) return r:is_child_of(extract) end)
        if not ext.empty(children) then
            local topic = getParent(grandParents, extract)
            local title = topic.row["title"]

            local extractFolder = element.new("SuperMemoElement")
            local t = table.concat(
                {
                    title,
                    "::",
                    extract.row["start"],
                    "->",
                    extract.row["stop"]
                }, " ")

            extractFolder:with_id(ct + 1):with_title(t):with_type("Topic")

            local content = element.new("Content")
            extractFolder:add_child(content)

            local r = references.new():with_title(title):with_link(player.get_full_url(extract, extract.row["start"]))
            content:add_question("", r) -- TODO: Add subs here

            root:add_child(extractFolder)
            ct = ct + 1 -- parentFolder

            for _, child in ipairs(children) do

                local audioEl = element.new("SuperMemoElement")
                audioEl:with_id(tostring(ct + 1)):with_title(title):with_type("Item")
                
                local content = element.new("Content")
                audioEl:add_child(content)

                -- TODO: add start time for item
                local ref = references.new():with_title(title):with_link(player.get_full_url(child))
                local url = player.get_full_url(child)
                local _, folder = mpu.split_path(moveMeFolder)
                local relPathEdl = mpu.join_path(folder, child.row["url"])
                local jsonString = mpu.format_json(
                    {
                        ["EDL"]=relPathEdl,
                        ["SPEED"]=child.row["speed"],
                        ["START"]=child.row["start"],
                        ["STOP"]=child.row["stop"],
                        ["YT"]=child:is_yt() and extract.row["url"] or nil,
                    })
                local encoded = b64.encode(jsonString)
                local div = ([[<div id="incmedia-data-json">%s</div>]]):format(encoded)
                local html = ("<div>%s</div><br>%s"):format(title, div)
                content:add_question(str.escape_special_chars(html), ref)

                -- Create question and answer
                local edl = EDL.new(url)
                local parentPath, parentStart, parentEnd, clozeStart, clozeEnd, mediaFile = edl:read()
                local qFname = table.concat({child.row["id"], "-q", ".", "mp3"})
                local aFname = table.concat({child.row["id"], "-a", ".", "mp3"})
                local qFpath = mpu.join_path(filesFolder, qFname)
                local aFpath = mpu.join_path(filesFolder, aFname)
                if not child:is_local() then
                    parentPath = mpu.join_path(fs.media, parentPath)
                end

                if not ffmpeg.generate_item_files(parentPath, parentStart, parentEnd, clozeStart, clozeEnd, qFpath, aFpath) then
                    log.err("Failed to generate item files.")
                    return false
                end

                if not ext.empty(mediaFile) then
                    content:add_image("files\\" .. mediaFile)
                    sys.copy(mpu.join_path(fs.media, mediaFile), mpu.join_path(filesFolder, mediaFile))
                end

                content:add_sound(true, "files\\" .. qFname, qFname)
                content:add_sound(false, "files\\" .. aFname, aFname)

                extractFolder:add_child(audioEl)
                ct = ct + 1

                local toCopy = { parentPath, fs.sine, url }
                for _, f in ipairs(toCopy) do
                    local _, fname = mpu.split_path(f)
                    if not sys.copy(f, mpu.join_path(moveMeFolder, fname)) then
                        log.err("Failed to copy " .. fname .. " to the move inside sm folder")
                    end
                end

                child.row["toexport"] = "0"
                child.row["dismissed"] = "1"
            end
        end
    end

    if collection:write(#toExport) then
        log.debug("Successfully wrote XML data.")
        giq:save_data()
        return true
    end

    log.err("Failed to write XML data.")
    return false
end

return exporter