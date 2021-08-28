local task_result = require 'systems.ui.input.task_result'
local str = require 'utils.str'

local function create_gui_args(name, title)
    if not title then title = str.capitalize_first(name) .. ": " end
    return {title, replace = true}
end

local function create_yn_input_handler(name, default, state_setter, title)
    local handler = function(input, state)
        if input == nil then return task_result.cancel end
        if input == "" then input = default end
        if input ~= "y" and input ~= "n" then
            return task_result.again_invalid_data
        end
        if state_setter then
            state_setter(input, state)
        else
            state[name] = input == "y"
        end
        return task_result.next
    end
    return handler, create_gui_args(name, title)
end

local function create_string_input_handler(name, validator, state_setter, title)
    local handler = function(input, state)
        if input == nil then return task_result.cancel end

        if not validator(input) then
            return task_result.again_invalid_data
        end

        if not state_setter then
            state[name] = input
        else
            state_setter(input, state)
        end
        return task_result.next
    end
    return handler, create_gui_args(name, title)
end

local function create_number_input_handler(name, validator, state_setter, title)
    local handler = function(input, state)
        if input == nil then return task_result.cancel end

        local n = tonumber(input)
        if not validator(n) then return task_result.again_invalid_data end

        if not state_setter then
            state[name] = n
        else
            state_setter(input, state)
        end
        return task_result.next
    end
    return handler, create_gui_args(name, title)
end

return {
    create_number_input_handler = create_number_input_handler,
    create_string_input_handler = create_string_input_handler,
    create_yn_input_handler = create_yn_input_handler
}
