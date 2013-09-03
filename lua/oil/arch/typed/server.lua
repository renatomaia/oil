local port = require "oil.port"
local component = require "oil.component"
local base = require "oil.arch.basic.server"

local module = {
	ServantManager = component.Template({
		types = port.Receptacle,
		indexer = port.Receptacle,
	}, base.ServantManager),
}

function module.assemble(_ENV)
	ServantManager.indexer = TypeRepository.indexer
	ServantManager.types = TypeRepository.types
end

return module
