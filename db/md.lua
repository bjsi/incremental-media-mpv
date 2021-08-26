local DBBase = require("db.base")

local MarkdownDB = {}
MarkdownDB.__index = MarkdownDB

setmetatable(MarkdownDB, {
    __index = DBBase,
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function MarkdownDB:_init(fp, default_header)
    DBBase._init(self, fp, "|", default_header)
end

function MarkdownDB:read_header(handle)
    local header = DBBase.read_header(self, handle)
    handle:read() -- read the | --- | --- | line
    return header
end

function MarkdownDB:write_header(handle, header)
    DBBase.write_header(self, handle, header)
    for i, v in ipairs(header) do
        local cell = string.gsub(v, ".", "-")
        self:write_cell(handle, i, #header, cell)
    end
    return true
end

function MarkdownDB:write_cell(handle, idx, total_cells, cell)
    if idx == 1 then
        handle:write(self.sep .. cell .. self.sep)
    elseif idx ~= total_cells then
        handle:write(cell .. self.sep)
    elseif idx == total_cells then
        handle:write(cell .. self.sep .. "\n")
    end
    return true
end

function MarkdownDB:preprocess_read_row(row) return string.sub(row, 1, -1) end

return MarkdownDB
