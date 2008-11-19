local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch"
local base      = require "oil.arch.base"                                       --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.arch.cooperative"

BasicSystem = component.Template({
	control = port.Facet,
	tasks   = port.Facet,
}, base.BasicSystem)

OperationInvoker = component.Template({
	mutex = port.Facet,
	tasks = port.Receptacle,
}, base.OperationInvoker)

RequestReceiver = component.Template({
	mutex = port.Facet,
	tasks = port.Receptacle,
}, base.RequestReceiver)

function assemble(components)
	arch.start(components)
	OperationInvoker.tasks = BasicSystem.tasks
	RequestReceiver.tasks  = BasicSystem.tasks
	arch.finish(components)
end
