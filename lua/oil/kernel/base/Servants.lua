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
--------------------------------------------------------------------------------

local getmetatable = getmetatable
local rawget       = rawget
local rawset       = rawset
local setmetatable = setmetatable
local luatostring  = tostring
local type         = type

local table = require "loop.table"
local ObjectCache = require "loop.collection.ObjectCache"                       --[[VERBOSE]] local verbose = require "oil.verbose"
local oo = require "oil.oo"
local Exception = require "oil.Exception"

module("oil.kernel.base.Servants", oo.class)

context = false
prefix = "_"

--------------------------------------------------------------------------------
-- Servant object proxy

local function deactivate(self)
	return self.__context.servants:removeentry(self.__key)
end

local function wrappertostring(self)
	return self.__context.referrer:encode(self.__reference)
end

local function wrapperindexer(self, key)
	local value = self.__newindex[key]
	if type(value) == "function"
		then return self.__methods[value]
		else return value
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function __init(self, ...)
	self = oo.rawnew(self, ...)
	self.map = self.map or {}
	return self
end

function addentry(self, key, entry)
	local result, except = self.map[key]
	if result then
		if result == entry then
			result = true
		else
			result, except = nil, Exception{
				reason = "usedkey",
				message = "object key already in use",
				key = key,
			}
		end
	else                                                                          --[[VERBOSE]] verbose:servants("object ",entry," registered with key ",key)
		self.map[key] = entry
		result = true
	end
	return result, except
end

function removeentry(self, key)
	local map = self.map
	local entry = map[key]
	if entry ~= nil then
		map[key] = nil
		return entry
	end
end

function hashof(self, object)
	local meta = getmetatable(object)
	local backup
	if meta then
		backup = rawget(meta, "__tostring")
		if backup ~= nil then rawset(meta, "__tostring", nil) end
	end
	local hash = luatostring(object)
	if meta then
		if backup ~= nil then rawset(meta, "__tostring", backup) end
	end
	return hash:match("%l+: (%w+)") or hash
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function setaccessinfo(self, ...)
	local result, except = true
	local accessinfo = self.accessinfo
	if not accessinfo then
		self.accessinfo = {...}
	else
		result, except = nil, Exception{
			reason = "configuration",
			message = "attempt to set access info twice",
			accessinfo = accessinfo,
		}
	end
	return result, except
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function register(self, object, key, ...)
	local context = self.context
	key = key or self.prefix..self:hashof(object)
	local result, except = self:addentry(key, object, ...)
	if result then
		result, except = context.referrer:newreference(self.accesspoint, key, ...)
		if result then
			result = {
				_deactivate = deactivate, -- TODO[maia]: DEPRECATED!
				__deactivate = deactivate,
				__context = context,
				__key = key,
				__tostring = wrappertostring,
				__index = wrapperindexer,
				__newindex = object,
				__reference = result,
				__methods = ObjectCache{
					retrieve = function(_, method)
						return function(_, ...)
							return method(object, ...)
						end
					end
				}
			}
			setmetatable(result, result)
		else
			self:removeentry(key)
		end
	end
	return result, except
end

function remove(self, object)
	local key
	if type(object) == "table" then
		key = rawget(object, "__key") or object
	end
	if type(key) ~= "string" then
		key = object.__objkey
		if key == nil then
			local meta = getmetatable(object)
			if meta then key = meta.__objkey end
			if key == nil then
				key = self.prefix..self:hashof(key)
			end
		end
	end
	return self:removeentry(key)
end

function retrieve(self, key)
	return self.map[key]
end
