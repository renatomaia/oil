local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch"

module "oil.arch.ludo.common"

ValueEncoder   = component.Template{ codec = port.Facet }
ObjectReferrer = component.Template{ references = port.Facet }

function assemble(components)
	arch.start(components)
	LuaEncoder.codec:localresources(components)
	arch.finish(components)
end
