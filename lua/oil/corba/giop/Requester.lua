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
-- Title  : Client-side CORBA GIOP Protocol                                   --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--   See chapter 15 of CORBA 3.0 specification.                               --
--------------------------------------------------------------------------------
-- requests:Facet
-- 	channel:object getchannel(reference:table)
-- 	reply:object, [except:table], [requests:table] newrequest(channel:object, reference:table, operation:table, args...)
-- 	reply:object, [except:table], [requests:table] getreply(channel:object, [probe:boolean])
-- 
-- channels:HashReceptacle
-- 	channel:object retieve(configs:table)
-- 
-- profiler:HashReceptacle
-- 	info:table decode(stream:string)
-- 
-- mutex:Receptacle
-- 	locksend(channel:object)
-- 	freesend(channel:object)
--------------------------------------------------------------------------------

local ipairs   = ipairs
local newproxy = newproxy
local pairs    = pairs
local type     = type
local unpack   = unpack

local oo        = require "oil.oo"
local bit       = require "oil.bit"
local giop      = require "oil.corba.giop"
local Exception = require "oil.corba.giop.Exception"
local Messenger = require "oil.corba.giop.Messenger"                            --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.corba.giop.Requester"

oo.class(_M, Messenger)

context = false

--------------------------------------------------------------------------------

local IOR                = giop.IOR
local RequestID          = giop.RequestID
local ReplyID            = giop.ReplyID
local LocateRequestID    = giop.LocateRequestID
local LocateReplyID      = giop.LocateReplyID
local CloseConnectionID  = giop.CloseConnectionID
local MessageErrorID     = giop.MessageErrorID
local MessageType        = giop.MessageType
local SystemExceptionIDL = giop.SystemExceptionIDL

local Empty = {}

local ChannelKey = newproxy()

--------------------------------------------------------------------------------
-- request id management for channels

local function register(channel, request)
	local id = #channel + 1
	request.channel = channel
	channel[id] = request
	return id
end

local function unregister(channel, id)
	local request = channel[id]
	if request then
		request.channel = nil
		channel[id] = nil
		return request
	end
end

local function contents(self)
	return self.success, unpack(self, 1, self.resultcount)
end


--------------------------------------------------------------------------------

function getchannel(self, reference)                                            --[[VERBOSE]] verbose:invoke(true, "get communication channel")
	local channel, except = reference[ChannelKey]
	if not channel then
		for _, profile in ipairs(reference.profiles) do                             --[[VERBOSE]] verbose:invoke("[IOR profile with tag ",profile.tag,"]")
			local tag = profile.tag
			local context = self.context
			local channels = context.channels[tag]
			local profiler = context.profiler[tag]
			if channels and profiler then
				profiler, except = profiler:decode(profile.profile_data)
				if profiler then
					reference._object = except
					channel, except = channels:retrieve(profiler)
					if channel then
						reference[ChannelKey] = channel
					elseif except == "connection refused" then
						except = Exception{ "COMM_FAILURE", minor_code_value = 1,
							reason = "connect",
							message = "connection to profile refused",
							profile = profiler,
						}
					elseif except == "too many open connections" then
						except = Exception{ "NO_RESOURCES", minor_code_value = 0,
							reason = "resources",
							message = "too many open connections by protocol",
							protocol = tag,
						}
					end
				end
				break
	 		end
		end
		if not channel and not except then
		 	except = Exception{ "IMP_LIMIT", minor_code_value = 1,
				message = "no supported GIOP profile found",
				reason = "profiles",
			}
		end
	end                                                                           --[[VERBOSE]] verbose:invoke(false)
	return channel, except
end

--------------------------------------------------------------------------------

local OneWayRequest = {
	service_context      = Empty,
	request_id           = 0, -- value not used
	response_expected    = false,
	object_key           = nil, -- defined later
	operation            = nil, -- defined later
	requesting_principal = Empty,
	resultcount          = 0,
	success              = true,
	contents             = contents,
}

function sendrequest(self, reference, operation, ...)
	local result, except = self:getchannel(reference)
	if result then
		local channel = result
		if operation.oneway then
			result = OneWayRequest
		else
			result = {
				response_expected    = true,
				service_context      = Empty,
				requesting_principal = Empty,
				inputs               = operation.inputs,
				...,
			}
			result.request_id = register(channel, result)
		end                                                                         --[[VERBOSE]] verbose:invoke(true, "request ",result.request_id," for operation '",operation.name,"'")
		result.object_key = reference._object
		result.operation  = operation.name
		result.opidl      = operation
		local success, except = self:sendmsg(channel,
		                             RequestID, result,
		                             operation.inputs, ...)
		if not success then
			unregister(channel, result)
			result = nil
		end
	end                                                                           --[[VERBOSE]] verbose:invoke(false)
	return result, except
end

function newrequest(self, reference, operation, ...)
	local requester = self.OperationRequester[operation.name] or self.sendrequest
	return requester(self, reference, operation, ...)
end

--------------------------------------------------------------------------------

function reissue(self, channel, request)                                        --[[VERBOSE]] verbose:invoke(true, "reissue request for operation '",request.operation,"'")
	local success, except = self:sendmsg(channel, RequestID,
	                                     request, request.inputs,
	                                     unpack(request, 1,
	                                            #request.inputs))                 --[[VERBOSE]] verbose:invoke(false)
	return success, except
end

local SystemExceptionReason = {
	["IDL:omg.org/CORBA/COMM_FAILURE:1.0"    ] = "closed",
	["IDL:omg.org/CORBA/MARSHAL:1.0"         ] = "marshal",
	["IDL:omg.org/CORBA/NO_IMPLEMENT:1.0"    ] = "noimplement",
	["IDL:omg.org/CORBA/BAD_OPERATION:1.0"   ] = "badoperation",
	["IDL:omg.org/CORBA/OBJECT_NOT_EXIST:1.0"] = "badkey",
}

function getreply(self, request, probe)                                         --[[VERBOSE]] verbose:invoke(true, "get a reply from communication channel")
	local success, except = true, nil
	if request.contents == nil then
		local channel = request.channel
		if channel:trylock("read", not probe, request) then
			local replied
			while success and (replied~=request) and (not probe or channel:probe()) do
				local msgid, header, decoder = self:receivemsg(channel)
				if msgid == ReplyID then
					replied = unregister(channel, header.request_id)
					if replied then
						local status = header.reply_status
						if status == "LOCATION_FORWARD" then                                --[[VERBOSE]] verbose:invoke("forwarding request ",header.request_id," through other channel")
							success, except = self:getchannel(decoder:struct(IOR))
							if success then
								replied.request_id = register(channel, replied)
								success, except = self:reissue(channel, replied)
							end
							if success then
								replied = nil
							else
								replied.contents = contents
								replied.success = false
								replied.resultcount = 1
								replied[1] = except
								success, except = true, nil
							end
						else -- status ~= LOCATION_FORWARD
							local operation = replied.opidl
							replied.contents = contents
							if status == "NO_EXCEPTION" then                                  --[[VERBOSE]] verbose:invoke("got successful reply for request ",header.request_id)
								replied.success = true
								replied.resultcount = #operation.outputs
								for index, output in ipairs(operation.outputs) do
									replied[index] = decoder:get(output)
								end
							else -- status ~= "NO_EXCEPTION"
								replied.success = false
								replied.resultcount = 1
								if status == "USER_EXCEPTION" then                              --[[VERBOSE]] verbose:invoke("got reply with exception for ",header.request_id)
									local repId = decoder:string()
									local exception = operation.exceptions[repId]
									if exception then
										exception = Exception(decoder:except(exception))
										exception[1] = repId
										replied[1] = exception
									else
										replied[1] = Exception{ "UNKNOWN", minor_code_value = 0,
											message = "unexpected user-defined exception",
											reason = "exception",
											exception = exception,
										}
									end
								elseif status == "SYSTEM_EXCEPTION" then                        --[[VERBOSE]] verbose:invoke("got reply with system exception for ",header.request_id)
									-- TODO:[maia] set its type to the proper SystemExcep.
									local exception = decoder:struct(SystemExceptionIDL)
									exception[1] = exception.exception_id
									exception.reason = SystemExceptionReason[ exception[1] ]
									replied[1] = Exception(exception)
								else -- status == ???
									replied[1] = Exception{ "INTERNAL", minor_code_value = 0,
										message = "unsupported reply status",
										reason = "replystatus",
										status = status,
									}
								end --[[ of if status == "USER_EXCEPTION"]]
							end -- of if status == "NO_EXCEPTION"
						end -- of if status == "LOCATION_FORWARD"
						if replied then
							local replier = self.OperationReplier[replied.operation]
							if replier then
								success, except = replier(self, replied)
							end
							channel:signal(replied)
						end
					else -- replied == nil
						success, except = nil, Exception{ "INTERNAL", minor_code_value = 0,
							message = "unexpected request id",
							reason = "requestid",
							id = header.request_id,
						}
					end
				elseif (msgid == CloseConnectionID) or
				       (msgid == nil and header.reason == "closed") then                --[[VERBOSE]] verbose:invoke("got remote request to close channel or channel is broken")
					success, except = channel:reset()
					if success then                                                       --[[VERBOSE]] verbose:invoke(true, "reissue all pending requests")
						-- reissue pending all requests
						for id, pending in pairs(channel) do
							if type(id) == "number" then
								success, except = self:reissue(channel, pending)
								if not success then
									unregister(channel, id)
									pending.contents = contents
									pending.success = false
									pending.resultcount = 1
									pending[1] = except
									if pending == request then
										replied = pending
									else
										channel:signal(pending)
									end
								end
							end
						end                                                                 --[[VERBOSE]] verbose:invoke(false)
						success, except = true, nil
					elseif except == "connection refused" then
						except = Exception{ "COMM_FAILURE", minor_code_value = 1,
							reason = "connect",
							message = "unable to restablish channel",
							channel = channel,
						}
					elseif except == "too many open connections" then
						except = Exception{ "NO_RESOURCES", minor_code_value = 0,
							reason = "resources",
							message = "unbale to restablish channel, too many open connections",
							channel = channel,
						}
					end
				elseif msgid == MessageErrorID then
					success, except = nil, Exception{ "COMM_FAILURE", minor_code_value = 0,
						reason = "server",
						message = "error in server message processing",
					}
				elseif MessageType[msgid] then
					success, except = nil, Exception{ "INTERNAL", minor_code_value = 0,
						reason = "unexpected",
						message = "unexpected GIOP message",
						message = MessageType[msgid],
						id = msgid,
					}
				elseif header.reason == "version" then                                  --[[VERBOSE]] verbose:invoke("got message with wrong version, send message error notification")
					success, except = self:sendmsg(channel, MessageErrorID)
				else -- not msgid and header.reason ~= ["version"|"closed"]
					success, except = nil, header
				end
			end -- of while should continue receiving messages
			channel:freelock("read")
		end -- of if mutex:lockreceive(channel, request)
	end --[[of if request.contents == nil]]                                        --[[VERBOSE]] verbose:invoke(false)
	return success, except
end

--------------------------------------------------------------------------------

OperationRequester = {}
OperationReplier = {}

local ReplyTrue  = {
	contents = contents,
	success = true,
	resultcount = 1,
	[1] = true,
}
local ReplyFalse = {
	contents = contents,
	success = true,
	resultcount = 1,
	[1] = false,
}

function OperationRequester:_is_equivalent(reference, _, otherref)
	otherref = otherref.__reference
	if otherref then
		local tags = {}
		for _, profile in ipairs(otherref.profiles) do
			tags[profile.tag] = profile
		end
		local context = self.context
		for _, profile in ipairs(reference.profiles) do
			local tag = profile.tag
			local other = tags[tag]
			if other then
				local profiler = context.profiler[tag]
				if
					profiler and
					profiler:equivalent(profile.profile_data, other.profile_data)
				then
					return ReplyTrue
				end
			end
		end
	end
	return ReplyFalse
end

local _non_existent = giop.ObjectOperations._non_existent
function OperationRequester:_non_existent(reference)
	local result, except = self:sendrequest(reference, _non_existent)
	if not result and (except.reason=="connect" or except.reason=="closed") then
		result = ReplyFalse
	end
	return result, except
end
function OperationReplier:_non_existent(request)
	local success, except = request.success, request[1]
	if not success
	and ( except.exception_id == "IDL:omg.org/CORBA/OBJECT_NOT_EXIST:1.0" or
		    except.reason == "closed" )
	then
		request.success = true
		request.resultcount = 1
		request[1] = true
	end
	return true
end
