local log = require("utils.log")
local Scheduler = require("reps.scheduler")
local ext = require("utils.ext")
local str = require("utils.str")
local CSVDB = require("db.csv")
local MarkdownDB = require("db.md")

local RepTable = {}
RepTable.__index = RepTable

setmetatable(RepTable, {
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end,
})

function RepTable:_init(fp, header)
    log.debug("Initialising new reptable.")
    self.db = self:create_db(fp, header)
end

function RepTable:create_db(fp, header)
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

function RepTable:get(predicate)
    return ext.list_filter(self.reps, predicate)
end

function RepTable:get_next_rep()
    self:sort()
    return self.reps[2]
end

function RepTable:remove_deleted()
    local predicate = function(rep)
        if rep:is_yt() then
            return true
        elseif rep:is_local() then
            return ext.file_exists(rep.row["url"])
        end
    end
    local existing = self:get(predicate)
    self.reps = existing
end

function RepTable:next_repetition()
    if ext.empty(self.reps) then
        log.debug("No more repetitions!")
        return
    end

    local curRep = self:get_current_rep()
    local nextRep = self:get_next_rep()

    -- not due; don't schedule or load
    if curRep ~= nil and not curRep:is_due() then
        log.debug("No more repetitions!")
        return
    end

    self:remove_current()
    local sched = Scheduler()
    sched:schedule(self, curRep)
    local toload = nil

    if curRep ~= nil and nextRep == nil then
        toload = curRep
        log.debug("No more repetitions!")
    elseif curRep ~= nil and nextRep ~= nil then
        if nextRep:is_due() then
            toload = nextRep
        else
            toload = curRep
        end
    end

    self.db:write(self)
    return toload
end

function RepTable:dismiss_current()
    local cur = self:get_current_rep()
    if not cur:is_due() then
        log.debug("No due repetition to dismiss.")
        return
    end
    self:remove_current()
    log.debug("Dismissed repetition: " .. cur.row["title"])
    self.db:write(self)
end

function RepTable:remove_current()
    self:sort()
    local removed = nil
    if #self.reps == 1 then
        removed = table.remove(self.reps, #self.reps)
    elseif #self.reps > 1 then
        removed = self.reps[1]
        table.remove(self.reps, 1)
    end
    return removed
end

function RepTable:add_rep(rep)
    for _, v in ipairs(self.header) do
        if rep.row[v] == nil then
            log.debug("Invalid row data.")
            return false
        end
    end

    self.reps[#self.reps+1] = rep
    return true
end

-- Returns a Rep
function RepTable:get_current_rep()
    self:sort()
    return self.reps[1]
end

function RepTable:sort()
    self:sort_by_priority()
end

function RepTable:sort_by_priority()
    local srt = function(a, b)
        local ap = tonumber(a.row["priority"])
        local bp = tonumber(b.row["priority"])
        return ap < bp
    end
    table.sort(self.reps, srt)
end

return RepTable
