local sounds = require 'systems.sounds'
local subs = require 'systems.subs.subs'
local sys = require 'systems.system'
local log = require 'utils.log'
local player = require 'systems.player'
local Stack = require 'queues.stack'
local active = require 'systems.active'
local menu = require 'systems.menu.menuBase'
local mp = require 'mp'
local stack = require 'utils.stack'
local obj = require 'utils.object'
local ivl = require 'utils.interval'
local af = require 'utils.afactor'
local pri = require 'utils.priority'
local num = require 'utils.number'

local QueueBase = {}
QueueBase.__index = QueueBase

setmetatable(QueueBase, {
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function QueueBase:_init(name, reptable, old_rep)
    self.name = name
    self.reptable = reptable
    self.fwd_history = Stack:Create()
    self.bwd_history = Stack:Create()
    self.playing = nil
    self.old_rep = old_rep
    self.create_loop_boundaries = true
    self.use_start_stop = true
end

function QueueBase:activate()
    log.notify("Loading: " .. self.name)
    player.on_overrun = nil
    player.on_underrun = nil
    return self:load_rep(self.reptable.fst, self.old_rep)
end

function QueueBase:localize(_)
    log.debug("Cannot localize videos in " .. self.name)
    sounds.play("negative")
end

function QueueBase:update_speed()
    local speed = mp.get_property_number("speed")
    if not speed then return end
    if not self.playing then return end
    self.playing.row.speed = num.round(speed, 2)
end

function QueueBase:learn()
    local old_rep = self.playing
    local new_rep = self.reptable:learn()
    if not new_rep then
        log.notify("No new rep to load.")
        return
    end

    self:save_data()
    if self:load_rep(new_rep, old_rep) and old_rep ~= nil then
        self.bwd_history:push(old_rep)
        log.notify("Next repetition")
    end
    menu.update()
end

function QueueBase:validate_abloop(a, b)
    if not a or not b then return false end
    if a == b then return false end
    if a == "no" or b == "no" then return false end
    a = tonumber(a)
    b = tonumber(b)
    local dur = tonumber(mp.get_property("duration"))
    return (a >= 0 and b >= 0) and (a <= dur and b <= dur)
end

function QueueBase:navigate_history(forward)
    local old_rep = self.playing

    local new_rep
    local exists = function(r) return r ~= nil and not r:is_deleted() end
    if forward then
        new_rep = stack.first(exists, self.fwd_history)
    else
        new_rep = stack.first(exists, self.bwd_history)
    end

    if new_rep == nil then
        log.debug("No elements to navigate to.")
        return false
    end

    self:save_data()
    if not self:load_rep(new_rep, old_rep) then
        log.debug("Failed to load rep.")
        return false
    end

    -- update navigation history
    if old_rep == nil then
        -- no need to update history
        return true
    end

    if forward then
        self.bwd_history:push(old_rep)
    else
        self.fwd_history:push(old_rep)
    end
    return true
end

function QueueBase:clear_extract_boundaries()
    player.unset_abloop()
    subs.clear()
    log.notify("Cleared extract boundaries.")
end

function QueueBase:set_extract_start()
    subs.set_timing('start')
    log.notify("Extract start.")
end

function QueueBase:set_extract_stop()
    subs.set_timing('end')
    log.notify("Extract stop.")
end

function QueueBase:set_extract_boundary()
    mp.commandv("ab-loop")
    local a = tonumber(mp.get_property("ab-loop-a"))
    local b = tonumber(mp.get_property("ab-loop-b"))

    if a == nil and b == nil then
        self:clear_extract_boundaries()
    elseif a ~= nil and b == nil then
        self:set_extract_start()
    elseif a ~= nil and b ~= nil then
        self:set_extract_stop()
    end
end

-- TODO
function QueueBase:set_end_boundary_extract()
    local cur = self.playing
    if cur == nil then return end
    local curTime = mp.get_property("time-pos")

    local a = mp.get_property("ab-loop-a")
    local b = mp.get_property("ab-loop-b")

    if a ~= "no" and b == "no" then
        mp.set_property("ab-loop-b", curTime)
        if self:extract() then mp.commandv("seek", curTime, "absolute") end
    end
end

function QueueBase:copy_url(includeTimestamp)
    local cur = self.playing
    if cur == nil then return end

    local url = includeTimestamp and
                    player.get_full_url(cur, mp.get_property("time-pos")) or
                    player.get_full_url(cur)
    if obj.empty(url) then
        log.err("Failed to get full url for current rep")
        return
    end
    sys.clipboard_write(url)
end

function QueueBase:adjust_interval(n)
    local cur = self.playing
    if cur == nil then return false end

    local curInt = tonumber(cur.row["interval"])
    local adj = tonumber(n)
    if curInt == nil or adj == nil then return false end

    local newInt = curInt + adj
    if ivl.validate(newInt) then
        cur.row["interval"] = newInt
        self:save_data()
        log.notify("Interval: " .. tostring(newInt))
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
    if pri.validate(newPri) and cur ~= nil then
        cur.row["priority"] = newPri
        self:save_data()
        log.notify("Priority: " .. tostring(newPri))
        menu.update()
        return true
    end
    return false
end

function QueueBase:split_chapters() sounds.play("negative") end

function QueueBase:advance_start(n)
    self:adjust_abloop(false, true, n)
    log.notify("<-start")
end

function QueueBase:postpone_start(n)
    self:adjust_abloop(true, true, n)
    log.notify("start->")
end

function QueueBase:advance_stop(n)
    self:adjust_abloop(false, false, n)
    log.notify("<-stop")
end

function QueueBase:postpone_stop(n)
    self:adjust_abloop(true, false, n)
    log.notify("stop->")
end

function QueueBase:adjust_abloop(postpone, start, n)
    local adj = postpone and n or -n

    local a = tonumber(mp.get_property("ab-loop-a"))
    local b = tonumber(mp.get_property("ab-loop-b"))
    if not self:validate_abloop(a, b) then
        log.debug("AB loop boundaries are invalid!")
        sounds.play("negative")
        return false
    end

    local oldStart = a > b and b or a
    local oldStop = a < b and b or a

    local newStart = oldStart
    local newStop = oldStop

    if start then
        newStart = oldStart + adj
        log.debug("Adjusting start from: ", tostring(oldStart), " to: ",
                  tostring(newStart))
    else
        newStop = oldStop + adj
        log.debug("Adjusting stop from: ", tostring(oldStop), " to: ",
                  tostring(newStop))
    end

    local start_changed = newStart ~= oldStart
    local stop_changed = newStop ~= oldStop

    if not self:validate_abloop(newStart, newStop) then
        log.debug("Invalid ab-loop values.")
        return false
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

    return true
end

function QueueBase:adjust_afactor(n)
    local cur = self.playing
    if cur == nil then return end

    local curAF = tonumber(cur.row["afactor"])
    local adj = tonumber(n)
    if curAF == nil or adj == nil then return end

    local newAF = curAF + adj
    if af.validate(newAF) then
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
    log.notify("Cleared loop boundaries")
    player.unset_abloop()
    sounds.play("click1")
end

function QueueBase:set_speed(speed)
    if speed < 0 or speed > 5 then return end
    mp.set_property("speed", tostring(speed))
end

function QueueBase:forward_history()
    self.reptable:update_dependencies()
    if not self:navigate_history(true) then
        sounds.play("negative")
    else
        log.notify("Forward")
        sounds.play("click1")
    end
end

function QueueBase:backward_history()
    self.reptable:update_dependencies()
    if not self:navigate_history(false) then
        sounds.play("negative")
    else
        log.notify("Backward")
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

    -- TODO: has to be adjusted for speed?
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

function QueueBase:load_grand_queue() end

function QueueBase:subscribe_to_events() end

function QueueBase:clean_up_events() end

function QueueBase:load_rep(new_rep, old_rep)
    if player.play(new_rep, old_rep, self.create_loop_boundaries,
                   self.use_start_stop) then
        self.playing = new_rep
        self.reptable:update_dependencies() -- TODO: why
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

function QueueBase:save_data() return self.reptable:write(self.reptable) end

return QueueBase
