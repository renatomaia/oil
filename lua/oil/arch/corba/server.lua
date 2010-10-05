local pairs = pairs

local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch"                                            --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.arch.corba.server"

RequestListener = component.Template{
	requests = port.Facet,
	codec = port.Receptacle,
	channels = port.Receptacle,
	servants = port.Receptacle,
	indexer = port.Receptacle,
}

function assemble(components)
	arch.start(components)
	
	ServerChannels.sockets = BasicSystem.sockets
	ServerChannels.dns = BasicSystem.dns
	
	RequestListener.codec = ValueEncoder.codec
	RequestListener.channels = ServerChannels.channels
	RequestListener.servants = ServantManager.servants -- get servant interface
	RequestListener.indexer = TypeRepository.indexer   -- get interface ops/types
	
	-- this optional dependency is to allow 'ObjectReferrer' to know the address
	-- the ORB is listening and identify local references (islocal) and create
	-- references to local servants (newreference).
	ObjectReferrer.listener = RequestListener.requests
	
	arch.finish(components)
end
