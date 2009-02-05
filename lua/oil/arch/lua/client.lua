local arch = require "oil.arch"

module "oil.arch.lua.client"

function assemble(components)
	arch.start(components)
	LuaEncoder.proxies = ProxyManager.proxies
	arch.finish(components)
end
