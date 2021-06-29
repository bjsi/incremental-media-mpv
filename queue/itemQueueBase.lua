local Base = require("queue.queueBase")
local player = require("systems.player")
local EDL = require("systems.edl")
local log = require("utils.log")
local active = require("systems.active")
local UnscheduledItemRepTable = require("reps.reptable.unscheduledItems")

local LocalExtractQueue

local ItemQueueBase = {}
ItemQueueBase.__index = ItemQueueBase

setmetatable(ItemQueueBase, {
    __index = Base, -- this is what makes the inheritance work
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function ItemQueueBase:_init(name, oldRep, subsetter)
    Base._init(self, name, UnscheduledItemRepTable(subsetter), oldRep)
end

function ItemQueueBase:handle_backward() self:stutter_backward() end

function ItemQueueBase:handle_forward() self:stutter_forward() end

function ItemQueueBase:parent()
    local cur = self.playing
    if cur == nil then
        log.debug("Failed to load parent queue because current rep is nil.")
        return false
    end

    LocalExtractQueue = LocalExtractQueue or require("queue.localExtractQueue")
    local queue = LocalExtractQueue(self.playing)
    active.change_queue(queue)
end

function ItemQueueBase:save_data()
    self.reptable:write(self.reptable)
end

function ItemQueueBase:adjust_cloze(postpone, start)
    local cur = self.playing
    if cur == nil then 
        log.err("Failed to adjust cloze because current rep is nil.")
        return
    end

    mp.set_property("pause", "yes")
    local newStart, newStop = EDL.new(cur.row["url"]):adjust_cloze(postpone, start)
    if newStart == nil or newStop == nil then
        log.err("Failed to adjust cloze.")
        return
    end

    player.unset_abloop()
    player.pause_timer.stop()

    -- TODO: validate

    if start then
        mp.commandv("loadfile", cur.row["url"], "replace", "start=" .. tostring(newStart - 0.4))
    else 
        mp.commandv("loadfile", cur.row["url"], "replace", "start=" .. tostring(newStop - 0.05))
    end

    log.debug("Cloze boundaries updated to: " .. tostring(newStart) .. " -> " .. tostring(newStop))
    player.loop_timer.set_start_time(0)
    player.loop_timer.set_stop_time(-1)
    mp.set_property("pause", "no")
end

function ItemQueueBase:advance_start()
    self:adjust_cloze(false, true)
end

function ItemQueueBase:postpone_start()
    self:adjust_cloze(true, true)
end

function ItemQueueBase:advance_stop()
    self:adjust_cloze(false, false)
end

function ItemQueueBase:postpone_stop()
    self:adjust_cloze(true, false)
end

return ItemQueueBase