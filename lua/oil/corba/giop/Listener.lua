-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Server-side CORBA GIOP Protocol
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local assert = _G.assert
local ipairs = _G.ipairs
local pairs = _G.pairs
local pcall = _G.pcall
local select = _G.select
local type = _G.type
local unpack = _G.unpack
local stderr = _G.io and _G.io.stderr

local tabops = require "loop.table"
local memoize = tabops.memoize

local oo = require "oil.oo"
local class = oo.class

local idl = require "oil.corba.idl"

local giop = require "oil.corba.giop"
local RequestID = giop.RequestID
local ReplyID = giop.ReplyID
local LocateRequestID = giop.LocateRequestID
local LocateReplyID = giop.LocateReplyID
local CancelRequestID = giop.CancelRequestID
local CloseConnectionID = giop.CloseConnectionID
local MessageErrorID = giop.MessageErrorID
local MessageType = giop.MessageType
local SystemExceptionIDs = giop.SystemExceptionIDs

local Listener = require "oil.protocol.Listener"
local Exception = require "oil.corba.giop.Exception"
local GIOPChannel = require "oil.corba.giop.Channel"



local UnknownSysEx = {
	"IDL:omg.org/CORBA/UNKNOWN:1.0",
	minor = 0,
	completed = "COMPLETED_MAYBE",
}

local OiLEx2SysEx = {
	badobjkey = Exception{ SystemExceptionIDs.OBJECT_NOT_EXIST,
		minor = 1,
		completed = "COMPLETED_NO",
	},
	badobjimpl = Exception{ SystemExceptionIDs.NO_IMPLEMENT,
		minor = 1,
		completed = "COMPLETED_NO",
	},
	badobjop = Exception{ SystemExceptionIDs.BAD_OPERATION,
		minor = 1,
		completed = "COMPLETED_NO",
	},
}



local Empty = {}

local SystemExceptions = {}
for _, repID in pairs(SystemExceptionIDs) do
	SystemExceptions[repID] = true
end



local SysExReply = {
	service_context = Empty,
	request_id      = nil, -- defined later
	reply_status    = "SYSTEM_EXCEPTION",
}
local SysExType = { giop.SystemExceptionIDL }
local SysExBody = { n = 1, --[[defined later]] }

local function sysexreply(requestid, body)                                            --[[VERBOSE]] verbose:listen("new system exception ",body.exception_id," for request ",requestid)
	SysExReply.request_id = requestid
	SysExBody[1] = body
	body.exception_id = body[1]
	return SysExReply, SysExType, SysExBody
end


local ServerRequest = class({}, Listener.Request)

-- this is a separated method to provide pointcut for interception
local ExceptionReplyTypes = { idl.string }
local ExceptionReplyBody = { n = 2, --[[defined later]] }
function ServerRequest:getreply()
	if self.success then                                                          --[[VERBOSE]] verbose:listen "got successful results"
		self.service_context = Empty
		self.reply_status = "NO_EXCEPTION"
		return self, self.outputs, self
	else
		local requestid = self.request_id
		local except = self[1]
		local extype = type(except)
		if extype == "table" then                                                   --[[VERBOSE]] verbose:listen("got exception ",except)
			local excepttype = self.exceptions
			excepttype = excepttype and excepttype[ except[1] ]
			if excepttype then
				self.service_context = Empty
				self.reply_status = "USER_EXCEPTION"
				ExceptionReplyTypes[2] = excepttype
				ExceptionReplyBody[1] = except[1]
				ExceptionReplyBody[2] = except
				return self, ExceptionReplyTypes, ExceptionReplyBody
			else
				if not SystemExceptions[ except[1] ] then                               --[[VERBOSE]] verbose:listen("got unexpected exception ",except)
					except = OiLEx2SysEx[except.error] or UnknownSysEx                    --[[VERBOSE]] else verbose:listen("got system exception ",except)
				end
			end
		elseif extype == "string" then                                              --[[VERBOSE]] verbose:listen("got unexpected error: ", except)
			if stderr then stderr:write(except, "\n") end
			except = UnknownSysEx
		else                                                                        --[[VERBOSE]] verbose:listen("got illegal exception: ", except)
			except = UnknownSysEx
		end
		return sysexreply(requestid, except)
	end
end

function ServerRequest:preinvoke(entry, member)
	if member ~= nil then
		local inputs = member.inputs
		local count = #inputs
		self.n = count
		self.outputs = member.outputs
		self.exceptions = member.exceptions
		local decoder = self.decoder
		for i = 1, count do
			local ok, result = pcall(decoder.get, decoder, inputs[i])
			if not ok then
				assert(type(result) == "table", result)
				self:setreply(false, result)
				return -- request cancelled
			end
			self[i] = result
		end
		local object = entry.__servant
		local method = object[member.name]
		if method == nil then
			method = member.implementation
		end
		return object, method
	end
end



local ServerChannel = class({}, GIOPChannel)

function ServerChannel:close()
	local result, except = self:sendmsg(CloseConnectionID)
	if result or except.error == "terminated" then
		result, except = true
	end
	return result, except
end

local function noresponse() return true end
function ServerChannel:getrequest(timeout)
	local result, except
	repeat
		if self:trylock("read", timeout) then
			local msgid, header, decoder = self:receivemsg(timeout)
			self:freelock("read")
				if msgid == RequestID then                                              --[[VERBOSE]] verbose:listen("got request ",header.request_id)
				local requestid = header.request_id
				if not self[requestid] then
					header.decoder = decoder
					if header.response_expected then
						header.channel = self
					else                                                                  --[[VERBOSE]] verbose:listen "no response expected"
						header.sendreply = noresponse
					end
					header.objectkey = header.object_key
					return self.listener.Request(header)                                 --[[VERBOSE]] else verbose:listen("got replicated request id ",requestid,", ignoring it")
				end
			elseif msgid == CancelRequestID then
				local request = self[header.request_id]                                 --[[VERBOSE]] verbose:listen("got cancelation of request ",header.request_id, request and "" or " (not found)")
				if request then result, except = request:finish() end
			elseif msgid == LocateRequestID then                                      --[[VERBOSE]] verbose:listen(true, "got request ",header.request_id," for location of object ",header.object_key)
				local reply = { request_id = header.request_id }
				if self.listener.servants:retrieve(header.object_key)
					then reply.locate_status = "OBJECT_HERE"                              --[[VERBOSE]] verbose:listen("object found here")
					else reply.locate_status = "UNKNOWN_OBJECT"                           --[[VERBOSE]] verbose:listen("object is unknown")
				end                                                                     --[[VERBOSE]] verbose:listen(false)
				reply[1] = reply
				result, except = self:sendmsg(LocateReplyID, reply)
			elseif msgid == MessageErrorID then                                       --[[VERBOSE]] verbose:listen "got message error notification"
				result, except = self:sendmsg(CloseConnectionID)
			elseif MessageType[msgid] then                                            --[[VERBOSE]] verbose:listen("got unknown message ",msgid,", sending message error notification")
				result, except = self:sendmsg(MessageErrorID)
			elseif header.error == "badversion" then
				result, except = self:sendmsg(MessageErrorID)
				self:close()
			else
				result, except = nil, header
			end
		end
	until not result
	return result, except
end

function ServerChannel:sendreply(request)                                       --[[VERBOSE]] verbose:listen(true, "replying for request ",request.request_id)
	local success, except = true
	local requestid = request.request_id
	if self and self[requestid] == request then
		success, except = self:sendmsg(ReplyID, request:getreply())
		if not success then
			if except.error == "terminated" then                                      --[[VERBOSE]] verbose:listen("unable to send reply, connection terminated")
				success, except = true
			else
				if SystemExceptions[except[1]] then                                     --[[VERBOSE]] verbose:listen("got system exception ",except," during reply")
					except.completed = "COMPLETED_YES"
					success, except = self:sendmsg(ReplyID, sysexreply(requestid, except))
				end
			end
		end                                                                         --[[VERBOSE]] else verbose:listen("no pending request found with id ",requestid,", reply discarded")
	end                                                                           --[[VERBOSE]] verbose:listen(false, "reply ", success and "successfully processed" or "failed: ", except or "")
	return success, except
end



return class({
	Request = ServerRequest,
	Channel = ServerChannel,
}, Listener)
