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
	sockets = port.Facet--[[
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
		RequestDispatcher.pcall = TaskManager.pcall
	end
end
