local require = require
local builder = require "oil.builder"
local client  = require "oil.arch.basic.client"
local server  = require "oil.arch.basic.server"
local common  = require "oil.arch.ludo.byref"

module "oil.builder.ludo.byref"

LuaEncoder      = common.ValueEncoder   {require "oil.ludo.CodecByRef"   }
ProxyManager    = client.ProxyManager   {require "oil.ludo.ProxiesByRef" }
ServantManager  = server.ServantManager {require "oil.kernel.base.Servants",
                            dispatcher = require "oil.ludo.DispatcherByRef"}

function create(comps)
	comps = builder.create(_M, comps)
	comps.ValueEncoder = comps.LuaEncoder
	return comps
end
