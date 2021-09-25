local active = require("systems.active")
local pri = require 'utils.priority'
local obj = require 'utils.object'
local cfg = require("systems.config")
local Base = require("systems.menu.submenuBase")
local OSD = require("systems.osd_styler")
local log = require("utils.log")
local sounds = require("systems.sounds")
local str = require("utils.str")
local date = require("utils.date")
local mp = require 'mp'

local list = dofile(mp.command_native({
    "expand-path", "~~/script-modules/scroll-list.lua"
}))

local LocalExtracts
local LocalItems
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
    -- LuaFormatter off
    list.keybinds = {
        {'DOWN', 'scroll_down', function() list:scroll_down() end, {repeatable = true} },
        {'UP', 'scroll_up', function() list:scroll_up() end, {repeatable = true} },
        {'j', 'scroll_down_j', function() list:scroll_down() end, {repeatable = true} },
        {'k', 'scroll_up_k', function() list:scroll_up() end, {repeatable = true} },
	{'Shift+UP', 'priority_up', function() self:adjust_priority(list.__current, 5) end, {}},
	{'Shift+DOWN', 'priority_down', function() self:adjust_priority(list.__current, -5) end, {} },
	{'ESC', 'close_browser', function() list:close() end, {}},
        {'H', 'home_menu', function() self:home() end, {}},
        {'w', 'parent_queue', function() self:home() end, {}},
        {'s', 'child_queue', function() self:home() end, {}},
        {'ENTER', 'toggle_children', function() self:toggle_children() end, {}}
    }
    -- LuaFormatter on
    self:add_osd()
end

function QueueMenu:add_osd()
    local queue = active.queue
    local subset
    local queue_name
    if queue then
	    subset = queue.reptable.subset
	    queue_name = queue.name
    else
	    subset = {}
	    queue_name = "No Loaded Queue"
    end

    list.list = {}
    list.header = queue_name

    for i, v in ipairs(subset) do
        local item = {}
        item.style = ""
        local itemOsd = OSD:new():size(cfg.menu_font_size - 1):align(4)
        local title
        if v.row.title then
            title = tostring(i) .. ". " ..
                        list.ass_escape(str.limit_length(v.row.title, 40))
        else
            title = tostring(i) .. ". " .. str.capitalize_first(v:type())
        end
        if i == 1 then
            itemOsd:color("ff0000"):bold(title):tab():text(v.row.priority)
        else
            itemOsd:text(title):tab():text(v.row.priority)
        end

        item.ass = itemOsd:get_text()
        item.rep = v
        list.list[i] = item
    end

    self:add_header_osd(queue_name)
    list:update()
    list:open()
end

function QueueMenu:add_header_osd(queue_name)
    list.header_style = ""
    local header = OSD:new():size(cfg.menu_font_size):align(4)
    header:submenu(queue_name):newline():get_text()
    list.header = header:get_text()
end

function QueueMenu:home()
    list:close()
    menuBase = menuBase or require("systems.menu.menuBase")
    menuBase.state = "home"
    menuBase.open()
end

function QueueMenu:adjust_priority(selected, adj)
    local queue = active.queue
    if queue == nil then return end

    local rep = selected.rep
    if rep == nil then return end

    local curPri = tonumber(rep.row["priority"])
    local newPri = curPri + adj
    if not pri.validate(newPri) then
        sounds.play("negative")
        return
    end

    rep.row["priority"] = newPri
    queue:save_data()
    list:close()
    self:add_osd()
end

function QueueMenu:toggle_children()
    local curListItem = list.__current
    curListItem.show_children = not curListItem.show_children
    local curRep = curListItem.rep

    if not curListItem.show_children then
        for i, v in ipairs(list.list) do
            if v.rep:is_child_of(curRep) then
                table.remove(list.list, i)
            end
        end

        list:update()
        return
    end

    local children
    if curRep:type() == "topic" then
        LocalExtracts = LocalExtracts or require("queues.local.extracts")
        local leq = LocalExtracts(curRep)
        children = leq.reptable.subset
    elseif curRep:type() == "extract" then
        LocalItems = LocalItems or require("queues.local.items")
        local liq = LocalItems(curRep)
        children = liq.reptable.subset
    end

    if obj.empty(children) then
        log.notify("No child elements available.")
        return
    end

    for _, v in ipairs(children) do
        local item = {}
        local itemOsd = OSD:new():size(cfg.menu_font_size - 1):align(4)
        local start = date.human_readable_time(tonumber(v.row.start)):sub(0, 6)
        local stop = date.human_readable_time(tonumber(v.row.stop)):sub(0, 6)
        local title =
            str.capitalize_first(v:type()) .. " " .. start .. " -> " .. stop
        itemOsd:tab():text("╚═ " .. title)

        item.ass = itemOsd:get_text()
        item.rep = v
        table.insert(list.list, list.selected + 1, item)
    end

    list:update()
end

return QueueMenu
