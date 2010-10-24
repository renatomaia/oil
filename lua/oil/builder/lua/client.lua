local require = require
local builder = require "oil.builder"
local arch    = require "oil.arch.basic.client"

module "oil.builder.lua.client"

ProxyManager = arch.ProxyManager{require "oil.kernel.lua.Proxies"}

function create(comps)
	comps.proxykind = comps.proxykind or {"lua"}
	comps.proxykind.lua = ProxyManager()
	return comps
end
