local arch = require "oil.arch.typed.client"
local basic = require "oil.builder.basic.client"
local create = basic.create

local factories = {
	ProxyManager = arch.ProxyManager{require "oil.kernel.typed.Proxies"},
}

function factories.create(built)
	create(built, factories)
end

return factories
