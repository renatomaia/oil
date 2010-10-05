local ipairs = ipairs

local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch"

module "oil.arch.basic.client"

ProxyManager = component.Template{
	proxies   = port.Facet,
	requester = port.Receptacle,
	referrer  = port.Receptacle,
}

function assemble(components)
	arch.start(components)
	for _, kind in ipairs(proxykind) do
		local ProxyManager = proxykind[kind]
		ProxyManager.requester = OperationRequester.requests
		ProxyManager.referrer = ObjectReferrer.references
	end
	arch.finish(components)
end
