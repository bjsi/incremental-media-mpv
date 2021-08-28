local sounds = require 'systems.sounds'
local player = require 'systems.player'
local log = require 'utils.log'
local active = require 'systems.active'
local QueueBase = require 'queues.base.base'
local TopicRepTable = require 'reps.reptable.topics'
local repCreators = require 'reps.rep.repCreators'
local ydl = require 'systems.ydl'
local subs = require 'systems.subs.subs'
local obj = require 'utils.object'
local mp = require 'mp'
local tbl = require 'utils.table'
local num = require 'utils.number'

local GlobalExtracts
local GlobalItems
local LocalExtracts

local TopicQueueBase = {}
TopicQueueBase.__index = TopicQueueBase

setmetatable(TopicQueueBase, {
    __index = QueueBase,
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
    QueueBase._init(self, name, TopicRepTable(subsetter), oldRep)
    self.createLoopBoundaries = false -- allow seeking behind curtime
end

function TopicQueueBase:localize(video)
    local cur = self.playing
    if not cur or cur:is_local() then return end
    local url = cur.row.url
    local file = video and ydl.download_video(url) or ydl.download_audio(url)
    if not file then
        log.debug("Failed to download locally.")
        sounds.play("negative")
        return
    end

    -- Update url, type for topic and for child extracts
    cur.row["url"] = file
    cur.row["type"] = "local"

    LocalExtracts = LocalExtracts or require("queues.local.extracts")
    local extracts = LocalExtracts(cur)
    local saved
    for _, extract in ipairs(extracts.reptable.subset) do
        saved = true
        extract.row["url"] = file
        extract.row["type"] = "local"
    end

    self:save_data()
    if saved then extracts:save_data() end

    -- Reload the current file
    self:loadRep(cur, nil)
end

function TopicQueueBase:localize_video() self:localize(true) end

function TopicQueueBase:localize_audio() self:localize(false) end

function TopicQueueBase:load_grand_queue()
    local topicParent = self.playing
    if not topicParent then
        log.debug(
            "Failed to load grandchild queue because currently playing is nil.")
        return
    end

    LocalExtracts = LocalExtracts or require("queues.global.extracts")
    local extracts = LocalExtracts(topicParent)
    local extract_reps = extracts.reptable.reps
    local mapper = function(r) return r.row["id"] end
    local extractParentIds = tbl.map(extract_reps, mapper)
    if obj.empty(extractParentIds) then
        log.debug("No available grandchild repetitions.")
        return
    end

    GlobalItems = GlobalItems or require("queues.global.items")
    local items = GlobalItems(nil)
    local itemReps = items.reptable.reps
    local isGrandChild = function(r)
        return tbl.contains(extractParentIds, r.row["parent"])
    end
    local grandChildren = tbl.filter(itemReps, isGrandChild)
    if obj.empty(grandChildren) then
        log.debug("No available grandchild repetitions.")
    end

    items.reptable.subset = grandChildren
    self:clean_up_events()
    active.change_queue(items)
end

function TopicQueueBase:activate()
    if QueueBase.activate(self) then
        player.on_overrun = function() self:learn() end
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
    self.playing.row["curtime"] = tostring(num.round(time, 2))
end

function TopicQueueBase:split_chapters()
    local cur = self.playing
    if cur == nil or not cur:type() == "topic" then
        log.err("Failed to split chapters because cur is nil or not topic.")
        sounds.play("negative")
        return
    end

    local info = ydl.get_info(cur.row["url"])
    if obj.empty(info) or obj.empty(info["chapters"]) then
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

    GlobalExtracts = GlobalExtracts or require("queues.global.extracts")
    local geq = GlobalExtracts(nil)
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

function TopicQueueBase:to_export() sounds.play("negative") end

function TopicQueueBase:child()
    local cur = self.playing
    if cur == nil then
        log.debug("Failed to load child queue because current rep is nil.")
        return false
    end

    LocalExtracts = LocalExtracts or require("queues.local.extracts")
    local extractQueue = LocalExtracts(cur)
    if obj.empty(extractQueue.reptable.subset) then
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
