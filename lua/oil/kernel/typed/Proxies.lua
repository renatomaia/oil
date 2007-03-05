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
-- invoker:Receptacle
-- 	[results:object], [except:table] invoke(reference, operation, args...)
--------------------------------------------------------------------------------

--[[VERBOSE]] local select = select

local rawget = rawget
local type   = type

local table = require "loop.table"

local ObjectCache = require "loop.collection.ObjectCache"

local oo        = require "oil.oo"
local assert    = require "oil.assert"
local Exception = require "oil.Exception"
local Proxies   = require "oil.kernel.base.Proxies"                             --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.kernel.typed.Proxies", oo.class)

context = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local CachedIndex = oo.class({}, Proxies.Proxy)

function CachedIndex:__index(field)
	if type(field) == "string" then
		local deferred = field:match(CachedIndex.DeferredPattern)
		local context = self.__context
		local operation, value, cached = context.indexer:valueof(self.__type,
		                                                         deferred or field)
		if operation then
			if cached then
				if value == nil then
					if deferred then
						value = function(self, ...)                                         --[[VERBOSE]] verbose:proxies("deferred call to ",operation, ...)
							local reply = CachedIndex.doresult(self, operation,
								self.__context.invoker:invoke(self, operation, ...))
							reply.proxy = self
							reply.operation = operation
							reply.results = CachedIndex.results
							return reply
						end
					else
						value = function(self, ...)                                         --[[VERBOSE]] verbose:proxies("call to ",operation, ...)
							return select(2,
								CachedIndex.doresult(self, operation, 
									CachedIndex.doresult(self, operation,
										self.__context.invoker:invoke(self, operation, ...)
									):results()
								)
							)
						end
					end
				end
				self[field] = value
			else
				if value == nil then
					local proxies = context.proxies
					CachedIndex:currentop(operation)
					value = deferred and CachedIndex.defer or CachedIndex.invoke
				end
			end
		end
		return value
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
		result = oo.rawnew(result, reference)
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

function excepthandler(self, type, handler)
	local class = self.classes[type]
	class._exceptions = handler
end

function resetcache(self, interface)
	local class = rawget(self.classes, interface)
	if class then
		table.clear(class)
	end
end

--------------------------------------------------------------------------------

--[[VERBOSE]] function verbose.custom:proxies(...)
--[[VERBOSE]] 	local params = false
--[[VERBOSE]] 	for i = 1, select("#", ...) do
--[[VERBOSE]] 		local value = select(i, ...)
--[[VERBOSE]] 		local type = type(value)
--[[VERBOSE]] 		if type == "string" and not params then
--[[VERBOSE]] 			self.viewer.output:write(value)
--[[VERBOSE]] 		elseif type == "table" and rawget(value, "name") then
--[[VERBOSE]] 			self.viewer.output:write(value.name,"(")
--[[VERBOSE]] 			params = true
--[[VERBOSE]] 		else
--[[VERBOSE]] 			self.viewer:write(value)
--[[VERBOSE]] 		end
--[[VERBOSE]] 	end
--[[VERBOSE]] 	if params then self.viewer.output:write(")") end
--[[VERBOSE]] end
