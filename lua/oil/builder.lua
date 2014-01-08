local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local ipairs = _G.ipairs
local pairs = _G.pairs
local require = _G.require

local port = require "oil.port"
local component = require "oil.component"

local function callwithenv(func, env)
	local backup = getfenv(func)
	setfenv(func, env)
	func(env)
	setfenv(func, backup)
end

local function inheritable(bases, field, table)
	return setmetatable(table or {}, {
		__index = function (_, name)
			for _, base in ipairs(bases) do
				local value = base[field][name]
				if value ~= nil then
					return value
				end
			end
		end,
	})
end

local DefinedFields = {"template","factory"}
local Flavors = {}

local function newflavor(info)
	local name = info.name
	assert(Flavors[name] == nil, "flavor duplicated")
	for _, field in pairs(DefinedFields) do
		info[field] = {}
	end
	local extends = info.extends
	if extends ~= nil then
		local bases = {}
		for index, base in ipairs(extends) do
			bases[index] = assert(Flavors[base], "missing extended flavor")
		end
		for _, field in pairs(DefinedFields) do
			info[field] = inheritable(bases, field, info[field])
		end
		info.bases = bases
	end
	local define = info.define
	if define ~= nil then
		callwithenv(define, info)
	end
	Flavors[name] = info
end


newflavor{
	name = "kernel.base",
	define = function (_ENV)
		template.SocketChannels = component.Template{
			channels = port.Facet,
			sockets = port.Receptacle,
			dns = port.Receptacle,
		}
		template.BasicSystem = component.Template{
			sockets = port.Facet,
			dns = port.Facet,
		}

		factory.BasicSystem = template.BasicSystem{
			sockets = require "oil.kernel.base.Sockets",
			dns = require "oil.kernel.base.DNS",
		}

		function build(_ENV)
			if Exception == nil then
				Exception = require "oil.Exception"
			end
		end
	end,
}

newflavor{
	name = "kernel.client",
	extends = { "kernel.base" },
	define = function (_ENV)
		template.ProxyManager = component.Template{
			proxies = port.Facet,
			requester = port.Receptacle,
			referrer = port.Receptacle,
		}

		factory.ClientChannels = template.SocketChannels{
			require "oil.kernel.base.Connector",
		}
		factory.ProxyManager = template.ProxyManager{
			require "oil.kernel.base.Proxies",
		}

		function build(_ENV)
			if ProxyManager == nil then
				if proxykind == nil then
					proxykind = {"synchronous","asynchronous","protected"}
				end
				for _, kind in ipairs(proxykind) do
					if proxykind[kind] == nil then
						proxykind[kind] = factory.ProxyManager{
							invoker = require("oil.kernel.base.Proxies."..kind),
						}
					end
				end
				ProxyManager = proxykind[ proxykind[1] ]
			end
		end

		function assemble(_ENV)
			ClientChannels.sockets = BasicSystem.sockets
			ClientChannels.dns = BasicSystem.dns
			for _, kind in ipairs(proxykind) do
				local ProxyManager = proxykind[kind]
				ProxyManager.requester = OperationRequester.requests
				ProxyManager.referrer = ObjectReferrer.references
			end
		end
	end,
}

newflavor{
	name = "kernel.server",
	extends = { "kernel.base" },
	define = function (_ENV)
		template.ServantManager = component.Template{
			servants = port.Facet,
			dispatcher = port.Facet,
			referrer = port.Receptacle,
			listener = port.Receptacle,
		}
		template.RequestReceiver = component.Template{
			acceptor = port.Facet,
			dispatcher = port.Receptacle,
			listener = port.Receptacle,
		}

		factory.ServerChannels = template.SocketChannels{
			require "oil.kernel.base.Acceptor",
		}
		factory.ServantManager = template.ServantManager{
			require "oil.kernel.base.Servants",
			dispatcher = require "oil.kernel.base.Dispatcher",
		}
		factory.RequestReceiver = template.RequestReceiver{
			require "oil.kernel.base.Receiver",
		}

		function assemble(_ENV)
			ServerChannels.sockets = BasicSystem.sockets
			ServerChannels.dns = BasicSystem.dns
			ServantManager.referrer = ObjectReferrer.references
			ServantManager.listener = RequestListener.requests
			RequestReceiver.dispatcher = ServantManager.dispatcher
			RequestReceiver.listener = RequestListener.requests
		end
	end,
}

newflavor{
	name = "cooperative.base",
	extends = { "kernel.base" },
	define = function (_ENV)
		factory.BasicSystem = template.BasicSystem{
			sockets = require "oil.kernel.cooperative.Sockets",
			dns = require "oil.kernel.base.DNS",
		}
	end,
}

newflavor{
	name = "cooperative.client",
	extends = { "cooperative.base", "kernel.client" },
	define = function (_ENV)
		factory.ClientChannels = template.SocketChannels{
			require "oil.kernel.cooperative.Connector",
		}
	end,
}

newflavor{
	name = "cooperative.server",
	extends = { "cooperative.base", "kernel.server" },
	define = function (_ENV)
		factory.RequestReceiver = template.RequestReceiver{
			require "oil.kernel.cooperative.Receiver",
		}
	end,
}

newflavor{
	name = "typed.base",
	define = function (_ENV)
		template.TypeRepository = component.Template{
			types = port.Facet,
			indexer = port.Facet,
		}
	end,
}

newflavor{
	name = "typed.client",
	extends = { "typed.base", "kernel.client" },
	define = function (_ENV)
		template.ProxyManager = component.Template({
			types = port.Receptacle,
			indexer = port.Receptacle,
		}, template.ProxyManager)

		factory.ProxyManager = template.ProxyManager{
			require "oil.kernel.typed.Proxies",
		}

		function assemble(_ENV)
			for _, kind in ipairs(proxykind) do
				local ProxyManager = proxykind[kind]
				ProxyManager.types = TypeRepository.types
				ProxyManager.indexer = TypeRepository.indexer
			end
		end
	end,
}

newflavor{
	name = "typed.server",
	extends = { "typed.base", "kernel.server" },
	define = function (_ENV)
		template.ServantManager = component.Template({
			types = port.Receptacle,
			indexer = port.Receptacle,
		}, template.ServantManager)

		factory.ServantManager = template.ServantManager{
			require "oil.kernel.typed.Servants",
			dispatcher = require "oil.kernel.typed.Dispatcher",
		}

		function assemble(_ENV)
			ServantManager.types = TypeRepository.types
			ServantManager.indexer = TypeRepository.indexer
		end
	end,
}

newflavor{
	name = "corba.base",
	extends = { "typed.base" },
	define = function (_ENV)
		-- IDL typing information
		template.TypeRepository = component.Template({
			registry = port.Facet,
			compiler = port.Facet,
			delegated = port.Receptacle,
		}, template.TypeRepository)
		-- CDR marshaling
		template.ValueEncoder = component.Template{
			codec = port.Facet,
			references = port.Receptacle,
			types = port.Receptacle,
			proxies = port.Receptacle,
			servants = port.Receptacle,
		}
		-- IOR references
		template.IORProfiler = component.Template{
			profiler = port.Facet,
			codec = port.Receptacle,
		}
		template.ObjectReferrer = component.Template{
			references = port.Facet,
			codec = port.Receptacle,
			profiler = port.HashReceptacle,
			requester = port.Receptacle,
			listener = port.Receptacle,
		}

		factory.TypeRepository = template.TypeRepository{
			require "oil.corba.idl.Registry",
			indexer = require "oil.corba.giop.Indexer",
			compiler = require "oil.corba.idl.Compiler",
			types = require "oil.corba.idl.Importer",
		}
		factory.ValueEncoder = template.ValueEncoder{
			require "oil.corba.giop.Codec",
		}
		factory.IIOPProfiler = template.IORProfiler{
			require "oil.corba.iiop.Profiler",
		}
		factory.ObjectReferrer = template.ObjectReferrer{
			require "oil.corba.giop.Referrer",
		}

		function build(_ENV)
			if Exception == nil then
				Exception = require "oil.corba.giop.Exception"
			end
		end

		function assemble(_ENV)
			-- IDL of standard system exceptions
			TypeRepository.types:register(require "oil.corba.idl.sysex")
			
			ValueEncoder.references = ObjectReferrer.references
			ValueEncoder.types = TypeRepository.types
			ValueEncoder.proxies = ProxyManager.proxies
			ValueEncoder.servants = ServantManager.servants
			
			IIOPProfiler.codec = ValueEncoder.codec
			
			ObjectReferrer.codec = ValueEncoder.codec
			ObjectReferrer.profiler[0] = IIOPProfiler.profiler
			ObjectReferrer.profiler.iiop = IIOPProfiler.profiler
			-- this optional depedency is to allow 'ObjectReferrer' to invoke
			-- 'get_interface' on references to find out their actual interface
			ObjectReferrer.requester = OperationRequester.requests
			-- this optional dependency is to allow 'ObjectReferrer' to know the address
			-- the ORB is listening and identify local references (islocal) and create
			-- references to local servants (newreference).
			ObjectReferrer.listener = RequestListener.requests
		end
	end,
}

newflavor{
	name = "corba.client",
	extends = { "corba.base", "typed.client" },
	define = function (_ENV)
		template.OperationRequester = component.Template{
			requests = port.Facet,
			codec = port.Receptacle,
			channels = port.Receptacle,
			listener = port.Receptacle,
		}

		factory.OperationRequester = template.OperationRequester{
			require "oil.corba.giop.Requester",
		}

		function assemble(_ENV)
			OperationRequester.codec = ValueEncoder.codec
			OperationRequester.channels = ClientChannels.channels
			OperationRequester.listener = RequestListener.requests -- BiDir GIOP
		end
	end,
}

newflavor{
	name = "corba.server",
	extends = { "corba.base", "typed.server" },
	define = function (_ENV)
		template.RequestListener = component.Template{
			requests = port.Facet,
			codec = port.Receptacle,
			channels = port.Receptacle,
			servants = port.Receptacle,
			indexer = port.Receptacle,
			requester = port.Receptacle, -- BiDir GIOP
			serviceencoder = port.Receptacle, -- BiDir GIOP
			servicedecoder = port.Receptacle, -- BiDir GIOP
		}

		factory.RequestListener = template.RequestListener{
			require "oil.corba.giop.Listener",
		}

		function assemble(_ENV)
			RequestListener.codec = ValueEncoder.codec
			RequestListener.channels = ServerChannels.channels
			RequestListener.servants = ServantManager.servants -- to answer LocateRequest
			RequestListener.indexer = TypeRepository.indexer -- get interface ops/types
			RequestListener.requester = OperationRequester.requests -- BiDir GIOP
			RequestListener.serviceencoder = IIOPProfiler.profiler -- BiDir GIOP
			RequestListener.servicedecoder = IIOPProfiler.profiler -- BiDir GIOP
		end
	end,
}

newflavor{
	name = "corba.intercepted.client",
	extends = { "corba.client" },
	define = function (_ENV)
		template.OperationRequester = component.Template({
			interceptor = port.Receptacle
		}, template.OperationRequester)

		factory.OperationRequester = template.OperationRequester{
			require "oil.corba.intercepted.Requester",
		}
	end,
}

newflavor{
	name = "corba.intercepted.server",
	extends = { "corba.server" },
	define = function (_ENV)
		template.RequestListener = component.Template({
			interceptor = port.Receptacle,
		}, template.RequestListener)

		factory.RequestListener = template.RequestListener{
			require "oil.corba.intercepted.Listener",
		}
	end,
}

newflavor{
	name = "corba.gencode",
	extends = { "corba.base" },
	define = function (_ENV)
		factory.ValueEncoder = template.ValueEncoder{
			require "oil.corba.giop.CodecGen",
		}
	end,
}

newflavor{
	name = "ludo.base",
	define = function (_ENV)
		template.ValueEncoder = component.Template{
			codec = port.Facet,
		}
		template.ObjectReferrer = component.Template{
			references = port.Facet,
			codec = port.Receptacle,
			listener = port.Receptacle,
		}
		
		factory.ValueEncoder = template.ValueEncoder{
			require "oil.ludo.Codec",
		}
		factory.ObjectReferrer = template.ObjectReferrer{
			require "oil.ludo.Referrer",
		}

		function assemble(_ENV)
			ValueEncoder.codec:localresources(_ENV)
			ObjectReferrer.codec = ValueEncoder.codec
			-- this optional dependency is to allow 'ObjectReferrer' to know the address
			-- the ORB is listening and identify local references (islocal) and create
			-- references to local servants (newreference).
			ObjectReferrer.listener = RequestListener.requests
		end
	end,
}

newflavor{
	name = "ludo.client",
	extends = { "ludo.base", "kernel.client" },
	define = function (_ENV)
		template.OperationRequester = component.Template{
			requests = port.Facet,
			channels = port.Receptacle,
			codec = port.Receptacle,
		}

		factory.OperationRequester = template.OperationRequester{
			require "oil.ludo.Requester",
		}
		
		function assemble(_ENV)
			OperationRequester.channels = ClientChannels.channels
			OperationRequester.codec = ValueEncoder.codec
		end
	end,
}

newflavor{
	name = "ludo.server",
	extends = { "ludo.base", "kernel.server" },
	define = function (_ENV)
		template.RequestListener = component.Template{
			requests = port.Facet,
			channels = port.Receptacle,
			codec = port.Receptacle,
		}

		factory.RequestListener = template.RequestListener{
			require "oil.ludo.Listener",
		}

		function assemble(_ENV)
			RequestListener.channels = ServerChannels.channels
			RequestListener.codec = ValueEncoder.codec
		end
	end,
}

newflavor{
	name = "ludo.byref",
	extends = { "ludo.base" },
	define = function (_ENV)
		template.ValueEncoder = component.Template({
			proxies = port.Receptacle,
			servants = port.Receptacle,
		}, template.ValueEncoder)

		factory.ValueEncoder = template.ValueEncoder{
			require "oil.ludo.CodecByRef",
		}
		
		function assemble(_ENV)
			ValueEncoder.proxies = ProxyManager.proxies
			ValueEncoder.servants = ServantManager.servants
		end
	end,
}

newflavor{
	name = "lua.client",
	extends = { "kernel.client" },
	define = function (_ENV)
		factory.ProxyManager = template.ProxyManager{
			require "oil.kernel.lua.Proxies",
		}
	end,
}

newflavor{
	name = "lua.server",
	extends = { "kernel.server" },
	define = function (_ENV)
		factory.ServantManager = template.ServantManager {
			require "oil.kernel.base.Servants",
			dispatcher = require "oil.kernel.lua.Dispatcher",
		}
	end,
}

newflavor{name="lua", extends={"lua.client","lua.server"}}
newflavor{name="ludo", extends={"ludo.client","ludo.server"}}
newflavor{name="corba", extends={"corba.client","corba.server"}}
newflavor{name="cooperative", extends={"cooperative.client","cooperative.server"}}
newflavor{name="corba.intercepted", extends={"corba.intercepted.client","corba.intercepted.server"}}


local OrderedSet = require "loop.collection.OrderedSet"
local add = OrderedSet.add
local contains = OrderedSet.contains
local sequence = OrderedSet.sequence

local function addflavor(set, info)
	local bases = info.bases
	if bases ~= nil then
		for _, base in ipairs(bases) do
			if not contains(set, base) then
				addflavor(set, base)
			end
		end
	end
	add(set, info)
end

local module = {}

function module.build(config)
	if config == nil then config = {} end
	local set = {}
	for _, name in ipairs(config.flavor) do
		local info = Flavors[name]
		if info == nil then error("unknown flavor '"..name.."'") end
		addflavor(set, info)
	end
	local list = {}
	for info in sequence(set) do
		list[#list+1] = info
	end
	-- collect factories of components
	local factories = {}
	for index = #list, 1, -1 do
		local info = list[index]
		for name, factory in pairs(info.factory) do
			if factories[name] == nil then                                            --[[VERBOSE]] verbose:built("factory ",name," found at flavor ",info.name)
				factories[name] = factory
			end
		end
	end
	-- call custom component builders
	config.factory = factories
	for index = #list, 1, -1 do
		local info = list[index]
		local build = info.build
		if build ~= nil then                                                        --[[VERBOSE]] verbose:built("calling component builder of flavor ",info.name)
			callwithenv(build, config)
		end
	end
	-- create any missing components that have a factory provided
	for name, factory in pairs(factories) do
		if config[name] == nil then                                                 --[[VERBOSE]] verbose:built("creating missing component ",name)
			config[name] = factory()
		end
	end
	-- call component assembly functions
	for index = #list, 1, -1 do
		local info = list[index]
		local assemble = info.assemble
		if assemble ~= nil then                                                     --[[VERBOSE]] verbose:built("assembling ",info.name," components")
			callwithenv(assemble, config)
		end
	end
	return config
end

return module
