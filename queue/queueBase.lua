local sounds = require("systems.sounds")
local fs = require("systems.fs")
local mpu = require("mp.utils")
local sys = require("systems.system")
local log = require("utils.log")
local player = require("systems.player")
local Stack = require("queue.stack")
local ext = require "utils.ext"
local active = require "systems.active"
local menu   = require "systems.menu.menuBase"

local QueueBase = {}
QueueBase.__index = QueueBase

setmetatable(QueueBase, {
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function QueueBase:_init(name, reptable, oldRep)
    self.name = name
    self.reptable = reptable
    self.fwd_history = Stack:Create()
    self.bwd_history = Stack:Create()
    self.playing = nil
    self.oldRep = oldRep
    self.createLoopBoundaries = true
    self.useStartStop = true
    self.bigSeek = 5
    self.smallSeek = 1
end

function QueueBase:activate()
    log.debug(table.concat({"Activating:", self.name, "with", tostring(#self.reptable.subset), "reps."}, " "))
    player.on_overrun = nil
    player.on_underrun = nil
    return self:loadRep(self.reptable.fst, self.oldRep)
end

function QueueBase:localize(_)
    log.debug("Cannot localize videos in " .. self.name)
    sounds.play("negative")
end

function QueueBase:has_children()
    sounds.play("negative")
end

function QueueBase:update_speed()
    local speed = mp.get_property_number("speed")
    if not speed then return end
    if not self.playing then return end
    self.playing.row["speed"] = ext.round(speed, 2)
end

-- TODO: Change name to learn
function QueueBase:next_repetition()
    local oldRep = self.playing
    local toLoad = self.reptable:next_repetition()
    if not toLoad then
        log.debug("No rep to load. Returning.")
        return 
    end

    self:save_data()
    if self:loadRep(toLoad, oldRep) and oldRep ~= nil then
        self.bwd_history:push(oldRep)
        log.debug("Pushing oldRep onto bwd history", self.bwd_history)
        log.notify("next rep")
        menu.update()
    end
end

function QueueBase:validate_abloop(a, b)
    if not a or not b then return false end
    if a == b then return false end
    if a == "no" or b == "no" then
        return false
    end
    a = tonumber(a)
    b = tonumber(b)
    local dur = tonumber(mp.get_property("duration"))
    return (a >=0 and b >= 0) and (a <= dur and b <= dur)
end

function QueueBase:navigate_history(fwd)
    log.debug("Navigate History called:")

    local oldRep = self.playing

    local exists = function(r)
        return r ~= nil and not r:is_deleted()
    end

    local toload
    
    if fwd then 
        toload = ext.stack_first(exists, self.fwd_history)
    else
        toload = ext.stack_first(exists, self.bwd_history)
    end

    if toload == nil then
        log.debug("No elements to navigate to.")
        return false
    end

    self:save_data()
    if self:loadRep(toload, oldRep) then
        if oldRep ~= nil then
            if fwd then
                self.bwd_history:push(oldRep)
                log.debug("Updated bwd history to: ", self.bwd_history)
            else
                self.fwd_history:push(oldRep)
                log.debug("Updated fwd history to: ", self.fwd_history)
            end
        end
        return true
    end

    return false
end

function QueueBase:set_end_boundary_extract()
    local cur = self.playing
    if cur == nil then return end
    local curTime = mp.get_property("time-pos")

    local a = mp.get_property("ab-loop-a")
    local b = mp.get_property("ab-loop-b")

    if a ~= "no" and b == "no" then
        mp.set_property("ab-loop-b", curTime)
        if self:extract() then
            mp.commandv("seek", curTime, "absolute")
        end
    end
end

function QueueBase:copy_url(includeTimestamp)
    local cur = self.playing
    if cur == nil then return end

    local url = includeTimestamp and player.get_full_url(cur, mp.get_property("time-pos")) or player.get_full_url(cur)
    if ext.empty(url) then
        log.err("Failed to get full url for current rep")
        return
    end
    sys.clipboard_write(url)
end

function QueueBase:advance_start(n)
    self:adjust_abloop(false, true, n)
end

function QueueBase:adjust_interval(n)
    local cur = self.playing
    if cur == nil then return false end

    local curInt = tonumber(cur.row["interval"])
    local adj = tonumber(n)
    if curInt == nil or adj == nil then return false end

    local newInt = curInt + adj
    if ext.validate_interval(newInt) then
        cur.row["interval"] = newInt
        self:save_data()
        log.notify("interval: " .. tostring(newInt))
        menu.update()
        return true
    end
end

function QueueBase:adjust_priority(n)
    local cur = self.playing
    if cur == nil then return end
    local curPri = tonumber(cur.row["priority"])
    local adj = tonumber(n)
    if curPri == nil or adj == nil then return end
    local newPri = curPri + adj
    if ext.validate_priority(newPri) and cur ~= nil then
        cur.row["priority"] = newPri
        self:save_data()
        log.notify("priority: " .. tostring(newPri))
        menu.update()
        return true
    end
    return false
end

function QueueBase:split_chapters()
    sounds.play("negative")
end

function QueueBase:postpone_start(n)
    self:adjust_abloop(true, true, n)
end

function QueueBase:advance_stop(n)
    self:adjust_abloop(false, false, n)
end

function QueueBase:postpone_stop(n)
    self:adjust_abloop(true, false, n)
end

function QueueBase:adjust_abloop(postpone, start, n)
    local adj = postpone and n or -n

    local a = tonumber(mp.get_property("ab-loop-a"))
    local b = tonumber(mp.get_property("ab-loop-b"))
    if not self:validate_abloop(a, b) then
        log.debug("AB loop boundaries are invalid!")
        sounds.play("negative")
        return
    end

    local oldStart = a > b and b or a
    local oldStop = a < b and b or a

    local newStart = oldStart
    local newStop = oldStop

    if start then
        newStart = oldStart + adj
        log.debug("Adjusting start from: ", tostring(oldStart), " to: ", tostring(newStart))
    else
        newStop = oldStop + adj
        log.debug("Adjusting stop from: ", tostring(oldStop), " to: ", tostring(newStop))
    end 

    local start_changed = newStart ~= oldStart
    local stop_changed = newStop ~= oldStop

    if not self:validate_abloop(newStart, newStop) then
        log.debug("Invalid ab-loop values.")
        return
    end

    mp.set_property("ab-loop-a", tostring(newStart))
    mp.set_property("ab-loop-b", tostring(newStop))

    if start_changed then
        log.debug("Updating ab-loop start to: " .. tostring(newStart))
        mp.commandv("seek", tostring(newStart), "absolute")
    elseif stop_changed then
        log.debug("Updating ab-loop stop to: " .. tostring(newStop))
        mp.commandv("seek", tostring(newStop - 0.3), "absolute")
    end
end

function QueueBase:adjust_afactor(n)
    local cur = self.playing
    if cur == nil then return end

    local curAF = tonumber(cur.row["afactor"])
    local adj = tonumber(n)
    if curAF == nil or adj == nil then return end
        
    local newAF = curAF + adj
    if ext.validate_afactor(newAF) then
        cur.row["afactor"] = newAF
        log.debug("Updated afactor to: " .. newAF)
        log.notify("interval: " .. tostring(newAF))
        self:save_data()
        menu.update()
        return true
    end

    return false
end

function QueueBase:toggle_export()
    local cur = self.playing
    if cur == nil then return end
    local exp = tonumber(cur.row["toexport"])
    cur.row["toexport"] = exp == 1 and 0 or 1
    local sound = exp == 1 and "positive" or "negative"
    sounds.play(sound)
    self:save_data()
end

function QueueBase:clear_abloop()
    player.unset_abloop()
end

function QueueBase:set_speed(num)
    if num < 0 or num > 5 then return end
    mp.set_property("speed", tostring(num))
end

function QueueBase:forward_history()
    self.reptable:update_dependencies()
    if not self:navigate_history(true) then
        sounds.play("negative")
    else
        sounds.play("click1")
    end
end

function QueueBase:backward_history()
    self.reptable:update_dependencies()
    if not self:navigate_history(false) then
        sounds.play("negative")
    else
        sounds.play("click1")
    end
end

function QueueBase:reload()
    local reptable = self.reptable.db:read()
    if reptable == nil then
        log.err("Failed to reload the rep table!")
        return false
    end

    self.reptable = reptable
    log.debug("Reloaded the rep table.")
    return true
end

function QueueBase:extract(extractType)
    if active.locked then
        log.debug("Can't extract during update lock.")
        sounds.play("negative")
        return false
    end

    local a = mp.get_property("ab-loop-a")
    local b = mp.get_property("ab-loop-b")
    if a == "no" or b == "no" then
        log.debug("Extract boundaries are not set!")
        sounds.play("negative")
        return false
    end

    a = tonumber(a)
    b = tonumber(b)
    if a == b then
        log.debug("Extract boundaries are equal!");
        return false
    end

    local start = a < b and a or b
    local stop = a > b and a or b
    local curRep = self.playing

    active.enter_update_lock()
    local ret = self:handle_extract(start, stop, curRep, extractType)
    active.exit_update_lock()
    if ret then
        log.notify("new extract created!")
        menu.update()
    else
        log.notify("extraction failed!")
    end
    return ret
end

function QueueBase:toggle_video() player.toggle_vid() end

function QueueBase:toggle() player.toggle() end

function QueueBase:loop() player.loop() end

function QueueBase:handle_backward(big)
    local seek = big and self.bigSeek or self.smallSeek
    mp.commandv("seek", "-" .. tostring(seek))
end

function QueueBase:handle_forward(big)
    local seek = big and self.bigSeek or self.smallSeek
    mp.commandv("seek", tostring(seek))
end

function QueueBase:dismiss()
    local cur = self.playing
    if cur == nil then
        log.debug("Failed to dismiss because self.playing is nil.")
        return
    end

    cur.row["dismissed"] = 1
    log.debug("Dismissed repetition.")
    sounds.play("delete")
    self.reptable:update_subset()
    self:save_data()
    menu.update()
end

function QueueBase:load_grand_queue()
end

function QueueBase:subscribe_to_events()
end

function QueueBase:clean_up_events()
end

function QueueBase:loadRep(newRep, oldRep)
    if player.play(newRep, oldRep, self.createLoopBoundaries, self.useStartStop) then
        self.playing = newRep
        self.reptable:update_dependencies()
        return true
    end

    log.debug("Failed to load rep.")
    return false
end

function QueueBase:child()
    sounds.play("negative")
    log.debug("No child element available.")
end

function QueueBase:parent()
    sounds.play("negative")
    log.debug("No parent element available.")
end

function QueueBase:save_data() self.reptable:write(self.reptable) end

return QueueBase
