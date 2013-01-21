local builder = require "oil.builder"
local create = builder.create

local arch = require "oil.arch.corba.common"
local Exception = require "oil.corba.giop.Exception"

local factories = {
	IIOPProfiler = arch.IORProfiler{ require "oil.corba.iiop.Profiler" },
	ValueEncoder = arch.ValueEncoder{ require "oil.corba.giop.Codec" },
	ObjectReferrer = arch.ObjectReferrer{ require "oil.corba.giop.Referrer" },
	TypeRepository = arch.TypeRepository{ require "oil.corba.idl.Registry",
		indexer = require "oil.corba.giop.Indexer",
		compiler = require "oil.corba.idl.Compiler",
		types = require "oil.corba.idl.Importer",
	},
}

function factories.create(built)
	if built.Exception == nil then built.Exception = Exception end
	create(factories, built)
end

return factories
