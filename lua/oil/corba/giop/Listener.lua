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
-- 	success:boolean, [except:table] freeachannel(channel:object)
-- 	request:object, [except:table], [requests:table] = getrequest(channel:object, [probe:boolean])
-- 
-- channels:HashReceptacle
-- 	channel:object retieve(configs:table)
-- 	channel:object dispose(configs:table)
-- 	configs:table default([configs:table])
-- 
-- messenger:Receptacle
-- 	success:boolean, [except:table] sendmsg(channel:object, type:number, header:table, idltypes:table, values...)
-- 	type:number, [header:table|except:table], [decoder:object] receivemsg(channel:object)
-- 
-- mapper:Receptacle
-- 	interface:table typeof(objectkey:string)
-- 
-- indexer:Receptacle
-- 	member:table valueof(interface:table, name:string)
--------------------------------------------------------------------------------

local ipairs = ipairs
local pairs  = pairs
local select = select
local type   = type
local unpack = unpack

local table = require "table"

local oo        = require "oil.oo"
local bit       = require "oil.bit"
local idl       = require "oil.corba.idl"
local giop      = require "oil.corba.giop"
local Exception = require "oil.corba.giop.Exception"                            --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.corba.giop.Listener", oo.class)

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

function default(self, configs)
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

--------------------------------------------------------------------------------

function getchannel(self, configs, probe)                                       --[[VERBOSE]] verbose:listen(true, "get channel with config ",configs)
	local result, except = self.context.channels[configs.tag or 0]
	if result then
		result, except = result:retrieve(configs, probe)
	else
		except = Exception{ "IMP_LIMIT", minor_code_value = 1,
			message = "no supported GIOP profile found for configuration",
			reason = "protocol",
			configuration = configs,
		}
	end                                                                           --[[VERBOSE]] verbose:listen(false)
	return result, except
end

--------------------------------------------------------------------------------

function freeaccess(self, configs)                                         --[[VERBOSE]] verbose:listen(true, "closing all channels with configs ",configs)
	local channels = self.context.channels[configs.tag or 0]
	local result, except = channels:dispose(configs)
	if result then
		local messenger = self.context.messenger
		for _, channel in ipairs(result) do
			result, except = messenger:sendmsg(channel, CloseConnectionID)
			if not result and except.reason ~= "closed" then
				break
			end
		end
	end                                                                           --[[VERBOSE]] verbose:listen(false)
	return result, except
end

--------------------------------------------------------------------------------

function freeachannel(self, channel)                                          --[[VERBOSE]] verbose:listen "close channel"
	if table.maxn(channel) > 0 then
		channel.invalid = true
		return true
	else
		return self.context.messenger:sendmsg(channel, CloseConnectionID)
	end
end

--------------------------------------------------------------------------------

local SysExReply = {
	service_context = Empty,
	request_id      = nil, -- defined later
	reply_status    = "SYSTEM_EXCEPTION",
}

local SysExType = { giop.SystemExceptionIDL }

function sysexreply(self, requestid, body)                                      --[[VERBOSE]] verbose:listen("new system exception ",body.exception_id," for request ",requestid)
	SysExReply.request_id = requestid
	return ReplyID, SysExReply, SysExType, body
end

--------------------------------------------------------------------------------

local Request = oo.class()

function Request:params()
	return unpack(self, 1, #self.member.inputs)
end

--------------------------------------------------------------------------------

function bypass(self, channel, request, ...)
	local result, except = true
	request.bypassed = true
	if request.response_expected ~= false then
		local context = self.context
		result, except = context.messenger:sendmsg(channel, ...)
	end
	return result, except
end

--------------------------------------------------------------------------------

function getrequest(self, channel, probe)                                       --[[VERBOSE]] verbose:listen(true, "get request from channel")
	local context = self.context
	local result, except = true, nil
	if channel:trylock("read", not probe) then
		if not probe or channel:probe() then
			local msgid, header, decoder = context.messenger:receivemsg(channel)
			if msgid == RequestID then
				local requestid = header.request_id
				if not channel[requestid] then
					local iface = context.mapper:typeof(header.object_key)
					if iface then
						local member, opimpl = context.indexer:valueof(iface, header.operation)
						if member then                                                          --[[VERBOSE]] verbose:listen("got request ",requestid," for ",header.operation)
							for index, input in ipairs(member.inputs) do
								header[index] = decoder:get(input)
							end
							header.member = member
							header.opimpl = opimpl
							if header.response_expected then
								channel[requestid] = header                                         --[[VERBOSE]] else verbose:listen "no response expected"
							end
							header.channel = channel
							result = Request(header)
						else                                                                    --[[VERBOSE]] verbose:listen("got illegal operation ",header.operation)
							result, except = self:bypass(channel, header,
								self:sysexreply(requestid, {
									exception_id = "IDL:omg.org/CORBA/BAD_OPERATION:1.0",
									minor_code_value  = 1, -- TODO:[maia] Which value?
									completion_status = COMPLETED_NO,
								}))
						end
					else                                                                      --[[VERBOSE]] verbose:listen("got illegal object ",header.object_key)
						result, except = self:bypass(channel, header,
							self:sysexreply(requestid, {
								exception_id = "IDL:omg.org/CORBA/OBJECT_NOT_EXIST:1.0",
								minor_code_value  = 1, -- TODO:[maia] Which value?
								completion_status = COMPLETED_NO,
							}))
					end
				else                                                                        --[[VERBOSE]] verbose:listen("got replicated request id ",requestid)
					result, except = self:bypass(channel, header,
						self:sysexreply(requestid, {
							exception_id = "IDL:omg.org/CORBA/INTERNAL:1.0",
							minor_code_value = 0, -- TODO:[maia] Which value?
							completion_status = COMPLETED_NO,
						}))
				end
			elseif msgid == CancelRequestID then                                          --[[VERBOSE]] verbose:listen("got cancelling of request ",header.request_id)
				channel[header.request_id] = nil
				header.bypassed = true
				result = true
			elseif msgid == LocateRequestID then                                          --[[VERBOSE]] verbose:listen("got locate request ",header.request_id)
				local reply = { request_id = header.request_id }
				if context.mapper:typeof(header.object_key)
					then reply.locate_status = "OBJECT_HERE"
					else reply.locate_status = "UNKNOWN_OBJECT"
				end
				result, except = self:bypass(channel, header, LocateReplyID, reply)
			elseif result == MessageErrorID then                                           --[[VERBOSE]] verbose:listen "got message error notification"
				result, except = self:bypass(channel, header, CloseConnectionID)
			elseif MessageType[msgid] then                                                --[[VERBOSE]] verbose:listen("got unknown message ",msgid,", sending message error notification")
				result, except = self:bypass(channel, header, MessageErrorID)
			else
				result, except = nil, header
			end
		
			if result then
				if header.bypassed then                                                     --[[VERBOSE]] verbose:listen(false, "reissuing request read")
					return self:getrequest(channel, probe)
				end
			elseif except.reason == "closed" then                                         --[[VERBOSE]] verbose:listen("client closed the connection")
				result, except = true, nil
			end
		end
		channel:freelock("read")
	end                                                                           --[[VERBOSE]] verbose:listen(false)
	
	return result, except
end

--------------------------------------------------------------------------------

local ExceptionReplyTypes = { idl.string }

function sendreply(self, request, success, ...)                        --[[VERBOSE]] verbose:listen(true, "got reply for request ",request.request_id)
	local except
	local channel = request.channel
	local requestid = request.request_id
	local messenger = self.context.messenger
	if channel[requestid] == request then
		local member = request.member
		if success then                                                             --[[VERBOSE]] verbose:listen "got successful results"
			request.service_context = Empty
			request.reply_status = "NO_EXCEPTION"
			success, except = messenger:sendmsg(channel, ReplyID, request,
			                                    member.outputs, ...)
		else
			except = ...
			if type(except) == "table" then                                           --[[VERBOSE]] verbose:listen("got exception ",except)
				local excepttype = member.exceptions[ except[1] ]
				if excepttype then
					ExceptionReplyTypes[2] = excepttype
					request.service_context = Empty
					request.reply_status = "USER_EXCEPTION"
					success, except = messenger:sendmsg(channel, ReplyID, request,
					                                    ExceptionReplyTypes,
					                                    except[1], except)
				else
					if SystemExceptions[ except[1] ] then                                 --[[VERBOSE]] verbose:listen("got system exception ",except)
						except.exception_id = except[1]
					elseif except.reason == "badkey" then
						except.exception_id = "IDL:omg.org/CORBA/OBJECT_NOT_EXIST:1.0"
						except.minor_code_value  = 1
						except.completion_status = COMPLETED_NO
					elseif except.reason == "noimplement" then
						except.exception_id = "IDL:omg.org/CORBA/NO_IMPLEMENT:1.0"
						except.minor_code_value  = 1
						except.completion_status = COMPLETED_NO
					elseif except.reason == "badoperation" then
						except.exception_id = "IDL:omg.org/CORBA/BAD_OPERATION:1.0"
						except.minor_code_value  = 1
						except.completion_status = COMPLETED_NO
					else                                                                  --[[VERBOSE]] verbose:listen("got unexpected exception ",except)
						except.exception_id = "IDL:omg.org/CORBA/UNKNOWN:1.0"
						except.minor_code_value  = 0
						except.completion_status = COMPLETED_MAYBE
					end
					success, except = messenger:sendmsg(channel,
						self:sysexreply(requestid, except))
				end
			elseif type(except) == "string" then                                      --[[VERBOSE]] verbose:listen("got unexpected error ", except)
				success, except = messenger:sendmsg(channel,
					self:sysexreply(requestid, {
						exception_id = "IDL:omg.org/CORBA/UNKNOWN:1.0",
						minor_code_value = 0,
						completion_status = COMPLETED_MAYBE,
						message = "servant error: "..except,
						reason = "servant",
						operation = operation,
						servant = servant,
						error = except,
					}))
			else                                                                      --[[VERBOSE]] verbose:listen("got illegal exception ", except)
				success, except = messenger:sendmsg(channel,
					self:sysexreply(requestid, {
						exception_id = "IDL:omg.org/CORBA/UNKNOWN:1.0",
						minor_code_value = 0,
						completion_status = COMPLETED_MAYBE,
						message = "invalid exception, got "..type(except),
						reason = "exception",
						exception = except,
					}))
			end
		end
		if success then
			channel[requestid] = nil
			if channel.invalid and table.maxn(channel) == 0 then                      --[[VERBOSE]] verbose:listen "all pending requests replied, connection being closed"
				success, except = messenger:sendmsg(channel, CloseConnectionID)
			end
		elseif SystemExceptions[ except[1] ] then                                   --[[VERBOSE]] verbose:listen("got system exception ",except," at reply send")
			except.exception_id = except[1]
			except.completion_status = COMPLETED_YES
			success, except = messenger:sendmsg(channel,
				self:sysexreply(requestid, except))
		end
	else
		success = true
	end                                                                           --[[VERBOSE]] verbose:listen(false)
	if not success and except.reason ~= "closed" then
		success, except = true, nil
	end
	return success, except
end
