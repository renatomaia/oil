local _G = require "_G"
local ipairs = _G.ipairs

local port = require "oil.port"
local component = require "oil.component"
local base = require "oil.arch.basic.client"

local module = {
	ProxyManager = component.Template({
		types = port.Receptacle,
		indexer = port.Receptacle,
	}, base.ProxyManager),
}

function module.assemble(_ENV)
	for _, kind in ipairs(proxykind) do
		local ProxyManager = proxykind[kind]
		ProxyManager.indexer = TypeRepository.indexer
		ProxyManager.types = TypeRepository.types
	end
end

return module
