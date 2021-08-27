local log = require 'utils.log'
local dir = require 'utils.directory'
local fs = require 'systems.fs'
local importer = require 'systems.importer'
local exporter = require 'systems.exporter'
local active_queue = require 'systems.active'
local sys = require 'systems.system'
local GlobalTopics = require 'queues.global.topics'
local GlobalExtracts = require 'queues.global.extracts'
local GlobalItems = require 'queues.global.items'
local SingletonExtract = require 'queues.singletons.extract'
local player = require 'systems.player'
local sounds = require 'systems.sounds'
local menuBase = require 'systems.menu.menuBase' -- TODO
local mp = require 'mp'
local singleton_utils = require 'queues.singletons.utils'
local obj = require 'utils.object'
local file = require 'utils.file'
local InputPipeline = require 'systems.ui.input.pipeline'
local create_input_handler = require 'systems.ui.input.create_input_handler'
local opts = require 'systems.options'
local mode = require 'systems.mode'

local loaded = false

local function run_export_sm_mode()
    local path = opts.path
    local ret = exporter.as_sm_xml(path)
    local sound
    local exit_code
    if ret then
        log.debug("Successfully exported to: " .. path)
        sound = "positive"
        exit_code = 0
    else
        log.debug("Failed to export.")
        sound = "negative"
        exit_code = 1
    end
    sounds.play_sync(sound)
    mp.commandv("quit", exit_code)
end

local function setup_player()
    require 'systems.keybinds' -- register script messages
    require 'systems.api' -- register api script messages
    sys.setup_ipc() -- TODO: require systems.ipc
    -- keep the window open unless audio only is set.
    if not mp.get_property_bool("audio-only") then
        mp.set_property("force-window", "yes")
    end

    -- set infinite loop
    mp.set_property("loop", "inf")
    mp.observe_property("time-pos", "number", player.loop_timer.check_loop)
end

local function run_minion_mode()
    setup_player()
    local queue = singleton_utils.get_singleton(opts.type, opts.id)
    if not queue or obj.empty(queue.reptable.subset) then
        log.debug("Failed to load singleton queue.")
        mp.commandv("quit", 1)
    end
    if not active_queue.change_queue(queue) then mp.commandv("quit", 1) end
end

local function run_master_mode()
    setup_player()
    -- get a topic, extract or item queue depending on which has
    -- outstanding reps.
    local function get_startup_queue()
        local gt = GlobalTopics(nil)
        if gt and not obj.empty(gt.reptable.subset) then return gt end
        local ge = GlobalExtracts(nil)
        if ge and not obj.empty(ge.reptable.subset) then return ge end
        local gi = GlobalItems(nil)
        if gi and not obj.empty(gi.reptable.subset) then return gi end
    end
    local queue = get_startup_queue()
    if not queue or obj.empty(queue.reptable.subset) then
        log.debug("No repetitions available. Creating empty topic queue...")
        queue = GlobalTopics(nil)
    end
    if not active_queue.change_queue(queue) then menuBase.open() end
end

local function run_import_extract_mode()
    local path = opts.path
    if not file.exists(path) then
        log.debug("Failed to add extract: file does not exist.")
        mp.commandv("quit", 1)
    end

    local import_and_load = function(state)
        local extract = importer.import_extract(state)
        local sound = "positive"
        local queue
        if extract then
            log.notify("Imported!")
            queue = SingletonExtract(extract.row.id)
        else
            log.notify("Failed to import.")
        end
        sounds.play(sound)
        if not active_queue.change_queue(queue) then
            mp.commandv("quit", 1)
        end
    end

    mp.set_property("force-window", "yes")
    local pipeline =
        InputPipeline.new(create_input_handler("title", "string")):then_(
            create_input_handler("priority", "number")):finally(import_and_load)
    pipeline:run({path = path})
end

local function run_import_topic_mode()
    local path = opts.path
    local ret = importer.import(path)
    local sound
    local exit_code
    if ret then
        log.debug("Successfully imported: " .. path)
        sound = "positive"
        exit_code = 0
    else
        log.debug("Failed to import: " .. path)
        sound = "negative"
        exit_code = 1
    end
    sounds.play_sync(sound)
    mp.commandv("quit", exit_code)
end

local function create_essential_files() -- TODO
    local folders = {fs.data, fs.media, fs.bkp}
    for _, folder in pairs(folders) do
        if not file.exists(folder) then
            if not dir.create(folder) then
                log.debug("Could not create essential folder: " .. folder ..
                              ". Exiting...")
                mp.commmandv("quit")
                return false
            end
        end
    end

    if not file.exists(fs.sine) then sys.copy(fs.sine_base, fs.sine) end

    if not file.exists(fs.meaning_zh) then
        sys.copy(fs.meaning_zh_base, fs.meaning_zh)
    end

    if not file.exists(fs.silence) then sys.copy(fs.silence_base, fs.silence) end
end

local function run()
    if loaded then return end

    loaded = true

    -- Only allows one instance of the script to
    -- run for each queue.
    if sys.already_running() then
        log.debug(opts.queue .. " inc media queue already running. Exiting.")
        mp.commandv("quit", 65)
        return
    end

    sys.write_pid_file()
    sys.verify_dependencies()
    create_essential_files()
    sys.backup() -- TODO
    sounds.start_background_process()
    mp.register_event("shutdown", active_queue.on_shutdown)

    if opts.mode == mode.master then
        run_master_mode()
    elseif opts.mode == mode.minion then
        run_minion_mode()
    elseif opts.mode == mode.import_topic then
        run_import_topic_mode()
    elseif opts.mode == mode.import_extract then
        run_import_extract_mode()
    elseif opts.mode == mode.export_sm then
        run_export_sm_mode()
    else
        log.debug("Unrecognised mode: " .. opts.mode)
        mp.commandv("quit", 1)
    end
end

if opts.mode ~= "" then
  run()
end
