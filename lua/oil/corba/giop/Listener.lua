-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Server-side CORBA GIOP Protocol
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
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

local Exception = require "oil.corba.giop.Exception"
local Channel = require "oil.corba.giop.Channel"                                --[[VERBOSE]] local verbose = require "oil.verbose"

module(...); local _ENV = _M

--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------

local Empty = {}

local SystemExceptions = {}
for _, repID in pairs(SystemExceptionIDs) do
	SystemExceptions[repID] = true
end

--------------------------------------------------------------------------------

local SysExReply = {
	service_context = Empty,
	request_id      = nil, -- defined later
	reply_status    = "SYSTEM_EXCEPTION",
}
local SysExType = { giop.SystemExceptionIDL }
local SysExBody = { n = 1, --[[defined later]] }

function sysexreply(requestid, body)                                            --[[VERBOSE]] verbose:listen("new system exception ",body.exception_id," for request ",requestid)
	SysExReply.request_id = requestid
	SysExBody[1] = body
	body.exception_id = body[1]
	return SysExReply, SysExType, SysExBody
end

--------------------------------------------------------------------------------

Request = class()

function Request:getparams()
	return unpack(self, 1, #self.inputs)
end

function Request:setreply(success, ...)
	local count = select("#", ...)
	self.success = success
	self.n = count
	for i = 1, count do
		self[i] = select(i, ...)
	end
end

function Request:sendreply()                                                    --[[VERBOSE]] verbose:listen(true, "replying for request ",self.request_id)
	local success, except = true
	local channel = self.channel
	local requestid = self.request_id
	if channel and channel[requestid] == self then
		success, except = channel:send(ReplyID, self:getreply())
		if not success
		and except.error ~= "terminated"
		and SystemExceptions[except[1]] then                                        --[[VERBOSE]] verbose:listen("got system exception ",except," during reply")
			except.completed = "COMPLETED_YES"
			success, except = channel:send(ReplyID, sysexreply(requestid, except))
		end
		if success then success, except = self:finish() end                         --[[VERBOSE]] else verbose:listen("no pending request found with id ",requestid,", reply discarded")
	end                                                                           --[[VERBOSE]] verbose:listen(false, "reply ", success and "successfully sent" or "failed: ", except or "")
	return success, except
end

local ExceptionReplyTypes = { idl.string }
local ExceptionReplyBody = { n = 2, --[[defined later]] }
function Request:getreply()
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

function Request:finish()
	local channel = self.channel
	if channel then
		self.channel = nil
		channel[self.request_id] = nil
		local pending = channel.pending
		channel.pending = pending-1
		if channel.closing and pending <= 1 then                                    --[[VERBOSE]] verbose:listen "all pending requests replied, connection being closed"
			return channel:send(CloseConnectionID)
		end
	end
	return true
end

--------------------------------------------------------------------------------

RequestChannel = class({
	pending = 0,
	closing = false,
}, Channel)

function RequestChannel:makerequest(header, decoder)
	header = Request(header)
	local requestid = header.request_id
	if not self[requestid] then
		header.objectkey = header.object_key
		local listener = self.listener
		local entry = listener.servants:retrieve(header.object_key)
		if entry then
			local iface = entry.__type
			header.target = entry.__servant
			header.interface = iface
			local member = listener.indexer:valueof(iface, header.operation)
			if member then                                                            --[[VERBOSE]] verbose:listen("got request for ",header.operation)
				header.member = member
				header.n = #member.inputs
				header.inputs = member.inputs
				header.outputs = member.outputs
				header.exceptions = member.exceptions
				for index, input in ipairs(member.inputs) do
					local ok, result = pcall(decoder.get, decoder, input)
					if not ok then
						assert(type(result) == "table", result)
						header:setreply(false, result)
						break
					end
					header[index] = result
				end
			else                                                                      --[[VERBOSE]] verbose:listen("got illegal operation ",header.operation)
				header:setreply(false, OiLEx2SysEx.badobjop)
			end
		else                                                                        --[[VERBOSE]] verbose:listen("got illegal object ",header.object_key)
			header:setreply(false, OiLEx2SysEx.badobjkey)
		end
	else                                                                          --[[VERBOSE]] verbose:listen("got replicated request id ",requestid,", ignoring it")
		header:setreply(true)
		header.response_expected = false
	end
	if header.response_expected then
		header.channel = self
		self[requestid] = header
		self.pending = self.pending+1                                               --[[VERBOSE]] else verbose:listen "no response expected"
	end
	return header
end

function RequestChannel:getrequest(timeout)
	local result, except
	repeat
		if self:trylock("read", timeout) then
			local msgid, header, decoder = self:receive(timeout)
			self:freelock("read")
			if msgid == RequestID then                                                  --[[VERBOSE]] verbose:listen("got request ",header.request_id)
				local request = self:makerequest(header, decoder)
				if request.success == nil then return request end
				result, except = request:sendreply()
			elseif msgid == CancelRequestID then
				local request = self[header.request_id]                                   --[[VERBOSE]] verbose:listen("got cancelation of request ",header.request_id, request and "" or " (not found)")
				if request then result, except = request:finish() end
			elseif msgid == LocateRequestID then                                        --[[VERBOSE]] verbose:listen(true, "got request ",header.request_id," for location of object ",header.object_key)
				local reply = { request_id = header.request_id }
				if self.listener.servants:retrieve(header.object_key)
					then reply.locate_status = "OBJECT_HERE"                                --[[VERBOSE]] verbose:listen("object found here")
					else reply.locate_status = "UNKNOWN_OBJECT"                             --[[VERBOSE]] verbose:listen("object is unknown")
				end                                                                       --[[VERBOSE]] verbose:listen(false)
				reply[1] = reply
				result, except = self:send(LocateReplyID, reply)
			elseif msgid == MessageErrorID then                                         --[[VERBOSE]] verbose:listen "got message error notification"
				result, except = self:send(CloseConnectionID)
			elseif MessageType[msgid] then                                              --[[VERBOSE]] verbose:listen("got unknown message ",msgid,", sending message error notification")
				result, except = self:send(MessageErrorID)
			elseif header.error == "badversion" then
				result, except = self:send(MessageErrorID)
				self.socket:close()
			else
				result, except = nil, header
			end
		end
	until not result
	return result, except
end

function RequestChannel:acquire()
	self.listener.access:remove(self.socket)
end

function RequestChannel:release()
	self.listener.access:add(self.socket)
end

--------------------------------------------------------------------------------

class(_ENV)

function _ENV:setup(configs)
	if self.configs == nil then
		self.configs = configs -- delay actual initialization (see 'getaccess')
		return true
	end
	return nil, Exception{
		error = "already started",
		message = "already started",
	}
end

function _ENV:getaccess(probe)
	local result, except = self.access
	if result == nil and not probe then
		result = self.configs
		if result == nil then
			except = Exception{
				error = "terminated",
				message = "terminated",
			}
		else
			result, except = self.channels:newaccess(result)
			if result ~= nil then
				self.access = result
				self.sock2channel = memoize(function(socket)
					return RequestChannel{
						socket = socket,
						listener = self,
						codec = self.codec,
					}
				end, "k")
				local host, port, addresses = result:address()
				self.configs.host = host
				self.configs.port = port
				self.configs.addresses = addresses
			end
		end
	end
	return result, except
end

function _ENV:getaddress(probe)
	local result, except = self.address
	if result == nil then
		result, except = self:getaccess(probe)
		if result ~= nil then
			local addresses
			result, except, addresses = result:address()
			if result ~= nil then
				result, except = {
					host = result,
					port = except,
					addresses = addresses,
				}
				self.address = result
			end
		end
	end
	return result, except
end

function _ENV:getchannel(timeout)
	local result, except = self:getaccess()
	if result ~= nil then
		result, except = result:accept(timeout)
		if result ~= nil then
			result, except = self.sock2channel[result], nil
		end
	end
	return result, except
end

function _ENV:shutdown()
	local result, except = self:getaccess()
	if result then
		local sock2channel = self.sock2channel
		for _, socket in ipairs(result:close()) do
			local channel = sock2channel[socket]
			if channel.pending > 0 then
				channel.closing = true
			else
				result, except = channel:send(CloseConnectionID)
				if not result and except.error~="terminated" then return nil, except end
			end
		end
		self.sock2channel = nil
		self.access = nil
		self.address = nil
		self.configs = nil
		return true
	end
	return result, except
end
