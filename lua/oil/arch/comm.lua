local component = require "loop.component.base"
local port      = require "loop.component.base"

module "oil.arch.comm"

ProtocolType = component.Type{
	channels = port.Receptacle,
		-- channel create(<configs>)
	codec = port.Receptacle,
		-- encoder newencoder()
		-- decoder newdecoder()
}

InvokeProtocolType = component.Type({
	invoker = port.Facet,
		-- [reply] sendrequest(reference, operation, <parameters>)
		-- 	reply = {
		-- 		success, <results or error> :result(),
		-- 		boolean :probe()
		-- 	}
}, ProtocolType)

ListenProtocolType = component.Type({
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
}, ProtocolType)

TypedInvokeProtocolType = component.Type({
	interfaces = port.Receptacle,
		-- interface lookup(interfaceid)
}, InvokeProtocolType)

TypedListenProtocolType = component.Type({
	objects = port.Receptacle,
		-- interface typeof(objectid)
}, ListenProtocolType)

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
ProxyFactoryType = component.Type{
	proxies = port.Facet,
		-- proxy create(reference, protocol)
}

TypedProxyFactoryType = component.Type({
	interfaces = port.Receptacle,
		-- interface lookup(interfaceid)
		-- class getclass(interface)
}, ProxyFactoryType)

ClientBrokerType = component.Type{
	proxies = port.Facet,
		-- proxy create(textref, interfaceName)
	reference = port.Receptacle,
		-- reference resolve(textref)
	protocol = port.Receptacle,
		-- [reply] sendrequest(reference, operation, <parameters>)
	factory = port.Receptacle,
		-- proxy create(reference, protocol, interfaceName)
}

--- Object
AcceptorType = component.Type{
	manager = port.Facet,
		-- create(<configs>)
		-- info getinfo()
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

DispatcherType = component.Type{
	registry = port.Facet,
		-- register(id, object)
		-- object unregister(id)
	dispatcher = port.Facet,
		-- dispatch(request)
	tasks = port.Receptacle,
		-- start(function, ...)
}

TypedDispatcherType = component.Type({
	objects = port.Receptacle,
  -- interface typeof(objid) 

}, DispatcherType)

ServerBrokerType = component.Type{
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
	reference = port.Receptacle,
		-- textref referto(reference)
}

--- Interface

TypeManagerType = component.Type{
	registry = port.Facet,
		-- update(typeid, def)
		-- def lookup(typeid)
	mapping = port.Facet,
		-- settype(objectid, typeid)
		-- def typeof(objectid)
}

-------------------------------------
