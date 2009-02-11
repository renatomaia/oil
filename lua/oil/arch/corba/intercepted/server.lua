local port = require "oil.port"
local comp = require "oil.component"
local arch = require "oil.arch"
local base = require "oil.arch.corba.server"

module "oil.arch.corba.intercepted.server"

RequestListener = comp.Template({
	interceptor = port.Receptacle
}, base.RequestListener)

ServerInterceptor = comp.Template{
	interceptions = port.Facet,
	interceptor   = port.Receptacle,
	servants      = port.Receptacle,
}

function assemble(comps)
	arch.start(comps)
	ServerInterceptor.servants = ServantManager.servants
	arch.finish(comps)
end
