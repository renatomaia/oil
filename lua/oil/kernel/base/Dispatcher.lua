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
-- 
-- dispatcher:Facet
-- 	success:boolean, [except:table]|results... dispatch(key:string, operation:string|function, params...)
--------------------------------------------------------------------------------

local luapcall     = pcall
local setmetatable = setmetatable
local type         = type

local oo        = require "oil.oo"
local assert    = require "oil.assert"
local Exception = require "oil.Exception"                                       --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.kernel.base.Dispatcher", oo.class)

context = false

pcall = luapcall

--------------------------------------------------------------------------------
-- Servant object proxy

local function deactivate(self)
	return self._dispatcher:unregister(self._key)
end

local value, object
local function method(self, ...) return value(object, ...) end
local function indexer(self, key)
	object = self.__newindex
	value = object[key]
	if type(value) == "function"
		then return method
		else return value
	end
end

function wrap(self, impl, key)
	local object = {
		_deactivate = deactivate,
		_key = key,
		_dispatcher = self,
		__newindex = impl,
		__index = indexer,
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

function register(self, impl, key)
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
		result = self:wrap(impl, key)
		self.map[key] = result
	end
	return result, except
end

function unregister(self, key)
	local map = self.mpa
	local impl = map[key]
	if impl then                                                                  --[[VERBOSE]] verbose:dispatcher("object with key ",key" unregistered")
		impl = impl.__newindex
		map[key] = nil
	end
	return impl
end

--------------------------------------------------------------------------------
-- Dispatcher facet

function dispatch(self, key, operation, ...)
	local success, except
	local object = self.map[key]
	if object then
		object = object.__newindex
		local method = object[operation] or
		               type(operation) == "function" and operation
		if method then                                                              --[[VERBOSE]] verbose:dispatcher("dispatching operation ",operation," for object with key ",key)
			success, except = self.pcall(method, object, ...)
		else
			success, except = false, Exception{
				reason = "noimplement",
				message = "no implementation for operation of object with key",
				operation = operation,
				key = key,
			}
		end
	else
		success, except = false, Exception{
			reason = "badkey",
			message = "no object with key",
			key = key,
		}
	end
	return success, except
end
