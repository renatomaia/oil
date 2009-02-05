local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch"

module "oil.arch.ludo.byref"

ValueEncoder = component.Template{
	codec    = port.Facet,
	proxies  = port.Receptacle,
	servants = port.Receptacle,
}
