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

local rawget = rawget
local type   = type

local table = require "loop.table"

local ObjectCache = require "loop.collection.ObjectCache"

local oo        = require "oil.oo"
local Exception = require "oil.Exception"
local Proxies   = require "oil.kernel.base.Proxies"                             --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.kernel.typed.Proxies", oo.class)

context = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local Proxy = Proxies.Proxy
local Deferred = Proxies.Deferred

local CachedIndex = oo.class({}, Proxy)

function CachedIndex:newinvoker(operation)
	return function(self, ...)                                                    --[[VERBOSE]] verbose:proxies("call to ",operation, ...)
		return Proxies.checkresults(self, operation, 
		       	Proxies.checkcall(self, operation,
		       		self.__context.invoker:invoke(self, operation, ...)
		       	):results()
		       )
	end
end

function CachedIndex:__index(field)
	if type(field) == "string" then
		local context = self.__context
		local operation, value, cached = context.indexer:valueof(self.__type, field)
		if cached then
			if operation and value == nil then
				value = oo.classof(self):newinvoker(operation)
			end
			self[field] = value
		elseif operation and value == nil then
			value = oo.superclass(oo.classof(self)).__index(self, operation)
		end
		return value
	end
end

--------------------------------------------------------------------------------

local DeferredIndex = oo.class({ __index = CachedIndex.__index }, Deferred--[[, CachedIndex]])

function DeferredIndex:newinvoker(operation)
	return function(self, ...)                                                   --[[VERBOSE]] verbose:proxies("deferred call to ",operation, ...)
		self = self[1]
		local reply = Proxies.checkcall(self, operation,
			self.__context.invoker:invoke(self, operation, ...))
		reply.proxy = self
		reply.operation = operation
		reply.results = Proxies.deferredresults
		return reply
	end
end

--------------------------------------------------------------------------------

function __init(self, object)
	self = oo.rawnew(self, object)
	self.classes = ObjectCache()
	function self.classes.retrieve(_, type)
		return CachedIndex(oo.initclass{
			__context = self.context,
			__type = type,
			__deferred = DeferredIndex(oo.initclass{
				__context = self.context,
				__type = type,
			}),
		})
	end
	return self
end

--------------------------------------------------------------------------------

function proxyto(self, reference, type)                                         --[[VERBOSE]] verbose:proxies(true, "new proxy to ",reference)
	local context = self.context
	type = type or context.indexer:typeof(reference)
	local result, except = self.classes[type]
	if result then
		reference = oo.rawnew(result, reference)
		reference.__deferred = oo.rawnew(result.__deferred, {reference})
		result = reference
	else
		except = Exception{
			reason = "type",
			message = "unable to get type for reference",
			reference = reference,
			type = type,
		}
	end                                                                           --[[VERBOSE]] verbose:proxies(false)
	return result, except
end

function excepthandler(self, handler, type)
	if type then
		local result, except = self.classes[type]
		if result then
			result.__exceptions = handler
		else
			except = Exception{
				reason = "type",
				message = "unknown type",
				type = type,
			}
		end
		return result, except
	else
		return Proxies.excepthandler(self, handler)
	end
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
