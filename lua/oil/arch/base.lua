local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch"

module "oil.arch.base"

-- UNDERPINNINGS
SocketChannels = component.Template{
	channels = port.Facet,
	sockets = port.Receptacle,
}
BasicSystem = component.Template{
	sockets = port.Facet,
}

-- CLIENT SIDE
ClientBroker = component.Template{
	broker     = port.Facet,
	proxies    = port.Receptacle,
	references = port.Receptacle,
}
ObjectProxies = component.Template{
	proxies = port.Facet,
	invoker = port.Receptacle,
}
OperationInvoker = component.Template{
	invoker   = port.Facet,
	requester = port.Receptacle,
}

-- SERVER SIDE
ServerBroker = component.Template{
	broker     = port.Facet,
	objects    = port.Receptacle,
	acceptor   = port.Receptacle,
	references = port.Receptacle,
}
RequestDispatcher = component.Template{
	objects    = port.Facet,
	dispatcher = port.Facet,
}
RequestReceiver = component.Template{
	acceptor   = port.Facet,
	dispatcher = port.Receptacle,
	listener   = port.Receptacle,
}

function assemble(components)
	arch.start(components)
	
	-- CLIENT SIDE
	OperationInvoker.requester = OperationRequester.requests
	ObjectProxies.invoker      = OperationInvoker.invoker
	ClientBroker.proxies       = ObjectProxies.proxies
	ClientBroker.references    = ObjectReferrer.references

	-- SERVER SIDE
	RequestReceiver.listener   = RequestListener.listener
	RequestReceiver.dispatcher = RequestDispatcher.dispatcher
	ServerBroker.objects       = RequestDispatcher.objects
	ServerBroker.acceptor      = RequestReceiver.acceptor
	ServerBroker.references    = ObjectReferrer.references
	
	-- define 'pcall' used in invocation dispatching.
	-- the function is retrieved by a method call because contained
	-- components cannot index functions that are not executed as methods.
	RequestDispatcher.pcall = BasicSystem.pcall
	
	arch.finish(components)
end
