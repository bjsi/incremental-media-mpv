local active = require("systems.active")
local mpu = require('mp.utils')
local Base = require("systems.menu.submenuBase")
local ext  = require("utils.ext")
local str  = require("utils.str")
local log  = require("utils.log")
local player = require("systems.player")
local ClozeEDL    = require("systems.edl.edl")
local QAEDL = require("systems.edl.qaEdl")
local ClozeContextEDL = require("systems.edl.clozeContextEdl")
local ffmpeg = require("systems.ffmpeg")
local ydl    = require("systems.ydl")
local fs     = require("systems.fs")
local item_format = require("reps.rep.item_format")

package.path = mp.command_native({"expand-path", "~~/script-modules/?.lua;"})..package.path
local ui = require "user-input-module"
local get_user_input = ui.get_user_input

local LocalItemQueue
local LocalExtractQueue
local GlobalExtractQueue
local menuBase

-- Change name to element menu?
local HomeSubmenu = {}
HomeSubmenu.__index = HomeSubmenu

setmetatable(HomeSubmenu, {
    __index = Base,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function HomeSubmenu:_init()
    Base._init(self)

    self.keybinds = {}

    self.base_binds = {}

    self.topic_keybinds = {
        { key = "t", desc = "edit title", fn = function() self:edit_title() end },
        { key = "c", desc = "extract chapter", fn = function() self:extract_chapter() end },
        { key = "C", desc = "extract all chapters", fn = function() self:extract_all_chapters() end },
    }

    self.media_keybinds = {
        { key = "r", desc = "remove media", fn = function() self:remove_media() end },
    }

    self.extract_keybinds = {
        { key='Q', desc = "create Q/A", fn = function() active.queue:create_qa() end},
        { key='Z', desc = "edit subs", fn = function() self:edit_current_field("subs") end },
    }

    self.item_keybinds = {
        { key = 'Z', desc = "edit subs", fn = function() self:edit_current_field("subs") end },
        { key = "S", desc = "add screenshot", fn = function() self:item_add_media("screenshot") end },
        { key = "G", desc = "add gif", fn = function() self:item_add_media("gif") end },
        { key = "q", desc = "edit question", fn = function() self:edit_current_field("question") end },
        { key = "a", desc = "edit answer", fn = function() self:edit_current_field("answer") end },
    }
end

function HomeSubmenu:add_osd(osd)
    local queue = active.queue
    osd:submenu("incremental media"):newline():newline()
    self:add_queue_osd(osd, queue)
    self:add_element_osd(osd, queue)
end

function HomeSubmenu:add_keybinds(tbl)
    for _, v in pairs(tbl) do
        table.insert(self.keybinds, v)
    end
end

--
-- OSD
---- OSD Queue Info

function HomeSubmenu:add_queue_osd(osd, queue)
    if queue ~= nil then
        osd:text(queue.name):newline()
        osd:item("reps: "):text(#queue.reptable.subset):newline()
        local toexport = #ext.list_filter(queue.reptable.reps, function(r) return r:to_export() end)
        osd:item("to export: "):text(tostring(toexport)):newline():newline()
    else
        osd:text("No queue loaded."):newline()
    end
end

---- OSD Element Info

function HomeSubmenu:add_generic_info(osd, cur)
    local type = str.capitalize_first(cur:type())
    osd:text(type .. " Data"):newline()
    osd:item('priority: '):text(tostring(cur.row["priority"])):newline()
    osd:item("dismissed: "):text(tostring(cur:is_dismissed())):newline()
    osd:item('export: '):text(tostring(cur:to_export())):newline()
end

function HomeSubmenu:add_scheduling_info(osd, cur)
    osd:item("interval: "):text(cur.row["interval"]):newline()
    osd:item("next rep: "):text(cur.row["nextrep"]):newline()
    osd:item("a-factor: "):text(cur.row["afactor"]):newline()
end

function HomeSubmenu:add_chapter_info(osd)
    local chaps = mp.get_property_native("chapter-list")
    local num = chaps ~= nil and #chaps or 0
    osd:item("chapters: "):text(tostring(num)):newline()
end

---- Element Type OSDs

function HomeSubmenu:add_question_osd(osd, cur)
    osd:item("question: "):text(cur.row["question"]):newline()
    osd:item("answer: "):text(cur.row["answer"]):newline()
    osd:item("format: "):text(cur.row["format"]):newline()
end

function HomeSubmenu:add_subs_osd(osd, cur)
    osd:item("subs: "):text(cur.row["subs"]):newline()
end

function HomeSubmenu:add_item_osd(osd, cur)
    self:add_generic_info(osd, cur)
    osd:newline()
    self:add_question_osd(osd, cur)
    self:add_subs_osd(osd, cur)
    self:add_keybinds(self.item_keybinds)
end

function HomeSubmenu:edit_title()
    local queue = active.queue
    if queue == nil or queue.playing == nil then return end

    local cur = queue.playing
    local handler = function(input)
        if input == nil then
            log.notify("Cancelled.")
            return
        end

        cur.row["title"] = str.remove_db_delimiters(input)
        queue:save_data()
        log.notify("Saved title.")
        menuBase = menuBase or require("systems.menu.menuBase")
        menuBase.update()
    end

    get_user_input(function(input) handler(input) end,
        {
            text = "Edit title: ",
            replace = true,
            default_input = cur.row["title"]
        })
end

function HomeSubmenu:add_topic_osd(osd, cur)
    self:add_generic_info(osd, cur)
    osd:item("title: "):text(cur.row["title"]):newline()
    self:add_scheduling_info(osd, cur)
    self:add_chapter_info(osd)

    LocalExtractQueue = LocalExtractQueue or require("queue.localExtractQueue")
    local leq = LocalExtractQueue(cur)
    osd:item("children: "):text(#leq.reptable.subset):newline():newline():newline()

    self:add_keybinds(self.topic_keybinds)
end


function HomeSubmenu:add_extract_osd(osd, cur)
    self:add_generic_info(osd, cur)
    self:add_scheduling_info(osd, cur)
    self:add_subs_osd(osd, cur)

    LocalItemQueue = LocalItemQueue or require("queue.localItemQueue")
    local liq = LocalItemQueue(cur)
    osd:item("children: "):text(#liq.reptable.subset):newline()
    if not ext.empty(cur.row["notes"]) then
        osd:item("notes: "):newline():text(cur.row["notes"]):newline()
    end

    osd:newline()

    self:add_keybinds(self.extract_keybinds)
end

function HomeSubmenu:add_element_osd(osd, queue)
    if queue == nil or queue.playing == nil then
        osd:text("No current element."):newline()
        return
    end

    local cur = queue.playing
    local type = cur:type()
    if type == "topic" then
        self:add_topic_osd(osd, cur)
    elseif type == "extract" then
        self:add_extract_osd(osd, cur)
    elseif type == "item" then
        self:add_item_osd(osd, cur)
    end
end

function HomeSubmenu:remove_media()
    local queue = active.queue
    if queue == nil or queue.playing == nil then return end
    local cur = queue.playing
    
    local handler = function(input)
        if input == nil or input == "n" or input == "" then
            log.notify("Cancelling")
        end

        if input == "y" then
            cur.row["media"] = ""
            queue:save_data()
            log.notify("Removed media.")
            return
        end
    end

    get_user_input(function(input) handler(input) end,
        {
            text = "Remove media? (y/[n]): ",
            replace = true,
        })
end

function HomeSubmenu:item_add_media(type)
    local queue = active.queue
    if queue == nil or queue.playing == nil then return end
    local cur = queue.playing

    -- TODO: edl update
    local edlFullPathWithExt = player.get_full_url(cur)
    local edl

    if cur.row.format == item_format.cloze then
        edl = ClozeEDL.new(edlFullPathWithExt)
    elseif cur.row.format == item_format.cloze_context then
        edl = ClozeContextEDL.new(edlFullPathWithExt)
    elseif cur.row.format == item_format.qa then
        edl = QAEDL.new(edlFullPathWithExt)
    end

    local sound, format, media = edl:read()

    GlobalExtractQueue = GlobalExtractQueue or require("queue.globalExtractQueue")
    local geq = GlobalExtractQueue(nil)
    local parent = ext.first_or_nil(function(r) return r:is_parent_of(cur) end, geq.reptable.reps)
    if not parent then return end

    local vidUrl = player.get_full_url(parent)
    local fp = mpu.join_path(fs.media, tostring(os.time()))
    local vidstream

    local mediaStart
    local mediaStop

    if cur.row.format == item_format.cloze then
        mediaStart = format["cloze-start"]
        mediaStop = format["cloze-stop"]
    elseif cur.row.format == item_format.cloze_context then
        mediaStart = sound["cloze-start"]
        mediaStop = sound["cloze-stop"]
    elseif cur.row.format == item_format.qa then
        mediaStart = sound["start"]
        mediaStop = sound["stop"]
    end

    if parent:is_yt() then
        vidstream = ydl.get_video_stream(vidUrl, false)
        mediaStart = mediaStart + tonumber(parent.row["start"])
        mediaStop = mediaStop + tonumber(parent.row["start"])
    else
        vidstream = vidUrl
    end

    local ret = false
    if type == "gif" then
        fp = fp .. ".gif"
        ret = ffmpeg.extract_gif(vidstream, mediaStart, mediaStop, fp)
    elseif type == "screenshot" then
        fp = fp .. ".png" -- TODO: GDI errors on SM side
        ret = ffmpeg.screenshot(vidstream, mediaStop, fp)
    end
    
    if ret then
        local _, filename = mpu.split_path(fp)
        edl:write(sound, format, { path = filename, showat="answer" })
        log.notify("Added " .. type)
        local curtime = mp.get_property("time-pos")
        mp.commandv("loadfile", edlFullPathWithExt, "replace", "start=" .. curtime)
    else
        log.notify("Failed to add " .. type)
    end
end

function HomeSubmenu:edit_current_field(field)
    local queue = active.queue
    if queue == nil or queue.playing == nil then return end

    local cur = queue.playing
    if cur == nil then return end

    local handler = function(input)
        if input == nil then
            log.notify("Cancelled.")
            return
        end

        cur.row[field] = str.remove_db_delimiters(input)
        queue:save_data()
        log.notify("Saved " .. field)
        menuBase = menuBase or require("systems.menu.menuBase")
        menuBase.update()
    end

    get_user_input(function(input) handler(input) end,
        {
            text = "Edit " .. field .. ": ",
            replace = true,
            default_input = cur.row[field]
        })
end

return HomeSubmenu