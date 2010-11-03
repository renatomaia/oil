-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : 
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local tonumber = _G.tonumber

local oo = require "oil.oo"
local class = oo.class

local Channel = require "oil.protocol.Channel"


local LuDOChannel = class({}, Channel)

local MessageFmt = "%d\n%s"
function LuDOChannel:sendvalues(...)
	local encoder = self.codec:encoder()
	encoder:put(...)
	local data = encoder:__tostring()
	return self:send(MessageFmt:format(#data, data))
end

function LuDOChannel:receivevalues(timeout)
	local size = self.pendingsize
	if size then
		self.pendingsize = nil
	else
		local bytes, except = self:receive(nil, timeout)
		if bytes then
			size = tonumber(bytes)
			if size == nil then
				return nil, Exception{
					error = "badmessage",
					message = "invalid LuDO message size (got $size)",
					size = bytes,
				}
			end
		end
	end
	local bytes, except = self:receive(size, timeout)
	if bytes ~= nil then
		return true, self.codec:decoder(bytes):get()
	elseif except.error == "timeout" then
		self.pendingsize = size
	end
	return nil, except
end

return LuDOChannel