local Base = require("queue.queueBase")
local player = require("systems.player")
local sounds = require("systems.sounds")
local ext = require("utils.ext")
local ItemRepTable = require("reps.reptable.unscheduledItems")
local log = require("utils.log")
local mpu = require("mp.utils")
local fs = require("systems.fs")
local ydl = require("systems.ydl")
local ffmpeg = require("systems.ffmpeg")
local active = require("systems.active")

local LocalTopicQueue
local LocalItemQueue

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

function ExtractQueueBase:adjust_extract(start, stop)
    local curRep = self.playing
    if not curRep then
        log.debug("Failed to adjust extract because currently playing is nil")
        sounds.play("negative")
        return
    end

    local duration = tonumber(mp.get_property("duration"))
    if start < 0 or start > duration or stop < 0 or stop > duration then
        log.err("Failed to adjust extract because start stop invalid")
        return
    end

    local start_changed = curRep.row["start"] ~= tostring(start)
    local stop_changed = curRep.row["stop"] ~= tostring(stop)

    curRep.row["start"] = tostring(start)
    curRep.row["stop"] = tostring(stop)

    -- update loop timer
    player.loop_timer.set_start_time(tonumber(curRep.row["start"]))
    player.loop_timer.set_stop_time(tonumber(curRep.row["stop"]))

    if start_changed then
        mp.commandv("seek", curRep.row["start"], "absolute")
    elseif stop_changed then
        mp.commandv("seek", tostring(tonumber(curRep.row["stop"]) - 1),
                    "absolute") -- TODO: > 0
    end

    log.debug(
        "Updated extract boundaries to " .. curRep.row["start"] .. " -> " ..
            curRep.row["stop"])
end

function ExtractQueueBase:save_data()
    self.reptable:write(self.reptable)
end

function ExtractQueueBase:advance_start()
    local adj = 0.1
    local curRep = self.playing
    local start = tonumber(curRep.row["start"]) - adj
    local stop = tonumber(curRep.row["stop"])
    self:adjust_extract(start, stop)
end

function ExtractQueueBase:advance_stop()
    local adj = 0.1
    local curRep = self.playing
    local start = tonumber(curRep.row["start"])
    local stop = tonumber(curRep.row["stop"]) - adj
    self:adjust_extract(start, stop)
end

function ExtractQueueBase:postpone_start()
    local adj = 0.1
    local curRep = self.playing
    local start = tonumber(curRep.row["start"]) + adj
    local stop = tonumber(curRep.row["stop"])
    self:adjust_extract(start, stop)
end

function ExtractQueueBase:postpone_stop()
    local adj = 0.1
    local curRep = self.playing
    local start = tonumber(curRep.row["start"])
    local stop = tonumber(curRep.row["stop"]) + adj
    self:adjust_extract(start, stop)
end

function ExtractQueueBase:create_item(fname, extension, start, stop, curRep)
    ItemRepTable():add_rep(item)
    sounds.play("echo")
    mp.commandv("script-message", "extracted", self.name)
    player.unset_abloop()
end

-- TODO: What about local
-- TODO: refactor
function ExtractQueueBase:handle_extract(start, stop, curRep)
    if curRep == nil then
        log.debug("Failed to extract because current rep was nil.")
        return
    end

    self:create_item(fname, extension, start, stop, curRep)
end

return ExtractQueueBase