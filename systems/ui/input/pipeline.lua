local get_user_input = require 'systems.user_input'
local log = require 'utils.log'
local task_result = require 'systems.ui.input.task_result'

InputPipeline = {}
InputPipeline.__index = InputPipeline

function InputPipeline.new(handler, args)
    local pipeline = {}
    setmetatable(pipeline, InputPipeline)

    pipeline.tasks = {}
    pipeline.idx = 1
    pipeline.finally = nil
    pipeline:Then(handler, args)

    return pipeline
end

function InputPipeline:run_current_task(state)
    if not self.tasks then
	    return
    end

    local cur = self.tasks[self.idx]
    if cur then
	    cur(state)
    elseif self.finally then
	    self.finally(state)
    end
end

function InputPipeline:create_continuation(handler)
	return function(input, state)
		local result = handler(input, state)
		if result == task_result.next then
			self.idx = self.idx + 1
			self:run_current_task(state)
		elseif result == task_result.again then
			self:run_current_task()
		elseif result == task_result.again_invalid_data then
			log.notify("Invalid data.")
			self:run_current_task()
		elseif result == task_result.cancel then
			log.notify("Cancelled.")
		end
	end
end

function InputPipeline:then_(handler, gui_args)
	local continuation = self:create_continuation(handler)
	local task = function(state) get_user_input(function(input) continuation(input, state) end, gui_args) end
	table.insert(self.tasks, task)
end

function InputPipeline:finally(func)
	self.finally = func
end

return InputPipeline
