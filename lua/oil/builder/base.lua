local require = require
local builder = require "oil.builder"
local arch    = require "oil.arch.base"

module "oil.builder.base"

BasicSystem     = arch.BasicSystem    {require "oil.kernel.base.Sockets"   }
ProxyManager    = arch.ProxyManager   {require "oil.kernel.base.Proxies"   }
RequestReceiver = arch.RequestReceiver{require "oil.kernel.base.Receiver"  }
ServantManager  = arch.ServantManager {require "oil.kernel.base.Servants"  ,
                          dispatcher = require "oil.kernel.base.Dispatcher"}

function create(comps)
	return builder.create(_M, comps)
end
