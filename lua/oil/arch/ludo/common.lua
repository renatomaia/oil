local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch"

module "oil.arch.ludo.common"

ValueEncoder = component.Template{ codec = port.Facet }
ObjectReferrer = component.Template{
	references = port.Facet,
	codec = port.Receptacle,
}

function assemble(components)
	arch.start(components)
	ValueEncoder.codec:localresources(components)
	ObjectReferrer.codec = ValueEncoder.codec
	arch.finish(components)
end
