local component = require "loop.component.base"
local port      = require "loop.component.base"

module "oil.arch.comm"

Protocol = component.Type{
	channels = port.Receptacle,
		-- channel create(<configs>)
	codec = port.Receptacle,
		-- encoder newencoder()
		-- decoder newdecoder()
}

InvokeProtocol = component.Type({
	invoker = port.Facet,
		-- [reply] sendrequest(reference, operation, <parameters>)
		-- 	reply = {
		-- 		success, <results or error> :result(),
		-- 		boolean :probe()
		-- 	}
}, Protocol)

ListenProtocol = component.Type({
	listener = port.Facet,
		-- channel getchannel(<configs>)
		-- request getrequest(channel)
		-- 	request = {
		-- 		objectid = "Object Identifier",
		-- 		operation = "operation name",
		-- 		paramcount = <number of parameters>,
		-- 		[1] = <first parameter>,
		-- 		[2] = <second parameter>,
		-- 		...
		-- 		
		-- 		:reply(success, <results or error>)
		-- 	}
		-- 
}, Protocol)

TypedInvokeProtocol = component.Type({
	interfaces = port.Receptacle,
		-- interface lookup(interfaceid)
}, InvokeProtocol)

TypedListenProtocol = component.Type({
	objects = port.Receptacle,
		-- interface typeof(objectid)
}, ListenProtocol)

CodecType = component.Type{
	codec = port.Facet,
		-- operations :
		--  newEncoder()
		--  newDecoder()
}

ChannelFactoryType = component.Type{
	factory = port.Facet,
		-- channel create(<configs>)
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
ReferenceResolverType = component.Type{
		resolver = port.Facet,
		codec = port.Receptacle,
}

--- Invocation
ProxyFactory = component.Type{
	proxies = port.Facet,
		-- proxy create(reference, protocol)
}

TypedProxyFactory = component.Type({
	interfaces = port.Receptacle,
		-- interface lookup(interfaceid)
}, ProxyFactory)

ClientBroker = component.Type{
	proxies = port.Facet,
		-- proxy create(textref)
	reference = port.Receptacle,
		-- reference resolve(textref)
	protocol = port.Receptacle,
		-- [reply] sendrequest(reference, operation, <parameters>)
	factory = port.Receptacle,
		-- proxy create(reference, protocol)
}

--- Object
Acceptor = component.Type{
	manager = port.Facet,
		-- acceptall()
		-- accept()
		-- boolean pending()
	listener = port.Receptacle,
		-- channel getchannel(<configs>)
		-- request getrequest(channel)
	dispatcher = port.Receptacle,
		-- dispatch(request)
	tasks = port.Receptacle,
		-- start(function, ...)
}

Dispatcher = component.Type{
	registry = port.Facet,
		-- register(id, object)
		-- object unregister(id)
	dispatcher = port.Facet,
		-- dispatch(request)
	tasks = port.Receptacle,
		-- start(function, ...)
}

TypedDispacher = component.Type({
	objects = port.Receptacle,
  -- interface typeof(objid) 

}, Dispatcher)

ServerBroker = component.Type{
	registry = port.Facet,
		-- servant register(object, [id])
		-- object unregister(servant)
		-- textref tostring(servant)
	control = port.Facet,
		-- run()
		-- step()
		-- boolean pending()
	ports = port.ListReceptacle,
		-- acceptall()
		-- accept()
		-- boolean pending()
	objectmap = port.Receptacle,
		-- register(id, object)
		-- object unregister(id)
	referee = port.Receptacle,
		-- textref referto(reference)
}

--- Interface

TypeManager = component.Type{
	registry = port.Facet,
		-- update(typeid, def)
		-- def lookup(typeid)
	mapping = port.Facet,
		-- settype(objectid, typeid)
		-- def typeof(objectid)
}

-------------------------------------
