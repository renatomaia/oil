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

function Requester:setup()                                                      --[[VERBOSE]] verbose:invoke("set up requester")
	self.enabled = true
	return true
end

function Requester:getchannel(reference, configs)
	local result, except
	if self.enabled then
		local channels = self.channels
		result, except = channels:retrieve(reference, configs)
		if result and result:unlocked("read") then --[[channel might be broken]]      --[[VERBOSE]] verbose:invoke(true, "check if channel is valid")
			local ok
			repeat ok, except = result:processmessage(0) until not ok
			if except.error == "timeout" then                                           --[[VERBOSE]] verbose:invoke(false, "channel seems OK")
				except = nil
			elseif except.error == "closed" then                                        --[[VERBOSE]] verbose:invoke(false, "channel seems to be broken:", except)
				channels:unregister(result)                                               --[[VERBOSE]] verbose:invoke(true, "get a new channel")
				result, except = channels:retrieve(reference, configs)                    --[[VERBOSE]] verbose:invoke(false)
			end
		end                                                                           --[[VERBOSE]] if not result then verbose:invoke("unable to get channel") end
	else
		result, except = nil, Exception{ "setup missing", error = "badsetup" }
	end
	return result, except
end

function Requester:shutdown()                                                   --[[VERBOSE]] verbose:invoke(true, "shutting down requester")
	local excepts = {}
	for _, channel in self.channels:iterate() do                                  --[[VERBOSE]] verbose:invoke("closing channel")
		local closed, except = channel:close("outgoing")
		if not closed then                                                          --[[VERBOSE]] verbose:invoke("shutdown failed while closing channel: ",except)
			excepts[#excepts+1] = except
		end
	end
	self.enabled = nil                                                            --[[VERBOSE]] verbose:invoke(false, "requester shutdown concluded")
	if #excepts > 0 then
		return nil, Exception{
			"unable to close all incoming connections",
			error = "badshutdown",
			excepts = excepts,
		}
	end
	return true
end

return Requester
