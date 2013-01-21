local port = require "oil.port"
local component = require "oil.component"

local module = {
	OperationRequester = component.Template{
		requests = port.Facet,
		channels = port.Receptacle,
		codec = port.Receptacle,
	},
}

function module.assemble(_ENV)
	ClientChannels.sockets = BasicSystem.sockets
	ClientChannels.dns = BasicSystem.dns
	OperationRequester.codec = ValueEncoder.codec
	OperationRequester.channels = ClientChannels.channels
end

return module
