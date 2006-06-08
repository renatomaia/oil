local component = require "loop.component.base"
local port      = require "loop.component.base"

module "oil.arch.comm"

ProtocolType = component.Type{
	protocol = port.Facet,
		-- operations :
		--  call(reference, operation, ...)
		--  handle(reference, operation, ...)
	
	codec = port.Receptacle,
		-- optional receptacles
	channelFactory = port.Receptacle,
	error_handling = port.Receptacle  
}

CORBAProtocolType = component.Type({
	iop = port.Receptacle,
	
	protocolHelper = port.Facet, -- TODO: change this name! 
		-- unmarshallHeader( stream ) 
}, ProtocolType)

IOPType = component.Type{
	iop = port.Facet, 
		-- operations
		--  connect(reference)
		--  listen(network_endpoint)
	channelFactory = port.Receptacle,
	protocolHelper = port.Receptacle, 
}

CodecType = component.Type{
	codec = port.Facet,
		-- operations :
		--  newEncoder()
		--  newDecoder()
}

ChannelFactoryType = component.Type{
	factory = port.Facet,
		-- operations :
		--  connect()
		--  send()
		--  receive()
	-- api do luasocket
}

ConnResolverType = component.Type{
	connector = port.Facet,
		-- operations :
		--  call( profile, operation, args)
	protocols = port.HashReceptacle,
--  codecs    = "context receptacle",
--  connmanager   = "receptacle",
	references = port.HashReceptacle, -- to get the references to the objects / open profiles etc
}

SchedulerType = component.Type{
	control = port.Facet,
	threads = port.Facet,
	sockets = port.Facet,
}

ResolverType = component.Type{
	codec = port.Facet,
}

--- Reference
ReferenceHandlerType = component.Type{
		reference = port.Facet,
		reference_resolver = port.HashReceptacle,
		profile_resolver   = port.HashReceptacle,
}

ReferenceResolverType = component.Type{
		resolver = port.Facet,
		codec = port.Receptacle,
		-- optional receptacles
		profile_resolver = port.Receptacle,
}

ProfileResolverType = component.Type{
		resolver = port.Facet, 
		codec = port.Receptacle,
}

--- Invocation
ProxyType = component.Type{
		proxy = port.Facet,
		protocol = port.Receptacle,
		reference_handler = port.Receptacle
}

--- Object
AccessPointType = component.Type{
	point = port.Facet,
		-- operations :
		--  listen(args)
	protocol = port.HashReceptacle, 
}

DispatcherType = component.Type{
		acceptor = port.Facet,
		point    = port.Receptacle,
		protocol = port.Receptacle,
		reference_handler = port.Receptacle,
}

--- Interface

ManagerType = component.Type{
	manager = port.Facet,
	proxy = port.Receptacle,
	ir    = port.Receptacle,
}
InterfaceRepositoryType = component.Type{
	ir = port.Facet,
	proxy = port.Receptacle,
}

-------------------------------------
