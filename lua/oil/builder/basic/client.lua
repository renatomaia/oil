local require = require
local builder = require "oil.builder"
local arch    = require "oil.arch.basic.client"

module "oil.builder.basic.client"

ProxyManager = arch.ProxyManager{require "oil.kernel.base.Proxies"}

function create(comps)
	return builder.create(_M, comps)
end
