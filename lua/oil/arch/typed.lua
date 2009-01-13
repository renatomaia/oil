local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch"
local base      = require "oil.arch.base"

module "oil.arch.typed"

-- TYPES
TypeRepository = component.Template{
	types   = port.Facet,
	indexer = port.Facet,
}

-- CLIENT SIDE
ProxyManager = component.Template({
	types   = port.Receptacle,
	indexer = port.Receptacle,
	caches  = port.Facet, -- TODO:[maia] use it to reset method cache when type
}, base.ProxyManager)   --             definition changes.

-- SERVER SIDE
ServantManager = component.Template({
	types   = port.Receptacle,
	indexer = port.Receptacle,
}, base.ServantManager)

function assemble(components)
	arch.start(components)
	
	-- CLIENT SIDE
	ProxyManager.indexer = TypeRepository.indexer
	ProxyManager.types   = TypeRepository.types
	
	-- SERVER SIDE
	ServantManager.indexer = TypeRepository.indexer
	ServantManager.types   = TypeRepository.types
	
	arch.finish(components)
end
