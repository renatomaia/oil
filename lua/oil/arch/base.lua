local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch"

module "oil.arch.base"

-- UNDERPINNINGS
SocketChannels = component.Template{
	channels = port.Facet,
	sockets  = port.Receptacle,
}
BasicSystem = component.Template{
	sockets = port.Facet,
}

-- CLIENT SIDE
ProxyManager = component.Template{
	proxies    = port.Facet,
	requester  = port.Receptacle,
	references = port.Receptacle,
}

-- SERVER SIDE
ServantManager = component.Template{
	servants   = port.Facet,
	dispatcher = port.Facet,
	references = port.Receptacle,
}
RequestReceiver = component.Template{
	acceptor   = port.Facet,
	dispatcher = port.Receptacle,
	listener   = port.Receptacle,
}

function assemble(components)
	arch.start(components)
	
	-- CLIENT SIDE
	ProxyManager.requester  = OperationRequester.requests
	ProxyManager.references = ObjectReferrer.references

	-- SERVER SIDE
	RequestReceiver.listener   = RequestListener.listener
	RequestReceiver.dispatcher = ServantManager.dispatcher
	ServantManager.references  = ObjectReferrer.references
	
	arch.finish(components)
end
