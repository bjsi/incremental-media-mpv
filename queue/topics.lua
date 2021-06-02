local sounds = require("systems.sounds")
local player = require("systems.player")
local log = require("utils.log")
local Queue = require("queue.base")
local ext = require("utils.ext")
require("queue.header")

TopicQueue.__index = TopicQueue

setmetatable(TopicQueue, {
    __index = Queue,
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end,
})

--- Create a new TopicQueue
-- @param old: The last playing Rep object.
-- @param topics: Topics RepTable object.
function TopicQueue:_init(oldRep, topicRepTable)
    Queue._init(self, "Global Topic Queue", topicRepTable)
    self:load(oldRep)
    sounds.play("global_topic_queue")
end

function TopicQueue:update_curtime()
    local cur = self:get_current()
    if cur == nil then return end
    local time = mp.get_property("time-pos")
    if not time then return end
    cur.row["curtime"] = time
end

function TopicQueue:update_speed()
    local cur = self:get_current()
    local speed = mp.get_property("speed")
    if speed == nil then return end
    cur.row["speed"] = speed
end

function TopicQueue:handle_forward()
    if player.paused() then
        self:stutter_forward()
    else
        self:forward()
    end
end

function TopicQueue:handle_backward()
    if player.paused() then
        self:stutter_backward()
    else
        self:backward()
    end
end

function TopicQueue:handle_extract(start, stop, cur)
    local extract = {
        title = cur.row["title"],
        type = cur.row["type"],
        url = cur.row["url"],
        element = "extract",
        start = tostring(start),
        stop = tostring(stop),
        curtime = tostring(start),
        priority = cur.row["priority"],
        interval = "1",
        nextrep = "1970-01-01",
        speed = 1,
    }

    self.db:add_row(extract)
    sounds.play("echo")
    mp.commandv("script-message", "extracted", self.name) -- TODO: Remove
    player.unset_abloop()
end

function TopicQueue:child()
    local cur = self:get_current()
    if cur == nil then
        log.debug("Failed to load child queue because current rep is nil.")
        return false
    end

    -- TODO: Create a reptable
    local extracts = self.db:get_extracts()
    local children = ext.list_filter(extracts)
    if ext.list_empty(children) then
        log.debug("No children available for topic: " .. cur.row["title"])
        return false
    end

    self:change_queue(ExtractQueue(cur, children))
    return true
end

return TopicQueue
