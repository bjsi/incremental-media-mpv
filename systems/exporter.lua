local cfg = require 'systems.config'
local file = require 'utils.file'
local json_rpc = require 'systems.json_rpc'
local tbl = require 'utils.table'
local b64 = require 'utils.base64'
local ClozeEDL = require 'systems.edl.edl'
local QAEDL = require 'systems.edl.qaEdl'
local ClozeContextEDL = require 'systems.edl.clozeContextEdl'
local ffmpeg = require 'systems.ffmpeg'
local player = require 'systems.player'
local mpu = require 'mp.utils'
local sys = require 'systems.system'
local log = require 'utils.log'
local fs = require 'systems.fs'
local str = require 'utils.str'
local item_format = require 'reps.rep.item_format'

local GlobalItems
local GlobalExtracts
local GlobalTopics

local exporter = {}

local function getParent(parents, child) return parents[child.row["parent"]] end

local function getGrandparent(grandparents, parents, child)
    local parent = getParent(parents, child)
    if parent then return grandparents[parent.row["parent"]] end
end

local function read_as_b64(fp)
    log.debug("Reading", fp, "as b64.")
    local h = io.open(fp, "rb")
    local data = h:read("*all")
    h:close()
    return b64.encode(data)
end

function exporter.create_topic_export_data(v)
    local topic = {
        id = v.row["id"],
        title = v.row.title,
        url = player.get_full_url(v, v.row.start),
        start = v.row.start,
        qtext = "",
        stop = v.row.stop,
        priority = v.row.priority,
        extracts = {
            ["NULL"] = {id = "NULL"} -- so mpu.format_json turns it into a dict
        }
    }

    return topic
end

function exporter.create_extract_export_data(v)
    local extract = {
        id = v.row["id"],
        parent = v.row["parent"],
        url = player.get_full_url(v, v.row["start"]),
        start = v.row.start,
        stop = v.row.stop,
        subs = v.row.subs,
        notes = v.row.notes,
        priority = v.row.priority,
        items = {
            ["NULL"] = {id = "NULL"} -- so mpu.format_json turns it into a dict
        }
    }
    return extract
end

function exporter.add_qa_data(itemRep, exportItem, sound)
    local soundPath
    if sound and not sound["showat"] == "no" then
        soundPath = sound["path"]
        if not itemRep:is_local() then
            soundPath = mpu.join_path(fs.media, soundPath)
        end

        -- Add flashcard media
        local mediaFullPathWithExt = mpu.join_path(sys.tmp_dir,
                                                   sys.uuid() .. ".mp3")
        if not ffmpeg.generate_qa_item_files(soundPath, mediaFullPathWithExt) then
            log.err("Failed to generate cloze context item files.")
            return false
        end

        table.insert(exportItem["flashcard_medias"], {
            type = "sound",
            showat = "answer",
            fname = str.basename(mediaFullPathWithExt),
            text = "audio cloze context answer",
            b64 = read_as_b64(mediaFullPathWithExt)
        })
    end

    return true
end

function exporter.add_cloze_context_data(itemRep, exportItem, sound, format)
    local soundFullPathWithExt = sound["path"]
    if not itemRep:is_local() then
        soundFullPathWithExt = mpu.join_path(fs.media, soundFullPathWithExt)
    end

    -- Add stored media
    table.insert(exportItem["stored_medias"], {
        fname = str.basename(soundFullPathWithExt),
        b64 = read_as_b64(soundFullPathWithExt)
    })

    -- Add flashcard media
    local aFpath = mpu.join_path(sys.tmp_dir, sys.uuid() .. ".mp3")
    if not ffmpeg.generate_cloze_context_item_files(soundFullPathWithExt, sound,
                                                    format, aFpath) then
        log.err("Failed to generate cloze context item files.")
        return false
    end

    table.insert(exportItem["flashcard_medias"], {
        type = "sound",
        showat = "answer",
        fname = str.basename(aFpath),
        text = "audio cloze context answer",
        b64 = read_as_b64(aFpath)
    })

    return true
end

function exporter.add_cloze_data(itemRep, exportItem, sound, format)
    local soundFullPathWithExt = sound["path"]
    if not file.is_absolute(soundFullPathWithExt) then
        soundFullPathWithExt = mpu.join_path(fs.media, sound["path"])
    end

    -- Add stored media
    table.insert(exportItem["stored_medias"], {
        fname = str.basename(soundFullPathWithExt),
        b64 = read_as_b64(soundFullPathWithExt)
    })

    -- Add flashcard media
    local questionFullWithExt = mpu.join_path(sys.tmp_dir, sys.uuid() .. "." ..
                                                  cfg.audio_format)
    local answerFullWithExt = mpu.join_path(sys.tmp_dir, sys.uuid() .. "." ..
                                                cfg.audio_format)
    if not ffmpeg.generate_cloze_item_files(soundFullPathWithExt, sound, format,
                                            questionFullWithExt,
                                            answerFullWithExt) then
        log.err("Failed to generate item files.")
        return false
    end

    table.insert(exportItem["flashcard_medias"], {
        type = "sound",
        showat = "question",
        fname = str.basename(questionFullWithExt),
        text = "audio cloze question",
        b64 = read_as_b64(questionFullWithExt)
    })

    table.insert(exportItem["flashcard_medias"], {
        type = "sound",
        showat = "answer",
        fname = str.basename(answerFullWithExt),
        text = "audio cloze answer",
        b64 = read_as_b64(answerFullWithExt)
    })
    return true
end

function exporter.create_item_export_data(itemRep)

    local exportItem = {
        id = itemRep.row["id"],
        parent = itemRep.row["parent"],
        qtext = itemRep.row.question,
        atext = itemRep.row.answer,
        edl = file.read_all_text(player.get_full_url(itemRep)),
        format = itemRep.row["format"],
        flashcard_medias = {},
        stored_medias = {},
        priority = itemRep.row["priority"],
        start = itemRep.row["start"],
        stop = itemRep.row["stop"],
        speed = itemRep.row["speed"],
        subs = itemRep.row["subs"]
    }

    local sound, format, media
    local edlFullPathWithExt = player.get_full_url(itemRep)

    local ret
    if itemRep.row.format == item_format.cloze then
        local edl = ClozeEDL.new(edlFullPathWithExt)
        sound, format, media = edl:read()
        ret = exporter.add_cloze_data(itemRep, exportItem, sound, format)
    elseif itemRep.row.format == item_format.cloze_context then
        local edl = ClozeContextEDL.new(edlFullPathWithExt)
        sound, format, media = edl:read()
        ret =
            exporter.add_cloze_context_data(itemRep, exportItem, sound, format)
    elseif itemRep.row.format == item_format.qa then
        local edl = QAEDL.new(edlFullPathWithExt)
        sound, format, media = edl:read()
        ret = exporter.add_qa_data(itemRep, exportItem, sound)
    end

    if not ret then
        log.debug("Failed to add data to " .. itemRep.row["format"] ..
                      " export item")
        return nil
    end

    if media ~= nil then
        local mediaFullPathWithExt = mpu.join_path(fs.media, media["path"])
        table.insert(exportItem["flashcard_medias"], {
            type = "image",
            showat = media["showat"],
            fname = media["path"],
            text = "",
            b64 = read_as_b64(mediaFullPathWithExt)
        })
    end

    return exportItem
end

function exporter.get_last_export_time()
    log.debug("Getting last export time for queue:", cfg.queue, "from SMA.")
    local ret = json_rpc.send_sma_request("GetLastImportTime", {cfg.queue})
    if ret then
        local jobj = mpu.parse_json(ret.stdout)
        if jobj then return tonumber(jobj.result) end
    end

    return nil
end

function exporter.update_sm_item(itemRep)
    if not json_rpc.send_sma_request("Ping") then
        log.notify("Failed to connect to SMA.")
        return false
    end

    local itemExportData = exporter.create_item_export_data(itemRep)
    if itemExportData == nil then
        log.debug("Failed to create item export data")
        return false
    end

    return json_rpc.send_sma_request("UpdateItem", {cfg.queue, itemExportData})
               .status == 0
end

function exporter.export_new_items_to_sm(lastExportTime)
    lastExportTime = tonumber(lastExportTime)
    if lastExportTime == nil then
        log.debug("Failed to get last export time from SMA.")
        return false
    end
    local predicate = function(itemRep)
        return tonumber(itemRep.row.created) > lastExportTime
    end
    return exporter.export_to_sm(predicate)
end

function exporter.export_to_sm(predicate)
    if not json_rpc.send_sma_request("Ping") then
        log.notify("Failed to connect to SMA.")
        return false
    end

    log.debug("Successfully pinged SMA.")

    GlobalTopics = GlobalTopics or require("queues.global.topics")
    local gtq = GlobalTopics(nil)
    local grandParents = tbl.index_by_key(gtq.reptable.reps, "id")

    GlobalExtracts = GlobalExtracts or require("queues.global.extracts")
    local geq = GlobalExtracts(nil)
    local parents = tbl.index_by_key(geq.reptable.reps, "id")

    GlobalItems = GlobalItems or require("queues.globalItemQueue")
    local giq = GlobalItems(nil)
    local toExport = tbl.filter(giq.reptable.reps, predicate)

    local topics = {} -- id indexed
    for _, v in ipairs(toExport) do
        local grandparent = getGrandparent(grandParents, parents, v)
        if topics[grandparent.row.id] == nil then
            local topic = exporter.create_topic_export_data(grandparent)
            topics[topic.id] = topic
        end

        local parent = getParent(parents, v)
        if topics[grandparent.row.id].extracts[parent.row.id] == nil then
            local extract = exporter.create_extract_export_data(parent)
            topics[grandparent.row.id].extracts[parent.row.id] = extract
        end

        local item = exporter.create_item_export_data(v)
        topics[grandparent.row.id].extracts[parent.row.id].items[item.id] = item
    end

    json_rpc.send_sma_request("ImportTopics", {cfg.queue, topics})
end

-- TODO: Need to update to the latest version of EDL files and item creation
-- function exporter.as_sm_xml(outputFolder)

--     log.err("This function is broken")

--     GlobalTopicQueue = GlobalTopicQueue or require("queues.global.topics")
--     local gtq = GlobalTopicQueue(nil)
--     local grandParents = ext.index_by_key(gtq.reptable.reps, "id")

--     GlobalItemQueue = GlobalItemQueue or require("queues.global.items")
--     local giq = GlobalItemQueue(nil)
--     local toExport = ext.filter(giq.reptable.reps, function(r) return r:to_export() end)
--     if obj.empty(toExport) then
--         log.debug("No item repetitions to export.")
--         return false
--     end

--     GlobalExtractQueue = GlobalExtractQueue or require("queues.global.extracts")
--     local geq = GlobalExtractQueue(nil)
--     local parents = tbl.index_by_key(geq.reptable.reps, "id")

--     local info, _ = mpu.file_info(outputFolder)
--     if ext.empty(outputFolder) or info ~= nil then
--         log.debug("Invalid outputFolder path or already exists.")
--         return false
--     end

--     if not sys.create_dir(outputFolder) then
--         log.debug("Failed to create export output folder: " .. outputFolder)
--         return false
--     end

--     local filesFolder = mpu.join_path(outputFolder, "files")
--     if not sys.create_dir(filesFolder) then
--         log.debug("Failed to create media files folder for export.")
--         return false
--     end

--     local moveMeFolder = mpu.join_path(outputFolder, "export-" .. os.time())
--     if not sys.create_dir(moveMeFolder) then
--         log.err("Failed to create the move inside sm folder.")
--         return false
--     end

--     log.debug("Successfully created output folder: " .. outputFolder)
--     log.debug(tostring(#toExport) .. " items to export.")

--     local collection = collection.new(outputFolder)
--     local root = collection.root

--     local ct = 1

--     for _, extract in pairs(parents) do
--         local children = tbl.filter(toExport, function(r) return r:is_child_of(extract) end)
--         if not obj.empty(children) then
--             local topic = getParent(grandParents, extract)
--             local title = topic.row["title"]

--             local extractFolder = element.new("SuperMemoElement")
--             local t = table.concat(
--                 {
--                     title,
--                     "::",
--                     extract.row["start"],
--                     "->",
--                     extract.row["stop"]
--                 }, " ")

--             extractFolder:with_id(ct + 1):with_title(t):with_type("Topic")

--             local content = element.new("Content")
--             extractFolder:add_child(content)

--             local r = references.new():with_title(title):with_link(player.get_full_url(extract, extract.row["start"]))
--             content:add_question("", r) -- TODO: Add subs here

--             root:add_child(extractFolder)
--             ct = ct + 1 -- parentFolder

--             for _, child in ipairs(children) do

--                 local audioEl = element.new("SuperMemoElement")
--                 audioEl:with_id(tostring(ct + 1)):with_title(title):with_type("Item")

--                 local content = element.new("Content")
--                 audioEl:add_child(content)

--                 -- TODO: add start time for item
--                 local ref = references.new():with_title(title):with_link(player.get_full_url(child))
--                 local url = player.get_full_url(child)
--                 local _, folder = mpu.split_path(moveMeFolder)
--                 local relPathEdl = mpu.join_path(folder, child.row["url"])
--                 local jsonString = mpu.format_json(
--                     {
--                         ["EDL"]=relPathEdl,
--                         ["SPEED"]=child.row["speed"],
--                         ["START"]=child.row["start"],
--                         ["STOP"]=child.row["stop"],
--                         ["YT"]=child:is_yt() and extract.row["url"] or nil,
--                     })
--                 local encoded = b64.encode(jsonString)
--                 local div = ([[<div id="incmedia-data-json">%s</div>]]):format(encoded)
--                 local html = ("<div>%s</div><br>%s"):format(title, div)
--                 content:add_question(str.escape_special_chars(html), ref)

--                 -- Create question and answer
--                 local edl = ClozeEDL.new(url)
--                 local parentPath, parentStart, parentEnd, clozeStart, clozeEnd, mediaFile = edl:read()
--                 local qFname = table.concat({child.row["id"], "-q", ".", "mp3"})
--                 local aFname = table.concat({child.row["id"], "-a", ".", "mp3"})
--                 local qFpath = mpu.join_path(filesFolder, qFname)
--                 local aFpath = mpu.join_path(filesFolder, aFname)
--                 if not child:is_local() then
--                     parentPath = mpu.join_path(fs.media, parentPath)
--                 end

--                 if not ffmpeg.generate_item_files(parentPath, parentStart, parentEnd, clozeStart, clozeEnd, qFpath, aFpath) then
--                     log.err("Failed to generate item files.")
--                     return false
--                 end

--                 if not obj.empty(mediaFile) then
--                     content:add_image("files\\" .. mediaFile)
--                     sys.copy(mpu.join_path(fs.media, mediaFile), mpu.join_path(filesFolder, mediaFile))
--                 end

--                 content:add_sound(true, "files\\" .. qFname, qFname)
--                 content:add_sound(false, "files\\" .. aFname, aFname)

--                 extractFolder:add_child(audioEl)
--                 ct = ct + 1

--                 local toCopy = { parentPath, fs.sine, url }
--                 for _, f in ipairs(toCopy) do
--                     local _, fname = mpu.split_path(f)
--                     if not file.copy(f, mpu.join_path(moveMeFolder, fname)) then
--                         log.err("Failed to copy " .. fname .. " to the move inside sm folder")
--                     end
--                 end

--                 child.row["toexport"] = "0"
--                 child.row["dismissed"] = "1"
--             end
--         end
--     end

--     if collection:write(#toExport) then
--         log.debug("Successfully wrote XML data.")
--         giq:save_data()
--         return true
--     end

--     log.err("Failed to write XML data.")
--     return false
-- end

return exporter
