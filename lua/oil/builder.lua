local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local assert = _G.assert
local error = _G.error
local getmetatable = _G.getmetatable
local ipairs = _G.ipairs
local pairs = _G.pairs
local require = _G.require
local setmetatable = _G.setmetatable

local port = require "oil.port"
local component = require "oil.component"

local function callwithenv(func, env)
	local backup
	if _G._VERSION == "Lua 5.1" then
		backup = _G.getfenv(func)
		_G.setfenv(func, env)
	end
	func(env)
	if _G._VERSION == "Lua 5.1" then
		_G.setfenv(func, backup)
	end
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

local function newlayer(info)
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
	Flavors[name] = info
end


newlayer{
	name = "kernel.base",
	define = function (_ENV)
		template.SocketConnector = component.Template{
			repository = port.Facet,
			channels = port.Receptacle,
			sockets = port.Receptacle,
			dns = port.Receptacle,
			limiter = port.Receptacle,
		}
		template.ResourceManager = component.Template{
			repository = port.Facet,
		}
		template.BasicSystem = component.Template{
			sockets = port.Facet,
			dns = port.Facet,
		}

		factory.ResourceManager = template.ResourceManager{
			require "oil.kernel.base.Limiter",
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

newlayer{
	name = "kernel.client",
	extends = { "kernel.base" },
	define = function (_ENV)
		template.ProxyManager = component.Template{
			proxies = port.Facet,
			requester = port.Receptacle,
			referrer = port.Receptacle,
		}

		factory.ClientConnector = template.SocketConnector{
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
			ClientConnector.channels = ClientChannels.channels
			ClientConnector.sockets = BasicSystem.sockets
			ClientConnector.dns = BasicSystem.dns
			ClientConnector.limiter = ResourceManager.repository
			for _, kind in ipairs(proxykind) do
				local ProxyManager = proxykind[kind]
				ProxyManager.requester = OperationRequester.requests
				ProxyManager.referrer = ObjectReferrer.references
			end
		end
	end,
}

newlayer{
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

		factory.ServerConnector = template.SocketConnector{
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
			ServerConnector.channels = ServerChannels.channels
			ServerConnector.sockets = BasicSystem.sockets
			ServerConnector.dns = BasicSystem.dns
			ServerConnector.limiter = ResourceManager.repository
			ServantManager.referrer = ObjectReferrer.references
			ServantManager.listener = RequestListener.requests
			RequestReceiver.dispatcher = ServantManager.dispatcher
			RequestReceiver.listener = RequestListener.requests
		end
	end,
}

newlayer{
	name = "cooperative.base",
	extends = { "kernel.base" },
	define = function (_ENV)
		factory.BasicSystem = template.BasicSystem{
			sockets = require "oil.kernel.cooperative.Sockets",
			dns = require "oil.kernel.base.DNS",
		}
	end,
}

newlayer{
	name = "kernel.ssl",
	extends = { "cooperative.base" },
	define = function (_ENV)
		factory.BasicSystem = template.BasicSystem{
			sockets = require "oil.kernel.cooperative.SecureSockets",
			dns = require "oil.kernel.base.DNS",
		}
	end,
}

newlayer{
	name = "cooperative.client",
	extends = { "cooperative.base", "kernel.client" },
	define = function (_ENV)
		factory.ClientConnector = template.SocketConnector{
			require "oil.kernel.cooperative.Connector",
		}
	end,
}

newlayer{
	name = "cooperative.server",
	extends = { "cooperative.base", "kernel.server" },
	define = function (_ENV)
		factory.RequestReceiver = template.RequestReceiver{
			require "oil.kernel.cooperative.Receiver",
		}
	end,
}

newlayer{
	name = "typed.base",
	define = function (_ENV)
		template.TypeRepository = component.Template{
			types = port.Facet,
			indexer = port.Facet,
		}
	end,
}

newlayer{
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

newlayer{
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

newlayer{
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
		-- GIOP messages
		template.MessageChannels = component.Template{
			channels = port.Facet,
			codec = port.Receptacle,
			referrer = port.Receptacle,
			servants = port.Receptacle,
			requester = port.Receptacle,
			listener = port.Receptacle,
			bidircodec = port.Receptacle,
		}
		-- IOR references
		template.IORProfiler = component.Template{
			profiler = port.Facet,
			codec = port.Receptacle,
			components = port.HashReceptacle,
		}
		template.IIOPProfileComponentCodec = component.Template{
			compcodec = port.Facet,
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
		factory.MessageChannels = template.MessageChannels{
			require "oil.corba.giop.Channels",
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
			if MessageChannels == nil then
				MessageChannels = factory.MessageChannels()
			end
			if ClientChannels == nil then
				ClientChannels = MessageChannels
			end
			if ServerChannels == nil then
				ServerChannels = MessageChannels
			end
		end

		function assemble(_ENV)
			-- IDL of standard system exceptions
			TypeRepository.types:register(require "oil.corba.idl.sysex")

			ValueEncoder.references = ObjectReferrer.references
			ValueEncoder.types = TypeRepository.types
			ValueEncoder.proxies = ProxyManager.proxies
			ValueEncoder.servants = ServantManager.servants

			MessageChannels.codec = ValueEncoder.codec
			MessageChannels.referrer = ObjectReferrer.references -- GIOP 1.2 target
			MessageChannels.servants = ServantManager.servants -- LocationRequest
			MessageChannels.requester = OperationRequester.requests -- BiDir registration
			MessageChannels.listener = RequestListener.requests -- BiDir registration
			MessageChannels.bidircodec = IIOPProfiler.profiler -- BiDir ServCtxt
			ClientChannels = MessageChannels
			ServerChannels = MessageChannels

			IIOPProfiler.codec = ValueEncoder.codec

			ObjectReferrer.codec = ValueEncoder.codec
			ObjectReferrer.profiler[IIOPProfiler.tag] = IIOPProfiler.profiler
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

newlayer{
	name = "corba.ssl",
	extends = { "corba.base" },
	define = function (_ENV)
		factory.SSLIOPComponentCodec = template.IIOPProfileComponentCodec{
			require "oil.corba.iiop.ssl.ComponentCodec",
		}

		function assemble(_ENV)
			SSLIOPComponentCodec.codec = ValueEncoder.codec

			IIOPProfiler.components[SSLIOPComponentCodec.tag] = SSLIOPComponentCodec.compcodec
		end
	end,
}

newlayer{
	name = "corba.client",
	extends = { "corba.base", "typed.client" },
	define = function (_ENV)
		template.OperationRequester = component.Template{
			requests = port.Facet,
			channels = port.Receptacle,
			listener = port.Receptacle,
		}

		factory.OperationRequester = template.OperationRequester{
			require "oil.corba.giop.Requester",
		}

		function assemble(_ENV)
			OperationRequester.channels = ClientConnector.repository
			OperationRequester.listener = RequestListener.requests -- BiDir GIOP
		end
	end,
}

newlayer{
	name = "corba.server",
	extends = { "corba.base", "typed.server" },
	define = function (_ENV)
		template.RequestListener = component.Template{
			requests = port.Facet,
			channels = port.Receptacle,
			indexer = port.Receptacle,
		}

		factory.RequestListener = template.RequestListener{
			require "oil.corba.giop.Listener",
		}

		function assemble(_ENV)
			RequestListener.channels = ServerConnector.repository
			RequestListener.indexer = TypeRepository.indexer -- get interface ops/types
		end
	end,
}

newlayer{
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

newlayer{
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

newlayer{
	name = "corba.gencode",
	extends = { "corba.base" },
	define = function (_ENV)
		factory.ValueEncoder = template.ValueEncoder{
			require "oil.corba.giop.CodecGen",
		}
	end,
}

newlayer{
	name = "ludo.base",
	define = function (_ENV)
		template.ValueEncoder = component.Template{
			codec = port.Facet,
		}
		template.MessageChannels = component.Template{
			channels = port.Facet,
			codec = port.Receptacle,
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

newlayer{
	name = "ludo.client",
	extends = { "ludo.base", "kernel.client" },
	define = function (_ENV)
		template.OperationRequester = component.Template{
			requests = port.Facet,
			channels = port.Receptacle,
			codec = port.Receptacle,
		}

		factory.ClientChannels = template.MessageChannels{
			require "oil.ludo.Channels",
		}
		factory.OperationRequester = template.OperationRequester{
			require "oil.ludo.Requester",
		}
		
		function assemble(_ENV)
			ClientChannels.codec = ValueEncoder.codec
			OperationRequester.channels = ClientConnector.repository
			OperationRequester.codec = ValueEncoder.codec
		end
	end,
}

newlayer{
	name = "ludo.server",
	extends = { "ludo.base", "kernel.server" },
	define = function (_ENV)
		template.RequestListener = component.Template{
			requests = port.Facet,
			channels = port.Receptacle,
			codec = port.Receptacle,
		}

		factory.ServerChannels = template.MessageChannels{
			require "oil.ludo.Listener", -- TODO rename it to 'oil.ludo.ServerChannels'
		}
		factory.RequestListener = template.RequestListener{
			require "oil.protocol.Listener",
		}

		function assemble(_ENV)
			ServerChannels.codec = ValueEncoder.codec
			RequestListener.channels = ServerConnector.repository
			RequestListener.codec = ValueEncoder.codec
		end
	end,
}

newlayer{
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

newlayer{
	name = "lua.client",
	extends = { "kernel.client" },
	define = function (_ENV)
		factory.ProxyManager = template.ProxyManager{
			require "oil.kernel.lua.Proxies",
		}
	end,
}

newlayer{
	name = "lua.server",
	extends = { "kernel.server" },
	define = function (_ENV)
		factory.ServantManager = template.ServantManager {
			require "oil.kernel.base.Servants",
			dispatcher = require "oil.kernel.lua.Dispatcher",
		}
	end,
}

newlayer{name="lua", extends={"lua.client","lua.server"}}
newlayer{name="ludo", extends={"ludo.client","ludo.server"}}
newlayer{name="corba", extends={"corba.client","corba.server"}}
newlayer{name="cooperative", extends={"cooperative.client","cooperative.server"}}
newlayer{name="corba.intercepted", extends={"corba.intercepted.client","corba.intercepted.server"}}


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
	local define = info.define
	if define ~= nil and info[DefinedFields[1]] ~= nil then
		callwithenv(define, info)
	end
	add(set, info)
end

local none = setmetatable({}, { __newindex = function() end })
local AssembleEnvMeta = { __index = function() return none end }


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
	local meta = getmetatable(config)
	setmetatable(config, AssembleEnvMeta)
	for index = #list, 1, -1 do
		local info = list[index]
		local assemble = info.assemble
		if assemble ~= nil then                                                     --[[VERBOSE]] verbose:built("assembling ",info.name," components")
			callwithenv(assemble, config)
		end
	end
	setmetatable(config, meta)
	return config
end

return module
