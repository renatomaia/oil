local port = require "oil.port"
local component = require "oil.component"

local module = {
	ValueEncoder = component.Template{
		codec = port.Facet,
		proxies = port.Receptacle,
		servants = port.Receptacle,
	},
}

function module.assemble(_ENV)
	ValueEncoder.proxies = proxykind[ proxykind[1] ].proxies
	ValueEncoder.servants = ServantManager.servants
end

return module
