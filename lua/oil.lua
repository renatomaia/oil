-- Project: OiL - ORB in Lua: An Object Request Broker in Lua
-- Release: 0.6
-- Title  : OiL main programming interface (API)
-- Authors: Renato Maia <maia@inf.puc-rio.br>
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   VERSION                                                                  --
--                                                                            --
--   types                                                                    --
--   loadidl(code)                                                            --
--   loadidlfile(path)                                                        --
--   getLIR()                                                                 --
--   getIR()                                                                  --
--   setIR(ir)                                                                --
--                                                                            --
--   newproxy(objref, [iface])                                                --
--   narrow(proxy, [iface])                                                   --
--                                                                            --
--   newservant(impl, [iface], [key])                                         --
--   deactivate(object, [type])                                               --
--   tostring(object)                                                         --
--                                                                            --
--   pending()                                                                --
--   step()                                                                   --
--   run()                                                                    --
--   shutdown()                                                               --
--                                                                            --
--   newexcept(body)                                                          --
--   setexcatch(callback, [type])                                             --
--                                                                            --
--   newencoder()                                                             --
--   newdecoder(stream)                                                       --
--                                                                            --
--   setclientinterceptor([iceptor])                                          --
--   setserverinterceptor([iceptor])                                          --
--                                                                            --
--   init()                                                                   --
--   main(function)                                                           --
--   newthread(function, ...)                                                 --
--   sleep(time)                                                              --
--   time()                                                                   --
--                                                                            --
--   writeto(filepath, text)                                                  --
--   readfrom(filepath)                                                       --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--------------------------------------------------------------------------------

local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local error = _G.error
local ipairs = _G.ipairs
local pairs = _G.pairs
local pcall = _G.pcall
local require = _G.require
local select = _G.select
local setmetatable = _G.setmetatable
local tostring = _G.tostring
local traceback = _G.debug and _G.debug.traceback -- only if available
local type = _G.type
local xpcall = _G.xpcall

local io = require "io"
local open = io.open

local coroutine = require "coroutine"
local newcoroutine = coroutine.create
local yield = coroutine.yield

local array = require "table"
local concat = array.concat
local unpack = array.unpack or _G.unpack

local OrderedSet = require "loop.collection.OrderedSet"

local oo = require "oil.oo"
local class = oo.class	
local rawnew = oo.rawnew

local builder = require "oil.builder"
local build = builder.build

local asserter = require "oil.assert"
local assert = asserter.results
local asserttype = asserter.type
local illegal = asserter.illegal

local currenttime

--------------------------------------------------------------------------------
-- OiL main programming interface (API).

-- This API provides access to the basic functionalities of the OiL ORB.
-- More advanced features may be accessed through more specialized interfaces
-- provided by internal components. OiL internal component organization is meant
-- to be customized for the application.

local Aliases = {
	["lua"]               = {"lua.client","lua.server"},
	["ludo"]              = {"ludo.client","ludo.server"},
	["corba"]             = {"corba.client","corba.server"},
	["cooperative"]       = {"cooperative.client","cooperative.server"},
	["corba.intercepted"] = {"corba.intercepted.client","corba.intercepted.server"},
}

local Dependencies = {
	-- LuDO support
	["ludo.client"] = {"ludo.common","basic.client"},
	["ludo.server"] = {"ludo.common","basic.server"},
	-- LuDO extension for by reference semantics
	["ludo.byref"]  = {"ludo.common"},
	-- CORBA support
	["corba.client"] = {"corba.common","typed.client"},
	["corba.server"] = {"corba.common","typed.server"},
	-- CORBA extension for interception
	["corba.intercepted.client"] = {"corba.client"},
	["corba.intercepted.server"] = {"corba.server"},
	-- CORBA extension for marshal code generation
	["corba.gencode"] = {"corba.common"},
	-- kernel extension for cooperative multithreading
	["cooperative.client"] = {"cooperative.common","basic.client"},
	["cooperative.server"] = {"cooperative.common","basic.server"},
	-- kernel extension for type-check
	["typed.client"] = {"typed.common","basic.client"},
	["typed.server"] = {"typed.common","basic.server"},
	-- kernel support
	["basic.client"] = {"basic.common"},
	["basic.server"] = {"basic.common"},
}

local function makeflavor(flavors)
	local packs = OrderedSet()
	for pack in flavors:gmatch("[^;]+") do
		local aliases = Aliases[pack]
		if aliases then
			for _, alias in ipairs(aliases) do
				packs:add(alias)
			end
		else
			packs:add(pack)
		end
	end
	for pack in packs:sequence() do
		local deps = Dependencies[pack]
		if deps then
			for _, dep in ipairs(deps) do
				if packs:contains(dep) then
					local place
					for item in packs:sequence() do
						if item == dep then
							packs:removefrom(place)
						end
						place = item
					end
				end
				packs:add(dep)
			end
		end
	end
	flavors = {}
	for pack in packs:sequence() do
		flavors[#flavors+1] = pack
	end
	return concat(flavors, ";")
end

--------------------------------------------------------------------------------
-- Class that implements the OiL's broker API.
--
local ORB = class()

function ORB:__new(config)
	self = rawnew(self, build(makeflavor(config.flavor), config))
	
	if self.TypeRepository ~= nil then
		----------------------------------------------------------------------------
		-- Internal interface repository used by the ORB.
		--
		-- This is a alias for a facet of the Type Respository component of the
		-- internal architecture.
		-- If the current assembly does not provide this component, this field is
		-- 'nil'.
		--
		-- @usage oil.types:register(oil.corba.idl.sequence{oil.corba.idl.string}) .
		-- @usage oil.types:lookup("CORBA::StructDescription")                     .
		-- @usage oil.types:lookup_id("IDL:omg.org/CORBA/InterfaceDef:1.0")        .
		--
		self.types = self.TypeRepository.types
		self.TypeRepository.compiler.defaults.incpath = config.idlpaths
	end
	if self.ClientChannels ~= nil and config.tcpoptions then
		self.ClientChannels.options = config.tcpoptions
	end
	if self.ServerChannels ~= nil and config.tcpoptions then
		self.ServerChannels.options = config.tcpoptions
	end
	if self.ServantManager ~= nil then
		self.ServantManager.prefix = config.keyprefix
		if config.objectmap ~= nil then
			self.ServantManager.map = config.objectmap
		end
	end
	if self.ValueEncoder ~= nil then
		if config.valuefactories == nil then
			config.valuefactories = {}
		end
		self.ValueEncoder.factories = config.valuefactories
		if config.localrefs ~= nil then
			self.ValueEncoder.localrefs = config.localrefs
		end
	end
	assert(self.RequestReceiver.acceptor:setup(self))
	
	return self
end

--------------------------------------------------------------------------------
-- Loads an IDL code strip into the internal interface repository.
--
-- The IDL specified will be parsed by the LuaIDL compiler and the resulting
-- definitions are updated in the internal interface repository.
-- If any errors occurs during the parse no definitions are loaded into the IR.
--
-- @param idlspec string The IDL code strip to be loaded into the local IR.
-- @return ... object IDL descriptors that represents the loaded definitions.
--
-- @usage oil.loadidl [[
--          interface Hello {
--            attribute boolean quiet;
--            readonly attribute unsigned long count;
--            string say_hello_to(in string msg);
--          };
--        ]]                                                                 .
--
function ORB:loadidl(idlspec)
	asserttype(idlspec, "string", "IDL specification")
	return assert(self.TypeRepository.compiler:load(idlspec))
end

--------------------------------------------------------------------------------
-- Loads an IDL file into the internal interface repository.
--
-- The file specified will be parsed by the LuaIDL compiler and the resulting
-- definitions are updated in the internal interface repository.
-- If any errors occurs during the parse no definitions are loaded into the
-- IR.
--
-- @param filename string The path to the IDL file that must be loaded.
-- @return ... object IDL descriptors that represents the loaded definitions.
--
-- @usage oil.loadidlfile "/usr/local/corba/idl/CosNaming.idl"               .
--
function ORB:loadidlfile(filepath, idlpaths)
	asserttype(filepath, "string", "IDL file path")
	return assert(self.TypeRepository.compiler:loadfile(filepath, idlpaths))
end

--------------------------------------------------------------------------------
-- Loads a parsed IDL file into the internal interface repository.
--
-- The parsed IDL is a table containing the result of LuaIDL. The IDL
-- definitions are updated in the internal interface repository.
--
-- @param parsedidl table The parsed IDL that must be loaded.
-- @return ... object IDL descriptors that represents the loaded definitions.
--
function ORB:loadparsedidl(parsedidl)
	asserttype(parsedidl, "table", "IDL description")
	return assert(self.TypeRepository.types:register(parsedidl))
end

--------------------------------------------------------------------------------
-- Get the servant of the internal interface repository.
--
-- Function used to retrieve a reference to the integrated Interface Repository.
-- It returns a reference to the object that implements the internal Interface
-- Repository and exports local cached interface definitions.
--
-- @return proxy CORBA object that exports the local interface repository.
--
-- @usage oil.writeto("ir.ior", oil.tostring(oil.getLIR()))                    .
--
function ORB:getLIR()
	return self:newservant(self.types,
	                       "InterfaceRepository",
	                       "IDL:omg.org/CORBA/Repository:1.0")
end

--------------------------------------------------------------------------------
-- Get the remote interface repository used to retrieve interface definitions.
--
-- Function used to set the remote Interface Repository that must be used to
-- retrieve interface definitions not stored in the internal IR.
-- Once these definitions are acquired, they are stored in the internal IR.
--
-- @return proxy Proxy for the remote IR currently used.
--
function ORB:getIR()
	return self.TypeRepository.delegated
end

--------------------------------------------------------------------------------
-- Defines a remote interface repository used to retrieve interface definitions.
--
-- Function used to get a reference to the Interface Repository used to retrieve
-- interface definitions not stored in the internal IR.
--
-- @param ir proxy Proxy for the remote IR to be used.
--
-- @usage oil.setIR(oil.newproxy("corbaloc::cos_host/InterfaceRepository",
--                               "IDL:omg.org/CORBA/Repository:1.0"))          .
--
function ORB:setIR(ir)
	self.TypeRepository.delegated = ir
end

--------------------------------------------------------------------------------
-- Creates a proxy for a remote object defined by a textual reference.
--
-- The value of reference must be a string containing reference information of
-- the object the new new proxy will represent like a stringfied IOR
-- (Inter-operable Object Reference) or corbaloc.
-- Optionally, an interface supported by the remote object may be defined, in
-- this case no attempt is made to determine the actual object interface, i.e.
-- no network communication is made to check the object's interface.
--
-- @param object string Textual representation of object's reference the new
-- proxy will represent.
-- @param interface string [optional] Interface identification in the interface
-- repository, like a repID or absolute name of a interface the remote object
-- supports (no interface or type check is done).
--
-- @return table Proxy to the remote object.
--
-- @usage oil.newproxy("IOR:00000002B494...")                                  .
-- @usage oil.newproxy("IOR:00000002B494...", "HelloWorld::Hello")             .
-- @usage oil.newproxy("IOR:00000002B494...", "IDL:HelloWorld/Hello:1.0")      .
-- @usage oil.newproxy("corbaloc::host:8080/Key", "IDL:HelloWorld/Hello:1.0")  .
--
function ORB:newproxy(reference, kind, iface)
	if type(reference) == "string" then
		reference = assert(self.ObjectReferrer.references:decodestring(reference))
	else
		iface = iface or reference.__type
		reference = reference.__reference
	end
	local proxykind = self.proxykind
	local ProxyManager = proxykind[ kind or proxykind[1] ]
	if ProxyManager == nil then illegal(kind, "proxy kind") end
	return assert(ProxyManager.proxies:newproxy{
		__reference = reference,
		__type = iface,
	})
end

--------------------------------------------------------------------------------
-- Narrow an object reference into some more specific interface supported by the
-- remote object.
--
-- The object's reference is defined as a proxy object.
-- If you wish to create a proxy to an object specified by a textual reference
-- like an IOR (Inter-operable Object Reference) that is already narrowed into
-- function.
-- The interface the object reference must be narrowed into is defined by the
-- parameter 'interface' (e.g. an interface repository ID).
-- If no interface is defined, then the object reference is narrowed to the most
-- specific interface supported by the remote object.
-- Note that in the former case, no attempt is made to determine the actual
-- object interface, i.e. no network communication is made to check the object's
-- interface.
--
-- @param proxy table Proxy that represents the remote object which reference
-- must be narrowed.
-- @param interface string [optional] Identification of the interface the
-- object reference must be narrowed into (no interface or type check is
-- made).
--
-- @return table New proxy to the remote object narrowed into some interface
-- supported by the object.
--
-- @usage oil.narrow(ns:resolve_str("HelloWorld"))                             .
-- @usage oil.narrow(ns:resolve_str("HelloWorld"), "IDL:HelloWorld/Hello:1.0") .
--
-- @see newproxy
--
function ORB:narrow(object, type)
	if object then
		asserttype(object, "table", "object proxy")
		local proxykind = self.proxykind
		local ProxyManager = proxykind[ proxykind[1] ]
		return assert(ProxyManager.proxies:newproxy{
			__reference = object.__reference,
			__type = type,
		})
	end
end

--------------------------------------------------------------------------------
-- Creates a new servant implemented in Lua that supports some interface.
--
-- Function used to create a new servant from a table containing attribute
-- values and operation implementations.
-- The value of impl is used as the implementation of the a servant with
-- interface defined by parameter interface (e.g. repository ID or absolute
-- name of a given IDL interface stored in the IR).
-- Optionally, an object key value may be specified to create persistent
-- references.
-- The servant returned by this function offers all servant attributes and
-- methods, as well as implicit basic operations like CORBA's _interface or
-- _is_a.
-- After this call any requests which object key matches the key of the servant
-- are dispathed to its implementation.
--
-- @param object table Value used as the servant implementation (may be any
-- indexable value, e.g. userdata with a metatable that defined the __index
-- field).
-- @param interface string Interface identification line an absolute name of the
-- interface in the internal interface repository.
-- @param key string [optional] User-defined object key used in creation of the
-- object reference.
--
-- @return table servant created.
--
-- @usage oil.newservant({say_hello_to=print}, nil,"IDL:HelloWorld/Hello:1.0") .
-- @usage oil.newservant({say_hello_to=print}, nil,"::HelloWorld::Hello")      .
-- @usage oil.newservant({say_hello_to=print}, "Key","::HelloWorld::Hello")    .
--
function ORB:newservant(impl, key, type)
	if impl == nil then illegal(impl, "servant's implementation") end
	if key ~= nil then asserttype(key, "string", "servant's key") end
	return assert(self.ServantManager.servants:register{
		__servant = impl,
		__objkey = key,
		__type = type,
	})
end

--------------------------------------------------------------------------------
-- Deactivates a servant by removing its implementation from the object map.
--
-- If 'object' is a servant (i.e. the object returned by 'newservant') then it
-- is deactivated.
-- Alternatively, the 'object' parameter may be the servant's object key.
-- Only in the case that the servant was created with an implicitly created key
-- by the ORB then the 'object' can be the servant's implementation.
-- Since a single implementation object can be used to create many servants with
-- different interface, in this case the 'type' parameter must be provided with
-- the exact servant's interface.
--
-- @param object string|object Servant's object key, servant's implementation or
-- servant itself.
-- @param type string Identification of the servant's interface (e.g. repository
-- ID or absolute name).
--
-- @usage oil.deactivate(oil.newservant(impl, "::MyInterface", "objkey"))      .
-- @usage oil.deactivate("objkey")                                             .
-- @usage oil.deactivate(impl, "MyInterface")                                  .
--
function ORB:deactivate(object, type)
	if not object then
		illegal(object,
			"object reference (servant, implementation or object key expected)")
	end
	return self.ServantManager.servants:unregister(object, type)
end

--------------------------------------------------------------------------------
-- Checks whether there is some request pending
--
-- Function used to checks whether there is some unprocessed ORB request
-- pending.
-- It returns true if there is some request pending that must be processed by
-- the main ORB or false otherwise.
--
-- @return boolean True if there is some ORB request pending or false otherwise.
--
-- @usage while oil.pending() do oil.step() end                                .
--
function ORB:pending(timeout)
	if timeout ~= nil then timeout = timeout+currenttime() end
	return assert(self.RequestReceiver.acceptor:probe(timeout))
end

--------------------------------------------------------------------------------
-- Waits for an ORB request and process it.
--
-- Function used to wait for an ORB request and process it.
-- Only one single ORB request is processed at each call.
-- It returns true if no exception is raised during request processing, or 'nil'
-- and the raised exception otherwise.
--
-- @usage while oil.pending() do oil.step() end                                .
--
function ORB:step(timeout)
	if timeout ~= nil then timeout = timeout+currenttime() end
	return self.RequestReceiver.acceptor:step(timeout)
end

--------------------------------------------------------------------------------
-- Runs the ORB main loop.
--
-- Function used to process all remote requisitions continuously until some
-- exception is raised.
-- If an exception is raised during the processing of requests this function
-- returns nil and the raised exception.
-- This function implicitly initiates the ORB if it was not initialized yet.
--
-- @see init
--
function ORB:run()
	return assert(self.RequestReceiver.acceptor:start())
end

--------------------------------------------------------------------------------
-- Shuts down the ORB.
--
-- Stops the ORB main loop if it is executing, handles all pending requests and
-- closes all connections.
--
-- @usage oil.shutdown()
--
function ORB:shutdown()
	local acceptor = self.RequestReceiver.acceptor
	assert(acceptor:stop(true))
	assert(acceptor:shutdown())
	assert(acceptor:setup(self)) -- so it can be started again
end

--------------------------------------------------------------------------------
-- Creates a new value encoder that marshal values into strings.
--
-- The encoder marshals values in a CORBA's CDR encapsulated stream, i.e.
-- includes an indication of the endianess used in value codification.
--
-- @return object Value encoder that provides operation 'put(value, [type])' to
-- marshal values and operation 'getdata()' to get the marshaled stream.
--
-- @usage encoder = oil.newencoder(); encoder:put({1,2,3}, oil.corba.idl.sequence{oil.corba.idl.long})
-- @usage encoder = oil.newencoder(); encoder:put({1,2,3}, oil.types:lookup("MyLongSeq"))
--
function ORB:newencoder()
	return assert(self.ValueEncoder.codec:encoder(true))
end

--------------------------------------------------------------------------------
-- Creates a new value decoder that extracts marshaled values from strings.
--
-- The decoder reads CORBA's CDR encapsulated streams, i.e. includes an
-- indication of the endianess used in value codification.
--
-- @param stream string String containing a stream with marshaled values.
--
-- @return object Value decoder that provides operation 'get([type])' to
-- unmarshal values from a marshaled stream.
--
-- @usage decoder = oil.newdecoder(stream); val = decoder:get(oil.corba.idl.sequence{oil.corba.idl.long})
-- @usage decoder = oil.newdecoder(stream); val = decoder:get(oil.types:lookup("MyLongSeq"))
--
function ORB:newdecoder(stream)
	asserttype(stream, "string", "byte stream")
	return assert(self.ValueEncoder.codec:decoder(stream, true))
end

--------------------------------------------------------------------------------
-- Creates a new exception object with the given body.
--
-- The 'body' must contain the values of the exceptions fields and must also
-- contain the exception identification in index 1 (in CORBA this
-- identification is a repID).
--
-- @param body table Exception body with all its field values and exception ID.
--
-- @return object Exception that provides meta-method '__tostring' that provides
-- a pretty-printing.
--
-- @usage error(oil.newexcept{ "IDL:omg.org.CORBA/INTERNAL:1.0", minor = 2 })
--
function ORB:newexcept(body)
	asserttype(body, "table", "exception body")
	local except = self.types and self.types:resolve(body[1])
	if except then body._repid = except.repID end
	return self.Exception(body)
end

--------------------------------------------------------------------------------
-- Defines a exception handling function for proxies.
--
-- The handling function receives the following parameters:
--   proxy    : object proxy that perfomed the operation.
--   exception: exception/error raised.
--   operation: descriptor of the operation that raised the exception.
-- If the parameter 'type' is provided, then the exception handling function
-- will be applied only to proxies of that type (i.e. interface).
-- Exception handling functions are nor cumulative.
-- For example, is the is an exception handling function defined for all proxies
-- and other only for proxies of a given type, then the later will be used for
-- proxies of that given type.
-- Additionally, exceptions handlers are not inherited through interface
-- hierarchies.
--
-- @param handler function Exception handling function.
-- @param type string Interface ID of a group of proxies (e.g. repID).
--
-- @usage oil.setexcatch(function(_, except) error(tostring(except)) end)
--
function ORB:setexcatch(handler, type)
	local managers = {}
	for _, name in ipairs(self.proxykind) do
		managers[#managers+1] = self.proxykind[name]
	end
	for _, manager in pairs(managers) do
		assert(manager.proxies:excepthandler(handler, type))
	end
end

--------------------------------------------------------------------------------
-- Sets a CORBA-specific interceptor for operation invocations in the client-size.
--
-- The interceptor must provide the following operations
--
--  send_request(request): 'request' structure is described below.
--    response_expected: [boolean] (read-only)
--    object_key: [string] (read-only)
--    operation: [string] (read-only) Operation name.
--    service_context: [table] Set this value to a table mapping service context
--      IDs to the octets representing the values.
--    success: [boolean] set this value to cancel invocation:
--      true ==> invocation successfull
--      false ==> invocation raised an exception
--    Note: The integer indexes store the operation's parameter values and
--    should also be used to store the results values if the request is canceled
--    (see note below).
--
--  receive_reply(reply): 'reply' structure is described below.
--    service_context: [table] (read-only) table mapping service context IDs to
--      the octets representing the values.
--    reply_status: [string] (read-only)
--    success: [boolean] Identifies the kind of result:
--      true ==> invocation successfull
--      false ==> invocation raised an exception
--    Note: The integer indexes store the results that will be sent as request
--    result. For successful invocations these values must be the operation's
--    results (return, out and inout parameters) in the same order they appear
--    in the IDL description. For failed invocations, index 1 must be the
--    exception that identifies the failure.
--
-- The 'request' and 'reply' are the same table in a single invocation.
-- Therefore, the fields of 'request' are also available in 'reply' except for
-- those defined in the description of 'reply'.
--
function ORB:setclientinterceptor(iceptor)
	return self:setinterceptor(iceptor, "corba.client")
end

--------------------------------------------------------------------------------
-- Sets a CORBA-specific interceptor for operation invocations in the server-size.
--
-- The interceptor must provide the following operations
--
--  receive_request(request): 'request' structure is described below.
--    service_context: [table] (read-only) table mapping service context IDs to
--      the octets representing the values.
--    request_id: [number] (read-only)
--    response_expected: [boolean] (read-only)
--    object_key: [string] (read-only)
--    operation: [string] (read-only) Operation name.
--    servant: [object] (read-only) Local object the invocation will be dispatched to.
--    method: [function] (read-only) Function that will be invoked on object 'servant'.
--    success: [boolean] Set this value to cancel invocation:
--      true ==> invocation successfull
--      false ==> invocation raised an exception
--    Note: The integer indexes store the operation's parameter values and
--    should also be used to store the results values if the request is canceled
--    (see note below).
--
--  send_reply(reply): 'reply' structure is described below.
--    service_context: [table] Set this value to a table mapping service context
--      IDs to the octets representing the values.
--    success: [boolean] identifies the kind of result:
--      true ==> invocation successfull
--      false ==> invocation raised an exception
--    Note: The integer indexes store the results that will be sent as request
--    result. For successful invocations these values must be the operation's
--    results (return, out and inout parameters) in the same order they appear
--    in the IDL description. For failed invocations, index 1 must be the
--    exception that identifies the failure.
--
-- The 'request' and 'reply' are the same table in a single invocation.
-- Therefore, the fields of 'request' are also available in 'reply' except for
-- those defined in the description of 'reply'.
--
function ORB:setserverinterceptor(iceptor)
	return self:setinterceptor(iceptor, "corba.server")
end

--------------------------------------------------------------------------------

function ORB:setinterceptor(iceptor, kind)
	local corbakind = kind:match("^corba(.-)$")
	if corbakind then
		if corbakind ~= ".server" then
			self.OperationRequester.interceptor = iceptor
		end
		if corbakind ~= ".client" then
			self.RequestListener.interceptor = iceptor
		end
	else
		if kind ~= "server" then
			local Wrapper = require "oil.kernel.intercepted.Requester"
			local wrapper = Wrapper{
				__object = self.OperationRequester.requests,
				interceptor = iceptor,
			}
			for _, kind in ipairs(self.proxykind) do
				local ProxyManager = self.proxykind[kind]
				ProxyManager.requester = wrapper
			end
		end
		if kind ~= "client" then
			local Wrapper = require "oil.kernel.intercepted.Listener"
			local wrapper = Wrapper{
				__object = self.RequestListener.requests,
				interceptor = iceptor,
			}
			self.RequestReceiver.listener = wrapper
		end
	end
end

function ORB:getinterceptor(kind)
	local corbakind = kind:match("^corba(.-)$")
	if corbakind then
		local srviceptor = self.RequestListener.interceptor
		local clticeptor = self.OperationRequester.interceptor
		if corbakind == ".server" then
			return srviceptor
		elseif corbakind ~= ".client" then
			return clticeptor
		elseif srviceptor == clticeptor then
			return srviceptor
		end
	else
		local wrapper = self.RequestReceiver.listener
		if kind == "server" then
			if wrapper ~= self.RequestListener.requests then
				return wrapper.interceptor
			end
		elseif kind == "client" then
			local requests = self.OperationRequester.requests
			for _, kind in ipairs(self.proxykind) do
				local ProxyManager = self.proxykind[kind]
				local wrapper = ProxyManager.requester
				if wrapper ~= requests then
					return wrapper.interceptor
				end
			end
		else
			local srvicpt = self:getinterceptor("server")
			local clticpt = self:getinterceptor("client")
			if srvicpt == clticpt then
				return srvicpt
			end
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local oil = {                                                                   --[[VERBOSE]] verbose = verbose,
	VERSION = "OiL 0.6",
	ORB = ORB,
}

local cothread = _G.package.loaded.cothread
if cothread == nil then
	--[[DEBUG]] pcall(require, "inspector") -- must be required before 'coroutine.pcall'
	if _G._VERSION == "Lua 5.1" then
		require "coroutine.pcall" -- to avoid coroutine limitation of Lua 5.1
	end
	local ok, result = pcall(require, "cothread")
	if ok then
		cothread = result
	end
end

if cothread then
	cothread.plugin(require "cothread.plugin.socket")
	--[[VERBOSE]] verbose.viewer.labels = cothread.verbose.viewer.labels
	--[[VERBOSE]] verbose.tabsof = cothread.verbose.tabsof
end

--------------------------------------------------------------------------------
-- Initialize the OiL main ORB.
--
-- Creates and initialize a ORB instance with the provided configurations.
-- If no configuration is provided, a default ORB instance is returned.
-- The configuration values may differ accordingly to the underlying protocol.
-- For example, for CORBA brokers the current options are the host name or IP
-- address and port that ORB must bind to, as well as the host name or IP
-- address and port that must be used in creation of object references.
--
-- The 'flavor' configuration field defines a list of archtectural levels.
-- Each level defines a set of components and connections that extends the
-- following level.
--
-- Components are created by builder modules registered under namespace
-- 'oil.builder.*' that must provide a 'create(components)' function.
-- The parameter 'components' is a table with all components created by the
-- previous levels builders and that must be used to store the components
-- created by the builder.
--
-- Components created by a previous builder should not be replaced by components
-- created by following builders.
-- After all level components are they are assembled by assembler modules
-- registered under namespace 'oil.arch.*' that must provide a
-- 'assemble(components)' function.
-- The parameter 'components' is a table with all components created by the
-- levels builders.
--
-- @param config table Configuration used to create the ORB instance.
-- @return table The ORB instance created/obtained.
--
-- @usage oil.init()                                                           .
-- @usage oil.init{ host = "middleware.inf.puc-rio.br" }                       .
-- @usage oil.init{ host = "10.223.10.56", port = 8080 }                       .
-- @usage oil.init{ port = 8080, flavor = "corba;typed;base" }                 .
-- @usage oil.init{ port = 8080, flavor = "ludo;cooperative;base" }            .
--
local Default
function oil.init(config)
	if config == nil then
		if Default then return Default end
		Default = {}
		config = Default
	end
	if config.flavor == nil then
		config.flavor = "cooperative;corba"
	end
	asserttype(config.flavor, "string", "ORB flavor")
	return ORB(config)
end

--------------------------------------------------------------------------------
-- Function executes the main function of the application.
--
-- The application's main function is executed in a new thread if the current
-- assembly provides thread support.
-- This may only return when the application terminates.
--
-- @param main function Appplication's main function.
--
-- @usage oil.main(orb.run, orb)
-- @usage oil.main(function() print(oil.tostring(oil.getLIR())) oil.run() end)
--
local function extracer(ex)
	return traceback(tostring(ex))
end

if cothread then
	function cothread.error(thread, errmsg)
		error(traceback(thread, tostring(errmsg)), 3)
	end
end

function oil.main(main, ...)
	asserttype(main, "function", "main function")
	local success, except
	if cothread then
		local thread = newcoroutine(main)                                           --[[VERBOSE]] verbose.viewer.labels[thread] = "oil.main"
		success, except = pcall(cothread.run, cothread.step(thread, ...))
	else
		success, except = xpcall(main, extracer, ...)
	end
	if not success then error(tostring(except), 2) end
end

--------------------------------------------------------------------------------
-- Creates and starts the execution of a new the thread.
--
-- Creates a new thread to execute the function 'func' with the extra parameters
-- provided.
-- This function imediately starts the execution of the new thread and the
-- original thread is only resumed again acordingly to the the scheduler's
-- internal policy.
-- This function can only be invocated from others threads, including the one
-- executing the application's main function (see 'main').
--
-- @param func function Function that the new thread will execute.
-- @param ... any Additional parameters passed to the 'func' function.
--
-- @usage oil.main(function() oil.newthread(oil.run) oil.newproxy(oil.readfrom("ior")):register(localobj) end)
--
-- @see main
--
function oil.newthread(func, ...)
	asserttype(func, "function", "thread body")
	return yield("next", newcoroutine(func) , ...)
end

--------------------------------------------------------------------------------
-- Suspends the execution of the current thread for some time.
--
-- @param time number Delay in seconds that the execution must be resumed.
--
-- @usage oil.sleep(5.5)
--
if cothread then
	function oil.sleep(time)
		asserttype(time, "number", "time")
		return yield("delay", time)
	end
else
	local _sleep = require("socket.core").sleep
	function oil.sleep(time)
		asserttype(time, "number", "time")
		return _sleep(time)
	end
end

--------------------------------------------------------------------------------
-- Get the current system time.
--
-- @return number Number of seconds since a fixed point in the past.
--
-- @usage local start = oil.time(); oil.sleep(3); print("I slept for", oil.time() - start)
--
if cothread then
	function currenttime()
		return yield("now")
	end
else
	currenttime = require("socket.core").gettime
end
oil.time = currenttime

--------------------------------------------------------------------------------
-- Writes a text into file.
--
-- Utility function for writing stringfied IORs into a file.
--
function oil.writeto(filepath, data, mode)
	local result, errmsg = open(filepath, mode or "w")
	if result then
		local file = result
		result, errmsg = file:write(tostring(data))
		file:close()
	end
	return result, errmsg
end

--------------------------------------------------------------------------------
-- Read the contents of a file.
--
-- Utility function for reading stringfied IORs from a file.
--
function oil.readfrom(filepath, mode)
	local result, errmsg = open(filepath, mode)
	if result then
		local file = result
		result, errmsg = file:read("*a")
		file:close()
	end
	return result, errmsg
end

return oil
