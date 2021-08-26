local stack = {}

function stack.first(pred, stk)
    local ret
    while true do
        ret = stk:pop()
        if pred(ret) or ret == nil then return ret end
    end
end

return stack
