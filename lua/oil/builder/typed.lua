local require = require
local builder = require "oil.builder"
local arch    = require "oil.arch.typed"

module "oil.builder.typed"

ProxyManager   = arch.ProxyManager  {require "oil.kernel.typed.Proxies"   }
ServantManager = arch.ServantManager{require "oil.kernel.typed.Servants"    ,
                        dispatcher = require "oil.kernel.typed.Dispatcher"}

function create(comps)
	return builder.create(_M, comps)
end
