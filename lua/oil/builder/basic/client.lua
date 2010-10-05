local ipairs = ipairs
local require = require
local builder = require "oil.builder"
local arch = require "oil.arch.basic.client"

module "oil.builder.basic.client"

ProxyManager = arch.ProxyManager{require "oil.kernel.base.Proxies"}

function create(comps)
	comps = comps or {}
	comps.proxykind=comps.proxykind or {"synchronous","asynchronous","protected"}
	for _, kind in ipairs(comps.proxykind) do
		if comps.proxykind[kind] == nil then
			comps.proxykind[kind] = ProxyManager{
				invoker = require("oil.kernel.base.Proxies."..kind),
			}
		end
	end
	return comps
end
