local pairs = pairs

local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch"                                            --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.arch.corba.client"

OperationRequester = component.Template{
	requests = port.Facet,
	codec    = port.Receptacle,
	channels = port.Receptacle,
	profiler = port.HashReceptacle,
}

function assemble(components)
	arch.start(components)
	
	ClientChannels.sockets = BasicSystem.sockets
	
	OperationRequester.codec = ValueEncoder.codec
	OperationRequester.channels = ClientChannels.channels
	OperationRequester.referrer = ObjectReferrer.references -- open IOR profiles
	
	-- this optional depedency is to allow 'ObjectReferrer' to invoke
	-- 'get_interface' on references to find out their actual interface
	ObjectReferrer.requester = OperationRequester.requests
	
	arch.finish(components)
end
