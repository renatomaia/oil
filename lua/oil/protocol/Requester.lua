-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Client-side LuDO Protocol
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local select  = _G.select
local tonumber = _G.tonumber

local array = require "table"
local unpack = array.unpack

local table = require "loop.table"
local memoize = table.memoize

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"
local Request = require "oil.protocol.Request"


local ClientRequest = class({}, Request)

function ClientRequest:getreply(timeout)                                        --[[VERBOSE]] verbose:invoke(true, "get reply for request ",self.request_id," to ",self.reference.object_key,":",self.operation)
	local requester = self.requester
	while self.success == nil do                                                  --[[VERBOSE]] verbose:invoke("reply results are not available yet")
		local ok, except = requester:getreply(self, timeout)
		if not ok then                                                              --[[VERBOSE]] verbose:invoke(false, "unable to get reply due to error")
			return false, except
		end
	end                                                                           --[[VERBOSE]] verbose:invoke(false, "got reply with ",self.success and "results" or "exception")
	return self.success, self:getvalues()
end


local WeakTable = class{ __mode = "kv" }


local Requester = class{ Request = ClientRequest }

function Requester:__init()
	self.sock2channel = memoize(function(socket)
		return self.Channel{
			socket = socket,
			context = self,
			requester = self,
		}
	end)
end

function Requester:getchannel(reference)
	local channels = self.channels
	local result, except = channels:retrieve(reference)
	if result then
		local sock2channel = self.sock2channel
		result = sock2channel[result]
		if result:unlocked("read") then --[[channel might be broken]]               --[[VERBOSE]] verbose:invoke(true, "check if channel is valid")
			local ok
			repeat ok, except = result:processmessage(0) until not ok
			if except.error == "timeout" then                                         --[[VERBOSE]] verbose:invoke(false, "channel seems OK")
				except = nil
			else                                                                      --[[VERBOSE]] verbose:invoke(false, "channel seems to be broken")
				result:close()                                                          --[[VERBOSE]] verbose:invoke("get a new channel")
				result, except = channels:retrieve(reference)
				if result then result = sock2channel[result] end
			end
		end
	end                                                                           --[[VERBOSE]] if not result then verbose:invoke("unable to get channel") end
	return result, except
end

return Requester
