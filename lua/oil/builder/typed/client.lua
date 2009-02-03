local require = require
local builder = require "oil.builder"
local arch    = require "oil.arch.typed.client"

module "oil.builder.typed.client"

ProxyManager = arch.ProxyManager{require "oil.kernel.typed.Proxies"}

function create(comps)
	return builder.create(_M, comps)
end
