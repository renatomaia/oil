local pairs   = pairs
local setfenv = setfenv
local type    = type

local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch.typed"                                      --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.arch.corba"

--
-- COMMUNICATION
--
SocketChannels = component.Template{
	channels = port.Facet--[[
		channel:object retieve(configs:table)
		configs:table default(configs:table)
	]],
	sockets = port.Receptacle--[[
		socket:object tcp()
		input:table, output:table select([input:table], [output:table], [timeout:number])
	]],
}

ValueEncoder = component.Template{
	codec = port.Facet--[[
		encoder:object encoder()
		decoder:object decoder(stream:string)
	]],
	proxies = port.Receptacle--[[
		reference:table proxyto(ior:table, iface:table|string)
	]],
	objects = port.Receptacle--[[
		configs:table
		reference:table register(impl:object, iface:table|string)
		impl:object retrieve(key:string)
	]],
	profiler = port.HashReceptacle--[[
		objkey:string belongsto(profile:string, orbcfg:table)
	]],
}

--
-- REFERENCES
--
ReferenceProfiler = component.Template{
	profiler = port.Facet--[[
		stream:string encode(profile:table, [version:number])
		profile:table decode(stream:string)
		objkey:string belongsto(profile:string, orbcfg:table)
		result:boolean equivalent(profile1:string, profile2:string)
		profile:table decodeurl(url:string)
	]],
	codec = port.Receptacle--[[
		encoder:object encoder([encapsulated:boolean])
		decoder:object decoder(stream:string, [encapsulated:boolean])
	]],
}

ObjectReferrer = component.Template{
	references = port.Facet--[[
		reference:table referenceto(objectkey:string, accesspointinfo:table...)
		reference:string encode(reference:table)
		reference:table decode(reference:string)
	]],
	codec = port.Receptacle--[[
		encoder:object encoder()
		decoder:object decoder(stream:string)
	]],
	profiler = port.HashReceptacle--[[
		profile:table decodeurl(data:string)
		data:string encode(objectkey:string, acceptorinfo:table)
	]],
	types = port.Receptacle--[[
		interface:table typeof(objectkey:string)
	]],
}

--
-- MESSENGER
--

MessageMarshaler = component.Template{
	messenger = port.Facet--[[
		success:booelan, [except:table] = sendmsg(channel:object, type:number, header:table, types:table, values...)
		type:number, header:table, decoder:object = receivemsg(channel:object , [wait:boolean])
	]],
	codec = port.Receptacle--[[
		encoder:object encoder()
		decoder:object decoder(stream:string)
	]],
}

--
-- REQUESTER
--

OperationRequester = component.Template{
	requests = port.Facet--[[
		channel:object getchannel(reference:table)
		reply:object, [except:table], [requests:table] newrequest(channel:object, reference:table, operation:table, args...)
		reply:object, [except:table], [requests:table] getreply(channel:object, [probe:boolean])
	]],
	messenger = port.Receptacle--[[
		success:booelan, [except:table] = sendmsg(channel:object, type:number, header:table, types:table, values...)
		type:number, header:table, decoder:object = receivemsg(channel:object , [wait:boolean])
	]],
	channels = port.HashReceptacle--[[
		channel:object retieve(configs:table)
	]],
	profiler = port.HashReceptacle--[[
		info:table decode(stream:string)
	]],
	mutex = port.Receptacle--[[
		locksend(channel:object)
		freesend(channel:object)
	]],
}

ProxyIndexer = component.Template{
	indexer = port.Facet--[[
		interface:table typeof(reference:table)
		member:table, [islocal:function], [cached:boolean] valueof(interface:table, name:string)
	]],
	members = port.Receptacle--[[
		member:table valueof(interface:table, name:string)
	]],
	invoker = port.Receptacle--[[
		[results:object], [except:table] invoke(reference:table, operation:table, args...)
	]],
	profiler = port.HashReceptacle--[[
		result:boolean equivalent(profile1:string, profile2:string)
	]],
	types = port.Receptacle--[[
		[type:table] register(definition:object)
		[type:table] resolve(type:string)
		[type:table] lookup_id(repid:string)
	]],
}

--
-- LISTENER
--
RequestListener = component.Template{
	listener = port.Facet--[[
		configs:table default([configs:table])
		channel:object, [except:table] getchannel(configs:table)
		request:object, [except:table], [requests:table] = getrequest(channel:object, [probe:boolean])
	]],
	messenger = port.Receptacle--[[
		success:booelan, [except:table] = sendmsg(channel:object, type:number, header:table, types:table, values...)
		type:number, header:table, decoder:object = receivemsg(channel:object , [wait:boolean])
	]],
	channels = port.HashReceptacle--[[
		channel:object retieve(configs:table)
	]],
	indexer = port.Receptacle--[[
		interface:table typeof(objectkey:string)
		[member:table], [value:function] valueof(interface:object, membername:string)
	]],
	mutex = port.Receptacle--[[
		locksend(channel:object)
		freesend(channel:object)
	]],
}

ServantIndexer = component.Template{
	indexer = port.Facet--[[
		inteface:object typeof(objectkey:string)
		[member:table], [value:function] valueof(interface:object, membername:string)
	]],
	mapper = port.Facet--[[
		interface:table register(key:string, interface:table)
	]],
	members = port.Receptacle--[[
		member:table valueof(interface:table, name:string)
	]],
}

--
-- TYPES
--
TypeRepository = component.Template({
	--[[ extended interface of 'types':
		type:table register(definition:table)
		type:table remove(definition:table)
		type:table resolve(type:string)
		[type:table] lookup(name:string)
		[type:table] lookup_id(repid:string)
	]]
	registry = port.Facet--[[
		type:table register(definition:table)
		type:table remove(definition:table)
		type:table resolve(type:string)
		[type:table] lookup(name:string)
		[type:table] lookup_id(repid:string)
	]],
	indexer = port.Facet--[[
		[interface:table] typeof(name:string)
		member:table valueof(interface:table, name:string)
	]],
	compiler = port.Facet--[[
		success:boolean, [except:table] load(idl:string)
		success:boolean, [except:table] loadfile(filepath:string)
	]],
	delegated = port.Receptacle--[[
		[type:table] lookup(name:string)
		[type:table] lookup_id(repid:string)
	]],
}, arch.TypeRepository)

function assemble(components)
	setfenv(1, components)
	-- COMMUNICATION
	if ClientChannels then
		for tag, channels in pairs(ClientChannels) do
			channels.sockets = OperatingSystem.sockets
		end
	end
	if ServerChannels then
		for tag, channels in pairs(ServerChannels) do
			channels.sockets = OperatingSystem.sockets
		end
	end
	if ValueEncoder then
		ValueEncoder.proxies = ClientBroker and ClientBroker.broker
		ValueEncoder.objects = ServerBroker and ServerBroker.broker
		if ReferenceProfilers then
			for tag, profiler in pairs(ReferenceProfilers) do
				ValueEncoder.profiler[tag] = profiler.profiler
			end
		end
	end
	-- REFERENCES
	if ObjectReferrer then
		ObjectReferrer.codec = ValueEncoder.codec
		ObjectReferrer.types = ServantIndexer.indexer
		if ReferenceProfilers then
			for tag, profiler in pairs(ReferenceProfilers) do
				ObjectReferrer.profiler[tag] = profiler.profiler
			end
		end
	end
	if ReferenceProfilers then
		for tag, profiler in pairs(ReferenceProfilers) do
			profiler.codec = ValueEncoder.codec
		end
	end
	-- MESSENGER
	if MessageMarshaler then
		MessageMarshaler.codec = ValueEncoder.codec
	end
	-- REQUESTER
	if OperationRequester then
		OperationRequester.messenger = MessageMarshaler.messenger
		OperationRequester.mutex = OperationInvoker and
		                           OperationInvoker.mutex
		if ReferenceProfilers then
			for tag, profiler in pairs(ReferenceProfilers) do
				if type(tag) == "number" then
					OperationRequester.profiler[tag] = profiler.profiler
				end
			end
		end
		if ClientChannels then
			for tag, channels in pairs(ClientChannels) do
				OperationRequester.channels[tag] = channels.channels
			end
		end
	end
	if ProxyIndexer then
		ProxyIndexer.members = TypeRepository.indexer
		ProxyIndexer.invoker = OperationInvoker.invoker
		ProxyIndexer.types = TypeRepository.types
		if ReferenceProfilers then
			for tag, profiler in pairs(ReferenceProfilers) do
				if type(tag) == "number" then
					ProxyIndexer.profiler[tag] = profiler.profiler
				end
			end
		end
	end
	-- LISTENER
	if RequestListener then
		RequestListener.messenger = MessageMarshaler.messenger
		RequestListener.indexer = ServantIndexer.indexer
		RequestListener.mutex = RequestReceiver and
		                        RequestReceiver.mutex
		if ServerChannels then
			for tag, channels in pairs(ServerChannels) do
				RequestListener.channels[tag] = channels.channels
			end
		end
	end
	if ServantIndexer then
		ServantIndexer.members = TypeRepository.indexer
	end
end
