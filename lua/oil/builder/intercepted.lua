local require   = require
local builder   = require "oil.builder"
local typed     = require "oil.arch.typed"
local corba     = require "oil.arch.corba"
local component = require "loop.component.wrapped"
local port      = require "loop.component.intercepted"

module "oil.builder.intercepted"

-- Redefine component templates and ports that will be intercepted

arch = {
	OperationRequester = component.Template({
		requests  = port.Facet,
		messenger = port.Receptacle,
	}, corba.OperationRequester),
	RequestListener = component.Template({
		messenger = port.Receptacle,
	}, corba.RequestListener),
	RequestDispatcher = component.Template({
		dispatcher = port.Facet,
	}, typed.RequestDispatcher),
}

OperationRequester = arch.OperationRequester{require "oil.corba.giop.Requester"    }
RequestListener    = arch.RequestListener   {require "oil.corba.giop.Listener"     }
RequestDispatcher  = arch.RequestDispatcher {require "oil.kernel.typed.Dispatcher" }

function create(comps)
	return builder.create(_M, comps)
end
