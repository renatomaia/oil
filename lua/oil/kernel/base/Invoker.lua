--------------------------------------------------------------------------------
------------------------------  #####      ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------ ##   ## ##  ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------  #####  ### ###### ------------------------------
--------------------------------                --------------------------------
----------------------- An Object Request Broker in Lua ------------------------
--------------------------------------------------------------------------------
-- Project: OiL - ORB in Lua: An Object Request Broker in Lua                 --
-- Release: 0.4                                                               --
-- Title  : Remote Object Invoker                                             --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- invoker:Facet
-- 	[results:object], [except:table] invoke(reference, operation, args...)
-- 
-- requester:Receptacle
-- 	channel:object getchannel(reference)
-- 	[request:table], [except:table], [requests:table] request(channel:object, reference, operation, args...)
-- 	[request:table], [except:table], [requests:table] getreply(channel:object, [probe:boolean])
--------------------------------------------------------------------------------

local pairs    = pairs
local newproxy = newproxy
local rawset   = rawset
local type     = type
local unpack   = unpack

local oo     = require "oil.oo"
local assert = require "oil.assert"                                             --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.kernel.base.Invoker", oo.class)

context = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local ChannelKey = newproxy()
local RequesterKey = newproxy()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function setfailed(requests, except)
	for requestid, request in pairs(requests) do
		if type(requestid) == "number" then
			request.success = false
			request.resultcount = 1
			request[1] = except
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

Request = oo.class()

function Request:ready()                                                        --[[VERBOSE]] verbose:invoke(true, "check reply")
	local requester = self[RequesterKey]
	local channel = self[ChannelKey]
	local request, except, failed = requester:getreply(channel, true)
	if request == nil then setfailed(failed, except) end                          --[[VERBOSE]] verbose:invoke(false)
	return self.success ~= nil
end

function Request:results()                                                      --[[VERBOSE]] verbose:invoke(true, "get reply")
	local requester = self[RequesterKey]
	local channel = self[ChannelKey]
	while self.success == nil do
		local request, except, failed = requester:getreply(channel)
		if request == nil then setfailed(failed, except) end
	end                                                                           --[[VERBOSE]] verbose:invoke(false)
	return self.success, unpack(self, 1, self.resultcount)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function invoke(self, reference, operation, ...)                                --[[VERBOSE]] verbose:invoke(true, "invoke remote operation")
	local requester = self.context.requester
	local result, except = requester:getchannel(reference)
	if result then
		local channel = result
		result, except = requester:newrequest(channel, reference, operation, ...)
		if result then
			result[RequesterKey] = requester
			result[ChannelKey] = channel
			result = Request(result)
		end
	end                                                                           --[[VERBOSE]] verbose:invoke(false)
	return result, except
end
