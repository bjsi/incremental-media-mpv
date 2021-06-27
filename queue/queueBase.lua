local sounds = require("systems.sounds")
local log = require("utils.log")
local player = require("systems.player")
local Stack = require("queue.stack")
local ext = require "utils.ext"

local QueueBase = {}
QueueBase.__index = QueueBase

-- TODO: Save a history of previously visited elements excluding dismissed
setmetatable(QueueBase, {
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function QueueBase:_init(name, reptable, oldRep)
    log.debug("Loading: " .. name)
    self.name = name
    self.reptable = reptable
    self.fwd_history = Stack:Create()
    self.bwd_history = Stack:Create()
    self.playing = nil
    self.oldRep = oldRep
    self.createLoopBoundaries = true
end

function QueueBase:activate()
    return self:loadRep(self.reptable.fst, self.oldRep)
end

-- TODO: Change name to learn
function QueueBase:next_repetition()
    local oldRep = self.playing
    local toLoad = self.reptable:next_repetition()
    if not toLoad then return end
    if self:loadRep(toLoad, oldRep) then
        self.bwd_history:push(oldRep)
    end
end

function QueueBase:navigate_history(fwd)
    local oldRep = self.playing

    local exists = function(r)
        return r and not r:is_deleted()
    end

    local toload = fwd and ext.stack_first(exists, self.fwd_history) or ext.stack_first(exists, self.bwd_history)
    if toload == nil then
        log.debug("No elements to navigate to.")
        return false
    end

    if self:loadRep(toload, oldRep) then
        if fwd then
            self.bwd_history:push(oldRep)
            log.debug("Updated bwd history to: ", self.bwd_history)
        else
            self.fwd_history:push(oldRep)
            log.debug("Updated bwd history to: ", self.bwd_history)
        end
        return true
    end
end

function QueueBase:forward_history()
    if not self:navigate_history(true) then
        sounds.play("negative")
    else
        sounds.play("click1")
    end
end

function QueueBase:backward_history()
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

function QueueBase:dismiss() self.reptable:dismiss_current() end

-- TODO: add oldRep to the backward history stack
function QueueBase:loadRep(newRep, oldRep)
    if player.play(newRep, oldRep, self.createLoopBoundaries) then
        self.playing = newRep
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
