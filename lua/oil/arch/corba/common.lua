local pairs = pairs

local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch"
local base      = require "oil.arch.typed.common"
local sysex     = require "oil.corba.idl.sysex"                                 --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.arch.corba.common"

-- IDL typing information
TypeRepository = component.Template({
	registry  = port.Facet,
	compiler  = port.Facet,
	delegated = port.Receptacle,
}, base.TypeRepository)

-- CDR marshaling
ValueEncoder = component.Template{
	codec    = port.Facet,
	proxies  = port.Receptacle,
	servants = port.Receptacle,
}

-- IOR references
IORProfiler = component.Template{
	profiler = port.Facet,
	codec    = port.Receptacle,
}
ObjectReferrer = component.Template{
	references = port.Facet,
	codec      = port.Receptacle,
	requester  = port.Receptacle,
	profiler   = port.HashReceptacle,
}

function assemble(components)
	arch.start(components)
	
	TypeRepository.types:register(sysex) -- IDL of standard system exceptions
	
	ValueEncoder.proxies = proxykind[ proxykind[1] ].proxies
	ValueEncoder.servants = ServantManager.servants
	
	IIOPProfiler.codec = ValueEncoder.codec
	
	ObjectReferrer.codec = ValueEncoder.codec
	ObjectReferrer.profiler[0] = IIOPProfiler.profiler
	ObjectReferrer.profiler.iiop = IIOPProfiler.profiler
	
	arch.finish(components)
end
