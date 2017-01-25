-- Project: OiL - ORB in Lua: An Object Request Broker in Lua
-- Release: 0.6
-- Title  : OiL main programming interface (API)
-- Authors: Renato Maia <maia@inf.puc-rio.br>

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
local unpack = array.unpack

local OrderedSet = require "loop.collection.OrderedSet"

local oo = require "oil.oo"
local class = oo.class	
local rawnew = oo.rawnew

local cothread = _G.package.loaded.cothread
if cothread == nil then
	-- [[DEBUG]] pcall(require, "inspector") -- must be required before 'coroutine.pcall'
	local ok, result = pcall(require, "cothread")
	if ok then cothread = result end
end

if cothread then
	cothread.plugin(require "cothread.plugin.socket")
	--[[VERBOSE]] verbose.viewer.labels = cothread.verbose.viewer.labels
	--[[VERBOSE]] verbose.tabsof = cothread.verbose.tabsof
end

local builder = require "oil.builder"
local build = builder.build

local asserter = require "oil.assert"
local assert = asserter.results
local asserttype = asserter.type
local illegal = asserter.illegal

local currenttime

local ORB = class()

function ORB:__new(config)
	if type(config.flavor) == "string" then
		local flavors = {}
		for name in config.flavor:gmatch("[^;]+") do
			flavors[#flavors+1] = name
		end
		config.flavor = flavors
	end
	self = rawnew(self, build(config))
	
	if self.TypeRepository ~= nil then
		self.types = self.TypeRepository.types
		self.TypeRepository.compiler.defaults.incpath = config.idlpaths
	end
	local options = config.options
	if options ~= nil then
		local cltopt = (options.client==nil and options or options.client or nil)
		if cltopt ~= nil then
			if cltopt.security ~= nil then
				self:setsecurity(cltopt.security)
			end
			if self.ClientConnector ~= nil then
				self.ClientConnector.options = cltopt.tcp
				self.ClientConnector.sslcfg = cltopt.ssl
			end
		end
		local srvopt = (options.server==nil and options or options.server or nil)
		if srvopt ~= nil then
			if self.ServantManager ~= nil then
				self.ServantManager.secured = (srvopt.security == "required")
			end
			if self.ServerConnector ~= nil then
				self.ServerConnector.options = srvopt.tcp
				self.ServerConnector.sslcfg = srvopt.ssl
			end
		end
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
	if self.ResourceManager ~= nil then
		self.ResourceManager.inuse.maxsize = config.maxchannels or 1000
	end

	self:setup() -- implicit setup
	return self
end

function ORB:loadidl(idlspec, idlpaths)
	asserttype(idlspec, "string", "IDL specification")
	return assert(self.TypeRepository.compiler:load(idlspec, idlpaths))
end

function ORB:loadidlfile(filepath, idlpaths)
	asserttype(filepath, "string", "IDL file path")
	return assert(self.TypeRepository.compiler:loadfile(filepath, idlpaths))
end

function ORB:loadparsedidl(parsedidl)
	asserttype(parsedidl, "table", "IDL description")
	return assert(self.TypeRepository.types:register(parsedidl))
end

function ORB:getLIR()
	return self:newservant(self.types,
	                       "InterfaceRepository",
	                       "IDL:omg.org/CORBA/Repository:1.0")
end

function ORB:getIR()
	return self.TypeRepository.delegated
end

function ORB:setIR(ir)
	self.TypeRepository.delegated = ir
end

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

function ORB:newservant(impl, key, type)
	if impl == nil then illegal(impl, "servant's implementation") end
	if key ~= nil then asserttype(key, "string", "servant's key") end
	return assert(self.ServantManager.servants:register{
		__servant = impl,
		__objkey = key,
		__type = type,
	})
end

function ORB:deactivate(object, type)
	if not object then
		illegal(object,
			"object reference (servant, implementation or object key expected)")
	end
	return self.ServantManager.servants:unregister(object, type)
end

function ORB:pending(timeout)
	if timeout ~= nil then timeout = timeout+currenttime() end
	return self.RequestReceiver.acceptor:probe(timeout) ~= nil
end

function ORB:step(timeout)
	if timeout ~= nil then timeout = timeout+currenttime() end
	return self.RequestReceiver.acceptor:step(timeout)
end

function ORB:run()
	return assert(self.RequestReceiver.acceptor:start())
end

function ORB:setup(side)
	if side ~= "client" and self.RequestReceiver ~= nil then
		assert(self.RequestReceiver.acceptor:setup(self))
	end
	if side ~= "server" and self.OperationRequester ~= nil then
		assert(self.OperationRequester.requests:setup(self))
	end
end

function ORB:shutdown(side)
	if side ~= "client" and self.RequestReceiver ~= nil then
		local acceptor = self.RequestReceiver.acceptor
		acceptor:stop()
		assert(acceptor:shutdown())
	end
	if side ~= "server" and self.OperationRequester ~= nil then
		assert(self.OperationRequester.requests:shutdown())
	end
end

function ORB:newencoder()
	return assert(self.ValueEncoder.codec:encoder(true))
end

function ORB:newdecoder(stream)
	asserttype(stream, "string", "byte stream")
	return assert(self.ValueEncoder.codec:decoder(stream, true))
end

function ORB:newexcept(body)
	asserttype(body, "table", "exception body")
	local except = self.types and self.types:resolve(body[1])
	if except then body._repid = except.repID end
	return self.Exception(body)
end

function ORB:setonerror(callback)
	local acceptor = self.RequestReceiver.acceptor
	local old = rawget(acceptor, "notifyerror")
	acceptor.notifyerror = callback
	return old
end

function ORB:setexhandler(handler)
	local dispatcher = self.ServantManager.dispatcher
	local old = rawget(dispatcher, "notifyerror")
	dispatcher.exhandler = handler
	return old
end

do
	local utils = require "oil.kernel.base.Proxies.utils"
	local keys = utils.keys

	for name in pairs(keys) do
		local opname = "set"..name
		ORB[opname] = function (self, ...)
			local managers = {}
			for _, name in ipairs(self.proxykind) do
				managers[#managers+1] = self.proxykind[name]
			end
			for _, manager in pairs(managers) do
				local proxies = manager.proxies
				assert(proxies[opname](proxies, ...))
			end
		end
	end
end

function ORB:setclientinterceptor(iceptor)
	return self:setinterceptor(iceptor, "corba.client")
end

function ORB:setserverinterceptor(iceptor)
	return self:setinterceptor(iceptor, "corba.server")
end

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
		elseif corbakind == ".client" then
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

local oil = {                                                                   --[[VERBOSE]] verbose = verbose,
	VERSION = "OiL 0.6",
	ORB = ORB,
}

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

function oil.newthread(func, ...)
	asserttype(func, "function", "thread body")
	return yield("next", newcoroutine(func) , ...)
end

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

if cothread then
	function currenttime()
		return yield("now")
	end
else
	currenttime = require("socket.core").gettime
end
oil.time = currenttime

function oil.writeto(filepath, data, mode)
	local result, errmsg = open(filepath, mode or "w")
	if result then
		local file = result
		result, errmsg = file:write(tostring(data))
		file:close()
	end
	return (result ~= nil), errmsg
end

function oil.readfrom(filepath, binary)
	local result, errmsg = open(filepath, binary and "rb" or "r")
	if result then
		local file = result
		result, errmsg = file:read("*a")
		file:close()
	end
	return result, errmsg
end

return oil
