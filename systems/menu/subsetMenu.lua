local active = require("systems.active")
local log = require("utils.log")
local Base = require("systems.menu.submenuBase")
local ext = require("utils.ext")
local str = require("utils.str")
package.path = mp.command_native({"expand-path", "~~/script-modules/?.lua;"}) ..
                   package.path
local ui = require "user-input-module"
local get_user_input = ui.get_user_input

local SubsetMenu = {}
SubsetMenu.__index = SubsetMenu

setmetatable(SubsetMenu, {
    __index = Base,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function SubsetMenu:_init()
    Base._init(self)

    self.keybinds = {
        {key = 'S', desc = "search", fn = function() self:search() end}
    }
end

function SubsetMenu:show_results(res) for _, v in ipairs(res) do end end

function SubsetMenu:call_chain(args, chain, i)
    if chain ~= nil and i <= #chain then
        chain[i](args, chain, i)
    else
        log.debug("End of chain: ", args)
    end
end

function SubsetMenu:query_title()
    local handle = function(input)
        if ext.empty(input) then
            log.notify("Cancelling.")
            return
        end

        if not active.queue then return end

        if active.queue.name:find("Topic") then
        elseif active.queue.name:find("Extract") then
        elseif active.queue.name:find("Item") then
        end
        self:call_chain(args, chain, i + 1)
    end

    get_user_input(handle, {text = "Search: ", replace = true})
end

function SubsetMenu:add_osd(osd)
    local queue = active.queue
    osd:submenu("incremental media"):newline():newline()
    self:add_queue_osd(osd, queue)
    self:add_element_osd(osd, queue)
end

return SubsetMenu
