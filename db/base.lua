local log = require("utils.log")

local DB = {}
DB.__index = DB

setmetatable(DB, {
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end,
})

function DB:_init(fp, sep, default_header)
    log.debug("Initialising database: " .. fp .. " with seperator: " .. sep)
    self.fp = fp
    self.sep = sep
    self.default_header = default_header
end

--- Open the database file for IO with mode and return the file handle.
-- @param mode IO mode.
function DB:open(mode)
    local handle = io.open(self.fp, mode)
    if handle == nil then
        log.err("Failed to open database: " .. self.fp)
    end
    return handle
end

function DB:read_reps(rep_func)
    local handle = self:open("r")
    if handle == nil then
        log.debug("Database file does not exist. Creating empty rep table.")
        return self.default_header, {}
    end

    local header = self:read_header(handle)
    if header == nil then
        log.err("Failed to read header from: " .. self.fp)
        handle:close()
        return nil
    end

    log.debug("Successfully read header from: " .. self.fp)

    local reps = self:read_rows(handle, header, rep_func)
    if reps == nil  then
        log.debug("Failed to read reps from: " .. self.fp)
        handle:close()
        return nil
    end

    log.debug("Successfully read reps from: " .. self.fp)
    handle:close()

    return header, reps
end

--- Write a RepTable to the database file.
-- @param repTable RepTable object
function DB:write(repTable)
    if repTable == nil or repTable.header == nil then
        log.err("Failed to write invalid data to: " .. self.fp)
        return false
    end

    local handle = self:open("w")
    if handle == nil then
        log.err("Failed to open db file for writing: " .. self.fp)
        return false
    end

    if not self:write_header(handle, repTable.header) then
        log.err("Failed to write header to: " .. self.fp)
        handle:close()
        return false
    end

    log.debug("Successfully wrote header to: " .. self.fp)

    if not self:write_rows(handle, repTable) then
        log.err("Failed to write rows to: " .. self.fp)
        handle:close()
        return false
    end

    log.debug("Successfully wrote rows to: " .. self.fp)

    handle:close()
    return true
end

function DB:preprocess_read_row(row)
    return row
end

function DB:parse_row(row)
    return string.gmatch(row, "[^" .. self.sep .. "]*")
end

function DB:read_header(handle)
    local ret = {}
    local data = handle:read()
    if data == nil then
        log.debug("Header line is nil or empty.")
        return nil
    end

    data = self:preprocess_read_row(data)
    for v in self:parse_row(data) do
        if v ~= "" then
            ret[#ret + 1] = v
        end
    end
    return ret
end

--- Reads the rows of the database returning a table of Rep objects.
function DB:read_rows(handle, header, rep_func)
    local ret = {}
    for line in handle:lines() do
        line = self:preprocess_read_row(line)
        local row = {}
        local ct = 1
        for v in self:parse_row(line) do
            if v ~= "" then
                row[header[ct]] = v
                ct = ct + 1
            end
        end
        ret[#ret+1] = rep_func(row)
    end
    return ret
end

function DB:write_header(handle, header)
    for i, v in ipairs(header) do
        self:write_cell(handle, i, #header, v)
    end
    return true
end

function DB:write_rows(handle, repTable)
    for _, rep in ipairs(repTable.reps) do
        for i, h in ipairs(repTable.header) do
            local cell = rep.row[h]
            self:write_cell(handle, i, #repTable.header, cell)
        end
    end
    return true
end

return DB
