local sounds = require("systems.sounds")
local log = require("utils.log")
local player = require("systems.player")
local Stack = require("queue.stack")

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
end

-- TODO: Change name to learn
function QueueBase:next_repetition()
    local playing = self.playing
    local toLoad = self.reptable:next_repetition()
    if not toLoad then return end
    self:loadRep(toLoad, playing)
end

-- TODO
function QueueBase:forward_history()
    local new = nil
    self.playing = new
end

-- TODO
function QueueBase:backward_history()
    local new = nil
    self.playing = new
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

function QueueBase:loadRep(newRep, oldRep)
    player.play(newRep, oldRep)
    self.playing = newRep
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
