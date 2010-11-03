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
	self.channelof = WeakTable()
	self.sock2channel = memoize(function(socket)
		return self.Channel{
			socket = socket,
			codec = self.codec,
		}
	end, "k")
end

function Requester:getchannel(reference)
	local channelof = self.channelof
	local channel, except = channelof[reference]
	if channel == nil then
		channel, except = self:newchannel(reference)
		if channel then
			channelof[reference] = channel
		end
	end
	return channel, except
end

function Requester:newrequest(reference, ...)
	local channel, except = self:getchannel(reference)
	return self:makerequest(channel, except, reference, ...)
end

return Requester
