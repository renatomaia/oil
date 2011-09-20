local require = require
local builder = require "oil.builder"
local arch    = require "oil.arch.corba.common"
local Exception = require "oil.corba.giop.Exception"

module "oil.builder.corba.common"

IIOPProfiler    = arch.IORProfiler   {require "oil.corba.iiop.Profiler"}
ValueEncoder    = arch.ValueEncoder  {require "oil.corba.giop.Codec"   }
ObjectReferrer  = arch.ObjectReferrer{require "oil.corba.giop.Referrer"}
TypeRepository  = arch.TypeRepository{require "oil.corba.idl.Registry" ,
                           indexer  = require "oil.corba.giop.Indexer" ,
                           compiler = require "oil.corba.idl.Compiler" ,
                           types    = require "oil.corba.idl.Importer" }

function create(comps)
	if comps.Exception == nil then
		comps.Exception = Exception
	end
	return builder.create(_M, comps)
end
