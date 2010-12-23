-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Server-side LuDO Protocol
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local select = _G.select
local tonumber = _G.tonumber
local unpack = _G.unpack
local stderr = _G.io and _G.io.stderr -- only if available

local tabops = require "loop.table"
local memoize = tabops.memoize

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
	if not success and except.error ~= "terminated" and stderr then
		stderr:write(tostring(except), "\n")
	end
end



local ServerChannel = class({}, LuDOChannel)

local function makerequest(channel, success, requestid, objkey, operation, ...)
	if not success then return nil, requestid end
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
		result, except = nil, Exception{
			error = "terminated",
			message = "terminated",
		}
	end
	return result, except
end



return class({
	Channel = ServerChannel,
	Request = ServerRequest,
}, Listener)
