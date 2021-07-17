local active = require("systems.active")
local log = require("utils.log")
local Base = require("systems.menu.submenuBase")
local ext  = require("utils.ext")
local str  = require("utils.str")
package.path = mp.command_native({"expand-path", "~~/script-modules/?.lua;"})..package.path
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

    self.keybinds = {}
    self.base_binds = {}

    self.subset_chain = { 
        function(a, c, i) self:query_title(a, c, i) end,
        function(a, c, i) self:confirm(a, c, i) end,
    }
end

function SubsetMenu:confirm(args, chain, i)
    log.debug("Finding subset elements where title contains: " .. args["title"])
end

function SubsetMenu:call_chain(args, chain, i)
    if chain ~= nil and i <= #chain then
        chain[i](args, chain, i)
    else
        log.debug("End of chain: ", args)
    end
end

function SubsetMenu:query_title(args, chain, i)
    local handle = function(input)
        if ext.empty(input) then log.notify("Cancelling.") return end
        args["title"] = input
        self:call_chain(args, chain, i + 1)
    end

    get_user_input(handle,
        {
            text = "Subset with titles containing: ",
            replace = true,
        })
end

function SubsetMenu:create_subset()
    self:call_chain({}, self.subset_chain, 1)
end

function SubsetMenu:add_osd(osd)
    local queue = active.queue
    osd:submenu("incremental media"):newline():newline()
    self:add_queue_osd(osd, queue)
    self:add_element_osd(osd, queue)
end

return SubsetMenu