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

local Requester = require "oil.protocol.Requester"
local LuDOChannel = require "oil.ludo.Channel"


local LuDORequester = class({ Channel = LuDOChannel }, Requester)

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

function LuDORequester:getreply(request, timeout)
	return request.channel:processmessage(timeout)
end

return LuDORequester
