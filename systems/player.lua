local mpu = require("mp.utils")
local ext = require("utils.ext")
local subs = require("systems.subs")
local log = require("utils.log")
local sounds = require("systems.sounds")
local active = require("systems.active")

local player = {}

local function load(newRep, oldRep, start)
    log.debug("player.load: start = " .. tostring(start))
    if oldRep ~= nil and oldRep.row["url"] == newRep.row["url"] then
        mp.commandv("seek", tostring(start), "absolute")
    else
        mp.commandv("loadfile", newRep.row["url"], "replace",
                    "start=" .. tostring(start))
    end
end

function player.setSpeed(speed)
    if speed ~= nil then
        mp.set_property("speed", tostring(speed))
    else
        mp.set_property("speed", "1")
    end
end

function player.get_stream_urls()
    local streams = mp.get_property("stream-path")
    local matches = streams:gmatch("https://[^;]+")
    local s1 = matches()
    local s2 = matches()
    local video, audio
    if s1:find("mime=video") then
        video, audio = s1, s2
    else
        video, audio = s2, s1
    end
    return video, audio
end

-- TODO: What if loadfile fails?
function player.play(newRep, oldRep, createLoopBoundaries)
    if newRep == nil then
        log.err("Failed to play new rep because it is nil.")
        return false
    end

    local speed = tonumber(newRep:valid_speed() and newRep.row["speed"] or 1)
    local start = tonumber(newRep:valid_start() and newRep.row["start"] or 0)
    local curtime = tonumber(newRep.row["curtime"])
    if curtime ~= nil then start = curtime end
    local stop = tonumber(newRep:valid_stop() and newRep.row["stop"] or -1)

    load(newRep, oldRep, start)
    player.setSpeed(speed)

    -- reset loops and timers
    player.unset_abloop()
    player.pause_timer.stop()
    if not createLoopBoundaries then
        start = 0
        stop = -1
    end

    log.debug("Setting loop boundaries - start: " .. tostring(start) .. " stop: " .. tostring(stop))
    player.loop_timer.set_start_time(start)
    player.loop_timer.set_stop_time(stop)

    return true
end

function player.unset_abloop()
    mp.set_property("ab-loop-a", "no")
    mp.set_property("ab-loop-b", "no")
end

function player.paused() return mp.get_property("pause") == "yes" end

player.loop_timer = (function()
    local start_time = 0
    local stop_time = -1
    local check_loop

    local set_stop_time = function(time) stop_time = time end
    local set_start_time = function(time) start_time = time end

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

    -- local on_el_changed = function(_, start_t, stop_t)
    --     log.debug("Received element changed event.")
    --     if start_t == nil then return end
    --     if stop_t == nil then return end
    --     set_start_time(tonumber(start_t))
    --     set_stop_time(tonumber(stop_t))
    -- end

    -- mp.register_script_message("element_changed", on_el_changed)

    return {
        set_start_time = set_start_time,
        set_stop_time = set_stop_time,
        check_loop = check_loop,
        stop = stop
    }
end)()

player.pause_timer = (function()
    local stop_time = -1
    local check_stop
    local set_stop_time = function(time) stop_time = time end
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
    return {set_stop_time = set_stop_time, check_stop = check_stop, stop = stop}
end)()

player.stutter_forward = function()
    if not player.vid_playing() then
        player.pause_timer.stop()
        mp.set_property("pause", "yes")
        mp.commandv("seek", "-0.055")
        local cur = tonumber(mp.get_property("time-pos"))
        player.pause_timer.set_stop_time(cur + 0.04)
        mp.observe_property("time-pos", "number", player.pause_timer.check_stop)
        mp.set_property("pause", "no")
    else
        mp.commandv("frame-step")
    end
end

player.stutter_backward = function()
    if not player.vid_playing() then
        player.pause_timer.stop()
        mp.set_property("pause", "yes")
        local cur = tonumber(mp.get_property("time-pos"))
        mp.commandv("seek", "-0.2")
        player.pause_timer.set_stop_time(cur - 0.08)
        mp.observe_property("time-pos", "number", player.pause_timer.check_stop)
        mp.set_property("pause", "no")
    else
        mp.commandv("frame-back-step")
    end
end

player.vid_playing = function() return mp.get_property("vid") ~= "no" end

player.toggle = function()
    mp.commandv("cycle", "pause")
    sounds.play("click1")
end

player.loop = function()
    mp.commandv("ab-loop")
    sounds.play("click1")
end

player.toggle_vid = function()
    log.debug("Toggling video.")
    if player.vid_playing() then
        mp.set_property("vid", "no")
    else
        mp.set_property("vid", "1")
    end
end

player.sub_replay = function()
    local sub = subs.get_current()
    player.pause_timer.set_stop_time(sub['end'] - 0.050)
    mp.commandv('seek', sub['start'], 'absolute')
    mp.set_property("pause", "no")
    mp.observe_property("time-pos", "number", player.pause_timer.check_stop)
end

player.sub_seek = function(direction, pause)
    mp.commandv("sub_seek", direction == 'backward' and '-1' or '1')
    mp.commandv("seek", "0.015", "relative+exact")
    if pause then mp.set_property("pause", "yes") end
    player.pause_timer.stop()
end

function player.sub_rewind()
    mp.commandv('seek', subs.get_current()['start'] + 0.015, 'absolute')
    player.pause_timer.stop()
end

return player
