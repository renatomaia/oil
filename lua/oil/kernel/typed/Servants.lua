-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Server-Side Broker
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local oo = require "oil.oo"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"
local class = oo.class
local getclass = oo.getclass

local Servants = require "oil.kernel.base.Servants"

module(...); local _ENV = _M

class(_ENV, Servants)

function _ENV:getkey(servant, type)
	return getfield(servant, "__objkey")
	    or self.prefix..hashof(servant)..hashof(type)
end

function _ENV:makeentry(entry)
	local servant = entry.__servant
	if entry.__type == nil then
		entry.__type = getfield(servant, "__type")
	end
	local type, except = self.types:resolve(entry.__type)
	if not type then return nil, except end
	entry.__type = type
	if entry.__objkey == nil then
		entry.__objkey = self:getkey(servant, type)
	end
	return Servants.makeentry(self, entry)
end

function _ENV:unregister(value, type)
	if type(value) ~= "string" then
		if getclass(value) == Registered then
			value = value.__objkey
		else
			local result, except = self.types:resolve(type)
			if not result then return nil, except end
			value = self:getkey(value, result)
		end
	end
	return self:removeentry(value)
end
