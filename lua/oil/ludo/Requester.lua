-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Client-side LuDO Protocol
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local select  = _G.select
local tonumber = _G.tonumber

local array = require "table"
local unpack = array.unpack

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"
local Requester = require "oil.protocol.Requester"

local LuDORequester = class({}, Requester)

function LuDORequester:newrequest(request)
	request = self.Request(request)
	local reference = request.reference                                           --[[VERBOSE]] verbose:invoke("new request to ",reference.object,":",request.operation)
	local channel, except = self:getchannel(reference)
	if channel then
		request.requester = self
		request.channel = channel
		local requestid = #channel+1                                                --[[VERBOSE]] request.request_id = requestid reference.object_key = reference.object
		channel:trylock("write")
		local success
		success, except = channel:sendvalues(requestid,
		                                     reference.object,
		                                     request.operation,
		                                     request:getvalues())
		channel:freelock("write")
		if success then
			channel[requestid] = request
			return request
		end
	end
	request:setreply(false, except)
	return request
end

function LuDORequester:cancelrequest(request)
	return true -- nothing to be done
end

function LuDORequester:getreply(request, timeout)
	local channel = request.channel
	local granted, expired = channel:trylock("read", timeout, request)
	if granted then
		local result, except
		repeat
			result, except = channel:processmessage(timeout)
		until result == nil or result == request
		channel:freelock("read")
		if result == nil then                                                     --[[VERBOSE]] verbose:invoke("failed to get reply")
			return nil, except
		end
	elseif expired then --[[timeout of 'trylock' expired]]                      --[[VERBOSE]] verbose:invoke("got no reply before timeout")
		return nil, Exception{ "timeout", error = "timeout" }
	end
	return true
end

return LuDORequester
