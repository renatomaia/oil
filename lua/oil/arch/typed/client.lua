local ipairs = ipairs

local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch"
local base      = require "oil.arch.basic.client"

module "oil.arch.typed.client"

ProxyManager = component.Template({
	types   = port.Receptacle,
	indexer = port.Receptacle,
}, base.ProxyManager)

function assemble(components)
	arch.start(components)
	for _, kind in ipairs(proxykind) do
		local ProxyManager = proxykind[kind]
		ProxyManager.indexer = TypeRepository.indexer
		ProxyManager.types = TypeRepository.types
	end
	arch.finish(components)
end
