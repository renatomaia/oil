local require = require
local builder = require "oil.builder"
local base    = require "oil.arch.base"
local arch    = require "oil.arch.corba"

module "oil.builder.corba"

ClientChannels     = base.SocketChannels    {require "oil.kernel.base.Connector" }
ServerChannels     = base.SocketChannels    {require "oil.kernel.base.Acceptor"  }
ValueEncoder       = arch.ValueEncoder      {require "oil.corba.giop.Codec"     }
ObjectReferrer     = arch.ObjectReferrer    {require "oil.corba.giop.Referrer"  }
IIOPProfiler       = arch.ReferenceProfiler {require "oil.corba.iiop.Profiler"  }
OperationRequester = arch.OperationRequester{require "oil.corba.giop.Requester" }
MessageMarshaler   = arch.MessageMarshaler  {require "oil.corba.giop.Messenger" }
RequestListener    = arch.RequestListener   {require "oil.corba.giop.Listener"  }
TypeRepository = arch.TypeRepository{
	registry = require "oil.corba.idl.Registry",
	indexer  = require "oil.corba.giop.Indexer",
	compiler = require "oil.corba.idl.Compiler",
	types    = require "oil.corba.idl.Importer",
}

function create(comps)
	return builder.create(_M, comps)
end
