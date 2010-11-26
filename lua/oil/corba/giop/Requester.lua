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

local Requester = require "oil.protocol.Requester"

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
local GIOPChannel = require "oil.corba.giop.Channel"                                --[[VERBOSE]] local verbose = require "oil.verbose"


local WeakKeys = oo.class{__mode = "k"}
local WeakTable = oo.class{__mode = "kv"}

local Empty = {}

local function register(channel, request)
	local id = #channel + 1
	request.request_id = id
	request.channel = channel
	channel[id] = request                                                         --[[VERBOSE]] verbose:invoke("registering request with id ",id)
	return id
end

local function unregister(channel, id)                                          --[[VERBOSE]] verbose:invoke("unregistering request with id ",id)
	local request = channel[id]
	if request then
		request.request_id = nil
		request.channel = nil
		channel[id] = nil
		return request
	end
end



local OperationRequester = {}
local OperationReplier = {}

local ReplyTrue  = { getreply = function() return true, true end }
local ReplyFalse = { getreply = function() return true, false end }
function OperationRequester:_is_equivalent(reference, operation, other)
	return self.referrer:isequivalent(reference, other.__reference)
	   and ReplyTrue
	    or ReplyFalse
end

function OperationReplier:_non_existent(request)
	local except = request:getvalues()
	if not request.success and (
		except.error == "badconnect" or
		except.exception_id == "IDL:omg.org/CORBA/OBJECT_NOT_EXIST:1.0"
	) then
		request:setreply(true, true)
	end
end



local GIOPRequester = class({
	register = register,
	unregiter = unregister,
	OperationRequester = OperationRequester,
	OperationReplier = OperationReplier,
	Channel = GIOPChannel,
}, Requester)

function GIOPRequester:getchannel(reference)
	local result, except = reference.ior_profile_data
	if result ~= nil then
		result, except = Requester.getchannel(self, result)
		if result then                                                              --[[VERBOSE]] verbose:invoke("reusing channel from previous IOR profile with tag ",reference.ior_profile_tag)
			return result
		end
	end
	for _, encoded in ipairs(reference.profiles) do                               --[[VERBOSE]] verbose:invoke("[IOR profile with tag ",encoded.tag,"]")
		local channels = self.channels
		local referrer = self.referrer
		result, except = referrer:decodeprofile(encoded)
		if result then
			local profile = result
			reference.object_key = except
			reference.ior_profile_tag = encoded.tag
			reference.ior_profile_data = profile
			result, except = Requester.getchannel(self, profile)
			if result then                                                            --[[VERBOSE]] verbose:invoke("got channel from profile with tag ",encoded.tag)
				return result
			end
		end
		except.completed = "COMPLETED_NO"
		except.profile = encoded
	end
	if except == nil then                                                         --[[VERBOSE]] verbose:invoke("[no supported profile found]")
		except = {
			error = "badversion",
			message = "no supported IOR profile found",
			minor = 1,
			completed = "COMPLETED_NO",
			profiles = reference.profiles,
		}
	end
	return nil, Exception(except)
end

-- this is a separated method to provide pointcut for interception
function GIOPRequester:buildrequest(channel, except, reference, operation, ...)
	local request = self.Request{
		requester            = self,
		reference            = reference,
		request_id           = 0,
		response_expected    = not operation.oneway,
		service_context      = Empty,
		requesting_principal = Empty,
		object_key           = reference.object_key,
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

-- this is a separated method to provide pointcut for interception
function GIOPRequester:processrequest(channel, except, request)                 --[[VERBOSE]] verbose:invoke(true, "processing new request")
	if channel then
		local success
		success, except = channel:sendmsg(RequestID, request,
		                                  request.inputs, request)
		if success then
			if not request.response_expected then
				self:endrequest(request, true, 0)
			end                                                                       --[[VERBOSE]] verbose:invoke(false, "request sent successfully")
			return request
		end                                                                         --[[VERBOSE]] verbose:invoke("unable to send the request")
		unregister(channel, request.request_id)                                     --[[VERBOSE]] else verbose:invoke("unable to contact the servant")
	end
	except.completed = "COMPLETED_NO"
	self:endrequest(request, false, except)                                       --[[VERBOSE]] verbose:invoke(false, "request failed")
end

-- this is a separated method to provide pointcut for interception
function GIOPRequester:endrequest(request, success, result)
	if success ~= nil then
		if success then
			request.success = true
			request.n = result
		else
			request:setreply(false, result)
		end
	end
	local replier = self.OperationReplier[request.operation]
	if replier then replier(self, request) end
end

function GIOPRequester:makerequest(channel, except, ...)
	local request = self:buildrequest(channel, except, ...)
	self:processrequest(channel, except, request)
	return request
end

function GIOPRequester:newrequest(reference, operation, ...)
	local requester = self.OperationRequester[operation.name]
	               or Requester.newrequest
	return requester(self, reference, operation, ...)
end



local function reissue(self, request, channel, except)
	if channel then                                                               --[[VERBOSE]] verbose:invoke(true, "reissue request for operation '",request.operation,"'")
		register(channel, request)
		local success
		success, except = channel:sendmsg(RequestID, request,
		                                  request.inputs, request)                  --[[VERBOSE]] verbose:invoke(false, "reissue",success and "d successfully" or " failed")
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
-- this is a separated method to provide pointcut for interception
function GIOPRequester:doreply(replied, header, decoder)
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
			local reference = decoder:struct(IOR)
			channel, except = self:getchannel(reference)
			if channel then
				replied.object_key = reference.object_key
				return reissue(self, replied, channel)
			end
		elseif status == "USER_EXCEPTION" then                                      --[[VERBOSE]] verbose:invoke("got reply with exception for ",header.request_id)
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
		elseif status == "SYSTEM_EXCEPTION" then                                    --[[VERBOSE]] verbose:invoke("got reply with system exception for ",header.request_id)
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

function GIOPRequester:readchannel(channel, timeout)
	local msgid, header, decoder = channel:receivemsg(timeout)
	if msgid == ReplyID then
		local replied = unregister(channel, header.request_id)
		if replied then
			self:doreply(replied, header, decoder)
			channel:signal("read", replied)
			return true
		end                                                                         --[[VERBOSE]] verbose:invoke("got reply for invalid request ID: ",header.request_id)
		msgid, header = channel:sendmsg(MessageErrorID)
		if msgid then return true end
	elseif msgid == CloseConnectionID then                                        --[[VERBOSE]] verbose:invoke("got remote request to close channel")
		channel:close()
		for id, pending in pairs(channel) do
			if type(id) == "number" then                                              --[[VERBOSE]] verbose:invoke(true, "reissuing pending request ",pending.request_id)
				unregister(channel, id)
				reissue(self, pending, self:getchannel(pending.reference))              --[[VERBOSE]] verbose:invoke(false)
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
		msgid, header = channel:sendmsg(MessageErrorID)
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
	return nil, Exception(header)
end

return GIOPRequester
