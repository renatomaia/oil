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
local type   = type

local table = require "loop.table"

local ObjectCache = require "loop.collection.ObjectCache"

local oo        = require "oil.oo"
local Exception = require "oil.Exception"
local Proxies   = require "oil.kernel.base.Proxies"                             --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.kernel.typed.Proxies", oo.class)

context = false

--------------------------------------------------------------------------------

local function initcache(self, cache)
	return oo.rawnew(self, oo.initclass(cache))
end
function newcache(methodmaker)
	return oo.class{
		__init = initcache,
		__index = function(self, field)
			if type(field) == "string" then
				local context = self.__context
				local operation, value = context.indexer:valueof(self.__type, field)
				if value ~= nil then
					return methodmaker(value, operation)
				elseif operation then
					return methodmaker(function(self, ...)                                --[[VERBOSE]] verbose:proxies("call to ",operation, ...)
						return context.invoker:invoke(self.__reference, operation, ...)
					end, operation)
				end
			end
		end
	}
end

--------------------------------------------------------------------------------

ProxyClass     = newcache(Proxies.makemethod)
ProtectedClass = newcache(Proxies.makeprotected)
DeferredClass  = newcache(Proxies.makedeferred)

--------------------------------------------------------------------------------

local Extras = {
	__deferred =  DeferredClass,
	__try = ProtectedClass,
}

function __init(self, object)
	self = oo.rawnew(self, object)
	self.classes = ObjectCache{
		retrieve = function(_, type)
			return ProxyClass{
				__context = self.context,
				__type = type,
			}
		end
	}
	local extras = {}
	for label, class in pairs(Extras) do
		extras[label] = ObjectCache{
			retrieve = function(_, type)
				return class{
					__context = self.context,
					__type = type,
				}
			end
		}
	end
	self.extras = extras
	return self
end

--------------------------------------------------------------------------------

function proxyto(self, reference, type)                                         --[[VERBOSE]] verbose:proxies(true, "new proxy to ",reference)
	local context = self.context
	type = type or context.indexer:typeof(reference)
	local result, except = self.classes[type]
	if result then
		result = oo.rawnew(result, { __reference = reference })
		for label, classes in pairs(self.extras) do
			local class = classes[type]
			if class then
				result[label] = oo.rawnew(class, { __reference = reference })
			end
		end
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
			for label, classes in pairs(self.extras) do
				local class = classes[type]
				if class then
					class.__exceptions = handler
				end
			end
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
