local Base = require("queue.queueBase")
local repCreators = require("reps.rep.repCreators")
local player = require("systems.player")
local sounds = require("systems.sounds")
local ext = require("utils.ext")
local log = require("utils.log")
local active = require("systems.active")

local LocalTopicQueue
local LocalItemQueue
local GlobalItemQueue

local ExtractQueueBase = {}
ExtractQueueBase.__index = ExtractQueueBase


setmetatable(ExtractQueueBase, {
    __index = Base, -- this is what makes the inheritance work
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function ExtractQueueBase:_init(name, oldRep, repTable)
    Base._init(self, name, repTable, oldRep)
end

function ExtractQueueBase:handle_backward() self:stutter_backward() end

function ExtractQueueBase:handle_forward() self:stutter_forward() end

function ExtractQueueBase:child()
    local curRep = self.reptable:current_scheduled()
    if curRep == nil then
        log.debug("Failed to load child queue because current rep is nil.")
        return false
    end

    LocalItemQueue = LocalItemQueue or require("queue.localItemQueue")
    local queue = LocalItemQueue(self.playing)
    if ext.empty(queue.reptable.subset) then
        log.debug("No children available for extract: " .. curRep.row["title"])
        sounds.play("negative")
        return false
    end

    active.change_queue(queue)
    return true
end

function ExtractQueueBase:parent()
    local cur = self.playing
    if cur == nil then
        log.debug("Failed to load parent queue because current rep is nil.")
        return false
    end

    LocalTopicQueue = LocalTopicQueue or require("queue.localTopicQueue")
    local queue = LocalTopicQueue(self.playing)
    active.change_queue(queue)
end

function ExtractQueueBase:adjust_extract(postpone, start)
    local curRep = self.playing
    if not curRep then
        log.debug("Failed to adjust extract because currently playing is nil")
        sounds.play("negative")
        return
    end

    local adj = postpone and 0.1 or -0.1
    local oldStart = tonumber(curRep.row["start"])
    local oldStop = tonumber(curRep.row["stop"])
    local newStart = start and oldStart + adj or oldStart
    local newStop = start and oldStop or oldStop + adj

    local duration = tonumber(mp.get_property("duration"))
    if newStart < 0 or newStart > duration or newStop < 0 or newStop > duration then
        log.err("Failed to adjust extract because start stop invalid")
        sounds.play("negative")
        return
    end

    local start_changed = oldStart ~= newStart
    local stop_changed = oldStop ~= newStop

    curRep.row["start"] = newStart
    curRep.row["stop"] = newStop

    -- update loop timer
    player.loop_timer.set_start_time(newStart)
    player.loop_timer.set_stop_time(newStop)

    if start_changed then
        mp.commandv("seek", tostring(newStart), "absolute")
    elseif stop_changed then
        mp.commandv("seek", tostring(newStop - 1), "absolute")
    end

    log.debug(
        "Updated extract boundaries to " .. curRep.row["start"] .. " -> " ..
            curRep.row["stop"])
end

function ExtractQueueBase:save_data()
    self.reptable:write(self.reptable)
end

function ExtractQueueBase:advance_start()
    local a = mp.get_property("ab-loop-a")
    local b = mp.get_property("ab-loop-b")
    if self:validate_abloop(a, b) then
        Base.advance_start(self)
    else
        self:adjust_extract(false, true)
    end
end

function ExtractQueueBase:advance_stop()
    local a = mp.get_property("ab-loop-a")
    local b = mp.get_property("ab-loop-b")
    if self:validate_abloop(a, b) then
        Base.advance_start(self)
    else
        self:adjust_extract(false, false)
    end
end

function ExtractQueueBase:postpone_start()
    local a = mp.get_property("ab-loop-a")
    local b = mp.get_property("ab-loop-b")
    if self:validate_abloop(a, b) then
        Base.advance_start(self)
    else
        self:adjust_extract(true, true)
    end
end

function ExtractQueueBase:postpone_stop()
    local a = mp.get_property("ab-loop-a")
    local b = mp.get_property("ab-loop-b")
    if self:validate_abloop(a, b) then
        Base.advance_start(self)
    else
        self:adjust_extract(true, false)
    end
end

function ExtractQueueBase:handle_extract(start, stop, curRep)
    if curRep == nil then
        log.debug("Failed to extract because current rep was nil.")
        return false
    end

    if not start or not stop or (start > stop) then 
        log.err("Invalid extract boundaries.")
        return false
    end

    local item = repCreators.createItem(curRep, start, stop)
    if ext.empty(item) then
        return false
    end

    GlobalItemQueue = GlobalItemQueue or require("queue.globalItemQueue")
    local irt = GlobalItemQueue(nil).reptable
    if irt:add_to_reps(item) then
        sounds.play("echo")
        player.unset_abloop()
        irt:write()
    else
        sounds.play("negative")
        log.err("Failed to add item to the rep table.")
    end
end

return ExtractQueueBase