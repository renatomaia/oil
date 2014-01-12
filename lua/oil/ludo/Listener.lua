-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Server-side LuDO Protocol
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local select = _G.select
local tonumber = _G.tonumber
local tostring = _G.tostring

local array = require "table"
local unpack = array.unpack

local table = require "loop.table"
local memoize = table.memoize

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"                                       --[[VERBOSE]] local verbose = require "oil.verbose"

local Listener = require "oil.protocol.Listener"
local LuDOChannel = require "oil.ludo.Channel"



local ServerRequest = class({}, Listener.Request)

function ServerRequest:setreply(...)                                            --[[VERBOSE]] verbose:listen("set reply for request ",self.request_id," to ",self.objectkey,":",self.operation)
	local channel = self.channel
	channel:trylock("write")
	local success, except = channel:sendvalues(self.request_id, ...)
	channel:freelock("write")
	if not success and except.error ~= "terminated" then
		return false, except
	end
	channel.pending = channel.pending-1
	if channel.closing and channel.pending == 0 then
		LuDOChannel.close(channel)
	end
	return true
end



local ServerChannel = class({ pending = 0 }, LuDOChannel)

local function makerequest(channel, success, requestid, objkey, operation, ...)
	if not success then return nil, requestid end
	channel.pending = channel.pending+1
	return channel.context.Request{
		channel = channel,
		request_id = requestid,
		objectkey = objkey,
		operation = operation,
		n = select("#", ...),
		...,
	}
end
function ServerChannel:getrequest(timeout)
	local result, except
	if self:trylock("read", timeout) then
		result, except = makerequest(self, self:receivevalues(timeout))
		self:freelock("read")
	else
		result, except = nil, Exception{ "terminated", error = "terminated" }
	end
	return result, except
end

function ServerChannel:close()
	if self.pending > 0 then
		self.closing = true
	else
		LuDOChannel.close(self)
	end
	return true
end



return class({
	Channel = ServerChannel,
	Request = ServerRequest,
}, Listener)
