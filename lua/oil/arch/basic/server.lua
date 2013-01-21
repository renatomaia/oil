local port = require "oil.port"
local component = require "oil.component"

local module = {
	ServantManager = component.Template{
		servants = port.Facet,
		dispatcher = port.Facet,
		referrer = port.Receptacle,
	},
	RequestReceiver = component.Template{
		acceptor = port.Facet,
		dispatcher = port.Receptacle,
		listener = port.Receptacle,
	},
}

function module.assemble(_ENV)
	ServantManager.referrer = ObjectReferrer.references
	RequestReceiver.dispatcher = ServantManager.dispatcher
	RequestReceiver.listener = RequestListener.requests
end

return module
