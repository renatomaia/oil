--------------------------------------------------------------------------------
------------------------------  #####      ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------ ##   ## ##  ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------  #####  ### ###### ------------------------------
--------------------------------                --------------------------------
----------------------- An Object Request Broker in Lua ------------------------
--------------------------------------------------------------------------------
-- Project: OiL - ORB in Lua                                                  --
-- Release: 0.4                                                               --
-- Title  : Server-side CORBA GIOP Protocol                                   --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--   See chapter 15 of CORBA 3.0 specification.                               --
--------------------------------------------------------------------------------
-- listener:Facet
-- 	configs:table default([configs:table])
-- 	channel:object, [except:table] getchannel(configs:table)
-- 	success:boolean, [except:table] freeaccess(configs:table)
-- 	success:boolean, [except:table] freechannel(channel:object)
-- 	request:object, [except:table], [requests:table] = getrequest(channel:object, [probe:boolean])
-- 
-- channels:HashReceptacle
-- 	channel:object retieve(configs:table)
-- 	channel:object dispose(configs:table)
-- 	configs:table default([configs:table])
-- 
-- mapper:Receptacle
-- 	interface:table typeof(objectkey:string)
-- 
-- indexer:Receptacle
-- 	member:table valueof(interface:table, name:string)
--------------------------------------------------------------------------------

local assert   = assert
local ipairs   = ipairs
local pairs    = pairs
local select   = select
local type     = type
local unpack   = unpack
local stderr   = io and io.stderr

local table = require "table"

local oo        = require "oil.oo"
local bit       = require "oil.bit"
local idl       = require "oil.corba.idl"
local giop      = require "oil.corba.giop"
local Exception = require "oil.corba.giop.Exception"
local Messenger = require "oil.corba.giop.Messenger"                            --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.corba.giop.Listener"

oo.class(_M, Messenger)

context = false

--------------------------------------------------------------------------------

local RequestID          = giop.RequestID
local ReplyID            = giop.ReplyID
local LocateRequestID    = giop.LocateRequestID
local LocateReplyID      = giop.LocateReplyID
local CancelRequestID    = giop.CancelRequestID
local CloseConnectionID  = giop.CloseConnectionID
local MessageErrorID     = giop.MessageErrorID
local MessageType        = giop.MessageType
local SystemExceptionIDs = giop.SystemExceptionIDs

local COMPLETED_YES   = 0
local COMPLETED_NO    = 1
local COMPLETED_MAYBE = 2

local Empty = {}

local SystemExceptions = {}

for _, repID in pairs(SystemExceptionIDs) do
	SystemExceptions[repID] = true
end

--------------------------------------------------------------------------------

function setupaccess(self, configs)
	local channels = self.context.channels[configs and configs.tag or 0]
	if channels then
		return channels:default(configs)
	else
		return nil, Exception{ "IMP_LIMIT", minor_code_value = 1,
			message = "no supported GIOP profile found for configuration",
			reason = "protocol",
			configuration = configs,
		}
	end
end

function freeaccess(self, accesspoint)                                          --[[VERBOSE]] verbose:listen(true, "closing all channels with accesspoint ",accesspoint)
	local channels = self.context.channels[accesspoint.tag or 0]
	local result, except = channels:dispose(accesspoint)
	if result then
		for _, channel in ipairs(result) do
			result, except = self:sendmsg(channel, CloseConnectionID)
			if not result and except.reason ~= "closed" then
				break
			end
		end
	end                                                                           --[[VERBOSE]] verbose:listen(false)
	return result, except
end

--------------------------------------------------------------------------------

function getchannel(self, accesspoint, probe)                                   --[[VERBOSE]] verbose:listen(true, "get channel from accesspoint ",accesspoint)
	local result, except = self.context.channels[accesspoint.tag or 0]
	if result then
		result, except = result:retrieve(accesspoint, probe)
	else
		except = Exception{ "IMP_LIMIT", minor_code_value = 1,
			message = "no supported GIOP profile found for accesspoint",
			reason = "protocol",
			accesspoint = accesspoint,
		}
	end                                                                           --[[VERBOSE]] verbose:listen(false)
	return result, except
end

function putchannel(self, channel)                                              --[[VERBOSE]] verbose:listen "put channel back"
	return channel:release()
end

function freechannel(self, channel)                                             --[[VERBOSE]] verbose:listen "close channel"
	if table.maxn(channel) > 0 then
		channel.freed = true
		return true
	else
		return self:sendmsg(channel, CloseConnectionID)
	end
end

--------------------------------------------------------------------------------

local SysExReply = {
	service_context = Empty,
	request_id      = nil, -- defined later
	reply_status    = "SYSTEM_EXCEPTION",
}
local SysExType = { giop.SystemExceptionIDL }
local SysExBody = { n = 1, --[[defined later]] }

function sysexreply(self, requestid, body)                                      --[[VERBOSE]] verbose:listen("new system exception ",body.exception_id," for request ",requestid)
	SysExReply.request_id = requestid
	SysExBody[1] = body
	body.exception_id = body[1]
	return SysExReply, SysExType, SysExBody
end

--------------------------------------------------------------------------------

local Request = oo.class()

function Request:params()
	return unpack(self, 1, #self.inputs)
end

--------------------------------------------------------------------------------

function handlerequest(self, channel, header, decoder)
	local context = self.context
	local requestid = header.request_id
	if not channel[requestid] then
		header.objectkey = header.object_key
		local target, iface = context.servants:retrieve(header.object_key)
		if target then
			header.target = target
			header.interface = iface
			local member = context.indexer:valueof(iface, header.operation)
			if member then                                                            --[[VERBOSE]] verbose:listen("got request ",requestid," for ",header.operation)
				header.member = member
				header.n = #member.inputs
				header.inputs = member.inputs
				header.outputs = member.outputs
				header.exceptions = member.exceptions
				for index, input in ipairs(member.inputs) do
					local ok, result = self.pcall(decoder.get, decoder, input)
					if not ok then
						assert(type(result) == "table", result)
						header.success = false
						header.n = 1
						header[1] = result
						break
					end
					header[index] = result
				end
			else                                                                      --[[VERBOSE]] verbose:listen("got illegal operation ",header.operation)
				header.success = false
				header.n = 1
				header[1] = Exception{
					reason = "badoperation",
					message = "servant with object_key does not decare operation",
					object_key = header.object_key,
					operation = header.operation,
				}
			end
		else                                                                        --[[VERBOSE]] verbose:listen("got illegal object ",header.object_key)
			header.success = false
			header.n = 1
			header[1] = Exception{
				reason = "badkey",
				message = "no servant found with object_key",
				object_key = header.object_key,
			}
		end
	else                                                                          --[[VERBOSE]] verbose:listen("got replicated request id ",requestid)
		header.success = false
		header.n = 1
		header[1] = Exception{
			reason = "badrequestid",
			message = "provided request_id is already in use by a pending request",
			request_id = header.request_id,
		}
	end
	if header.response_expected then
		header.channel = channel
		channel[requestid] = header                                                 --[[VERBOSE]] else verbose:listen "no response expected"
	end
end

function getrequest(self, channel, probe)                                       --[[VERBOSE]] verbose:listen(true, "get request from channel")
	local context = self.context
	local result, except = true, nil
	if channel:trylock("read", not probe) then
		if not probe or channel:probe() then
			local bypassed = false
			
			local msgid, header, decoder = self:receivemsg(channel)
			if msgid == RequestID then
				self:handlerequest(channel, header, decoder)
				if header.success ~= nil then
					result, except = self:sendreply(header)
					bypassed = result
				else
					result, except = header, nil
				end
			elseif msgid == CancelRequestID then                                      --[[VERBOSE]] verbose:listen("got cancelling of request ",header.request_id)
				channel[header.request_id] = nil
				result, except = true, nil
				bypassed = true
			elseif msgid == LocateRequestID then                                      --[[VERBOSE]] verbose:listen("got locate request ",header.request_id)
				local reply = { request_id = header.request_id }
				if context.servants:retrieve(header.object_key)
					then reply.locate_status = "OBJECT_HERE"
					else reply.locate_status = "UNKNOWN_OBJECT"
				end
				reply[1] = reply
				result, except = self:sendmsg(channel, LocateReplyID, reply)
				bypassed = result
			elseif result == MessageErrorID then                                      --[[VERBOSE]] verbose:listen "got message error notification"
				result, except = self:sendmsg(channel, CloseConnectionID)
				bypassed = result
			elseif MessageType[msgid] then                                            --[[VERBOSE]] verbose:listen("got unknown message ",msgid,", sending message error notification")
				result, except = self:sendmsg(channel, MessageErrorID)
				bypassed = result
			else
				result, except = nil, header
			end
			
			if bypassed then                                                          --[[VERBOSE]] verbose:listen(false, "reissuing request read")
				return self:getrequest(channel, probe)
			elseif not result and except.reason == "closed" then                      --[[VERBOSE]] verbose:listen("client closed the connection")
				result, except = true, nil
			end
		end
		channel:freelock("read")
	end                                                                           --[[VERBOSE]] verbose:listen(false)
	return result, except
end

--------------------------------------------------------------------------------

local ExceptionReplyTypes = { idl.string }
local ExceptionReplyBody = { n = 2, --[[defined later]] }

function handlereply(self, request)
	if request.success then                                                       --[[VERBOSE]] verbose:listen "got successful results"
		request.service_context = Empty
		request.reply_status = "NO_EXCEPTION"
		return request, request.outputs, request
	else
		local requestid = request.request_id
		local except = request[1]
		local extype = type(except)
		if extype == "table" then                                                   --[[VERBOSE]] verbose:listen("got exception ",except)
			local excepttype = request.exceptions
			excepttype = excepttype and excepttype[ except[1] ]
			if excepttype then
				request.service_context = Empty
				request.reply_status = "USER_EXCEPTION"
				ExceptionReplyTypes[2] = excepttype
				ExceptionReplyBody[1] = except[1]
				ExceptionReplyBody[2] = except
				return request, ExceptionReplyTypes, ExceptionReplyBody
			else
				if except.reason == "badkey" then
					except[1] = "IDL:omg.org/CORBA/OBJECT_NOT_EXIST:1.0"
					except.minor_code_value  = 1
					except.completion_status = COMPLETED_NO
				elseif except.reason == "noimplement" then
					except[1] = "IDL:omg.org/CORBA/NO_IMPLEMENT:1.0"
					except.minor_code_value  = 1
					except.completion_status = COMPLETED_NO
				elseif except.reason == "badoperation" then
					except[1] = "IDL:omg.org/CORBA/BAD_OPERATION:1.0"
					except.minor_code_value  = 1
					except.completion_status = COMPLETED_NO
				elseif except.reason == "badrequestid" then
					except[1] = "IDL:omg.org/CORBA/INTERNAL:1.0"
					except.minor_code_value  = 1
					except.completion_status = COMPLETED_NO
				elseif not SystemExceptions[ except[1] ] then                           --[[VERBOSE]] verbose:listen("got unexpected exception ",except)
					except[1] = "IDL:omg.org/CORBA/UNKNOWN:1.0"
					except.minor_code_value  = 0
					except.completion_status = COMPLETED_MAYBE                            --[[VERBOSE]] else verbose:listen("got system exception ",except)
				end
				return self:sysexreply(requestid, except)
			end
		elseif extype == "string" then                                              --[[VERBOSE]] verbose:listen("got unexpected error ", except)
			if stderr then stderr:write(except, "\n") end
			return self:sysexreply(requestid, {
				"IDL:omg.org/CORBA/UNKNOWN:1.0",
				minor_code_value = 0,
				completion_status = COMPLETED_MAYBE,
				message = "servant error: "..except,
				reason = "servant",
				operation = operation,
				servant = servant,
				error = except,
			})
		else                                                                        --[[VERBOSE]] verbose:listen("got illegal exception ", except)
			return self:sysexreply(requestid, {
				"IDL:omg.org/CORBA/UNKNOWN:1.0",
				minor_code_value = 0,
				completion_status = COMPLETED_MAYBE,
				message = "invalid exception, got "..extype,
				reason = "exception",
				exception = except,
			})
		end
	end
end

function sendreply(self, request)                                               --[[VERBOSE]] verbose:listen(true, "got reply for request ",request.request_id)
	local success, except = true, nil
	local channel = request.channel
	local requestid = request.request_id
	if channel and channel[requestid] == request then
		success, except = self:sendmsg(channel, ReplyID,
		                               self:handlereply(request))
		if success then
			channel[requestid] = nil
			if channel.freed and table.maxn(channel) == 0 then                        --[[VERBOSE]] verbose:listen "all pending requests replied, connection being closed"
				success, except = self:sendmsg(channel, CloseConnectionID)
			end
		elseif SystemExceptions[ except[1] ] then                                   --[[VERBOSE]] verbose:listen("got system exception ",except," at reply send")
			except.completion_status = COMPLETED_YES
			success, except = self:sendmsg(channel, ReplyID,
			                               self:sysexreply(requestid, except))
		end
	else                                                                          --[[VERBOSE]] verbose:listen("no pending request found with id ",requestid,", reply discarted")
		success = true
	end
	if not success and except.reason == "closed" then
		success, except = true, nil
	end                                                                           --[[VERBOSE]] verbose:listen(false, "reply ", success and "successfully sent" or "failed", except)
	return success, except
end
