-- $Id$
--******************************************************************************
-- Copyright 2002 Noemi Rodriquez & Roberto Ierusalimschy. All rights reserved. 
--******************************************************************************

--------------------------------------------------------------------------------
------------------------------  #####      ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------ ##   ## ##  ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------  #####  ### ###### ------------------------------
--------------------------------                --------------------------------
----------------------- An Object Request Broker in Lua ------------------------
--------------------------------------------------------------------------------
-- Project: OiL - ORB in Lua: An Object Request Broker in Lua                 --
-- Release: 0.3 alpha                                                         --
-- Title  : Method invocation implementation                                  --
-- Authors: Renato Maia           <maia@inf.puc-rio.br>                       --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   call(ref, op, arg)  Performs an operation call on a reference            --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--------------------------------------------------------------------------------

local ipairs      = ipairs
local next        = next
local pairs       = pairs
local print       = print
local require     = require
local rawget      = rawget
local rawset      = rawset
local select      = select
local scheduler   = scheduler
local string      = string
local tostring    = tostring
local type        = type
local unpack      = unpack

local table       = require "table"
local oo          = require "oil.oo"

module "oil.corba.Protocol"                                         --[[VERBOSE]] local verbose = require "oil.verbose"                                                     

local Exception          = require "oil.Exception"
local IDL                = require "oil.idl"
local giop               = require "oil.corba.giop"
local OrderedSet      = require "loop.collection.OrderedSet"
local assert          = require "oil.assert"

--------------------------------------------------------------------------------
-- Local module variables 
--------------------------------------------------------------------------------

local Protocols          = giop.Protocols
local RequestID          = giop.RequestID
local ReplyID            = giop.ReplyID
local LocateReplyID      = giop.ReplyID
local CancelRequestID    = giop.CancelRequestID
local LocateRequestID    = giop.LocateRequestID
local MessageErrorID     = giop.MessageErrorID
local MessageType        = giop.MessageType
local SystemExceptionIDL = giop.SystemExceptionIDL

--------------------------------------------------------------------------------
-- GIOP structures for fast access 
--------------------------------------------------------------------------------

local GIOPHeaderSize        = giop.GIOPHeaderSize
local GIOPMagicTag          = giop.GIOPMagicTag
local GIOPHeader_v1_        = giop.GIOPHeader_v1_
local GIOPMessageHeader_v1_ = giop.MessageHeader_v1_
local MessageErrorID        = giop.MessageErrorID

local Empty = {}

--------------------------------------------------------------------------------
-- Exception handling 
--------------------------------------------------------------------------------
-- TODISCUSS: component for error handling?  Answer: see comm.lua
local function handleexception(self, exception, operation, ...)                 --[[VERBOSE]] verbose:invoke("handling exception ", exception[1])
	local handler = self._handlers
	if handler then
		handler = handler[ exception[1] ]
		if handler then
			return handler(self, exception, operation, ...) -- handle exception
		end
	end
	return nil, Exception(exception) -- raise exception
end

local function sendsysex(conn, requestid, body)                                --[[VERBOSE]] verbose:dispatcher(true, "send System Exception ", body[1],  " for request ", requestid)
	SystemExceptionReply.request_id = requestid
	body.exception_id = giop.SystemExceptionIDs[ body[1] ]
	return conn:send(self, ReplyID, SystemExceptionReply,
										{SystemExceptionIDL}, {body})
end

--------------------------------------------------------------------------------
-- Connection implementation
--------------------------------------------------------------------------------

-- protocol IIOP tag
Tag = 0

local Connection = oo.class()

function Connection:__init(socket, codec)
	self.replies = {}
	self.receivers = {}
	self.senders = OrderedSet()
	self.socket = socket
	self.codec = codec
	return oo.rawnew(self)
end

function Connection:close()
	self.socket:close()                                                           --[[VERBOSE]] verbose:close "connection socket closed"
end

function Connection:receive()

	local socket = self.socket
	local header, except = socket:receive(GIOPHeaderSize)         --[[VERBOSE]] verbose:receive(true, "read GIOP header from socket [error: ", except, "]")
	if not header then
		if except == "closed" then self:close() end         
		return nil, Exception{ "COMM_FAILURE", minor_code_value = 0,
			message = "unable to read from socket",
			reason = except,
			socket = socket,
		}                                                                           --[[VERBOSE]] , verbose:receive(false)
	end
	
	-- overwrite header with the structure unmarshalled
	local size, type, buffer
	size, type, header, buffer = unmarshallHeader(self, header)
	
	local stream
	if size then                                                                  --[[VERBOSE]] verbose:receive(false)
		stream, except = socket:receive(size)                                       --[[VERBOSE]] verbose:receive("read GIOP body from socket [error: ", except, "]")
		if not stream then
			if except == "closed" then self:close() end
			return nil, Exception{ "COMM_FAILURE", minor_code_value = 0,
				message = "unable to read from socket",
				reason = except,
				socket = socket,
			}                                                                         
		end
	end
	buffer.data = buffer.data..stream -- for alignment (Giop)
	header = buffer:struct(header)
	return type, header, buffer                                                   
end

function Connection:send(stream)           
	--
	-- Send data stream over the socket
	--
	print("sending stream", self.socket)
	local failures, success, except = 0                                           --[[VERBOSE]] verbose:send(true, "writing message into socket")
	repeat
		success, except = self.socket:send(stream)                                  --[[VERBOSE]] verbose:send("write GIOP message into socket [error: ", except, "]")
		if not success then
			if except == "closed" and self.host and failures < 1 then                 --[[VERBOSE]] verbose:send(true, "attempt to reconnect to ", self.host, ":", self.port)
				failures = failures + 1
				success, except = newsocket(self.host, self.port)
				if success
					then success, self.socket = false, success
					else self:close()
				end                                                                     --[[VERBOSE]] verbose:send(false)
			else
				except = Exception{ "COMM_FAILURE", minor_code_value = 0,
					message = "unable to write into socket",
					reason = except,
					socket = socket,
				}
			end
		end
	until success or except                                                       --[[VERBOSE]] verbose:send(false)
	
	return success, except
end

--------------------------------------------------------------------------------
-- Server connection management
--------------------------------------------------------------------------------

local PortConnection = oo.class({}, Connection)

function PortConnection:__init(socket, codec)
	self.senders = OrderedSet()
	self.socket = socket
	self.codec = codec
	self.pending = {}
	return oo.rawnew(self)
end

function PortConnection:close()
	-- test whether still active
	if self.port.connections:remove(self.socket) then                             --[[VERBOSE]] verbose:close "connection unregistered" verbose:close(true, "send close connection message")
		return self:send(giop.CloseConnectionID)                                         --[[VERBOSE]] , verbose:close(false)
	end
end


--------------------------------------------------------------------------------
-- Client helper functions
--------------------------------------------------------------------------------

function unmarshallHeader(self, stream )
	local header

-- TODO:[nogara] which is the object to send to the decoder?? 
	local buffer = self.codec:newDecoder(stream, false, self)
	
	--
	-- Read GIOP message header
	--
	local header = GIOPHeader_v1_[0] -- use GIOP 1.0 by default
	
	local magic = buffer:array(header[1].type)
	if magic ~= GIOPMagicTag then
		-- TODO:[maia] raise MARSHAL exception with minor code 8
		return nil, Exception{ "MARSHALL", minor_code_value = 8,
			message = "illegal GIOP message, magic number is "..magic,
			reason = "magictag",
			tag = magic,
		}                                                                           
	end
	
	local version = buffer:struct(header[2].type)
	local major, minor = version.major, version.minor
	header = GIOPMessageHeader_v1_[minor]
	if major ~= 1 or not header then
		return nil, Exception{ "INTERNAL", minor_code_value = 0,
			message = "GIOP version not supported, got "..major.."."..minor,
			reason = "version",
			procotol = "GIOP",
			major = major,
			minor = minor,
		}                                                                           
	end
	
	local order
	if minor == 0
		then order = buffer:boolean()
		else assert.error "Oops! Missing code ;-)" -- TODO:[maia] handle flags of GIOP 1.1
	end
	buffer:order(order)
	
	local type = buffer:octet()
	local size = buffer:ulong()

	--
	-- Read GIOP message body
	--
	header = GIOPMessageHeader_v1_[minor][type]
		if header == nil then
		return nil, Exception{ "INTERNAL", minor_code_value = 0,
			message = "GIOP 1."..minor.." message type not supported, got "..type,
			reason = "messageid",
			major = major,
			minor = minor,
			messageid = type,
		}                                                                           
	end

		return size, type, header, buffer
end

--------------------------------------------------------------------------------
-- Client helper functions
--------------------------------------------------------------------------------

local Request = {
	service_context      = Empty,
	request_id           = 0,
	response_expected    = nil, -- defined later
	object_key           = nil, -- defined later
	operation            = nil, -- defined later
	requesting_principal = {},
	-- only GIOP 1.2 and 1.3
	reserved             = "\0\0\0",
}

local function requestid(conn) -- TODO:[maia] avoid overflow. Lua
	local id = conn.newid or 0   --             numbers may not be 
	conn.newid = id + 1          --             problem, but CORBA 
	return id                    --             unsigned long may. 
end

local DefaultGIOPHeader = {
	magic        = GIOPMagicTag,
	GIOP_version = {major=1, minor=0},
	byte_order   = false, -- TODO:[maia] get native endianess
	message_type = 0, -- Request message
	message_size = 0,
}

local function createMessage(self, message, header, bodyidl, ...)
	local minor = 0 -- default GIOP version for sending messages
	
	--
	-- Create GIOP message body
	--
	local headeridl = GIOPMessageHeader_v1_[minor or 0][message]                  -- [[VERBOSE]] verbose:newMsg(message, minor)

	local buffer = self.codec:newEncoder(false, self)
	
	buffer:shift(GIOPHeaderSize) -- alignment accordingly to GIOP header size
	if headeridl then buffer:put(header, headeridl) end
	if bodyidl then
		buffer.orb = orb
		for index, idltype in ipairs(bodyidl) do
			buffer:put(arg[index], idltype)
		end
	end
	
	body = buffer:getdata()                                                       -- [[VERBOSE]] verbose:send()
	
	--
	-- Create GIOP message header
	--
	DefaultGIOPHeader.GIOP_version.minor = minor
	DefaultGIOPHeader.message_size = string.len(body)
	DefaultGIOPHeader.message_type = message
	buffer = self.codec:newEncoder()                                              -- [[VERBOSE]] verbose:newHead(DefaultGIOPHeader, VERBOSE_header, VERBOSE_body)
	buffer:struct(DefaultGIOPHeader, GIOPHeader_v1_[minor])
	header = buffer:getdata()                                                     -- [[VERBOSE]] verbose:send()
	
	body = header..body
	return body

end

--------------------------------------------------------------------------------
-- Reply object implementation
--------------------------------------------------------------------------------

ReplyObject = oo.class{}

--------------------------------------------------------------------------------
-- Client functions
--------------------------------------------------------------------------------

InvokeProtocol = oo.class{}

function InvokeProtocol:sendrequest(reference, operation, ...)
	local params = operation.inputs
	local expected = #params
	if expected > 0 then
		if select("#", ...) < expected then
			return false, "expected "..expected.." arguments, but got "..
										select("#", ...)
		end
	end
	local socket, except = self.channels:create(reference.host, reference.port)
	print("except", except)
	local conn = Connection(socket, self.codec)
	local reply_object
	if conn then
		local request_id = requestid(conn)
		-- reuse the Request object because it is marshalled before any yield
		Request.request_id        = request_id
		Request.object_key        = reference.object_key -- object_key at self._profiles
		Request.operation         = operation.name
		Request.response_expected = not operation.oneway                            --[[VERBOSE]] verbose:invoke(true, "invoke ", operation.name, " [req id: ", Request.request_id, "]")
		
		local stream = createMessage(self, RequestID, Request, params, ... )
		-- synchronization
		--
		-- Test for mutual exclusion on connection access
		--
		if conn.sending then                                                        --[[VERBOSE]] verbose:send(true, "connection already being written, waiting notification")
			conn.senders:enqueue(scheduler:current())                                  
			scheduler.sleep()                                                         --[[VERBOSE]] verbose:send(false, "notification received")
		else                                                                        --[[VERBOSE]] verbose:send "connection free for writing"
			conn.sending = true                                                        
		end                                                                         
		                                                                            
		expected, except = conn:send( stream )                                      
		                                                                            
		--                                                                          
		-- Wake blocked threads                                                     
		--                                                                          
		if conn.senders:empty()                                                     
			then conn.sending = false                                                 --[[VERBOSE]] verbose:send "freeing socket for other threads"
			else scheduler.wake(conn.senders:dequeue())                               --[[VERBOSE]] verbose:send "thread waken for writting into socket"
		end
		
		reply_object = ReplyObject{ result = function() 
			if expected then
				if operation.oneway then                                                  --[[VERBOSE]] verbose:invoke "no response expected"
					return Empty                                                            --[[VERBOSE]] , verbose:invoke(false)
				else
					-- TODO:[maia] add proper support for colaborative multi-threading.
					--             Caution! Avoid any sort of race conditions on the use
					--             of sockets since collaborative multi-threading is used.
					
					local msgtype, header, stream
					
					local replies = conn.replies
					local reply = replies[request_id]
					if reply then                                                           --[[VERBOSE]] verbose:receive "returning stored reply"
						replies[request_id] = nil
						msgtype, header, buffer = unpack(reply)
					else 
						-- message still not received
						repeat                                                                 
						-- conn receive
							msgtype, header, buffer = conn:receive()                                  
							if
								msgtype == nil or
								msgtype == MessageErrorID or
								msgtype == CloseConnectionID
							then                                                                  
								local package = { message, header, buffer, n=3 }
								local routine
								local receivers = conn.receivers
								while next(receivers) do                                             
									request_id, routine = next(receivers)
									replies[request_id] = package
									receivers[request_id] = nil
									scheduler.wake(routine)
								end
								conn:close()                                                         
								break
							end
					
							if header.request_id ~= request_id then                               
								local routine = conn.receivers[header.request_id]
								if routine then                                                    
									scheduler.wake(routine)                                             
									coroutine.yield(msgtype, header, buffer)
								else                                                                 
									replies[header.request_id] = { msgtype, header, buffer, n=3 }
								end
								msgtype, header, buffer = nil, nil, nil
							end
						until msgtype
					end
					
					if msgtype == ReplyID then                                              --[[VERBOSE]] verbose:invoke "got a reply message"
						local status = header.reply_status
						if status == "NO_EXCEPTION" then                                      --[[VERBOSE]] verbose:invoke("successfull invokation, return results")
							expected = { n = table.getn(operation.outputs) }
							for index, output in ipairs(operation.outputs) do
								expected[index] = buffer:get(output)
							end                                                                 --[[VERBOSE]] verbose:invoke(false)
							request_id, reply = next(conn.receivers)
							if reply
								then scheduler:register(reply)                                            
								else conn.receiving = false                                           
							end
							return expected
						elseif status == "USER_EXCEPTION" then                                --[[VERBOSE]] verbose:invoke("got user-defined exception")
							local repId = buffer:string()                                       --[[VERBOSE]] verbose:invoke(false)
							local exception = operation.exceptions[repId]
							if exception then
								except = Exception(buffer:except(exception))
							else
								except = Exception{ "UNKNOWN", minor_code_value = 0,
									message = "unexpected user-defined exception, got "..repId,
									reason = "exception",
									exception = exception,
								}
							end
						elseif status == "SYSTEM_EXCEPTION" then                              --[[VERBOSE]] verbose:invoke(true, "got system exception")
							local exception = buffer:struct(SystemExceptionIDL)                 --[[VERBOSE]] verbose:invoke(false)
							-- TODO:[maia] set its type to the proper SystemExcep.
							exception[1] = exception.exception_id
							except = Exception(exception)
						--TODO:[nogara] fix LOCATION_FORWARD message type
						--elseif status == "LOCATION_FORWARD" then                              --[[VERBOSE]] verbose:invoke "got location forward notice"
						--	return call(buffer:IOR(), operation, ...)
						else
							--TODO:[maia] handle GIOP 1.2 reply status
							except = Exception{ "INTERNAL", minor_code_value = 0,
								message = "unsupported reply status, got "..status,
								reason = "replystatus",
								status = status,
							}
						end
					--TODO:[nogara] find out why there is a call() here
					--elseif msgtype == CloseConnectionID then                                  
					--	conn:close() -- TODO:[maia] only reissue if not reached some timeout
					--	return call(self, operation, ...)
					elseif msgtype == MessageErrorID then                                     
						except = Exception{ "COMM_FAILURE", minor_code_value = 0,
							message = "error in server message processing",
							reason = "server",
						}
					elseif MessageType[msgtype] then                                          
						except = Exception{ "INTERNAL", minor_code_value = 0,
							message = "unexpected GIOP message, got "..MessageType[msgtype],
							reason = "unexpected",
							messageid = msgtype,
						}
					else
						except = header
						conn:close()
					end

			-- TODO: [nogara] check if this should be here or before checking
			-- the return type
			-- wake threads after receiving?        
					request_id, reply = next(conn.receivers)
					if reply
						then scheduler.wake(reply)                                            
						else conn.receiving = false                                           
					end
					
				end --[[ oneway test ]]                                                   
			end -- request sending
		end }
	end -- connection test
	-- TODO:[nogara] see where we will handle the exception 
	-- handleexception(self, except, operation, ...)
	print("reply object", reply_object)
	return true, reply_object
end

--------------------------------------------------------------------------------
-- Server functions
--------------------------------------------------------------------------------

ListenProtocol = oo.class{}

local COMPLETED_YES   = 0
local COMPLETED_NO    = 1
local COMPLETED_MAYBE = 2

local Reply = {
	service_context = Empty,
	request_id      = nil, -- defined later
	reply_status    = "NO_EXCEPTION",
}
local LocateReply = {
	request_id      = nil, -- defined later
	locate_status   = "OBJECT_HERE",
}
local SystemExceptionReply = {
	service_context = Empty,
	request_id      = nil, -- defined later
	reply_status    = "SYSTEM_EXCEPTION",
}

local ObjectOps = giop.ObjectOperations

ResultObject = oo.class{}
function ResultObject:__init(object_key, operation, params)
	self.object_key = object_key
	self.operation = operation
	self.params = params
  return oo.rawnew(self)
end

local ReturnTrue = { true }
function ListenProtocol:getrequest(conn)
	local except
	local msgtype, header, buffer = conn:receive()
	if msgtype == RequestID then
		local requestid = header.request_id                                         --[[VERBOSE]] verbose:dispatcher("got request with ID ", requestid, " for object ", header.object_key )
		if conn.pending[requestid] == nil then
			conn.pending[requestid] = true
			print("request id", requestid)
			local iface = self.objects:lookup(header.object_key)
			if iface then
				local member = iface.members[header.operation] or ObjectOps[header.operation]
				-- get the parameters for the call
				local params = { n = #member.inputs }
				for index, input in ipairs(member.inputs) do
					params[index] = buffer:get(input)
				end

				-- if member.attribute then 
				-- header.response_expected = nil
				-- 	if member.inputs[1] then 
				-- 		header.operation = '_set_' .. member.attribute
				-- 	else
				-- 		header.operation = '_get_' .. member.attribute
				-- 	end
				-- end 
				-- try to call the function
				local resultObject = ResultObject(header.object_key, header.operation, params)
				print( "result object before function", resultObject)
				resultObject.result = function(success, result) 
					print("passei por aqui", requestid)
					print(conn.pending)
					print(conn.pending[requestid])
					print(header.response_expected)
					if conn.pending[requestid] and header.response_expected then
					  print("passei por aqui 2")
						if success then                                                     --[[VERBOSE]] verbose:dispatcher("send reply for request ", requestid)
					    print("passei por aqui 3")
							Reply.request_id = requestid
							Reply.reply_status = "NO_EXCEPTION"
							local stream = createMessage(self, ReplyID, Reply,
							                             member.outputs, unpack(result))
							print("passei por aqui 4")
							_, except = conn:send(stream)                                     --[[VERBOSE]] verbose:dispatcher(false)
							print("passei por aqui 5")
						elseif type(result) == "table" then
							print("la")
							local excepttype = member.exceptions[ result[1] ]
							if excepttype then                                                --[[VERBOSE]] verbose:dispatcher(true, "send raised exception ", result.repID)
								Reply.request_id = requestid
								Reply.reply_status = "USER_EXCEPTION"
								local stream = createMessage(self, ReplyID, Reply,
								                             {IDL.string, excepttype},
								                             result[1], result)
								_, except = conn:send(stream)                                   --[[VERBOSE]] verbose:dispatcher(false)
							elseif header.operation == "_non_existent" or
								     header.operation == "_not_existent"
								then                                                            --[[VERBOSE]] verbose:dispatcher "non_existent basic operation"
								Reply.request_id = requestid                                    --[[VERBOSE]] verbose:dispatcher(true, "send reply for request ", requestid)
								Reply.reply_status = "NO_EXCEPTION"
								local stream = createMessage(self, ReplyID, Reply,
								                   ObjectOps._non_existent.outputs, ReturnTrue)
								_, except = conn:send(stream)
							elseif result[1] == "OBJECT_NOT_EXIST" or 
							       result[1] == "NO_IMPLEMENT" then                           --[[VERBOSE]] verbose:dispatcher("object does not exist [key: ", header.object_key, "]")
									-- TODO:[nogara] fix sendsysex!!
									_, except = self:sendsysex(conn, requestid, { result[1],
									  minor_code_value  = 1, -- TODO:[maia] Which value?
									  completion_status = COMPLETED_NO,
									})
							elseif giop.SystemExceptionIDs[ result[1] ] then
								result.completion_status = COMPLETED_MAYBE
								_, except = self:sendsysex(conn, requestid, result)             --[[VERBOSE]] verbose:dispatcher(false)
							else                                                              --[[VERBOSE]] verbose:dispatcher("unexcepted exception rep. id: ", result[1])
								except = Exception{ "UNKNOWN", minor_code_value = 0,
								  completion_status = COMPLETED_MAYBE,
								  message = "unexpected exception raised",
								  reason = "exceptionid",
								  exception = result,
								}
								self:sendsysex(conn, requestid, except)
							end
							print("la")
						elseif type(result) == "string" then                                --[[VERBOSE]] verbose:dispatcher("unknown error in dispach, got ", result)
							print("la")
							except = Exception{ "UNKNOWN", minor_code_value = 0,
							  completion_status = COMPLETED_MAYBE,
							  message = "servant error: "..result,
							  reason = "servant",
							  operation = operation,
							  servant = servant,
							  error = result,
							}
							self:sendsysex(conn, requestid, except)
						else                                                                --[[VERBOSE]] verbose:dispatcher("illegal error type, got ", type(result))
							print("la")
							except = Exception{ "UNKNOWN", minor_code_value = 0,
							  completion_status = COMPLETED_MAYBE,
							  message = "invalid exception, got "..type(result),
							  reason = "exception",
							  exception = result,
							}
							self:sendsysex(conn, requestid, except)
						end                                                                 --[[VERBOSE]] else verbose:dispatcher("no reply expected or canceled for request ", requestid)
						print("fim do result")
					end
					print("fim do result 2")
				end

				return resultObject
			else 
				_, except = self:sendsysex(conn, requestid, { "BAD_OPERATION",
				  minor_code_value  = 1, -- TODO:[maia] Which value?
				  completion_status = COMPLETED_NO,
				})         
			end
			conn.pending[requestid] = nil
		else                                                                        --[[VERBOSE]] verbose:dispatcher("got duplicated request ID: ", requestid)
			except = Exception{ "INTERNAL", minor_code_value = 0,
			  completion_status = COMPLETED_NO,
			  message = "duplicated request ID received",
			  reason = "requestid",
			  requestid = requestid,
			}
			self:sendsysex(conn, requestid, except)
		end

	elseif msgtype == CancelRequestID then                                        --[[VERBOSE]] verbose:dispatcher("message to cancel request ", header.request_id)
		conn.pending[header.request_id] = nil
	elseif msgtype == LocateRequestID then                                        --[[VERBOSE]] verbose:dispatcher(true, "message requesting location")
		LocateReply.request_id = header.request_id
		conn:send(self, LocateReplyID, LocateReply)                                 --[[VERBOSE]] verbose:dispatcher(false)
	elseif msgtype == MessageErrorID then                                         --[[VERBOSE]] verbose:dispatcher "message error notice"
		conn:close()
	elseif msgtype then
		except = Except{ "INTERNAL",
		  completion_status = COMPLETED_NO,
		  message = "unexpected GIOP message, got "..MessageType[msgtype],
		  reason = "unexpected",
		  messageid = msgtype,
		}
		self:sendsysex(conn, requestid, except)
	else
		if header.reason ~= "closed" then
			except = header                                                           --[[VERBOSE]] else verbose:receive "client closed the connection"
		end
		conn:close()
	end
	return except == nil, except
end


local PortLowerBound = 2809 -- inclusive (never at first attempt)
local PortUpperBound = 9999 -- inclusive

function ListenProtocol:getchannel(args)
	local host, port
	host = "*"
	port = args.port
	local conn, except
	if not port then
		local start = PortLowerBound
		port = start
		repeat
	print('config', args)
			conn, except = self.channels:create(host, port)
	print('config', args)
			if conn then break end
			if port >= PortUpperBound
				then port = PortLowerBound
				else port = port + 1
			end
		until port == start
	else
		conn, except = self.channels:create(host, port)
	end
	--args.host = conn.host
	--args.port = port
	print( "conn", conn )
	local portConnection = PortConnection(conn, self.codec)
	print( "portConnection", portConnection )
	if not except then
		
	else 
		-- TODO:[nogara] treat this exception, in case the listen didn't went through
	end

	return portConnection, except
end


--------------------------------------------------------------------------------
-- IIOP IOR profile support ----------------------------------------------------

Tag = 0

local TaggedComponentSeq = IDL.sequence{IDL.struct{
	{name = "tag"           , type = IDL.ulong   },
	{name = "component_data", type = IDL.OctetSeq},
}}

local IIOPProfileBody_v1_ = {
	-- Note: First profile structure field is read/write directly
	[0] = IDL.struct{
		--{name = "iiop_version", type = IDL.Version },
		{name = "host"        , type = IDL.string  },
		{name = "port"        , type = IDL.ushort  },
		{name = "object_key"  , type = IDL.OctetSeq},
	},
	[1] = IDL.struct{
		--{name = "iiop_version", type = IDL.Version       },
		{name = "host"        , type = IDL.string        },
		{name = "port"        , type = IDL.ushort        },
		{name = "object_key"  , type = IDL.OctetSeq      },
		{name = "components"  , type = TaggedComponentSeq},
	},
}
IIOPProfileBody_v1_[2] = IIOPProfileBody_v1_[1] -- same as IIOP 1.1
IIOPProfileBody_v1_[3] = IIOPProfileBody_v1_[1] -- same as IIOP 1.1

local function openprofile(self, profile)                                             --[[VERBOSE]] verbose:connect(true, "open IIOP IOR profile")
	local buffer = self.codec:newDecoder(profile, true)
	local version = buffer:struct(IDL.Version)
	local profileidl = IIOPProfileBody_v1_[version.minor]

	if version.major ~= 1 or not profileidl then
		return nil, Exception{ "INTERNAL", minor_code_value = 0,
			message = "IIOP version not supported, got "..
								version.major.."."..version.minor,
			reason = "version",
			protocol = "IIOP",
			major = version.major,
			minor = version.minor,
		}
	end

	profile = buffer:struct(profileidl)
	profile.iiop_version = version -- add version read directly

	return profile                                                                --[[VERBOSE]] , verbose:connect(false)
end

local function createprofile(self, profile, minor)
	if not minor then minor = 0 end
	local profileidl = IIOPProfileBody_v1_[minor]

	if not profileidl then
		return nil, Exception{ "INTERNAL", minor_code_value = 0,
			message = "IIOP version not supported, got 1."..minor,
			reason = "version",
			protocol = "IIOP",
			major = 1,
			minor = minor,
		}
	end
																																								--[[VERBOSE]] verbose:ior(true, "create IIOP IOR profile with version 1.", minor)
	local buffer = self.codec:newEncoder(true)
	buffer:struct({major=1, minor=minor}, IDL.Version)
	buffer:struct(profile, profileidl)                                            --[[VERBOSE]] verbose:ior(false)
	return {
		tag = Tag,  -- TODO:[nogara] this tag=Tag=0 is only for iiop
		profile_data = buffer:getdata(),
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local components = Empty
function decodeurl(self, data)
	local temp, objectkey = string.match(data, "^([^/]*)/(.*)$")
	if temp
		then data = temp
		else objectkey = "" -- TODO:[maia] is this correct?
	end
	local major, minor
	major, minor, temp = string.match(data, "^(%d+).(%d+)@(.+)$")
	if major and major ~= "1" then
		return nil, Exception{ "INTERNAL", minor_code_value = 0,
			message = "IIOP version not supported, got "..major.."."..minor,
			reason = "version",
			protocol = "IIOP",
			major = major,
			minor = minor,
		}
	end
	if temp then data = temp end
	local host, port = string.match(data, "^([^:]+):(%d*)$")
	if port then
		port = tonumber(port)
	else
		port = 2809
		if data == ""
			then host = "localhost"
			else host = data
		end
	end                                                                           --[[VERBOSE]] verbose:ior("got host ", host, ":", port, " and object key '", objectkey, "'")
	return createprofile(self, {
			host = host,
			port = port,
			object_key = objectkey,
			components = components,
		},
		tonumber(minor)
	)
end

function decode_profile(self, profiles)
		for _, profile in ipairs(profiles) do                                         --[[VERBOSE]] verbose:resolver("got profile with tag ", profile.tag)
		if profile.tag == Tag then
			local decoded = openprofile(self, profile.profile_data)
			return decoded
		end
	end
end

function encode_profile(self, ...)
-- args are (host, port, object_key)
	return createprofile(self, {
		host = arg[1],
		port = arg[2],
		object_key = arg[3],
	})
end


