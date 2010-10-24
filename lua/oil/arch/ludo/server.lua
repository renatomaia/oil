local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch"

module "oil.arch.ludo.server"

RequestListener = component.Template{
	requests = port.Facet,
	channels = port.Receptacle,
	codec    = port.Receptacle,
}

function assemble(components)
	arch.start(components)
	
	ServerChannels.sockets = BasicSystem.sockets
	ServerChannels.dns = BasicSystem.dns
	
	RequestListener.codec = ValueEncoder.codec
	RequestListener.channels = ServerChannels.channels
	
	-- this optional dependency is to allow 'ObjectReferrer' to know the address
	-- the ORB is listening and identify local references (islocal) and create
	-- references to local servants (newreference).
	ObjectReferrer.listener = RequestListener.requests
	
	arch.finish(components)
end
