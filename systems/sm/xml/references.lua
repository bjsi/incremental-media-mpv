local references  = {}
references .__index = references

function references.new()
    local self = setmetatable({}, references)
    self.template_start = [[<br>
<br>
<hr SuperMemo>
<SuperMemoReference>
<H5 dir=ltr align=left>
<Font size="1" style="color: transparent">#SuperMemo Reference:</font>
<br><FONT class=reference>]]

    self.content = {
        "#Source: Incremental Media Player",
    }

    self.template_end = [[</FONT>
</SuperMemoReference>]]

    return self
end

function references:with_link(link)
    table.insert(self.content, ([[#Link: <a href="%s">%s</a>]]):format(link, link))
    return self
end

function references:with_title(title)
    table.insert(self.content, "#Title: " .. title)
    return self
end

function references:as_string()
    return table.concat({
        self.template_start,
        table.concat(self.content, "<br>"),
        self.template_end,
    }, "")
end

return references