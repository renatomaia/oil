local port = require "oil.port"
local component = require "oil.component"

local module = {
	RequestListener = component.Template{
		requests = port.Facet,
		channels = port.Receptacle,
		codec    = port.Receptacle,
	},
}

function module.assemble(_ENV)
	ServerChannels.sockets = BasicSystem.sockets
	ServerChannels.dns = BasicSystem.dns
	
	ServantManager.listener = RequestListener.requests
	
	RequestListener.codec = ValueEncoder.codec
	RequestListener.channels = ServerChannels.channels
	
	-- this optional dependency is to allow 'ObjectReferrer' to know the address
	-- the ORB is listening and identify local references (islocal) and create
	-- references to local servants (newreference).
	ObjectReferrer.listener = RequestListener.requests
end

return module
