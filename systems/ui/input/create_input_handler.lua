local task_result = require 'systems.ui.input.task_result'
local ivl = require 'utils.interval'
local obj = require 'utils.object'
local pri = require 'utils.priority'
local str = require 'utils.str'

local function create_gui_args(name, title)
    if not title then title = str.capitalize_first(name) .. ": " end
    return {text = title, replace = true}
end

local function create_yn_gui_args(default, name, title)
    if not title then title = str.capitalize_first(name) .. ": " end
    if default == "y" then
        title = title .. " ([y]/n)"
    elseif default == "n" then
        title = title .. " (y/[n])"
    else
        title = title .. " (y/n)"
    end
    return {text = title, replace = true}
end

local function yesno_input_handler(name, default, state_setter, title)
    local handler = function(input, state)
        if input == nil then return task_result.cancel end
        if input == "" then input = default end
        if input ~= "y" and input ~= "n" then
            return task_result.cancel
        else
            if state_setter then
                state_setter(input, state)
            else
                state[name] = input == "y"
            end
            return task_result.next
        end
    end
    return handler, create_yn_gui_args(default, name, title)
end

local function string_input_handler(name, validator, state_setter, title)
    local handler = function(input, state)
        if input == nil then return task_result.cancel end

        if validator then
            if not validator(input) then
                return task_result.again_invalid_data
            end
        else
            if obj.empty(input) then
                return task_result.again_invalid_data
            end
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

local function number_input_handler(name, validator, state_setter, title)
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

local function priority_range_input_handler()
    local validator = function(input)
        local min, max = input:gmatch("(%d+)%s*-%s*(%d+)")()
        min = tonumber(min)
        max = tonumber(max)

        if not pri.validate(min) or not pri.validate(max) or min > max then
            return false
        end
        return true
    end

    local state_setter = function(input, state)
        local min, max = input:gmatch("(%d+)%s*-%s*(%d+)")()
        min = tonumber(min)
        max = tonumber(max)
        state["priority-min"] = min
        state["priority-max"] = max
    end

    return string_input_handler(nil, validator, state_setter,
                                "Priority Range (eg. 5-20): ")
end

-- LuaFormatter off
return {
    number = number_input_handler,
    string = string_input_handler,
    yn = yesno_input_handler,
    priority = function() return number_input_handler("priority",
				 function(n) return pri.validate(n) end,
				 nil,
				 "Priority (0-100): ")
	       end,
   priority_range = priority_range_input_handler,
   interval = function() return number_input_handler("interval",
   				function(n) return ivl.validate(n) end,
			        nil,
			        "Interval (> 0): ")
			 end,
   confirm = function() return yesno_input_handler("confirm", "y", nil, nil)
	     end,
}
-- LuaFormatter on
