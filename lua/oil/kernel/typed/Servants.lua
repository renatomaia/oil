-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Server-Side Broker
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local luatype = _G.type

local oo = require "oil.oo"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"
local class = oo.class
local getclass = oo.getclass

local Servants = require "oil.kernel.base.Servants"
local getfield = Servants.getfield
local hashof = Servants.hashof

local TypedServants = class({}, Servants)

function TypedServants:getkey(servant, type)
	return getfield(servant, "__objkey")
	    or self.prefix..hashof(servant)..hashof(type)
end

function TypedServants:makeentry(entry)
	local servant = entry.__servant
	local type = getfield(servant, "__type")
	if type ~= nil then entry.__type = type end
	local except
	type, except = self.types:resolve(entry.__type)
	if not type then return nil, except end
	entry.__type = type
	if entry.__objkey == nil then
		entry.__objkey = self:getkey(servant, type)
	end
	return Servants.makeentry(self, entry)
end

function TypedServants:addentry(entry)
	local key = entry.__objkey
	local map = self.map
	local current = map[key]
	if current == nil then
		map[key] = entry                                                            --[[VERBOSE]] verbose:servants("object ",entry.__servant," registered with key ",key)
	elseif current.__servant ~= entry.__servant
	    or current.__type ~= entry.__type then
		return nil, Exception{
			error = "badobjkey",
			message = "object key already in use (got $key)",
			key = key,
		}
	end
	return entry
end

function TypedServants:unregister(value, type)
	if luatype(value) ~= "string" then
		if getclass(value) == Registered then
			value = value.__objkey
		else
			local objkey = getfield(value, "__objkey")
			if objkey == nil then
				if type == nil then type = getfield(value, "__type") end
				local result, except = self.types:resolve(type)
				if not result then return nil, except end
				objkey = self:getkey(value, result)
			end
			value = objkey
		end
	end
	return self:removeentry(value)
end

return TypedServants
