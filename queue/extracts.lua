local QueueBase = require("queue.base")
local sounds = require("systems.sounds")
local ext = require("utils.ext")
local GlobalTopicQueue = require("queue.topics")
local ItemQueue = require("queue.items")
local sys = require("systems.system")

local ExtractQueue = {}
ExtractQueue.__index = ExtractQueue

setmetatable(ExtractQueue, {
    __index = QueueBase, -- this is what makes the inheritance work
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end,
})

function ExtractQueue:_init(old, extracts)
    QueueBase._init(self, extracts, "Extract Queue")
    self:load(old, self.items[self.cur_idx])
    sounds.play("local_extract_queue")
end

function ExtractQueue:handle_backward()
    self:stutter_backward()
end

function ExtractQueue:handle_forward()
    self:stutter_forward()
end

function ExtractQueue:child()
    local cur = self:get_current()
    local is_child_of_cur = curry2(is_parent)(cur)
    self:change_queue(db.items, is_child_of_cur, function(x) return ItemQueue(x) end)
end

function ExtractQueue:parent()
    local cur = self:get_current()
    local creator_fn = function(topics)
        local is_parent_of_cur = curry2(is_child)(cur)
        ext.move_to_first_where(is_parent_of_cur, topics)
        return GlobalTopicQueue(cur, topics)
    end
    self:change_queue(db.topics, is_outstanding, creator_fn)
end

function ExtractQueue:adjust_extract(start, stop)
    local cur = self:get_current()
    local duration = tonumber(mp.get_property("duration"))
    if start < 0 or start > duration or stop < 0 or stop > duration
        then return end

    local start_changed = cur["start"] ~= tostring(start)
    local stop_changed = cur["stop"] ~= tostring(stop)

    cur["start"] = tostring(start)
    cur["stop"] = tostring(stop)
    db.extracts:set_by_id(cur["id"], cur)

    -- update loop timer
    loop_timer.set_start_time(tonumber(cur["start"]))
    loop_timer.set_stop_time(tonumber(cur["stop"]))

    if start_changed then
        mp.commandv("seek", cur["start"], "absolute")
    elseif stop_changed then
        mp.commandv("seek", tostring(tonumber(cur["stop"]) - 1), "absolute") -- TODO: > 0
    end

    msg.info("Updated extract boundaries to " .. cur["start"] .. " -> " .. cur["stop"])
end

function ExtractQueue:advance_start()
    local adj = 0.1
    local cur = self:get_current()
    local start = tonumber(cur["start"]) - adj
    local stop = tonumber(cur["stop"])
    self:adjust_extract(start, stop)
end

function ExtractQueue:advance_stop()
    local adj = 0.1
    local cur = self:get_current()
    local start = tonumber(cur["start"])
    local stop = tonumber(cur["stop"]) - adj
    self:adjust_extract(start, stop)
end

function ExtractQueue:postpone_start()
    local adj = 0.1
    local cur = self:get_current()
    local start = tonumber(cur["start"]) + adj
    local stop = tonumber(cur["stop"])
    self:adjust_extract(start, stop)
end

function ExtractQueue:postpone_stop()
    local adj = 0.1
    local cur = self:get_current()
    local start = tonumber(cur["start"])
    local stop = tonumber(cur["stop"]) + adj
    self:adjust_extract(start, stop)
end

function ExtractQueue:handle_extract(start, stop, cur)
    local url = cur["url"]
    if cur["type"] == "youtube" then
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

    start = start - tonumber(cur["start"])
    stop = stop - tonumber(cur["start"])

    local extension = ".wav"
    local fname = tostring(os.time(os.date("!*t"))) .. "-aa"
    local extract = utils.join_path(mediadir, fname .. extension)

    local args = {
        "ffmpeg",
        -- "-hide_banner",
        "-nostats",
        -- "-loglevel", "fatal",
        "-ss", tostring(cur["start"]),
        "-to", tostring(cur["stop"]),
        "-i", url, -- extract audio stream
        extract
    }

    local completion_fn = function()

        local cloze = "sine.opus"
        local edl = utils.join_path("media", fname .. ".edl")
        local id = tostring(#db.items.csv_table + 1)

        -- Create virtual file using EDL
        local handle = io.open(edl, "w")
        handle:write("# mpv EDL v0\n")
        handle:write(fname .. extension .. ",0," .. tostring(start) .. "\n")
        handle:write(cloze .. ",0," .. tostring(stop - start) .. "\n")
        handle:write(fname .. extension .. "," .. tostring(stop) .. "," .. tostring(tonumber(cur["stop"]) - tonumber(cur["start"]) - stop) .. "\n")
        handle:close()

        local item = {
            id = id,
            parent = cur["id"],
            url = edl,
            priority = cur["priority"]
        }

        db.items:add(item)
        sounds.play("echo")
        mp.commandv("script-message", "extracted", self.name)
        mp.set_property("ab-loop-a", "no")
        mp.set_property("ab-loop-b", "no")
    end

    subprocess(args, completion_fn)

end

return ExtractQueue
