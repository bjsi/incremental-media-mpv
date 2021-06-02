local Base = require("queue.base")
local player = require("systems.player")
local sounds = require("systems.sounds")
local ext = require("utils.ext")
local TopicRepTable = require("reps.reptable.topics")
local ItemRepTable = require("rep.reptable.items")
local sys = require("systems.system")
local log = require("utils.log")
local mpu = require("mp.utils")
local fs = require("systems.fs")
require("queue.header")

ExtractQueue.__index = ExtractQueue

setmetatable(ExtractQueue, {
    __index = Base, -- this is what makes the inheritance work
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end,
})

function ExtractQueue:_init(oldRep, extractRepTable)
    Base._init(self, "Extract Queue", extractRepTable)
    self:load(oldRep)
    sounds.play("local_extract_queue")
end

function ExtractQueue:handle_backward()
    self:stutter_backward()
end

function ExtractQueue:handle_forward()
    self:stutter_forward()
end

function ExtractQueue:child()
    local curRep = self:get_current()
    if curRep == nil then
        log.debug("Failed to load child queue because current rep is nil.")
        return false
    end

    local itemRepTable = ItemRepTable()
    if ext.list_empty(itemRepTable.reps) then
        log.debug("No children available for extract: " .. curRep.row["title"])
        return false
    end

    self:change_queue(ItemQueue(curRep, itemRepTable))
    return true
end

function ExtractQueue:parent()
    local curRep = self:get_current()
    if curRep == nil then
        log.debug("Failed to load parent queue because current rep is nil.")
        return false
    end

    local topicTable = TopicRepTable()
    self:change_queue(TopicQueue(curRep, topicTable))
end

function ExtractQueue:adjust_extract(start, stop)
    local curRep = self:get_current()
    local duration = tonumber(mp.get_property("duration"))
    if start < 0 or start > duration or stop < 0 or stop > duration
        then return end

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
        mp.commandv("seek", tostring(tonumber(curRep.row["stop"]) - 1), "absolute") -- TODO: > 0
    end

    log.debug("Updated extract boundaries to " .. curRep.row["start"] .. " -> " .. curRep.row["stop"])
end

function ExtractQueue:advance_start()
    local adj = 0.1
    local curRep = self:get_current()
    local start = tonumber(curRep.row["start"]) - adj
    local stop = tonumber(curRep.row["stop"])
    self:adjust_extract(start, stop)
end

function ExtractQueue:advance_stop()
    local adj = 0.1
    local curRep = self:get_current()
    local start = tonumber(curRep.row["start"])
    local stop = tonumber(curRep.row["stop"]) - adj
    self:adjust_extract(start, stop)
end

function ExtractQueue:postpone_start()
    local adj = 0.1
    local curRep = self:get_current()
    local start = tonumber(curRep.row["start"]) + adj
    local stop = tonumber(curRep.row["stop"])
    self:adjust_extract(start, stop)
end

function ExtractQueue:postpone_stop()
    local adj = 0.1
    local curRep = self:get_current()
    local start = tonumber(curRep.row["start"])
    local stop = tonumber(curRep.row["stop"]) + adj
    self:adjust_extract(start, stop)
end

function ExtractQueue:handle_extract(start, stop, curRep)
    local url = curRep.row["url"]
    if curRep:is_yt() then
        local args = {
            "youtube-dl",
            "-f", "worstaudio",
            "--youtube-skip-dash-manifest",
            "-g", url
        }
        local ret = sys.subprocess(args)
        if ret.status == 0 then
            local lines = ret.stdout
            local matches = lines:gmatch("([^\n]*)\n?")
            url = matches()
            log.debug("Found audio stream: " .. url)
        else
            log.debug("Failed to get audio stream.")
            return false
        end
    end

    start = start - tonumber(curRep.row["start"])
    stop = stop - tonumber(curRep.row["start"])

    local extension = ".wav"
    local fname = tostring(os.time(os.date("!*t"))) .. "-aa"
    local extract = mpu.join_path(fs.media, fname .. extension)

    local args = {
        "ffmpeg",
        -- "-hide_banner",
        "-nostats",
        -- "-loglevel", "fatal",
        "-ss", tostring(curRep.row["start"]),
        "-to", tostring(curRep.row["stop"]),
        "-i", url, -- extract audio stream
        extract
    }

    local completion_fn = function()

        local cloze = "sine.opus"
        local edl = mpu.join_path(fs.media, fname .. ".edl")
        local id = tostring(#db.items.csv_table + 1)

        -- Create virtual file using EDL
        local handle = io.open(edl, "w")
        handle:write("# mpv EDL v0\n")
        handle:write(fname .. extension .. ",0," .. tostring(start) .. "\n")
        handle:write(cloze .. ",0," .. tostring(stop - start) .. "\n")
        handle:write(fname .. extension .. "," .. tostring(stop) .. "," .. tostring(tonumber(curRep.row["stop"]) - tonumber(curRep.row["start"]) - stop) .. "\n")
        handle:close()

        local item = {
            id = id,
            parent = curRep["id"],
            url = edl,
            priority = curRep["priority"]
        }

        db.items:add(item)
        sounds.play("echo")
        mp.commandv("script-message", "extracted", self.name)
        mp.set_property("ab-loop-a", "no")
        mp.set_property("ab-loop-b", "no")
    end

    sys.background_process(args, completion_fn)

end

return ExtractQueue
