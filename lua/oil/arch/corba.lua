local pairs = pairs

local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch"
local base      = require "oil.arch.typed"
local sysex     = require "oil.corba.idl.sysex"                                 --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.arch.corba"

-- TYPES
TypeRepository = component.Template({
	registry  = port.Facet,
	indexer   = port.Facet,
	compiler  = port.Facet,
	delegated = port.Receptacle,
}, base.TypeRepository)

-- MARSHALING
ValueEncoder = component.Template{
	codec    = port.Facet,
	proxies  = port.Receptacle,
	objects  = port.Receptacle,
	profiler = port.HashReceptacle,
}

-- REFERENCES
ReferenceProfiler = component.Template{
	profiler = port.Facet,
	codec    = port.Receptacle,
}
ObjectReferrer = component.Template{
	references = port.Facet,
	codec      = port.Receptacle,
	servants   = port.Receptacle,
	requester  = port.Receptacle,
	profiler   = port.HashReceptacle,
}

-- MESSENGER
MessageMarshaler = component.Template{
	messenger = port.Facet,
	codec     = port.Receptacle,
}

-- REQUESTER
OperationRequester = component.Template{
	requests  = port.Facet,
	messenger = port.Receptacle,
	channels  = port.HashReceptacle,
	profiler  = port.HashReceptacle,
	mutex     = port.Receptacle,
}

-- LISTENER
RequestListener = component.Template{
	listener   = port.Facet,
	messenger  = port.Receptacle,
	channels   = port.HashReceptacle,
	dispatcher = port.Receptacle,
	indexer    = port.Receptacle,
	mutex      = port.Receptacle,
}

function assemble(components)
	arch.start(components)
	
	-- GIOP MAPPINGS
	local IOPClientChannels  = { [0] = ClientChannels }
	local IOPServerChannels  = { [0] = ServerChannels }
	local ReferenceProfilers = {
		[0]  = IIOPProfiler,
		[""] = IIOPProfiler,
		iiop = IIOPProfiler,
	}
	
	-- IDL DEFINITIONS
	TypeRepository.types:register(sysex)
	
	-- MARSHALING
	ValueEncoder.proxies   = ProxyManager.proxies
	ValueEncoder.servants  = ServantManager.servants
	MessageMarshaler.codec = ValueEncoder.codec

	-- REQUESTER
	OperationRequester.messenger = MessageMarshaler.messenger

	-- LISTENER
	RequestListener.messenger  = MessageMarshaler.messenger
	RequestListener.dispatcher = ServantManager.dispatcher
	RequestListener.indexer    = TypeRepository.indexer
	
	-- COMMUNICATION
	for tag, ClientChannels in pairs(IOPClientChannels) do
		ClientChannels.sockets           = BasicSystem.sockets
		OperationRequester.channels[tag] = ClientChannels.channels
	end
	for tag, ServerChannels in pairs(IOPServerChannels) do
		ServerChannels.sockets        = BasicSystem.sockets
		RequestListener.channels[tag] = ServerChannels.channels
	end
	
	-- REFERENCES
	ObjectReferrer.codec      = ValueEncoder.codec
	ObjectReferrer.servants   = ServantManager.dispatcher
	ObjectReferrer.requester  = OperationRequester.requests
	for tag, ReferenceProfiler in pairs(ReferenceProfilers) do
		ReferenceProfiler.codec          = ValueEncoder.codec
		ValueEncoder.profiler[tag]       = ReferenceProfiler.profiler
		ObjectReferrer.profiler[tag]     = ReferenceProfiler.profiler
		OperationRequester.profiler[tag] = ReferenceProfiler.profiler
	end
	
	arch.finish(components)
end
