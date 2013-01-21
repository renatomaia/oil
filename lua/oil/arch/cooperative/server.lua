local port = require "oil.port"
local component = require "oil.component"
local base = require "oil.arch.basic.server"

local module = {
	RequestReceiver = component.Template({
		tasks = port.Receptacle,
	}, base.RequestReceiver),
}

function module.assemble(_ENV)
	RequestReceiver.tasks = BasicSystem.tasks
end

return module