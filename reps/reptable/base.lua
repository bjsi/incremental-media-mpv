local log = require("utils.log")
local str = require("utils.str")
local CSVDB = require("db.csv")
local MarkdownDB = require("db.md")

local RepTableBase = {}
RepTableBase.__index = RepTableBase

setmetatable(RepTableBase, {
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function RepTableBase:_init(fp, header, subsetter)
    log.debug("Initialising new reptable.")
    self.db = self:create_db(fp, header)
    self.defaultHeader = header
    self.subsetter = subsetter
    self.fst = nil
    self.reps = {}
    self.subset = {}
end

function RepTableBase:update_subset()
    local subset, getFst = self.subsetter(self.reps)
    self.subset = subset
    self:sort()
    self.fst = getFst(self.subset)
end

function RepTableBase:write() return self.db:write(self) end

function RepTableBase:create_db(fp, header)
    local extension = str.get_extension(fp)
    local db = nil
    if extension == "md" then
        db = MarkdownDB(fp, header)
    elseif extension == "csv" then
        db = CSVDB(fp, header)
    else
        local x = "Unrecognised database file extension."
        log.err(x)
        error(x)
    end
    return db
end

function RepTableBase:get_next_rep()
    self:sort()
    return self.subset[2]
end

function RepTableBase:next_repetition()
    error("override me!")
end

function RepTableBase:dismiss_current()
    local cur = self:current_scheduled()
    if not cur:is_due() then
        log.debug("No due repetition to dismiss.")
        return
    end
    self:remove_current()
    log.debug("Dismissed repetition: " .. cur.row["title"])
    self:write()
end

function RepTableBase:remove_current()
    self:sort()
    local removed = self.subset[1]
    table.remove(self.subset, 1)
    return removed
end

--- Add a Rep to the current subset.
--- @param rep Rep
---@return boolean
function RepTableBase:add_to_subset(rep)
    self.subset[#self.subset+1] = rep
    self:update_subset()
    return true
end

--- Add rep to reps table.
---@param rep Rep
---@return boolean
function RepTableBase:add_to_reps(rep)
    self.reps[#self.reps + 1] = rep
    self:update_subset()
    return true
end

function RepTableBase:current_scheduled()
    self:sort()
    return self.subset[1]
end

function RepTableBase:sort() self:sort_by_priority() end

function RepTableBase:sort_by_priority()
    local sort_func = function(a, b)
        local ap = tonumber(a.row["priority"])
        local bp = tonumber(b.row["priority"])
        return ap < bp
    end
    table.sort(self.subset, sort_func)
end

function RepTableBase:read_reps()
    local repFunc =  function(row) return self:as_rep(row) end
    local header, reps = self.db:read_reps(repFunc)
    self.reps = reps and reps or {}
    self.header = header and header or self.defaultHeader
    self:update_subset()
end

return RepTableBase
