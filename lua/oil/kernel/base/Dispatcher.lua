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
-- Title  : Object Request Dispatcher                                         --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- objects:Facet
-- 	object:object register(impl:object, key:string)
-- 	impl:object unregister(key:string)
-- 	impl:object retrieve(key:string)
-- 
-- dispatcher:Facet
-- 	success:boolean, [except:table]|results... dispatch(key:string, operation:string|function, params...)
--------------------------------------------------------------------------------

local luapcall     = pcall
local setmetatable = setmetatable
local type         = type                                                       --[[VERBOSE]] local select = select

local oo          = require "oil.oo"
local Exception   = require "oil.Exception"
local ObjectCache = require "loop.collection.ObjectCache"                       --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.kernel.base.Dispatcher", oo.class)

context = false

pcall = luapcall

--------------------------------------------------------------------------------
-- Servant object proxy

local function deactivate(self)
	return self._dispatcher:unregister(self._key)
end

local function indexer(self, key)
	local value = self.__newindex[key]
	if type(value) == "function"
		then return self.__methods[value]
		else return value
	end
end

function wrap(self, impl, key)
	local object
	object = {
		_deactivate = deactivate,
		_key = key,
		_dispatcher = self,
		__newindex = impl,
		__index = indexer,
		__methods = ObjectCache{
			retrieve = function(_, method)
				return function(_, ...)
					return method(object.__newindex, ...)
				end
			end
		}
	}
	return setmetatable(object, object)
end

--------------------------------------------------------------------------------
-- Objects facet

function __init(self, object)
	self = oo.rawnew(self, object)
	self.map = self.map or {}
	return self
end

function register(self, impl, key, ...)
	local result, except = self.map[key]
	if result then
		if result.__newindex ~= impl then
			result, except = nil, Exception{
				reason = "usedkey",
				message = "object key already in use",
				key = key,
			}
		end
	else                                                                          --[[VERBOSE]] verbose:dispatcher("object ",impl," registered with key ",key)
		result = self:wrap(impl, key, ...)
		self.map[key] = result
	end
	return result, except
end

function unregister(self, key)
	local map = self.map
	local impl = map[key]
	if impl then                                                                  --[[VERBOSE]] verbose:dispatcher("object with key ",key," unregistered")
		impl = impl.__newindex
		map[key] = nil
	end
	return impl
end

function retrieve(self, key)
	return self.map[key]
end

--------------------------------------------------------------------------------
-- Dispatcher facet

function dispatch(self, key, operation, default, ...)
	local object = self.map[key]
	if object then
		object = object.__newindex
		local method = object[operation] or default
		if method then                                                              --[[VERBOSE]] verbose:dispatcher("dispatching operation ",key,":",operation, ...)
			return self.pcall(method, object, ...)
		else
			return false, Exception{
				reason = "noimplement",
				message = "no implementation for operation of object with key",
				operation = operation,
				key = key,
			}
		end
	else
		return false, Exception{
			reason = "badkey",
			message = "no object with key",
			key = key,
		}
	end
end

--------------------------------------------------------------------------------

--[[VERBOSE]] function verbose.custom:dispatcher(...)
--[[VERBOSE]] 	local params
--[[VERBOSE]] 	for i = 1, select("#", ...) do
--[[VERBOSE]] 		local value = select(i, ...)
--[[VERBOSE]] 		local type = type(value)
--[[VERBOSE]] 		if params == true then
--[[VERBOSE]] 			params = "("
--[[VERBOSE]] 			if type == "string" then
--[[VERBOSE]] 				self.viewer.output:write(value)
--[[VERBOSE]] 			else
--[[VERBOSE]] 				self.viewer:write(value)
--[[VERBOSE]] 			end
--[[VERBOSE]] 		elseif type == "string" then
--[[VERBOSE]] 			if params then
--[[VERBOSE]] 				self.viewer.output:write(params)
--[[VERBOSE]] 				params = ", "
--[[VERBOSE]] 				self.viewer:write((value:gsub("[^%w%p%s]", "?")))
--[[VERBOSE]] 			else
--[[VERBOSE]] 				self.viewer.output:write(value)
--[[VERBOSE]] 				if value == ":" then params = true end
--[[VERBOSE]] 			end
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
