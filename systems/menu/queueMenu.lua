local active = require("systems.active")
local Base = require("systems.menu.submenuBase")
local osd = require("systems.osd_styler")
local log = require("utils.log")local ext = require("utils.ext")local sounds = require("systems.sounds")
local list = dofile(mp.command_native({"expand-path", "~~/script-modules/scroll-list.lua"}))

local menuBase

local QueueMenu = {}
QueueMenu.__index = QueueMenu

setmetatable(QueueMenu, {
    __index = Base,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function QueueMenu:_init()
    Base._init(self)
    self.keybinds = {}
end

function QueueMenu:add_osd(_)
    local queue = active.queue
    if queue == nil then return end
    local subset = queue.reptable.subset
    list.list = {}
    list.header = queue.name

    list.keybinds = {
        {'DOWN', 'scroll_down', function() list:scroll_down() end, {repeatable = true}},
        {'UP', 'scroll_up', function() list:scroll_up() end, {repeatable = true}},
        {'Shift+Up', 'priority_up', function() self:adjust_priority(list.__current, 5) end},
        {'Shift+Down', 'priority_down', function() self:adjust_priority(list.__current, -5) end},
        --{'ENTER', 'open_chapter', open_chapter, {} },
        {'ESC', 'close_browser', function() list:close() end, {}}
    }

    for i, v in ipairs(subset) do
        local item = {}
        if i == 1 then
            item.style = [[{\c&H33ff66&}]]
        end
        
        item.ass = list.ass_escape(v.row["title"])
        item.ass = item.ass .. "\\h\\h\\h" .. v.row["priority"]
        item.rep = v
        list.list[i] = item
    end

    list:update()
    list:open()
end

function QueueMenu:adjust_priority(selected, adj)
    local queue = active.queue
    if queue == nil then return end

    local rep = selected.rep
    if rep == nil then return end

    local curPri = tonumber(rep.row["priority"])
    local newPri = curPri + adj
    if not ext.validate_priority(newPri) then
        sounds.play("negative")
        return
    end

    rep.row["priority"] = newPri
    queue:save_data()
    menuBase = menuBase or require("systems.menu.menuBase")
    menuBase:update()
end

return QueueMenu