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
local copy = tabop.copy
local clear = tabop.clear
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

local OperationRequester = {}
local OperationReplier = {}

local ReplyTrue  = { getreply = function() return true, true end }
local ReplyFalse = { getreply = function() return true, false end }
function OperationRequester:_is_equivalent(request)
	local reference = request.reference
	local other = request[1]
	return reference:equivalentto(other.__reference)
	   and ReplyTrue
	    or ReplyFalse
end

local NonExistentErrors = {
	badconnect = true,
	badobjkey = true,
}
function OperationReplier:_non_existent(request)
	local except = request:getvalues()
	if not request.success and NonExistentErrors[except.error] then
		request:setreply(true, true)
	end
end



local function reissue(self, request, reference, addressing)                    --[[VERBOSE]] verbose:invoke(true, "reissue request to ",request.object_key,":",request.operation)
	local channel, except = self:getchannel(reference)
	if channel then
		request.reference = reference
		if addressing == nil or addressing == 0 then                                --[[VERBOSE]] verbose:invoke("using object key as addressing mode")
			request.object_key = reference.object_key
		else
			request.object_key = nil
			if adressing == 1 then                                                    --[[VERBOSE]] verbose:invoke("using IOR profile as addressing mode")
				request.target = {profile=reference.ior_profile}
			elseif addressing == 2 then                                               --[[VERBOSE]] verbose:invoke("using complete IOR as addressing mode")
				request.target = {ior=reference}
			end
		end
		local success
		success, except = channel:sendrequest(request)
		if success then                                                             --[[VERBOSE]] verbose:invoke(false, "reissued as request ",request.request_id," to ",request.object_key,":",request.operation)
			return channel
		end
		channel:unregister(request.id, "outgoing")
	end                                                                           --[[VERBOSE]] verbose:invoke(false, "unable to reissue request")
	self:endrequest(request, false, except)
end



local GIOPRequester = class({
	OperationRequester = OperationRequester,
	OperationReplier = OperationReplier,
	Channel = GIOPChannel,
}, Requester)

function GIOPRequester:addbidirchannel(channel, addresses)                      --[[VERBOSE]] verbose:invoke("add bidirectional channel to ",addresses[1].host or "<unknown host>",":",addresses[1].port or "<unknown port>")
	local socket = channel.socket
	self.sock2channel[socket] = channel
	local channels = self.channels
	for _, address in ipairs(addresses) do
		channels:register(socket, address)
	end
end

function GIOPRequester:getchannel(reference)
	local result, except = reference.ior_profile_data
	if result ~= nil then                                                         --[[VERBOSE]] verbose:invoke("reusing previous profile with tag ",reference.ior_profile_tag)
		local giop_minor = result.giop_minor
		result, except = Requester.getchannel(self, result)
		if result then
			result:upgradeto(giop_minor)
			return result
		end
	end
	for _, profile in reference:allprofiles() do                                  --[[VERBOSE]] verbose:invoke("using IOR profile with tag ",profile.tag)
		local decoded = profile.decoded
		if decoded then
			local channels = self.channels
			reference.object_key = decoded.object_key
			reference.ior_profile = profile
			reference.ior_profile_decoded = decoded
			result, except = Requester.getchannel(self, decoded)
			if result then
				result:upgradeto(decoded.giop_minor)
				return result
			end
		else
			except = profile.except
		end
		except.completed = "COMPLETED_NO"
		except.profile = profile
	end                                                                           --[[VERBOSE]] verbose:invoke("unable to connect using the provided IOR profiles")
	return nil, Exception(except)
end

function GIOPRequester:endrequest(request, success, result)
	if success ~= nil then
		request.success = success
		if success then
			request.n = result
		else
			request.n = 1
			request[1] = result
		end
	end
	local replier = self.OperationReplier[request.operation]
	if replier then replier(self, request) end
end

function GIOPRequester:dorequest(request)
	request = self.Request(request)
	request.requester = self
	local operation = request.operation
	request.operation = operation.name
	request.inputs = operation.inputs
	request.outputs = operation.outputs
	request.exceptions = operation.exceptions
	if request.sync_scope == nil then
		request.sync_scope = operation.oneway and "channel" or "servant"
	end
	local reference = request.reference
	local channel, except = self:getchannel(reference)                            --[[VERBOSE]] verbose:invoke("new request to ",reference.object_key,":",request.operation)
	if channel then
		request.object_key = reference.object_key
		local success
		success, except = channel:sendrequest(request)
		if success then
			if request.sync_scope == "channel" then
				self:endrequest(request, true, 0)
			end
			return request
		end
	end
	except.completed = "COMPLETED_NO"
	self:endrequest(request, false, except)
	return request
end

function GIOPRequester:newrequest(request)
	local requester = self.OperationRequester[request.operation.name]
	               or self.dorequest
	return requester(self, request)
end



local SystemExceptionError = {
	["IDL:omg.org/CORBA/COMM_FAILURE:1.0"    ] = "badchannel",
	["IDL:omg.org/CORBA/MARSHAL:1.0"         ] = "badstream",
	["IDL:omg.org/CORBA/NO_IMPLEMENT:1.0"    ] = "badobjimpl",
	["IDL:omg.org/CORBA/BAD_OPERATION:1.0"   ] = "badobjop",
	["IDL:omg.org/CORBA/OBJECT_NOT_EXIST:1.0"] = "badobjkey",
}
local function doreply(self, replied)
	local header = replied.reply
	local decoder = replied.decoder
	local status = header.reply_status
	if status == "NO_EXCEPTION" then                                              --[[VERBOSE]] verbose:invoke("got reply with results for request ",header.request_id," to ",replied.object_key,":",replied.operation)
		local outputs = replied.outputs
		local count = #outputs
		if replied.sync_scope ~= "server" then
			for i = 1, count do
				local ok, result = pcall(decoder.get, decoder, outputs[i])
				if not ok then                                                          --[[VERBOSE]] verbose:invoke("error in decoding of result ",i)
					self:endrequest(replied, false, result)
					break
				end
				replied[i] = result
			end
		end
		if replied.success == nil then
			self:endrequest(replied, true, count)
		end
	elseif status:find("LOCATION_FORWARD", 1, true) == 1 then                     --[[VERBOSE]] verbose:invoke("got remote request to forward request through other channel")
		local ok, reference = pcall(decoder.IOR, decoder)
		if ok then
			if status == "LOCATION_FORWARD_PERM" then                                 --[[VERBOSE]] verbose:invoke("replacing current reference with a new one permanently")
				reference = copy(reference, clear(replied.reference))
			end
			reissue(self, replied, reference)
		else                                                                        --[[VERBOSE]] verbose:invoke("error in decoding of reply with request for different addressing mode")
			self:endrequest(replied, false, result)
		end
	elseif status == "NEEDS_ADDRESSING_MODE" then                                 --[[VERBOSE]] verbose:invoke("got remote request to reissue with a different addressing mode")
		local ok, result = pcall(decoder.short, decoder)
		if ok then
			reissue(self, replied, replied.reference, result)
		else                                                                        --[[VERBOSE]] verbose:invoke("error in decoding of reply with request for different addressing mode")
			self:endrequest(replied, false, result)
		end
	else
		local except
		if status == "USER_EXCEPTION" then                                          --[[VERBOSE]] verbose:invoke("got reply with user exception for request ",header.request_id," to ",replied.object_key,":",replied.operation)
			local repid = decoder:string()
			except = replied.exceptions[repid]
			if except then
				except = decoder:except(except)
				except._repid = repid
				except = Exception(except)
			else
				except = Exception{
					"illegal user exception (got $exception)",
					error = "badexception",
					exception = repid,
					minor = 1,
				}
			end
		elseif status == "SYSTEM_EXCEPTION" then
			-- TODO:[maia] set its type to the proper SystemExcep.
			local repid = decoder:string()                                            --[[VERBOSE]] verbose:invoke("got reply with system exception ",repid," for request ",header.request_id," to ",replied.object_key,":",replied.operation)
			except = decoder:struct(SystemExceptionIDL)
			except[1] = "CORBA System Exception $_repid: minor code: $minor, completed: $completed"
			except.error = SystemExceptionError[repid] or "corbasysex"
			except._repid = repid
			except = Exception(except)
		else --[[status == ???]]                                                    --[[VERBOSE]] verbose:invoke("got unsupported GIOP reply status: ",status)
			except = Exception{
				"unsupported GIOP reply status (got $replystatus)",
				error = "badmessage",
				replystatus = status,
			}
		end
		self:endrequest(replied, false, except)
	end -- of if status == "NO_EXCEPTION"
	replied.reply = nil
	replied.decoder = nil
end

function GIOPRequester:getreply(request, timeout)
	while request.reply == nil do
		local channel = request.channel or reissue(self, request, request.reference)
		if channel == nil then -- error on reissue is stored as request's reply
			return true
		end
		local success, except = channel:getreply(request, timeout)
		if not success then
			return false, except
		end
	end
	doreply(self, request)
	return true
end

return GIOPRequester
