-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Marshaling of CORBA GIOP Protocol Messages
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                       --[[VERBOSE]] local verbose = require "oil.verbose"
local assert = _G.assert
local ipairs = _G.ipairs
local pcall = _G.pcall
local type = _G.type

local coroutine = require "coroutine"
local running = coroutine.running

local math = require "math"
local floor = math.floor

local struct = require "struct"
local littleendian = (struct.unpack("B", struct.pack("I2", 1)) == 1)

local Queue = require "loop.collection.Queue"

local Mutex = require "cothread.Mutex"

local oo = require "oil.oo"
local class = oo.class

local idl = require "oil.corba.idl"

local giop = require "oil.corba.giop"                                         --[[VERBOSE]] local MessageType = giop.MessageType
local MagicTag = giop.MagicTag
local HeaderSize = giop.HeaderSize
local GIOPHeader_v1_ = giop.Header_v1_
local MessageHeader_v1_ = giop.MessageHeader_v1_
local RequestID = giop.RequestID
local ReplyID = giop.ReplyID
local CancelRequestID = giop.CancelRequestID
local LocateRequestID = giop.LocateRequestID
local CloseConnectionID = giop.CloseConnectionID
local MessageErrorID = giop.MessageErrorID
local FragmentID = giop.FragmentID
local SystemExceptionIDs = giop.SystemExceptionIDs
local SystemExceptionIDL = giop.SystemExceptionIDL

local Channel = require "oil.protocol.Channel"
local Exception = require "oil.corba.giop.Exception"



local Empty = {}
local MessageBuilder_v1_ = {}
local MessageAdapter_v1_ = {}
do
	local values = {
		reserved = "\000\000\000",
		response_expected = nil, -- defined later, see below
		requesting_principal = Empty,
	}
	local meta = {}
	setmetatable(values, meta)
	MessageBuilder_v1_[0] = {
		[RequestID] = function(header)
			meta.__index = header
			values.response_expected = (header.sync_scope~="channel")
			return values
		end,
		[ReplyID] = function(header)
			meta.__index = header
			return values
		end,
	}
	MessageAdapter_v1_[0] = {
		[RequestID] = function(header)
			header.sync_scope = header.response_expected and "servant" or "channel"
			return header
		end
	}
	MessageBuilder_v1_[1] = MessageBuilder_v1_[0]
	MessageAdapter_v1_[1] = MessageAdapter_v1_[0]
end
do
	local targetkey = {
		_switch = 0,
		_value = nil, -- defined later, see below
	}
	local values = {
		reserved = "\000\000\000",
		response_flags = nil, -- defined later, see below
		target = nil, -- defined later, see below
	}
	local meta = {}
	setmetatable(values, meta)
	local response_flags = {
		channel = 0x0,
		server  = 0x1,
		servant = 0x3,
	}
	MessageBuilder_v1_[2] = {
		[RequestID] = function(header)
			meta.__index = header
			values.response_flags = response_flags[header.sync_scope]
			if header.target == nil then
				targetkey._value = header.object_key
				values.target = targetkey
			else
				values.target = nil
			end
			return values
		end,
		[LocateRequestID] = function(header)
			meta.__index = header
			targetkey._value = header.object_key
			values.target = targetkey
			return values
		end,
	}
	local sync_scopes = {}
	for scope, flag in pairs(response_flags) do
		sync_scopes[flag] = scope
	end
	local function target2objkey(target, self)
		local kind = target._switch
		if kind == 0 then
			return target._value
		elseif kind == 1 then
			local context = self.context
			local referrer = context.referrer or context.codec.referrer
			if referrer then
				local profile = referrer:decodeprofile(target._value)
				if profile then
					return profile.object_key
				end
			end
		elseif kind == 2 then
			local target = target._value
			local profile = target.ior:getprofile(target.selected_profile_index)
			if profile.decoded then
				return profile.object_key
			end
		end
	end
	MessageAdapter_v1_[2] = {
		[RequestID] = function(header, self)
			header.sync_scope = sync_scopes[header.response_flags]
			header.object_key = target2objkey(header.target, self)
			return header
		end,
		[LocateRequestID] = function(header, self)
			header.object_key = target2objkey(header.target, self)
			return header
		end,
	}
end
MessageBuilder_v1_[3] = MessageBuilder_v1_[2]


local function pdecode_cont(ok, ...)
	if ok then return true, ... end
	if type(...) ~= "string" then return false, Exception(...) end
	return false, Exception{ (...), error = "badvalue" }
end
local function pdecode(func, ...)
	return pdecode_cont(pcall(func, ...))
end

local function encodevalues(self, types, values, encoder)
	local count = values.n or #values
	for index, idltype in ipairs(types) do
		local value
		if index <= count then
			value = values[index]
		end
		encoder:put(value, idltype)
	end
end

local function encodemsg(self, kind, header, types, values)
	local codec = self.context.codec
	-- create GIOP message body
	local encoder = codec:encoder()
	encoder:shift(self.headersize) -- alignment accordingly to GIOP header size
	if header then
		local builder = self.messagebuilder[kind]
		if builder then header = builder(header) end
		encoder:struct(header, self.messagetype[kind])
	end
	if types and #types > 0 then
		if self.version > 1 and (kind == RequestID or kind == ReplyID) then
			encoder:align(8)
			local encoded = values.encoded
			if encoded ~= nil then
				local length = #encoded
				encoder:rawput('c'..length, encoded, length)
			else
				encodevalues(self, types, values, encoder)
			end
		else
			encodevalues(self, types, values, encoder)
		end
	end
	local stream = encoder:getdata()
	-- create GIOP message header
	local header = self.header
	header.message_size = #stream
	header.message_type = kind
	encoder = codec:encoder()
	encoder:struct(header, self.headertype)
	return encoder:getdata()..stream
end
local function sendmsg(self, kind, header, types, values)                     --[[VERBOSE]] verbose:message(true, "send message ",MessageType[kind],header or "")
	local ok, result = pcall(encodemsg, self, kind, header, types, values)
	if ok then
		self:trylock("write")
		ok, result = self:send(result)
		if not ok and type(result) == "table" then result = Exception(result) end
		self:freelock("write")                                                    --[[VERBOSE]] else verbose:message("message encoding failed")
	end                                                                         --[[VERBOSE]] verbose:message(false)
	return ok, result
end

local function decodeheader(self, stream)
	local decoder = self.context.codec:decoder(stream)
	local header = self.headertype
	local magic = decoder:array(header[1].type)
	if magic ~= self.magictag then                                              --[[VERBOSE]] verbose:message("got invalid magic tag: ",magic)
		error(Exception{
			"illegal GIOP magic tag (got $actualtag)",
			error = "badstream",
			actualtag = magic,
		})
	end
	local version = decoder:struct(header[2].type)
	local minor = version.minor
	header = GIOPHeader_v1_[minor]
	if version.major ~= 1 or header == nil then                                 --[[VERBOSE]] verbose:message("got unsupported GIOP version: ",version)
		error(Exception{
			"illegal GIOP version (got $majorversion.$minorversion)",
			error = "badversion",
			majorversion = version.major,
			minorversion = version.minor,
		})
	end
	local incomplete
	if minor == 0 then
		decoder:order(decoder:boolean())
	else
		local flags = decoder:octet()
		local orderbit = flags%2
		decoder:order(orderbit == 1)
		local fragbit = (flags-orderbit)%4
		incomplete = (fragbit == 2)
	end
	return minor, -- version
	       decoder:octet(), -- type
	       decoder:ulong(), -- size
	       incomplete,
	       decoder
end
local function decodemsgbody(self, decoder, minor, kind)
	local struct = MessageHeader_v1_[minor][kind]
	if struct then
		local body = decoder:struct(struct)
		local adapter = MessageAdapter_v1_[minor][kind]
		if adapter then
			body = adapter(body, self)
		end
		if minor > 1 and (kind == RequestID or kind == ReplyID)
		and decoder.cursor <= #decoder.data then
			decoder:align(8)
		end
		return body
	end
end
local IncompleteMessages = {}
local function receivemsg(self, timeout)                                      --[[VERBOSE]] verbose:message(true, "get message from channel")
	while true do
		local minor, kind, size, decoder, incomplete
		local pending = self.pendingmessage
		if pending == nil then
			-- unmarshal message header
			local stream, except = self:receive(self.headersize, timeout)
			if stream == nil then                                                   --[[VERBOSE]] verbose:message(false, except.error == "timeout" and "message data is not available yet" or "error while reading message header data")
				return nil, Exception(except)
			end
			local ok
			ok, minor, kind, size, incomplete, decoder = pdecode(decodeheader,
			                                                     self, stream)
			if not ok then                                                          --[[VERBOSE]] verbose:message(false, "error in message header decoding: ",minor.error)
				return nil, minor
			end
		else                                                                      --[[VERBOSE]] verbose:message("continue message from a previous decoded header")
			-- continue decoding of a previous decoded header
			minor = pending.minor
			kind = pending.kind
			size = pending.size
			decoder = pending.decoder
			incomplete = pending.incomplete
		end
		-- upgrade channel version
		self:upgradeto(minor)
		-- unmarshal message body
		local message
		if size > 0 then
			local stream, except = self:receive(size, timeout)
			if stream == nil then
				if except.error ~= "timeout" then                                     --[[VERBOSE]] verbose:message(false, "error while reading message body data")
					self.pending = nil
				elseif pending == nil then                                            --[[VERBOSE]] verbose:message(false, "message body data is not available yet")
					self.pending = {
						kind = kind,
						size = size,
						decoder = decoder,
						incomplete = incomplete,
					}                                                                   --[[VERBOSE]] else verbose:message(false)
				end
				return nil, Exception(except)
			end
			decoder:append(stream)
		end
		self.pending = nil
		local fragment = (kind == FragmentID) or incomplete
		if fragment then
			local cursor
			local id
			if minor == 1 then
				id = #IncompleteMessages
				if kind ~= FragmentID then id = id+1 end
			else
				cursor = decoder.cursor
				local ok
				ok, id = pdecode(decoder.ulong, decoder)
				if not ok then                                                        --[[VERBOSE]] verbose:message(false, "error in decoding request id: ",message.error)
					return nil, id
				end
			end
			-- handle incomplete fragmented messages
			if kind == FragmentID then
				local previous = IncompleteMessages[id]
				previous:append(decoder:remains())
				if not incomplete then
					decoder = previous
					kind = decoder.kind                                                 --[[VERBOSE]] verbose:message("got final fragment of message ",MessageType[kind])
					fragment = false
					IncompleteMessages[id] = nil                                        --[[VERBOSE]] else verbose:message("fragment of an incomplete message")
				end
			else                                                                    --[[VERBOSE]] verbose:message("got the begin of a fragmented message")
				if cursor then decoder.cursor = cursor end
				decoder.kind = kind
				IncompleteMessages[id] = decoder
			end
		end
		if not fragment then
			local ok
			ok, message = pdecode(decodemsgbody, self, decoder, minor, kind)
			if not ok then                                                          --[[VERBOSE]] verbose:message(false, "error in message body decoding: ",message.error)
				return nil, message
			end                                                                     --[[VERBOSE]] verbose:message(false, "got message ",MessageType[kind],message or "")
			return kind, message or minor, decoder
		end
	end
end

local function failedGIOP(self, errmsg)
	sendmsg(self, MessageErrorID) -- ignore any errors
	self:close() -- ignore any errors
	return nil, Exception{
		"GIOP Failure ($errmsg)",
		error = "badmessage",
		errmsg = errmsg,
	}
end



local GIOPChannel = class({
	magictag = MagicTag,
	headersize = HeaderSize,
	version = 0,
}, Channel)

function GIOPChannel:__init()
	self.header = {
		magic = MagicTag,
		GIOP_version = {major=1, minor=nil}, -- 'minor' is defined later
		byte_order = littleendian,
		flags = littleendian and 1 or 0,
		message_type = nil, -- defined later
		message_size = nil, -- defined later
	}
	self.unprocessed = Queue()
	self.incoming = {}
	self.outgoing = {}
	self:upgradeto(self.version)
end

function GIOPChannel:register(request, direction)
	if request.channel == nil then
		request.channel = self
		local set = self[direction]
		local id
		if direction == "outgoing" then
			id = #set+1
			request.id = id
			request.request_id = 2*id + (self.bidir_role=="acceptor" and 1 or 0)
		else
			id = request.request_id
		end
		set[id] = request
		return true
	end
end

function GIOPChannel:unregister(requestid, direction)
	local set = self[direction]
	local request = set[requestid]
	if request ~= nil then
		set[requestid] = nil
		request.channel = nil
		if direction == "outgoing" then
			request.id = nil
			request.request_id = nil
		elseif self.closing then
			self:close()
		end
		return request
	end
end

function GIOPChannel:upgradeto(minor)
	if minor >= self.version and GIOPHeader_v1_[minor] ~= nil then              --[[VERBOSE]] verbose:message("GIOP channel upgraded to version 1.",minor)
		self.headertype = GIOPHeader_v1_[minor]
		self.messagetype = MessageHeader_v1_[minor]
		self.messagebuilder = MessageBuilder_v1_[minor]
		self.header.GIOP_version.minor = minor
		self.version = minor
	end
end

local AddressingType = {giop.AddressingDisposition}
local KeyAddrValue = {giop.KeyAddr}
local MessageHandlers = {
	[RequestID] = function(channel, header, decoder)
		local requestid = header.request_id
		if channel.incoming[requestid] ~= nil then                                --[[VERBOSE]] verbose:listen("got replicated request id ",requestid)
			return failedGIOP(channel, "remote ORB issued a request with duplicated ID")
		end
		local response = header.sync_scope ~= "channel"
		if header.object_key == nil then                                          --[[VERBOSE]] verbose:listen("got request ",requestid," with wrong addressing information")
			if response then                                                        --[[VERBOSE]] verbose:listen("send reply requesting different addressing information")
				local reply = {
					request_id = requestid,
					reply_status = "NEEDS_ADDRESSING_MODE",
				}
				return sendmsg(channel, ReplyID, reply, AddressingType, KeyAddrValue)
			end                                                                     --[[VERBOSE]] verbose:listen("ignoring request because no reply is expected, so it is not possible to request different addressing information")
			return true
		end
		if response then
			channel:register(header, "incoming")                                    --[[VERBOSE]] else verbose:listen("no reply is expected")
		end
		header.decoder = decoder
		local unprocessed = channel.unprocessed
		unprocessed:enqueue(header)
		channel:signal("read", unprocessed)
		return true
	end,
	[ReplyID] = function(channel, header, decoder)
		local request = channel:unregister(floor(header.request_id/2), "outgoing")
		if request == nil then                                                    --[[VERBOSE]] verbose:invoke("got reply for invalid request ID: ",header.request_id)
			return failedGIOP(channel, "remote ORB issued a reply with unknown ID")
		end
		request.reply = header
		request.decoder = decoder
		channel:signal("read", request) -- notify thread waiting for this reply
		return request
	end,
	[CancelRequestID] = function(channel, header, decoder)                      --[[VERBOSE]] verbose:listen("got cancelation of request ",requestid)
		if channel:unregister(header.request_id, "incoming") == nil then          --[[VERBOSE]] verbose:listen("canceled request ",requestid," does not exist")
			return failedGIOP(channel, "remote ORB canceled a request with unknown ID")
		end
		return true
	end,
	[LocateRequestID] = function(channel, header, decoder)
		local types, values
		local objkey = header.object_key                                          --[[VERBOSE]] verbose:listen(true, "got request ",header.request_id," to locate object ",objkey)
		local reply = { request_id = header.request_id }
		if objkey == nil then
			reply.locate_status = "LOC_NEEDS_ADDRESSING_MODE"                       --[[VERBOSE]] verbose:listen("different addressing information is required")
			types = AddressingType
			values = KeyAddrValue
		elseif self.context.servants:retrieve(objkey) then
			reply.locate_status = "OBJECT_HERE"                                     --[[VERBOSE]] verbose:listen("object found here")
		else
			reply.locate_status = "UNKNOWN_OBJECT"                                  --[[VERBOSE]] verbose:listen("object is unknown")
		end                                                                       --[[VERBOSE]] verbose:listen(false)
		return sendmsg(channel, LocateReplyID, reply, types, values)
	end,
	[CloseConnectionID] = function(channel)
		-- cancel all pending incoming requests
		for requestid in pairs(channel.incoming) do
			channel:unregister(requestid, "incoming")
		end
		-- notify threads waiting for replies to reissue them in a new connection
		for requestid in pairs(channel.outgoing) do
			channel:signal("read", channel:unregister(requestid, "outgoing"))
		end
		return channel:close()
	end,
	[MessageErrorID] = function(channel, minor)
		if next(channel.incoming) == nil and minor < channel.version then         --[[VERBOSE]] verbose:invoke("got remote request to use GIOP 1.",minor," instead of GIOP 1.",channel.version)
			-- notify threads waiting for replies to reissue them in a new connection
			for requestid in pairs(channel.outgoing) do
				request.reference.ior_profile_decoded.giop_minor = minor
				channel:signal("read", channel:unregister(requestid, "outgoing"))
			end
			return channel:close()
		end                                                                       --[[VERBOSE]] verbose:invoke("got remote indication of error in protocol messages")
		return failedGIOP(channel, "remote ORB reported error in GIOP messages")
	end,
}
function GIOPChannel:processmessage(timeout)
	local msgid, header, decoder = receivemsg(self, timeout)
	if msgid == nil then
		if header.error == "badversion" then
			sendmsg(self, MessageErrorID)
		end
		return nil, header
	end
	local handler = MessageHandlers[msgid]
	if handler == nil then
		return sendmsg(self, MessageErrorID)
	end
	return handler(self, header, decoder)
end

function GIOPChannel:sendrequest(request)
	local bidir = self.bidir_role
	if self.sync_scope ~= "channel" then
		self:register(request, "outgoing") -- defines the 'request_id'
	else
		request.request_id = (bidir=="acceptor" and 1 or 0)
	end
	local types = request.inputs
	if self.version > 1 and request.encoded == nil then
		local encoder = self.context.codec:encoder()
		encodevalues(self, types, request, encoder)
		request.encoded = encoder:getdata()
	end
	-- add Bi-Directional GIOP service context
	local listener
	if bidir == nil then
		listener = self.context.listener
		if listener ~= nil then
			bidir = listener:addbidircontext(request.service_context)
			if bidir ~= nil then                                                    --[[VERBOSE]] verbose:invoke("bi-directional GIOP indication added to the request")
				request.service_context = bidir
			end
		end
	end
	if request.service_context == nil then request.service_context = Empty end
	local success, except = sendmsg(self, RequestID, request, types, request)
	if not success then                                                         --[[VERBOSE]] verbose:invoke("unable to send the request")
		self:unregister(request.id, "outgoing")
	elseif bidir ~= nil and listener ~= nil then
		self.bidir_role = "connector"
		listener:addbidirchannel(self)
	end
	return success, except
end

function GIOPChannel:getreply(request, timeout)
	local granted, expired = self:trylock("read", timeout, request)
	if granted then
		local result, except
		repeat
			result, except = self:processmessage(timeout)
		until result == nil or result == request or request.channel ~= self
		self:freelock("read")
		if result == nil then                                                     --[[VERBOSE]] verbose:invoke("failed to get reply")
			return nil, except
		end
	elseif expired then --[[timeout of 'trylock' expired]]                      --[[VERBOSE]] verbose:invoke("got no reply before timeout")
		return nil, Exception{ "timeout", error = "timeout" }
	end
	return true
end

function GIOPChannel:getrequest(timeout)
	local unprocessed = self.unprocessed
	if unprocessed:empty() then                                                 --[[VERBOSE]] verbose:listen(true, "no request ready to be processed, read from channel")
		if self:trylock("read", timeout, unprocessed) then
			local ok, except
			repeat
				ok, except = self:processmessage(timeout)
			until not ok or not unprocessed:empty()
			self:freelock("read")
			if not ok then                                                          --[[VERBOSE]] verbose:listen(false, "failed to get request")
				return nil, except
			end
		end                                                                       --[[VERBOSE]] verbose:listen(false, "request was successfully read from channel")
	end
	local request = unprocessed:dequeue()
	-- handle Bi-Directional GIOP service context
	local bidir = self.bidir_role
	if bidir == nil then
		local context = self.context
		local requester = context.requester
		if requester ~= nil then
			local decoder = context.servicedecoder
			if decoder ~= nil then
				bidir = decoder:decodebidir(request.service_context)
				if bidir ~= nil then
					self.bidir_role = "acceptor"
					requester:addbidirchannel(self, bidir)                              --[[VERBOSE]] else verbose:listen("no bi-directional GIOP indication found in request received")
				end
			end
		end
	end
	return self.context.Request(request)
end

local SysExTypes = { idl.string, giop.SystemExceptionIDL }
local SysExBody = { n=2, --[[defined later, see below]] }
function GIOPChannel:sendreply(request)
	local success, except = true
	local requestid = request.request_id                                        --[[VERBOSE]] verbose:listen(true, "replying for request ",request.request_id," for ",request.objectkey,":",request.operation)
	if self.incoming[requestid] == request then
		local types, values = request:getreplybody()
		if request.service_context == nil then request.service_context = Empty end
		success, except = sendmsg(self, ReplyID, request, types, values)
		if not success then                                                       --[[VERBOSE]] verbose:listen(true, "unable to send reply: ",except)
			if except.error == "terminated" then                                    --[[VERBOSE]] verbose:listen("connection terminated")
				success, except = true
			else
				if request.reply_status == "SYSTEM_EXCEPTION" then
					except.completed = values[2].completed
				else
					request.reply_status = "SYSTEM_EXCEPTION"
					except.completed = "COMPLETED_YES"
				end
				SysExBody[1], SysExBody[2] = except._repid, except
				success, except = sendmsg(self,ReplyID,request,SysExTypes,SysExBody)
				if not success then                                                   --[[VERBOSE]] verbose:listen("unable to send exception on reply: ",except)
					if except.error == "terminated" then                                --[[VERBOSE]] verbose:listen("connection terminated")
						success, except = true                                            --[[VERBOSE]] else verbose:listen(false, "unable to send the error on reply as well")
					end                                                                 --[[VERBOSE]] else verbose:listen(false, "error on reply was sent instead of the original result")
				end
			end
		end
		self:unregister(requestid, "incoming")                                    --[[VERBOSE]] else verbose:listen("no pending request found with id ",requestid,", reply discarded")
	end                                                                         --[[VERBOSE]] verbose:listen(false, "reply ", success and "successfully processed" or "failed: ", except or "")
	return success, except
end

function GIOPChannel:close()
	if next(self.incoming) == nil then
		local result, except
		if self.server or self.version >= 2  then
			result, except = sendmsg(self, CloseConnectionID)
		else
			result, except = true
		end
		if result or except.error == "terminated" then
			result, except = Channel.close(self)
		end                                                                       --[[VERBOSE]] verbose:listen("channel closed")
		return result, except
	end                                                                         --[[VERBOSE]] verbose:listen("channel marked for closing after pending requests are replied")
	self.closing = true
	return true
end

return GIOPChannel
