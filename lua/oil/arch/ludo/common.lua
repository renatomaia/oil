local port = require "oil.port"
local component = require "oil.component"

local module = {
	ValueEncoder = component.Template{ codec = port.Facet },
	ObjectReferrer = component.Template{
		references = port.Facet,
		codec = port.Receptacle,
	},
}

function module.assemble(_ENV)
	ValueEncoder.codec:localresources(_ENV)
	ObjectReferrer.codec = ValueEncoder.codec
end

return module
