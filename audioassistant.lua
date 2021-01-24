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

local basedir = mp.get_script_directory()
msg.info(basedir)
local mediadir = utils.join_path(basedir, "media")
local datadir = utils.join_path(basedir, "data")
local extractsdb = utils.join_path(datadir, "extracts.csv")
local itemsdb = utils.join_path(datadir, "items.csv")
local topicsdb = utils.join_path(datadir, "topics.csv")
local topicsheader = utils.join_path(datadir, "topics_header.csv")
local extractsheader = utils.join_path(datadir, "extracts_header.csv")
local itemsheader = utils.join_path(datadir, "items_header.csv")
local soundsdir = utils.join_path(basedir, "sounds")

-- namespaces
local subs
local encoder
local active_queue

-- classes
local Subtitle
local ExtractQueue
local GlobalTopicQueue
local Queue
local LocalExtractQueue
local GlobalExtractQueue
local ItemQueue
local GlobalItemQueue
local LocalItemQueue


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
-- utility classes

local function new_timings()
    local self = { ['start'] = -1, ['end'] = -1, }
    local is_set = function(position)
        return self[position] >= 0
    end
    local set = function(position)
        self[position] = mp.get_property_number('time-pos')
    end
    local get = function(position)
        return self[position]
    end
    return {
        is_set = is_set,
        set = set,
        get = get,
    }
end

local function new_sub_list()
    local subs_list = {}
    local _is_empty = function()
        return next(subs_list) == nil
    end
    local find_i = function(sub)
        for i, v in ipairs(subs_list) do
            if sub < v then
                return i
            end
        end
        return #subs_list + 1
    end
    local get_time = function(position)
        local i = position == 'start' and 1 or #subs_list
        return subs_list[i][position]
    end
    local get_text = function()
        local speech = {}
        for _, sub in ipairs(subs_list) do
            table.insert(speech, sub['text'])
        end
        return table.concat(speech, ' ')
    end
    local insert = function(sub)
        if sub ~= nil and not table.contains(subs_list, sub) then
            table.insert(subs_list, find_i(sub), sub)
            return true
        end
        return false
    end
    return {
        get_time = get_time,
        get_text = get_text,
        is_empty = _is_empty,
        insert = insert
    }
end

local function make_switch(states)
    local self = {
        states = states,
        current_state = 1
    }
    local bump = function()
        self.current_state = self.current_state + 1
        if self.current_state > #self.states then
            self.current_state = 1
        end
    end
    local get = function()
        return self.states[self.current_state]
    end
    return {
        bump = bump,
        get = get
    }
end

------------------------------------------------------------
-- subtitles and timings

subs = {
    dialogs = new_sub_list(),
    user_timings = new_timings(),
    observed = false
}

subs.get_current = function()
    local sub_text = mp.get_property("sub-text")
    if not is_empty(sub_text) then
        local sub_delay = mp.get_property_native("sub-delay")
        return Subtitle:new {
            ['text'] = sub_text,
            ['start'] = mp.get_property_number("sub-start") + sub_delay,
            ['end'] = mp.get_property_number("sub-end") + sub_delay
        }
    end
    return nil
end

subs.get_timing = function(position)
    if subs.user_timings.is_set(position) then
        return subs.user_timings.get(position)
    elseif not subs.dialogs.is_empty() then
        return subs.dialogs.get_time(position)
    end
    return -1
end

subs.get = function()
    if subs.dialogs.is_empty() then
        subs.dialogs.insert(subs.get_current())
    end
    local sub = Subtitle:new {
        ['text'] = subs.dialogs.get_text(),
        ['start'] = subs.get_timing('start'),
        ['end'] = subs.get_timing('end'),
    }
    if sub['start'] < 0 or sub['end'] < 0 then
        return nil
    end
    if sub['start'] == sub['end'] then
        return nil
    end
    if sub['start'] > sub['end'] then
        sub['start'], sub['end'] = sub['end'], sub['start']
    end
    if not is_empty(sub['text']) then
        sub['text'] = trim(sub['text'])
        sub['text'] = escape_special_characters(sub['text'])
    end
    return sub
end

subs.append = function()
    if subs.dialogs.insert(subs.get_current()) then
        menu.update()
    end
end

subs.observe = function()
    mp.observe_property("sub-text", "string", subs.append)
    subs.observed = true
end

subs.unobserve = function()
    mp.unobserve_property(subs.append)
    subs.observed = false
end

subs.set_timing = function(position)
    subs.user_timings.set(position)
    menu.update()
    notify(capitalize_first_letter(position) .. " time has been set.")
    if not subs.observed then
        subs.observe()
    end
end

subs.set_starting_line = function()
    subs.clear()
    if not is_empty(mp.get_property("sub-text")) then
        subs.observe()
        notify("Timings have been set to the current sub.", "info", 2)
    else
        notify("There's no visible subtitle.", "info", 2)
    end
end

subs.clear = function()
    subs.unobserve()
    subs.dialogs = new_sub_list()
    subs.user_timings = new_timings()
    menu.update()
end

subs.clear_and_notify = function()
    subs.clear()
    notify("Timings have been reset.", "info", 2)
end

---------------
-- Random utils

local function dump(o)
    if type(o) == "table" then
        local s = '{'
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. ']' .. dump (v) .. ','
        end
        return s .. '}'
    else
        return tostring(o)
    end
end

------------------------------------------------------------
-- seeking: sub replay, sub seek, sub rewind

local function _(params)
    local unpack = unpack and unpack or table.unpack
    return function() return pcall(unpack(params)) end
end

local pause_timer = (function()
    local stop_time = -1
    local check_stop
    local set_stop_time = function(time)
        stop_time = time
    end
    local stop = function()
        mp.unobserve_property(check_stop)
        stop_time = -1
    end
    check_stop = function(_, time)
        if time >= stop_time then
            stop()
            mp.set_property("pause", "yes")
        else
            -- notify('Timer: ' .. human_readable_time(stop_time - time))
        end
    end
    return {
        set_stop_time = set_stop_time,
        check_stop = check_stop,
        stop = stop,
    }
end)()

local function sub_replay()
    local sub = subs.get_current()
    pause_timer.set_stop_time(sub['end'] - 0.050)
    mp.commandv('seek', sub['start'], 'absolute')
    mp.set_property("pause", "no")
    mp.observe_property("time-pos", "number", pause_timer.check_stop)
end

local function sub_seek(direction, pause)
    mp.commandv("sub_seek", direction == 'backward' and '-1' or '1')
    mp.commandv("seek", "0.015", "relative+exact")
    if pause then
        mp.set_property("pause", "yes")
    end
    pause_timer.stop()
end

local function sub_rewind()
    mp.commandv('seek', subs.get_current()['start'] + 0.015, 'absolute')
    pause_timer.stop()
end

------------------------------------------------------------
-- platform specific

local function init_platform_windows()
    local self = {}
    local curl_tmpfile_path = utils.join_path(os.getenv('TEMP'), 'curl_tmp.txt')
    mp.register_event('shutdown', function() os.remove(curl_tmpfile_path) end)

    self.tmp_dir = function()
        return os.getenv('TEMP')
    end

    self.copy_to_clipboard = function(text)
        mp.commandv("run", "cmd.exe", "/d", "/c", string.format("@echo off & chcp 65001 & echo %s|clip", text))
    end

    self.curl_telnet = function(request_json, completion_fn)
        local handle = io.open(curl_tmpfile_path, "w")
        handle:write(request_json)
        handle:close()
        local args = {
            './curl_telnet_win.bat',
            config["amp_host"],
            config["amp_port"],
            curl_tmpfile_path
        }
        return subprocess(args, completion_fn)
    end

    self.file2base64 = function(filepath, completion_fn)
        local args = {
            "./file2base64_win.bat",
            filepath
        }
        return subprocess(args, completion_fn)
    end

    -- TODO: Check
    self.check_dependency = function(program)
        local args = {
            "which",
            "/q",
            program
        }
        local ret = subprocess(args)
        return ret.status == 0
    end


    self.curl_request = function(request_json, completion_fn)
        local handle = io.open(curl_tmpfile_path, "w")
        handle:write(request_json)
        handle:close()
        local args = {
            'curl',
            '-s',
            'localhost:8765',
            '-H',
            'Content-Type: application/json; charset=UTF-8',
            '-X',
            'POST',
            '--data-binary',
            table.concat { '@', curl_tmpfile_path }
        }
        return subprocess(args, completion_fn)
    end

    self.windows = true

    return self
end

local function init_platform_nix()
    local self = {}
    local clip = is_running_macOS() and 'LANG=en_US.UTF-8 pbcopy' or 'xclip -i -selection clipboard'

    self.tmp_dir = function()
        return '/tmp'
    end

    self.copy_to_clipboard = function(text)
        local handle = io.popen(clip, 'w')
        handle:write(text)
        handle:close()
    end

    local curl_tmpfile_path = utils.join_path('/tmp', 'curl_tmp.txt')
    mp.register_event('shutdown', function() os.remove(curl_tmpfile_path) end)

    self.curl_telnet = function(request_json, completion_fn)
        local handle = io.open(curl_tmpfile_path, "w")
        handle:write(request_json .. "\n")
        handle:close()
        local args = {
            "./curl_telnet_nix",
            config['amp_host'],
            config['amp_port'],
            curl_tmpfile_path
        }
        return subprocess(args, completion_fn)
    end

    self.file2base64 = function(filepath)
        local args = {
            "./file2base64_nix",
            filepath
        }
        return subprocess(args)
    end

    self.check_dependency = function(program)
        local args = {
            "which",
            program
        }
        local ret = subprocess(args)
        return ret.status == 0
    end

    self.curl_request = function(request_json, completion_fn)
        local args = { 'curl', '-s', 'localhost:8765', '-X', 'POST', '-d', request_json }
        return subprocess(args, completion_fn)
    end

    return self
end

platform = is_running_windows() and init_platform_windows() or init_platform_nix()

----------------
-- Sound Effects

local sounds = {
    files = {
        negative = "negative.wav",
        click1 = "click.wav",
        click2 = "click_2.wav",
        load = "load.wav",
        positive = "positive.wav",
        echo = "sharp_echo.wav",
        global_topic_queue = "global_topic_queue.wav",
        global_extract_queue = "global_extract_queue.wav",
        local_extract_queue = "local_extract_queue.wav",
        global_item_queue = "global_item_queue.wav",
        local_item_queue = "local_item_queue.wav",
    }
}

sounds.play = function(sound)
    local fp = utils.join_path(soundsdir, sounds.files[sound])
    local args = {
        "mpv",
        "--no-video",
        "--really-quiet",
        fp
    }
    subprocess(args, function() end)
end

local loop_timer = (function()
    local start_time = 0
    local stop_time = -1
    local check_loop

    local set_stop_time = function(time)
        stop_time = time
    end
    local set_start_time = function(time)
        start_time = time
    end

    local stop = function()
        mp.unobserve_property(check_loop)
        start_time = 0
        stop_time = -1
    end

    check_loop = function(_, time)
        if time == nil then return end
        local overrun = stop_time > 0 and time >= stop_time
        local underrun = start_time > 0 and time < start_time
        if overrun or underrun then
            mp.commandv("seek", start_time, "absolute")
        end
    end

    local on_el_changed = function(_, start_t, stop_t)
        msg.info("Received element changed event")
        if start_t == nil then return end
        if stop_t == nil then return end
        set_start_time(tonumber(start_t))
        set_stop_time(tonumber(stop_t))
    end

    mp.register_script_message("element_changed", on_el_changed)

    return {
        set_start_time = set_start_time,
        set_stop_time = set_stop_time,
        check_loop = check_loop,
        stop = stop,
    }
end)()

------------
-- Element Queue Filters


-- sorts in place
local function sort_by_priority(tb)
    local priority = function(a, b)
        local ap = tonumber(a["priority"])
        local bp = tonumber(b["priority"])
        return ap > bp
    end
    table.sort(tb, priority)
end

local function is_done(r)
    local curtime = r["curtime"]
    local stop = r["stop"]
    if curtime == nil or stop == "nil" then return false end
    return (tonumber(curtime) / tonumber(stop)) >= 0.95
end

local function is_outstanding(r)
    return not is_done(r)
end

local function is_child(a, b)
    return a["parent"] == b["id"]
end

local function is_parent(a, b)
    return a["id"] == b["parent"]
end

local function curry2(f)
  return function(a)
    return function(b)
      return f(a, b)
    end
  end
end

-------------
-- Databases


CSV = {}
CSV.__index = CSV


function CSV.new()
    local self = setmetatable({}, CSV)
    self.csv_table = {}
    self.header = {}
    self.loaded_file = nil
    return self
end

-- Load CSV file.
function CSV:load(fp)
    local fobj = io.open(fp, "r")
    if fobj == nil then
        print("Failed to open csv file for reading: " .. fp)
        return false
    end

    self.loaded_file = fp

    -- header
    local data = fobj:read()
    for v in string.gmatch(data, "[^,]*") do
        if v ~= "" then
            self.header[#self.header+1] = v
        end
    end

    -- rows
    for line in fobj:lines() do
        local row = {}
        local ct = 1
        for v in string.gmatch(line, "[^,]*") do
            if v ~= "" then
                row[self.header[ct]] = v
                ct = ct + 1
            end
        end

        self.csv_table[#self.csv_table+1] = row
    end
    fobj:close()
    msg.info("Successfully read csv file: " .. fp)
    return true
end

-- Write CSV file.
function CSV:write(fp)
    if fp == nil then fp = self.loaded_file end
    if next(self.csv_table) == nil then
        print("Did not write to " .. fp .. " because the table was empty.")
        return false
    end

    local fobj = io.open(fp, "w")
    if fobj == nil then
        print("Failed to write to csv file: " .. fp)
        return false
    end

    -- header
    for i, v in ipairs(self.header) do
        if i ~= #self.header then
            fobj:write(v .. ',')
        else
            fobj:write(v .. '\n')
        end
    end

    -- rows
    for _, row in ipairs(self.csv_table) do
        for i, h in ipairs(self.header) do
            if i ~= #self.header then
                fobj:write(row[h]..',')
            else
                fobj:write(row[h]..'\n')
            end
        end
    end
    fobj:close()
    msg.info("Successfully wrote to csv file: " .. fp)
    return true
end

-- Print out the csv
function CSV:show()
    if next(self.csv_table) == nil then
        msg.info("Failed to show csv because the table is empty.")
        return
    end
    for _, v in ipairs(self.csv_table) do
        msg.info(dump(v))
    end
end

function CSV:get_all()
    if next(self.csv_table) == nil then
        return nil
    end
    local ret = {}
    for _, v in ipairs(self.csv_table) do
        ret[#ret + 1] = v
    end
    return ret
end

function CSV:get_outstanding()
    if next(self.csv_table) == nil then
        return nil
    end
    local ret = {}
    for _, v in ipairs(self.csv_table) do
        if not is_done(v) then
            ret[#ret + 1] = v
        end
    end
    sort_by_priority(ret)
    return ret
end

-- Get all rows matching some predicate
function CSV:where(predicate)
    if next(self.csv_table) == nil then
        return nil
    end
    local ret = {}
    for i, v in ipairs(self.csv_table) do
        if predicate(v) then
            ret[#ret+1] = v
        end
    end
    return ret
end

function CSV:get_by_id(id)
    if next(self.csv_table) == nil then
        return nil
    end
    for _, v in ipairs(self.csv_table) do
        if v["id"] == id then
            return v
        end
    end
end

function CSV:set_by_id(id, row)
    if next(self.csv_table) == nil then
        msg.info("Failed to set by id because the table is empty.")
        return
    end
    for i, v in ipairs(self.csv_table) do
        if v["id"] == id then
            self.csv_table[i] = row
            return
        end
    end
end


function CSV:add(row)
    self.csv_table[#self.csv_table+1] = row
    msg.info("Added row to table: " .. dump(row))
end

db = {
    topics = CSV.new(),
    extracts = CSV.new(),
    items = CSV.new()
}

db.init = function()
    db.topics:load(topicsdb)
    db.extracts:load(extractsdb)
    db.items:load(itemsdb)
end

db.on_shutdown = function()
    db.topics:write()
    db.extracts:write()
    db.items:write()
end

local function file_exists(name)
	local f=io.open(name,"r")
	if f~=nil then io.close(f) return true else return false end
end

local function create_db(db_fp, header_fp)
    if not file_exists(db_fp) then
        local header = io.open(header_fp, "r")
        local content = header:read("*all")
        local db = io.open(db_fp, "w")
        db:write(content)
        header:close()
        db:close()
    end
end

local function create_essential_files()
    create_db(topicsdb, topicsheader)
    create_db(extractsdb, extractsheader)
    create_db(itemsdb, itemsheader)
end

local function unset_abloop()
    mp.set_property("ab-loop-a", "no")
    mp.set_property("ab-loop-b", "no")
end

local function move_to_first_where(predicate, elements)
    local idx = nil
    for i, v in ipairs(elements) do
        if predicate(v) then
            idx = i
            break
        end
    end
    if idx ~= nil then
        local target = table.remove(elements, idx)
        table.insert(elements, 1, target)
    end
end

---------------
-- EDL Files

EDL = {}
EDL.__index = EDL


function EDL.new(fp)
    local self = setmetatable({}, EDL)
    self.fp = fp
    self.header = "# mpv EDL v0\n"
    self.data = {}
    return self
end

function EDL:write()
    local handle = io.open(self.fp, "w")
    if handle == nil then
        print("Failed to open EDL file for writing: " .. fp)
        return false
    end

    handle:write(self.header)
    handle:write(self.data["beg"]["fp"] .. "," .. self.data["beg"]["start"] .. "," .. self.data["beg"]["stop"] .. "\n")
    handle:write(self.data["cloze"]["fp"] .. "," .. self.data["cloze"]["start"] .. "," .. self.data["cloze"]["stop"] .. "\n")
    handle:write(self.data["ending"]["fp"] .. "," .. self.data["ending"]["start"] .. "," .. self.data["ending"]["stop"] .. "\n")
    handle:close()

    msg.info("Successfully wrote to EDL file")
    return true
end

-- Load EDL file.
function EDL:load()
    local handle = io.open(self.fp, "r")
    if handle == nil then
        print("Failed to open EDL file for reading: " .. fp)
        return false
    end

    local content = handle:read("*all")
    local match = content:gmatch("([^\n]*)\n?")
    match()
    local beg = self:parse_line(match())
    local cloze = self:parse_line(match())
    local ending = self:parse_line(match())
    handle:close()

    self.data =  {
        beg = beg,
        cloze = cloze,
        ending = ending,
    }

    msg.info("Successfully parsed EDL file")
    return true
end

-- parses a single line in an EDL file
function EDL:parse_line(line)
    local ret = {}
    local ct = 1
    for v in string.gmatch(line, "[^,]*") do
        if v ~= "" then
            if ct == 1 then ret["fp"] = v end
            if ct == 2 then ret["start"] = v end
            if ct == 3 then ret ["stop"] = v end
            ct = ct + 1
        end
    end
    return ret
end

-------------
-- Base Queue
-- http://lua-users.org/wiki/ObjectOrientationTutorial

Queue = {cur_idx = 1}
Queue.__index = Queue

setmetatable(Queue, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end,
})

function Queue:advance_start()
    -- noop
end

function Queue:advance_stop()
    -- noop
end

function Queue:postpone_start()
    -- noop
end

function Queue:postpone_stop()
    -- noop
end

function Queue:_init(items, name)
    self.items = items
    self.name = name
    msg.info("Loading new ".. name)
end

function Queue:change_queue(db, db_predicate, creator_fn)
    local elements = db:where(db_predicate)
    if elements == nil or #elements == 0 then
        sounds.play("negative")
        msg.info("No elements to create queue.")
        return false
    end
    sort_by_priority(elements)
    active_queue = creator_fn(elements)
    return true
end

function Queue:extract()
    local a = mp.get_property("ab-loop-a")
    local b = mp.get_property("ab-loop-b")
    if a == "no" or b == "no" then return end
    a = tonumber(a)
    b = tonumber(b)
    local start = a < b and a or b
    local stop = a > b and a or b
    local cur = self:get_current()
    self:handle_extract(start, stop, cur)
end

-- TODO: Does this work consistently across platforms
function Queue:stutter_forward()

    local vid = mp.get_property("vid")

    -- if video is playing then frame seek, else, stutter
    if vid == "no" then
        pause_timer.stop()
        mp.set_property("pause", "yes")
        mp.commandv("seek", "-0.055")
        local cur = mp.get_property("time-pos")
        pause_timer.set_stop_time(tonumber(cur) + 0.04)
        mp.observe_property("time-pos", "number", pause_timer.check_stop)
        mp.set_property("pause", "no")
    else
        mp.commandv("frame-step")
    end
end

-- TODO: Does this work consistently across platforms
function Queue:stutter_backward()
    if vid == "no" then
        pause_timer.stop()
        mp.set_property("pause", "yes")
        local cur = mp.get_property("time-pos")
        mp.commandv("seek", "-0.2")
        pause_timer.set_stop_time(tonumber(cur) - 0.08)
        mp.observe_property("time-pos", "number", pause_timer.check_stop)
        mp.set_property("pause", "no")
    else
        mp.commandv("frame-back-step")
    end
end

function Queue:prev()
    if self.cur_idx - 1 < 1 then
        sounds.play("negative")
        msg.info("No previous element in the current queue.")
        return false
    end
    local old = self.items[self.cur_idx]
    self.cur_idx = self.cur_idx - 1
    local new = self.items[self.cur_idx]
    self:load(old, new)
    sounds.play("click1")
end

function Queue:next()
    if self.cur_idx + 1 > #self.items then
        sounds.play("negative")
        msg.info("No next element in the current queue.")
        return false
    end
    local old = self.items[self.cur_idx]
    self.cur_idx = self.cur_idx + 1
    local new = self.items[self.cur_idx]
    self:load(old, new)
    sounds.play("click1")
end

-- old can be nil
function Queue:load(old, new)

    -- set start, stop
    local start = new["curtime"] ~= nil and new["curtime"] or new["start"]
    if start == nil then start = 0 end
    local stop = new["stop"] ~= nil and new["stop"] or -1
    start = tonumber(start)
    stop = tonumber(stop)

    -- seek if old and new have the same url
    if old ~= nil and old["url"] == new["url"] then
        msg.info("New element has the same url: seeking")
        mp.commandv("seek", tostring(start), "absolute")

    -- load file if old and new have different urls
    else
        msg.info("New element has a different url: loading new file")
        mp.commandv("loadfile", new["url"], "replace", "start=" .. tostring(start))
    end

    if new["speed"] ~= nil then
        mp.set_property("speed", new["speed"])
    else
        mp.set_property("speed", "1")
    end

    -- reset loops and timers
    unset_abloop()
    pause_timer.stop()

    mp.commandv("script-message", "element_changed", self.name, tostring(start), tostring(stop))
end

function Queue:forward()
    mp.commandv("seek", "+5")
end

function Queue:backward()
    mp.commandv("seek", "-5")
end

function Queue:child()
    sounds.play("negative")
    msg.info("No child element available.")
end

function Queue:get_current()
    return self.items[self.cur_idx]
end

function Queue:parent()
    sounds.play("negative")
    msg.info("No parent element available.")
end

function Queue:handle(m)
    self.bindings[m]()
end

---------------------
-- Global Topic Queue

GlobalTopicQueue = {}
GlobalTopicQueue.__index = GlobalTopicQueue

setmetatable(GlobalTopicQueue, {
    __index = Queue, -- this is what makes the inheritance work
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end,
})

function GlobalTopicQueue:_init(old, topics)
    Queue._init(self, topics, "Global Topic Queue")
    self:load(old, self.items[self.cur_idx])
    self:subscribe_to_events()
    sounds.play("global_topic_queue")
end

-- TODO: Refactor
local function update_curtime(_, time)
    if time == nil then return end
    local cur = active_queue:get_current()
    if cur == nil then return end
    if cur["curtime"] == nil then return end
    cur["curtime"] = tostring(time)
    cur["curtime_updated"] = tostring(os.time(os.date("!*t"))) -- TODO: is this UTC?
    db.topics:set_by_id(cur["id"], cur)
end

-- TODO: Refactor
local function update_speed(_, speed)
    local cur = active_queue:get_current()
    if speed == nil then return end
    cur["speed"] = speed
    db.topics:set_by_id(cur["id"], cur)
end

function GlobalTopicQueue:subscribe_to_events()
    msg.info("Subscribing to events.")
    mp.observe_property("speed", "number", update_speed)
    mp.observe_property("time-pos", "number", update_curtime)
end

function GlobalTopicQueue:clean_up_events()
    msg.info("Unsubscribing from events.")
    mp.unobserve_property(update_curtime)
    mp.unobserve_property(update_speed)
end

function GlobalTopicQueue:handle_forward()
    if mp.get_property("pause") == "yes" then
        self:stutter_forward()
    else
        self:forward()
    end
end

function GlobalTopicQueue:handle_backward()
    if mp.get_property("pause") == "yes" then
        self:stutter_backward()
    else
        self:backward()
    end
end

function GlobalTopicQueue:handle_extract(start, stop, cur)
    local id = tostring(#db.extracts.csv_table + 1)
    local extract = {
        id = id,
        parent = cur["id"],
        type = cur["type"],
        url = cur["url"],
        start = tostring(start),
        stop = tostring(stop),
        priority = cur["priority"]
    }
    db.extracts:add(extract)
    sounds.play("echo")
    mp.commandv("script-message", "extracted", self.name)
    unset_abloop()
end

function GlobalTopicQueue:child()
    local cur = self:get_current()
    local is_child_of_cur = curry2(is_parent)(cur)
    if self:change_queue(db.extracts,
                         is_child_of_cur,
                         function(x) return ExtractQueue(cur, x)end)
    then
        self:clean_up_events()
    end
end

----------------
-- Base Extract Queue

ExtractQueue = {}
ExtractQueue.__index = ExtractQueue

setmetatable(ExtractQueue, {
    __index = Queue, -- this is what makes the inheritance work
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end,
})

function ExtractQueue:_init(old, extracts)
    Queue._init(self, extracts, "Extract Queue")
    self:load(old, self.items[self.cur_idx])
    sounds.play("local_extract_queue")
end

function ExtractQueue:handle_backward()
    self:stutter_backward()
end

function ExtractQueue:handle_forward()
    self:stutter_forward()
end

function ExtractQueue:child()
    local cur = self:get_current()
    local is_child_of_cur = curry2(is_parent)(cur)
    self:change_queue(db.items, is_child_of_cur, function(x) return ItemQueue(x) end)
end

function ExtractQueue:parent()
    local cur = self:get_current()
    local creator_fn = function(topics)
        local is_parent_of_cur = curry2(is_child)(cur)
        move_to_first_where(is_parent_of_cur, topics)
        return GlobalTopicQueue(cur, topics)
    end
    self:change_queue(db.topics, is_outstanding, creator_fn)
end

function ExtractQueue:adjust_extract(start, stop)
    local cur = self:get_current()
    local duration = tonumber(mp.get_property("duration"))
    if start < 0 or start > duration or stop < 0 or stop > duration
        then return end

    local start_changed = cur["start"] ~= tostring(start)
    local stop_changed = cur["stop"] ~= tostring(stop)

    cur["start"] = tostring(start)
    cur["stop"] = tostring(stop)
    db.extracts:set_by_id(cur["id"], cur)

    -- update loop timer
    loop_timer.set_start_time(tonumber(cur["start"]))
    loop_timer.set_stop_time(tonumber(cur["stop"]))

    if start_changed then
        mp.commandv("seek", cur["start"], "absolute")
    elseif stop_changed then
        mp.commandv("seek", tostring(tonumber(cur["stop"]) - 1), "absolute") -- TODO: > 0
    end

    msg.info("Updated extract boundaries to " .. cur["start"] .. " -> " .. cur["stop"])
end

function ExtractQueue:advance_start()
    local adj = 0.1
    local cur = self:get_current()
    local start = tonumber(cur["start"]) - adj
    local stop = tonumber(cur["stop"])
    self:adjust_extract(start, stop)
end

function ExtractQueue:advance_stop()
    local adj = 0.1
    local cur = self:get_current()
    local start = tonumber(cur["start"])
    local stop = tonumber(cur["stop"]) - adj
    self:adjust_extract(start, stop)
end

function ExtractQueue:postpone_start()
    local adj = 0.1
    local cur = self:get_current()
    local start = tonumber(cur["start"]) + adj
    local stop = tonumber(cur["stop"])
    self:adjust_extract(start, stop)
end

function ExtractQueue:postpone_stop()
    local adj = 0.1
    local cur = self:get_current()
    local start = tonumber(cur["start"])
    local stop = tonumber(cur["stop"]) + adj
    self:adjust_extract(start, stop)
end

function ExtractQueue:handle_extract(start, stop, cur)
    local url = cur["url"]
    if cur["type"] == "youtube" then
        local args = {
            "youtube-dl",
            "-f", "worstaudio",
            "--youtube-skip-dash-manifest",
            "-g", url
        }
        local ret = subprocess(args)
        if ret.status == 0 then
            local lines = ret.stdout
            local matches = lines:gmatch("([^\n]*)\n?")
            url = matches()
            msg.info("Found audio stream: " .. url)
        else
            msg.info("Failed to get audio stream.")
            return false
        end
    end

    start = start - tonumber(cur["start"])
    stop = stop - tonumber(cur["start"])

    local extension = ".wav"
    local fname = tostring(os.time(os.date("!*t"))) .. "-aa"
    local extract = utils.join_path(mediadir, fname .. extension)

    local args = {
        "ffmpeg",
        -- "-hide_banner",
        "-nostats",
        -- "-loglevel", "fatal",
        "-ss", tostring(cur["start"]),
        "-to", tostring(cur["stop"]),
        "-i", url, -- extract audio stream
        extract
    }

    local completion_fn = function()

        local cloze = "sine.opus"
        local edl = utils.join_path("media", fname .. ".edl")
        local id = tostring(#db.items.csv_table + 1)

        -- Create virtual file using EDL
        local handle = io.open(edl, "w")
        handle:write("# mpv EDL v0\n")
        handle:write(fname .. extension .. ",0," .. tostring(start) .. "\n")
        handle:write(cloze .. ",0," .. tostring(stop - start) .. "\n")
        handle:write(fname .. extension .. "," .. tostring(stop) .. "," .. tostring(tonumber(cur["stop"]) - tonumber(cur["start"]) - stop) .. "\n")
        handle:close()

        local item = {
            id = id,
            parent = cur["id"],
            url = edl,
            priority = cur["priority"]
        }

        db.items:add(item)
        sounds.play("echo")
        mp.commandv("script-message", "extracted", self.name)
        mp.set_property("ab-loop-a", "no")
        mp.set_property("ab-loop-b", "no")
    end

    subprocess(args, completion_fn)

end

----------------------
-- Item Queue

ItemQueue = {}
ItemQueue.__index = ItemQueue

setmetatable(ItemQueue, {
 __index = Queue, -- this is what makes the inheritance work
 __call = function (cls, ...)
     local self = setmetatable({}, cls)
     self:_init(...)
     return self
 end,
})

function ItemQueue:_init(items)
    Queue._init(self, items, "Item Queue")
    self:load(nil, self:get_current())
    sounds.play("local_item_queue")
end

function ItemQueue:parent()

    local all = function(_) return true end
    local cur = self:get_current()
    local creator_fn = function(extracts)
        local is_parent_of_cur = curry2(is_child)(cur)
        move_to_first_where(is_parent_of_cur, extracts)
        return ExtractQueue(nil, extracts)
    end

    self:change_queue(db.extracts, all, creator_fn)
end

function ItemQueue:adjust_cloze(adjustment_fn)
    mp.set_property("pause", "yes")
    local cur = self:get_current()
    local edl = EDL.new(cur["url"])
    edl:load()

    local cloze_start = edl.data["cloze"]["start"]
    local cloze_end = edl.data["cloze"]["stop"]

    adjustment_fn(edl)

    local adj_cloze_start = edl.data["cloze"]["start"]
    local adj_cloze_end = edl.data["cloze"]["stop"]

    local start_changed = cloze_start ~= adj_cloze_start
    local end_changed = cloze_end ~= adj_cloze_end

    edl:write()

    -- reload

    if start_changed then
        local start = tostring(tonumber(adj_cloze_start) - 0.5) -- TODO > 0
        mp.commandv("loadfile", cur["url"], "replace", "start=" .. start)
    elseif end_changed then
        local start = tostring(tonumber(adj_cloze_end)) -- TODO > 0
        mp.commandv("loadfile", cur["url"], "replace", "start=".. start)
    end
    mp.set_property("pause", "no")
    sounds.play("click1")
end

function ItemQueue:advance_start()
    local adj = 0.02
    local duration = tonumber(mp.get_property("duration"))

    local function adjustment_fn(edl)
        local beg_stop = tonumber(edl.data["beg"]["stop"]) - adj
        local cloze_stop = tonumber(edl.data["cloze"]["stop"]) + adj
        local beg_valid = beg_stop > 0 and beg_stop < duration
        local cloze_valid = cloze_stop > 0 and cloze_stop < duration
        if cloze_valid and beg_valid then
            edl.data["beg"]["stop"] = tostring(beg_stop)
            edl.data["cloze"]["stop"] = tostring(cloze_stop)
        end
    end

    self:adjust_cloze(adjustment_fn)
end

function ItemQueue:postpone_start()
    local adj = 0.02
    local duration = tonumber(mp.get_property("duration"))

    local function adjustment_fn(edl)
        local beg_stop = tonumber(edl.data["beg"]["stop"]) + adj
        local cloze_start = tonumber(edl.data["cloze"]["start"]) + adj
        local beg_valid = beg_stop > 0 and beg_stop < duration
        local cloze_valid = cloze_start > 0 and cloze_start < duration

        if cloze_valid and beg_valid then
            edl.data["beg"]["stop"] = tostring(beg_stop)
            edl.data["cloze"]["start"] = tostring(cloze_start)
        end
    end
    self:adjust_cloze(adjustment_fn)
end

function ItemQueue:advance_stop()
    local adj = 0.02
    local duration = tonumber(mp.get_property("duration"))

    local function adjustment_fn(edl)
        local cloze_stop = tonumber(edl.data["beg"]["stop"]) - adj
        local ending_start = tonumber(edl.data["ending"]["start"]) - adj

        local cloze_valid = cloze_stop > 0 and cloze_stop < duration
        local ending_valid = ending_start > 0 and ending_start < duration

        if cloze_valid and ending_valid then
            edl.data["cloze"]["stop"] = tostring(cloze_stop)
            edl.data["ending"]["start"] = tostring(ending_start)
        end
    end
    self:adjust_cloze(adjustment_fn)
end

function ItemQueue:postpone_stop()
    local adj = 0.02
    local duration = tonumber(mp.get_property("duration"))

    local function adjustment_fn(edl)
        local cloze_stop = tonumber(edl.data["cloze"]["stop"]) + adj
        local ending_start = tonumber(edl.data["ending"]["start"]) + adj

        local cloze_valid = cloze_stop > 0 and cloze_stop < duration
        local ending_valid = ending_start > 0 and ending_start < duration

        if cloze_valid and ending_valid then
            edl.data["cloze"]["stop"] = tostring(cloze_stop)
            edl.data["ending"]["start"] = tostring(ending_start)
        end
    end

    self:adjust_cloze(adjustment_fn)
end


local function verify_dependencies()
    local deps = { "youtube-dl", "ffmpeg" }
    for _, dep in pairs(deps) do
        if not platform.check_dependency(dep) then
            msg.info("Could not find dependency " .. dep .. " in path. Exiting...")
            mp.commmandv("exit")
            return
        end
    end
    msg.info("All dependencies available in path.")
end

------------------------------------------------------------
-- main

local main
do
    local main_executed = false
    main = function()
        if main_executed then return end

        validate_config()
        verify_dependencies()
        create_essential_files()

        -- TODO: Refactor to open extracts / items instead
        db.init()

        local topics = db.topics:get_outstanding()
        if topics == nil or #topics == 0 then
            msg.info("No topics!")
            mp.commandv("quit")
            return
        end

        mp.observe_property("time-pos", "number", loop_timer.check_loop)
        mp.set_property("loop", "inf")
        mp.register_event("shutdown", db.on_shutdown)

        active_queue = GlobalTopicQueue(nil, topics)

        -- Key bindings
        mp.add_forced_key_binding("UP", "aa-parent", function() active_queue:parent() end )
        mp.add_forced_key_binding("DOWN", "aa-child", function() active_queue:child() end )
        mp.add_forced_key_binding("LEFT", "aa-backward", function() active_queue:handle_backward() end )
        mp.add_forced_key_binding("RIGHT", "aa-forward", function() active_queue:handle_forward() end )
        mp.add_forced_key_binding("alt+x", "aa-extract", function() active_queue:extract() end )
        mp.add_forced_key_binding("shift+left", "aa-prev", function() active_queue:prev() end )
        mp.add_forced_key_binding("shift+right", "aa-next", function() active_queue:next() end )

        mp.add_forced_key_binding("y", "aa-advance-start", function() active_queue:advance_start() end )
        mp.add_forced_key_binding("u", "aa-postpone-start", function() active_queue:postpone_start() end )
        mp.add_forced_key_binding("o", "aa-postpone-stop", function() active_queue:postpone_stop() end )
        mp.add_forced_key_binding("i", "aa-advance-stop", function() active_queue:advance_stop() end )

        main_executed = true
    end
end

-- for when loading from idle
mp.add_key_binding("ctrl+p", "aa-load", main)
mp.register_event("file-loaded", main)
