-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Client-side LuDO Protocol
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local select  = _G.select
local tonumber = _G.tonumber
local unpack = _G.unpack

local tabop = require "loop.table"
local memoize = tabop.memoize

local oo = require "oil.oo"
local class = oo.class

local Request = require "oil.protocol.Request"


local ClientRequest = class({}, Request)

function ClientRequest:getreply(timeout)
	local requester = self.requester
	while self.success == nil do
		local channel = self.channel
		if channel:trylock("read", timeout, self) then
			repeat
				local ok, except = requester:readchannel(channel, timeout)
				if not ok then return nil, except end
			until self.channel ~= channel
			channel:freelock("read")
		end
	end
	return self.success, self:getvalues()
end


local WeakTable = class{ __mode = "kv" }


local Requester = class{ Request = ClientRequest }

function Requester:__init()
	self.sock2channel = memoize(function(socket)
		return self.Channel{
			socket = socket,
			codec = self.codec,
		}
	end, "k")
end

function Requester:getchannel(reference)
	local channels = self.channels
	local result, except = channels:retrieve(reference)
	if result then
		result = self.sock2channel[result]
		if result:unlocked("read") then -- channel might be broken
			local ok
			repeat ok, except = self:readchannel(result, 0) until not ok
			if except.error == "timeout" then
				except = nil
			else
				result:close()
				result, except = channels:retrieve(reference)
				if result then result = sock2channel[result] end
			end
		end
	end
	return result, except
end

function Requester:newrequest(reference, ...)
	local channel, except = self:getchannel(reference)
	return self:makerequest(channel, except, reference, ...)
end

return Requester
