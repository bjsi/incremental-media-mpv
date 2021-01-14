local config = {

    -- Common
    audio_format = "opus",         -- opus or mp3
    audio_bitrate = "18k",         -- from 16k to 32k
    audio_padding = 0.12,          -- Set a pad to the dialog timings. 0.5 = audio is padded by .5 seconds. 0 = disable.
    tie_volumes = false,           -- if set to true, the volume of the outputted audio file depends on the volume of the player at the time of export
}

local utils = require('mp.utils')
local msg = require('mp.msg')
local mpopt = require('mp.options')

mpopt.read_options(config, "audioassistant")

local basedir = "/home/james/Projects/Lua/audio-assistant-mpv/"
local datadir = "/home/james/Projects/Lua/audio-assistant-mpv/data"
local audiodir = "/home/james/Projects/Lua/audio-assistant-mpv/audio"

-- namespaces
local subs
local encoder
local topics
local extracts
local items
local gtq
local leq
local liq
local current

-- classes
local Subtitle


------------------------------------------------------------
-- utility functions

---Returns true if table contains element. Returns false otherwise.
---@param table table
---@param element any
---@return boolean
function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

---Returns the largest numeric index.
---@param table table
---@return number
function table.max_num(table)
    local max = table[1]
    for _, value in ipairs(table) do
        if value > max then
            max = value
        end
    end
    return max
end

---Returns a value for the given key. If key is not available then returns default value 'nil'.
---@param table table
---@param key string
---@param default any
---@return any
function table.get(table, key, default)
    if table[key] == nil then
        return default or 'nil'
    else
        return table[key]
    end
end

---Filters a table array
---@param table table
---@param predicate function
---@return table
function table.filter(table, predicate)
    local filtered = {}
    for _, v in ipairs(table) do
        if predicate(v) then
            filtered[#filtered+1] = v end
    end
    return filtered
end

local function is_empty(var)
    return var == nil or var == '' or (type(var) == 'table' and next(var) == nil)
end

local function is_running_windows()
    return mp.get_property('options/vo-mmcss-profile') ~= nil
end

local function is_running_macOS()
    return mp.get_property('options/cocoa-force-dedicated-gpu') ~= nil
end

local function contains_non_latin_letters(str)
    return str:match("[^%c%p%s%w]")
end

local function capitalize_first_letter(string)
    return string:gsub("^%l", string.upper)
end

local function notify(message, level, duration)
    level = level or 'info'
    duration = duration or 1
    msg[level](message)
    mp.osd_message(message, duration)
end

local escape_special_characters
do
    local entities = {
        ['&'] = '&amp;',
        ['"'] = '&quot;',
        ["'"] = '&apos;',
        ['<'] = '&lt;',
        ['>'] = '&gt;',
    }
    escape_special_characters = function(s)
        return s:gsub('[&"\'<>]', entities)
    end
end

local function remove_extension(filename)
    return filename:gsub('%.%w+$', '')
end

local function remove_special_characters(str)
    return str:gsub('[%c%p%s]', ''):gsub('　', '')
end

local function remove_text_in_brackets(str)
    return str:gsub('%b[]', ''):gsub('【.-】', '')
end

local function remove_text_in_parentheses(str)
    -- Remove text like （泣き声） or （ドアの開く音）
    -- Note: the modifier `-´ matches zero or more occurrences.
    -- However, instead of matching the longest sequence, it matches the shortest one.
    return str:gsub('%b()', ''):gsub('（.-）', '')
end

local function remove_newlines(str)
    return str:gsub('[\n\r]+', ' ')
end

local function remove_leading_trailing_spaces(str)
    return str:gsub('^%s*(.-)%s*$', '%1')
end

local function remove_all_spaces(str)
    return str:gsub('%s*', '')
end

local function remove_spaces(str)
    if config.nuke_spaces == true and contains_non_latin_letters(str) then
        return remove_all_spaces(str)
    else
        return remove_leading_trailing_spaces(str)
    end
end

local function trim(str)
    str = remove_spaces(str)
    str = remove_text_in_parentheses(str)
    str = remove_newlines(str)
    return str
end

local function human_readable_time(seconds)
    if type(seconds) ~= 'number' or seconds < 0 then
        return 'empty'
    end

    local parts = {
        h = math.floor(seconds / 3600),
        m = math.floor(seconds / 60) % 60,
        s = math.floor(seconds % 60),
        ms = math.floor((seconds * 1000) % 1000),
    }

    local ret = string.format("%02dm%02ds%03dms", parts.m, parts.s, parts.ms)

    if parts.h > 0 then
        ret = string.format('%dh%s', parts.h, ret)
    end

    return ret
end

local function subprocess(args, completion_fn)
    -- if `completion_fn` is passed, the command is ran asynchronously,
    -- and upon completion, `completion_fn` is called to process the results.
    local command_native = type(completion_fn) == 'function' and mp.command_native_async or mp.command_native
    local command_table = {
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = args
    }
    return command_native(command_table, completion_fn)
end

local function minutes_ago(m)
    return (os.time() - 60 * m) * 1000
end

local validate_config
do
    local function is_opus_supported()
        local ret = subprocess { 'mpv', '--oac=help' }
        return ret.status == 0 and ret.stdout:match('--oac=libopus')
    end

    local function set_audio_format()
        if config.audio_format == 'opus' and is_opus_supported() then
            config.audio_codec = 'libopus'
            config.audio_extension = '.ogg'
        else
            config.audio_codec = 'libmp3lame'
            config.audio_extension = '.mp3'
        end
    end

    validate_config = function()
        set_audio_format()
    end
end


------------------------------------------------------------
-- Database

db = {}

db.read_csv = function(fpath, table_func)
    local ret = {}
    for line in io.lines(fpath) do
        ret[#ret + 1] = table_func(line)
    end
    return ret
end

db.create_element = function(line)
    local fname, stime, etime, curtime, priority = line:match("%s*(.-),%s*(.-),%s*(.-),%s*(.-),%s*(.-)")
    return {
        fname = fname,
        stime = stime,
        etime = etime,
        curtime = curtime,
        priority = priority
    }
end

db.sort_priority = function(fst, snd)
    return fst.priority >= snd
end

db.get_topics = function()
    local data = db.read_csv(utils.join_path(datadir, "topics.csv"), db.create_element)
    table.sort(data, db.sort_priority)
    return data
end

db.get_extracts = function()
    local data = db.read_csv(utils.join_path(datadir, "extracts.csv"), db.create_element)
    table.sort(data, db.sort_priority)
end

------------------------------------------------------------
-- Global Topic Queue

gtq = {
    queue = db.get_topics(),
    cur_idx = 1
}

gtq.bindings = {
    child = function() leq.init(gtq.queue[gtq.cur_idx]["fname"]) end,
    -- seek_right = function() sub_seek("forward", true) end,
}

gtq.init = function()
    local topic = gtq.queue[gtq.cur_idx]
    if topic ~= nil then
        mp.commandv("loadfile", topic["fname"], "replace")
    else
        print("GTQ: No files!")
    end
end

gtq.extract = function()
    local topic = gtq.queue[gtq.cur_idx]
    local fname = topic["fname"]
    local a = mp.get_property("ab-loop-a")
    local b = mp.get_property("ab-loop-b")
    local stime = a < b and a or b
    local etime = a > b and a or b
    local priority = topic["priority"]
    local row = table.concat(
    {
        fname,
        stime,
        etime,
        stime,
        priority
    }, ",")
    local f = io.open(utils.join_path(datadir, "extracts.csv"), "a")
    f:write(row .. "\n")
    f:close()
end

------------------------------------------------------------
-- Global Extract Queue
geq = {
    queue = nil
}

geq.bindings = {
    child = function() liq.init() end,
}

geq.can_init()

geq.init = function()
    geq.queue = db.get_extracts()
    if geq.queue == nil then return end
    
end

------------------------------------------------------------
-- Local Extract Queue

leq = {
    queue = nil,
    cur_idx = 1
}

leq.bindings = {
    child = function() liq.init() end,
    parent = function() gtq.init() end,
}

leq.can_init = function(fname)
    local data = db.get_extracts()
    leq.queue = table.filter(data, function(v) return v["fname"] == fname end)
    return leq.queue == nil
end

leq.init = function(fname)
    if not leq.can_init(fname) then return end
    print("LOCAL EXTRACT QUEUE")
    mp.commandv("loadfile", leq.queue[leq.cur_idx]["fname"], "replace")
    current.queue = leq
end

------------------------------------------------------------
-- Local Item Queue

liq = {}
liq.bindings = {
    parent = function() leq.init() end,
    -- seek_right = function() frame_seek("forward", true) end,
}

liq.init = function() end
------------------------------------------------------------
-- Current Queue

current = {
    queue = gtq
}

current.init = function() current.queue.init() end

current.next_file = function()
    local next_file = current.queue[current.queue.cur_idx]
    if next_file == nil then
        print("No next file")
    else
        mp.commandv("loadfile", next_file.fname, "replace")
        if next_file.stime > 0 then
            mp.commandv('seek', next_file.stime, 'absolute')
        end
    end
end

current.handle_input = function(msg)
    local func = current.queue.bindings[msg]
    if func ~= nil then func() end
end

------------------------------------------------------------
-- main

local main
do
    local main_executed = false
    main = function()
        if main_executed then return end
        validate_config()

        -- Key bindings
        mp.add_key_binding("UP", "aa-parent", function () current.handle_input("parent") end )
        mp.add_key_binding("DOWN", "aa-child", function() current.handle_input("child") end )

        current.init()

        -- Topics
        -- mp.add_key_binding("H", "mpvacious-sub-seek-back", _ { sub_seek, 'backward' })
        -- mp.add_key_binding("L", "mpvacious-sub-seek-forward", _ { sub_seek, 'forward' })

        -- Extracts
        
        -- Items
        -- -- Vim-like seeking between subtitle lines

        -- mp.add_key_binding("Alt+h", "mpvacious-sub-seek-back-pause", _ { sub_seek, 'backward', true })
        -- mp.add_key_binding("Alt+l", "mpvacious-sub-seek-forward-pause", _ { sub_seek, 'forward', true })

        -- mp.add_key_binding("ctrl+h", "mpvacious-sub-rewind", _ { sub_rewind })
        -- mp.add_key_binding("ctrl+H", "mpvacious-sub-replay", _ { sub_replay })

        -- -- Unset by default
        -- mp.add_key_binding(nil, "mpvacious-set-starting-line", subs.set_starting_line)
        -- mp.add_key_binding(nil, "mpvacious-reset-timings", subs.clear_and_notify)
        -- mp.add_key_binding(nil, "mpvacious-toggle-sub-autocopy", clip_autocopy.toggle)

        main_executed = true
    end
end
mp.register_event("file-loaded", main)
