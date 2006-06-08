local component = require "loop.component.base"

module "oil.arch.comm"

ProtocolType = component.Type{
	protocol = component.Facet,
		-- operations :
		--  call(reference, operation, ...)
		--  handle(reference, operation, ...)
	
	codec = component.Receptacle,
		-- optional receptacles
	channelFactory = component.Receptacle,
	error_handling = component.Receptacle  
}

CORBAProtocolType = component.Type{ ProtocolType,
	iop = component.Receptacle,
	
	protocolHelper = component.Facet, -- TODO: change this name! 
		-- unmarshallHeader( stream ) 
}

IOPType = component.Type{
	iop = component.Facet, 
		-- operations
		--  connect(reference)
		--  listen(network_endpoint)
	channelFactory = component.Receptacle,
	protocolHelper = component.Receptacle, 
}

CodecType = component.Type{
	codec = component.Facet,
		-- operations :
		--  newEncoder()
		--  newDecoder()
}

ChannelFactoryType = component.Type{
	factory = component.Facet,
		-- operations :
		--  connect()
		--  send()
		--  receive()
	-- api do luasocket
}

ConnResolverType = component.Type{
	connector = component.Facet,
		-- operations :
		--  call( profile, operation, args)
	protocols = component.HashReceptacle,
--  codecs    = "context receptacle",
--  connmanager   = "receptacle",
	references = component.HashReceptacle, -- to get the references to the objects / open profiles etc
}

SchedulerType = component.Type{
	control = component.Facet,
	threads = component.Facet,
	sockets = component.Facet,
}

ResolverType = component.Type{
	codec = component.Facet,
}

--- Reference
ReferenceHandlerType = component.Type{
		reference = component.Facet,
		reference_resolver = component.HashReceptacle,
		profile_resolver   = component.HashReceptacle,
}

ReferenceResolverType = component.Type{
		resolver = component.Facet,
		codec = component.Receptacle,
		-- optional receptacles
		profile_resolver = component.Receptacle,
}

ProfileResolverType = component.Type{
		resolver = component.Facet, 
		codec = component.Receptacle,
}

--- Invocation
ProxyType = component.Type{
		proxy = component.Facet,
		protocol = component.Receptacle,
		reference_handler = component.Receptacle
}

--- Object
AccessPointType = component.Type{
	point = component.Facet,
		-- operations :
		--  listen(args)
	protocol = component.HashReceptacle, 
}

DispatcherType = component.Type{
		acceptor = component.Facet,
		point    = component.Receptacle,
		protocol = component.Receptacle,
		reference_handler = component.Receptacle,
}

--- Interface

ManagerType = component.Type{
	manager = component.Facet,
	proxy = component.Receptacle,
	ir    = component.Receptacle,
}
InterfaceRepositoryType = component.Type{
	ir = component.Facet,
	proxy = component.Receptacle,
}

-------------------------------------
