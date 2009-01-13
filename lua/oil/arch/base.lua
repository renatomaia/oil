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
	proxies   = port.Facet,
	requester = port.Receptacle,
	referrer  = port.Receptacle,
	servants  = port.Receptacle,
}

-- SERVER SIDE
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
	
	-- CLIENT SIDE
	ProxyManager.requester = OperationRequester.requests
	ProxyManager.referrer  = ObjectReferrer.references
	ProxyManager.servants  = ServantManager.servants

	-- SERVER SIDE
	ServantManager.referrer    = ObjectReferrer.references
	RequestReceiver.dispatcher = ServantManager.dispatcher
	RequestReceiver.listener   = RequestListener.requests
	
	arch.finish(components)
end
