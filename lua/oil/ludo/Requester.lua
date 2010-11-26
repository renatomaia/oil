-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Client-side LuDO Protocol
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local select  = _G.select
local tonumber = _G.tonumber
local unpack = _G.unpack

local oo = require "oil.oo"
local class = oo.class

local Requester = require "oil.protocol.Requester"
local LuDOChannel = require "oil.ludo.Channel"


local LuDORequester = class({ Channel = LuDOChannel }, Requester)

function LuDORequester:makerequest(channel, except, reference, operation, ...)
	local request = self.Request{
		channel = channel,
		requester = self,
	}
	if channel then
		local requestid = #channel+1
		channel:trylock("write")
		local success
		success, except = channel:sendvalues(requestid,
		                                     reference.object,
		                                     operation, ...)
		channel:freelock("write")
		if success then
			channel[requestid] = request
			return request
		end
	end
	request:setreply(false, except)
	return request
end

local function doreply(channel, ok, requestid, success, ...)
	if not ok then return nil, requestid end
	local request, except = channel[requestid]
	if request then
		channel[requestid] = nil
		request.channel = nil
		request:setreply(success, ...)
		channel:signal("read", request)
	else
		except = Exception{
			error = "badmessage",
			message = "unexpected LuDO reply ID (got $requestid)",
			requestid = requestid,
		}
	end
	return request, except
end
function LuDORequester:readchannel(channel, timeout)
	return doreply(channel, channel:receivevalues(timeout))
end

return LuDORequester
