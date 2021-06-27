local Base = require("queue.queueBase")
local EDL = require("systems.edl")
local sounds = require("systems.sounds")
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

function ItemQueueBase:adjust_cloze(adjustment_fn)
    mp.set_property("pause", "yes")
    local cur = self:get_current()
    local edl = EDL.new(cur["url"])
    edl:load()

    local cloze_start = edl.data["cloze"]["start"]
    local cloze_end = edl.data["cloze"]["stop"]

    adjustment_fn(edl)

    local adj_cloze_start = edl.data["cloze"]["start"]
    local adj_cloze_end = edl.data["cloze"]["stop"]

    local start_changed = cloze_start ~= adj_cloze_start
    local end_changed = cloze_end ~= adj_cloze_end

    edl:write()

    -- reload

    if start_changed then
        local start = tostring(tonumber(adj_cloze_start) - 0.5) -- TODO > 0
        mp.commandv("loadfile", cur["url"], "replace", "start=" .. start)
    elseif end_changed then
        local start = tostring(tonumber(adj_cloze_end)) -- TODO > 0
        mp.commandv("loadfile", cur["url"], "replace", "start=" .. start)
    end
    mp.set_property("pause", "no")
    sounds.play("click1")
end

function ItemQueueBase:advance_start()
    local adj = 0.02
    local duration = tonumber(mp.get_property("duration"))

    local function adjustment_fn(edl)
        local beg_stop = tonumber(edl.data["beg"]["stop"]) - adj
        local cloze_stop = tonumber(edl.data["cloze"]["stop"]) + adj
        local beg_valid = beg_stop > 0 and beg_stop < duration
        local cloze_valid = cloze_stop > 0 and cloze_stop < duration
        if cloze_valid and beg_valid then
            edl.data["beg"]["stop"] = tostring(beg_stop)
            edl.data["cloze"]["stop"] = tostring(cloze_stop)
        end
    end

    self:adjust_cloze(adjustment_fn)
end

function ItemQueueBase:postpone_start()
    local adj = 0.02
    local duration = tonumber(mp.get_property("duration"))

    local function adjustment_fn(edl)
        local beg_stop = tonumber(edl.data["beg"]["stop"]) + adj
        local cloze_start = tonumber(edl.data["cloze"]["start"]) + adj
        local beg_valid = beg_stop > 0 and beg_stop < duration
        local cloze_valid = cloze_start > 0 and cloze_start < duration

        if cloze_valid and beg_valid then
            edl.data["beg"]["stop"] = tostring(beg_stop)
            edl.data["cloze"]["start"] = tostring(cloze_start)
        end
    end
    self:adjust_cloze(adjustment_fn)
end

function ItemQueueBase:advance_stop()
    local adj = 0.02
    local duration = tonumber(mp.get_property("duration"))

    local function adjustment_fn(edl)
        local cloze_stop = tonumber(edl.data["beg"]["stop"]) - adj
        local ending_start = tonumber(edl.data["ending"]["start"]) - adj

        local cloze_valid = cloze_stop > 0 and cloze_stop < duration
        local ending_valid = ending_start > 0 and ending_start < duration

        if cloze_valid and ending_valid then
            edl.data["cloze"]["stop"] = tostring(cloze_stop)
            edl.data["ending"]["start"] = tostring(ending_start)
        end
    end
    self:adjust_cloze(adjustment_fn)
end

function ItemQueueBase:postpone_stop()
    local adj = 0.02
    local duration = tonumber(mp.get_property("duration"))

    local function adjustment_fn(edl)
        local cloze_stop = tonumber(edl.data["cloze"]["stop"]) + adj
        local ending_start = tonumber(edl.data["ending"]["start"]) + adj

        local cloze_valid = cloze_stop > 0 and cloze_stop < duration
        local ending_valid = ending_start > 0 and ending_start < duration

        if cloze_valid and ending_valid then
            edl.data["cloze"]["stop"] = tostring(cloze_stop)
            edl.data["ending"]["start"] = tostring(ending_start)
        end
    end

    self:adjust_cloze(adjustment_fn)
end

return ItemQueueBase