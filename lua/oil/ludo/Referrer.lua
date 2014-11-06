-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Client-side LuDO Protocol Support
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local type = _G.type

local oo = require "oil.oo"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"
local class = oo.class


local Reference = class()

function Reference:islocal(access)
	local addresses = access.addresses
	local index = addresses[self.host]
	if index ~= nil and addresses[index].port == access.port then
		return self.object
	end
end

function Reference:__tostring()
	local object, host, port = self.object, self.host, self.port
	if type(object) == "string"
	and type(host) == "string"
	and type(port) == "number" then
		local encoder = self.referrer.codec:encoder()
		encoder:put(object, host, port)
		return encoder:__tostring()
	end
	return "bad LuDO reference"
end



local Referrer = class{ Reference = Reference }

function Referrer:newreference(entry)
	local result, except = self.listener:getaddress()
	if result then
		return Reference{
			referrer = self,
			host = result.host,
			port = result.port,
			object = entry.__objkey,
		}
	end
	return result, except
end

function Referrer:decodestring(reference)
	local decoder = self.codec:decoder(reference)
	local object, host, port = decoder:get()
	if type(object) == "string"
	and type(host) == "string"
	and type(port) == "number" then
		return Reference{
			referrer = self,
			host = host,
			port = port,
			object = object,
		}
	end
	return nil, "invalid LuDO reference"
end

return Referrer
