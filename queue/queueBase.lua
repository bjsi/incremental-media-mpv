local sounds = require("systems.sounds")
local log = require("utils.log")
local player = require("systems.player")
local Stack = require("queue.stack")
local ext = require "utils.ext"

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
end

function QueueBase:activate()
    log.debug("Activating: " .. self.name)
    return self:loadRep(self.reptable.fst, self.oldRep)
end

-- TODO: Change name to learn
function QueueBase:next_repetition()
    local oldRep = self.playing
    local toLoad = self.reptable:next_repetition()
    if not toLoad then
        log.debug("No rep to load. Returning.")
        return 
    end
    if self:loadRep(toLoad, oldRep) and oldRep ~= nil then
        self.bwd_history:push(oldRep)
        log.debug("Pushing oldRep onto bwd history", self.bwd_history)
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

function QueueBase:advance_start()
    self:adjust_abloop(false, true)
end

function QueueBase:postpone_start()
    self:adjust_abloop(true, true)
end

function QueueBase:advance_stop()
    self:adjust_abloop(false, false)
end

function QueueBase:postpone_stop()
    self:adjust_abloop(true, false)
end

function QueueBase:adjust_abloop(postpone, start)
    local adj = postpone and 0.1 or -0.1

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

function QueueBase:extract()
    local a = mp.get_property("ab-loop-a")
    local b = mp.get_property("ab-loop-b")
    if a == "no" or b == "no" then
        log.debug("Extract boundaries are not set!")
        sounds.play("negative")
        return
    end

    a = tonumber(a)
    b = tonumber(b)
    if a == b then
        log.debug("Extract boundaries are equal!");
        return
    end

    local start = a < b and a or b
    local stop = a > b and a or b
    local curRep = self.playing
    self:handle_extract(start, stop, curRep)
end

function QueueBase:toggle_video() player.toggle_vid() end

function QueueBase:toggle() player.toggle() end

function QueueBase:loop() player.loop() end

function QueueBase:stutter_forward() player.stutter_forward() end

function QueueBase:stutter_backward() player.stutter_backward() end

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
end

function QueueBase:load_grand_queue()
end

function QueueBase:clean_up_events()
end

function QueueBase:loadRep(newRep, oldRep)
    if player.play(newRep, oldRep, self.createLoopBoundaries) then
        self.playing = newRep
        self.reptable:update_dependencies()
        return true
    end

    log.debug("Failed to load rep.")
    return false
end

function QueueBase:forward() mp.commandv("seek", "+5") end

function QueueBase:backward() mp.commandv("seek", "-5") end

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
