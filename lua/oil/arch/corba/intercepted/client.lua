local port = require "oil.port"
local comp = require "oil.component"
local base = require "oil.arch.corba.client"

return {
	OperationRequester = comp.Template({
		interceptor = port.Receptacle
	}, base.OperationRequester),
}
