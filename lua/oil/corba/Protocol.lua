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
local MapWithArrayOfKeys = require "loop.collection.MapWithArrayOfKeys"
local OrderedSet         = require "loop.collection.OrderedSet"
local socket             = require "oil.socket"

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

-- variables used accessed by protocolHelper facet
HeaderSize            = GIOPHeaderSize
CloseConnectionID     = giop.CloseConnectionID

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

local OrderedSet      = require "loop.collection.OrderedSet"
local Exception       = require "oil.Exception"
local assert          = require "oil.assert"
local giop            = require "oil.corba.giop"

local Empty = {}

-- protocol IIOP tag
Tag = 0

local Connection = oo.class()

function Connection:__init()
	self.replies = {}
	self.receivers = {}
	self.senders = OrderedSet()
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
	size, type, header, buffer = unmarshallHeader(header)
	
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

function PortConnection:__init()
	self.senders = OrderedSet()
end

function PortConnection:close()
	-- test whether still active
	if self.port.connections:remove(self.socket) then                             --[[VERBOSE]] verbose:close "connection unregistered" verbose:close(true, "send close connection message")
		return self:send(self.protocolHelper.CloseConnectionID)                                         --[[VERBOSE]] , verbose:close(false)
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
verbose:debug( "createmessage" )
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
	conn, except = self.channels:create(reference)

	if conn then
		local request_id = requestid(conn)
		-- reuse the Request object because it is marshalled before any yield
		Request.request_id        = request_id
		Request.object_key        = except -- object_key at self._profiles
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
		
		local reply_object = ReplyObject{ result = function() 
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
	return true, result_object
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

local ReturnTrue = { true }
function ListenProtocol:getrequest(self, dispatcher, conn)
	local except
	local msgtype, header, buffer = conn:receive()
	if msgtype == RequestID then
		local requestid = header.request_id                                         --[[VERBOSE]] verbose:dispatcher("got request with ID ", requestid, " for object ", header.object_key )
		if conn.pending[requestid] == nil then
			conn.pending[requestid] = true
			
			local iface = self.objects:typeof(header.object_key)
			if iface then
				local member = iface.members[header.operation] or objectops[header.operation]
				local params = { n = #member.inputs }
				if member.attribute then 
						local result
						if member.inputs[1] 
							then servant[member.attribute] = buffer:get(member.inputs[1])     --[[VERBOSE]] verbose:dispatcher("changed the value of ", member.attribute)
							else result = servant[member.attribute]                           --[[VERBOSE]] verbose:dispatcher("the value of ", member.attribute, " is ", result)
						end                                                                 --[[VERBOSE]] verbose:dispatcher(false)
						if conn.pending[requestid] and header.response_expected then
							Reply.request_id = requestid                                      --[[VERBOSE]] verbose:dispatcher(true, "send reply for request ", requestid)
							Reply.reply_status = "NO_EXCEPTION"
							local stream = createMessage(self, ReplyID, Reply,
																		member.outputs, result)
							_, except = conn:send(stream)                                     --[[VERBOSE]] verbose:dispatcher(false) else verbose:dispatcher("no reply expected or canceled for request ", requestid)
						end
				else 
					-- try to call the function
					for index, input in ipairs(member.inputs) do
						params[index] = buffer:get(input)
					end
					local success, result = dispatcher:handle(header.object_key, 
					                                          header.operation, params )
					if conn.pending[requestid] and header.response_expected then
						if success then                                                     --[[VERBOSE]] verbose:dispatcher("send reply for request ", requestid)
							Reply.request_id = requestid
							Reply.reply_status = "NO_EXCEPTION"
							local stream = createMessage(self, ReplyID, Reply,
							                             member.outputs, unpack(result))
							_, except = conn:send(stream)                                     --[[VERBOSE]] verbose:dispatcher(false)
						elseif type(result) == "table" then
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
						elseif type(result) == "string" then                                --[[VERBOSE]] verbose:dispatcher("unknown error in dispach, got ", result)
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
							except = Exception{ "UNKNOWN", minor_code_value = 0,
							  completion_status = COMPLETED_MAYBE,
							  message = "invalid exception, got "..type(result),
							  reason = "exception",
							  exception = result,
							}
							self:sendsysex(conn, requestid, except)
						end                                                                 --[[VERBOSE]] else verbose:dispatcher("no reply expected or canceled for request ", requestid)
					end
				end
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


function getchannel(self, args)
	local conn, except = self.channels:create(args.host, args.port)
	if not except then
		
	else 
		-- TODO:[nogara] treat this exception, in case the listen didn't went through
	end

	return portConnection, except
end

--------------------------------------------------------------------------------
-- Port implementation
--------------------------------------------------------------------------------

local Empty = {}
local Port = oo.class()

function Port:__init(port)
	port.ready = OrderedSet() -- queue of ready connections
	port.connections = MapWithArrayOfKeys()
	port.connections:add(port.socket) -- first connection will always be the port
	return oo.rawnew(self, port)
end

function Port:waitformore(timeout)
	local ready = self.ready
	if self.ready:empty() then
		local connections = self.connections
		local attempts = 0 -- how many attempts to select a socket?
		local giveup = false
		repeat
			attempts = attempts + connections:size()                                  --[[VERBOSE]] verbose:listen("waiting for messages or more connections (", connections:size() - 1, ") [timeout: ", timeout, "]")
			local selected = socket:select(connections, Empty, timeout)
			local port = self.socket
			if selected[port] then                                                    --[[VERBOSE]] verbose:listen( "new connection accepted" )
				selected[port] = nil
				local conn = self.protocol:createConnection{
					pending = {},
					socket = port:accept(),
					port = self,
				}
				connections:add(conn.socket, conn)
			end
			for sock in pairs(selected) do
				if type(sock) ~= "number" then                                          --[[VERBOSE]] verbose:listen( "got new message" )
					local conn = connections[sock]
					ready:enqueue(conn)
				end
			end
			if timeout and timeout >= 0 then
				-- select has already tried to select ready sockets for timeout seconds
				if attempts > 1 or connections:size() == 1 then
					-- there were other attempts to select sockets besides
					-- the first one to select the port socket or ...
					-- no new connections were created
					giveup = true                                                         --[[VERBOSE]] else verbose:listen "repeating selection for new connections"
				end
			else
				giveup = not ready:empty()
			end
		until giveup
		return not ready:empty()
	else
		return true
	end
end

-- TODO:[nogara] Add scheduler to this part of code again after all is working
function Port:accept(dispatcher)
	local conn = self.ready:dequeue()
	if not conn then                                                              --[[VERBOSE]] verbose:listen(true, "no message, waiting for more")
		if self:waitformore() then
			conn = self.ready:dequeue()
		end                                                                         --[[VERBOSE]] verbose:listen(false) else verbose:listen "message already queued"
	end
	return self.protocol:handle(dispatcher, conn)
end

function Port:acceptall(dispatcher)
	local success, errmsg
	repeat
		success, errmsg = self:accept(dispatcher)
	until not success
	return success, errmsg
end

function createPort(self, args)
	local host = args.host or "*"
	local port = args.port
	local conn, except, reason
	-- use the protocol.listen function to create a new connection
	conn, except, reason = self:listen(host, port)
	if conn then
		conn = Port{
		  socket = conn.socket,
		  host = conn.host,
		  port = conn.port,
		  iorhost = args.iorhost,
		  iorport = args.iorport,
		  protocol = self,
		}
	else
		conn, except = nil, Exception{ "NO_RESOURCES", minor_code_value = 0,
		  message = "unable to bind to address "..host..":"..port,
		  reason = reason,
		  error = except,
		  host = host,
		  port = port,
		}
	end
	return conn, except
end

