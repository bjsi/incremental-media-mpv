local DB = require("db.base")
local log = require("utils.log")

local CSVDB = {}
CSVDB.__index = CSVDB

setmetatable(CSVDB, {
    __index = DB,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end,
})

function CSVDB:_init(fp, default_header)
    log.debug("Initialising CSV database: " .. fp)
    DB._init(self, fp, ",", default_header)
end

function CSVDB:write_cell(handle, idx, total_cells, cell)
    if cell == nil then cell = "" end
    if idx ~= total_cells then
        handle:write(cell .. self.sep)
    else
        handle:write(cell .. "\n")
    end
    return true
end

return CSVDB
