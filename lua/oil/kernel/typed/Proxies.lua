local error = error

--------------------------------------------------------------------------------
------------------------------  #####      ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------ ##   ## ##  ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------  #####  ### ###### ------------------------------
--------------------------------                --------------------------------
----------------------- An Object Request Broker in Lua ------------------------
--------------------------------------------------------------------------------
-- Project: OiL - ORB in Lua: An Object Request Broker in Lua                 --
-- Release: 0.4                                                               --
-- Title  : Remote Object Proxies                                             --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- proxies:Facet
-- 	proxy:object proxyto(reference:table)
--
-- indexer:Facet
-- 	interface:table typeof(reference:table)
-- 	member:table, [islocal:function], [cached:boolean] valueof(interface:table, name:string)
--
-- invoker:Receptacle
-- 	[results:object], [except:table] invoke(reference, operation, args...)
--------------------------------------------------------------------------------

--[[VERBOSE]] local select = select

local pairs  = pairs
local rawget = rawget
local rawset = rawset
local type   = type

local table = require "loop.table"

local ObjectCache = require "loop.collection.ObjectCache"

local oo        = require "oil.oo"
local Exception = require "oil.Exception"
local Proxies   = require "oil.kernel.base.Proxies"                             --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.kernel.typed.Proxies"

oo.class(_M, Proxies)

context = false

--------------------------------------------------------------------------------

function newcache(methodmaker)
	return oo.class{
		__index = function(cache, field)                                            --[[VERBOSE]] verbose:proxies(true, "attempt to invoke operation named ",field)
			local context = cache.__context
			local operation = context.indexer:valueof(cache.__type, field)
			if operation then
				local function invoker(self, ...)                                       --[[VERBOSE]] verbose:proxies("call to ",operation, ...)
					return context.requester:newrequest(self.__reference, operation, ...)
				end
				invoker = methodmaker(invoker, operation)                               --[[VERBOSE]] verbose:proxies(false, "operation named ",field," was created")
				cache[field] = invoker                                                  --[[VERBOSE]]
				return invoker                                                          --[[VERBOSE]] else verbose:proxies(false, "operation named ",field," not found")
			end
		end
	}
end

--------------------------------------------------------------------------------

ProxyClass     = newcache(Proxies.makemethod)
ProtectedClass = newcache(Proxies.makeprotected)
DeferredClass  = newcache(Proxies.makedeferred)

--------------------------------------------------------------------------------

local Classes = {
	ProxyClass,
	__deferred =  DeferredClass,
	__try = ProtectedClass,
}

function __init(self, object)
	self = oo.rawnew(self, object)
	local function narrow(proxy, type)
		return self:newproxy(proxy.__reference, type)
	end
	local prxcls = {}
	for label, class in pairs(Classes) do
		prxcls[label] = ObjectCache{
			retrieve = function(_, type)
				local class = class()
				local updater = {}
				function updater.notify()
					table.clear(class)
					class.__context = self.context
					class.__type = type
					class.__narrow = narrow
					class._narrow = narrow -- TODO:[maia] should be deprecated
					oo.initclass(class)
				end
				updater:notify()
				if type.observer then
					rawset(type.observer, class, updater)
				end
				return class
			end
		}
	end
	self.classes = prxcls[1]
	prxcls[1] = nil
	self.extras = prxcls
	return self
end

--------------------------------------------------------------------------------

function newproxy(self, reference, type)                                        --[[VERBOSE]] verbose:proxies("new proxy to ",reference," with type ",type)
	local result, except
	local context = self.context
	if not type then
		type, except = context.references:typeof(reference)
	end
	if type then
		type, except = context.types:resolve(type)
		if type then
			local class = self.classes[type]
			result = oo.rawnew(class, { __reference = reference })
			for label, classes in pairs(self.extras) do
				class = classes[type]
				if class then
					result[label] = oo.rawnew(class, { __reference = reference })
				end
			end
		end
	end
	return result, except
end

function excepthandler(self, handler, type)                                     --[[VERBOSE]] verbose:proxies("setting exception handler for proxies of ",type)
	local result, except = true
	local context = self.context
	if type then
		result, except = context.types:resolve(type)
		if result then type = result end
	end
	if result then
		if type then
			local class = self.classes[type]
			class.__exceptions = handler
			for label, classes in pairs(self.extras) do
				local class = classes[type]
				if class then
					class.__exceptions = handler
				end
			end
			return class
		else
			return Proxies.excepthandler(self, handler)
		end
	end
	return result, except
end

function resetcache(self, interface)
	local class = rawget(self.classes, interface)
	if class then
		table.clear(class)
	end
end

--------------------------------------------------------------------------------

--[[VERBOSE]] function verbose.custom:proxies(...)
--[[VERBOSE]] 	local params
--[[VERBOSE]] 	for i = 1, select("#", ...) do
--[[VERBOSE]] 		local value = select(i, ...)
--[[VERBOSE]] 		local type = type(value)
--[[VERBOSE]] 		if type == "string" then
--[[VERBOSE]] 			if params then
--[[VERBOSE]] 				self.viewer.output:write(params)
--[[VERBOSE]] 				params = ", "
--[[VERBOSE]] 				self.viewer:write((value:gsub("[^%w%p%s]", "?")))
--[[VERBOSE]] 			else
--[[VERBOSE]] 				self.viewer.output:write(value)
--[[VERBOSE]] 			end
--[[VERBOSE]] 		elseif not params and type == "table" and
--[[VERBOSE]] 		       value._type == "operation" then
--[[VERBOSE]] 			params = "("
--[[VERBOSE]] 			self.viewer.output:write(value.name)
--[[VERBOSE]] 		else
--[[VERBOSE]] 			if params then
--[[VERBOSE]] 				self.viewer.output:write(params)
--[[VERBOSE]] 				params = ", "
--[[VERBOSE]] 			end
--[[VERBOSE]] 			self.viewer:write(value)
--[[VERBOSE]] 		end
--[[VERBOSE]] 	end
--[[VERBOSE]] 	if params then
--[[VERBOSE]] 		self.viewer.output:write(params == "(" and "()" or ")")
--[[VERBOSE]] 	end
--[[VERBOSE]] end
