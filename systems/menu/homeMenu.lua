local active = require("systems.active")
local mpu = require('mp.utils')
local Base = require("systems.menu.submenuBase")
local ext  = require("utils.ext")
local str  = require("utils.str")
local log  = require("utils.log")
local player = require("systems.player")
local edl    = require("systems.edl")
local ffmpeg = require("systems.ffmpeg")
local ydl    = require("systems.ydl")
local fs     = require("systems.fs")

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
        { key = "t", fn = function() self:edit_title() end },
    }

    self.media_keybinds = {
        { key = "S", fn = function() self:toggle_media() end },
        { key = "r", fn = function() self:remove_media() end },
    }

    self.extract_keybinds = {
        { key = "n", fn = function() self:extract_edit_notes() end },
        -- { key = "g", fn = function() self:extract_add_gif() end },
        -- { key = "s", fn = function() self:extract_add_screenshot() end },
    }

    self.item_keybinds = {
        { key = "S", fn = function() self:item_add_media("screenshot") end },
        { key = "G", fn = function() self:item_add_media("gif") end },
        { key = "W", fn = function() self:item_generate_meaning_card() end },
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

---- OSD Binds

function HomeSubmenu:add_base_binds_osd(osd)
    osd:text("Bindings"):newline()
    osd:tab():item("i: "):text("import menu"):newline()
end

function HomeSubmenu:add_topic_binds_osd(osd)
    local chaps = mp.get_property_native("chapter-list")
    local num = chaps ~= nil and #chaps or 0
    if num > 0 then
        osd:tab():italics("chapters"):newline()
        osd:tab():item('c: '):text('extract chapter '):newline()
        osd:tab():item('C: '):text('extract all chapters '):newline():newline()
    end
end

function HomeSubmenu:add_media_binds_osd(osd)
    osd:tab():item('r: '):text("remove media"):newline():newline()
end

function HomeSubmenu:add_extract_binds_osd(osd)
    osd:tab():item('n: '):text("edit notes"):newline()
    -- osd:tab():item('G: '):text("add gif to children"):newline()
    -- osd:tab():item('S: '):text("add screenshot to children"):newline()
end

function HomeSubmenu:add_item_binds_osd(osd)
    osd:tab():item('S: '):text("add cloze screenshot"):newline()
    osd:tab():item('G: '):text("add cloze gif"):newline()
    -- osd:tab():item("W: "):text("meaning card"):newline()
end

---- Element Type OSDs

function HomeSubmenu:add_item_osd(osd, cur)
    self:add_generic_info(osd, cur)
    osd:newline()
    self:add_base_binds_osd(osd)
    self:add_item_binds_osd(osd)
    self:add_media_binds_osd(osd)
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

    self:add_base_binds_osd(osd)
    self:add_topic_binds_osd(osd)
    self:add_keybinds(self.topic_keybinds)
end


function HomeSubmenu:add_extract_osd(osd, cur)
    self:add_generic_info(osd, cur)
    self:add_scheduling_info(osd, cur)

    LocalItemQueue = LocalItemQueue or require("queue.localItemQueue")
    local liq = LocalItemQueue(cur)
    osd:item("children: "):text(#liq.reptable.subset):newline()
    if not ext.empty(cur.row["notes"]) then
        osd:item("notes: "):newline():text(cur.row["notes"]):newline()
    end

    osd:newline()

    self:add_base_binds_osd(osd)
    self:add_keybinds(self.extract_keybinds)
    self:add_extract_binds_osd(osd)
end

function HomeSubmenu:add_element_osd(osd, queue)
    if queue == nil or queue.playing == nil then
        osd:text("No current element.")
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

function HomeSubmenu:item_add_media(type)
    local queue = active.queue
    if queue == nil or queue.playing == nil then return end
    local cur = queue.playing

    local edlPath = player.get_full_url(cur)
    local e = edl.new(edlPath)
    local parentPath, parentStart, parentEnd, clozeStart, clozeEnd, _ = e:read()
    if clozeStart == nil then return end

    GlobalExtractQueue = GlobalExtractQueue or require("queue.globalExtractQueue")
    local geq = GlobalExtractQueue(nil)
    local parent = ext.first_or_nil(function(r) return r:is_parent_of(cur) end, geq.reptable.reps)
    if not parent then return end

    local vidUrl = player.get_full_url(parent)
    local fp = mpu.join_path(fs.media, tostring(os.time()))
    local vidstream
    local mediaStart = clozeStart
    local mediaEnd = clozeEnd

    if parent:is_yt() then
        vidstream = ydl.get_video_stream(vidUrl, false)
        mediaStart = clozeStart + tonumber(parent.row["start"])
        mediaEnd = clozeEnd + tonumber(parent.row["start"])
    else
        vidstream = vidUrl
    end

    local ret = false
    if type == "gif" then
        fp = fp .. ".gif"
        ret = ffmpeg.extract_gif(vidstream, mediaStart, clozeEnd, fp)
    elseif type == "screenshot" then
        fp = fp .. ".jpg"
        ret = ffmpeg.screenshot(vidstream, mediaEnd, fp)
    end
    
    if ret then
        local _, filename = mpu.split_path(fp)
        e:write(parentPath, parentStart, parentEnd, clozeStart, clozeEnd, filename)
        log.notify("Added " .. type)
        local curtime = mp.get_property("time-pos")
        mp.commandv("loadfile", edlPath, "replace", "start=" .. curtime)
    else
        log.notify("Failed to add " .. type)
    end
end

function HomeSubmenu:extract_edit_notes()
    local queue = active.queue
    if queue == nil or queue.playing == nil then return end

    local cur = queue.playing
    local notes = cur.row["notes"] and cur.row["notes"] or ""

    local handler = function(input)
        if input == nil then
            log.notify("Cancelled.")
            return
        end
        cur.row["notes"] = str.remove_db_delimiters(input)
        queue:save_data()
        log.notify("Saved notes.")
        menuBase = menuBase or require("systems.menu.menuBase")
        menuBase.update()
    end

    get_user_input(function(input) handler(input) end,
        {
            text = "Edit notes: ",
            replace = true,
            default_input = notes
        })
end

return HomeSubmenu