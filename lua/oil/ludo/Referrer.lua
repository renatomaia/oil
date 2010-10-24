-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Client-side LuDO Protocol Support
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local type = _G.type

local oo = require "oil.oo"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"
local class = oo.class


local Referrer = class()

function Referrer:newreference(entry)
	local result, except = self.listener:getaddress()
	if result then
		result, except = {
			host = result.host,
			port = result.port,
			object = entry.__objkey,
		}
	end
	return result, except
end

function Referrer:islocal(reference, access)
	local result, except = self.listener:getaddress()
	if result then
		if result.addresses[reference.host] and reference.port == result.port then
			result, except = reference.object, nil
		end
	end
	return result, except
end

function Referrer:encode(reference)
	local object, host, port = reference.object, reference.host, reference.port
	if type(object) == "string"
	and type(host) == "string"
	and type(port) == "number" then
		local encoder = self.codec:encoder()
		encoder:put(object, host, port)
		return encoder:__tostring()
	end
	return nil, "bad LuDO reference"
end

function Referrer:decode(reference)
	local decoder = self.codec:decoder(reference)
	local object, host, port = decoder:get()
	if type(object) == "string"
	and type(host) == "string"
	and type(port) == "number" then
		return {
			host = host,
			port = port,
			object = object,
		}
	end
	return nil, "invalid LuDO reference"
end

return Referrer
