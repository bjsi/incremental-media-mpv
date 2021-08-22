local log = require 'utils.log'
local mpu = require 'mp.utils'
local exporter = require 'systems.exporter'
local importer = require 'systems.importer'
local active = require 'systems.active'
local sys = require 'systems.system'
local GlobalTopics = require 'queue.globalTopicQueue'
local GlobalExtracts = require 'queue.globalExtractQueue'
local GlobalItems = require 'queue.globalItemQueue'
local LocalExtracts = require 'queue.localExtractQueue'
local SingletonExtract = require 'queue.singletons.extract'
local player = require 'systems.player'
local ext = require 'utils.ext'
local sounds = require 'systems.sounds'
local fs = require 'systems.fs'
local menuBase = require 'systems.menu.menuBase' -- TODO
local ffmpeg = require 'systems.ffmpeg'
local rep_factory = require 'reps.rep.repCreators' -- TODO
local cfg = require 'systems.config'
local get_user_input = require 'systems.user_input'
local mp = require 'mp'

local loaded = false

---Gets the first queue to be loaded when incremental media loads.
---@return QueueBase queue
local function get_startup_queue()

    -- if the script was launched to add an extract,
    -- start a singleton extract queue with the new extract.
    if not ext.empty(cfg.add_extract) then
        local extracts = LocalExtracts(nil)
        local predicate = function(r) return r.row.url == cfg.add_extract end
        local added_rep = ext.first_or_nil(predicate, extracts.reptable.reps)
        if added_rep == nil then
            log.notify('Failed to get added extract.')
            return nil
        end
        return SingletonExtract(added_rep.row.id)

    elseif not ext.empty(cfg.singleton_id) and not ext.empty(cfg.singleton_type) then
        local type = cfg.singleton_type
        local id = cfg["singleton_id"]
        return active.get_singleton_queue(type, id)

        -- get a topic, extract or item queue depending on which has
        -- outstanding reps.
    else
        local gt = GlobalTopics(nil)
        if gt and not ext.empty(gt.reptable.subset) then return gt end
        local ge = GlobalExtracts(nil)
        if ge and not ext.empty(ge.reptable.subset) then return ge end
        local gi = GlobalItems(nil)
        if gi and not ext.empty(gi.reptable.subset) then return gi end
    end
end

local function load_media()
    require 'systems.keybinds' -- register script messages
    require 'systems.api' -- register api script messages
    sys.setup_ipc() -- TODO: require systems.ipc

    if not mp.get_property_bool("audio-only") then
        mp.set_property("force-window", "yes")
    end

    mp.observe_property("time-pos", "number", player.loop_timer.check_loop)
    mp.set_property("loop", "inf")

    local queue = get_startup_queue()
    if not queue or ext.empty(queue.reptable.subset) then
        log.debug("No repetitions available. Creating empty topic queue...")
        queue = GlobalTopics(nil)
    end

    if not active.change_queue(queue) then menuBase.open() end
end

local function import_extract(args)
    local gtq = GlobalTopics(nil)
    local folder = ext.first_or_nil(function(r)
        return r.row.title == args["title"] and r.row.type == "local-oc"
    end, gtq.reptable.reps)
    if folder == nil then
        local duration = ffmpeg.get_duration(args["path"])
        folder = rep_factory.createTopic(args["title"], "local-oc",
                                         args["path"], args["priority"],
                                         duration, nil)
        if not importer.add_topics_to_queue({folder}) then
            log.notify("Failed to import")
            return false
        end
    end

    local extract = rep_factory.createExtract(folder, folder.row.start,
                                              folder.row.stop, "",
                                              args["priority"])
    extract.row["url"] = cfg["add_extract"]
    local leq = LocalExtracts(nil)
    leq.reptable:add_to_reps(extract)
    leq:save_data()
    return true
end

local function query_get_extract_priority(args)
    local handler = function(input)
        if input == nil then
            log.notify("Cancelled.")
            return
        end

        local pri = tonumber(input)
        if input == nil or not ext.validate_priority(pri) then
            log.notify("Invalid priority.")
            query_get_extract_priority(args)
            return
        end

        args["priority"] = pri
        if import_extract(args) then
            log.notify("Imported!")
            sounds.play("positive")
            load_media()
        end
    end

    get_user_input(handler, {text = "Priority: ", replace = true})
end

local function query_get_extract_title(path)
    local handler = function(input)
        if input == nil then
            log.notify("Cancelled.")
            return
        elseif input == "" then
            log.notify("Invalid title.")
            query_get_extract_title()
            return
        end

        local args = {}
        args["path"] = path
        args["title"] = input
        query_get_extract_priority(args)
    end

    get_user_input(handler, {text = "Title: ", replace = true})
end

local function run()
    if not loaded then
        loaded = true

        log.debug("Queue: ", fs.data)

        sys.verify_dependencies()
        sys.create_essential_files()
        sys.backup()

        sounds.start_background_process()
        mp.register_event("shutdown", active.on_shutdown)

        if not ext.empty(cfg["import"]) then
            local importTarget = cfg["import"]
            local ret = importer.import(importTarget)
            log.debug("Exiting after import....")
            local sound = ret and "positive" or "negative"
            sounds.play_sync(sound)
            mp.commandv("quit", ret and 0 or 1)

        elseif not ext.empty(cfg["add_extract"]) then
            local toImport = cfg["add_extract"]
            if not sys.exists(toImport) then
                log.debug(
                    "Failed to add extract because import file does not exist.")
                mp.commandv("quit", 1)
            end

            mp.set_property("force-window", "yes")
            query_get_extract_title(toImport)
            return

        elseif not ext.empty(cfg["export"]) then
            local exportFolder = cfg["export"]
            local ret = exporter.as_sm_xml(exportFolder)
            log.debug("Exiting after export...")
            local sound = ret and "positive" or "negative"
            sounds.play_sync(sound)
            mp.commandv("quit", ret and 0 or 1)
        end

        if cfg["start"] then load_media() end
    end
end

-- Only allows one instance of the script to
-- run for each queue.

local pid_file = mpu.join_path(fs.data, "pid_file")

local read_pid_file = function()
    local h = io.open(pid_file, "r")
    if h == nil then return -1 end
    local pid = h:read("*all")
    h:close()
    return pid
end

local write_pid_file = function()
    local h = io.open(pid_file, "w")
    if h == nil then return end
    h:write(mpu.getpid())
    h:close()
end

local delete_pid_file = function()
    log.debug("Removing PID file.")
    os.remove(pid_file)
end

if cfg["start"] or not ext.empty(cfg["import"]) or not ext.empty(cfg["export"]) then
    local pid = read_pid_file()
    if pid ~= -1 and sys.pid_running(pid) then
        log.debug("Already running with PID: ", pid, ". Exiting.")
        mp.commandv("quit", 65)
    else
        write_pid_file()
        mp.register_event("shutdown", delete_pid_file)
        run()
    end
end
