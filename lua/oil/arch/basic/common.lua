local port      = require "oil.port"
local component = require "oil.component"

module "oil.arch.basic.common"

-- UNDERPINNINGS
SocketChannels = component.Template{
	channels = port.Facet,
	sockets  = port.Receptacle,
	dns  = port.Receptacle,
}
BasicSystem = component.Template{
	sockets = port.Facet,
	dns = port.Facet,
}
