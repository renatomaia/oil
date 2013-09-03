-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Server-Side Broker
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local assert = _G.assert
local getmetatable = _G.getmetatable
local pcall = _G.pcall
local rawget = _G.rawget
local rawset = _G.rawset
local tostring = _G.tostring
local type = _G.type

local table = require "loop.table"
local memoize = table.memoize

local oo = require "oil.oo"
local class = oo.class
local getclass = oo.getclass

local Exception = require "oil.Exception"


local function hashof(object)
	local meta = getmetatable(object)
	local backup
	if meta then
		backup = rawget(meta, "__tostring")
		if backup ~= nil then rawset(meta, "__tostring", nil) end
	end
	local hash = tostring(object)
	if meta then
		if backup ~= nil then rawset(meta, "__tostring", backup) end
	end
	return hash:match("%l+: (%w+)") or hash
end

local function index(indexable, field)
	return indexable[field]
end
local function pindex(indexable, field)
	local ok, value = pcall(index, indexable, field)
	if ok then return value end
end
local function getfield(object, field)
	return pindex(object, field)
	    or pindex(getmetatable(object), field)
end


local MethodWrapper = memoize(function(method)
	return function(self, ...)
		return method(self.__servant, ...)
	end
end, "k")


local Registered = class()

function Registered:__index(field)
	local value = Registered[field]
	if value == nil then
		value = self.__servant[field]
		if type(value) == "function" then
			value = MethodWrapper[value]
		end
	end
	return value
end

function Registered:__newindex(field, value)
	self.__servant[field] = value
end

function Registered:__deactivate()
	return self.__manager:removeentry(self.__objkey)
end

function Registered:__tostring()
	return tostring(self.__reference)
end



local Servants = class{
	hashof = hashof,
	getfield = getfield,
	Registered = Registered,
	prefix = "_",
}

function Servants:__init()
	self.map = self.map or {}
end

function Servants:getkey(servant)
	return getfield(servant, "__objkey")
	    or self.prefix..hashof(servant)
end

function Servants:makeentry(entry)
	local servant = entry.__servant
	if entry.__objkey == nil then
		entry.__objkey = self:getkey(servant)
	end
	if entry.__proxies == nil then
		entry.__proxies = getfield(servant, "__proxies")
	end
	return entry
end

function Servants:addentry(entry)
	local key = entry.__objkey
	local map = self.map
	local current = map[key]
	if current == nil then
		map[key] = entry                                                            --[[VERBOSE]] verbose:servants("object ",entry.__servant," registered with key ",key)
	elseif current.__servant ~= entry.__servant then
		return nil, Exception{
			"object key already in use (got $key)",
			error = "badobjkey",
			key = key,
		}
	end
	return entry
end

function Servants:removeentry(key)
	local map = self.map
	local entry = map[key]
	if entry == nil then
		return nil, Exception{
			"unknown object key (got $key)",
			error = "badobjkey",
			key = key,
		}
	end
	map[key] = nil                                                                --[[VERBOSE]] verbose:servants("object with key ",key," removed")
	return entry
end


function Servants:register(...)
	local result, except = self:makeentry(...)
	if result then
		assert(result.__servant ~= nil)
		local entry = result
		result, except = self.listener:getaddress()
		if result then
			result, except = self.referrer:newreference(entry, result)
			if result then
				entry.__reference = result
				result, except = self:addentry(entry)
				if result then
					result.__manager = self
					result = Registered(result)
				end
			end
		end
	end
	return result, except
end

function Servants:unregister(value)
	if type(value) ~= "string" then
		if getclass(value) == Registered then
			value = value.__objkey
		else
			value = self:getkey(value)
		end
	end
	return self:removeentry(value)
end

function Servants:retrieve(key)
	return self.map[key]
end

function Servants:localref(reference)
	local result, except = self.listener:getaddress("probe")
	if result then
		local key = reference:islocal(result)
		if key then
			return self.map[key]
		end
	end
end

return Servants
