local arch = require "oil.arch.basic.client"

local factories = {
	ProxyManager = arch.ProxyManager{ require "oil.kernel.lua.Proxies" },
}

function factories.create(built)
	built.proxykind = built.proxykind or {"lua"}
	built.proxykind.lua = factories.ProxyManager()
end

return factories
