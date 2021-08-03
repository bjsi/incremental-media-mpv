local log = require("utils.log")
local ext = require("utils.ext")
local str = require("utils.str")
local Subtitle = require("systems.subs.subtitle")

local function new_sub_list()
    local subs_list = {}
    local _is_empty = function() return next(subs_list) == nil end
    local find_i = function(sub)
        for i, v in ipairs(subs_list) do if sub < v then return i end end
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
        if sub ~= nil and not ext.list_contains(subs_list, sub) then
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

local function new_timings()
    local self = {['start'] = -1, ['end'] = -1}
    local is_set = function(position) return self[position] >= 0 end
    local set = function(position, time)
        time = tonumber(time)
        if not time then time = mp.get_property_number('time-pos') end
        self[position] = time
    end
    local get = function(position) return self[position] end
    return {is_set = is_set, set = set, get = get}
end

local subs = {
    dialogs = new_sub_list(),
    user_timings = new_timings(),
    observed = false
}

subs.get_current = function()
    local sub_text = mp.get_property("sub-text")
    if not ext.empty(sub_text) then
        local sub_delay = mp.get_property_native("sub-delay")
        return Subtitle:new{
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
    if subs.dialogs.is_empty() then subs.dialogs.insert(subs.get_current()) end
    local sub = Subtitle:new{
        ['text'] = subs.dialogs.get_text(),
        ['start'] = subs.get_timing('start'),
        ['end'] = subs.get_timing('end')
    }
    if sub['start'] < 0 or sub['end'] < 0 then return nil end
    if sub['start'] == sub['end'] then return nil end
    if sub['start'] > sub['end'] then
        sub['start'], sub['end'] = sub['end'], sub['start']
    end
    if not ext.empty(sub['text']) then
        sub['text'] = str.trim(sub['text'])
        sub["text"] = str.remove_db_delimiters(sub["text"])
        -- sub['text'] = str.escape_special_chars(sub['text'])
    end
    return sub
end

subs.append = function()
    subs.dialogs.insert(subs.get_current())
end

subs.observe = function()
    mp.observe_property("sub-text", "string", subs.append)
    subs.observed = true
end

subs.unobserve = function()
    mp.unobserve_property(subs.append)
    subs.observed = false
end

subs.set_timing = function(position, time)
    subs.user_timings.set(position, time)
    log.notify(str.capitalize_first(position) .. " time has been set.")
    if not subs.observed then subs.observe() end
end

subs.set_starting_line = function()
    subs.clear()
    if not ext.empty(mp.get_property("sub-text")) then
        subs.observe()
        log.notify("Timings have been set to the current sub.", "info", 2)
    else
        log.notify("There's no visible subtitle.", "info", 2)
    end
end

subs.clear = function()
    subs.unobserve()
    subs.dialogs = new_sub_list()
    subs.user_timings = new_timings()
end

subs.clear_and_notify = function()
    subs.clear()
    log.notify("Timings have been reset.", "info", 2)
end

return subs