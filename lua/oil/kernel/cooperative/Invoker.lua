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
-- 
-- mutex:Facet
-- 	locksend(channel:object)
-- 	freesend(channel:object)
-- 	lockreceive(channel:object, request:object)
-- 	notifyreceived(channel:object, request:object)
-- 	freereceive(channel:object)
-- 
-- tasks:Receptacle
-- 	current:thread
-- 	suspend()
-- 	resume(thread:thread)
-- 	register(thread:thread)
--------------------------------------------------------------------------------

local ipairs   = ipairs
local next     = next
local newproxy = newproxy
local rawset   = rawset
local unpack   = unpack

local ObjectCache = require "loop.collection.ObjectCache"
local OrderedSet  = require "loop.collection.OrderedSet"

local oo     = require "oil.oo"
local assert = require "oil.assert"                                             --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.kernel.cooperative.Invoker", oo.class)

context = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local ChannelKey = newproxy()
local InvokerKey = newproxy()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

Request = oo.class()

function Request:ready()                                                        --[[VERBOSE]] verbose:invoke(true, "check reply")
	self[InvokerKey]:lockedreceive(self[ChannelKey], self, true)                  --[[VERBOSE]] verbose:invoke(false)
	return self.success ~= nil
end

function Request:results()                                                      --[[VERBOSE]] verbose:invoke(true, "get reply")
		self[InvokerKey]:lockedreceive(self[ChannelKey], self)                      --[[VERBOSE]] verbose:invoke(false)
	return self.success, unpack(self, 1, self.resultcount)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function invoke(self, reference, operation, ...)                                --[[VERBOSE]] verbose:invoke(true, "invoke remote operation")
	local context = self.context
	local result, except = context.requester:getchannel(reference)
	if result then
		local channel = result
		context.mutex:locksend(channel)
		result, except = context.requester:newrequest(channel, reference, operation, ...)
		context.mutex:freesend(channel)
		if result then
			result[InvokerKey] = self
			result[ChannelKey] = channel
			result = Request(result)
		end
	end                                                                           --[[VERBOSE]] verbose:invoke(false)
	return result, except
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function lockedreceive(self, channel, request, probe)
	if request.success == nil then
		local context = self.context
		if context.mutex:lockreceive(channel, request) then
			local result, except, failed
			while request.success == nil and (not probe or result == nil) do
				result, except, failed = context.requester:getreply(channel, probe)
				if result then
					context.mutex:notifyreceived(channel, result)
				elseif result == nil then
					for _, request in ipairs(failed) do
						request.success = false
						request.resultcount = 1
						request[1] = except
						context.mutex:notifyreceived(channel, request)
					end
				end
			end
			context.mutex:freereceive(channel)
		end
	end
end
