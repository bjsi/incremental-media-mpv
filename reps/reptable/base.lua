local CSVDB = require 'db.csv'
local sounds = require 'systems.sounds'
local MarkdownDB = require 'db.md'
local log = require 'utils.log'
local tbl = require 'utils.table'
local obj = require 'utils.object'
local str = require 'utils.str'

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
    self.db = self:create_db(fp, header)
    self.default_header = header
    self.subsetter = subsetter
    self.fst = nil
    self.reps = {}
    self.subset = {}
    self:read_reps()
end

function RepTableBase:learn()
    self:update_subset()
    if obj.empty(self.subset) then
        log.debug("Subset is empty. No more repetitions!")
        sounds.play("negative")
        return false
    end

    return true
end

function RepTableBase:get_rep_by_id(id, reps)
    return tbl.first(function(r) return r.row["id"] == id end, reps)
end

function RepTableBase:update_dependencies()
    local updated = false
    if obj.empty(self.reps) then return false end
    for _, v in ipairs(self.reps) do
        local dep_id = v.row["dependency"]
        if dep_id then
            local dep = self:get_rep_by_id(dep_id, self.reps)
            if not dep or dep:is_deleted() or dep:is_done() then
                v.row["dependency"] = ""
                updated = true
            end
        end
    end

    if updated then self:write() end
    return true
end

function RepTableBase:exists(element)
    for _, v in ipairs(self.reps) do
        if v.row["url"] == element.row["url"] then return true end
    end
    return false
end

function RepTableBase:update_subset()
    self:update_dependencies()
    self.subset, self.fst = self.subsetter(self.reps)
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

--- Add a Rep to the current subset.
function RepTableBase:add_to_subset(rep)
    self.subset[#self.subset + 1] = rep
    self:update_subset()
    return true
end

--- Add rep to reps table.
function RepTableBase:add_to_reps(rep)
    self.reps[#self.reps + 1] = rep
    self:update_subset()
    return true
end

function RepTableBase:read_reps()
    local as_rep = function(row) return self:as_rep(row) end
    local header, reps = self.db:read_reps(as_rep)
    if reps then
        self.reps = reps
    else
        self.reps = {}
    end
    if header then
        self.header = header
    else
        self.header = self.default_header
    end
    self:update_subset()
end

return RepTableBase
