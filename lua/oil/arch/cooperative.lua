local setfenv = setfenv

local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch.base"                                       --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.arch.cooperative"

TaskManager = component.Template({
	control = port.Facet--[[
	]],
	tasks = port.Facet--[[
	]],
}, arch.OperatingSystem)

OperationInvoker = component.Template({
	mutex = port.Facet--[[
		locksend(channel:object)
		freesend(channel:object)
		lockreceive(channel:object, request:table, [probe:boolean])
	]],
	tasks = port.Receptacle--[[
		current:thread
		suspend()
		resume(thread:thread)
		register(thread:thread)
	]],
}, arch.OperationInvoker)

RequestReceiver = component.Template({
	mutex = port.Facet--[[
		locksend(channel:object)
		freesend(channel:object)
		lockreceive(channel:object)
	]],
	tasks = port.Receptacle--[[
		current:thread
		start(func:function, args...)
		suspend()
		resume(thread:thread)
		register(thread:thread)
	]],
}, arch.RequestReceiver)

function assemble(components)
	setfenv(1, components)
	--
	-- Client side
	--
	if OperationInvoker then
		OperationInvoker.tasks = TaskManager.tasks
	end
	if RequestReceiver then
		RequestReceiver.tasks = TaskManager.tasks
	end
	if RequestDispatcher then
		-- define 'pcall' used in invocation dispatching.
		-- operation is done over segments because contained components cannot
		-- index functions that are not executed as methods.
		local dispather = component.segmentof(RequestDispatcher, "dispatcher")
		local tasks     = component.segmentof(TaskManager, "tasks")
		dispather.pcall = tasks.pcall
	end
end
