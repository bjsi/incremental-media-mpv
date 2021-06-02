local sounds = require("systems.sounds")
local log = require("utils.log")
local player = require("systems.player")

local Queue = {}
Queue.__index = Queue

-- TODO: Save a history of previously visited elements excluding dismissed
setmetatable(Queue, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end,
})

function Queue:_init(name, reptable)
    log.debug("Loading: " .. name)
    self.name = name
    self.reptable = reptable
end

function Queue:reload()
    local reptable = self.reptable.db:read()
    if reptable == nil then
        log.err("Failed to reload the rep table!")
        return false
    end

    self.reptable = reptable
    log.debug("Reloaded the rep table.")
    return true
end

function Queue:extract()
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
    local curRep = self.reptable:current()
    self:handle_extract(start, stop, curRep)
end

function Queue:toggle_video()
    player.toggle_vid()
end

function Queue:toggle()
    player.toggle()
end

function Queue:loop()
    player.loop()
end

function Queue:stutter_forward()
    player.stutter_forward()
end

function Queue:stutter_backward()
    player.stutter_backward()
end

function Queue:dismiss()
    self.reptable:dismiss_current()
end

-- old can be nil
function Queue:load(oldRep)
    local newRep = self.reptable:current()

    -- set start, stop
    local start = newRep.row["curtime"] ~= nil and newRep.row["curtime"] or newRep.row["start"]
    if start == nil then start = 0 end
    local stop = newRep.row["stop"] ~= nil and newRep.row["stop"] or -1
    start = tonumber(start)
    stop = tonumber(stop)

    -- seek if old and new have the same url
    if oldRep ~= nil and oldRep.row["url"] == newRep.row["url"] then
        log.debug("New element has the same url: seeking")
        mp.commandv("seek", tostring(start), "absolute")

    -- load file if old and new have different urls
    else
        log.debug("New element has a different url: loading new file")
        mp.commandv("loadfile", newRep.row["url"], "replace", "start=" .. tostring(start))
    end

    if newRep.row["speed"] ~= nil then
        mp.set_property("speed", newRep.row["speed"])
    else
        mp.set_property("speed", "1")
    end

    -- reset loops and timers
    player.unset_abloop()
    player.pause_timer.stop()

    -- TODO: Get rid of this?
    mp.commandv("script-message", "element_changed", self.name, tostring(start), tostring(stop))
end

function Queue:next_repetition()
    local nextRep = self.reptable:next_repetition()
    if not nextRep then return end
end

function Queue:forward()
    mp.commandv("seek", "+5")
end

function Queue:backward()
    mp.commandv("seek", "-5")
end

function Queue:child()
    sounds.play("negative")
    log.debug("No child element available.")
end

function Queue:parent()
    sounds.play("negative")
    log.debug("No parent element available.")
end

function Queue:save_data()
    self.reptable:write(self.reps)
end

-- TODO: Write to db?
function Queue:change_queue(db, predicate, current)
    local repTable = db.rows
    self:save_data()
end

return Queue
