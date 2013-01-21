local port = require "oil.port"
local component = require "oil.component"

local module = {
	RequestListener = component.Template{
		requests = port.Facet,
		codec = port.Receptacle,
		channels = port.Receptacle,
		servants = port.Receptacle,
		indexer = port.Receptacle,
	},
}

function module.assemble(_ENV)
	ValueEncoder.servants = ServantManager.servants
	
	ServerChannels.sockets = BasicSystem.sockets
	ServerChannels.dns = BasicSystem.dns
	
	ServantManager.listener = RequestListener.requests
	
	RequestListener.codec = ValueEncoder.codec
	RequestListener.channels = ServerChannels.channels
	RequestListener.servants = ServantManager.servants -- to answer LocateRequest
	RequestListener.indexer = TypeRepository.indexer   -- get interface ops/types
	RequestListener.requester = OperationRequester.requests -- BiDir GIOP
	RequestListener.serviceencoder = IIOPProfiler.profiler -- BiDir GIOP
	RequestListener.servicedecoder = IIOPProfiler.profiler -- BiDir GIOP
	
	-- this optional dependency is to allow 'ObjectReferrer' to know the address
	-- the ORB is listening and identify local references (islocal) and create
	-- references to local servants (newreference).
	ObjectReferrer.listener = RequestListener.requests
end

return module
