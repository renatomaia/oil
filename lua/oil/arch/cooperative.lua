local setfenv = setfenv

local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch.base"                                       --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.arch.cooperative"

BasicSystem = component.Template({
	control = port.Facet--[[
	]],
	tasks = port.Facet--[[
	]],
}, arch.BasicSystem)

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
		OperationInvoker.tasks = BasicSystem.tasks
	end
	if RequestReceiver then
		RequestReceiver.tasks = BasicSystem.tasks
	end
	if RequestDispatcher then
		-- define 'pcall' used in invocation dispatching.
		-- the function is retrieved by a method call because contained
		-- components cannot index functions that are not executed as methods.
		RequestDispatcher.dispatcher.pcall = BasicSystem.tasks:getpcall()
	end
end
