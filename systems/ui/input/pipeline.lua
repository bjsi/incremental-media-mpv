local get_user_input = require 'systems.user_input'
local log = require 'utils.log'
local task_result = require 'systems.ui.input.task_result'

InputPipeline = {}
InputPipeline.__index = InputPipeline

function InputPipeline.new(run_if, handler, args)
    local pipeline = {}
    setmetatable(pipeline, InputPipeline)

    pipeline.tasks = {}
    pipeline.idx = 1
    pipeline.finally = nil
    pipeline:then_(run_if, handler, args)

    return pipeline
end

function InputPipeline:run(state)
    if not self.tasks then return end
    local cur = self.tasks[self.idx]
    if cur then
   	local task = cur["task"]
	local run_if = cur["run_if"]
	if run_if ~= nil then
		if not run_if(state) then
			self.idx = self.idx + 1
			self:run(state)
			return
		else
			task(state)
		end
	else
		task(state)
	end
    elseif self.finally then
   	local task = self.finally["task"]
	local run_if = self.finally["run_if"]
	if run_if ~= nil then
		if run_if(state) then
			task(state)
		end
	else
		task(state)
	end
    end
end

function InputPipeline:create_continuation(handler)
    return function(input, state)
        local result = handler(input, state)
        if result == task_result.next then
            self.idx = self.idx + 1
            self:run(state)
        elseif result == task_result.again then
            self:run(state)
        elseif result == task_result.again_invalid_data then
            log.notify("Invalid data.")
            self:run(state)
        elseif result == task_result.cancel then
            log.notify("Cancelled.")
        end
    end
end

function InputPipeline:then_(run_if, handler, gui_args)
    local continuation = self:create_continuation(handler)
    local task = function(state)
        get_user_input(function(input) continuation(input, state) end, gui_args)
    end
    table.insert(self.tasks, {task=task, run_if=run_if})
end

function InputPipeline:finally(func) self.finally = func end

return InputPipeline
