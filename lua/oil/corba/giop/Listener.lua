-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Server-side CORBA GIOP Protocol
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                       --[[VERBOSE]] local verbose = require "oil.verbose"
local assert = _G.assert
local ipairs = _G.ipairs
local pairs = _G.pairs
local pcall = _G.pcall
local select = _G.select
local tostring = _G.tostring
local type = _G.type
local unpack = _G.unpack
local stderr = _G.io and _G.io.stderr -- only if available

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
local Request = Listener.Request

local Exception = require "oil.corba.giop.Exception"
local GIOPChannel = require "oil.corba.giop.Channel"



local function unknownex(error)
	if stderr then stderr:write(tostring(error), "\n") end
	return Exception{ SystemExceptionIDs.UNKNOWN,
		minor = 0,
		completed = "COMPLETED_MAYBE",
		error = error,
	}
end

local OiLEx2SysEx = {
	badobjkey = {
		_repid = SystemExceptionIDs.OBJECT_NOT_EXIST,
		minor = 1,
		completed = "COMPLETED_NO",
	},
	badobjimpl = {
		_repid = SystemExceptionIDs.NO_IMPLEMENT,
		minor = 1,
		completed = "COMPLETED_NO",
	},
	badobjop = {
		_repid = SystemExceptionIDs.BAD_OPERATION,
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
	request_id      = nil, -- defined later
	reply_status    = "SYSTEM_EXCEPTION",
}
local SysExType = { giop.SystemExceptionIDL }
local SysExBody = { n = 1, --[[defined later]] }

local function sysexreply(requestid, body)                                    --[[VERBOSE]] verbose:listen("new system exception ",body.exception_id," for request ",requestid)
	SysExReply.request_id = requestid
	SysExBody[1] = body
	body.exception_id = body[1]
	return SysExReply, SysExType, SysExBody
end


local ServerRequest = class({}, Request)

local function noresponse() return true end
function ServerRequest:__init()
	if self.sync_scope == "channel" then
		self.sendreply = noresponse
	end
	self.objectkey = self.object_key
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

local UserExTypes = { idl.string, --[[defined later, see below]] }
local SysExTypes = { idl.string, giop.SystemExceptionIDL }
local ExMsgBody = {}
function ServerRequest:getreplybody()
	self.service_context = nil
	if self.success then                                                        --[[VERBOSE]] verbose:listen("got successful results")
		self.reply_status = "NO_EXCEPTION"
		return self.outputs, self
	end
	local except = self[1]
	if type(except) == "table" then
		local repid = except._repid
		local excepttype = self.exceptions
		excepttype = excepttype and excepttype[repid]
		if excepttype then                                                        --[[VERBOSE]] verbose:listen("got exception ",except)
			self.reply_status = "USER_EXCEPTION"
			UserExTypes[2] = excepttype
			ExMsgBody[1] = repid
			ExMsgBody[2] = except
			return UserExTypes, ExMsgBody
		elseif not SystemExceptions[repid] then                                   --[[VERBOSE]] verbose:listen("got unexpected exception ",except)
			except = OiLEx2SysEx[except.error] or unknownex(except)                 --[[VERBOSE]] else verbose:listen("got system exception ",except)
		end
	else
		except = unknownex(except)
	end
	self.reply_status = "SYSTEM_EXCEPTION"
	ExMsgBody[1] = except._repid
	ExMsgBody[2] = except
	return SysExTypes, ExMsgBody
end

function ServerRequest:setreply(success, ...)
	local channel = self.channel
	if channel ~= nil then                                                      --[[VERBOSE]] verbose:listen("set reply for request ",self.request_id," to ",self.objectkey,":",self.operation)
		Request.setreply(self, success, ...)
		local success, except = channel:sendreply(self)
		if not success and except.error ~= "terminated" and stderr then           --[[VERBOSE]] verbose:listen("error sending reply for request ",self.request_id," to ",self.objectkey,":",self.operation)
			stderr:write(tostring(except), "\n")
		end                                                                       --[[VERBOSE]] else verbose:listen("ignoring reply for cancelled request ",self.request_id," to ",self.objectkey,":",self.operation)
	end
end



local GIOPListener = class({
	Request = ServerRequest,
	Channel = GIOPChannel,
}, Listener)

function GIOPListener:addbidircontext(servctxt)
	local encoder = self.serviceencoder
	if encoder ~= nil then
		local address = self:getaddress("probe")
		if address ~= nil then
			if servctxt == nil then servctxt = {} end
			encoder:encodebidir(servctxt, address)
			return servctxt
		end
	end
end

function GIOPListener:addbidirchannel(channel)                                --[[VERBOSE]] verbose:listen("add bidirectional channel as incoming request channel")
	channel.context = self
	local socket = channel.socket
	self.sock2channel[socket] = channel
	self.access:add(socket, true)
end

return GIOPListener
