local require = require
local builder = require "oil.builder"
local arch    = require "oil.arch.corba.intercepted.server"

module "oil.builder.corba.intercepted.server"

RequestListener   = arch.RequestListener  {require "oil.corba.intercepted.Listener"}
ServerInterceptor = arch.ServerInterceptor{require "oil.corba.intercepted.Server"}

function create(comps)
	return builder.create(_M, comps)
end
