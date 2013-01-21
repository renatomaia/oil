local port = require "oil.port"
local component = require "oil.component"
local base = require "oil.arch.typed.common"
local sysex = require "oil.corba.idl.sysex"

local module = {
	-- IDL typing information
	TypeRepository = component.Template({
		registry = port.Facet,
		compiler = port.Facet,
		delegated = port.Receptacle,
	}, base.TypeRepository),
	-- CDR marshaling
	ValueEncoder = component.Template{
		codec = port.Facet,
		proxies = port.Receptacle,
		servants = port.Receptacle,
		types = port.Receptacle,
	},
	-- IOR references
	IORProfiler = component.Template{
		profiler = port.Facet,
		codec = port.Receptacle,
	},
	ObjectReferrer = component.Template{
		references = port.Facet,
		codec = port.Receptacle,
		requester = port.Receptacle,
		profiler = port.HashReceptacle,
	},
}

function module.assemble(_ENV)
	TypeRepository.types:register(sysex) -- IDL of standard system exceptions
	
	ValueEncoder.references = ObjectReferrer.references
	ValueEncoder.types = TypeRepository.types
	
	IIOPProfiler.codec = ValueEncoder.codec
	
	ObjectReferrer.codec = ValueEncoder.codec
	ObjectReferrer.profiler[0] = IIOPProfiler.profiler
	ObjectReferrer.profiler.iiop = IIOPProfiler.profiler
end

return module
