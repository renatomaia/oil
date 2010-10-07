-- Project: OiL - ORB in Lua
-- Release: 0.5
-- Title  : Client-side CORBA GIOP Protocol
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local assert = _G.assert
local ipairs = _G.ipairs
local pairs = _G.pairs
local pcall = _G.pcall
local select = _G.select
local setmetatable = _G.setmetatable
local type = _G.type
local unpack = _G.unpack

local tabop = require "loop.table"
local memoize = tabop.memoize

local oo = require "oil.oo"
local class = oo.class
local rawnew = oo.rawnew

local giop = require "oil.corba.giop"
local IOR = giop.IOR
local RequestID = giop.RequestID
local ReplyID = giop.ReplyID
local LocateRequestID = giop.LocateRequestID
local LocateReplyID = giop.LocateReplyID
local CloseConnectionID = giop.CloseConnectionID
local MessageErrorID = giop.MessageErrorID
local MessageType = giop.MessageType
local SystemExceptionIDL = giop.SystemExceptionIDL
local _non_existent = giop.ObjectOperations._non_existent

local Exception = require "oil.corba.giop.Exception"
local Channel = require "oil.corba.giop.Channel"                                --[[VERBOSE]] local verbose = require "oil.verbose"

module(...); local _ENV = _M

class(_M)

--------------------------------------------------------------------------------

local WeakKeys = oo.class{__mode = "k"}
local WeakTable = oo.class{__mode = "kv"}

local Empty = {}

--------------------------------------------------------------------------------
-- request id management for channels

function register(channel, request)
	local id = #channel + 1
	request.request_id = id
	request.channel = channel
	channel[id] = request
	return id
end

function unregister(channel, id)
	local request = channel[id]
	if request then
		request.request_id = nil
		request.channel = nil
		channel[id] = nil
		return request
	end
end

--------------------------------------------------------------------------------

function __init(self, ...)
	self.objkeyof = WeakKeys()
	self.channelof = WeakTable()
	self.sock2channel = memoize(function(socket)
		return Channel{
			socket = socket,
			codec = self.codec,
		}
	end, "k")
	self.Request = class{
		ready = function(request, timeout)
			if request.success ~= nil then return true end
			self:getreply(request, timeout or 0)
			return request.success ~= nil
		end,
		results = function(request, timeout)
			local success = request.success
			if success == nil then
				self:getreply(request, timeout)
				success = request.success
				if success == nil then
					return nil, Exception{
						error = "timeout",
						message = "timeout",
					}
				end
			end
			return success, unpack(request, 1, request.n)
		end,
	}
end

--------------------------------------------------------------------------------

function newchannel(self, reference)
	local except
	for _, encoded in ipairs(reference.profiles) do                               --[[VERBOSE]] verbose:invoke("[IOR profile with tag ",encoded.tag,"]")
		local channels = self.channels
		local referrer = self.referrer
		local result
		result, except = referrer:decodeprofile(encoded)
		if result then
			local profile, objectkey = result, except
			result, except = channels:retrieve(profile)
			if result then
				local sock2channel = self.sock2channel
				result = sock2channel[result]
				local ok
				if result:unlocked("read") then -- channel might be broken
					repeat ok, except = self:readchannel(result, 0) until not ok
					if except.error == "timeout" then
						ok = true
					else
						result:close()
						result, except = channels:retrieve(profile)
						if result then
							ok = true
							result = sock2channel[result]
						end
					end
				else
					ok = true -- channel is being read, so it should be working fine
				end
				if ok then                                                            --[[VERBOSE]] verbose:invoke("got channel from profile with tag ",profile.tag)
					reference._profile = profile
					return result, objectkey
				end
			end
		end
		except.completed = "COMPLETED_NO"
		except.profile = encoded
	end
	if except == nil then                                                         --[[VERBOSE]] verbose:invoke("[no supported profile found]")
		except = Exception{
			error = "badversion",
			message = "no supported IOR profile found",
			minor = 1,
			completed = "COMPLETED_NO",
			profiles = reference.profiles,
		}
	end
	return nil, except
end

function getchannel(self, reference)                                                --[[VERBOSE]] verbose:invoke(true, "get communication channel")
	local channelof, objkeyof = self.channelof, self.objkeyof
	local channel, objectkey = channelof[reference], objkeyof[reference]
	if channel == nil then
		channel, objectkey = self:newchannel(reference)
		if channel then
			channelof[reference] = channel
			objkeyof[reference] = objectkey
		end
	end                                                                           --[[VERBOSE]] verbose:invoke(false)
	return channel, objectkey
end

--------------------------------------------------------------------------------

function makerequest(self, channel, reference, operation, ...)
	local request = self.Request{
		requester            = self,
		reference            = reference,
		request_id           = 0,
		response_expected    = not operation.oneway,
		service_context      = Empty,
		requesting_principal = Empty,
		object_key           = self.objkeyof[reference],
		operation            = operation.name,
		inputs               = operation.inputs,
		outputs              = operation.outputs,
		exceptions           = operation.exceptions,
		n                    = select("#", ...),
		...,
	}
	if channel and request.response_expected then
		register(channel, request) -- defines the 'request_id'
	end
	return request
end

function endrequest(self, request, success, result)
	if success then
		request.success = true
		request.n = result
	else
		request.success = false
		request.n = 1
		request[1] = result
	end
	local replier = self.OperationReplier[request.operation]
	if replier then replier(self, request) end
end

function sendrequest(self, reference, operation, ...)
	local channel, except = self:getchannel(reference)
	local request = self:makerequest(channel, reference, operation, ...)          --[[VERBOSE]] verbose:invoke(true, "request ",request.request_id," for operation '",operation.name,"'")
	if channel then
		local success
		success, except = channel:send(RequestID, request,
		                               request.inputs, request)
		if success then
			if not request.response_expected then
				self:endrequest(request, true, 0)
			end                                                                       --[[VERBOSE]] verbose:invoke(false, "request sent successfully")
			return request
		end                                                                         --[[VERBOSE]] verbose:invoke("unable to send the request")
		unregister(channel, request.request_id)                                     --[[VERBOSE]] else verbose:invoke("unable to contact the servant")
	end
	self:endrequest(request, false, except)                                       --[[VERBOSE]] verbose:invoke(false, "request failed")
	return request
end

function newrequest(self, reference, operation, ...)
	local requester = self.OperationRequester[operation] or self.sendrequest
	return requester(self, reference, operation, ...)
end

--------------------------------------------------------------------------------

function reissue(self, request, channel, except)
	if channel then                                                               --[[VERBOSE]] verbose:invoke(true, "reissue request for operation '",request.operation,"'")
		register(channel, request)
		local success
		success, except = channel:send(RequestID, request,
		                               request.inputs, request)                     --[[VERBOSE]] verbose:invoke(false, "reissue",success and "d successfully" or " failed")
		if success then return true end
		unregister(channel, request.request_id)
	end
	self:endrequest(request, false, except)
end

local SystemExceptionReason = {
	["IDL:omg.org/CORBA/COMM_FAILURE:1.0"    ] = "badchannel",
	["IDL:omg.org/CORBA/MARSHAL:1.0"         ] = "badstream",
	["IDL:omg.org/CORBA/NO_IMPLEMENT:1.0"    ] = "badobjimpl",
	["IDL:omg.org/CORBA/BAD_OPERATION:1.0"   ] = "badobjop",
	["IDL:omg.org/CORBA/OBJECT_NOT_EXIST:1.0"] = "badobjkey",
}

function doreply(self, replied, header, decoder)
	local status = header.reply_status
	if status == "NO_EXCEPTION" then                                              --[[VERBOSE]] verbose:invoke("got successful reply for request ",header.request_id)
		local outputs = replied.outputs
		local count = #outputs
		local ok, result = true
		for i = 1, count do
			ok, result = pcall(decoder.get, decoder, outputs[i])
			if not ok then
				assert(type(result) == "table", result)
				self:endrequest(replied, false, result)
				break
			end
			replied[i] = result
		end
		if ok then
			self:endrequest(replied, true, count)
		end
	else -- status ~= "NO_EXCEPTION"
		local except
		if status == "LOCATION_FORWARD" then                                        --[[VERBOSE]] verbose:invoke("forwarding request ",header.request_id," through other channel")
			local channel
			channel, except = self:newchannel(decoder:struct(IOR))
			if channel then
				replied.object_key = except
				return self:reissue(replied, channel)
			end
		elseif status == "USER_EXCEPTION" then                                        --[[VERBOSE]] verbose:invoke("got reply with exception for ",header.request_id)
			local repId = decoder:string()
			except = replied.exceptions[repId]
			if except then
				except = decoder:except(except)
				except[1] = repId
				except = Exception(except)
			else
				except = Exception{
					error = "badexception",
					minor_code_value = 1,
					message = "illegal user exception (got $exception)",
					exception = repId,
				}
			end
		elseif status == "SYSTEM_EXCEPTION" then                                  --[[VERBOSE]] verbose:invoke("got reply with system exception for ",header.request_id)
			-- TODO:[maia] set its type to the proper SystemExcep.
			except = decoder:struct(SystemExceptionIDL)
			except[1] = except.exception_id
			except.reason = SystemExceptionReason[ except[1] ]
			except.message = "got remote exception $exception_id"
			except.error = "remote exception"
			except = Exception(except)
		else -- status == ???
			except = Exception{
				error = "badmessage",
				message = "unsupported GIOP reply status (got $replystatus)",
				replystatus = status,
			}
		end -- of if status == "LOCATION_FORWARD"
		self:endrequest(replied, false, except)
	end -- of if status == "NO_EXCEPTION"
end

function readchannel(self, channel, timeout)
	local msgid, header, decoder = channel:receive(timeout)
	if msgid == ReplyID then
		local replied = unregister(channel, header.request_id)
		if replied then
			self:doreply(replied, header, decoder)
			channel:signal("read", replied)
			return true
		end                                                                         --[[VERBOSE]] verbose:invoke("got reply for invalid request ID: ",header.request_id)
		msgid, header = channel:send(MessageErrorID)
		if msgid then return true end
	elseif msgid == CloseConnectionID then                                        --[[VERBOSE]] verbose:invoke("got remote request to close channel")
		local channelof = self.channelof
		for reference, achannel in pairs(channelof) do
			if channel == achannel then channelof[reference] = nil end
		end
		channel:close()
		for id, pending in pairs(channel) do
			if type(id) == "number" then                                              --[[VERBOSE]] verbose:invoke(true, "reissuing pending request ",pending.request_id)
				unregister(channel, id)
				self:reissue(pending, self:getchannel(pending.reference))               --[[VERBOSE]] verbose:invoke(false)
				channel:signal("read", replied)
			end
		end
		return true
	elseif msgid == MessageErrorID then
		msgid, header = nil, Exception{
			error = "badmessage",
			message = "error in remote ORB message processing",
		}
	elseif MessageType[msgid]~=nil or (msgid==nil and header.reason=="badversion") then
		msgid, header = channel:send(MessageErrorID)
		if msgid then return true end
	end
	if header.error ~= "timeout" then
		for id, pending in pairs(channel) do
			if type(id) == "number" then
				unregister(channel, id)
				self:endrequest(pending, false, header)
			end
		end
	end
	return nil, header
end

function getreply(self, request, timeout)
	repeat
		local channel = request.channel
		if channel:trylock("read", timeout, request) then
			repeat
				local ok, except = self:readchannel(channel, timeout)
				if not ok and except.error == "timeout" then return end
			until request.channel ~= channel
			channel:freelock("read")
		end
	until request.success ~= nil
end

--------------------------------------------------------------------------------

OperationRequester = {}
OperationReplier = {}

local ReplyTrue  = {
	ready = function() return true end,
	results = function() return true, true end,
}
local ReplyFalse = {
	ready = ReplyTrue.ready,
	results = function() return true, false end,
}

function OperationRequester:_is_equivalent(reference, operation, other)
	return self.referrer:isequivalent(reference, other.__reference)
	   and ReplyTrue
	    or ReplyFalse
end

function OperationReplier:_non_existent(request)
	local except = request[1]
	if not request.success
	and (
		except.exception_id == "IDL:omg.org/CORBA/OBJECT_NOT_EXIST:1.0" or
		(except.error == "badconnect" and except.errmsg == "connection refused")
	)
	then
		request.success = true
		request.n = 1
		request[1] = true
	end
end
