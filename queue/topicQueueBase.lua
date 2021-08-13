local sounds = require("systems.sounds")
local player = require("systems.player")
local log = require("utils.log")
local active = require("systems.active")
local Base = require("queue.queueBase")
local ext = require("utils.ext")
local TopicRepTable = require("reps.reptable.topics")
local repCreators = require("reps.rep.repCreators")
local ydl = require "systems.ydl"
local importer = require "systems.importer"
local subs = require("systems.subs.subs")

local GlobalExtractQueue
local GlobalItemQueue
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
    self.bigSeek = 10
    self.smallSeek = 2
end

function TopicQueueBase:localize(video)
    local cur = self.playing
    if not cur or cur:is_local() then return end
    local url = cur.row["url"]
    local file = video and ydl.download_video(url) or ydl.download_audio(url)
    if not file then
        log.debug("Failed to download locally.")
        sounds.play("negative")
        return
    end

    -- Update url, type for topic and for child extracts
    cur.row["url"] = file
    cur.row["type"] = "local"

    LocalExtractQueue = LocalExtractQueue or require("queue.localExtractQueue")
    local leq = LocalExtractQueue(cur)
    local saved
    for _, extract in ipairs(leq.reptable.subset) do
        saved = true
        extract.row["url"] = file
        extract.row["type"] = "local"
    end
    
    self:save_data()
    if saved then
        leq:save_data()
    end

    -- Reload the current file
    self:loadRep(cur, nil)
end

function TopicQueueBase:localize_video()
    self:localize(true)
end

function TopicQueueBase:localize_audio()
    self:localize(false)
end

function TopicQueueBase:load_grand_queue()
    local topicParent = self.playing
    if not topicParent then
        log.debug("Failed to load grandchild queue because currently playing is nil.")
        return
    end

    LocalExtractQueue = LocalExtractQueue or require("queue.globalExtractQueue")
    local leq = LocalExtractQueue(topicParent)
    local extractReps = leq.reptable.reps
    local extractParentIds = ext.list_map(extractReps, function(r) return r.row["id"] end)
    if ext.empty(extractParentIds) then
        log.debug("No available grandchild repetitions.")
        return
    end

    local GlobalItemQueue = GlobalItemQueue or require("queue.globalItemQueue")
    local giq = GlobalItemQueue(nil)
    local itemReps = giq.reptable.reps
    local isGrandChild = function(r)
        return ext.list_contains(extractParentIds, r.row["parent"])
    end
    local grandChildren = ext.list_filter(itemReps, isGrandChild)
    if ext.empty(grandChildren) then
        log.debug("No available grandchild repetitions.")
    end

    giq.reptable.subset = grandChildren
    self:clean_up_events()
    active.change_queue(giq)
end

function TopicQueueBase:activate()
    if Base.activate(self) then
        player.on_overrun = function() self:next_repetition() end
        return true
    end
    return false
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
    if not self.playing then return end
    self.playing.row["curtime"] = tostring(ext.round(time, 2))
end

function TopicQueueBase:split_chapters()
    local cur = self.playing
    if cur == nil or not cur:type() == "topic" then
        log.err("Failed to split chapters because cur is nil or not topic.")
        sounds.play("negative")
        return
    end

    local info = ydl.get_info(cur.row["url"])
    if ext.empty(info) or ext.empty(info["chapters"]) then
        log.debug("Failed to get vid info or chapters.")
        sounds.play("negative")
        return
    end

    -- if importer.split_and_import_chapters() then
end

function TopicQueueBase:handle_extract(start, stop, curRep)
    if curRep == nil then
        log.err("Failed to extract because current rep was nil.")
        return false
    end

    local sub = subs.get()
    local subText = sub and sub.text or ""

    local extract = repCreators.createExtract(curRep, start, stop, subText)
    if not extract then
        log.err("Failed to handle extract.")
        return false
    end

    GlobalExtractQueue = GlobalExtractQueue or require("queue.globalExtractQueue")
    local geq = GlobalExtractQueue(nil)
    if geq.reptable:add_to_reps(extract) then
        sounds.play("echo")
        player.unset_abloop()
        subs.clear()
        geq:save_data()
        return true
    else
        sounds.play("negative")
        log.err("Failed to create extract")
        return false
    end
end

function TopicQueueBase:to_export()
    sounds.play("negative")
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
    return self.reptable:write(self.reptable)
end

return TopicQueueBase
