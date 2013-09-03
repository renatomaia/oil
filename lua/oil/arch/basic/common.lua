local port = require "oil.port"
local component = require "oil.component"

return {
	SocketChannels = component.Template{
		channels = port.Facet,
		sockets = port.Receptacle,
		dns = port.Receptacle,
	},
	BasicSystem = component.Template{
		sockets = port.Facet,
		dns = port.Facet,
	},
}
