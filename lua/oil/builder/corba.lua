local require = require
local builder = require "oil.builder"
local arch    = require "oil.arch.corba"

module "oil.builder.corba"

IIOPClientChannels = arch.SocketChannels    {require "oil.corba.iiop.Connector" }
IIOPServerChannels = arch.SocketChannels    {require "oil.corba.iiop.Acceptor"  }
ValueEncoder       = arch.ValueEncoder      {require "oil.corba.giop.Codec"     }
ObjectReferrer     = arch.ObjectReferrer    {require "oil.corba.giop.Referrer"  }
IIOPProfiler       = arch.ReferenceProfiler {require "oil.corba.iiop.Profiler"  }
OperationRequester = arch.OperationRequester{require "oil.corba.giop.Requester" }
MessageMarshaler   = arch.MessageMarshaler  {require "oil.corba.giop.Messenger" }
ProxyIndexer       = arch.ProxyIndexer      {require "oil.corba.giop.ProxyOps"  }
RequestListener    = arch.RequestListener   {require "oil.corba.giop.Listener"  }
ServantIndexer     = arch.ServantIndexer    {require "oil.corba.giop.ServantOps"}
TypeRepository = arch.TypeRepository{
	types    = require "oil.corba.idl.Registry",
	indexer  = require "oil.corba.idl.Indexer",
	compiler = require "oil.corba.idl.Compiler",
	importer = require "oil.corba.idl.Importer",
}

function create(comps)
	comps = comps or {}
	builder.create(_M, comps)
	comps.ClientChannels     = comps.ClientChannels or { [0] = comps.IIOPClientChannels }
	comps.ServerChannels     = comps.ServerChannels or { [0] = comps.IIOPServerChannels }
	comps.ReferenceProfilers = comps.ReferenceProfilers or {
		[0]  = comps.IIOPProfiler,
		[""] = comps.IIOPProfiler,
		iiop = comps.IIOPProfiler,
	}
	return comps
end