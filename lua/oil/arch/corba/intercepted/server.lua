local port = require "oil.port"
local comp = require "oil.component"
local base = require "oil.arch.corba.server"

return {
	RequestListener = comp.Template({
		interceptor = port.Receptacle,
	}, base.RequestListener),
}
