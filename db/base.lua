local log = require("utils.log")

local DBBase = {}
DBBase.__index = DBBase

setmetatable(DBBase, {
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function DBBase:_init(fp, sep, default_header)
    self.fp = fp
    self.sep = sep
    self.default_header = default_header
end

function DBBase:open(mode) return io.open(self.fp, mode) end

function DBBase:read_reps(rep_func)
    local handle = self:open("r")
    if handle == nil then return self.default_header, {} end

    local header = self:read_header(handle)
    if header == nil then
        log.err("Failed to read header from: " .. self.fp)
        handle:close()
        return nil
    end

    local reps = self:read_rows(handle, header, rep_func)
    if reps == nil then
        log.debug("Failed to read reps from: " .. self.fp)
        handle:close()
        return nil
    end

    handle:close()
    return header, reps
end

function DBBase:write(rep_table)
    if rep_table == nil or rep_table.header == nil then
        log.err("Failed to write invalid data to: " .. self.fp)
        return false
    end

    local handle = self:open("w")
    if handle == nil then
        log.err("Failed to open db file for writing: " .. self.fp)
        return false
    end

    if not self:write_header(handle, rep_table.header) then
        log.err("Failed to write header to: " .. self.fp)
        handle:close()
        return false
    end

    if not self:write_rows(handle, rep_table) then
        log.err("Failed to write rows to: " .. self.fp)
        handle:close()
        return false
    end

    handle:close()
    return true
end

function DBBase:preprocess_read_row(row) return row end

function DBBase:parse_row(row)
    return string.gmatch(row, "[^" .. self.sep .. "]*")
end

function DBBase:read_header(handle)
    local ret = {}
    local data = handle:read()
    if data == nil then
        log.debug("Header line is nil or empty.")
        return nil
    end

    data = self:preprocess_read_row(data)
    for v in self:parse_row(data) do if v ~= "" then ret[#ret + 1] = v end end
    return ret
end

--- Reads the rows of the database returning a table of Rep objects.
function DBBase:read_rows(handle, header, rep_func)
    local ret = {}
    for line in handle:lines() do
        line = self:preprocess_read_row(line)

        local row = {}
        local ct = 1
        for v in self:parse_row(line) do
            if v ~= "" then
                if v == "NULL" then v = "" end
                row[header[ct]] = v
                ct = ct + 1
            end
        end

        -- Ignore deleted
        local rep = rep_func(row)
        if rep:is_deleted() then
            log.debug("Ignoring deleted rep: " .. rep.row["url"])
        else
            ret[#ret + 1] = rep
        end
    end
    return ret
end

function DBBase:write_header(handle, header)
    for i, v in ipairs(header) do self:write_cell(handle, i, #header, v) end
    return true
end

function DBBase:write_rows(handle, repTable)
    for _, rep in ipairs(repTable.reps) do
        for i, h in ipairs(repTable.header) do
            local cell = rep.row[h]
            if cell == "" then cell = "NULL" end
            self:write_cell(handle, i, #repTable.header, cell)
        end
    end
    return true
end

return DBBase
