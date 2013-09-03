local _G = require "_G"
local ipairs = _G.ipairs

local port = require "oil.port"
local component = require "oil.component"

local module = {
	ProxyManager = component.Template{
		proxies = port.Facet,
		requester = port.Receptacle,
		referrer = port.Receptacle,
	},
}

function module.assemble(_ENV)
	for _, kind in ipairs(proxykind) do
		local ProxyManager = proxykind[kind]
		ProxyManager.requester = OperationRequester.requests
		ProxyManager.referrer = ObjectReferrer.references
	end
end

return module
