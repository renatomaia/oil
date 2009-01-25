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
-- Title  : Server-Side Broker                                                --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- broker:Facet
-- 	servant:object register(impl:object, [objectkey:string])
-- 	impl:object remove(servant:object|impl:object|objectkey:string)
-- 	impl:object retrieve(objectkey:string)
-- 	reference:string tostring(servant:object)
--
-- referrer:Receptacle
-- 	reference:table newreference(objectkey:string, accesspointinfo:table...)
-- 	stringfiedref:string encode(reference:table)
-- 
-- types:Receptacle
-- 	type:table resolve(type:string)
--------------------------------------------------------------------------------

local getmetatable = getmetatable
local rawget       = rawget
local type         = type

local table = require "loop.table"

local oo       = require "oil.oo"
local Servants = require "oil.kernel.base.Servants"                             --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.kernel.typed.Servants"

oo.class(_M, Servants)

context = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function addentry(self, key, impl, type)
	local entry = self.map[key]
	if entry == nil
	or entry.object ~= impl
	or entry.type ~= type
	then
		return Servants.addentry(self, key, { object = impl, type = type })
	end
	return true
end

function removeentry(self, key)
	local result, except = Servants.removeentry(self, key)
	if result then result, except = result.object, result.type end
	return result, except
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local KeyFmt = "\0%s%s"

function register(self, object, key, type)
	local context = self.context
	local metatable = getmetatable(object)
	if metatable then
		type = object.__type   or metatable.__type   or type
		key  = object.__objkey or metatable.__objkey or key
	else
		type = object.__type   or type
		key  = object.__objkey or key
	end
	local result, except = context.types:resolve(type)
	if result then
		key = key or KeyFmt:format(self:hashof(object), self:hashof(result))
		result, except = Servants.register(self, object, key, result)
	end
	return result, except
end

function remove(self, key, objtype)
	local context = self.context
	local result, except
	if type(key) == "table" then key = rawget(key, "_key") or key end
	if type(key) ~= "string" then
		result, except = context.types:resolve(result)
		if result
			then key = KeyFmt:format(self:hashof(key), self:hashof(result))
			else key = nil
		end
	end
	if key then
		result, except = self:removeentry(key)
	end
	return result, except
end

function retrieve(self, key)
	local result, except = Servants.retrieve(self, key)
	if result then result, except = result.object, result.type end
	return result, except
end
