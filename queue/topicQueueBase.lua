local sounds = require("systems.sounds")
local player = require("systems.player")
local log = require("utils.log")
local active = require("systems.active")
local Base = require("queue.queueBase")
local ext = require("utils.ext")
local TopicRepTable = require("reps.reptable.topics")
local repCreators = require("reps.rep.repCreators")
local ExtractRepTable = require("reps.reptable.extracts")

local LocalExtractQueue

local TopicQueueBase = {}
TopicQueueBase.__index = TopicQueueBase

setmetatable(TopicQueueBase, {
    __index = Base,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

--- Create a new TopicQueueBase
--- @param oldRep Rep Last playing Rep object.
--- @param subsetter function Subset creator function.
function TopicQueueBase:_init(name, oldRep, subsetter)
    Base._init(self, name, TopicRepTable(subsetter), oldRep)
    self.createLoopBoundaries = false -- allow seeking behind curtime
end

function TopicQueueBase:activate()
    self:subscribe_to_events()
    return Base.activate(self)
end

local function on_time_changed(_, time) active.queue:update_curtime(time) end

function TopicQueueBase:subscribe_to_events()
    log.debug("Subscribing to time changed event.")
    mp.observe_property("time-pos", "number", on_time_changed)
end

function TopicQueueBase:clean_up_events()
    log.debug("Cleaning up events.")
    mp.unobserve_property(on_time_changed)
end

-- TODO: check self.playing == actual current playing file
function TopicQueueBase:update_curtime(time)
    if not time then return end
    self.playing.row["curtime"] = tostring(ext.round(time, 2))
end

-- TODO: check self.playing == actual current playing file
function TopicQueueBase:update_speed()
    local speed = mp.get_property_number("speed")
    if not speed then return end
    self.playing.row["speed"] = ext.round(speed, 2)
end

function TopicQueueBase:handle_forward()
    if player.paused() then
        self:stutter_forward()
    else
        self:forward()
    end
end

function TopicQueueBase:handle_backward()
    if player.paused() then
        self:stutter_backward()
    else
        self:backward()
    end
end

function TopicQueueBase:handle_extract(start, stop, curRep)
    if curRep == nil then
        log.err("Failed to extract because current rep was nil.")
        return
    end

    local extract = repCreators.createExtract(curRep, start, stop)
    if not extract then
        log.err("Failed to handle extract.")
        return
    end

    local ert = ExtractRepTable(function(r) return r end)
    if ert:add_to_reps(extract) then
        sounds.play("echo")
        player.unset_abloop()
        ert:write()
    else
        sounds.play("negative")
        log.err("Failed to create extract")
    end
end

function TopicQueueBase:child()
    local cur = self.playing
    if cur == nil then
        log.debug("Failed to load child queue because current rep is nil.")
        return false
    end

    LocalExtractQueue = LocalExtractQueue or require("queue.localExtractQueue")
    local extractQueue = LocalExtractQueue(cur)
    if ext.empty(extractQueue.reptable.subset) then
        log.debug("No children available for topic: " .. cur.row["title"])
        sounds.play("negative")
        return false
    end

    self:clean_up_events()
    active.change_queue(extractQueue)
    return true
end

function TopicQueueBase:save_data()
    self:update_speed()
    self.reptable:write(self.reptable)
end

return TopicQueueBase
