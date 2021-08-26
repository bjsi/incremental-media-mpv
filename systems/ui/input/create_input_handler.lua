local task_result = require 'systems.ui.input.task_result'
local str = require 'utils.str'

local function create_string_input_handler(name, validator)
    return function(input, state)
        if input == nil then return task_result.cancel end

        if not validator(input) then
            return task_result.again_invalid_data
        end

        state[name] = input
        return "next"
    end
end

local function create_number_input_handler(name, validator)
    return function(input, state)
        if input == nil then return task_result.cancel end

        local p = tonumber(input)
        if not validator(p) then return task_result.again_invalid_data end

        state[name] = p
        return "next"
    end
end

local function create_input_handler(name, type, validator, title)
    if not title then title = str.capitalize_first(name) .. ": " end
    local gui_args = {title, replace = true}
    if type == "number" then
        return create_number_input_handler(name, validator), gui_args
    elseif type == "string" then
        return create_string_input_handler(name, validator), gui_args
    else
        error("unsupported type")
    end
end

create_input_handler("priority", "number")
