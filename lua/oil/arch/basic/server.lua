local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch"                                            --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.arch.basic.server"

ServantManager = component.Template{
	servants   = port.Facet,
	dispatcher = port.Facet,
	referrer   = port.Receptacle,
}
RequestReceiver = component.Template{
	acceptor   = port.Facet,
	dispatcher = port.Receptacle,
	listener   = port.Receptacle,
}

function assemble(components)
	arch.start(components)
	ServantManager.referrer    = ObjectReferrer.references
	RequestReceiver.dispatcher = ServantManager.dispatcher
	RequestReceiver.listener   = RequestListener.requests
	
	-- define 'pcall' used in invocation dispatching.
	-- the function is retrieved by a method call because contained
	-- components cannot index functions that are not executed as methods.
	ServantManager.dispatcher.pcall = BasicSystem:getpcall()
	arch.finish(components)
end
