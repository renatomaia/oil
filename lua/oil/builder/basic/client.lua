local _G = require "_G"
local ipairs = _G.ipairs
local require = _G.require

local arch = require "oil.arch.basic.client"

local factories = {
	ProxyManager = arch.ProxyManager{require "oil.kernel.base.Proxies"},
}

function factories.create(built, facts)
	if facts == nil then facts = factories end
	built.proxykind = built.proxykind
	               or {"synchronous","asynchronous","protected"}
	for _, kind in ipairs(built.proxykind) do
		if built.proxykind[kind] == nil then
			built.proxykind[kind] = facts.ProxyManager{
				invoker = require("oil.kernel.base.Proxies."..kind),
			}
		end
	end
end

return factories
