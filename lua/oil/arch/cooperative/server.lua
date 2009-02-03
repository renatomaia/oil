local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch"
local base      = require "oil.arch.basic.server"                                --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.arch.cooperative.server"

RequestReceiver = component.Template({
	tasks = port.Receptacle,
}, base.RequestReceiver)

function assemble(components)
	arch.start(components)
	RequestReceiver.tasks  = BasicSystem.tasks
	-- define 'pcall' used in invocation dispatching.
	-- the function is retrieved by a method call because contained
	-- components cannot index functions that are not executed as methods.
	ServantManager.dispatcher.pcall = BasicSystem.tasks:getpcall()
	arch.finish(components)
end
